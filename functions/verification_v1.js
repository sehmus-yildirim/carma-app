const {createHash, randomBytes, randomUUID} = require("node:crypto");
const {Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const {createVehicleDeclarationPdf} = require("./verification_declaration_pdf");
const {
  assuranceLevel,
  verificationMethod,
} = require("./verification_v1_policy");

const schemaVersion = 2;
const privacyVersion = "verification_privacy_international_v2.0.0";
const declarationVersion = "vehicle_authorization_international_v2.0.0";
const sessionLifetimeMs = 15 * 60 * 1000;
const minimumAge = 16;
const hourlyAttemptLimit = 5;
const dailyAttemptLimit = 20;
const declarationGenerationLeaseMs = 2 * 60 * 1000;
const blockingAccountDeletionStatuses = new Set([
  "requested",
  "processing",
  "completed",
]);
const relations = new Set([
  "registered_holder",
  "leasing",
  "company_car",
  "authorized_private_vehicle",
  "other_authorized",
]);
const legacyRelations = new Map([
  ["leasing_vehicle", "leasing"],
  ["company_vehicle", "company_car"],
  ["authorized_by_holder", "authorized_private_vehicle"],
]);
const documentTypes = new Set(["id_card", "passport", "residence_permit"]);
const supportedIdentityCountries = new Set([
  "DE", "TR", "UA", "SY", "RO", "PL", "IT", "AF", "BG", "HR", "GR",
  "XK", "IN", "RU", "RS", "AT", "BA", "ES", "FR", "NL", "CH",
]);
const passportProfileVersion = "icao_td3_eighth_edition_v1";
const germanIdentityProfileVersions = new Set([
  "deu_bo_02004_2021_v1",
  "deu_bo_02001_2010_v1",
]);
const germanResidenceProfileVersions = new Set(["de_eat_card_family_v1"]);
const germanVehicleProfileVersions = new Set(["deu_go_01001_2005_v1"]);

const declarationTemplate = `Eigenerklärung zur Fahrzeugnutzungsberechtigung

Ich, [VORNAME NACHNAME], bestätige, dass ich berechtigt bin, das Fahrzeug mit dem amtlichen Kennzeichen [KENNZEICHEN] zu nutzen und diesem Plaqa-Konto zuzuordnen.

Die von mir ausgewählte Fahrzeugzuordnung lautet: [FAHRZEUGZUORDNUNG].

Ich bestätige, dass meine Angaben vollständig, aktuell und wahrheitsgemäß sind. Ich werde die Fahrzeugzuordnung entfernen oder Plaqa informieren, sobald meine Nutzungsberechtigung endet.

Mir ist bekannt, dass falsche Angaben zur Sperrung der Fahrzeugzuordnung oder meines Plaqa-Kontos führen können.`;

const relationLabels = {
  registered_holder: "Ich bin im Fahrzeugschein als Halter eingetragen",
  leasing: "Leasingfahrzeug",
  company_car: "Firmen-/Dienstwagen",
  authorized_private_vehicle: "Fahrzeug mit Erlaubnis des Halters",
  other_authorized: "Sonstiges berechtigt genutztes Fahrzeug",
};

function ensureTrustedCaller(authContext, appContext, {requireAppCheck = true} = {}) {
  const userId = safeString(authContext?.uid);
  if (userId.length === 0) {
    throw new HttpsError("unauthenticated", "Bitte melde dich neu an.");
  }
  if (requireAppCheck && safeString(appContext?.appId).length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Die App-Integrität konnte nicht bestätigt werden.",
      {reason: "app-check-required"},
    );
  }
  if (requireAppCheck && appContext?.alreadyConsumed === true) {
    throw new HttpsError(
      "failed-precondition",
      "Die App-Integrität konnte nicht erneut bestätigt werden.",
      {reason: "app-check-token-replayed"},
    );
  }
  return userId;
}

function accountDeletionBlocksVerification(snapshot) {
  if (snapshot?.exists !== true) return false;
  return blockingAccountDeletionStatuses.has(
    safeString(snapshot.data()?.status),
  );
}

function ensureAccountAcceptsVerification(snapshot) {
  if (!accountDeletionBlocksVerification(snapshot)) return;
  throw new HttpsError(
    "failed-precondition",
    "Die Verifizierung ist während der Kontolöschung nicht verfügbar.",
    {reason: "account-deletion-in-progress"},
  );
}

function vehicleIsActiveAndOwned(vehicle, userId) {
  return safeString(vehicle?.ownerUserId) === userId &&
    vehicle?.isDeleted !== true &&
    safeString(vehicle?.status || "active") === "active";
}

function plateSnapshotMatchesVehicle(snapshot, userId, vehicleId) {
  return snapshot?.exists === true &&
    safeString(snapshot.data()?.ownerUserId) === userId &&
    safeString(snapshot.data()?.vehicleId) === vehicleId;
}

function normalizeCreateSessionInput(input) {
  const vehicleId = normalizeId(input?.vehicleId, "Fahrzeug");
  const relation = normalizeRelation(input?.relation);
  if (!relations.has(relation)) {
    throw new HttpsError("invalid-argument", "Wähle eine gültige Fahrzeugzuordnung.");
  }
  return {vehicleId, relation};
}

function normalizeSubmissionInput(input) {
  const sessionId = normalizeId(input?.sessionId, "Session");
  const nonce = safeString(input?.nonce);
  if (!/^[A-Za-z0-9_-]{32,128}$/u.test(nonce)) {
    throw new HttpsError("invalid-argument", "Die Verifizierungssession ist ungültig.");
  }
  if (safeString(input?.privacyVersion) !== privacyVersion) {
    throw new HttpsError(
      "failed-precondition",
      "Bitte bestätige die aktuelle Datenschutzinformation.",
    );
  }
  const identity = normalizeIdentityInput(input?.identity);
  const vehicleRegistration = normalizeVehicleRegistrationInput(
    input?.vehicleRegistration,
  );
  return {sessionId, nonce, identity, vehicleRegistration};
}

function normalizeIdentityInput(value) {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "Die Identitätsdaten fehlen.");
  }
  const documentType = safeString(value.documentType);
  if (!documentTypes.has(documentType)) {
    throw new HttpsError("invalid-argument", "Der Dokumenttyp wird nicht unterstützt.");
  }
  const firstNames = normalizeDisplayName(value.firstNames, "Vorname");
  const lastName = normalizeDisplayName(value.lastName, "Nachname");
  const dateOfBirth = parseDateOnly(value.dateOfBirth, "Geburtsdatum");
  const expiresAt = parseDateOnly(value.expiresAt, "Ablaufdatum");
  const parserVersion = normalizeParserVersion(value.parserVersion);
  const issuingCountryCode = normalizeCountryCode(
    safeString(value.issuingCountryCode).length === 0 ?
      "DE" : value.issuingCountryCode,
    "Ausstellungsland",
  );
  const documentProfileVersion = normalizeParserVersion(
    safeString(value.documentProfileVersion).length === 0 ?
      legacyIdentityProfileVersion(documentType) :
      value.documentProfileVersion,
  );
  validateIdentityProfile({
    issuingCountryCode,
    documentType,
    documentProfileVersion,
  });
  return {
    firstNames,
    lastName,
    dateOfBirth,
    expiresAt,
    documentType,
    parserVersion,
    issuingCountryCode,
    documentProfileVersion,
  };
}

