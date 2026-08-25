const {createHmac, randomUUID} = require("node:crypto");
const {
  normalizeEmail,
  renderBrandedEmail,
} = require("./branded_email");

const senderEmail = "no-reply@plaqa.de";
const maxRequestBytes = 16 * 1024;
const minimumFillTimeMs = 1500;
const maximumFillTimeMs = 2 * 60 * 60 * 1000;
const shortWindowMs = 15 * 60 * 1000;
const dailyWindowMs = 24 * 60 * 60 * 1000;
const duplicateWindowMs = 10 * 60 * 1000;
const proposedMetadataTtlMs = 48 * 60 * 60 * 1000;
const rateLimitCollection = "_system_website_contact_rate_limits";
const duplicateCollection = "_system_website_contact_duplicates";
const submissionCollection = "_system_website_contact_submissions";
const allowedOrigins = new Set([
  "https://plaqa.de",
  "http://localhost:5000",
  "http://127.0.0.1:5000",
]);
const emailPattern = /^[^\s@]+@(?:[^\s@.]+\.)+[^\s@.]{2,}$/;
const forbiddenHeaderCharacters = /[\u0000-\u001f\u007f]/;
const forbiddenTextCharacters = /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/;

const channelConfigs = Object.freeze({
  support: Object.freeze({
    id: "support",
    label: "Support",
    recipient: "support@plaqa.de",
    pageUrl: "https://plaqa.de/support/",
    allowedFields: [
      "channel",
      "category",
      "email",
      "subject",
      "message",
      "appVersion",
      "device",
      "honeypot",
      "startedAt",
    ],
    categories: Object.freeze({
      technical_issue: "Technisches Problem",
      account_access: "Konto und Anmeldung",
      verification: "Verifizierung",
      feedback: "Feedback und Verbesserung",
      other: "Anderes Anliegen",
    }),
    confirmation: Object.freeze({
      eyebrow: "plaqa Support",
      title: "Supportanfrage erhalten",
      preheader: "Deine Supportanfrage ist bei plaqa angekommen.",
      paragraphs: [
        "deine Supportanfrage ist bei uns angekommen. Wir prüfen dein Anliegen und melden uns über die von dir angegebene E-Mail-Adresse.",
        "Bitte sende uns niemals Passwörter oder Anmeldecodes.",
      ],
      notice: "Du kannst auf diese E-Mail antworten, wenn du deiner Anfrage noch Informationen hinzufügen möchtest.",
      buttonLabel: "Zum plaqa Support",
    }),
  }),
  privacy: Object.freeze({
    id: "privacy",
    label: "Datenschutz",
    recipient: "privacy@plaqa.de",
    pageUrl: "https://plaqa.de/datenschutz/",
    allowedFields: [
      "channel",
      "requestType",
      "email",
      "message",
      "honeypot",
      "startedAt",
    ],
    categories: Object.freeze({
      access: "Auskunft",
      correction: "Berichtigung",
      deletion: "Löschung",
      restriction: "Einschränkung der Verarbeitung",
      objection: "Widerspruch",
      portability: "Datenübertragbarkeit",
      other: "Andere Datenschutzanfrage",
    }),
    confirmation: Object.freeze({
      eyebrow: "Datenschutz bei plaqa",
      title: "Datenschutzanfrage erhalten",
      preheader: "Deine Datenschutzanfrage ist bei plaqa angekommen.",
      paragraphs: [
        "deine Datenschutzanfrage ist bei uns angekommen und wird sorgfältig geprüft.",
        "Bitte sende keine Ausweis- oder Verifizierungsdokumente unaufgefordert per E-Mail. Falls eine Identitätsprüfung erforderlich ist, teilen wir dir den sicheren Ablauf mit.",
      ],
      notice: "Eine Kontolöschung kannst du weiterhin direkt in der App anstoßen. Der Ablauf ist zusätzlich auf plaqa.de/konto-loeschen beschrieben.",
      buttonLabel: "Datenschutz ansehen",
    }),
  }),
  partners: Object.freeze({
    id: "partners",
    label: "Partnerschaften",
    recipient: "partners@plaqa.de",
    pageUrl: "https://plaqa.de/partner/",
    allowedFields: [
      "channel",
      "name",
      "organization",
      "email",
      "partnershipType",
      "message",
      "honeypot",
      "startedAt",
    ],
    categories: Object.freeze({
      strategic: "Strategische Partnerschaft",
      business: "Geschäftliche Kooperation",
      technology: "Technologie und Integration",
      media: "Medien und Kommunikation",
      community: "Community und Veranstaltung",
      other: "Andere Partnerschaft",
    }),
    confirmation: Object.freeze({
      eyebrow: "Partnerschaften",
      title: "Partnerschaftsanfrage erhalten",
      preheader: "Deine Partnerschaftsanfrage ist bei plaqa angekommen.",
      paragraphs: [
        "vielen Dank für dein Interesse an einer Zusammenarbeit mit plaqa. Wir prüfen deine Anfrage und melden uns über die angegebene E-Mail-Adresse.",
        "Diese Eingangsbestätigung ist noch keine Zusage oder vertragliche Vereinbarung.",
      ],
      notice: "Ergänzungen kannst du als Antwort auf diese E-Mail senden.",
      buttonLabel: "Partnerschaften bei plaqa",
    }),
  }),
  report: Object.freeze({
    id: "report",
    label: "Meldestelle",
    recipient: "support@plaqa.de",
    pageUrl: "https://plaqa.de/meldestelle/",
    allowedFields: [
      "channel",
      "category",
      "reference",
      "description",
      "contactEmail",
      "honeypot",
      "startedAt",
    ],
    categories: Object.freeze({
      content: "Problematischer Inhalt",
      profile: "Profil oder Konto",
      harassment: "Belästigung oder Bedrohung",
      minor_safety: "Schutz von Minderjährigen",
      fraud: "Betrug oder Täuschung",
      other: "Andere Meldung",
    }),
    confirmation: Object.freeze({
      eyebrow: "plaqa Meldestelle",
      title: "Meldung erhalten",
      preheader: "Deine Meldung ist bei plaqa angekommen.",
      paragraphs: [
        "deine Meldung ist bei uns angekommen und wird anhand der verfügbaren Informationen geprüft.",
        "Wenn du eine Kontaktadresse angegeben hast, können wir dich bei notwendigen Rückfragen darüber erreichen.",
      ],
      notice: "Die plaqa Meldestelle ist keine Notfallstelle. Bei akuter Gefahr wende dich sofort an Polizei, Rettungsdienst oder eine andere zuständige Stelle.",
      buttonLabel: "Zur plaqa Meldestelle",
    }),
  }),
});

