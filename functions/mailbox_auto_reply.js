const {createHash} = require("node:crypto");
const {ImapFlow} = require("imapflow");
const nodemailer = require("nodemailer");
const {
  normalizeEmail,
  renderBrandedEmail,
} = require("./branded_email");

const imapHost = "imap.ionos.de";
const imapPort = 993;
const smtpHost = "smtp.ionos.de";
const smtpPort = 465;
const maxMessagesPerRun = 50;
const senderCooldownMs = 24 * 60 * 60 * 1000;
const recordRetentionMs = 90 * 24 * 60 * 60 * 1000;
const stateCollection = "_system_mailbox_auto_reply_states";
const replyCollection = "_system_mailbox_auto_replies";
const cooldownCollection = "_system_mailbox_sender_cooldowns";

const mailboxConfigs = Object.freeze({
  support: Object.freeze({
    id: "support",
    email: "support@plaqa.de",
    senderName: "plaqa Support",
    eyebrow: "plaqa Support",
    title: "Nachricht erhalten",
    preheader: "Deine Nachricht ist beim plaqa Support angekommen.",
    paragraphs: [
      "deine Nachricht ist sicher bei unserem Support angekommen. Wir prüfen dein Anliegen und melden uns über diesen E-Mail-Verlauf bei dir.",
      "Ergänzungen kannst du einfach als Antwort auf diese E-Mail senden. Bitte teile keine Passwörter oder Anmeldecodes.",
    ],
    signatureLines: ["Viele Grüße", "Dein plaqa Support"],
    buttonLabel: "Zum plaqa Support",
    buttonUrl: "https://plaqa.de/support/",
    notice: "Bei akuter Gefahr wende dich bitte direkt an die zuständigen örtlichen Stellen. Die plaqa-Meldefunktion ersetzt keinen Notruf.",
    footerLabel: "Dies ist eine automatische Nachricht vom plaqa Support. Weitere Hilfe erhältst du unter",
  }),
  privacy: Object.freeze({
    id: "privacy",
    email: "privacy@plaqa.de",
    senderName: "plaqa Datenschutz",
    eyebrow: "Datenschutz bei plaqa",
    title: "Datenschutzanfrage erhalten",
    preheader: "Deine Datenschutzanfrage ist bei plaqa angekommen.",
    paragraphs: [
      "wir haben deine Nachricht zum Datenschutz erhalten und prüfen dein Anliegen sorgfältig. Je nach Anfrage kann eine Identitätsprüfung erforderlich sein, bevor personenbezogene Daten offengelegt, geändert oder gelöscht werden.",
      "Bitte sende keine Ausweisdokumente unaufgefordert per E-Mail. Falls weitere Angaben nötig sind, melden wir uns über diesen E-Mail-Verlauf.",
    ],
    signatureLines: ["Viele Grüße", "Dein plaqa Datenschutzteam"],
    buttonLabel: "Datenschutz ansehen",
    buttonUrl: "https://plaqa.de/datenschutz/",
    notice: "Eine Kontolöschung kannst du auch direkt in der App anstoßen. Der öffentliche Ablauf ist unter plaqa.de/konto-loeschen beschrieben.",
    footerLabel: "Dies ist eine automatische Eingangsbestätigung von plaqa Datenschutz. Rückfragen sendest du an",
    footerLinks: [
      {label: "Kontolöschung", url: "https://plaqa.de/konto-loeschen/"},
      {label: "Impressum", url: "https://plaqa.de/impressum/"},
    ],
  }),
  partners: Object.freeze({
    id: "partners",
    email: "partners@plaqa.de",
    senderName: "plaqa Partnerschaften",
    eyebrow: "Partnerschaften",
    title: "Vielen Dank für dein Interesse",
    preheader: "Deine Partnerschaftsanfrage ist bei plaqa angekommen.",
    paragraphs: [
      "deine Anfrage ist bei plaqa angekommen. Wir prüfen, wie dein Unternehmen, deine Idee oder dein Angebot zu unserer Fahrzeug-Community passt.",
      "Ergänzende Informationen oder Unterlagen kannst du einfach als Antwort auf diese E-Mail senden.",
    ],
    signatureLines: ["Viele Grüße", "Dein plaqa Partnerschaftsteam"],
    buttonLabel: "Partnerschaften bei plaqa",
    buttonUrl: "https://plaqa.de/partner/",
    notice: "Diese Eingangsbestätigung ist noch keine Zusage oder vertragliche Vereinbarung.",
    footerLabel: "Dies ist eine automatische Eingangsbestätigung von plaqa Partnerschaften. Rückfragen sendest du an",
  }),
});

