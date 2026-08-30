const test = require("node:test");
const assert = require("node:assert/strict");
const {
  assuranceLevel,
  isEffectiveIdentityVerification,
  isEffectiveVehicleVerification,
  usesVerificationV1,
  verificationMethod,
} = require("./verification_v1_policy");

const identity = {
  status: "verified",
  documentExpiresAt: "2026-08-30",
  verificationMethod,
  assuranceLevel,
  identityVersion: "identity-version-1",
};

const verification = {
  status: "verified",
  plateNormalized: "HHAB123",
  verificationMethod,
  assuranceLevel,
  identityVersion: "identity-version-1",
};

const vehicle = {
  ownerUserId: "user-1",
  countryCode: "DE",
  plateRegion: "HH",
  plateLetters: "AB",
  plateNumbers: "123",
  status: "active",
};

test("identity remains effective through its expiry date", () => {
  assert.equal(
    isEffectiveIdentityVerification(identity, new Date("2026-08-30T23:59:59Z")),
    true,
  );
  assert.equal(
    isEffectiveIdentityVerification(identity, new Date("2026-08-31T00:00:00Z")),
    false,
  );
});

test("identity rejects stale status and foreign assurance metadata", () => {
  assert.equal(isEffectiveIdentityVerification({...identity, status: "expired"}), false);
  assert.equal(
    isEffectiveIdentityVerification({...identity, assuranceLevel: "document_authenticity"}),
    false,
  );
  assert.equal(
    isEffectiveIdentityVerification({...identity, verificationMethod: "cloud_ocr"}),
    false,
  );
});

test("vehicle requires current identity, exact plate and V1 metadata", () => {
  const now = new Date("2026-08-30T12:00:00Z");
  assert.equal(isEffectiveVehicleVerification({identity, verification, vehicle, now}), true);
  assert.equal(isEffectiveVehicleVerification({
    identity,
    verification: {...verification, plateNormalized: "HHAB124"},
    vehicle,
    now,
  }), false);
  assert.equal(isEffectiveVehicleVerification({
    identity: {...identity, documentExpiresAt: "2026-08-29"},
    verification,
    vehicle,
    now,
  }), false);
  assert.equal(isEffectiveVehicleVerification({
    identity,
    verification: {...verification, identityVersion: "identity-version-0"},
    vehicle,
    now,
  }), false);
});

test("inactive and no-longer-owned vehicles cannot authorize protected actions", () => {
  for (const status of ["sold", "deregistered", "noLongerOwned", "deleted"]) {
    assert.equal(isEffectiveVehicleVerification({
      identity,
      verification,
      vehicle: {...vehicle, status},
    }), false, status);
  }
  assert.equal(isEffectiveVehicleVerification({
    identity,
    verification,
    vehicle: {...vehicle, isDeleted: true},
  }), false);
});

test("V1 presence is authoritative even when one side is missing", () => {
  assert.equal(usesVerificationV1(null, null), false);
  assert.equal(usesVerificationV1(identity, null), true);
  assert.equal(usesVerificationV1(null, verification), true);
});