function normalizeVehicleRegistrationInput(value) {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "Die Fahrzeugscheindaten fehlen.");
  }
  const plate = safeString(value.plate);
  const holderNameOrCompany = normalizeDisplayName(
    value.holderNameOrCompany,
    "Haltername",
  );
  const rawFirstNames = safeString(value.holderFirstNames);
  const holderFirstNames = rawFirstNames.length === 0 ? null :
    normalizeDisplayName(rawFirstNames, "Haltervorname");
  const registrationCountryCode = normalizeCountryCode(
    safeString(value.registrationCountryCode).length === 0 ?
      "DE" : value.registrationCountryCode,
    "Zulassungsland",
  );
  const documentProfileVersion = normalizeParserVersion(
    safeString(value.documentProfileVersion).length === 0 ?
      "deu_go_01001_2005_v1" : value.documentProfileVersion,
  );
  if (registrationCountryCode !== "DE" ||
      !germanVehicleProfileVersions.has(documentProfileVersion)) {
    throw new HttpsError(
      "failed-precondition",
      "Dieses Fahrzeugdokument ist noch nicht zuverlässig unterstützt.",
      {reason: "unsupported-document-profile"},
    );
  }
  return {
    plate,
    holderNameOrCompany,
    holderFirstNames,
    parserVersion: normalizeParserVersion(value.parserVersion),
    registrationCountryCode,
    documentProfileVersion,
  };
}

function legacyIdentityProfileVersion(documentType) {
  if (documentType === "passport") return passportProfileVersion;
  if (documentType === "residence_permit") return "de_eat_card_family_v1";
  return "deu_bo_02004_2021_v1";
}

function normalizeRelation(value) {
  const relation = safeString(value);
  return legacyRelations.get(relation) ?? relation;
}

function normalizeCountryCode(value, fieldName) {
  const result = safeString(value).toUpperCase();
  if (!/^[A-Z]{2}$/u.test(result) || !supportedIdentityCountries.has(result)) {
    throw new HttpsError("invalid-argument", `${fieldName} ist ungültig.`);
  }
  return result;
}

function validateIdentityProfile({
  issuingCountryCode,
  documentType,
  documentProfileVersion,
}) {
  const supported = documentType === "passport" ?
    documentProfileVersion === passportProfileVersion :
    issuingCountryCode === "DE" &&
      (documentType === "id_card" ?
        germanIdentityProfileVersions.has(documentProfileVersion) :
        germanResidenceProfileVersions.has(documentProfileVersion));
  if (!supported) {
    throw new HttpsError(
      "failed-precondition",
      "Dieser Dokumenttyp ist noch nicht zuverlässig unterstützt.",
      {reason: "unsupported-document-profile"},
    );
  }
}

function validateIdentity(identity, serverNow, {ageLimit = minimumAge} = {}) {
  const today = utcDateOnly(serverNow);
  if (identity.dateOfBirth >= today) {
    throw new HttpsError("invalid-argument", "Das Geburtsdatum ist nicht plausibel.");
  }
  if (ageOn(identity.dateOfBirth, today) < ageLimit) {
    throw new HttpsError(
      "failed-precondition",
      `Für Plaqa musst du mindestens ${ageLimit} Jahre alt sein.`,
      {reason: "minimum-age"},
    );
  }
  if (identity.expiresAt < today) {
    throw new HttpsError(
      "failed-precondition",
      "Der Identitätsnachweis ist abgelaufen. Bitte verwende ein gültiges Dokument.",
      {reason: "document-expired"},
    );
  }
  if (identity.expiresAt <= identity.dateOfBirth) {
    throw new HttpsError("invalid-argument", "Das Ablaufdatum ist nicht plausibel.");
  }
}

async function createVerificationSession({
  firestore,
  authContext,
  appContext,
  input,
  now = Timestamp.now(),
  requireAppCheck = true,
}) {
  const userId = ensureTrustedCaller(authContext, appContext, {requireAppCheck});
  const normalized = normalizeCreateSessionInput(input);
  const nowDate = asDate(now);
  const expiresAt = Timestamp.fromDate(
    new Date(nowDate.getTime() + sessionLifetimeMs),
  );
  const nonce = randomBytes(32).toString("base64url");
  const nonceHash = sha256(nonce);
  const sessionId = randomUUID();
  const vehicleReference = firestore.doc(
    `users/${userId}/vehicles/${normalized.vehicleId}`,
  );
  const rateReference = firestore.doc(`_verification_rate_limits/${userId}`);
  const sessionReference = firestore.doc(`_verification_sessions/${sessionId}`);
  const deletionReference = firestore.doc(`account_deletions/${userId}`);

  await firestore.runTransaction(async (transaction) => {
    const [vehicleSnapshot, rateSnapshot, deletionSnapshot] = await Promise.all([
      transaction.get(vehicleReference),
      transaction.get(rateReference),
      transaction.get(deletionReference),
    ]);
    ensureAccountAcceptsVerification(deletionSnapshot);
    if (!vehicleSnapshot.exists ||
        !vehicleIsActiveAndOwned(vehicleSnapshot.data(), userId)) {
      throw new HttpsError("permission-denied", "Dieses Fahrzeug gehört nicht zu deinem Konto.");
    }
    const vehicle = vehicleSnapshot.data() ?? {};
    if (safeString(vehicle.countryCode).toUpperCase() !== "DE") {
      throw new HttpsError(
        "failed-precondition",
        "Die automatische Dokumentverifizierung unterstützt in V1 deutsche Fahrzeugdokumente.",
        {reason: "unsupported-country"},
      );
    }
    const attempts = normalizedAttempts(rateSnapshot.data()?.attempts, nowDate);
    const hourStart = nowDate.getTime() - 60 * 60 * 1000;
    if (attempts.filter((attempt) => attempt.getTime() >= hourStart).length >=
        hourlyAttemptLimit || attempts.length >= dailyAttemptLimit) {
      throw new HttpsError(
        "resource-exhausted",
        "Zu viele Verifizierungsversuche. Bitte versuche es später erneut.",
        {reason: "verification-rate-limit"},
      );
    }
    transaction.set(rateReference, {
      attempts: [...attempts.map((attempt) => Timestamp.fromDate(attempt)), now],
      updatedAt: now,
    }, {merge: false});
    transaction.set(sessionReference, {
      schemaVersion,
      uid: userId,
      vehicleId: normalized.vehicleId,
      relation: normalized.relation,
      state: "created",
      flowState: "not_started",
      vehicleCountryCode: safeString(vehicle.countryCode).toUpperCase(),
      nonceHash,
      createdAt: now,
      updatedAt: now,
      expiresAt,
      attemptCount: 0,
      submissionHash: null,
      holderMatch: null,
      declarationId: null,
    }, {merge: false});
  });

  return {
    sessionId,
    nonce,
    expiresAt: expiresAt.toDate().toISOString(),
    state: "created",
  };
}

