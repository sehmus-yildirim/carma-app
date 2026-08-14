const assert = require("node:assert/strict");
const test = require("node:test");

const {
  deactivateProfileVehicle,
  normalizeVehicleInput,
  saveProfileVehicle,
  setPrimaryProfileVehicle,
} = require("./profile_vehicle_management");

function fakeFirestore(initialDocuments = {}) {
  const documents = new Map(Object.entries(initialDocuments));
  const writes = [];

  function reference(documentPath) {
    return {
      path: documentPath,
      async get() {
        return snapshotFor(this);
      },
    };
  }

  function snapshotFor(document) {
    const value = documents.get(document.path);
    return {
      exists: value != null,
      data: () => value,
      ref: document,
    };
  }

  function setDocument(document, data, merge) {
    const previous = merge ? documents.get(document.path) ?? {} : {};
    documents.set(document.path, {...previous, ...data});
    writes.push({type: "set", path: document.path, data, merge});
  }

  return {
    documents,
    writes,
    doc: reference,
    async runTransaction(callback) {
      return callback({
        get: async (document) => snapshotFor(document),
        set(document, data, options) {
          setDocument(document, data, options?.merge === true);
        },
        delete(document) {
          documents.delete(document.path);
          writes.push({type: "delete", path: document.path});
        },
      });
    },
  };
}

function profileData(userId, overrides = {}) {
  return {
    uid: userId,
    firstName: "Mara",
    lastName: "Beispiel",
    displayName: "Mara B.",
    photoUrl: null,
    allowContactRequests: true,
    allowAnonymousReports: true,
    showVehicleOnPublicProfile: true,
    showPlateOnPublicProfile: true,
    verificationStatus: "unverified",
    ...overrides,
  };
}

function vehicleInput(overrides = {}) {
  return {
    vehicleId: "vehicle-1",
    brand: "Mercedes-Benz",
    model: "GLS",
    series: "X167",
    color: "Weiß",
    countryCode: "DE",
    plateRegion: "FD",
    plateLetters: "RT",
    plateNumbers: "2918",
    isPrimary: true,
    status: "active",
    useRelationship: "owner",
    vehicleType: "passengerCar",
    plateType: "standard",
    seasonStartMonth: null,
    seasonEndMonth: null,
    showOnPublicProfile: true,
    discoverableByPlate: true,
    selectableInStories: true,
    allowContactRequests: true,
    plateDisplayMode: "full",
    year: 2024,
    bodyStyle: "SUV",
    mileage: 12000,
    ...overrides,
  };
}

function storedVehicle(userId, overrides = {}) {
  const normalized = normalizeVehicleInput(userId, vehicleInput(overrides));
  const result = {
    ...normalized,
    isVerified: false,
    verificationStatus: "unverified",
    verificationLocked: false,
    verificationRejectionReason: null,
    createdAt: new Date("2026-08-01T08:00:00Z"),
    updatedAt: new Date("2026-08-01T08:00:00Z"),
  };
  delete result.displayPlate;
  delete result.plateKey;
  delete result.plateDocumentId;
  delete result.plateDisplayLabel;
  return result;
}

function plateData(userId, vehicle, overrides = {}) {
  return {
    ownerUserId: userId,
    vehicleId: vehicle.vehicleId,
    isPrimary: vehicle.isPrimary === true,
    countryCode: vehicle.countryCode,
    plateKey: `${vehicle.plateRegion}${vehicle.plateLetters}${vehicle.plateNumbers}`,
    normalizedPlate:
      `${vehicle.plateRegion}${vehicle.plateLetters}${vehicle.plateNumbers}`,
    region: vehicle.plateRegion,
    letters: vehicle.plateLetters,
    numbers: vehicle.plateNumbers,
    plateRegion: vehicle.plateRegion,
    plateLetters: vehicle.plateLetters,
    plateNumbers: vehicle.plateNumbers,
    displayPlate:
      `${vehicle.plateRegion}-${vehicle.plateLetters} ${vehicle.plateNumbers}`,
    isActive: true,
    isDeleted: false,
    createdAt: new Date("2026-08-01T08:00:00Z"),
    updatedAt: new Date("2026-08-01T08:00:00Z"),
    ...overrides,
  };
}

test("validates DACH plates, types and season data", () => {
  assert.equal(
    normalizeVehicleInput("user-1", vehicleInput()).plateDocumentId,
    "DE_FDRT2918",
  );
  assert.equal(
    normalizeVehicleInput("user-1", vehicleInput({
      countryCode: "CH",
      plateRegion: "ZH",
      plateLetters: "",
      plateNumbers: "123456",
    })).displayPlate,
    "ZH 123456",
  );
  assert.throws(() => normalizeVehicleInput("user-1", vehicleInput({
    plateType: "electric",
  })), /mit E enden/);
  assert.throws(() => normalizeVehicleInput("user-1", vehicleInput({
    plateType: "seasonal",
  })), /Saisonzeitraum/);
});

