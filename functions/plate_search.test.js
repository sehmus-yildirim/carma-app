const assert = require("node:assert/strict");
const test = require("node:test");

const {
  coarseLocationCell,
  maxPlateTargetSearchesPerWindow,
  searchPlateDocument,
} = require("./plate_search");

const now = new Date("2026-07-23T12:00:00.000Z");

function fakeFirestore(data, settings = null) {
  const documents = new Map();
  return {
    lastPath: null,
    paths: [],
    documents,
    doc(path) {
      this.lastPath = path;
      this.paths.push(path);
      return {
        path,
        async get() {
          if (path.startsWith("plate_search_")) {
            const stored = documents.get(path);
            return {exists: stored != null, data: () => stored};
          }
          if (path.includes("/settings/visibility")) {
            return {
              exists: settings != null,
              data: () => settings,
            };
          }
          if (path.startsWith("public_profiles/")) {
            return {
              exists: true,
              data: () => ({
                verificationStatus: data?.ownerIdentityVerified === true ?
                  "verified" : "unverified",
              }),
            };
          }
          return {
            exists: data != null,
            data: () => data,
          };
        },
      };
    },
    async runTransaction(callback) {
      return callback({
        get: (reference) => reference.get(),
        set(reference, value, options) {
          const current = options?.merge === true ?
            documents.get(reference.path) ?? {} : {};
          documents.set(reference.path, {...current, ...value});
        },
      });
    },
  };
}

function visibleSettings(overrides = {}) {
  return {
    profileVisibility: "contacts",
    plateSearchVisibility: "contacts",
    showVehicle: true,
    showRegion: true,
    showPlate: true,
    allowContactRequests: true,
    ...overrides,
  };
}

function validData(overrides = {}) {
  return {
    ownerUserId: "target-user",
    vehicleId: "vehicle-mercedes-gls",
    countryCode: "DE",
    plateKey: "FDRT2918",
    normalizedPlate: "FDRT2918",
    displayPlate: "FD-RT 2918",
    displayName: "Mara Beispiel",
    profilePhotoUrl: "https://example.test/profile.jpg",
    verificationStatus: "verified",
    isVerified: true,
    ownerIdentityVerified: true,
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
  const firestore = fakeFirestore(
    validData({privateEmail: "hidden@test"}),
    visibleSettings(),
  );

  const result = await searchPlateDocument({
    firestore,
    requesterUserId: "searching-user",
    input: validInput(),
    now,
  });

  assert.deepEqual(firestore.paths, [
    "plate_search_rate_limits/searching-user",
    firestore.paths[1],
    firestore.paths[2],
    "plates/DE_FDRT2918",
    "users/target-user/settings/visibility",
    "public_profiles/target-user",
  ]);
  assert.deepEqual(result, {
    found: true,
    targetUid: "target-user",
    displayName: "Mara Beispiel",
    profilePhotoUrl: "https://example.test/profile.jpg",
    isVerified: true,
    vehicleId: "vehicle-mercedes-gls",
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
  assert.equal(Object.hasOwn(result, "distanceKm"), false);
});

test("blocks repeated coordinate probes for the same plate", async () => {
  const firestore = fakeFirestore(validData(), visibleSettings());
  const request = {
    firestore,
    requesterUserId: "searching-user",
    input: validInput(),
    now,
  };

  assert.equal((await searchPlateDocument(request)).found, true);
  await assert.rejects(
    searchPlateDocument({
      ...request,
      input: validInput({latitude: 50.58, longitude: 9.71, radiusKm: 1}),
    }),
    (error) => error.code === "resource-exhausted",
  );
});

test("caps searches for one target across different accounts", async () => {
  const firestore = fakeFirestore(validData(), visibleSettings());
  for (let index = 0; index < maxPlateTargetSearchesPerWindow; index += 1) {
    const result = await searchPlateDocument({
      firestore,
      requesterUserId: `searching-user-${index}`,
      input: validInput(),
      now,
    });
    assert.equal(result.found, true);
  }

  await assert.rejects(
    searchPlateDocument({
      firestore,
      requesterUserId: "searching-user-over-limit",
      input: validInput(),
      now,
    }),
    (error) => error.code === "resource-exhausted",
  );
});

test("reduces stored coordinates to a coarse three-kilometre cell", () => {
  const first = coarseLocationCell(50.5558, 9.6808);
  const nearby = coarseLocationCell(50.5560, 9.6810);

  assert.deepEqual(first, nearby);
  assert.notEqual(first.latitude, 50.5558);
  assert.notEqual(first.longitude, 9.6808);
});

test("keeps missing photo and unverified status private and neutral", async () => {
  const result = await searchPlateDocument({
    firestore: fakeFirestore(
      validData({
        profilePhotoUrl: null,
        ownerIdentityVerified: false,
      }),
      visibleSettings(),
    ),
    requesterUserId: "searching-user",
    input: validInput(),
    now,
  });

  assert.equal(result.found, true);
  assert.equal(result.profilePhotoUrl, null);
  assert.equal(result.isVerified, false);
});

test("hides vehicle and plate fields when visibility settings disallow them", async () => {
  const result = await searchPlateDocument({
    firestore: fakeFirestore(
      validData(),
      visibleSettings({showVehicle: false, showPlate: false}),
    ),
    requesterUserId: "searching-user",
    input: validInput(),
    now,
  });

  assert.equal(result.found, true);
  assert.equal(result.displayPlate, null);
  assert.equal(result.region, null);
  assert.equal(result.letters, null);
  assert.equal(result.numbers, null);
  assert.equal(result.vehicleBrand, null);
  assert.equal(result.vehicleModel, null);
  assert.equal(result.vehicleColor, null);
  assert.equal(result.vehicleLabel, null);
});

test("does not reveal users who paused plate discovery in settings", async () => {
  const result = await searchPlateDocument({
    firestore: fakeFirestore(
      validData(),
      visibleSettings({plateSearchVisibility: "onlyMe"}),
    ),
    requesterUserId: "searching-user",
    input: validInput(),
    now,
  });

  assert.deepEqual(result, {found: false});
});

test("does not reveal users who disabled contact requests in settings", async () => {
  const result = await searchPlateDocument({
    firestore: fakeFirestore(
      validData(),
      visibleSettings({allowContactRequests: false}),
    ),
    requesterUserId: "searching-user",
    input: validInput(),
    now,
  });

  assert.deepEqual(result, {found: false});
});

for (const [name, data, requesterUserId] of [
  ["own plate", validData(), "target-user"],
  ["plate without vehicle identity", validData({vehicleId: null}), "searching-user"],
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
      firestore: fakeFirestore(data, visibleSettings()),
      requesterUserId,
      input: validInput(),
      now,
    });

    assert.deepEqual(result, {found: false});
  });
}
