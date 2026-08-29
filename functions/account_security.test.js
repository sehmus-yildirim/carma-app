const assert = require("node:assert/strict");
const test = require("node:test");

const {
  cleanupAccountData,
  cleanupCrossOwnerSocialData,
  cleanupVehicleEncounters,
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

test("account cleanup removes private MFA recovery data", async () => {
  const recursivelyDeleted = [];
  const firestore = fakeCleanupFirestore(recursivelyDeleted);
  const bucket = {
    async getFiles() {
      return [[], null, {}];
    },
  };

  await cleanupAccountData({
    firestore,
    bucket,
    userId: "user-1",
    now,
  });

  assert.deepEqual(recursivelyDeleted, [
    "mfa_recovery_requests/user-1",
    "public_profiles/user-1",
    "users/user-1",
  ]);
});

test("account cleanup removes or anonymizes cross-owner social data", async () => {
  const firestore = fakeIndexedFirestore({
    "users/owner/social_posts/post-1/likes/user-1": {
      userId: "user-1",
    },
    "users/owner/social_posts/post-1/comments/comment-1": {
      authorUserId: "user-1",
      authorDisplayName: "Private Name",
      authorPhotoUrl: "https://private.test/photo.jpg",
      text: "Mein Kommentar",
    },
    "users/owner/social_posts/post-1/comments/comment-2/replies/reply-1": {
      authorUserId: "user-1",
      text: "Meine Antwort",
    },
    "users/owner/social_posts/post-1/comments/comment-2/reactions/user-1": {
      userId: "user-1",
    },
    "users/owner/social_posts/post-1/comments/comment-2/reports/user-1": {
      reporterUserId: "user-1",
    },
    "reports/moderation-report": {reporterUserId: "user-1"},
  });

  await cleanupCrossOwnerSocialData({
    firestore,
    userId: "user-1",
    pseudonym: "deleted_hash",
    now,
  });

  assert.equal(
    firestore.documents.has(
      "users/owner/social_posts/post-1/likes/user-1",
    ),
    false,
  );
  assert.equal(
    firestore.documents.has(
      "users/owner/social_posts/post-1/comments/comment-2/reactions/user-1",
    ),
    false,
  );
  assert.equal(
    firestore.documents.has(
      "users/owner/social_posts/post-1/comments/comment-2/reports/user-1",
    ),
    false,
  );
  assert.equal(firestore.documents.has("reports/moderation-report"), true);
  const comment = firestore.documents.get(
    "users/owner/social_posts/post-1/comments/comment-1",
  );
  assert.equal(comment.authorUserId, "deleted_hash");
  assert.equal(comment.authorDisplayName, "Gelöschtes Konto");
  assert.equal(comment.text, "");
  assert.equal(comment.isDeleted, true);
});

test("account cleanup deletes both public encounter mirrors", async () => {
  const encounterPath = "vehicle_encounters/encounter-1";
  const initiatorMirror =
    "public_profiles/user-1/vehicles/vehicle-a/encounters/encounter-1";
  const recipientMirror =
    "public_profiles/user-2/vehicles/vehicle-b/encounters/encounter-1";
  const firestore = fakeIndexedFirestore({
    [encounterPath]: {
      participantUserIds: ["user-1", "user-2"],
      initiatorUserId: "user-1",
      initiatorVehicleId: "vehicle-a",
      recipientUserId: "user-2",
      recipientVehicleId: "vehicle-b",
    },
    [initiatorMirror]: {status: "confirmed"},
    [recipientMirror]: {status: "confirmed"},
  });

  await cleanupVehicleEncounters({firestore, userId: "user-1"});

  assert.equal(firestore.documents.has(encounterPath), false);
  assert.equal(firestore.documents.has(initiatorMirror), false);
  assert.equal(firestore.documents.has(recipientMirror), false);
});

function fakeCleanupFirestore(recursivelyDeleted) {
  const emptySnapshot = {docs: []};
  const query = {
    where() {
      return this;
    },
    async get() {
      return emptySnapshot;
    },
  };

  return {
    collection() {
      return query;
    },
    collectionGroup() {
      return query;
    },
    doc(path) {
      return {
        path,
        async get() {
          return {exists: false};
        },
      };
    },
    async recursiveDelete(reference) {
      recursivelyDeleted.push(reference.path);
    },
    batch() {
      return {
        delete() {},
        set() {},
        async commit() {},
      };
    },
  };
}

function fakeIndexedFirestore(initialDocuments) {
  const documents = new Map(Object.entries(initialDocuments));

  function reference(path) {
    return {path};
  }

  function queryFor(predicate) {
    let field;
    let operator;
    let expected;
    return {
      where(nextField, nextOperator, nextExpected) {
        field = nextField;
        operator = nextOperator;
        expected = nextExpected;
        return this;
      },
      async get() {
        const docs = [];
        for (const [path, data] of documents) {
          if (!predicate(path)) continue;
          const value = data[field];
          const matches = operator === "array-contains" ?
            Array.isArray(value) && value.includes(expected) :
            value === expected;
          if (matches) {
            docs.push({id: path.split("/").at(-1), ref: reference(path), data: () => data});
          }
        }
        return {docs};
      },
    };
  }

  return {
    documents,
    collection(name) {
      return queryFor((path) => {
        const parts = path.split("/");
        return parts.length === 2 && parts[0] === name;
      });
    },
    collectionGroup(name) {
      return queryFor((path) => {
        const parts = path.split("/");
        return parts.length >= 2 && parts.at(-2) === name;
      });
    },
    doc: reference,
    batch() {
      const mutations = [];
      return {
        delete(ref) {
          mutations.push(() => documents.delete(ref.path));
        },
        set(ref, data) {
          mutations.push(() => documents.set(ref.path, {
            ...(documents.get(ref.path) ?? {}),
            ...data,
          }));
        },
        async commit() {
          for (const mutation of mutations) mutation();
        },
      };
    },
  };
}

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
