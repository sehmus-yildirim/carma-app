const assert = require("node:assert/strict");
const test = require("node:test");
const {Timestamp} = require("firebase-admin/firestore");

const {
  createVerificationSession,
  declarationVersion,
  expireIdentityVerifications,
  finalizeVehicleDeclaration,
  identityCoreChanged,
  normalizeIdentityInput,
  normalizePersonName,
  normalizePlate,
  normalizeRelation,
  normalizeSignature,
  privacyVersion,
  revokeOrInvalidateVerification,
  submitVerificationData,
  validateIdentity,
} = require("./verification_v1");
const {createVehicleDeclarationPdf} = require("./verification_declaration_pdf");
const {isEffectiveVehicleVerification} = require("./verification_v1_policy");

const nowDate = new Date("2026-08-30T12:00:00.000Z");
const now = Timestamp.fromDate(nowDate);
const auth = {uid: "user-1"};
const app = {appId: "android-app"};

test("requires authentication and App Check", async () => {
  const firestore = fakeFirestore();
  await assert.rejects(
    createVerificationSession({
      firestore,
      authContext: null,
      appContext: app,
      input: {vehicleId: "vehicle-1", relation: "registered_holder"},
      now,
    }),
    (error) => error.code === "unauthenticated",
  );
  await assert.rejects(
    createVerificationSession({
      firestore,
      authContext: auth,
      appContext: null,
      input: {vehicleId: "vehicle-1", relation: "registered_holder"},
      now,
    }),
    (error) => error.code === "failed-precondition" &&
      error.details.reason === "app-check-required",
  );
});

test("rejects already-consumed App Check tokens before any write", async () => {
  const firestore = firestoreWithVehicle();
  await assert.rejects(
    createVerificationSession({
      firestore,
      authContext: auth,
      appContext: {...app, alreadyConsumed: true},
      input: {vehicleId: "vehicle-1", relation: "registered_holder"},
      now,
    }),
    (error) => error.code === "failed-precondition" &&
      error.details.reason === "app-check-token-replayed",
  );
  assert.equal(
    [...firestore.documents.keys()].some((path) =>
      path.startsWith("_verification_sessions/")),
    false,
  );
});

test("creates a short-lived session only for an owned German vehicle", async () => {
  const firestore = firestoreWithVehicle();
  const result = await createVerificationSession({
    firestore,
    authContext: auth,
    appContext: app,
    input: {vehicleId: "vehicle-1", relation: "registered_holder"},
    now,
  });

  assert.equal(result.state, "created");
  assert.equal(result.nonce.length >= 32, true);
  assert.equal(
    new Date(result.expiresAt).getTime() - nowDate.getTime(),
    15 * 60 * 1000,
  );
  const stored = firestore.documents.get(`_verification_sessions/${result.sessionId}`);
  assert.equal(stored.nonceHash.length, 64);
  assert.equal(JSON.stringify(stored).includes(result.nonce), false);
});