async function submitVerificationData({
  firestore,
  authContext,
  appContext,
  input,
  now = Timestamp.now(),
  requireAppCheck = true,
  ageLimit = minimumAge,
  invalidateSiblings = invalidateSiblingVehicleVerifications,
}) {
  const userId = ensureTrustedCaller(authContext, appContext, {requireAppCheck});
  const normalized = normalizeSubmissionInput(input);
  const nowDate = asDate(now);
  validateIdentity(normalized.identity, nowDate, {ageLimit});
  const sessionReference = firestore.doc(
    `_verification_sessions/${normalized.sessionId}`,
  );

  const result = await firestore.runTransaction(async (transaction) => {
    const sessionSnapshot = await transaction.get(sessionReference);
    if (!sessionSnapshot.exists) {
      throw new HttpsError("not-found", "Die Verifizierungssession wurde nicht gefunden.");
    }
    const session = sessionSnapshot.data() ?? {};
    validateSession(session, userId, normalized.nonce, nowDate);
    const vehicleReference = firestore.doc(
      `users/${userId}/vehicles/${safeString(session.vehicleId)}`,
    );
    const identityReference = firestore.doc(
      `users/${userId}/private_verification/identity`,
    );
    const vehicleVerificationReference = firestore.doc(
      `users/${userId}/vehicle_verifications/${safeString(session.vehicleId)}`,
    );
    const profileReference = firestore.doc(`users/${userId}/profiles/main`);
    const publicProfileReference = firestore.doc(`public_profiles/${userId}`);
    const publicVehicleReference = firestore.doc(
      `public_profiles/${userId}/vehicles/${safeString(session.vehicleId)}`,
    );
    const deletionReference = firestore.doc(`account_deletions/${userId}`);
    const [vehicleSnapshot, identitySnapshot, deletionSnapshot] =
      await Promise.all([
      transaction.get(vehicleReference),
      transaction.get(identityReference),
      transaction.get(deletionReference),
    ]);
    ensureAccountAcceptsVerification(deletionSnapshot);
    if (!vehicleSnapshot.exists ||
        !vehicleIsActiveAndOwned(vehicleSnapshot.data(), userId)) {
      throw new HttpsError("permission-denied", "Dieses Fahrzeug gehört nicht zu deinem Konto.");
    }
    const vehicle = vehicleSnapshot.data() ?? {};
    const vehicleId = safeString(session.vehicleId);
    const vehicleCountryCode = safeString(vehicle.countryCode).toUpperCase();
    if (normalized.vehicleRegistration.registrationCountryCode !==
        vehicleCountryCode) {
      throw new HttpsError(
        "failed-precondition",
        "Das Zulassungsland des Dokuments stimmt nicht mit dem Fahrzeug überein.",
        {reason: "vehicle-country-mismatch"},
      );
    }
    const expectedPlate = plateFromVehicle(vehicle);
    const plateReference = firestore.doc(`plates/DE_${expectedPlate}`);
    const plateSnapshot = await transaction.get(plateReference);
    if (!plateSnapshotMatchesVehicle(plateSnapshot, userId, vehicleId)) {
      throw new HttpsError(
        "failed-precondition",
        "Das Kennzeichen ist nicht mehr diesem Fahrzeug zugeordnet.",
        {reason: "plate-binding-changed"},
      );
    }
    const submittedPlate = normalizePlate(normalized.vehicleRegistration.plate);
    if (submittedPlate.length === 0 || submittedPlate !== expectedPlate) {
      throw new HttpsError(
        "failed-precondition",
        "Das Kennzeichen im Fahrzeugschein stimmt nicht mit dem ausgewählten Fahrzeug überein.",
        {reason: "plate-mismatch"},
      );
    }
    const holderMatch = holderMatches(
      normalized.identity,
      normalized.vehicleRegistration,
    );
    const relation = normalizeRelation(session.relation);
    const identityChanged = identitySnapshot.exists &&
      identityCoreChanged(identitySnapshot.data(), normalized.identity);
    const previousIdentityVersion = safeString(
      identitySnapshot.data()?.identityVersion,
    );
    const identityVersion = !identityChanged &&
      previousIdentityVersion.length > 0 ?
      previousIdentityVersion : randomUUID();
    if (relation === "registered_holder" && !holderMatch) {
      throw new HttpsError(
        "failed-precondition",
        "Die Halterdaten stimmen nicht mit deinem Identitätsnachweis überein. Fotografiere die Dokumente erneut oder wähle die passende Fahrzeugzuordnung.",
        {reason: "holder-mismatch"},
      );
    }
    const submissionHash = sha256(stableJson({
      identity: serializeIdentityForHash(normalized.identity),
      vehicleRegistration: normalized.vehicleRegistration,
      relation,
      vehicleId: session.vehicleId,
    }));
    if (["completed", "requires_declaration"].includes(safeString(session.state))) {
      if (safeString(session.submissionHash) !== submissionHash) {
        throw new HttpsError("already-exists", "Diese Session wurde bereits verwendet.", {
          reason: "session-replay",
        });
      }
      return {
        status: session.state === "completed" ? "verified" : "requires_declaration",
        holderMatch: session.holderMatch === true,
        declarationId: session.declarationId ?? null,
        idempotent: true,
        identityChanged: false,
      };
    }
    if (safeString(session.state) !== "created") {
      throw new HttpsError("failed-precondition", "Diese Session kann nicht mehr verwendet werden.");
    }
    const requiresDeclaration = relation !== "registered_holder";
    const status = requiresDeclaration ? "requires_declaration" : "verified";
    const verifiedAt = requiresDeclaration ? null : now;
    transaction.set(identityReference, {
      schemaVersion,
      status: "verified",
      flowState: "identity_data_checked",
      identityDocumentDataChecked: true,
      documentType: normalized.identity.documentType,
      issuingCountryCode: normalized.identity.issuingCountryCode,
      documentProfileVersion: normalized.identity.documentProfileVersion,
      verifiedFirstNames: normalized.identity.firstNames,
      verifiedLastName: normalized.identity.lastName,
      dateOfBirth: dateOnlyString(normalized.identity.dateOfBirth),
      documentExpiresAt: dateOnlyString(normalized.identity.expiresAt),
      verificationMethod,
      assuranceLevel,
      parserVersion: normalized.identity.parserVersion,
      privacyVersion,
      privacyAcceptedAt: now,
      identityVersion,
      verifiedAt: now,
      updatedAt: now,
    }, {merge: false});
    transaction.set(vehicleVerificationReference, {
      schemaVersion,
      status,
      flowState: requiresDeclaration ? "awaiting_declaration" : "verified",
      relation,
      plateNormalized: expectedPlate,
      registrationCountryCode:
        normalized.vehicleRegistration.registrationCountryCode,
      documentProfileVersion:
        normalized.vehicleRegistration.documentProfileVersion,
      identityDocumentDataChecked: true,
      vehicleDocumentDataChecked: true,
      plateMatch: true,
      holderMatch,
      declarationRequired: requiresDeclaration,
      identityVerificationRef: identityReference.path,
      identityVersion,
      declarationId: null,
      verificationMethod,
      assuranceLevel,
      verifiedAt,
      updatedAt: now,
    }, {merge: false});
    transaction.set(vehicleReference, {
      isVerified: !requiresDeclaration,
      verificationStatus: requiresDeclaration ? "inReview" : "verified",
      verificationLocked: requiresDeclaration,
      verificationRejectionReason: null,
      updatedAt: now,
    }, {merge: true});
    transaction.set(profileReference, {
      verificationStatus: "verified",
      verificationRejectionReason: null,
      verificationReviewedAt: now,
      updatedAt: now,
    }, {merge: true});
    transaction.set(publicProfileReference, {
      verificationStatus: "verified",
      isVerified: true,
      updatedAt: now,
    }, {merge: true});
    transaction.set(publicVehicleReference, {
      verificationStatus: requiresDeclaration ? "inReview" : "verified",
      isVerified: !requiresDeclaration,
      updatedAt: now,
    }, {merge: true});
    transaction.set(plateReference, {
      verificationStatus: requiresDeclaration ? "inReview" : "verified",
      isVerified: !requiresDeclaration,
      ownerIdentityVerified: true,
      updatedAt: now,
    }, {merge: true});
    transaction.set(sessionReference, {
      state: requiresDeclaration ? "requires_declaration" : "completed",
      flowState: requiresDeclaration ? "awaiting_declaration" : "verified",
      submissionHash,
      holderMatch,
      attemptCount: Number(session.attemptCount ?? 0) + 1,
      updatedAt: now,
      completedAt: requiresDeclaration ? null : now,
    }, {merge: true});
    return {
      status,
      holderMatch,
      declarationId: null,
      idempotent: false,
      identityChanged,
      currentVehicleId: safeString(session.vehicleId),
    };
  });
  if (result.identityChanged === true) {
    await invalidateSiblings({
      firestore,
      userId,
      currentVehicleId: result.currentVehicleId,
      reason: "identity_core_changed",
      now,
    });
  }
  return {
    status: result.status,
    holderMatch: result.holderMatch,
    declarationId: result.declarationId,
    idempotent: result.idempotent,
  };
}

