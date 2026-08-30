const assert = require("node:assert/strict");
const test = require("node:test");

const {
  deactivateProfileVehicle,
  normalizeVehicleInput,
  saveProfileVehicle,
  setPrimaryProfileVehicle,
  syncProfileVisibilityReferences,
  updatePrimaryVehicleLocation,
  vehicleHeroAppearanceChanged,
  verificationCoreChanged,
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

  function collectionReference(collectionPath) {
    return {
      path: collectionPath,
      isCollection: true,
      async get() {
        return collectionSnapshotFor(this);
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

  function collectionSnapshotFor(collection) {
    const prefix = `${collection.path}/`;
    const docs = [...documents.entries()]
      .filter(([path]) => {
        if (!path.startsWith(prefix)) return false;
        return !path.slice(prefix.length).includes("/");
      })
      .map(([path, value]) => {
        const ref = reference(path);
        return {
          id: path.slice(prefix.length),
          exists: true,
          data: () => value,
          ref,
        };
      });
    return {docs, empty: docs.length === 0, size: docs.length};
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
    collection: collectionReference,
    batch() {
      const operations = [];
      return {
        set(document, data, options) {
          operations.push({
            type: "set",
            document,
            data,
            merge: options?.merge === true,
          });
        },
        delete(document) {
          operations.push({type: "delete", document});
        },
        async commit() {
          for (const operation of operations) {
            if (operation.type === "set") {
              setDocument(
                operation.document,
                operation.data,
                operation.merge,
              );
            } else {
              documents.delete(operation.document.path);
              writes.push({type: "delete", path: operation.document.path});
            }
          }
        },
      };
    },
    async runTransaction(callback) {
      return callback({
        get: async (referenceOrQuery) => referenceOrQuery.isCollection === true
          ? collectionSnapshotFor(referenceOrQuery)
          : snapshotFor(referenceOrQuery),
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

test("vehicle ownership status is verification-critical", () => {
  const active = storedVehicle("user-1", {isPrimary: false});
  for (const status of ["sold", "deregistered", "noLongerOwned"]) {
    assert.equal(
      verificationCoreChanged(active, {...active, status}),
      true,
      status,
    );
  }
});

test("vehicle hero refresh ignores plate visibility but tracks appearance", () => {
  const current = storedVehicle("user-1", {
    equipment: ["Panorama", "Sitzheizung"],
  });
  assert.equal(
    vehicleHeroAppearanceChanged(current, {
      ...current,
      plateDisplayMode: "hidden",
      showPlate: false,
    }),
    false,
  );
  assert.equal(
    vehicleHeroAppearanceChanged(current, {...current, color: "Blau"}),
    true,
  );
  assert.equal(
    vehicleHeroAppearanceChanged(current, {
      ...current,
      equipment: ["Sitzheizung", "Panorama"],
    }),
    false,
  );
});

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

test("normalizes equipment case-insensitively and rejects more than 40", () => {
  const normalized = normalizeVehicleInput("user-1", vehicleInput({
    equipment: ["Panorama", "panorama", "Sitzheizung"],
  }));
  assert.deepEqual(normalized.equipment, ["Panorama", "Sitzheizung"]);

  assert.throws(
    () => normalizeVehicleInput("user-1", vehicleInput({
      equipment: Array.from({length: 41}, (_, index) => `Extra ${index}`),
    })),
    /Maximal 40 Ausstattungen/,
  );
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

test("stores vehicle identifiers privately and never projects them publicly", async () => {
  const userId = "user-private-identifiers";
  const firestore = fakeFirestore({
    [`users/${userId}/profiles/main`]: profileData(userId),
    [`public_profiles/${userId}`]: {uid: userId},
  });

  await saveProfileVehicle({
    firestore,
    authContext: {uid: userId},
    input: vehicleInput({
      hsn: " 0005 ",
      tsn: " abc ",
      vin: " wba12345678901234 ",
    }),
    now: new Date("2026-08-14T08:00:00Z"),
  });

  const privateVehicle = firestore.documents.get(
    `users/${userId}/vehicles/vehicle-1`,
  );
  const publicVehicle = firestore.documents.get(
    `public_profiles/${userId}/vehicles/vehicle-1`,
  );
  assert.equal(privateVehicle.hsn, "0005");
  assert.equal(privateVehicle.tsn, "ABC");
  assert.equal(privateVehicle.vin, "WBA12345678901234");
  assert.equal(Object.hasOwn(publicVehicle, "hsn"), false);
  assert.equal(Object.hasOwn(publicVehicle, "tsn"), false);
  assert.equal(Object.hasOwn(publicVehicle, "vin"), false);
});

test("an active secondary vehicle remains discoverable by its own plate", async () => {
  const userId = "user-secondary";
  const primary = storedVehicle(userId, {
    vehicleId: "vehicle-primary",
    plateRegion: "HH",
    plateLetters: "AA",
    plateNumbers: "1",
    isPrimary: true,
  });
  const firestore = fakeFirestore({
    [`users/${userId}/profiles/main`]: profileData(userId, {
      primaryVehicleId: "vehicle-primary",
    }),
    [`public_profiles/${userId}`]: {uid: userId},
    [`users/${userId}/vehicles/vehicle-primary`]: primary,
    [`public_profiles/${userId}/vehicles/vehicle-primary`]: primary,
    "plates/DE_HHAA1": plateData(userId, primary, {isPrimary: true}),
  });

  const result = await saveProfileVehicle({
    firestore,
    authContext: {uid: userId},
    input: vehicleInput({
      vehicleId: "vehicle-secondary",
      isPrimary: false,
    }),
    now: new Date("2026-08-14T08:00:00Z"),
  });

  const secondaryPlate = firestore.documents.get("plates/DE_FDRT2918");
  assert.equal(result.isPrimary, false);
  assert.equal(secondaryPlate.vehicleId, "vehicle-secondary");
  assert.equal(secondaryPlate.isPrimary, false);
  assert.equal(secondaryPlate.isActive, true);
  assert.equal(secondaryPlate.isDeleted, false);
  assert.equal(secondaryPlate.allowContactRequests, true);
});

test("global visibility is a hard ceiling for every vehicle", async () => {
  const userId = "user-privacy";
  const vehicle = storedVehicle(userId);
  const firestore = fakeFirestore({
    [`users/${userId}/profiles/main`]: profileData(userId, {
      primaryVehicleId: vehicle.vehicleId,
      publicRegion: "Hamburg",
    }),
    [`public_profiles/${userId}`]: {
      uid: userId,
      showVehicleOnPublicProfile: true,
      showPlateOnPublicProfile: true,
      profileAccessEnabled: true,
    },
    [`users/${userId}/vehicles/${vehicle.vehicleId}`]: vehicle,
    [`public_profiles/${userId}/vehicles/${vehicle.vehicleId}`]: {
      ...vehicle,
      plateRegion: "FD",
      plateLetters: "RT",
      plateNumbers: "2918",
    },
    "plates/DE_FDRT2918": plateData(userId, vehicle, {
      allowContactRequests: true,
    }),
  });

  await syncProfileVisibilityReferences({
    firestore,
    userId,
    settings: {
      profileVisibility: "contacts",
      showVehicle: true,
      showPlate: false,
      showRegion: false,
      allowContactRequests: false,
    },
    now: new Date("2026-08-16T10:00:00Z"),
  });

  const publicVehicle = firestore.documents.get(
    `public_profiles/${userId}/vehicles/${vehicle.vehicleId}`,
  );
  assert.equal(publicVehicle.brand, "Mercedes-Benz");
  assert.equal(publicVehicle.plateRegion, null);
  assert.equal(publicVehicle.plateLetters, null);
  assert.equal(publicVehicle.plateNumbers, null);
  assert.equal(publicVehicle.showPlate, false);
  assert.equal(publicVehicle.allowContactRequests, false);
  assert.equal(
    firestore.documents.get("plates/DE_FDRT2918").allowContactRequests,
    false,
  );

  await syncProfileVisibilityReferences({
    firestore,
    userId,
    settings: {
      profileVisibility: "onlyMe",
      showVehicle: false,
      showPlate: false,
      showRegion: false,
      allowContactRequests: false,
    },
    now: new Date("2026-08-16T10:01:00Z"),
  });

  assert.equal(
    firestore.documents.has(
      `public_profiles/${userId}/vehicles/${vehicle.vehicleId}`,
    ),
    false,
  );
  assert.equal(
    firestore.documents.get(`public_profiles/${userId}`).profileAccessEnabled,
    false,
  );
});

test("location refresh updates every active discoverable vehicle", async () => {
  const userId = "user-location";
  const primary = storedVehicle(userId, {
    vehicleId: "vehicle-primary",
    plateRegion: "HH",
    plateLetters: "AA",
    plateNumbers: "1",
    isPrimary: true,
  });
  const secondary = storedVehicle(userId, {
    vehicleId: "vehicle-secondary",
    plateRegion: "B",
    plateLetters: "CD",
    plateNumbers: "2",
    isPrimary: false,
  });
  const hidden = storedVehicle(userId, {
    vehicleId: "vehicle-hidden",
    plateRegion: "M",
    plateLetters: "EF",
    plateNumbers: "3",
    isPrimary: false,
    discoverableByPlate: false,
  });
  const firestore = fakeFirestore({
    [`users/${userId}/profiles/main`]: profileData(userId, {
      primaryVehicleId: "vehicle-primary",
    }),
    [`users/${userId}/vehicles/vehicle-primary`]: primary,
    [`users/${userId}/vehicles/vehicle-secondary`]: secondary,
    [`users/${userId}/vehicles/vehicle-hidden`]: hidden,
    "plates/DE_HHAA1": plateData(userId, primary),
    "plates/DE_BCD2": plateData(userId, secondary),
    "plates/DE_MEF3": plateData(userId, hidden),
  });
  const now = new Date("2026-08-14T08:00:00Z");

  const result = await updatePrimaryVehicleLocation({
    firestore,
    authContext: {uid: userId},
    input: {latitude: 53.55, longitude: 9.99},
    now,
  });

  assert.equal(result.updatedVehicleCount, 2);
  assert.equal(firestore.documents.get("plates/DE_HHAA1").latitude, 53.55);
  assert.equal(firestore.documents.get("plates/DE_BCD2").longitude, 9.99);
  assert.equal(
    firestore.documents.get("plates/DE_BCD2").locationUpdatedAt,
    now,
  );
  assert.equal(
    firestore.documents.get("plates/DE_MEF3").locationUpdatedAt,
    undefined,
  );
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
  nextVehicle.isVerified = true;
  nextVehicle.verificationStatus = "verified";
  const firestore = fakeFirestore({
    [`users/${userId}/profiles/main`]: profileData(userId, {
      primaryVehicleId: "vehicle-old",
      verificationStatus: "verified",
      verificationStages: {identity: true, vehicle: true},
    }),
    [`public_profiles/${userId}`]: {
      uid: userId,
      verificationStatus: "verified",
      isVerified: true,
    },
    [`users/${userId}/vehicles/vehicle-old`]: oldVehicle,
    [`users/${userId}/vehicles/vehicle-next`]: nextVehicle,
    [`public_profiles/${userId}/vehicles/vehicle-old`]: oldVehicle,
    [`public_profiles/${userId}/vehicles/vehicle-next`]: nextVehicle,
    "plates/DE_HHCR2026": plateData(userId, oldVehicle, {isPrimary: true}),
    "plates/DE_BPQ1234": plateData(userId, nextVehicle, {isPrimary: false}),
  });

  const result = await setPrimaryProfileVehicle({
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
  assert.equal(firestore.documents.get("plates/DE_BPQ1234").isVerified, true);
  assert.equal(result.verificationReset, false);
  assert.equal(firestore.documents.get(
    `users/${userId}/profiles/main`,
  ).verificationStatus, "verified");
  assert.equal(firestore.documents.get(
    `public_profiles/${userId}`,
  ).isVerified, true);
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

test("verified core changes reset only the vehicle verification", async () => {
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
      verificationStages: {identity: true, vehicle: true},
    }),
    [`public_profiles/${userId}`]: {
      uid: userId,
      verificationStatus: "verified",
      isVerified: true,
    },
    [`users/${userId}/vehicles/vehicle-1`]: existing,
    [`public_profiles/${userId}/vehicles/vehicle-1`]: existing,
    "plates/DE_FDRT2918": plateData(userId, existing, {
      verificationStatus: "verified",
      isVerified: true,
    }),
    [`verification_requests/${userId}`]: {
      userId,
      vehicleId: "vehicle-1",
      status: "verified",
      documentStatuses: {
        identityFront: "verified",
        identityBack: "verified",
        driverLicenseFront: "verified",
        vehicleFront: "verified",
        vehicleBack: "verified",
      },
      documentRejectionReasons: {},
      submittedDocumentGroups: [],
    },
    [`users/${userId}/vehicle_verifications/vehicle-1`]: {
      status: "verified",
      declarationId: "declaration-1",
    },
    [`users/${userId}/verification_declarations/declaration-1`]: {
      status: "active",
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
  ).verificationStatus, "verified");
  assert.deepEqual(firestore.documents.get(
    `users/${userId}/profiles/main`,
  ).verificationStages, {identity: true, vehicle: false});
  assert.equal(firestore.documents.get(
    `public_profiles/${userId}`,
  ).isVerified, true);
  assert.equal(firestore.documents.get("plates/DE_FDRT2918").isVerified, false);
  const request = firestore.documents.get(`verification_requests/${userId}`);
  assert.equal(request.status, "draft");
  assert.equal(request.documentStatuses.identityFront, "verified");
  assert.equal(request.documentStatuses.identityBack, "verified");
  assert.equal(request.documentStatuses.driverLicenseFront, "verified");
  assert.equal(request.documentStatuses.vehicleFront, "expired");
  assert.equal(request.documentStatuses.vehicleBack, "expired");
  assert.equal(firestore.documents.get(
    `users/${userId}/vehicle_verifications/vehicle-1`,
  ).status, "invalidated");
  assert.equal(firestore.documents.get(
    `users/${userId}/verification_declarations/declaration-1`,
  ).status, "revoked");
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
    [`users/${userId}/vehicle_verifications/vehicle-archive`]: {
      status: "verified",
      declarationId: "declaration-archive",
    },
    [`users/${userId}/verification_declarations/declaration-archive`]: {
      status: "active",
    },
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
  assert.equal(stored.isVerified, false);
  assert.equal(stored.verificationStatus, "unverified");
  assert.equal(firestore.documents.get(
    `users/${userId}/vehicle_verifications/vehicle-archive`,
  ).status, "revoked");
  assert.equal(firestore.documents.get(
    `users/${userId}/verification_declarations/declaration-archive`,
  ).status, "revoked");
});