test("first save reserves the plate and stays idempotent", async () => {
  const userId = "user-first";
  const firestore = fakeFirestore({
    [`users/${userId}/profiles/main`]: profileData(userId),
    [`public_profiles/${userId}`]: {uid: userId},
  });
  const parameters = {
    firestore,
    authContext: {uid: userId},
    input: vehicleInput(),
    now: new Date("2026-08-14T08:00:00Z"),
  };

  const first = await saveProfileVehicle(parameters);
  const repeated = await saveProfileVehicle(parameters);

  assert.equal(first.vehicleId, "vehicle-1");
  assert.equal(first.isPrimary, true);
  assert.equal(repeated.vehicleId, "vehicle-1");
  assert.equal(firestore.documents.get(
    `users/${userId}/profiles/main`,
  ).primaryVehicleId, "vehicle-1");
  assert.equal(firestore.documents.get("plates/DE_FDRT2918").vehicleId,
    "vehicle-1");
  assert.equal([...firestore.documents.keys()].filter((path) =>
    path.endsWith("/timeline/vehicle_created")).length, 2);
});

test("an active plate cannot be claimed by another vehicle", async () => {
  const userId = "user-conflict";
  const existingVehicle = storedVehicle("other-user");
  const firestore = fakeFirestore({
    [`users/${userId}/profiles/main`]: profileData(userId),
    "plates/DE_FDRT2918": plateData("other-user", existingVehicle),
  });

  await assert.rejects(saveProfileVehicle({
    firestore,
    authContext: {uid: userId},
    input: vehicleInput(),
    now: new Date("2026-08-14T08:00:00Z"),
  }), /bereits einem aktiven Fahrzeug/);
  assert.equal(firestore.writes.length, 0);
});

test("primary switch updates private, public and both plate projections", async () => {
  const userId = "user-primary";
  const oldVehicle = storedVehicle(userId, {
    vehicleId: "vehicle-old",
    plateRegion: "HH",
    plateLetters: "CR",
    plateNumbers: "2026",
    isPrimary: true,
  });
  const nextVehicle = storedVehicle(userId, {
    vehicleId: "vehicle-next",
    plateRegion: "B",
    plateLetters: "PQ",
    plateNumbers: "1234",
    isPrimary: false,
  });
  const firestore = fakeFirestore({
    [`users/${userId}/profiles/main`]: profileData(userId, {
      primaryVehicleId: "vehicle-old",
    }),
    [`public_profiles/${userId}`]: {uid: userId},
    [`users/${userId}/vehicles/vehicle-old`]: oldVehicle,
    [`users/${userId}/vehicles/vehicle-next`]: nextVehicle,
    [`public_profiles/${userId}/vehicles/vehicle-old`]: oldVehicle,
    [`public_profiles/${userId}/vehicles/vehicle-next`]: nextVehicle,
    "plates/DE_HHCR2026": plateData(userId, oldVehicle, {isPrimary: true}),
    "plates/DE_BPQ1234": plateData(userId, nextVehicle, {isPrimary: false}),
  });

  await setPrimaryProfileVehicle({
    firestore,
    authContext: {uid: userId},
    input: {vehicleId: "vehicle-next"},
    now: new Date("2026-08-14T08:00:00Z"),
  });

  assert.equal(firestore.documents.get(
    `users/${userId}/profiles/main`,
  ).primaryVehicleId, "vehicle-next");
  assert.equal(firestore.documents.get(
    `users/${userId}/vehicles/vehicle-old`,
  ).isPrimary, false);
  assert.equal(firestore.documents.get(
    `users/${userId}/vehicles/vehicle-next`,
  ).isPrimary, true);
  assert.equal(firestore.documents.get("plates/DE_HHCR2026").isPrimary, false);
  assert.equal(firestore.documents.get("plates/DE_BPQ1234").isPrimary, true);
});

test("inactive vehicles cannot become or remain primary", async () => {
  const userId = "user-inactive";
  const inactive = storedVehicle(userId, {
    vehicleId: "vehicle-inactive",
    status: "sold",
    isPrimary: false,
  });
  const firestore = fakeFirestore({
    [`users/${userId}/profiles/main`]: profileData(userId, {
      primaryVehicleId: "vehicle-old",
    }),
    [`users/${userId}/vehicles/vehicle-inactive`]: inactive,
  });

  await assert.rejects(setPrimaryProfileVehicle({
    firestore,
    authContext: {uid: userId},
    input: {vehicleId: "vehicle-inactive"},
    now: new Date("2026-08-14T08:00:00Z"),
  }), /nicht als Hauptfahrzeug/);
  await assert.rejects(saveProfileVehicle({
    firestore,
    authContext: {uid: userId},
    input: vehicleInput({
      vehicleId: "vehicle-old",
      status: "sold",
      isPrimary: true,
    }),
    now: new Date("2026-08-14T08:00:00Z"),
  }), /anderes aktives Hauptfahrzeug/);
});