class WebsiteContactError extends Error {
  constructor(status, code, publicMessage) {
    super(publicMessage);
    this.name = "WebsiteContactError";
    this.status = status;
    this.code = code;
    this.publicMessage = publicMessage;
  }
}

async function handleWebsiteContactRequest({
  request,
  response,
  firestore,
  transportFactory,
  rateLimitSecret,
  now = new Date(),
  logger = console,
  requestIdFactory = randomUUID,
}) {
  const started = Date.now();
  let requestId = null;
  let channel = "unknown";

  try {
    const origin = headerValue(request, "origin");
    if (!allowedOrigins.has(origin)) {
      throw new WebsiteContactError(
        403,
        "origin-not-allowed",
        "Diese Anfrage konnte nicht verarbeitet werden.",
      );
    }
    applyCorsHeaders(response, origin);

    if (safeString(request?.method).toUpperCase() === "OPTIONS") {
      response.status(204).send("");
      return;
    }
    if (safeString(request?.method).toUpperCase() !== "POST") {
      setResponseHeader(response, "Allow", "POST, OPTIONS");
      throw new WebsiteContactError(
        405,
        "method-not-allowed",
        "Bitte sende das Formular erneut über die Website.",
      );
    }
    if (requestByteLength(request) > maxRequestBytes) {
      throw new WebsiteContactError(
        413,
        "request-too-large",
        "Die Anfrage ist zu groß. Bitte kürze deine Nachricht.",
      );
    }
    if (contentType(request) !== "application/json") {
      throw new WebsiteContactError(
        415,
        "unsupported-content-type",
        "Bitte sende das Formular erneut über die Website.",
      );
    }

    const submission = validateWebsiteContact(request?.body, now);
    channel = submission.channel;
    requestId = safeRequestId(requestIdFactory());
    const result = await processWebsiteContact({
      firestore,
      submission,
      clientAddress: clientAddress(request),
      transportFactory,
      rateLimitSecret,
      requestId,
      now,
    });
    logEvent(logger, "info", "Website contact request completed", {
      requestId,
      channel,
      result: result.confirmationSent === false ?
        "sent_without_confirmation" : "sent",
      durationMs: Date.now() - started,
    });
    response.status(202).json({accepted: true, requestId});
  } catch (error) {
    const safeError = publicError(error);
    logEvent(logger, safeError.status >= 500 ? "error" : "warn",
      "Website contact request rejected", {
        requestId,
        channel: channelConfigs[channel] == null ? "unknown" : channel,
        result: "rejected",
        durationMs: Date.now() - started,
        errorCategory: safeError.code,
      });
    response.status(safeError.status).json({
      accepted: false,
      error: safeError.publicMessage,
    });
  }
}