test("rejects a foreign vehicle and unsupported relation", async () => {
  const firestore = firestoreWithVehicle({ownerUserId: "other-user"});
  await assert.rejects(
    createSession(firestore),
    (error) => error.code === "permission-denied",
  );
  await assert.rejects(
    createVerificationSession({
      firestore,
      authContext: auth,
      appContext: app,
      input: {vehicleId: "vehicle-1", relation: "owner"},
      now,
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("enforces the hourly session limit transactionally", async () => {
  const attempts = Array.from({length: 5}, (_, index) =>
    Timestamp.fromDate(new Date(nowDate.getTime() - index * 1000)));
  const firestore = firestoreWithVehicle({}, {
    "_verification_rate_limits/user-1": {attempts},
  });
  await assert.rejects(
    createSession(firestore),
    (error) => error.code === "resource-exhausted",
  );
});

test("validates date boundaries and the existing Plaqa minimum age", () => {
  assert.doesNotThrow(() => validateIdentity(identityInput({
    dateOfBirth: new Date("2010-08-30T00:00:00Z"),
    expiresAt: new Date("2026-08-30T00:00:00Z"),
  }), nowDate));
  assert.throws(
    () => validateIdentity(identityInput({
      dateOfBirth: new Date("2010-08-31T00:00:00Z"),
    }), nowDate),
    (error) => error.details.reason === "minimum-age",
  );
  assert.throws(
    () => validateIdentity(identityInput({
      expiresAt: new Date("2026-08-29T00:00:00Z"),
    }), nowDate),
    (error) => error.details.reason === "document-expired",
  );
});

test("normalizes names and plates without lookalike guessing", () => {
  assert.equal(normalizePersonName("  Yılmaz-Müller "), "yilmaz-mueller");
  assert.equal(normalizePlate("hh - ab 123"), "HHAB123");
  assert.notEqual(normalizePlate("HH OI 1"), normalizePlate("HH 01 1"));
});

test("validates international document profiles without guessing layouts", () => {
  const passport = normalizeIdentityInput(identityPayload({
    documentType: "passport",
    issuingCountryCode: "TR",
    documentProfileVersion: "icao_td3_eighth_edition_v1",
  }));
  assert.equal(passport.issuingCountryCode, "TR");
  assert.equal(normalizeRelation("leasing_vehicle"), "leasing");
  assert.throws(
    () => normalizeIdentityInput(identityPayload({
      documentType: "id_card",
      issuingCountryCode: "TR",
      documentProfileVersion: "invented_layout_v1",
    })),
    (error) => error.details.reason === "unsupported-document-profile",
  );
});

test("detects only identity-core changes", () => {
  const previous = {
    verifiedFirstNames: "Erika Maria",
    verifiedLastName: "Muster",
    dateOfBirth: "1990-01-01",
  };
  assert.equal(identityCoreChanged(previous, identityInput()), false);
  assert.equal(identityCoreChanged(previous, identityInput({
    firstNames: "Erika",
  })), true);
  assert.equal(identityCoreChanged(previous, identityInput({
    expiresAt: new Date("2035-12-31T00:00:00Z"),
  })), false);
});

test("expires identity and every dependent vehicle verification", async () => {
  const firestore = fakeExpiryFirestore({
    "users/user-1/private_verification/identity": {
      status: "verified",
      documentExpiresAt: "2026-08-29",
    },
    "users/user-1/vehicle_verifications/vehicle-1": {
      status: "verified",
      declarationId: "declaration-1",
      plateNormalized: "HHAB123",
    },
    "users/user-1/verification_declarations/declaration-1": {
      status: "active",
    },
    "users/user-1/vehicles/vehicle-1": {
      isVerified: true,
      verificationStatus: "verified",
    },
    "plates/DE_HHAB123": {
      ownerUserId: "user-1",
      vehicleId: "vehicle-1",
      isVerified: true,
      verificationStatus: "verified",
    },
  });

  const result = await expireIdentityVerifications({firestore, now});

  assert.deepEqual(result, {
    identityCount: 1,
    vehicleCount: 1,
    hasMore: false,
  });
  assert.equal(firestore.documents.get(
    "users/user-1/private_verification/identity",
  ).status, "expired");
  assert.equal(firestore.documents.get(
    "users/user-1/vehicle_verifications/vehicle-1",
  ).status, "invalidated");
  assert.equal(firestore.documents.get(
    "users/user-1/verification_declarations/declaration-1",
  ).status, "revoked");
  assert.equal(firestore.documents.get(
    "users/user-1/vehicles/vehicle-1",
  ).isVerified, false);
  assert.equal(firestore.documents.get(
    "public_profiles/user-1",
  ).isVerified, false);
  assert.equal(firestore.documents.get(
    "public_profiles/user-1/vehicles/vehicle-1",
  ).isVerified, false);
  assert.equal(firestore.documents.get("plates/DE_HHAB123").isVerified, false);
});

test("skips a stale expiry snapshot after concurrent identity renewal", async () => {
  let renewalInjected = false;
  const firestore = fakeExpiryFirestore({
    "users/user-1/private_verification/identity": {
      status: "verified",
      documentExpiresAt: "2026-08-29",
    },
    "users/user-1/vehicle_verifications/vehicle-1": {
      status: "verified",
      plateNormalized: "HHAB123",
    },
    "users/user-1/vehicles/vehicle-1": {
      isVerified: true,
      verificationStatus: "verified",
    },
    "plates/DE_HHAB123": {
      ownerUserId: "user-1",
      vehicleId: "vehicle-1",
      isVerified: true,
      verificationStatus: "verified",
    },
  }, {
    beforeBatchCommit({setDocument}) {
      if (renewalInjected) return;
      renewalInjected = true;
      setDocument("users/user-1/private_verification/identity", {
        status: "verified",
        documentExpiresAt: "2030-12-31",
      });
    },
  });

  const result = await expireIdentityVerifications({firestore, now});

  assert.deepEqual(result, {
    identityCount: 0,
    vehicleCount: 0,
    hasMore: false,
  });
  assert.equal(firestore.documents.get(
    "users/user-1/private_verification/identity",
  ).documentExpiresAt, "2030-12-31");
  assert.equal(firestore.documents.get(
    "users/user-1/vehicle_verifications/vehicle-1",
  ).status, "verified");
  assert.equal(firestore.documents.get("plates/DE_HHAB123").isVerified, true);
});

test("registered holder completes atomically and does not persist C.1 fields", async () => {
  const firestore = firestoreWithVehicle();
  const session = await createSession(firestore);
  const result = await submit(firestore, session);

  assert.deepEqual(result, {
    status: "verified",
    holderMatch: true,
    declarationId: null,
    idempotent: false,
  });
  const identity = firestore.documents.get(
    "users/user-1/private_verification/identity",
  );
  const verification = firestore.documents.get(
    "users/user-1/vehicle_verifications/vehicle-1",
  );
  assert.equal(identity.verifiedFirstNames, "Erika Maria");
  assert.equal(identity.schemaVersion, 2);
  assert.equal(identity.identityDocumentDataChecked, true);
  assert.equal(identity.issuingCountryCode, "DE");
  assert.equal(identity.documentProfileVersion, "deu_bo_02004_2021_v1");
  assert.equal(verification.status, "verified");
  assert.equal(verification.flowState, "verified");
  assert.equal(verification.identityDocumentDataChecked, true);
  assert.equal(verification.vehicleDocumentDataChecked, true);
  assert.equal(verification.plateMatch, true);
  assert.equal(verification.declarationRequired, false);
  assert.equal(verification.registrationCountryCode, "DE");
  assert.match(identity.identityVersion, /^[0-9a-f-]{36}$/u);
  assert.equal(verification.identityVersion, identity.identityVersion);
  assert.equal(firestore.documents.get("public_profiles/user-1").isVerified, true);
  assert.equal(firestore.documents.get(
    "public_profiles/user-1/vehicles/vehicle-1",
  ).isVerified, true);
  assert.equal(firestore.documents.get("plates/DE_HHAB123").isVerified, true);
  const serialized = JSON.stringify([...firestore.documents.entries()]);
  assert.equal(serialized.includes("holderNameOrCompany"), false);
  assert.equal(serialized.includes("holderFirstNames"), false);
  assert.equal(serialized.includes("Muster GmbH"), false);
});

test("rejects plate mismatch and holder mismatch", async () => {
  const plateFirestore = firestoreWithVehicle();
  const plateSession = await createSession(plateFirestore);
  await assert.rejects(
    submit(plateFirestore, plateSession, {
      vehicleRegistration: registrationPayload({plate: "B AB 1"}),
    }),
    (error) => error.details.reason === "plate-mismatch",
  );

  const holderFirestore = firestoreWithVehicle();
  const holderSession = await createSession(holderFirestore);
  await assert.rejects(
    submit(holderFirestore, holderSession, {
      vehicleRegistration: registrationPayload({holderNameOrCompany: "Anders"}),
    }),
    (error) => error.details.reason === "holder-mismatch",
  );

  const countryFirestore = firestoreWithVehicle();
  const countrySession = await createSession(countryFirestore);
  await assert.rejects(
    submit(countryFirestore, countrySession, {
      vehicleRegistration: registrationPayload({
        registrationCountryCode: "TR",
      }),
    }),
    (error) => [
      "unsupported-document-profile",
      "vehicle-country-mismatch",
    ].includes(error.details.reason),
  );
});

test("rejects expired sessions and replay with changed data", async () => {
  const expiredFirestore = firestoreWithVehicle();
  const expiredSession = await createSession(expiredFirestore);
  await assert.rejects(
    submitVerificationData({
      firestore: expiredFirestore,
      authContext: auth,
      appContext: app,
      input: submissionPayload(expiredSession),
      now: Timestamp.fromDate(new Date(nowDate.getTime() + 16 * 60 * 1000)),
    }),
    (error) => error.code === "deadline-exceeded",
  );

  const replayFirestore = firestoreWithVehicle();
  const replaySession = await createSession(replayFirestore);
  await submit(replayFirestore, replaySession);
  const repeated = await submit(replayFirestore, replaySession);
  assert.equal(repeated.idempotent, true);
  await assert.rejects(
    submit(replayFirestore, replaySession, {
      identity: identityPayload({firstNames: "Erika"}),
    }),
    (error) => error.details.reason === "session-replay",
  );
});

test("non-holder requires a declaration and finalizes the PDF exactly once", async () => {
  const firestore = firestoreWithVehicle();
  const session = await createSession(firestore, "leasing");
  const submitted = await submit(firestore, session, {
    vehicleRegistration: registrationPayload({
      holderNameOrCompany: "Muster Leasing GmbH",
      holderFirstNames: null,
    }),
  });
  assert.equal(submitted.status, "requires_declaration");
  assert.equal(submitted.holderMatch, false);

  const bucket = fakeBucket();
  let generated = 0;
  const input = declarationPayload(session);
  const first = await finalizeVehicleDeclaration({
    firestore,
    bucket,
    authContext: auth,
    appContext: app,
    input,
    now,
    pdfFactory: async () => {
      generated += 1;
      return {bytes: Buffer.from("synthetic-pdf"), sha256: "a".repeat(64)};
    },
  });
  const second = await finalizeVehicleDeclaration({
    firestore,
    bucket,
    authContext: auth,
    appContext: app,
    input,
    now,
    pdfFactory: async () => {
      generated += 1;
      throw new Error("must not regenerate");
    },
  });

  assert.equal(first.status, "verified");
  assert.equal(second.idempotent, true);
  assert.equal(generated, 1);
  assert.equal(bucket.saves.length, 1);
  assert.match(bucket.saves[0].path, /^verification_declarations\/user-1\//u);
  const declaration = firestore.documents.get(
    `users/user-1/verification_declarations/${first.declarationId}`,
  );
  assert.equal(declaration.status, "active");
  assert.equal(declaration.signatureHash, null);
  assert.equal(declaration.pdfSha256, "a".repeat(64));
  assert.equal(firestore.documents.get("plates/DE_HHAB123").isVerified, true);

  await revokeOrInvalidateVerification({
    firestore,
    authContext: auth,
    appContext: app,
    input: {vehicleId: "vehicle-1", reason: "authorization_ended"},
    now,
  });
  assert.equal(firestore.documents.get(
    "users/user-1/vehicle_verifications/vehicle-1",
  ).status, "revoked");
  assert.equal(firestore.documents.get(
    `users/user-1/verification_declarations/${first.declarationId}`,
  ).status, "revoked");
  assert.equal(firestore.documents.get("plates/DE_HHAB123").isVerified, false);
});

test("former owner cannot revoke a successor's plate verification", async () => {
  const firestore = firestoreWithVehicle();
  const session = await createSession(firestore);
  await submit(firestore, session);
  firestore.documents.set("plates/DE_HHAB123", {
    ownerUserId: "user-2",
    vehicleId: "vehicle-2",
    isVerified: true,
    verificationStatus: "verified",
  });

  await revokeOrInvalidateVerification({
    firestore,
    authContext: auth,
    appContext: app,
    input: {vehicleId: "vehicle-1", reason: "user_requested"},
    now,
  });

  assert.deepEqual(firestore.documents.get("plates/DE_HHAB123"), {
    ownerUserId: "user-2",
    vehicleId: "vehicle-2",
    isVerified: true,
    verificationStatus: "verified",
  });
  assert.equal(firestore.documents.get(
    "users/user-1/vehicle_verifications/vehicle-1",
  ).status, "revoked");
});

test("concurrent revocation cannot be restored by declaration finalization", async () => {
  const firestore = firestoreWithVehicle();
  const session = await createSession(firestore, "authorized_private_vehicle");
  await submit(firestore, session, {
    vehicleRegistration: registrationPayload({
      holderNameOrCompany: "Muster Leasing GmbH",
      holderFirstNames: null,
    }),
  });
  const bucket = fakeBucket();
  let releasePdf;
  let markPdfStarted;
  const pdfStarted = new Promise((resolve) => {
    markPdfStarted = resolve;
  });
  const pdfReleased = new Promise((resolve) => {
    releasePdf = resolve;
  });
  const finalization = finalizeVehicleDeclaration({
    firestore,
    bucket,
    authContext: auth,
    appContext: app,
    input: declarationPayload(session),
    now,
    pdfFactory: async () => {
      markPdfStarted();
      await pdfReleased;
      return {bytes: Buffer.from("synthetic-pdf"), sha256: "b".repeat(64)};
    },
  });
  await pdfStarted;
  await revokeOrInvalidateVerification({
    firestore,
    authContext: auth,
    appContext: app,
    input: {vehicleId: "vehicle-1", reason: "authorization_ended"},
    now,
  });
  releasePdf();

  await assert.rejects(
    finalization,
    (error) => error.code === "aborted" &&
      error.details.reason === "verification-state-changed",
  );
  assert.equal(firestore.documents.get(
    "users/user-1/vehicle_verifications/vehicle-1",
  ).status, "revoked");
  assert.equal(bucket.deletes.length, 1);
});

test("account deletion aborts finalization and removes the staged PDF", async () => {
  const firestore = firestoreWithVehicle();
  const session = await createSession(firestore, "company_car");
  await submit(firestore, session, {
    vehicleRegistration: registrationPayload({
      holderNameOrCompany: "Muster GmbH",
      holderFirstNames: null,
    }),
  });
  const bucket = fakeBucket();
  let releasePdf;
  let markPdfStarted;
  const pdfStarted = new Promise((resolve) => {
    markPdfStarted = resolve;
  });
  const pdfReleased = new Promise((resolve) => {
    releasePdf = resolve;
  });
  const finalization = finalizeVehicleDeclaration({
    firestore,
    bucket,
    authContext: auth,
    appContext: app,
    input: declarationPayload(session),
    now,
    pdfFactory: async () => {
      markPdfStarted();
      await pdfReleased;
      return {bytes: Buffer.from("synthetic-pdf"), sha256: "c".repeat(64)};
    },
  });
  await pdfStarted;
  firestore.documents.set("account_deletions/user-1", {status: "requested"});
  releasePdf();

  await assert.rejects(
    finalization,
    (error) => error.details.reason === "account-deletion-in-progress",
  );
  assert.equal(bucket.deletes.length, 1);
});

test("identity versions make stale siblings ineffective after repair failure", async () => {
  const firestore = firestoreWithVehicle();
  const initialSession = await createSession(firestore);
  await submit(firestore, initialSession);
  const initialIdentity = firestore.documents.get(
    "users/user-1/private_verification/identity",
  );
  firestore.documents.set("users/user-1/vehicles/vehicle-2", {
    ownerUserId: "user-1",
    countryCode: "DE",
    plateRegion: "B",
    plateLetters: "AB",
    plateNumbers: "2",
    status: "active",
  });
  firestore.documents.set("users/user-1/vehicle_verifications/vehicle-2", {
    status: "verified",
    plateNormalized: "BAB2",
    verificationMethod: "on_device_ocr_front_v1",
    assuranceLevel: "document_data_match",
    identityVersion: initialIdentity.identityVersion,
  });

  const replacementSession = await createSession(firestore);
  await assert.rejects(
    submitVerificationData({
      firestore,
      authContext: auth,
      appContext: app,
      input: submissionPayload(replacementSession, {
        identity: identityPayload({lastName: "Neu"}),
        vehicleRegistration: registrationPayload({holderNameOrCompany: "Neu"}),
      }),
      now,
      invalidateSiblings: async () => {
        throw new Error("synthetic repair failure");
      },
    }),
    /synthetic repair failure/u,
  );
  const replacementIdentity = firestore.documents.get(
    "users/user-1/private_verification/identity",
  );
  const staleSibling = firestore.documents.get(
    "users/user-1/vehicle_verifications/vehicle-2",
  );
  assert.notEqual(
    replacementIdentity.identityVersion,
    staleSibling.identityVersion,
  );
  assert.equal(isEffectiveVehicleVerification({
    identity: replacementIdentity,
    verification: staleSibling,
    vehicle: firestore.documents.get("users/user-1/vehicles/vehicle-2"),
    now: nowDate,
  }), false);

  let repairCalled = false;
  const replay = await submitVerificationData({
    firestore,
    authContext: auth,
    appContext: app,
    input: submissionPayload(replacementSession, {
      identity: identityPayload({lastName: "Neu"}),
      vehicleRegistration: registrationPayload({holderNameOrCompany: "Neu"}),
    }),
    now,
    invalidateSiblings: async () => {
      repairCalled = true;
    },
  });
  assert.equal(replay.idempotent, true);
  assert.equal(repairCalled, false);
});

test("rejects missing, tiny and oversized signatures", () => {
  assert.throws(() => normalizeSignature(null), /unterschreibe/u);
  assert.throws(() => normalizeSignature({
    strokes: [[{x: 0.1, y: 0.1}, {x: 0.101, y: 0.101}]],
  }), /zu kurz/u);
  assert.throws(() => normalizeSignature({
    strokes: [Array.from({length: 301}, () => ({x: 0.5, y: 0.5}))],
  }), /ungültig/u);
});

test("creates a real private declaration PDF with Unicode-capable font", async () => {
  const pdf = await createVehicleDeclarationPdf({
    declarationId: "declaration-1",
    userReference: "reference-1",
    fullName: "Çağla Yılmaz-Öztürk",
    plate: "HHAB123",
    relationLabel: "Leasingfahrzeug",
    declarationVersion,
    declarationText: "Ich, Çağla Yılmaz-Öztürk, bestätige die Berechtigung.",
    declarationTextHash: "b".repeat(64),
    acceptedAt: nowDate,
    signature: validSignature(),
  });
  assert.equal(pdf.bytes.subarray(0, 4).toString("ascii"), "%PDF");
  assert.equal(pdf.sha256.length, 64);
  assert.equal(pdf.bytes.length > 2000, true);
});

function firestoreWithVehicle(overrides = {}, additional = {}) {
  const vehicle = {
    ownerUserId: "user-1",
    countryCode: "DE",
    plateRegion: "HH",
    plateLetters: "AB",
    plateNumbers: "123",
    status: "active",
    ...overrides,
  };
  const plateNormalized = normalizePlate(
    `${vehicle.plateRegion}${vehicle.plateLetters}${vehicle.plateNumbers}`,
  );
  return fakeFirestore({
    "users/user-1/vehicles/vehicle-1": vehicle,
    [`plates/DE_${plateNormalized}`]: {
      ownerUserId: "user-1",
      vehicleId: "vehicle-1",
      countryCode: "DE",
      plateKey: plateNormalized,
      isActive: true,
      isDeleted: false,
    },
    ...additional,
  });
}

function createSession(firestore, relation = "registered_holder") {
  return createVerificationSession({
    firestore,
    authContext: auth,
    appContext: app,
    input: {vehicleId: "vehicle-1", relation},
    now,
  });
}

function submit(firestore, session, overrides = {}) {
  return submitVerificationData({
    firestore,
    authContext: auth,
    appContext: app,
    input: {...submissionPayload(session), ...overrides},
    now,
  });
}

function submissionPayload(session, overrides = {}) {
  return {
    sessionId: session.sessionId,
    nonce: session.nonce,
    privacyVersion,
    identity: identityPayload(),
    vehicleRegistration: registrationPayload(),
    ...overrides,
  };
}

function identityPayload(overrides = {}) {
  return {
    firstNames: "Erika Maria",
    lastName: "Muster",
    dateOfBirth: "1990-01-01",
    expiresAt: "2030-12-31",
    documentType: "id_card",
    parserVersion: "de_id_front_v1.0.0",
    issuingCountryCode: "DE",
    documentProfileVersion: "deu_bo_02004_2021_v1",
    ...overrides,
  };
}

function identityInput(overrides = {}) {
  return {
    firstNames: "Erika Maria",
    lastName: "Muster",
    dateOfBirth: new Date("1990-01-01T00:00:00Z"),
    expiresAt: new Date("2030-12-31T00:00:00Z"),
    documentType: "id_card",
    parserVersion: "de_id_front_v1.0.0",
    ...overrides,
  };
}

function registrationPayload(overrides = {}) {
  return {
    plate: "HH AB 123",
    holderNameOrCompany: "Muster",
    holderFirstNames: "Erika Maria",
    parserVersion: "de_vehicle_registration_front_v1.0.0",
    registrationCountryCode: "DE",
    documentProfileVersion: "deu_go_01001_2005_v1",
    ...overrides,
  };
}

function declarationPayload(session) {
  return {
    sessionId: session.sessionId,
    nonce: session.nonce,
    declarationVersion,
    privacyVersion,
    declarationAccepted: true,
    signature: validSignature(),
  };
}

function validSignature() {
  return {
    strokes: [[
      {x: 0.1, y: 0.6},
      {x: 0.18, y: 0.35},
      {x: 0.25, y: 0.65},
      {x: 0.33, y: 0.3},
      {x: 0.42, y: 0.62},
      {x: 0.52, y: 0.4},
      {x: 0.65, y: 0.58},
      {x: 0.82, y: 0.42},
    ]],
  };
}

function fakeBucket() {
  const saves = [];
  const deletes = [];
  return {
    saves,
    deletes,
    file(path) {
      return {
        async save(bytes, options) {
          saves.push({path, bytes, options});
        },
        async delete(options) {
          deletes.push({path, options});
        },
      };
    },
  };
}

function fakeFirestore(initialDocuments = {}) {
  const documents = new Map(Object.entries(initialDocuments));
  const writes = [];
  function reference(path) {
    return {path};
  }
  function snapshotFor(ref) {
    const data = documents.get(ref.path);
    return {exists: data != null, data: () => data, ref};
  }
  function set(ref, data, merge) {
    const previous = merge ? documents.get(ref.path) ?? {} : {};
    documents.set(ref.path, {...previous, ...data});
    writes.push({path: ref.path, data, merge});
  }
  return {
    documents,
    writes,
    doc: reference,
    async runTransaction(callback) {
      return callback({
        get: async (ref) => snapshotFor(ref),
        set(ref, data, options) {
          set(ref, data, options?.merge === true);
        },
        delete(ref) {
          documents.delete(ref.path);
        },
      });
    },
  };
}

function fakeExpiryFirestore(initialDocuments, {beforeBatchCommit} = {}) {
  const documents = new Map(Object.entries(initialDocuments));
  const versions = new Map(
    [...documents.keys()].map((path) => [path, 1]),
  );
  let version = 1;
  function setDocument(path, data, {merge = false} = {}) {
    const previous = merge ? documents.get(path) ?? {} : {};
    documents.set(path, {...previous, ...data});
    version += 1;
    versions.set(path, version);
  }
  function reference(path) {
    return {
      path,
      async get() {
        return snapshot(path);
      },
    };
  }
  function snapshot(path) {
    const data = documents.get(path);
    return {
      id: path.split("/").at(-1),
      exists: data != null,
      data: () => data,
      ref: reference(path),
      updateTime: versions.get(path) ?? null,
    };
  }
  function queryFor(paths) {
    return {
      where() {
        return this;
      },
      limit() {
        return this;
      },
      async get() {
        const docs = paths.map(snapshot);
        return {docs, size: docs.length};
      },
    };
  }
  return {
    documents,
    doc: reference,
    collectionGroup() {
      return queryFor([
        "users/user-1/private_verification/identity",
      ]);
    },
    collection(path) {
      return queryFor([
        `${path}/vehicle-1`,
      ]);
    },
    batch() {
      const writes = [];
      return {
        set(ref, data, options) {
          writes.push({
            ref,
            data,
            merge: options?.merge === true,
            precondition: null,
          });
        },
        update(ref, data, precondition) {
          writes.push({ref, data, merge: true, precondition});
        },
        async commit() {
          await beforeBatchCommit?.({documents, setDocument, versions});
          for (const write of writes) {
            const expected = write.precondition?.lastUpdateTime;
            if (expected != null && versions.get(write.ref.path) !== expected) {
              const error = new Error("Synthetic stale snapshot.");
              error.code = 9;
              throw error;
            }
          }
          for (const write of writes) {
            setDocument(write.ref.path, write.data, {merge: write.merge});
          }
        },
      };
    },
  };
}
