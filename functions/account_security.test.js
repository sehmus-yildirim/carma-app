const assert = require("node:assert/strict");
const test = require("node:test");

const {
  deleteStoragePrefixes,
  requestAccountDeletion,
  requireRecentAuthentication,
  revokeAccountSessions,
} = require("./account_security");

const now = new Date("2026-08-12T12:00:00.000Z");
const recentAuth = {
  uid: "user-1",
  token: {auth_time: Math.floor(now.getTime() / 1000) - 30},
};

test("rejects account deletion without recent authentication", () => {
  assert.throws(
    () => requireRecentAuthentication({
      uid: "user-1",
      token: {auth_time: Math.floor(now.getTime() / 1000) - 600},
    }, now),
    (error) => error.code === "failed-precondition" &&
      error.details.reason === "requires-recent-login",
  );
});

test("deletion is idempotent and deletes auth only after cleanup", async () => {
  const firestore = fakeFirestore();
  const order = [];
  const authAdmin = {
    async deleteUser(userId) {
      assert.equal(userId, "user-1");
      order.push("auth");
    },
  };
  const cleanup = async () => order.push("cleanup");

  const first = await requestAccountDeletion({
    firestore,
    authAdmin,
    bucket: {},
    authContext: recentAuth,
    input: {platform: "android", password: "must-not-be-stored"},
    now,
    cleanup,
  });
  const second = await requestAccountDeletion({
    firestore,
    authAdmin,
    bucket: {},
    authContext: recentAuth,
    input: {platform: "android"},
    now,
    cleanup,
  });

  assert.deepEqual(order, ["cleanup", "auth"]);
  assert.equal(first.status, "completed");
  assert.equal(second.status, "completed");
  assert.equal(second.alreadyRequested, true);
  const serializedWrites = JSON.stringify(firestore.writes);
  assert.equal(serializedWrites.includes("must-not-be-stored"), false);
  assert.equal(serializedWrites.includes("password"), false);
  assert.equal(serializedWrites.includes("token"), false);
});

test("failed cleanup never deletes the auth account", async () => {
  const firestore = fakeFirestore();
  let authDeletes = 0;

  await assert.rejects(
    requestAccountDeletion({
      firestore,
      authAdmin: {async deleteUser() { authDeletes += 1; }},
      bucket: {},
      authContext: recentAuth,
      input: {platform: "android"},
      now,
      cleanup: async () => {
        throw new Error("missing media is represented by a cleanup failure");
      },
      logger: {error() {}},
    }),
    (error) => error.code === "internal",
  );

  assert.equal(authDeletes, 0);
  assert.equal(
    firestore.documents.get("account_deletions/user-1").status,
    "failed",
  );
});

test("session revocation uses Firebase capability and records safe metadata", async () => {
  const firestore = fakeFirestore();
  const revoked = [];
  const result = await revokeAccountSessions({
    firestore,
    authAdmin: {
      async revokeRefreshTokens(userId) {
        revoked.push(userId);
      },
    },
    authContext: recentAuth,
    input: {platform: "android", ipAddress: "must-not-be-stored"},
    now,
  });

  assert.deepEqual(revoked, ["user-1"]);
  assert.deepEqual(result, {revoked: true, requiresLocalSignOut: true});
  const serializedWrites = JSON.stringify(firestore.writes);
  assert.equal(serializedWrites.includes("must-not-be-stored"), false);
  assert.equal(serializedWrites.includes("ipAddress"), false);
});

test("storage cleanup tolerates missing files and uses bounded pages", async () => {
  const deleted = [];
  let pages = 0;
  const bucket = {
    async getFiles(options) {
      pages += 1;
      assert.equal(options.maxResults, 100);
      return [[
        {delete: async () => deleted.push(`${options.prefix}a`)},
        {delete: async () => deleted.push(`${options.prefix}missing`)},
      ], null, {}];
    },
  };

  await deleteStoragePrefixes(bucket, ["profile_photos/user-1/"]);
  assert.equal(pages, 1);
  assert.equal(deleted.length, 2);
});

function fakeFirestore(initialDocuments = {}) {
  const documents = new Map(Object.entries(initialDocuments));
  const writes = [];

  function reference(path) {
    return {
      path,
      async get() {
        const data = documents.get(path);
        return {exists: data != null, data: () => data};
      },
      async set(data, options) {
        const current = options?.merge === true ? documents.get(path) ?? {} : {};
        documents.set(path, {...current, ...data});
        writes.push({path, data});
      },
      async delete() {
        documents.delete(path);
      },
    };
  }

  return {
    documents,
    writes,
    doc: reference,
    async runTransaction(callback) {
      return callback({
        get: (document) => document.get(),
        set(document, data, options) {
          const current = options?.merge === true ?
            documents.get(document.path) ?? {} : {};
          documents.set(document.path, {...current, ...data});
          writes.push({path: document.path, data});
        },
      });
    },
  };
}