async function processWebsiteContact({
  firestore,
  submission,
  clientAddress: address,
  transportFactory,
  rateLimitSecret,
  requestId,
  now,
}) {
  const secret = requireRateLimitSecret(rateLimitSecret);
  const ipHash = hmacValue(secret, "ip", requireClientAddress(address));
  const contactEmail = submission.contactEmail;
  const emailHash = contactEmail == null ? null :
    hmacValue(secret, "email", contactEmail);
  const fingerprint = hmacValue(
    secret,
    "submission",
    canonicalSubmission(submission, emailHash || ipHash),
  );
  const claim = await claimWebsiteContact({
    firestore,
    submission,
    requestId,
    ipHash,
    emailHash,
    fingerprint,
    now,
  });

  let transport;
  try {
    transport = transportFactory();
    const internalMessage = internalMail({submission, requestId});
    await transport.sendMail(internalMessage);
  } catch (error) {
    if (transport != null && typeof transport.close === "function") {
      transport.close();
    }
    await markSubmission(claim.submissionReference, {
      status: "failed",
      errorCategory: "mail-service-unavailable",
      updatedAt: now,
    });
    await claim.duplicateReference.delete().catch(() => undefined);
    throw new WebsiteContactError(
      503,
      "mail-service-unavailable",
      "Deine Anfrage konnte gerade nicht gesendet werden. Bitte versuche es später erneut.",
    );
  }

  let confirmationSent = null;
  if (contactEmail != null) {
    try {
      await transport.sendMail(confirmationMail({submission, requestId}));
      confirmationSent = true;
    } catch (_) {
      confirmationSent = false;
    }
  }

  if (transport != null && typeof transport.close === "function") {
    transport.close();
  }
  await markSubmission(claim.submissionReference, {
    status: confirmationSent === false ?
      "sent_confirmation_failed" : "sent",
    confirmationSent,
    sentAt: now,
    updatedAt: now,
  });
  return {accepted: true, confirmationSent};
}

