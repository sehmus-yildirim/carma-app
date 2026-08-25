const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const {
  channelDefinitions,
  endpointForLocation,
  requestByteLength,
  responseMessageForStatus,
  submitContactPayload,
  validateChannelValues,
} = require("../hosting/contact-form.js");

const fixedNow = Date.parse("2026-08-25T18:00:00.000Z");
const startedAt = fixedNow - 30_000;

test("builds exact safe payloads for all four channels", () => {
  for (const [channel, values] of Object.entries(validValues())) {
    const result = validateChannelValues(channel, values, fixedNow);
    assert.equal(result.valid, true, `${channel} should be valid`);
    assert.deepEqual(
      Object.keys(result.payload).sort(),
      [...channelDefinitions[channel].fields].sort(),
    );
    assert.equal("recipient" in result.payload, false);
    assert.equal("to" in result.payload, false);
  }
});

test("normalizes strings, emails and line endings", () => {
  const result = validateChannelValues("support", {
    ...validValues().support,
    email: "  NUTZER@EXAMPLE.COM ",
    subject: "  Hilfe   beim Konto  ",
    message: "  Erste Zeile\r\nZweite Zeile mit weiteren Informationen.  ",
  }, fixedNow);
  assert.equal(result.valid, true);
  assert.equal(result.payload.email, "nutzer@example.com");
  assert.equal(result.payload.subject, "Hilfe beim Konto");
  assert.equal(
    result.payload.message,
    "Erste Zeile\nZweite Zeile mit weiteren Informationen.",
  );
});

test("rejects missing fields, invalid categories and invalid emails", () => {
  const cases = [
    ["support", {...validValues().support, subject: ""}, "subject"],
    ["support", {...validValues().support, category: "unknown"}, "category"],
    ["privacy", {...validValues().privacy, email: "ungueltig"}, "email"],
    ["partners", {...validValues().partners, name: "A"}, "name"],
    ["report", {...validValues().report, description: "zu kurz"}, "description"],
  ];
  for (const [channel, values, field] of cases) {
    const result = validateChannelValues(channel, values, fixedNow);
    assert.equal(result.valid, false);
    assert.equal(typeof result.errors[field], "string");
  }
});

test("rejects header injection, honeypot and implausible start times", () => {
  const injection = validateChannelValues("support", {
    ...validValues().support,
    subject: "Hilfe\r\nBcc: fremd@example.com",
  }, fixedNow);
  assert.equal(injection.valid, false);
  assert.ok(injection.errors.subject);

  const bot = validateChannelValues("support", {
    ...validValues().support,
    honeypot: "ausgefüllt",
  }, fixedNow);
  assert.equal(bot.valid, false);
  assert.ok(bot.errors._form);

  const tooFast = validateChannelValues("support", {
    ...validValues().support,
    startedAt: fixedNow,
  }, fixedNow);
  assert.equal(tooFast.valid, false);
  assert.ok(tooFast.errors._form);
});

test("enforces field and 16 KiB request limits", () => {
  const fieldLimit = validateChannelValues("support", {
    ...validValues().support,
    message: "x".repeat(5001),
  }, fixedNow);
  assert.equal(fieldLimit.valid, false);
  assert.ok(fieldLimit.errors.message);

  const payload = {
    channel: "support",
    message: "ä".repeat(9000),
  };
  assert.ok(requestByteLength(payload) > 16 * 1024);
});

test("report contact email remains optional", () => {
  const anonymous = validateChannelValues("report", validValues().report, fixedNow);
  assert.equal(anonymous.valid, true);
  assert.equal(anonymous.payload.contactEmail, "");

  const contactable = validateChannelValues("report", {
    ...validValues().report,
    contactEmail: "hinweis@example.com",
  }, fixedNow);
  assert.equal(contactable.valid, true);
  assert.equal(contactable.payload.contactEmail, "hinweis@example.com");
});

test("uses the emulator endpoint locally and no production endpoint", () => {
  assert.match(endpointForLocation({hostname: "127.0.0.1"}), /127\.0\.0\.1:5001/);
  assert.match(endpointForLocation({hostname: "localhost"}), /submitWebsiteContact$/);
  assert.equal(endpointForLocation({hostname: "plaqa.de"}), "");
});

