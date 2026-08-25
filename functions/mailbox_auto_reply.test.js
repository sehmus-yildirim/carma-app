const assert = require("node:assert/strict");
const test = require("node:test");

const {
  mailboxConfigs,
  parseHeaders,
  renderMailboxAutoReply,
  responseSubject,
  runMailboxAutoReplies,
  shouldAutoReply,
} = require("./mailbox_auto_reply");

test("renders a matching black branded reply for every mailbox", () => {
  for (const mailbox of Object.values(mailboxConfigs)) {
    const content = renderMailboxAutoReply(mailbox);
    assert.match(content.html, /bgcolor="#000000"/);
    assert.match(content.html, /background:#000000 !important/);
    assert.match(content.html, new RegExp(`mailto:${mailbox.email}`));
    assert.match(content.html, new RegExp(mailbox.footerLabel));
    assert.match(content.html, new RegExp(mailbox.signatureLines[1]));
    assert.match(content.html, /plaqa_logo_transparent\.png/);
    assert.match(content.text, new RegExp(mailbox.email));
    assert.match(content.text, new RegExp(mailbox.signatureLines[1]));
    assert.doesNotMatch(content.html, /<script|tracking|pixel/i);
  }
});

test("uses purpose-specific wording and destinations", () => {
  const support = renderMailboxAutoReply(mailboxConfigs.support);
  const privacy = renderMailboxAutoReply(mailboxConfigs.privacy);
  const partners = renderMailboxAutoReply(mailboxConfigs.partners);

  assert.match(support.html, /plaqa Support/);
  assert.match(support.html, /https:\/\/plaqa\.de\/support\//);
  assert.match(privacy.html, /Datenschutzanfrage erhalten/);
  assert.match(privacy.html, /https:\/\/plaqa\.de\/konto-loeschen\//);
  assert.match(partners.html, /Vielen Dank für dein Interesse/);
  assert.match(partners.html, /https:\/\/plaqa\.de\/partner\//);
});

test("parses folded headers without retaining control characters", () => {
  const headers = parseHeaders(Buffer.from([
    "Auto-Submitted: no",
    "X-Test: first",
    "  second",
    "Return-Path: <sender@example.com>",
    "",
  ].join("\r\n")));
  assert.equal(headers.get("auto-submitted"), "no");
  assert.equal(headers.get("x-test"), "first second");
  assert.equal(headers.get("return-path"), "<sender@example.com>");
});

test("accepts an ordinary external sender", () => {
  assert.equal(shouldAutoReply({
    senderEmail: "nutzer@example.com",
    headers: new Map([
      ["auto-submitted", "no"],
      ["return-path", "<nutzer@example.com>"],
    ]),
  }), true);
});

test("rejects automatic, list, bounce and internal senders", () => {
  const cases = [
    {senderEmail: "support@plaqa.de", headers: new Map()},
    {senderEmail: "no-reply@example.com", headers: new Map()},
    {
      senderEmail: "system@example.com",
      headers: new Map([["auto-submitted", "auto-generated"]]),
    },
    {
      senderEmail: "newsletter@example.com",
      headers: new Map([["precedence", "bulk"]]),
    },
    {
      senderEmail: "list@example.com",
      headers: new Map([["list-id", "Example List"]]),
    },
    {
      senderEmail: "mailer@example.com",
      headers: new Map([["return-path", "<>"]]),
    },
  ];
  for (const candidate of cases) {
    assert.equal(shouldAutoReply(candidate), false);
  }
});

test("keeps replies in the original thread with a safe subject", () => {
  assert.equal(responseSubject("Hilfe mit meinem Konto"),
    "Re: Hilfe mit meinem Konto");
  assert.equal(responseSubject("Re: Hilfe"), "Re: Hilfe");
  assert.equal(responseSubject("Angriff\r\nBcc: fremd@example.com"),
    "Re: Angriff Bcc: fremd@example.com");
});

test("initializes safely before reading an existing mailbox", async () => {
  const firestore = new FakeFirestore();
  let imapCreated = false;
  const result = await runMailboxAutoReplies({
    firestore,
    mailbox: mailboxConfigs.support,
    password: "secret",
    now: new Date("2026-08-25T10:00:00Z"),
    imapFactory() {
      imapCreated = true;
      throw new Error("must not connect during initialization");
    },
  });

  assert.equal(result.initialized, true);
  assert.equal(imapCreated, false);
  assert.equal(firestore.data.has(
    "_system_mailbox_auto_reply_states/support",
  ), true);
});

test("sends once from the matching mailbox and suppresses duplicates", async () => {
  const firestore = new FakeFirestore();
  const enabledAt = new Date("2026-08-25T10:00:00Z");
  firestore.data.set("_system_mailbox_auto_reply_states/support", {
    mailboxId: "support",
    enabledAt,
    lastRunAt: enabledAt,
  });
  const sentMessages = [];
  const messages = [
    fakeMessage({
      uid: 10,
      sender: "nutzer@example.com",
      messageId: "<mail-10@example.com>",
      subject: "Hilfe benötigt",
      internalDate: new Date("2026-08-25T10:01:00Z"),
    }),
    fakeMessage({
      uid: 11,
      sender: "system@example.com",
      messageId: "<mail-11@example.com>",
      subject: "Automatisch",
      internalDate: new Date("2026-08-25T10:02:00Z"),
      headers: "Auto-Submitted: auto-generated\r\n",
    }),
  ];
  const common = {
    firestore,
    mailbox: mailboxConfigs.support,
    password: "secret",
    now: new Date("2026-08-25T10:03:00Z"),
    imapFactory: () => new FakeImapClient(messages),
    smtpFactory: () => new FakeTransport(sentMessages),
  };

  const first = await runMailboxAutoReplies(common);
  assert.equal(first.examined, 2);
  assert.equal(first.sent, 1);
  assert.equal(first.ignored, 1);
  assert.equal(sentMessages.length, 1);
  assert.equal(sentMessages[0].from,
    '"plaqa Support" <support@plaqa.de>');
  assert.equal(sentMessages[0].to, "nutzer@example.com");
  assert.equal(sentMessages[0].replyTo, "support@plaqa.de");
  assert.equal(sentMessages[0].inReplyTo, "<mail-10@example.com>");
  assert.equal(sentMessages[0].headers["Auto-Submitted"], "auto-replied");

  const second = await runMailboxAutoReplies({
    ...common,
    now: new Date("2026-08-25T10:08:00Z"),
  });
  assert.equal(second.sent, 0);
  assert.equal(second.skipped, 1);
  assert.equal(sentMessages.length, 1);
});

function fakeMessage({
  uid,
  sender,
  messageId,
  subject,
  internalDate,
  headers = "Auto-Submitted: no\r\n",
}) {
  return {
    uid,
    internalDate,
    headers: Buffer.from(`${headers}Message-Id: ${messageId}\r\n`),
    envelope: {
      from: [{address: sender}],
      messageId,
      subject,
    },
  };
}

class FakeImapClient {
  constructor(messages) {
    this.messages = messages;
  }

  async connect() {}

  async getMailboxLock() {
    return {release() {}};
  }

  async search() {
    return this.messages.map((message) => message.uid);
  }

  async fetchAll() {
    return this.messages.map((message) => ({...message}));
  }

  async logout() {}
}

class FakeTransport {
  constructor(messages) {
    this.messages = messages;
  }

  async verify() {}

  async sendMail(message) {
    this.messages.push(message);
  }

  close() {}
}

class FakeFirestore {
  constructor() {
    this.data = new Map();
  }

  collection(path) {
    return {
      doc: (id) => new FakeReference(this, `${path}/${id}`),
    };
  }

  async runTransaction(operation) {
    const writes = [];
    const transaction = {
      get: async (reference) => reference.get(),
      set: (reference, value, options) => {
        writes.push({reference, value, options});
      },
    };
    const result = await operation(transaction);
    for (const write of writes) {
      await write.reference.set(write.value, write.options);
    }
    return result;
  }
}

class FakeReference {
  constructor(firestore, path) {
    this.firestore = firestore;
    this.path = path;
  }

  async get() {
    const value = this.firestore.data.get(this.path);
    return {
      exists: value != null,
      data: () => value,
    };
  }

  async set(value, options = {}) {
    const previous = this.firestore.data.get(this.path) ?? {};
    this.firestore.data.set(
      this.path,
      options.merge === true ? {...previous, ...value} : {...value},
    );
  }
}