function createIonosImapClient(email, password) {
  return new ImapFlow({
    host: imapHost,
    port: imapPort,
    secure: true,
    auth: {user: email, pass: requirePassword(password)},
    connectionTimeout: 15000,
    greetingTimeout: 10000,
    socketTimeout: 30000,
    disableAutoIdle: true,
    logger: false,
    tls: {
      minVersion: "TLSv1.2",
      rejectUnauthorized: true,
    },
  });
}

function createIonosSmtpTransport(email, password) {
  return nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: true,
    auth: {user: email, pass: requirePassword(password)},
    connectionTimeout: 15000,
    greetingTimeout: 10000,
    socketTimeout: 20000,
    disableFileAccess: true,
    disableUrlAccess: true,
    tls: {
      minVersion: "TLSv1.2",
      rejectUnauthorized: true,
    },
  });
}

async function runMailboxAutoReplies({
  firestore,
  mailbox,
  password,
  now = new Date(),
  imapFactory = createIonosImapClient,
  smtpFactory = createIonosSmtpTransport,
}) {
  validateMailbox(mailbox);
  requirePassword(password);

  const stateReference = firestore.collection(stateCollection).doc(mailbox.id);
  const stateSnapshot = await stateReference.get();
  if (!stateSnapshot.exists) {
    await stateReference.set({
      mailboxId: mailbox.id,
      enabledAt: now,
      lastRunAt: now,
    }, {merge: false});
    return emptyResult({initialized: true});
  }

  const enabledAt = dateFromValue(stateSnapshot.data()?.enabledAt) ?? now;
  const imapClient = imapFactory(mailbox.email, password);
  let messages = [];
  let imapConnected = false;
  try {
    await imapClient.connect();
    imapConnected = true;
    const lock = await imapClient.getMailboxLock("INBOX");
    try {
      const unseenUids = await imapClient.search({seen: false}, {uid: true});
      const selectedUids = unseenUids.slice(-maxMessagesPerRun);
      if (selectedUids.length > 0) {
        messages = await imapClient.fetchAll(selectedUids, {
          uid: true,
          envelope: true,
          internalDate: true,
          headers: [
            "Auto-Submitted",
            "List-Id",
            "Message-Id",
            "Precedence",
            "Return-Path",
            "X-Auto-Response-Suppress",
          ],
        }, {uid: true});
      }
    } finally {
      lock.release();
    }
  } finally {
    if (imapConnected) {
      await imapClient.logout().catch(() => undefined);
    }
  }

  const result = emptyResult({examined: messages.length});
  let transport;
  try {
    for (const message of messages.sort((a, b) => a.uid - b.uid)) {
      const messageDate = dateFromValue(message.internalDate) ?? now;
      if (messageDate.getTime() < enabledAt.getTime() - 60 * 1000) {
        result.ignored += 1;
        continue;
      }
      const headers = parseHeaders(message.headers);
      const senderEmail = messageSender(message);
      if (!shouldAutoReply({senderEmail, headers})) {
        result.ignored += 1;
        continue;
      }
      const identity = messageIdentity({mailbox, message, headers});
      const claim = await claimReply({
        firestore,
        mailbox,
        senderEmail,
        identity,
        now,
      });
      if (!claim.claimed) {
        result.skipped += 1;
        continue;
      }

      try {
        transport ??= smtpFactory(mailbox.email, password);
        if (typeof transport.verify === "function" && result.sent === 0) {
          await transport.verify();
        }
        const content = renderMailboxAutoReply(mailbox);
        const originalMessageId = safeMessageId(
          message.envelope?.messageId || headers.get("message-id"),
        );
        await transport.sendMail({
          from: `"${mailbox.senderName}" <${mailbox.email}>`,
          to: senderEmail,
          replyTo: mailbox.email,
          subject: responseSubject(message.envelope?.subject),
          html: content.html,
          text: content.text,
          inReplyTo: originalMessageId || undefined,
          references: originalMessageId || undefined,
          headers: {
            "Auto-Submitted": "auto-replied",
            "Precedence": "auto_reply",
            "X-Auto-Response-Suppress": "All",
          },
          disableFileAccess: true,
          disableUrlAccess: true,
        });
        await claim.replyReference.set({
          status: "sent",
          sentAt: now,
        }, {merge: true});
        result.sent += 1;
      } catch (error) {
        await claim.replyReference.set({
          status: "failed",
          failedAt: now,
          errorType: errorType(error),
        }, {merge: true});
        result.failed += 1;
      }
    }
  } finally {
    if (transport != null && typeof transport.close === "function") {
      transport.close();
    }
  }

  await stateReference.set({lastRunAt: now}, {merge: true});
  return result;
}

