const assert = require("node:assert/strict");
const test = require("node:test");

const {
  photoValue,
  profilePhotoUpdateFor,
} = require("./profile_photo_sync");

test("normalizes empty profile photos to null", () => {
  assert.equal(photoValue("  "), null);
  assert.equal(photoValue(" https://plaqa.de/profile.jpg "),
    "https://plaqa.de/profile.jpg");
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
