const {createHash} = require("node:crypto");
const nodemailer = require("nodemailer");
const {HttpsError} = require("firebase-functions/v2/https");

const smtpHost = "smtp.ionos.de";
const smtpPort = 465;
const senderEmail = "no-reply@plaqa.de";
const supportEmail = "support@plaqa.de";
const logoUrl = "https://plaqa.de/assets/plaqa_logo_transparent.png";
const continueUrl = "https://plaqa.de/";
const rateLimitCollection = "_system_email_rate_limits";
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function createSmtpTransport(password) {
  const normalizedPassword = safeString(password);
  if (normalizedPassword.length === 0) {
    throw new Error("SMTP password is not configured.");
  }

  return nodemailer.createTransport({
    host: smtpHost,
    port: smtpPort,
    secure: true,
    auth: {
      user: senderEmail,
      pass: normalizedPassword,
    },
    connectionTimeout: 15000,
    greetingTimeout: 10000,
    socketTimeout: 20000,
    tls: {
      minVersion: "TLSv1.2",
    },
  });
}

async function sendPasswordResetEmail({
  firestore,
  authAdmin,
  transport,
  input,
  rawRequest,
  now = new Date(),
}) {
  const email = normalizeEmail(input?.email);
  if (email.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "Bitte gib eine gültige E-Mail-Adresse ein.",
      {reason: "invalid-email"},
    );
  }

  const clientAddress = safeClientAddress(rawRequest);
  await claimRateLimit({
    firestore,
    key: `password-reset-email:${email}`,
    now,
    maxAttempts: 4,
    windowMs: 60 * 60 * 1000,
    minimumIntervalMs: 60 * 1000,
  });
  await claimRateLimit({
    firestore,
    key: `password-reset-client:${clientAddress}`,
    now,
    maxAttempts: 12,
    windowMs: 60 * 60 * 1000,
    minimumIntervalMs: 10 * 1000,
  });

  let user;
  try {
    user = await authAdmin.getUserByEmail(email);
  } catch (error) {
    if (isAuthError(error, "auth/user-not-found")) {
      return {accepted: true};
    }
    throw emailServiceError(error);
  }

  if (user.disabled === true) {
    return {accepted: true};
  }

  try {
    const actionUrl = await authAdmin.generatePasswordResetLink(
      email,
      actionCodeSettings(),
    );
    const content = renderPasswordResetEmail({actionUrl});
    await sendTransactionalEmail({
      transport,
      to: email,
      subject: "Setze dein plaqa Passwort zurück",
      ...content,
    });
  } catch (error) {
    throw emailServiceError(error);
  }

  return {accepted: true};
}

async function sendEmailVerification({
  firestore,
  authAdmin,
  transport,
  authContext,
  now = new Date(),
}) {
  const userId = requireUserId(authContext);
  await claimRateLimit({
    firestore,
    key: `verify-email:${userId}`,
    now,
    maxAttempts: 5,
    windowMs: 60 * 60 * 1000,
    minimumIntervalMs: 60 * 1000,
  });

  let user;
  try {
    user = await authAdmin.getUser(userId);
  } catch (error) {
    throw emailServiceError(error);
  }

  const email = normalizeEmail(user.email);
  if (email.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Für dieses Konto ist keine E-Mail-Adresse hinterlegt.",
      {reason: "missing-email"},
    );
  }
  if (user.emailVerified === true) {
    return {accepted: true, alreadyVerified: true};
  }

  try {
    const actionUrl = await authAdmin.generateEmailVerificationLink(
      email,
      actionCodeSettings(),
    );
    const content = renderVerificationEmail({
      actionUrl,
      displayName: safeDisplayName(user.displayName),
    });
    await sendTransactionalEmail({
      transport,
      to: email,
      subject: "Bestätige deine E-Mail-Adresse für plaqa",
      ...content,
    });
  } catch (error) {
    throw emailServiceError(error);
  }

  return {accepted: true, alreadyVerified: false};
}