test("verified core changes expire verification atomically", async () => {
  const userId = "user-recheck";
  const existing = storedVehicle(userId, {
    isPrimary: true,
  });
  existing.isVerified = true;
  existing.verificationStatus = "verified";
  const firestore = fakeFirestore({
    [`users/${userId}/profiles/main`]: profileData(userId, {
      primaryVehicleId: "vehicle-1",
      verificationStatus: "verified",
    }),
    [`public_profiles/${userId}`]: {uid: userId},
    [`users/${userId}/vehicles/vehicle-1`]: existing,
    [`public_profiles/${userId}/vehicles/vehicle-1`]: existing,
    "plates/DE_FDRT2918": plateData(userId, existing),
    [`verification_requests/${userId}`]: {
      userId,
      vehicleId: "vehicle-1",
      status: "verified",
    },
  });

  const result = await saveProfileVehicle({
    firestore,
    authContext: {uid: userId},
    input: vehicleInput({color: "Schwarz"}),
    now: new Date("2026-08-14T08:00:00Z"),
  });

  assert.equal(result.verificationReset, true);
  assert.equal(firestore.documents.get(
    `users/${userId}/vehicles/vehicle-1`,
  ).verificationStatus, "evidenceMissing");
  assert.equal(firestore.documents.get(
    `users/${userId}/profiles/main`,
  ).verificationStatus, "unverified");
  assert.equal(firestore.documents.get(
    `verification_requests/${userId}`,
  ).status, "expired");
});

test("visibility-only changes preserve vehicle verification", async () => {
  const userId = "user-visibility";
  const existing = storedVehicle(userId, {isPrimary: true});
  existing.isVerified = true;
  existing.verificationStatus = "verified";
  const firestore = fakeFirestore({
    [`users/${userId}/profiles/main`]: profileData(userId, {
      primaryVehicleId: "vehicle-1",
      verificationStatus: "verified",
    }),
    [`public_profiles/${userId}`]: {uid: userId},
    [`users/${userId}/vehicles/vehicle-1`]: existing,
    [`public_profiles/${userId}/vehicles/vehicle-1`]: existing,
    "plates/DE_FDRT2918": plateData(userId, existing),
  });

  const result = await saveProfileVehicle({
    firestore,
    authContext: {uid: userId},
    input: vehicleInput({
      showOnPublicProfile: false,
      discoverableByPlate: false,
      plateDisplayMode: "hidden",
    }),
    now: new Date("2026-08-14T08:00:00Z"),
  });

  assert.equal(result.verificationReset, false);
  assert.equal(firestore.documents.get(
    `users/${userId}/vehicles/vehicle-1`,
  ).verificationStatus, "verified");
  assert.equal(firestore.documents.has(
    `public_profiles/${userId}/vehicles/vehicle-1`,
  ), false);
});

test("deactivation is soft, private and releases the exact plate", async () => {
  const userId = "user-archive";
  const primary = storedVehicle(userId, {
    vehicleId: "vehicle-primary",
    plateRegion: "HH",
    plateLetters: "AA",
    plateNumbers: "1",
    isPrimary: true,
  });
  const archived = storedVehicle(userId, {
    vehicleId: "vehicle-archive",
    plateRegion: "B",
    plateLetters: "CD",
    plateNumbers: "2",
    isPrimary: false,
  });
  const firestore = fakeFirestore({
    [`users/${userId}/profiles/main`]: profileData(userId, {
      primaryVehicleId: "vehicle-primary",
    }),
    [`users/${userId}/vehicles/vehicle-primary`]: primary,
    [`users/${userId}/vehicles/vehicle-archive`]: archived,
    [`public_profiles/${userId}/vehicles/vehicle-archive`]: archived,
    "plates/DE_BCD2": plateData(userId, archived),
  });

  await deactivateProfileVehicle({
    firestore,
    authContext: {uid: userId},
    input: {vehicleId: "vehicle-archive"},
    now: new Date("2026-08-14T08:00:00Z"),
  });

  const stored = firestore.documents.get(
    `users/${userId}/vehicles/vehicle-archive`,
  );
  assert.equal(stored.status, "archived");
  assert.equal(stored.showOnPublicProfile, false);
  assert.ok(stored.deactivatedAt instanceof Date);
  assert.equal(firestore.documents.has(
    `public_profiles/${userId}/vehicles/vehicle-archive`,
  ), false);
  assert.equal(firestore.documents.get("plates/DE_BCD2").isActive, false);
});
