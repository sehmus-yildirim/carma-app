const assert = require("node:assert/strict");
const test = require("node:test");

const {
  maxProfileViewsPerWindow,
  recordProfileViewTransaction,
} = require("./profile_view");

const now = new Date("2026-08-29T10:00:00.000Z");

function snapshot(value) {
  return {exists: value != null, data: () => value};
}

function fakeFirestore(seed) {
  const documents = new Map(Object.entries(seed));
  return {
    documents,
    doc(path) {
      return {path, get: async () => snapshot(documents.get(path))};
    },
    async runTransaction(callback) {
      return callback({
        get: (reference) => reference.get(),
        set(reference, value) {
          documents.set(reference.path, value);
        },
        update(reference, value) {
          documents.set(reference.path, {
            ...documents.get(reference.path),
            ...value,
          });
        },
      });
    },
  };
}

function validSeed() {
  return {
    "public_profiles/target-user": {
      profileAccessEnabled: true,
      profileViewCount: 4,
    },
    "profile_connections/viewer-user_target-user": {
      status: "active",
      participants: ["viewer-user", "target-user"],
      requestId: "request-1",
      chatId: "chat-1",
    },
    "contact_requests/request-1": {status: "accepted"},
    "chats/chat-1": {
      status: "active",
      requestId: "request-1",
      participants: ["viewer-user", "target-user"],
      deletedBy: {"viewer-user": false, "target-user": false},
    },
  };
}

test("counts one authorized profile view per viewer and day", async () => {
  const firestore = fakeFirestore(validSeed());
  const first = await recordProfileViewTransaction({
    firestore,
    viewerUserId: "viewer-user",
    profileUserId: "target-user",
    now,
  });
  const second = await recordProfileViewTransaction({
    firestore,
    viewerUserId: "viewer-user",
    profileUserId: "target-user",
    now: new Date(now.getTime() + 60_000),
  });
  assert.equal(first.recorded, true);
  assert.equal(second.recorded, false);
  assert.equal(
    firestore.documents.get("public_profiles/target-user").profileViewCount,
    5,
  );
});

test("rejects viewers without a live accepted connection", async () => {
  const seed = validSeed();
  delete seed["profile_connections/viewer-user_target-user"];
  await assert.rejects(
    recordProfileViewTransaction({
      firestore: fakeFirestore(seed),
      viewerUserId: "viewer-user",
      profileUserId: "target-user",
      now,
    }),
    (error) => error.code === "permission-denied",
  );
});

test("rejects views while the target account is being deleted", async () => {
  const seed = validSeed();
  seed["account_deletions/target-user"] = {status: "requested"};
  await assert.rejects(
    recordProfileViewTransaction({
      firestore: fakeFirestore(seed),
      viewerUserId: "viewer-user",
      profileUserId: "target-user",
      now,
    }),
    (error) => error.code === "not-found",
  );
});

test("rejects views while the viewer account is being deleted", async () => {
  const seed = validSeed();
  seed["account_deletions/viewer-user"] = {status: "processing"};
  await assert.rejects(
    recordProfileViewTransaction({
      firestore: fakeFirestore(seed),
      viewerUserId: "viewer-user",
      profileUserId: "target-user",
      now,
    }),
    (error) => error.code === "not-found",
  );
});

test("rejects a deleted chat relationship", async () => {
  const seed = validSeed();
  seed["chats/chat-1"].deletedBy["target-user"] = true;
  await assert.rejects(
    recordProfileViewTransaction({
      firestore: fakeFirestore(seed),
      viewerUserId: "viewer-user",
      profileUserId: "target-user",
      now,
    }),
    (error) => error.code === "permission-denied",
  );
});

test("enforces the daily profile-view quota", async () => {
  const firestore = fakeFirestore(validSeed());
  const first = await recordProfileViewTransaction({
    firestore,
    viewerUserId: "viewer-user",
    profileUserId: "target-user",
    now,
  });
  assert.equal(first.recorded, true);
  const eventKey = [...firestore.documents.keys()].find((key) =>
    key.startsWith("profile_view_events/"));
  const limitKey = [...firestore.documents.keys()].find((key) =>
    key.startsWith("profile_view_rate_limits/"));
  firestore.documents.delete(eventKey);
  firestore.documents.set(limitKey, {
    ...firestore.documents.get(limitKey),
    viewCount: maxProfileViewsPerWindow,
  });
  await assert.rejects(
    recordProfileViewTransaction({
      firestore,
      viewerUserId: "viewer-user",
      profileUserId: "target-user",
      now: new Date(now.getTime() + 60_000),
    }),
    (error) => error.code === "resource-exhausted",
  );
});