async function sendEmailChangeVerification({
  firestore,
  authAdmin,
  transport,
  authContext,
  input,
  now = new Date(),
}) {
  const userId = requireUserId(authContext);
  requireRecentAuthentication(authContext, now);
  const newEmail = normalizeEmail(input?.newEmail);
  if (newEmail.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "Bitte gib eine gültige neue E-Mail-Adresse ein.",
      {reason: "invalid-email"},
    );
  }

  await claimRateLimit({
    firestore,
    key: `change-email:${userId}`,
    now,
    maxAttempts: 4,
    windowMs: 60 * 60 * 1000,
    minimumIntervalMs: 60 * 1000,
  });

  let user;
  try {
    user = await authAdmin.getUser(userId);
  } catch (error) {
    throw emailServiceError(error);
  }
  const currentEmail = normalizeEmail(user.email);
  if (currentEmail.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Für dieses Konto ist keine E-Mail-Adresse hinterlegt.",
      {reason: "missing-email"},
    );
  }
  if (currentEmail === newEmail) {
    throw new HttpsError(
      "failed-precondition",
      "Die neue E-Mail-Adresse entspricht der bisherigen Adresse.",
      {reason: "email-unchanged"},
    );
  }

  try {
    const actionUrl = await authAdmin.generateVerifyAndChangeEmailLink(
      currentEmail,
      newEmail,
      actionCodeSettings(),
    );
    const content = renderEmailChangeVerification({
      actionUrl,
      newEmail,
      displayName: safeDisplayName(user.displayName),
    });
    await sendTransactionalEmail({
      transport,
      to: newEmail,
      subject: "Bestätige deine neue E-Mail-Adresse für plaqa",
      ...content,
    });
  } catch (error) {
    if (isAuthError(error, "auth/email-already-exists")) {
      throw new HttpsError(
        "already-exists",
        "Diese E-Mail-Adresse wird bereits verwendet.",
        {reason: "email-already-in-use"},
      );
    }
    throw emailServiceError(error);
  }

  return {accepted: true};
}

async function claimRateLimit({
  firestore,
  key,
  now,
  maxAttempts,
  windowMs,
  minimumIntervalMs,
}) {
  const nowMs = now.getTime();
  const reference = firestore.collection(rateLimitCollection).doc(
    createHash("sha256").update(key).digest("hex"),
  );

  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.data() ?? {};
    const windowStartedAt = valueToMillis(data.windowStartedAt);
    const lastAttemptAt = valueToMillis(data.lastAttemptAt);
    const isActiveWindow = windowStartedAt != null &&
      nowMs - windowStartedAt < windowMs;
    const count = isActiveWindow && Number.isInteger(data.attemptCount) ?
      data.attemptCount :
      0;

    if (lastAttemptAt != null &&
        nowMs - lastAttemptAt < minimumIntervalMs) {
      throw tooManyEmailRequests();
    }
    if (count >= maxAttempts) {
      throw tooManyEmailRequests();
    }

    transaction.set(reference, {
      attemptCount: count + 1,
      windowStartedAt: new Date(isActiveWindow ? windowStartedAt : nowMs),
      lastAttemptAt: new Date(nowMs),
      expiresAt: new Date(nowMs + Math.max(windowMs * 2, 24 * 60 * 60 * 1000)),
    }, {merge: false});
  });
}

function renderVerificationEmail({actionUrl, displayName}) {
  return renderBrandedEmail({
    preheader: "Bestätige deine E-Mail-Adresse und schütze dein plaqa Konto.",
    eyebrow: "Konto schützen",
    title: "E-Mail-Adresse bestätigen",
    greeting: greetingFor(displayName),
    paragraphs: [
      "bestätige bitte deine E-Mail-Adresse, damit dein plaqa Konto vollständig eingerichtet und geschützt ist.",
    ],
    buttonLabel: "E-Mail-Adresse bestätigen",
    buttonUrl: actionUrl,
    notice: "Du hast kein plaqa Konto erstellt? Dann kannst du diese E-Mail ignorieren. Der Link ist nur für dein Konto bestimmt.",
  });
}

function renderPasswordResetEmail({actionUrl}) {
  return renderBrandedEmail({
    preheader: "Lege ein neues Passwort für dein plaqa Konto fest.",
    eyebrow: "Kontosicherheit",
    title: "Passwort zurücksetzen",
    greeting: "Hallo,",
    paragraphs: [
      "du hast angefordert, das Passwort für dein plaqa Konto zurückzusetzen. Über den Button kannst du jetzt ein neues Passwort festlegen.",
    ],
    buttonLabel: "Neues Passwort festlegen",
    buttonUrl: actionUrl,
    notice: "Du hast das nicht angefordert? Dann ignoriere diese E-Mail. Dein bisheriges Passwort bleibt unverändert.",
  });
}