async function finalizeVehicleDeclaration({
  firestore,
  bucket,
  authContext,
  appContext,
  input,
  now = Timestamp.now(),
  requireAppCheck = true,
  pdfFactory = createVehicleDeclarationPdf,
}) {
  const userId = ensureTrustedCaller(authContext, appContext, {requireAppCheck});
  const sessionId = normalizeId(input?.sessionId, "Session");
  const nonce = safeString(input?.nonce);
  if (safeString(input?.declarationVersion) !== declarationVersion ||
      safeString(input?.privacyVersion) !== privacyVersion) {
    throw new HttpsError("failed-precondition", "Die Erklärung ist nicht mehr aktuell.");
  }
  if (input?.declarationAccepted !== true) {
    throw new HttpsError("failed-precondition", "Bitte bestätige die Eigenerklärung.");
  }
  const signature = normalizeSignature(input?.signature);
  const signatureHash = sha256(stableJson(signature));
  const sessionReference = firestore.doc(`_verification_sessions/${sessionId}`);
  const deletionReference = firestore.doc(`account_deletions/${userId}`);
  const nowDate = asDate(now);

  const reservation = await firestore.runTransaction(async (transaction) => {
    const sessionSnapshot = await transaction.get(sessionReference);
    if (!sessionSnapshot.exists) {
      throw new HttpsError("not-found", "Die Verifizierungssession wurde nicht gefunden.");
    }
    const session = sessionSnapshot.data() ?? {};
    validateSession(session, userId, nonce, nowDate, {allowCompleted: true});
    const vehicleId = normalizeId(session.vehicleId, "Fahrzeug");
    const vehicleReference = firestore.doc(
      `users/${userId}/vehicles/${vehicleId}`,
    );
    const declarationId = sha256(`${userId}:${vehicleId}:${sessionId}`).slice(0, 32);
    const declarationReference = firestore.doc(
      `users/${userId}/verification_declarations/${declarationId}`,
    );
    const identityReference = firestore.doc(
      `users/${userId}/private_verification/identity`,
    );
    const vehicleVerificationReference = firestore.doc(
      `users/${userId}/vehicle_verifications/${vehicleId}`,
    );
    const [
      declarationSnapshot,
      identitySnapshot,
      verificationSnapshot,
      vehicleSnapshot,
      deletionSnapshot,
    ] =
      await Promise.all([
        transaction.get(declarationReference),
        transaction.get(identityReference),
        transaction.get(vehicleVerificationReference),
        transaction.get(vehicleReference),
        transaction.get(deletionReference),
      ]);
    ensureAccountAcceptsVerification(deletionSnapshot);
    if (!vehicleSnapshot.exists ||
        !vehicleIsActiveAndOwned(vehicleSnapshot.data(), userId)) {
      throw new HttpsError(
        "failed-precondition",
        "Das Fahrzeug ist nicht mehr aktiv mit deinem Konto verknüpft.",
        {reason: "vehicle-inactive"},
      );
    }
    if (declarationSnapshot.exists &&
        safeString(declarationSnapshot.data()?.status) === "active") {
      return {
        alreadyFinalized: true,
        declaration: declarationSnapshot.data(),
      };
    }
    if (safeString(session.state) !== "requires_declaration") {
      throw new HttpsError(
        "failed-precondition",
        "Für diese Session ist keine Eigenerklärung offen.",
      );
    }
    if (!identitySnapshot.exists ||
        safeString(identitySnapshot.data()?.status) !== "verified" ||
        !verificationSnapshot.exists ||
        safeString(verificationSnapshot.data()?.status) !== "requires_declaration") {
      throw new HttpsError("failed-precondition", "Der Dokumentabgleich ist nicht vollständig.");
    }
    const identityVersion = safeString(
      identitySnapshot.data()?.identityVersion,
    );
    if (identityVersion.length === 0 ||
        safeString(verificationSnapshot.data()?.identityVersion) !==
          identityVersion) {
      throw new HttpsError(
        "failed-precondition",
        "Die Identitätsverifizierung ist nicht mehr aktuell.",
        {reason: "identity-version-mismatch"},
      );
    }
    const existing = declarationSnapshot.data() ?? {};
    if (declarationSnapshot.exists &&
        safeString(existing.signatureHash) !== signatureHash) {
      throw new HttpsError("already-exists", "Die Erklärung wird bereits verarbeitet.");
    }
    const generationUpdatedAt = asDate(existing.updatedAt);
    if (declarationSnapshot.exists &&
        safeString(existing.status) === "generating" &&
        Number.isFinite(generationUpdatedAt.getTime()) &&
        nowDate.getTime() - generationUpdatedAt.getTime() <
          declarationGenerationLeaseMs) {
      throw new HttpsError(
        "aborted",
        "Die Erklärung wird bereits verarbeitet.",
        {reason: "declaration-in-progress"},
      );
    }
    const acceptedAt = existing.acceptedAt ?? now;
    const plate = safeString(verificationSnapshot.data()?.plateNormalized);
    const plateReference = firestore.doc(`plates/DE_${plate}`);
    const plateSnapshot = await transaction.get(plateReference);
    if (!plateSnapshotMatchesVehicle(plateSnapshot, userId, vehicleId)) {
      throw new HttpsError(
        "failed-precondition",
        "Das Kennzeichen ist nicht mehr diesem Fahrzeug zugeordnet.",
        {reason: "plate-binding-changed"},
      );
    }
    const relation = safeString(verificationSnapshot.data()?.relation);
    const fullName = [
      safeString(identitySnapshot.data()?.verifiedFirstNames),
      safeString(identitySnapshot.data()?.verifiedLastName),
    ].filter(Boolean).join(" ");
    const declarationText = declarationTemplate
      .replace("[VORNAME NACHNAME]", fullName)
      .replace("[KENNZEICHEN]", plate)
      .replace("[FAHRZEUGZUORDNUNG]", relationLabels[relation] ?? relation);
    const declarationTextHash = sha256(declarationText);
    const pdfPath =
      `verification_declarations/${userId}/${vehicleId}/${declarationId}.pdf`;
    transaction.set(declarationReference, {
      schemaVersion,
      declarationId,
      uid: userId,
      vehicleId,
      plateNormalized: plate,
      relation,
      declarationVersion,
      declarationAccepted: true,
      declarationTextHash,
      signatureHash,
      pdfPath,
      pdfSha256: null,
      acceptedAt,
      status: "generating",
      updatedAt: now,
    }, {merge: false});
    return {
      alreadyFinalized: false,
      declarationId,
      declarationReference,
      identityReference,
      vehicleVerificationReference,
      vehicleReference,
      publicVehicleReference: firestore.doc(
        `public_profiles/${userId}/vehicles/${vehicleId}`,
      ),
      plateReference,
      vehicleId,
      plate,
      relation,
      fullName,
      declarationText,
      declarationTextHash,
      pdfPath,
      acceptedAt,
      identityVersion,
    };
  });

  if (reservation.alreadyFinalized) {
    return {
      status: "verified",
      declarationId: reservation.declaration.declarationId,
      pdfPath: reservation.declaration.pdfPath,
      pdfSha256: reservation.declaration.pdfSha256,
      idempotent: true,
    };
  }

  const pdf = await pdfFactory({
    declarationId: reservation.declarationId,
    userReference: sha256(userId).slice(0, 16),
    fullName: reservation.fullName,
    plate: reservation.plate,
    relationLabel: relationLabels[reservation.relation],
    declarationVersion,
    declarationText: reservation.declarationText,
    declarationTextHash: reservation.declarationTextHash,
    acceptedAt: asDate(reservation.acceptedAt),
    signature,
  });
  const pdfFile = bucket.file(reservation.pdfPath);
  let pdfUploaded = false;
  try {
    await pdfFile.save(pdf.bytes, {
      resumable: false,
      validation: "md5",
      metadata: {
        contentType: "application/pdf",
        cacheControl: "private, no-store, max-age=0",
        metadata: {
          declarationId: reservation.declarationId,
          sha256: pdf.sha256,
          schemaVersion: String(schemaVersion),
        },
      },
    });
    pdfUploaded = true;

    await firestore.runTransaction(async (transaction) => {
      const [
        declarationSnapshot,
        sessionSnapshot,
        identitySnapshot,
        verificationSnapshot,
        vehicleSnapshot,
        deletionSnapshot,
        plateSnapshot,
      ] = await Promise.all([
        transaction.get(reservation.declarationReference),
        transaction.get(sessionReference),
        transaction.get(reservation.identityReference),
        transaction.get(reservation.vehicleVerificationReference),
        transaction.get(reservation.vehicleReference),
        transaction.get(deletionReference),
        transaction.get(reservation.plateReference),
      ]);
      ensureAccountAcceptsVerification(deletionSnapshot);
      const current = declarationSnapshot.data() ?? {};
      if (!declarationSnapshot.exists ||
          safeString(current.signatureHash) !== signatureHash ||
          safeString(current.status) !== "generating") {
        throw new HttpsError("aborted", "Die Erklärung wurde parallel verändert.");
      }
      const currentSession = sessionSnapshot.data() ?? {};
      const currentIdentity = identitySnapshot.data() ?? {};
      const currentVerification = verificationSnapshot.data() ?? {};
      const currentVehicle = vehicleSnapshot.data() ?? {};
      const stateStillValid = sessionSnapshot.exists &&
        safeString(currentSession.uid) === userId &&
        safeString(currentSession.vehicleId) === reservation.vehicleId &&
        safeString(currentSession.state) === "requires_declaration" &&
        identitySnapshot.exists &&
        safeString(currentIdentity.status) === "verified" &&
        safeString(currentIdentity.identityVersion) ===
          reservation.identityVersion &&
        verificationSnapshot.exists &&
        safeString(currentVerification.status) === "requires_declaration" &&
        safeString(currentVerification.identityVersion) ===
          reservation.identityVersion &&
        normalizePlate(currentVerification.plateNormalized) ===
          reservation.plate &&
        safeString(currentVerification.relation) === reservation.relation &&
        vehicleSnapshot.exists &&
        vehicleIsActiveAndOwned(currentVehicle, userId) &&
        plateSnapshotMatchesVehicle(
          plateSnapshot,
          userId,
          reservation.vehicleId,
        );
      if (!stateStillValid) {
        throw new HttpsError(
          "aborted",
          "Die Verifizierung wurde während der Verarbeitung geändert.",
          {reason: "verification-state-changed"},
        );
      }
      transaction.set(reservation.declarationReference, {
        status: "active",
        pdfSha256: pdf.sha256,
        signatureHash: null,
        updatedAt: now,
      }, {merge: true});
      transaction.set(reservation.vehicleVerificationReference, {
        status: "verified",
        flowState: "verified",
        declarationId: reservation.declarationId,
        verifiedAt: now,
        updatedAt: now,
      }, {merge: true});
      transaction.set(reservation.vehicleReference, {
        isVerified: true,
        verificationStatus: "verified",
        verificationLocked: false,
        verificationRejectionReason: null,
        updatedAt: now,
      }, {merge: true});
      transaction.set(reservation.publicVehicleReference, {
        isVerified: true,
        verificationStatus: "verified",
        updatedAt: now,
      }, {merge: true});
      transaction.set(reservation.plateReference, {
        isVerified: true,
        verificationStatus: "verified",
        ownerIdentityVerified: true,
        updatedAt: now,
      }, {merge: true});
      transaction.set(sessionReference, {
        state: "completed",
        flowState: "verified",
        declarationId: reservation.declarationId,
        completedAt: now,
        updatedAt: now,
      }, {merge: true});
    });
  } catch (error) {
    if (pdfUploaded) await deleteStorageFileBestEffort(pdfFile);
    throw error;
  }
  return {
    status: "verified",
    declarationId: reservation.declarationId,
    pdfPath: reservation.pdfPath,
    pdfSha256: pdf.sha256,
    idempotent: false,
  };
}