function renderMailboxAutoReply(mailbox) {
  validateMailbox(mailbox);
  return renderBrandedEmail({
    preheader: mailbox.preheader,
    eyebrow: mailbox.eyebrow,
    title: mailbox.title,
    greeting: "Hallo,",
    paragraphs: mailbox.paragraphs,
    buttonLabel: mailbox.buttonLabel,
    buttonUrl: mailbox.buttonUrl,
    notice: mailbox.notice,
    contactEmail: mailbox.email,
    footerLabel: mailbox.footerLabel,
    footerLinks: mailbox.footerLinks,
    signatureLines: mailbox.signatureLines,
  });
}

function shouldAutoReply({senderEmail, headers}) {
  const normalizedSender = normalizeEmail(senderEmail);
  if (normalizedSender.length === 0 || normalizedSender.endsWith("@plaqa.de")) {
    return false;
  }
  const localPart = normalizedSender.split("@")[0];
  if (/^(no-?reply|mailer-daemon|postmaster)$/i.test(localPart)) {
    return false;
  }
  const autoSubmitted = headerValue(headers, "auto-submitted").toLowerCase();
  if (autoSubmitted.length > 0 && autoSubmitted !== "no") {
    return false;
  }
  if (headerValue(headers, "x-auto-response-suppress").length > 0 ||
      headerValue(headers, "list-id").length > 0) {
    return false;
  }
  const precedence = headerValue(headers, "precedence").toLowerCase();
  if (/\b(bulk|junk|list|auto_reply)\b/.test(precedence)) {
    return false;
  }
  return headerValue(headers, "return-path") !== "<>";
}

