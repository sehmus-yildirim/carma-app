const assert = require("node:assert/strict");
const test = require("node:test");

const {searchPlateDocument} = require("./plate_search");

const now = new Date("2026-07-23T12:00:00.000Z");

function fakeFirestore(data) {
  return {
    lastPath: null,
    doc(path) {
      this.lastPath = path;
      return {
        async get() {
          return {
            exists: data != null,
            data: () => data,
          };
        },
      };
    },
  };
}

function validData(overrides = {}) {
  return {
    ownerUserId: "target-user",
    countryCode: "DE",
    plateKey: "FDRT2918",
    normalizedPlate: "FDRT2918",
    displayPlate: "FD-RT 2918",
    displayName: "Mara Beispiel",
    profilePhotoUrl: "https://example.test/profile.jpg",
    verificationStatus: "verified",
    vehicleBrand: "Mercedes-Benz",
    vehicleModel: "GLS",
    vehicleColor: "Weiß",
    vehicleLabel: "Mercedes-Benz GLS",
    allowContactRequests: true,
    isActive: true,
    isDeleted: false,
    latitude: 50.5558,
    longitude: 9.6808,
    locationUpdatedAt: {
      toDate: () => new Date("2026-07-23T11:30:00.000Z"),
    },
    ...overrides,
  };
}

function validInput(overrides = {}) {
  return {
    countryCode: "DE",
    plate: "FD-RT 2918",
    region: "FD",
    letters: "RT",
    numbers: "2918",
    latitude: 50.5558,
    longitude: 9.6808,
    radiusKm: 5,
    ...overrides,
  };
}

test("returns only the dynamic public hit fields", async () => {
  const firestore = fakeFirestore(validData({privateEmail: "hidden@test"}));

  const result = await searchPlateDocument({
    firestore,
    requesterUserId: "searching-user",
    input: validInput(),
    now,
  });

  assert.equal(firestore.lastPath, "plates/DE_FDRT2918");
  assert.deepEqual(result, {
    found: true,
    targetUid: "target-user",
    displayName: "Mara Beispiel",
    profilePhotoUrl: "https://example.test/profile.jpg",
    isVerified: true,
    distanceKm: 0,
    plateKey: "FDRT2918",
    displayPlate: "FD-RT 2918",
    countryCode: "DE",
    region: "FD",
    letters: "RT",
    numbers: "2918",
    vehicleBrand: "Mercedes-Benz",
    vehicleModel: "GLS",
    vehicleColor: "Weiß",
    vehicleLabel: "Mercedes-Benz GLS",
  });
  assert.equal(Object.hasOwn(result, "privateEmail"), false);
});

test("keeps missing photo and unverified status private and neutral", async () => {
  const result = await searchPlateDocument({
    firestore: fakeFirestore(validData({
      profilePhotoUrl: null,
      verificationStatus: "pending",
    })),
    requesterUserId: "searching-user",
    input: validInput(),
    now,
  });

  assert.equal(result.found, true);
  assert.equal(result.profilePhotoUrl, null);
  assert.equal(result.isVerified, false);
});

for (const [name, data, requesterUserId] of [
  ["own plate", validData(), "target-user"],
  ["inactive plate", validData({isActive: false}), "searching-user"],
  ["deleted plate", validData({isDeleted: true}), "searching-user"],
  [
    "plate without explicit deletion state",
    validData({isDeleted: undefined}),
    "searching-user",
  ],
  [
    "disabled contact requests",
    validData({allowContactRequests: false}),
    "searching-user",
  ],
  [
    "stale location",
    validData({
      locationUpdatedAt: {
        toDate: () => new Date("2026-07-23T10:59:59.000Z"),
      },
    }),
    "searching-user",
  ],
  [
    "outside radius",
    validData({latitude: 50.7, longitude: 9.9}),
    "searching-user",
  ],
]) {
  test(`does not reveal ${name}`, async () => {
    const result = await searchPlateDocument({
      firestore: fakeFirestore(data),
      requesterUserId,
      input: validInput(),
      now,
    });

    assert.deepEqual(result, {found: false});
  });
}