async function revokeOrInvalidateVerification({
  firestore,
  authContext,
  appContext,
  input,
  now = Timestamp.now(),
  requireAppCheck = true,
}) {
  const userId = ensureTrustedCaller(authContext, appContext, {requireAppCheck});
  const vehicleId = normalizeId(input?.vehicleId, "Fahrzeug");
  const reason = safeString(input?.reason);
  if (!["authorization_ended", "vehicle_removed", "user_requested"].includes(reason)) {
    throw new HttpsError("invalid-argument", "Der Widerrufsgrund ist ungültig.");
  }
  const vehicleReference = firestore.doc(`users/${userId}/vehicles/${vehicleId}`);
  const verificationReference = firestore.doc(
    `users/${userId}/vehicle_verifications/${vehicleId}`,
  );
  const deletionReference = firestore.doc(`account_deletions/${userId}`);
  await firestore.runTransaction(async (transaction) => {
    const [vehicleSnapshot, verificationSnapshot, deletionSnapshot] =
      await Promise.all([
      transaction.get(vehicleReference),
      transaction.get(verificationReference),
      transaction.get(deletionReference),
    ]);
    ensureAccountAcceptsVerification(deletionSnapshot);
    if (!vehicleSnapshot.exists ||
        safeString(vehicleSnapshot.data()?.ownerUserId) !== userId) {
      throw new HttpsError("permission-denied", "Dieses Fahrzeug gehört nicht zu deinem Konto.");
    }
    const declarationId = safeString(
      verificationSnapshot.data()?.declarationId,
    );
    const declarationReference = declarationId.length === 0 ? null :
      firestore.doc(
        `users/${userId}/verification_declarations/${declarationId}`,
      );
    const declarationSnapshot = declarationReference == null ? null :
      await transaction.get(declarationReference);
    const plateNormalized = normalizePlate(
      verificationSnapshot.data()?.plateNormalized,
    );
    const plateReference = plateNormalized.length === 0 ? null :
      firestore.doc(`plates/DE_${plateNormalized}`);
    const plateSnapshot = plateReference == null ? null :
      await transaction.get(plateReference);
    transaction.set(verificationReference, {
      status: "revoked",
      flowState: "reverification_required",
      revokedReason: reason,
      revokedAt: now,
      updatedAt: now,
    }, {merge: true});
    transaction.set(vehicleReference, {
      isVerified: false,
      verificationStatus: "unverified",
      verificationLocked: false,
      updatedAt: now,
    }, {merge: true});
    transaction.set(
      firestore.doc(`public_profiles/${userId}/vehicles/${vehicleId}`),
      {
        isVerified: false,
        verificationStatus: "unverified",
        updatedAt: now,
      },
      {merge: true},
    );
    if (plateSnapshotMatchesVehicle(plateSnapshot, userId, vehicleId)) {
      transaction.set(plateReference, {
        isVerified: false,
        verificationStatus: "unverified",
        updatedAt: now,
      }, {merge: true});
    }
    if (declarationSnapshot?.exists === true) {
      transaction.set(declarationReference, {
        status: "revoked",
        revokedReason: reason,
        revokedAt: now,
        updatedAt: now,
      }, {merge: true});
    }
  });
  return {status: "revoked", vehicleId};
}