function validateWebsiteContact(body, now = new Date()) {
  if (!isPlainObject(body)) {
    invalidInput("Bitte prüfe deine Eingaben und versuche es erneut.");
  }
  const channel = requiredHeaderString(body.channel, 20);
  const config = channelConfigs[channel];
  if (config == null) {
    invalidInput("Bitte wähle einen gültigen Kontaktweg.");
  }
  rejectUnknownFields(body, config.allowedFields);
  if (typeof body.honeypot !== "string" || body.honeypot.length !== 0) {
    invalidInput("Diese Anfrage konnte nicht verarbeitet werden.");
  }
  validateStartedAt(body.startedAt, now);

  switch (channel) {
    case "support":
      return buildSubmission(config, {
        category: allowedCategory(body.category, config.categories),
        email: requiredEmail(body.email),
        subject: requiredHeaderString(body.subject, 120, 5),
        message: requiredText(body.message, 5000, 20),
        appVersion: optionalHeaderString(body.appVersion, 40),
        device: optionalHeaderString(body.device, 120),
      });
    case "privacy":
      return buildSubmission(config, {
        requestType: allowedCategory(body.requestType, config.categories),
        email: requiredEmail(body.email),
        message: requiredText(body.message, 5000, 20),
      });
    case "partners":
      return buildSubmission(config, {
        name: requiredHeaderString(body.name, 100, 2),
        organization: optionalHeaderString(body.organization, 160),
        email: requiredEmail(body.email),
        partnershipType: allowedCategory(
          body.partnershipType,
          config.categories,
        ),
        message: requiredText(body.message, 5000, 20),
      });
    case "report":
      return buildSubmission(config, {
        category: allowedCategory(body.category, config.categories),
        reference: optionalText(body.reference, 300),
        description: requiredText(body.description, 5000, 20),
        contactEmail: optionalEmail(body.contactEmail),
      });
    default:
      invalidInput("Bitte wähle einen gültigen Kontaktweg.");
  }
}

function buildSubmission(config, fields) {
  const contactEmail = fields.email || fields.contactEmail || null;
  return Object.freeze({
    channel: config.id,
    config,
    fields: Object.freeze(fields),
    contactEmail,
  });
}

async function claimWebsiteContact({
  firestore,
  submission,
  requestId,
  ipHash,
  emailHash,
  fingerprint,
  now,
}) {
  const nowMs = now.getTime();
  const rateSpecs = [
    rateSpec("ip_short", ipHash, nowMs, shortWindowMs, 8),
    rateSpec("ip_daily", ipHash, nowMs, dailyWindowMs, 30),
  ];
  if (emailHash != null) {
    rateSpecs.push(
      rateSpec("email_short", emailHash, nowMs, shortWindowMs, 4),
      rateSpec("email_daily", emailHash, nowMs, dailyWindowMs, 12),
    );
  }
  const rateReferences = rateSpecs.map((spec) =>
    firestore.collection(rateLimitCollection).doc(spec.documentId),
  );
  const duplicateReference = firestore.collection(duplicateCollection)
    .doc(fingerprint);
  const submissionReference = firestore.collection(submissionCollection)
    .doc(requestId);

  await firestore.runTransaction(async (transaction) => {
    const rateSnapshots = await Promise.all(
      rateReferences.map((reference) => transaction.get(reference)),
    );
    const duplicateSnapshot = await transaction.get(duplicateReference);
    const duplicateUntil = dateMillis(duplicateSnapshot.data()?.expiresAt);
    if (duplicateSnapshot.exists && duplicateUntil > nowMs) {
      throw tooManyRequests();
    }
    for (let index = 0; index < rateSpecs.length; index += 1) {
      const count = integerValue(rateSnapshots[index].data()?.count);
      if (count >= rateSpecs[index].maximum) {
        throw tooManyRequests();
      }
    }
    for (let index = 0; index < rateSpecs.length; index += 1) {
      const spec = rateSpecs[index];
      const count = integerValue(rateSnapshots[index].data()?.count);
      transaction.set(rateReferences[index], {
        scope: spec.scope,
        keyHash: spec.keyHash,
        windowStartedAt: new Date(spec.windowStartMs),
        windowEndsAt: new Date(spec.windowEndMs),
        count: count + 1,
        updatedAt: now,
        expiresAt: new Date(spec.windowEndMs + proposedMetadataTtlMs),
      }, {merge: false});
    }
    transaction.set(duplicateReference, {
      requestId,
      channel: submission.channel,
      fingerprint,
      createdAt: now,
      expiresAt: new Date(nowMs + duplicateWindowMs),
    }, {merge: false});
    transaction.set(submissionReference, compactObject({
      requestId,
      channel: submission.channel,
      ipHash,
      emailHash,
      fingerprint,
      status: "sending",
      createdAt: now,
      updatedAt: now,
      expiresAt: new Date(nowMs + proposedMetadataTtlMs),
    }), {merge: false});
  });

  return {duplicateReference, submissionReference};
}

