const assert = require("node:assert/strict");
const test = require("node:test");

const {
  normalizeEmail,
  renderEmailChangeVerification,
  renderPasswordResetEmail,
  renderVerificationEmail,
  sendEmailChangeVerification,
  sendEmailVerification,
  sendPasswordResetEmail,
} = require("./branded_email");

test("branded auth templates keep links behind a visible action button", () => {
  const actionUrl = "https://auth.plaqa.de/auth/action?mode=verifyEmail&oobCode=abc";
  const templates = [
    renderVerificationEmail({actionUrl, displayName: "Plaqa Nutzer"}),
    renderPasswordResetEmail({actionUrl}),
    renderEmailChangeVerification({
      actionUrl,
      newEmail: "neu@example.com",
      displayName: "Plaqa Nutzer",
    }),
  ];

  for (const template of templates) {
    assert.match(template.html, /plaqa_logo_transparent\.png/);
    assert.match(template.html, /bgcolor="#000000"/);
    assert.match(template.html, /background:#000000 !important/);
    assert.match(template.html, /support@<\/span><span style="color:#0869ff;">pla/);
    assert.match(template.html, /<span style="color:#0869ff;">a<\/span><span style="color:#ffffff;">\.de<\/span><\/a><br>/);
    assert.match(template.html, /background:#0869ff/);
    assert.match(template.html, /href="https:\/\/auth\.plaqa\.de\/auth\/action/);
    assert.doesNotMatch(template.html, />https:\/\/auth\.plaqa\.de/);
    assert.match(template.text, /https:\/\/auth\.plaqa\.de\/auth\/action/);
    assert.doesNotMatch(template.html, /<script|tracking|pixel/i);
  }
});

test("email normalization rejects malformed and oversized addresses", () => {
  assert.equal(normalizeEmail(" Nutzer@Example.COM "), "nutzer@example.com");
  assert.equal(normalizeEmail("ungueltig"), "");
  assert.equal(normalizeEmail(`${"a".repeat(250)}@example.com`), "");
});

test("password reset does not reveal an unknown account", async () => {
  const transport = new FakeTransport();
  const result = await sendPasswordResetEmail({
    firestore: new FakeFirestore(),
    authAdmin: {
      async getUserByEmail() {
        const error = new Error("not found");
        error.code = "auth/user-not-found";
        throw error;
      },
    },
    transport,
    input: {email: "missing@example.com"},
    rawRequest: {ip: "127.0.0.1"},
    now: new Date("2026-08-25T12:00:00Z"),
  });

  assert.deepEqual(result, {accepted: true});
  assert.equal(transport.messages.length, 0);
});

test("verification email uses the authenticated account only", async () => {
  const transport = new FakeTransport();
  const result = await sendEmailVerification({
    firestore: new FakeFirestore(),
    authAdmin: {
      async getUser(userId) {
        assert.equal(userId, "user-1");
        return {
          email: "user@example.com",
          emailVerified: false,
          displayName: "Plaqa Nutzer",
        };
      },
      async generateEmailVerificationLink(email) {
        assert.equal(email, "user@example.com");
        return "https://auth.plaqa.de/auth/action?mode=verifyEmail&oobCode=abc";
      },
    },
    transport,
    authContext: {uid: "user-1", token: {auth_time: 1787659200}},
    now: new Date("2026-08-25T12:00:00Z"),
  });

  assert.deepEqual(result, {accepted: true, alreadyVerified: false});
  assert.equal(transport.messages.length, 1);
  assert.equal(transport.messages[0].to, "user@example.com");
  assert.match(transport.messages[0].subject, /Bestätige/);
});

test("email change sends the verification only to the new address", async () => {
  const transport = new FakeTransport();
  const result = await sendEmailChangeVerification({
    firestore: new FakeFirestore(),
    authAdmin: {
      async getUser(userId) {
        assert.equal(userId, "user-1");
        return {
          email: "alt@example.com",
          displayName: "Plaqa Nutzer",
        };
      },
      async generateVerifyAndChangeEmailLink(currentEmail, newEmail) {
        assert.equal(currentEmail, "alt@example.com");
        assert.equal(newEmail, "neu@example.com");
        return "https://auth.plaqa.de/auth/action?mode=verifyAndChangeEmail&oobCode=abc";
      },
    },
    transport,
    authContext: {
      uid: "user-1",
      token: {auth_time: Date.parse("2026-08-25T11:59:30Z") / 1000},
    },
    input: {newEmail: "neu@example.com"},
    now: new Date("2026-08-25T12:00:00Z"),
  });

  assert.deepEqual(result, {accepted: true});
  assert.equal(transport.messages.length, 1);
  assert.equal(transport.messages[0].to, "neu@example.com");
  assert.match(transport.messages[0].html, /neu@example\.com/);
});

test("password reset rate limit rejects an immediate repeated request", async () => {
  const firestore = new FakeFirestore();
  const transport = new FakeTransport();
  const authAdmin = {
    async getUserByEmail() {
      const error = new Error("not found");
      error.code = "auth/user-not-found";
      throw error;
    },
  };
  const request = {
    firestore,
    authAdmin,
    transport,
    input: {email: "missing@example.com"},
    rawRequest: {ip: "127.0.0.1"},
    now: new Date("2026-08-25T12:00:00Z"),
  };

  await sendPasswordResetEmail(request);
  await assert.rejects(
    sendPasswordResetEmail(request),
    (error) => error.code === "resource-exhausted" &&
      error.details?.reason === "too-many-requests",
  );
  assert.equal(transport.messages.length, 0);
});

test("email change requires a recent authenticated session", async () => {
  const transport = new FakeTransport();
  await assert.rejects(
    sendEmailChangeVerification({
      firestore: new FakeFirestore(),
      authAdmin: {},
      transport,
      authContext: {
        uid: "user-1",
        token: {auth_time: Date.parse("2026-08-25T11:50:00Z") / 1000},
      },
      input: {newEmail: "neu@example.com"},
      now: new Date("2026-08-25T12:00:00Z"),
    }),
    (error) => error.code === "failed-precondition" &&
      error.details?.reason === "requires-recent-login",
  );
  assert.equal(transport.messages.length, 0);
});

class FakeTransport {
  constructor() {
    this.messages = [];
  }

  async sendMail(message) {
    this.messages.push(message);
    return {messageId: "test-message"};
  }
}

class FakeFirestore {
  constructor() {
    this.documents = new Map();
  }

  collection(name) {
    return {
      doc: (id) => ({key: `${name}/${id}`}),
    };
  }

  async runTransaction(callback) {
    return callback({
      get: async (reference) => ({
        data: () => this.documents.get(reference.key),
      }),
      set: (reference, data) => {
        this.documents.set(reference.key, data);
      },
    });
  }
}
