const assert = require("node:assert/strict");
const test = require("node:test");

const {
  WebsiteContactError,
  channelConfigs,
  handleWebsiteContactRequest,
  processWebsiteContact,
  validateWebsiteContact,
} = require("./website_contact");

const fixedNow = new Date("2026-08-25T12:00:00.000Z");
const rateLimitSecret = "local-test-rate-limit-key-with-32-characters";

test("validates and normalizes every supported channel", () => {
  const submissions = Object.entries(validBodies()).map(([channel, body]) => {
    const submission = validateWebsiteContact(body, fixedNow);
    assert.equal(submission.channel, channel);
    assert.equal(submission.config.recipient, channelConfigs[channel].recipient);
    return submission;
  });

  assert.equal(submissions.length, 4);
  assert.equal(submissions[0].contactEmail, "nutzer@example.com");
  assert.equal(submissions[3].contactEmail, null);
  assert.equal(
    submissions[0].fields.message,
    "Die App zeigt nach dem Öffnen des Chats einen unbekannten Fehler.",
  );
});

test("rejects unknown fields, malformed values and bot signals", () => {
  const cases = [
    {...validBodies().support, recipient: "fremd@example.com"},
    {...validBodies().support, email: "ungueltig"},
    {...validBodies().support, subject: "Hilfe\r\nBcc: fremd@example.com"},
    {...validBodies().support, message: "Zu kurz"},
    {...validBodies().support, honeypot: "ausgefüllt"},
    {...validBodies().support, startedAt: fixedNow.getTime()},
    {...validBodies().support, category: "nicht_erlaubt"},
    {...validBodies().partners, name: "A"},
    {...validBodies().report, description: "x".repeat(5001)},
  ];

  for (const body of cases) {
    assert.throws(
      () => validateWebsiteContact(body, fixedNow),
      (error) => error instanceof WebsiteContactError && error.status === 400,
    );
  }
});