function internalMail({submission, requestId}) {
  const details = internalDetailLines(submission);
  const content = renderBrandedEmail({
    preheader: `Neue ${submission.config.label}-Anfrage ${requestId}`,
    eyebrow: "plaqa Website",
    title: `${submission.config.label}-Anfrage`,
    greeting: "Neue Website-Anfrage,",
    paragraphs: [
      `Anfrage-ID: ${requestId}`,
      ...details,
    ],
    buttonLabel: "Kontaktseite öffnen",
    buttonUrl: submission.config.pageUrl,
    notice: "Diese Nachricht wurde serverseitig validiert. Antworte bei vorhandener Kontaktadresse direkt auf diese E-Mail.",
    contactEmail: submission.config.recipient,
    footerLabel: "Zuständiges plaqa Postfach:",
  });
  return mailEnvelope({
    to: submission.config.recipient,
    replyTo: submission.contactEmail,
    subject: `[plaqa Website] ${submission.config.label} ${requestId}`,
    content,
    requestId,
  });
}

function confirmationMail({submission, requestId}) {
  const confirmation = submission.config.confirmation;
  const content = renderBrandedEmail({
    preheader: confirmation.preheader,
    eyebrow: confirmation.eyebrow,
    title: confirmation.title,
    greeting: "Hallo,",
    paragraphs: [
      ...confirmation.paragraphs,
      `Deine Anfrage-ID lautet ${requestId}.`,
    ],
    buttonLabel: confirmation.buttonLabel,
    buttonUrl: submission.config.pageUrl,
    notice: confirmation.notice,
    contactEmail: submission.config.recipient,
    footerLabel: "Dies ist eine automatische Eingangsbestätigung. Rückfragen sendest du an",
  });
  return mailEnvelope({
    to: submission.contactEmail,
    replyTo: submission.config.recipient,
    subject: `${confirmation.title} · ${requestId}`,
    content,
    requestId,
  });
}

function mailEnvelope({to, replyTo, subject, content, requestId}) {
  return compactObject({
    from: `"plaqa" <${senderEmail}>`,
    to,
    replyTo,
    subject,
    html: content.html,
    text: content.text,
    headers: {
      "Auto-Submitted": "auto-generated",
      "Precedence": "auto_reply",
      "X-Auto-Response-Suppress": "All",
      "X-Plaqa-Website-Contact": requestId,
    },
    disableFileAccess: true,
    disableUrlAccess: true,
  });
}

function internalDetailLines(submission) {
  const fields = submission.fields;
  switch (submission.channel) {
    case "support":
      return compactLines([
        `Kategorie: ${categoryLabel(submission, fields.category)}`,
        `E-Mail: ${fields.email}`,
        `Betreff: ${fields.subject}`,
        `App-Version: ${fields.appVersion || "Nicht angegeben"}`,
        `Gerät/Plattform: ${fields.device || "Nicht angegeben"}`,
        `Nachricht:\n${fields.message}`,
      ]);
    case "privacy":
      return [
        `Anfrageart: ${categoryLabel(submission, fields.requestType)}`,
        `E-Mail: ${fields.email}`,
        `Nachricht:\n${fields.message}`,
      ];
    case "partners":
      return compactLines([
        `Name: ${fields.name}`,
        `Organisation: ${fields.organization || "Nicht angegeben"}`,
        `E-Mail: ${fields.email}`,
        `Partnerschaft: ${categoryLabel(submission, fields.partnershipType)}`,
        `Nachricht:\n${fields.message}`,
      ]);
    case "report":
      return compactLines([
        `Kategorie: ${categoryLabel(submission, fields.category)}`,
        `Inhalt-/Profilbezug: ${fields.reference || "Nicht angegeben"}`,
        `Kontaktadresse: ${fields.contactEmail || "Nicht angegeben"}`,
        `Beschreibung:\n${fields.description}`,
      ]);
    default:
      return [];
  }
}