test("submits JSON without adding recipients or browser metadata", async () => {
  let captured;
  const result = await submitContactPayload({
    endpoint: "http://127.0.0.1:5001/test",
    payload: {channel: "support", message: "Testnachricht"},
    fetchImpl: async (url, options) => {
      captured = {url, options};
      return {
        status: 202,
        json: async () => ({accepted: true, requestId: "request-test-123"}),
      };
    },
  });
  assert.equal(result.accepted, true);
  assert.equal(captured.options.method, "POST");
  assert.equal(captured.options.headers["Content-Type"], "application/json");
  const body = JSON.parse(captured.options.body);
  assert.deepEqual(body, {channel: "support", message: "Testnachricht"});
  assert.equal("recipient" in body, false);
});

test("maps public HTTP failures to German messages", () => {
  for (const status of [400, 403, 405, 413, 415, 429, 500, 503]) {
    assert.match(responseMessageForStatus(status), /[A-Za-zÄÖÜäöüß]/);
  }
  assert.equal(responseMessageForStatus(599), responseMessageForStatus(500));
});

test("all four pages contain accessible forms and visible email fallbacks", () => {
  const pages = {
    support: ["support/index.html", "support@plaqa.de"],
    privacy: ["datenschutz/index.html", "privacy@plaqa.de"],
    partners: ["partner/index.html", "partners@plaqa.de"],
    report: ["meldestelle/index.html", "support@plaqa.de"],
  };
  for (const [channel, [relativePath, fallback]] of Object.entries(pages)) {
    const html = readHostingFile(relativePath);
    assert.match(html, new RegExp(`data-contact-form="${channel}"`));
    assert.match(html, /aria-live="polite"/);
    assert.match(html, /name="honeypot"/);
    assert.match(html, /name="startedAt"/);
    assert.match(html, new RegExp(`mailto:${fallback.replace(".", "\\.")}`));
    assert.doesNotMatch(html, /type="file"/);
    assert.doesNotMatch(html, /name="(?:recipient|to)"/);
    assert.match(html, /contact-form\.css/);
    assert.match(html, /contact-form\.js/);
  }
});

test("report and privacy pages retain their required safety guidance", () => {
  const report = readHostingFile("meldestelle/index.html");
  assert.match(report, /Keine Notfallstelle/);
  assert.match(report, /Polizei/);
  assert.match(report, /nicht öffentlich angezeigt/);

  const privacy = readHostingFile("datenschutz/index.html");
  assert.match(privacy, /\/konto-loeschen\//);
  assert.match(privacy, /keine Ausweis- oder Verifizierungsdokumente/i);
});

test("browser module does not persist or log contact data", () => {
  const script = readHostingFile("contact-form.js");
  assert.doesNotMatch(script, /localStorage|sessionStorage/);
  assert.doesNotMatch(script, /console\.(?:log|info|warn|error)/);
  assert.doesNotMatch(script, /support@plaqa\.de|privacy@plaqa\.de|partners@plaqa\.de/);
});

function validValues() {
  return {
    support: {
      category: "technical_issue",
      email: "nutzer@example.com",
      subject: "Hilfe beim Öffnen des Chats",
      message: "Beim Öffnen des Chats erscheint eine unbekannte Fehlermeldung.",
      appVersion: "1.0.0",
      device: "Android",
      honeypot: "",
      startedAt,
    },
    privacy: {
      requestType: "access",
      email: "nutzer@example.com",
      message: "Ich möchte Auskunft über die zu meinem Konto gespeicherten Daten erhalten.",
      honeypot: "",
      startedAt,
    },
    partners: {
      name: "Plaqa Partner",
      organization: "Beispiel GmbH",
      email: "partner@example.com",
      partnershipType: "business",
      message: "Wir möchten eine mögliche geschäftliche Zusammenarbeit mit plaqa besprechen.",
      honeypot: "",
      startedAt,
    },
    report: {
      category: "content",
      reference: "Beitrag oder Profil",
      description: "Ich möchte einen problematischen Inhalt melden, der in der App sichtbar ist.",
      contactEmail: "",
      honeypot: "",
      startedAt,
    },
  };
}

function readHostingFile(relativePath) {
  return fs.readFileSync(path.join(__dirname, "..", "hosting", relativePath), "utf8");
}