test("sends support internally and confirms with fixed safe headers", async () => {
  const firestore = new FakeFirestore();
  const transport = new FakeTransport();
  const body = {
    ...validBodies().support,
    subject: "Anzeige <script>alert(1)</script>",
    message: "Beim Öffnen erscheint <img src=x onerror=alert(1)> im Bereich.",
  };
  const submission = validateWebsiteContact(body, fixedNow);

  const result = await processWebsiteContact({
    firestore,
    submission,
    clientAddress: "203.0.113.10",
    transportFactory: () => transport,
    rateLimitSecret,
    requestId: "request-support-1",
    now: fixedNow,
  });

  assert.deepEqual(result, {accepted: true, confirmationSent: true});
  assert.equal(transport.messages.length, 2);
  const [internal, confirmation] = transport.messages;
  assert.equal(internal.from, '"plaqa" <no-reply@plaqa.de>');
  assert.equal(internal.to, "support@plaqa.de");
  assert.equal(internal.replyTo, "nutzer@example.com");
  assert.match(internal.subject, /Support request-support-1/);
  assert.match(internal.html, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
  assert.match(internal.html, /&lt;img src=x onerror=alert\(1\)&gt;/);
  assert.doesNotMatch(internal.html, /<script>|<img src=x/);
  assert.equal(internal.headers["Auto-Submitted"], "auto-generated");
  assert.equal(internal.headers.Precedence, "auto_reply");
  assert.equal(confirmation.to, "nutzer@example.com");
  assert.equal(confirmation.replyTo, "support@plaqa.de");
  assert.match(confirmation.text, /request-support-1/);

  assertStoredMetadataIsPseudonymous(firestore, [
    "203.0.113.10",
    "nutzer@example.com",
    body.subject,
    body.message,
  ]);
});

test("routes all channels to fixed recipients and handles anonymous reports", async () => {
  const expectedRecipients = {
    support: "support@plaqa.de",
    privacy: "privacy@plaqa.de",
    partners: "partners@plaqa.de",
    report: "support@plaqa.de",
  };

  for (const [index, [channel, body]] of
    Object.entries(validBodies()).entries()) {
    const firestore = new FakeFirestore();
    const transport = new FakeTransport();
    const submission = validateWebsiteContact(body, fixedNow);
    const result = await processWebsiteContact({
      firestore,
      submission,
      clientAddress: `203.0.113.${index + 20}`,
      transportFactory: () => transport,
      rateLimitSecret,
      requestId: `request-${channel}-route`,
      now: fixedNow,
    });

    assert.equal(transport.messages[0].to, expectedRecipients[channel]);
    assert.equal(transport.messages[0].from,
      '"plaqa" <no-reply@plaqa.de>');
    if (channel === "report") {
      assert.equal(transport.messages.length, 1);
      assert.equal(result.confirmationSent, null);
      assert.equal(transport.messages[0].replyTo, undefined);
    } else {
      assert.equal(transport.messages.length, 2);
      assert.equal(result.confirmationSent, true);
    }
  }
});

test("sends a report confirmation only when a contact address exists", async () => {
  const firestore = new FakeFirestore();
  const transport = new FakeTransport();
  const submission = validateWebsiteContact({
    ...validBodies().report,
    contactEmail: "hinweis@example.com",
  }, fixedNow);

  await processWebsiteContact({
    firestore,
    submission,
    clientAddress: "203.0.113.30",
    transportFactory: () => transport,
    rateLimitSecret,
    requestId: "request-report-contact",
    now: fixedNow,
  });

  assert.equal(transport.messages.length, 2);
  assert.equal(transport.messages[0].replyTo, "hinweis@example.com");
  assert.equal(transport.messages[1].to, "hinweis@example.com");
  assert.equal(transport.messages[1].replyTo, "support@plaqa.de");
  assert.match(transport.messages[1].html, /keine Notfallstelle/i);
});

test("deduplicates identical submissions for ten minutes", async () => {
  const firestore = new FakeFirestore();
  const transport = new FakeTransport();
  const submission = validateWebsiteContact(validBodies().support, fixedNow);
  const common = {
    firestore,
    submission,
    clientAddress: "203.0.113.40",
    transportFactory: () => transport,
    rateLimitSecret,
    now: fixedNow,
  };

  await processWebsiteContact({...common, requestId: "request-dedup-1"});
  await assert.rejects(
    processWebsiteContact({...common, requestId: "request-dedup-2"}),
    isRateLimitError,
  );
  assert.equal(transport.messages.length, 2);
});

test("enforces short IP and email limits transactionally", async () => {
  const ipFirestore = new FakeFirestore();
  const ipTransport = new FakeTransport();
  for (let index = 0; index < 8; index += 1) {
    const submission = supportSubmission(
      `IP-Nachricht Nummer ${index} mit genügend Inhalt.`,
      fixedNow,
      `ip-test-${index}@example.com`,
    );
    await processWebsiteContact({
      firestore: ipFirestore,
      submission,
      clientAddress: "203.0.113.50",
      transportFactory: () => ipTransport,
      rateLimitSecret,
      requestId: `request-ip-${index}`,
      now: fixedNow,
    });
  }
  await assert.rejects(processWebsiteContact({
    firestore: ipFirestore,
    submission: supportSubmission(
      "Neunte IP-Nachricht mit genügend Inhalt.",
      fixedNow,
      "ip-test-9@example.com",
    ),
    clientAddress: "203.0.113.50",
    transportFactory: () => ipTransport,
    rateLimitSecret,
    requestId: "request-ip-9",
    now: fixedNow,
  }), isRateLimitError);

  const emailFirestore = new FakeFirestore();
  const emailTransport = new FakeTransport();
  for (let index = 0; index < 4; index += 1) {
    await processWebsiteContact({
      firestore: emailFirestore,
      submission: supportSubmission(
        `E-Mail-Nachricht Nummer ${index} mit genügend Inhalt.`,
      ),
      clientAddress: `203.0.113.${60 + index}`,
      transportFactory: () => emailTransport,
      rateLimitSecret,
      requestId: `request-email-${index}`,
      now: fixedNow,
    });
  }
  await assert.rejects(processWebsiteContact({
    firestore: emailFirestore,
    submission: supportSubmission("Fünfte E-Mail-Nachricht mit genügend Inhalt."),
    clientAddress: "203.0.113.70",
    transportFactory: () => emailTransport,
    rateLimitSecret,
    requestId: "request-email-5",
    now: fixedNow,
  }), isRateLimitError);
});

test("enforces the daily email limit across short windows", async () => {
  const firestore = new FakeFirestore();
  const transport = new FakeTransport();
  for (let index = 0; index < 12; index += 1) {
    const now = new Date(fixedNow.getTime() + index * 16 * 60 * 1000);
    await processWebsiteContact({
      firestore,
      submission: supportSubmission(
        `Tageslimit Nachricht ${index} mit ausreichend Inhalt.`,
        now,
      ),
      clientAddress: `198.51.100.${index + 1}`,
      transportFactory: () => transport,
      rateLimitSecret,
      requestId: `request-daily-${index}`,
      now,
    });
  }
  const finalNow = new Date(fixedNow.getTime() + 12 * 16 * 60 * 1000);
  await assert.rejects(processWebsiteContact({
    firestore,
    submission: supportSubmission(
      "Dreizehnte Tageslimit-Nachricht mit ausreichend Inhalt.",
      finalNow,
    ),
    clientAddress: "198.51.100.100",
    transportFactory: () => transport,
    rateLimitSecret,
    requestId: "request-daily-13",
    now: finalNow,
  }), isRateLimitError);
});

test("releases duplicate claim after an internal mail failure", async () => {
  const firestore = new FakeFirestore();
  const failingTransport = new FakeTransport({failAt: 1});
  const submission = validateWebsiteContact(validBodies().support, fixedNow);
  const common = {
    firestore,
    submission,
    clientAddress: "203.0.113.80",
    rateLimitSecret,
    now: fixedNow,
  };

  await assert.rejects(processWebsiteContact({
    ...common,
    transportFactory: () => failingTransport,
    requestId: "request-failure-1",
  }), (error) => error.status === 503 &&
    error.code === "mail-service-unavailable");
  assert.equal(failingTransport.closed, true);

  const retryTransport = new FakeTransport();
  const result = await processWebsiteContact({
    ...common,
    transportFactory: () => retryTransport,
    requestId: "request-failure-2",
  });
  assert.equal(result.accepted, true);
  assert.equal(retryTransport.messages.length, 2);
});

test("HTTP handler enforces method, content type, size and CORS", async () => {
  const scenarios = [
    {
      request: fakeRequest({method: "GET"}),
      expectedStatus: 405,
    },
    {
      request: fakeRequest({contentType: "text/plain"}),
      expectedStatus: 415,
    },
    {
      request: fakeRequest({origin: "https://example.com"}),
      expectedStatus: 403,
    },
    {
      request: fakeRequest({rawBody: Buffer.alloc(16 * 1024 + 1)}),
      expectedStatus: 413,
    },
  ];

  for (const scenario of scenarios) {
    const response = new FakeResponse();
    await handleWebsiteContactRequest({
      request: scenario.request,
      response,
      firestore: new FakeFirestore(),
      transportFactory: () => new FakeTransport(),
      rateLimitSecret,
      now: fixedNow,
      logger: new FakeLogger(),
      requestIdFactory: () => "request-http-error",
    });
    assert.equal(response.statusCode, scenario.expectedStatus);
    assert.equal(response.body.accepted, false);
  }

  const preflight = new FakeResponse();
  await handleWebsiteContactRequest({
    request: fakeRequest({method: "OPTIONS"}),
    response: preflight,
    firestore: new FakeFirestore(),
    transportFactory: () => new FakeTransport(),
    rateLimitSecret,
    now: fixedNow,
    logger: new FakeLogger(),
  });
  assert.equal(preflight.statusCode, 204);
  assert.equal(preflight.headers["Access-Control-Allow-Origin"],
    "https://plaqa.de");
  assert.equal(preflight.headers.Vary, "Origin");
});

test("HTTP handler accepts production and explicit local origins only", async () => {
  for (const origin of [
    "https://plaqa.de",
    "http://localhost:5000",
    "http://127.0.0.1:5000",
  ]) {
    const logger = new FakeLogger();
    const response = new FakeResponse();
    await handleWebsiteContactRequest({
      request: fakeRequest({origin}),
      response,
      firestore: new FakeFirestore(),
      transportFactory: () => new FakeTransport(),
      rateLimitSecret,
      now: fixedNow,
      logger,
      requestIdFactory: () => `request-origin-${origin.length}`,
    });
    assert.equal(response.statusCode, 202);
    assert.equal(response.body.accepted, true);
    assert.equal(response.headers["Access-Control-Allow-Origin"], origin);
  }
});

test("logs contain metadata only and return generic transport failures", async () => {
  const logger = new FakeLogger();
  const response = new FakeResponse();
  const request = fakeRequest();
  await handleWebsiteContactRequest({
    request,
    response,
    firestore: new FakeFirestore(),
    transportFactory: () => new FakeTransport({failAt: 1}),
    rateLimitSecret,
    now: fixedNow,
    logger,
    requestIdFactory: () => "request-generic-failure",
  });

  assert.equal(response.statusCode, 503);
  assert.equal(response.body.accepted, false);
  assert.doesNotMatch(response.body.error, /smtp|firebase|firestore|secret|stack/i);
  const serializedLogs = JSON.stringify(logger.entries);
  assert.doesNotMatch(serializedLogs, /nutzer@example\.com/);
  assert.doesNotMatch(serializedLogs, /203\.0\.113\.10/);
  assert.doesNotMatch(serializedLogs, /unbekannten Fehler/);
});

function validBodies(now = fixedNow) {
  const startedAt = now.getTime() - 5000;
  return {
    support: {
      channel: "support",
      category: "technical_issue",
      email: " Nutzer@Example.COM ",
      subject: "Darstellungsproblem im Chat",
      message:
        "Die App zeigt nach dem Öffnen des Chats einen unbekannten Fehler.",
      appVersion: "plaqa 1.0.0",
      device: "Android",
      honeypot: "",
      startedAt,
    },
    privacy: {
      channel: "privacy",
      requestType: "access",
      email: "datenschutz@example.com",
      message: "Ich möchte Auskunft zu den Daten meines plaqa Kontos erhalten.",
      honeypot: "",
      startedAt,
    },
    partners: {
      channel: "partners",
      name: "Plaqa Partner",
      organization: "Beispiel GmbH",
      email: "partner@example.com",
      partnershipType: "strategic",
      message: "Wir möchten eine mögliche Partnerschaft mit plaqa besprechen.",
      honeypot: "",
      startedAt,
    },
    report: {
      channel: "report",
      category: "content",
      reference: "Profil Plaqa N.",
      description:
        "Ich möchte einen möglicherweise problematischen Inhalt melden.",
      contactEmail: "",
      honeypot: "",
      startedAt,
    },
  };
}

function supportSubmission(
  message,
  now = fixedNow,
  email = "nutzer@example.com",
) {
  return validateWebsiteContact({
    ...validBodies(now).support,
    email,
    message,
  }, now);
}

function fakeRequest({
  method = "POST",
  origin = "https://plaqa.de",
  contentType = "application/json; charset=utf-8",
  body = validBodies().support,
  rawBody,
  ip = "203.0.113.10",
} = {}) {
  const headers = {
    origin,
    "content-type": contentType,
  };
  const serializedBody = Buffer.from(JSON.stringify(body));
  return {
    method,
    headers,
    body,
    rawBody: rawBody || serializedBody,
    ip,
    get(name) {
      return headers[name.toLowerCase()];
    },
  };
}

function isRateLimitError(error) {
  return error instanceof WebsiteContactError && error.status === 429 &&
    error.code === "too-many-requests";
}

function assertStoredMetadataIsPseudonymous(firestore, forbiddenValues) {
  const stored = JSON.stringify([...firestore.documents.values()]);
  for (const value of forbiddenValues) {
    assert.doesNotMatch(stored, new RegExp(escapeRegExp(value), "i"));
  }
  assert.match(stored, /ipHash/);
  assert.match(stored, /emailHash/);
  assert.match(stored, /expiresAt/);
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

class FakeTransport {
  constructor({failAt = null} = {}) {
    this.messages = [];
    this.failAt = failAt;
    this.attempts = 0;
    this.closed = false;
  }

  async sendMail(message) {
    this.attempts += 1;
    if (this.attempts === this.failAt) {
      throw new Error("simulated transport failure");
    }
    this.messages.push(message);
    return {messageId: `test-${this.attempts}`};
  }

  close() {
    this.closed = true;
  }
}

class FakeFirestore {
  constructor() {
    this.documents = new Map();
  }

  collection(name) {
    return {
      doc: (id) => new FakeDocumentReference(this, `${name}/${id}`),
    };
  }

  async runTransaction(callback) {
    const writes = [];
    const transaction = {
      get: async (reference) => this.snapshot(reference.path),
      set: (reference, data, options) => {
        writes.push({reference, data, options});
      },
    };
    const result = await callback(transaction);
    for (const write of writes) {
      this.set(write.reference.path, write.data, write.options);
    }
    return result;
  }

  snapshot(path) {
    return {
      exists: this.documents.has(path),
      data: () => this.documents.get(path),
    };
  }

  set(path, data, options) {
    const previous = this.documents.get(path) || {};
    this.documents.set(path, options?.merge === true ?
      {...previous, ...data} : {...data});
  }
}

class FakeDocumentReference {
  constructor(firestore, path) {
    this.firestore = firestore;
    this.path = path;
  }

  async set(data, options) {
    this.firestore.set(this.path, data, options);
  }

  async delete() {
    this.firestore.documents.delete(this.path);
  }
}

class FakeResponse {
  constructor() {
    this.statusCode = 200;
    this.headers = {};
    this.body = null;
  }

  set(name, value) {
    this.headers[name] = value;
    return this;
  }

  status(value) {
    this.statusCode = value;
    return this;
  }

  json(value) {
    this.body = value;
    return this;
  }

  send(value) {
    this.body = value;
    return this;
  }
}

class FakeLogger {
  constructor() {
    this.entries = [];
  }

  info(message, details) {
    this.entries.push({level: "info", message, details});
  }

  warn(message, details) {
    this.entries.push({level: "warn", message, details});
  }

  error(message, details) {
    this.entries.push({level: "error", message, details});
  }
}
