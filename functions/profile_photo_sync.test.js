const assert = require("node:assert/strict");
const test = require("node:test");

const {
  displayNameValue,
  photoValue,
  profilePhotoUpdateFor,
  syncProfilePhotoReference,
} = require("./profile_photo_sync");

function snapshot(value) {
  return {exists: value != null, data: () => value};
}

function fakeTransactionFirestore(seed) {
  const documents = new Map(Object.entries(seed));
  return {
    documents,
    doc(path) {
      return {path, get: async () => snapshot(documents.get(path))};
    },
    async runTransaction(callback) {
      return callback({
        get: (reference) => reference.get(),
        update(reference, value) {
          if (!documents.has(reference.path)) {
            throw new Error("missing document");
          }
          documents.set(reference.path, {
            ...documents.get(reference.path),
            ...value,
          });
        },
      });
    },
  };
}

test("normalizes empty profile photos to null", () => {
  const trusted = "https://firebasestorage.googleapis.com/v0/b/" +
    "carma-a84e4.firebasestorage.app/o/" +
    "profile_photos%2Fuser-a%2Fprofile.png?alt=media&token=test-token";
  assert.equal(photoValue("  ", "user-a"), null);
  assert.equal(photoValue(` ${trusted} `, "user-a"), trusted);
  assert.equal(photoValue("https://tracker.example/profile.jpg", "user-a"), null);
  assert.equal(photoValue(trusted, "user-b"), null);
});

test("normalizes empty public display names", () => {
  assert.equal(displayNameValue("  "), "plaqa Nutzer");
  assert.equal(displayNameValue(" Sehmus Y. "), "Sehmus Y.");
});

test("updates the correct chat participant photo", () => {
  const update = profilePhotoUpdateFor({
    collection: "chats",
    data: {senderUserId: "user-a", receiverUserId: "user-b"},
    userId: "user-b",
    photoUrl: "photo-b",
  });

  assert.equal(update.receiverPhotoUrl, "photo-b");
  assert.equal(Object.hasOwn(update, "senderPhotoUrl"), false);
});

test("updates request, follow, story, encounter and plate references", () => {
  const cases = [
    ["contact_requests", {senderUserId: "user-a"}, "senderPhotoUrl"],
    ["follow_relationships", {followedUserId: "user-a"},
      "followedPhotoUrl"],
    ["chat_stories", {ownerUserId: "user-a"}, "ownerPhotoUrl"],
    ["vehicle_encounters", {initiatorUserId: "user-a"},
      "initiatorPhotoUrl"],
    ["plates", {ownerUserId: "user-a"}, "profilePhotoUrl"],
  ];

  for (const [collection, data, field] of cases) {
    const update = profilePhotoUpdateFor({
      collection,
      data,
      userId: "user-a",
      photoUrl: "photo-a",
    });
    assert.equal(update[field], "photo-a");
  }
});

test("ignores unrelated denormalized records", () => {
  const update = profilePhotoUpdateFor({
    collection: "chats",
    data: {senderUserId: "user-a", receiverUserId: "user-b"},
    userId: "user-c",
    photoUrl: "photo-c",
  });

  assert.equal(update, null);
});

test("updates social post like identity references", () => {
  const update = profilePhotoUpdateFor({
    collection: "social_post_likes",
    data: {userId: "user-a", postOwnerUserId: "post-owner"},
    userId: "user-a",
    photoUrl: "photo-a",
    displayName: "Sehmus Y.",
  });

  assert.equal(update.photoUrl, "photo-a");
  assert.equal(update.displayName, "Sehmus Y.");
});

test("updates social post comment identity references", () => {
  const update = profilePhotoUpdateFor({
    collection: "social_post_comments",
    data: {authorUserId: "user-a", postOwnerUserId: "post-owner"},
    userId: "user-a",
    photoUrl: null,
    displayName: "Sehmus Y.",
  });

  assert.equal(update.authorPhotoUrl, "");
  assert.equal(update.authorDisplayName, "Sehmus Y.");
});

test("transactional sync updates an existing projection", async () => {
  const firestore = fakeTransactionFirestore({
    "plates/plate-a": {ownerUserId: "user-a", profilePhotoUrl: null},
  });
  const updated = await syncProfilePhotoReference({
    firestore,
    deletionReference: firestore.doc("account_deletions/user-a"),
    collection: "plates",
    reference: firestore.doc("plates/plate-a"),
    userId: "user-a",
    photoUrl: "photo-a",
    displayName: "User A",
  });

  assert.equal(updated, true);
  assert.equal(
    firestore.documents.get("plates/plate-a").profilePhotoUrl,
    "photo-a",
  );
});

test("transactional sync stops after account deletion is reserved", async () => {
  const firestore = fakeTransactionFirestore({
    "account_deletions/user-a": {status: "processing"},
    "plates/plate-a": {ownerUserId: "user-a", profilePhotoUrl: null},
  });
  const updated = await syncProfilePhotoReference({
    firestore,
    deletionReference: firestore.doc("account_deletions/user-a"),
    collection: "plates",
    reference: firestore.doc("plates/plate-a"),
    userId: "user-a",
    photoUrl: "photo-a",
    displayName: "User A",
  });

  assert.equal(updated, false);
  assert.equal(
    firestore.documents.get("plates/plate-a").profilePhotoUrl,
    null,
  );
});

test("transactional sync never recreates a deleted projection", async () => {
  const firestore = fakeTransactionFirestore({});
  const updated = await syncProfilePhotoReference({
    firestore,
    deletionReference: firestore.doc("account_deletions/user-a"),
    collection: "plates",
    reference: firestore.doc("plates/plate-a"),
    userId: "user-a",
    photoUrl: "photo-a",
    displayName: "User A",
  });

  assert.equal(updated, false);
  assert.equal(firestore.documents.has("plates/plate-a"), false);
});