async function expireIdentityVerifications({
  firestore,
  now = Timestamp.now(),
  pageSize = 200,
}) {
  const today = dateOnlyString(utcDateOnly(asDate(now)));
  const snapshot = await firestore.collectionGroup("private_verification")
    .where("status", "==", "verified")
    .where("documentExpiresAt", "<", today)
    .limit(pageSize)
    .get();
  let identityCount = 0;
  let vehicleCount = 0;
  for (const identityDocument of snapshot.docs) {
    const match = /^users\/([^/]+)\/private_verification\/identity$/u
      .exec(identityDocument.ref.path);
    if (match == null) continue;
    let result;
    try {
      result = await invalidateAllVehicleVerifications({
        firestore,
        userId: match[1],
        identityReference: identityDocument.ref,
        identityUpdateTime: identityDocument.updateTime,
        reason: "identity_document_expired",
        now,
      });
    } catch (error) {
      if (isStaleVerificationSnapshotError(error)) continue;
      throw error;
    }
    identityCount += 1;
    vehicleCount += result.vehicleCount;
  }
  return {identityCount, vehicleCount, hasMore: snapshot.size === pageSize};
}

async function invalidateSiblingVehicleVerifications({
  firestore,
  userId,
  currentVehicleId,
  reason,
  now,
}) {
  return invalidateAllVehicleVerifications({
    firestore,
    userId,
    excludedVehicleId: currentVehicleId,
    reason,
    now,
  });
}