function categoryLabel(submission, value) {
  return submission.config.categories[value] || value;
}

function rateSpec(scope, keyHash, nowMs, windowMs, maximum) {
  const windowStartMs = Math.floor(nowMs / windowMs) * windowMs;
  const windowEndMs = windowStartMs + windowMs;
  return {
    scope,
    keyHash,
    maximum,
    windowStartMs,
    windowEndMs,
    documentId: `${scope}_${windowStartMs}_${keyHash}`,
  };
}

async function markSubmission(reference, data) {
  try {
    await reference.set(data, {merge: true});
  } catch (_) {
    // Delivery success must not be turned into a retry and duplicate email.
  }
}

function canonicalSubmission(submission, actorHash) {
  const fields = Object.fromEntries(
    Object.entries(submission.fields)
      .filter(([key]) => key !== "email" && key !== "contactEmail")
      .sort(([left], [right]) => left.localeCompare(right)),
  );
  return JSON.stringify({
    channel: submission.channel,
    actorHash,
    fields,
  });
}

function validateStartedAt(value, now) {
  if (!Number.isInteger(value)) {
    invalidInput("Bitte lade das Formular neu und versuche es erneut.");
  }
  const elapsed = now.getTime() - value;
  if (elapsed < minimumFillTimeMs || elapsed > maximumFillTimeMs) {
    invalidInput("Bitte lade das Formular neu und versuche es erneut.");
  }
}

function rejectUnknownFields(body, allowedFields) {
  const allowed = new Set(allowedFields);
  if (Object.keys(body).some((field) => !allowed.has(field))) {
    invalidInput("Bitte prüfe deine Eingaben und versuche es erneut.");
  }
}

function allowedCategory(value, categories) {
  const normalized = requiredHeaderString(value, 60);
  if (!Object.prototype.hasOwnProperty.call(categories, normalized)) {
    invalidInput("Bitte wähle eine gültige Kategorie.");
  }
  return normalized;
}

function requiredEmail(value) {
  const email = normalizedEmail(value);
  if (email.length === 0) {
    invalidInput("Bitte gib eine gültige E-Mail-Adresse ein.");
  }
  return email;
}

function optionalEmail(value) {
  if (value == null || value === "") return null;
  return requiredEmail(value);
}

function normalizedEmail(value) {
  if (typeof value !== "string" || forbiddenHeaderCharacters.test(value)) {
    return "";
  }
  const email = normalizeEmail(value);
  return email.length <= 254 && emailPattern.test(email) ? email : "";
}

function requiredHeaderString(value, maximum, minimum = 1) {
  const normalized = headerString(value);
  if (normalized.length < minimum || normalized.length > maximum) {
    invalidInput("Bitte prüfe deine Eingaben und versuche es erneut.");
  }
  return normalized;
}

function optionalHeaderString(value, maximum) {
  if (value == null || value === "") return null;
  const normalized = headerString(value);
  if (normalized.length > maximum) {
    invalidInput("Bitte kürze deine Eingabe und versuche es erneut.");
  }
  return normalized.length === 0 ? null : normalized;
}

function headerString(value) {
  if (typeof value !== "string" || forbiddenHeaderCharacters.test(value)) {
    invalidInput("Bitte prüfe deine Eingaben und versuche es erneut.");
  }
  return value.trim().replace(/\s+/g, " ");
}

function requiredText(value, maximum, minimum) {
  const normalized = textString(value);
  if (normalized.length < minimum || normalized.length > maximum) {
    invalidInput("Bitte prüfe die Länge deiner Nachricht.");
  }
  return normalized;
}

function optionalText(value, maximum) {
  if (value == null || value === "") return null;
  const normalized = textString(value);
  if (normalized.length > maximum) {
    invalidInput("Bitte kürze deine Eingabe und versuche es erneut.");
  }
  return normalized.length === 0 ? null : normalized;
}

function textString(value) {
  if (typeof value !== "string" || forbiddenTextCharacters.test(value)) {
    invalidInput("Bitte prüfe deine Eingaben und versuche es erneut.");
  }
  return value.replace(/\r\n?/g, "\n").trim();
}