function renderEmailChangeVerification({actionUrl, newEmail, displayName}) {
  return renderBrandedEmail({
    preheader: "Bestätige die neue E-Mail-Adresse für dein plaqa Konto.",
    eyebrow: "Sicherheitshinweis",
    title: "Neue E-Mail-Adresse bestätigen",
    greeting: greetingFor(displayName),
    paragraphs: [
      "für dein plaqa Konto wurde eine neue E-Mail-Adresse hinterlegt. Bestätige die Änderung über den folgenden Button.",
      `Neue Adresse: ${newEmail}`,
    ],
    buttonLabel: "E-Mail-Adresse bestätigen",
    buttonUrl: actionUrl,
    notice: "Du hast diese Änderung nicht veranlasst? Bestätige sie nicht und wende dich direkt an den plaqa Support.",
  });
}

function renderBrandedEmail({
  preheader,
  eyebrow,
  title,
  greeting,
  paragraphs,
  buttonLabel,
  buttonUrl,
  notice,
  contactEmail = supportEmail,
  footerLabel = "Automatische Nachricht von plaqa. Hilfe erhältst du unter",
  footerLinks = [
    {label: "Datenschutz", url: "https://plaqa.de/datenschutz/"},
    {label: "Impressum", url: "https://plaqa.de/impressum/"},
  ],
  signatureLines = [],
}) {
  const normalizedContactEmail = normalizeEmail(contactEmail) || supportEmail;
  const escapedUrl = escapeHtml(buttonUrl);
  const paragraphHtml = paragraphs.map((paragraph) =>
    `<p style="margin:0 0 16px;color:#aeb9c9;font-size:16px;line-height:1.65;">${escapeHtml(paragraph)}</p>`,
  ).join("");
  const signatureHtml = signatureLines.length === 0 ? "" :
    `<p style="margin:2px 0 24px;color:#dce4f0;font-size:16px;line-height:1.55;">${signatureLines.map((line, index) => `${index > 0 ? "<br>" : ""}${escapeHtml(line)}`).join("")}</p>`;
  const footerLinksHtml = footerLinks.map(({label, url}) =>
    `<a href="${escapeHtml(url)}" style="color:#8794a8;text-decoration:underline;">${escapeHtml(label)}</a>`,
  ).join("&nbsp;&nbsp;·&nbsp;&nbsp;");
  const html = `<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="color-scheme" content="dark">
  <meta name="supported-color-schemes" content="dark">
  <title>${escapeHtml(title)}</title>
</head>
<body bgcolor="#000000" style="margin:0;padding:0;background:#000000 !important;color:#f7f9fc;font-family:Arial,Helvetica,sans-serif;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">${escapeHtml(preheader)}</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" bgcolor="#000000" style="width:100%;background:#000000 !important;">
    <tr><td align="center" bgcolor="#000000" style="padding:28px 14px;background:#000000 !important;">
      <table role="presentation" width="600" cellspacing="0" cellpadding="0" border="0" bgcolor="#000000" style="width:100%;max-width:600px;background:#000000 !important;border:1px solid #13223a;border-radius:8px;overflow:hidden;">
        <tr><td style="height:4px;background:#0869ff;font-size:0;line-height:0;">&nbsp;</td></tr>
        <tr><td bgcolor="#000000" style="padding:26px 34px 22px;background:#000000 !important;"><img src="${logoUrl}" width="168" alt="plaqa" style="display:block;width:168px;max-width:50%;height:auto;border:0;"></td></tr>
        <tr><td bgcolor="#000000" style="padding:0 34px 34px;background:#000000 !important;">
          <p style="margin:0 0 14px;color:#6da6ff;font-size:12px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;">${escapeHtml(eyebrow)}</p>
          <h1 style="margin:0 0 18px;color:#ffffff;font-size:30px;line-height:1.2;font-weight:700;letter-spacing:0;">${escapeHtml(title)}</h1>
          <p style="margin:0 0 12px;color:#dce4f0;font-size:16px;line-height:1.65;">${escapeHtml(greeting)}</p>
          ${paragraphHtml}
          ${signatureHtml}
          <table role="presentation" cellspacing="0" cellpadding="0" border="0"><tr><td bgcolor="#0869ff" style="border-radius:6px;"><a href="${escapedUrl}" style="display:inline-block;padding:14px 22px;color:#ffffff;text-decoration:none;font-size:16px;font-weight:700;line-height:1;">${escapeHtml(buttonLabel)}</a></td></tr></table>
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" bgcolor="#000000" style="margin-top:26px;background:#000000 !important;border:1px solid #13223a;border-left:3px solid #ff6a1a;border-radius:4px;"><tr><td bgcolor="#000000" style="padding:14px 16px;background:#000000 !important;color:#c1cada;font-size:14px;line-height:1.55;">${escapeHtml(notice)}</td></tr></table>
        </td></tr>
        <tr><td bgcolor="#000000" style="padding:20px 34px 26px;background:#000000 !important;border-top:1px solid #13223a;color:#8794a8;font-size:12px;line-height:1.6;">${escapeHtml(footerLabel)} <a href="mailto:${normalizedContactEmail}" style="text-decoration:none;">${brandedEmailAddressHtml(normalizedContactEmail)}</a><br>${footerLinksHtml}</td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;

  const text = [
    title,
    "",
    greeting,
    "",
    ...paragraphs,
    "",
    ...signatureLines,
    ...(signatureLines.length > 0 ? [""] : []),
    `${buttonLabel}: ${buttonUrl}`,
    "",
    notice,
    "",
    `${footerLabel} ${normalizedContactEmail}`,
    ...footerLinks.map(({label, url}) => `${label}: ${url}`),
  ].join("\n");

  return {html, text};
}

function brandedEmailAddressHtml(email) {
  const normalizedEmail = normalizeEmail(email) || supportEmail;
  const atIndex = normalizedEmail.lastIndexOf("@");
  const localPart = normalizedEmail.slice(0, atIndex + 1);
  const domain = normalizedEmail.slice(atIndex + 1);
  if (domain !== "plaqa.de") {
    return `<span style="color:#ffffff;">${escapeHtml(normalizedEmail)}</span>`;
  }
  return [
    `<span style="color:#ffffff;">${escapeHtml(localPart)}</span>`,
    '<span style="color:#0869ff;">pla</span>',
    '<span style="color:#ff6a1a;">q</span>',
    '<span style="color:#0869ff;">a</span>',
    '<span style="color:#ffffff;">.de</span>',
  ].join("");
}

async function sendTransactionalEmail({transport, to, subject, html, text}) {
  await transport.sendMail({
    from: `"plaqa" <${senderEmail}>`,
    to,
    replyTo: supportEmail,
    subject,
    html,
    text,
  });
}

function actionCodeSettings() {
  return {
    url: continueUrl,
    handleCodeInApp: false,
  };
}

function requireUserId(authContext) {
  const userId = safeString(authContext?.uid);
  if (userId.length === 0) {
    throw new HttpsError(
      "unauthenticated",
      "Bitte melde dich neu an.",
      {reason: "missing-user"},
    );
  }
  return userId;
}

function requireRecentAuthentication(authContext, now) {
  const authTimeSeconds = Number(authContext?.token?.auth_time);
  if (!Number.isFinite(authTimeSeconds) ||
      now.getTime() - authTimeSeconds * 1000 > 5 * 60 * 1000) {
    throw new HttpsError(
      "failed-precondition",
      "Bitte bestätige deine Anmeldung erneut.",
      {reason: "requires-recent-login"},
    );
  }
}

function normalizeEmail(value) {
  const email = safeString(value).toLowerCase();
  return email.length <= 254 && emailPattern.test(email) ? email : "";
}

function safeDisplayName(value) {
  return safeString(value).replace(/[\u0000-\u001f\u007f]/g, " ")
    .replace(/\s+/g, " ").slice(0, 80).trim();
}

function greetingFor(displayName) {
  return displayName.length === 0 ? "Hallo," : `Hallo ${displayName},`;
}

function safeClientAddress(rawRequest) {
  const address = safeString(rawRequest?.ip);
  return address.length === 0 ? "unknown" : address.slice(0, 128);
}

function valueToMillis(value) {
  if (value instanceof Date) return value.getTime();
  if (value != null && typeof value.toMillis === "function") {
    return value.toMillis();
  }
  return null;
}

function tooManyEmailRequests() {
  return new HttpsError(
    "resource-exhausted",
    "Zu viele E-Mail-Anfragen. Bitte versuche es später erneut.",
    {reason: "too-many-requests"},
  );
}

function emailServiceError(error) {
  if (error instanceof HttpsError) return error;
  return new HttpsError(
    "unavailable",
    "Die E-Mail konnte gerade nicht gesendet werden.",
    {reason: "email-service-unavailable"},
  );
}

function isAuthError(error, code) {
  return safeString(error?.code) === code;
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

module.exports = {
  createSmtpTransport,
  normalizeEmail,
  renderBrandedEmail,
  renderEmailChangeVerification,
  renderPasswordResetEmail,
  renderVerificationEmail,
  sendEmailChangeVerification,
  sendEmailVerification,
  sendPasswordResetEmail,
};
