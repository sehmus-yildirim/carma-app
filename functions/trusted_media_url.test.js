const assert = require("node:assert/strict");
const test = require("node:test");

const {trustedProfilePhotoUrl} = require("./trusted_media_url");

function profilePhotoUrl(userId, query = "alt=media&token=test-token") {
  return "https://firebasestorage.googleapis.com/v0/b/" +
    "carma-a84e4.firebasestorage.app/o/" +
    `profile_photos%2F${userId}%2Fprofile.png?${query}`;
}

test("accepts only the owner-bound profile photo object", () => {
  assert.equal(
    trustedProfilePhotoUrl(profilePhotoUrl("user-a"), "user-a"),
    profilePhotoUrl("user-a"),
  );
  assert.equal(
    trustedProfilePhotoUrl(profilePhotoUrl("user-b"), "user-a"),
    null,
  );
});

test("rejects external hosts and malformed download queries", () => {
  assert.equal(
    trustedProfilePhotoUrl(
      "https://tracker.example/profile_photos%2Fuser-a%2Fprofile.png" +
        "?alt=media",
      "user-a",
    ),
    null,
  );
  assert.equal(
    trustedProfilePhotoUrl(profilePhotoUrl("user-a", "alt=mediaevil"), "user-a"),
    null,
  );
  assert.equal(
    trustedProfilePhotoUrl(
      profilePhotoUrl("user-a", "alt=media&redirect=https%3A%2F%2Fevil.test"),
      "user-a",
    ),
    null,
  );
  assert.equal(
    trustedProfilePhotoUrl(profilePhotoUrl("user-a", "alt=media&token="), "user-a"),
    null,
  );
});

test("rejects unsafe user identifiers before path matching", () => {
  assert.equal(trustedProfilePhotoUrl(profilePhotoUrl("user-a"), ".*"), null);
});