function invalidInput(message) {
  throw new WebsiteContactError(400, "invalid-input", message);
}

function tooManyRequests() {
  return new WebsiteContactError(
    429,
    "too-many-requests",
    "Zu viele Anfragen. Bitte versuche es später erneut.",
  );
}

function publicError(error) {
  if (error instanceof WebsiteContactError) return error;
  return new WebsiteContactError(
    500,
    "internal-error",
    "Die Anfrage konnte gerade nicht verarbeitet werden. Bitte versuche es später erneut.",
  );
}

function requireRateLimitSecret(value) {
  const secret = safeString(value);
  if (secret.length < 32) {
    throw new WebsiteContactError(
      503,
      "rate-limit-service-unavailable",
      "Die Anfrage konnte gerade nicht verarbeitet werden. Bitte versuche es später erneut.",
    );
  }
  return secret;
}

function requireClientAddress(value) {
  const address = safeString(value);
  if (address.length === 0 || address.length > 128) {
    throw new WebsiteContactError(
      503,
      "client-address-unavailable",
      "Die Anfrage konnte gerade nicht verarbeitet werden. Bitte versuche es später erneut.",
    );
  }
  return address;
}

function hmacValue(secret, namespace, value) {
  return createHmac("sha256", secret)
    .update(`${namespace}:${value}`)
    .digest("hex");
}

function clientAddress(request) {
  return safeString(request?.ip).slice(0, 128);
}

function requestByteLength(request) {
  const declaredLength = Number(headerValue(request, "content-length"));
  if (Number.isFinite(declaredLength) && declaredLength > maxRequestBytes) {
    return declaredLength;
  }
  if (Buffer.isBuffer(request?.rawBody)) return request.rawBody.length;
  try {
    return Buffer.byteLength(JSON.stringify(request?.body ?? null), "utf8");
  } catch (_) {
    return maxRequestBytes + 1;
  }
}

function contentType(request) {
  return headerValue(request, "content-type")
    .split(";", 1)[0]
    .trim()
    .toLowerCase();
}

function headerValue(request, name) {
  if (typeof request?.get === "function") {
    return safeString(request.get(name));
  }
  return safeString(request?.headers?.[name.toLowerCase()]);
}

function applyCorsHeaders(response, origin) {
  setResponseHeader(response, "Access-Control-Allow-Origin", origin);
  setResponseHeader(response, "Access-Control-Allow-Methods", "POST, OPTIONS");
  setResponseHeader(response, "Access-Control-Allow-Headers", "Content-Type");
  setResponseHeader(response, "Access-Control-Max-Age", "600");
  setResponseHeader(response, "Vary", "Origin");
}

function setResponseHeader(response, name, value) {
  if (typeof response?.set === "function") {
    response.set(name, value);
  } else if (typeof response?.setHeader === "function") {
    response.setHeader(name, value);
  }
}

function safeRequestId(value) {
  const requestId = safeString(value);
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(requestId)) {
    return randomUUID();
  }
  return requestId;
}

function dateMillis(value) {
  if (value instanceof Date) return value.getTime();
  if (value != null && typeof value.toMillis === "function") {
    return value.toMillis();
  }
  return 0;
}

function integerValue(value) {
  return Number.isInteger(value) && value >= 0 ? value : 0;
}

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item != null),
  );
}

function compactLines(value) {
  return value.filter((item) => typeof item === "string" && item.length > 0);
}

function isPlainObject(value) {
  return value != null && typeof value === "object" &&
    !Array.isArray(value) && Object.getPrototypeOf(value) === Object.prototype;
}

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function logEvent(logger, level, message, details) {
  const method = typeof logger?.[level] === "function" ?
    logger[level].bind(logger) : null;
  if (method != null) method(message, details);
}

module.exports = {
  WebsiteContactError,
  allowedOrigins,
  channelConfigs,
  handleWebsiteContactRequest,
  processWebsiteContact,
  validateWebsiteContact,
};