async function invalidateAllVehicleVerifications({
  firestore,
  userId,
  identityReference = null,
  identityUpdateTime = null,
  excludedVehicleId = null,
  reason,
  now,
}) {
  const snapshot = await firestore
    .collection(`users/${userId}/vehicle_verifications`)
    .where("status", "in", ["verified", "requires_declaration"])
    .get();
  const active = snapshot.docs.filter((document) =>
    document.id !== excludedVehicleId,
  );
  const declarationReferences = active
    .map((document) => safeString(document.data()?.declarationId))
    .filter(Boolean)
    .map((declarationId) => firestore.doc(
      `users/${userId}/verification_declarations/${declarationId}`,
    ));
  const declarationSnapshots = await Promise.all(
    declarationReferences.map((reference) => reference.get()),
  );
  const plateEntries = active
    .map((document) => ({
      vehicleId: document.id,
      plateNormalized: normalizePlate(document.data()?.plateNormalized),
    }))
    .filter((entry) => entry.plateNormalized.length > 0)
    .map((entry) => ({
      ...entry,
      reference: firestore.doc(`plates/DE_${entry.plateNormalized}`),
    }));
  const plateSnapshots = await Promise.all(
    plateEntries.map((entry) => entry.reference.get()),
  );
  const batch = firestore.batch();
  if (identityReference != null) {
    batch.update(identityReference, {
      status: "expired",
      flowState: "reverification_required",
      invalidatedReason: reason,
      invalidatedAt: now,
      updatedAt: now,
    }, {lastUpdateTime: requireUpdateTime(identityUpdateTime, "identity")});
    batch.set(firestore.doc(`users/${userId}/profiles/main`), {
      verificationStatus: "expired",
      verificationRejectionReason: reason,
      updatedAt: now,
    }, {merge: true});
    batch.set(firestore.doc(`public_profiles/${userId}`), {
      verificationStatus: "expired",
      isVerified: false,
      updatedAt: now,
    }, {merge: true});
  }
  for (const document of active) {
    batch.update(document.ref, {
      status: "invalidated",
      flowState: "reverification_required",
      invalidatedReason: reason,
      invalidatedAt: now,
      updatedAt: now,
    }, {lastUpdateTime: requireUpdateTime(document.updateTime, "vehicle verification")});
    batch.set(firestore.doc(`users/${userId}/vehicles/${document.id}`), {
      isVerified: false,
      verificationStatus: "unverified",
      verificationLocked: false,
      updatedAt: now,
    }, {merge: true});
    batch.set(
      firestore.doc(`public_profiles/${userId}/vehicles/${document.id}`),
      {
        isVerified: false,
        verificationStatus: "unverified",
        updatedAt: now,
      },
      {merge: true},
    );
  }
  for (let index = 0; index < plateEntries.length; index += 1) {
    const entry = plateEntries[index];
    const plateSnapshot = plateSnapshots[index];
    if (plateSnapshotMatchesVehicle(plateSnapshot, userId, entry.vehicleId)) {
      batch.update(entry.reference, {
        isVerified: false,
        verificationStatus: "unverified",
        ...(identityReference != null ? {ownerIdentityVerified: false} : {}),
        updatedAt: now,
      }, {
        lastUpdateTime: requireUpdateTime(
          plateSnapshot.updateTime,
          "plate projection",
        ),
      });
    }
  }
  for (const declaration of declarationSnapshots) {
    if (!declaration.exists) continue;
    batch.update(declaration.ref, {
      status: "revoked",
      revokedReason: reason,
      revokedAt: now,
      updatedAt: now,
    }, {
      lastUpdateTime: requireUpdateTime(
        declaration.updateTime,
        "verification declaration",
      ),
    });
  }
  await batch.commit();
  return {vehicleCount: active.length};
}

function requireUpdateTime(updateTime, label) {
  if (updateTime != null) return updateTime;
  throw new Error(`Missing update time for ${label}.`);
}

function isStaleVerificationSnapshotError(error) {
  return error?.code === 9 ||
    error?.code === 10 ||
    error?.code === "failed-precondition" ||
    error?.code === "aborted";
}

function identityCoreChanged(previous, next) {
  if (previous == null) return false;
  return normalizePersonName(previous.verifiedFirstNames) !==
      normalizePersonName(next.firstNames) ||
    normalizePersonName(previous.verifiedLastName) !==
      normalizePersonName(next.lastName) ||
    safeString(previous.dateOfBirth) !== dateOnlyString(next.dateOfBirth) ||
    (safeString(previous.documentType).length > 0 &&
      safeString(previous.documentType) !== next.documentType) ||
    (safeString(previous.issuingCountryCode).length > 0 &&
      safeString(previous.issuingCountryCode) !== next.issuingCountryCode);
}

function normalizeSignature(value) {
  if (value == null || typeof value !== "object" || !Array.isArray(value.strokes)) {
    throw new HttpsError("invalid-argument", "Bitte unterschreibe die Eigenerklärung.");
  }
  if (value.strokes.length === 0 || value.strokes.length > 30) {
    throw new HttpsError("invalid-argument", "Die Unterschrift ist leer oder zu groß.");
  }
  let pointCount = 0;
  let minX = 1;
  let maxX = 0;
  let minY = 1;
  let maxY = 0;
  const strokes = value.strokes.map((stroke) => {
    if (!Array.isArray(stroke) || stroke.length < 2 || stroke.length > 300) {
      throw new HttpsError("invalid-argument", "Die Unterschrift ist ungültig.");
    }
    return stroke.map((point) => {
      const x = Number(point?.x);
      const y = Number(point?.y);
      if (!Number.isFinite(x) || !Number.isFinite(y) ||
          x < 0 || x > 1 || y < 0 || y > 1) {
        throw new HttpsError("invalid-argument", "Die Unterschrift ist ungültig.");
      }
      pointCount += 1;
      minX = Math.min(minX, x);
      maxX = Math.max(maxX, x);
      minY = Math.min(minY, y);
      maxY = Math.max(maxY, y);
      return {x: roundedPoint(x), y: roundedPoint(y)};
    });
  });
  if (pointCount < 8 || (maxX - minX) * (maxY - minY) < 0.004) {
    throw new HttpsError("invalid-argument", "Die Unterschrift ist zu kurz.");
  }
  return {strokes};
}

function validateSession(session, userId, nonce, nowDate, {allowCompleted = false} = {}) {
  if (safeString(session.uid) !== userId) {
    throw new HttpsError("permission-denied", "Diese Session gehört nicht zu deinem Konto.");
  }
  if (safeString(session.nonceHash) !== sha256(nonce)) {
    throw new HttpsError("permission-denied", "Die Session-Bestätigung ist ungültig.");
  }
  const expiresAt = asDate(session.expiresAt);
  const state = safeString(session.state);
  if (expiresAt.getTime() < nowDate.getTime() &&
      !(allowCompleted && state === "completed")) {
    throw new HttpsError("deadline-exceeded", "Die Session ist abgelaufen.", {
      reason: "session-expired",
    });
  }
}