async function claimReply({
  firestore,
  mailbox,
  senderEmail,
  identity,
  now,
}) {
  const senderHash = hashValue(`${mailbox.id}:${senderEmail}`);
  const replyHash = hashValue(`${mailbox.id}:${identity}`);
  const replyReference = firestore.collection(replyCollection).doc(replyHash);
  const cooldownReference = firestore.collection(cooldownCollection)
    .doc(senderHash);
  const claimed = await firestore.runTransaction(async (transaction) => {
    const replySnapshot = await transaction.get(replyReference);
    const cooldownSnapshot = await transaction.get(cooldownReference);
    if (replySnapshot.exists) return false;
    const cooldownUntil = dateFromValue(cooldownSnapshot.data()?.expiresAt);
    const isCoolingDown = cooldownUntil != null &&
      cooldownUntil.getTime() > now.getTime();
    transaction.set(replyReference, {
      mailboxId: mailbox.id,
      senderHash,
      status: isCoolingDown ? "suppressed" : "sending",
      createdAt: now,
      expiresAt: new Date(now.getTime() + recordRetentionMs),
    }, {merge: false});
    if (isCoolingDown) return false;
    transaction.set(cooldownReference, {
      mailboxId: mailbox.id,
      senderHash,
      updatedAt: now,
      expiresAt: new Date(now.getTime() + senderCooldownMs),
    }, {merge: false});
    return true;
  });
  return {claimed, replyReference};
}

function parseHeaders(value) {
  const headers = new Map();
  if (!Buffer.isBuffer(value) && typeof value !== "string") return headers;
  const unfolded = String(value).replace(/\r?\n[\t ]+/g, " ");
  for (const line of unfolded.split(/\r?\n/)) {
    const separator = line.indexOf(":");
    if (separator <= 0) continue;
    const key = line.slice(0, separator).trim().toLowerCase();
    const header = safeHeaderValue(line.slice(separator + 1));
    if (key.length > 0 && !headers.has(key)) headers.set(key, header);
  }
  return headers;
}

function messageSender(message) {
  const addresses = message.envelope?.from ?? [];
  for (const entry of addresses) {
    const email = normalizeEmail(entry?.address);
    if (email.length > 0) return email;
  }
  return "";
}

function messageIdentity({mailbox, message, headers}) {
  const messageId = safeMessageId(
    message.envelope?.messageId || headers.get("message-id"),
  );
  if (messageId.length > 0) return messageId;
  const uidValidity = String(message.uidValidity ?? "unknown");
  return `${mailbox.id}:${uidValidity}:${Number(message.uid) || 0}`;
}

function responseSubject(value) {
  const subject = safeHeaderValue(value) || "Deine Nachricht an plaqa";
  return /^re:/i.test(subject) ? subject : `Re: ${subject}`;
}

function safeMessageId(value) {
  const messageId = safeHeaderValue(value);
  return /^<[^<>\r\n]{1,998}>$/.test(messageId) ? messageId : "";
}

function safeHeaderValue(value) {
  return typeof value === "string" ?
    value.replace(/[\r\n\u0000-\u001f\u007f]+/g, " ").trim().slice(0, 500) :
    "";
}

function headerValue(headers, key) {
  return safeHeaderValue(headers instanceof Map ? headers.get(key) : "");
}

function dateFromValue(value) {
  if (value instanceof Date && Number.isFinite(value.getTime())) return value;
  if (value != null && typeof value.toDate === "function") {
    const date = value.toDate();
    return date instanceof Date && Number.isFinite(date.getTime()) ? date : null;
  }
  return null;
}

function requirePassword(value) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error("Mailbox password is not configured.");
  }
  return value.trim();
}

function validateMailbox(mailbox) {
  if (mailbox == null || mailboxConfigs[mailbox.id] !== mailbox) {
    throw new Error("Unknown mailbox configuration.");
  }
}

function hashValue(value) {
  return createHash("sha256").update(String(value)).digest("hex");
}

function errorType(error) {
  if (error == null) return "unknown";
  if (typeof error.code === "string" && error.code.length > 0) {
    return error.code.slice(0, 80);
  }
  return error.constructor?.name?.slice(0, 80) || "Error";
}

function emptyResult(overrides = {}) {
  return {
    initialized: false,
    examined: 0,
    ignored: 0,
    skipped: 0,
    sent: 0,
    failed: 0,
    ...overrides,
  };
}

module.exports = {
  mailboxConfigs,
  parseHeaders,
  renderMailboxAutoReply,
  responseSubject,
  runMailboxAutoReplies,
  shouldAutoReply,
};