function holderMatches(identity, registration) {
  const lastNameMatches = normalizePersonName(identity.lastName) ===
    normalizePersonName(registration.holderNameOrCompany);
  if (!lastNameMatches || registration.holderFirstNames == null) return false;
  return conservativeFirstNamesMatch(
    identity.firstNames,
    registration.holderFirstNames,
  );
}

function conservativeFirstNamesMatch(left, right) {
  const leftTokens = normalizePersonName(left).split(" ").filter(Boolean);
  const rightTokens = normalizePersonName(right).split(" ").filter(Boolean);
  if (leftTokens.length === 0 || rightTokens.length === 0 ||
      leftTokens[0] !== rightTokens[0]) return false;
  return isOrderedSubset(leftTokens, rightTokens) ||
    isOrderedSubset(rightTokens, leftTokens);
}

function normalizePersonName(value) {
  return safeString(value)
    .normalize("NFC")
    .toLocaleLowerCase("de-DE")
    .replaceAll("ä", "ae")
    .replaceAll("ö", "oe")
    .replaceAll("ü", "ue")
    .replaceAll("ß", "ss")
    .replaceAll("ı", "i")
    .replace(/[’`´]/gu, "'")
    .replace(/\s*-\s*/gu, "-")
    .replace(/\s*'\s*/gu, "'")
    .replace(/\s+/gu, " ")
    .trim();
}

function normalizePlate(value) {
  return safeString(value).toUpperCase().replace(/[\s-]+/gu, "")
    .replace(/[^A-ZÄÖÜ0-9]/gu, "");
}

function plateFromVehicle(vehicle) {
  const country = safeString(vehicle.countryCode).toUpperCase();
  if (country !== "DE") return "";
  return normalizePlate(
    `${safeString(vehicle.plateRegion)}${safeString(vehicle.plateLetters)}` +
    safeString(vehicle.plateNumbers),
  );
}

function parseDateOnly(value, fieldName) {
  const raw = safeString(value);
  const match = /^(\d{4})-(\d{2})-(\d{2})$/u.exec(raw);
  if (match == null) {
    throw new HttpsError("invalid-argument", `${fieldName} ist ungültig.`);
  }
  const parsed = new Date(Date.UTC(
    Number(match[1]), Number(match[2]) - 1, Number(match[3]),
  ));
  if (parsed.getUTCFullYear() !== Number(match[1]) ||
      parsed.getUTCMonth() !== Number(match[2]) - 1 ||
      parsed.getUTCDate() !== Number(match[3])) {
    throw new HttpsError("invalid-argument", `${fieldName} ist ungültig.`);
  }
  return parsed;
}

function ageOn(birthDate, currentDate) {
  let age = currentDate.getUTCFullYear() - birthDate.getUTCFullYear();
  if (currentDate.getUTCMonth() < birthDate.getUTCMonth() ||
      (currentDate.getUTCMonth() === birthDate.getUTCMonth() &&
       currentDate.getUTCDate() < birthDate.getUTCDate())) age -= 1;
  return age;
}

function utcDateOnly(value) {
  const date = asDate(value);
  return new Date(Date.UTC(
    date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(),
  ));
}

function dateOnlyString(value) {
  return `${value.getUTCFullYear().toString().padStart(4, "0")}-` +
    `${(value.getUTCMonth() + 1).toString().padStart(2, "0")}-` +
    value.getUTCDate().toString().padStart(2, "0");
}

function normalizedAttempts(value, nowDate) {
  if (!Array.isArray(value)) return [];
  const dayStart = nowDate.getTime() - 24 * 60 * 60 * 1000;
  return value.map(asDate).filter((date) =>
    Number.isFinite(date.getTime()) && date.getTime() >= dayStart);
}

function normalizeDisplayName(value, fieldName) {
  const result = safeString(value).replace(/\s+/gu, " ");
  if (result.length < 1 || result.length > 120 || /[\u0000-\u001F]/u.test(result)) {
    throw new HttpsError("invalid-argument", `${fieldName} ist ungültig.`);
  }
  return result;
}

function normalizeParserVersion(value) {
  const result = safeString(value);
  if (!/^[a-z0-9_.-]{3,80}$/u.test(result)) {
    throw new HttpsError("invalid-argument", "Die Parser-Version ist ungültig.");
  }
  return result;
}

function normalizeId(value, label) {
  const result = safeString(value);
  if (!/^[A-Za-z0-9_-]{1,128}$/u.test(result)) {
    throw new HttpsError("invalid-argument", `${label} ist ungültig.`);
  }
  return result;
}

function serializeIdentityForHash(identity) {
  return {
    firstNames: identity.firstNames,
    lastName: identity.lastName,
    dateOfBirth: dateOnlyString(identity.dateOfBirth),
    expiresAt: dateOnlyString(identity.expiresAt),
    documentType: identity.documentType,
    parserVersion: identity.parserVersion,
    issuingCountryCode: identity.issuingCountryCode,
    documentProfileVersion: identity.documentProfileVersion,
  };
}

function stableJson(value) {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;
  if (value != null && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) =>
      `${JSON.stringify(key)}:${stableJson(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

function isOrderedSubset(shorter, longer) {
  if (shorter.length > longer.length) return false;
  let cursor = 0;
  for (const token of longer) {
    if (cursor < shorter.length && token === shorter[cursor]) cursor += 1;
  }
  return cursor === shorter.length;
}

function asDate(value) {
  if (value instanceof Date) return value;
  if (typeof value?.toDate === "function") return value.toDate();
  if (typeof value === "string" || typeof value === "number") return new Date(value);
  return new Date(Number.NaN);
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

async function deleteStorageFileBestEffort(file) {
  try {
    await file.delete({ignoreNotFound: true});
  } catch (_) {
    // Account cleanup and bucket lifecycle remain the final retry boundary.
  }
}

function roundedPoint(value) {
  return Math.round(value * 10000) / 10000;
}

module.exports = {
  assuranceLevel,
  createVerificationSession,
  declarationTemplate,
  declarationVersion,
  expireIdentityVerifications,
  finalizeVehicleDeclaration,
  holderMatches,
  identityCoreChanged,
  normalizeCreateSessionInput,
  normalizeIdentityInput,
  normalizePersonName,
  normalizePlate,
  normalizeRelation,
  normalizeSignature,
  normalizeSubmissionInput,
  normalizeVehicleRegistrationInput,
  privacyVersion,
  revokeOrInvalidateVerification,
  submitVerificationData,
  validateIdentity,
  validateIdentityProfile,
  verificationMethod,
};
