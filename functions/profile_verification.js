const {createHash} = require("node:crypto");
const {Timestamp} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");
const {HttpsError} = require("firebase-functions/v2/https");

const requiredDocumentKeys = [
  "identityFront",
  "identityBack",
  "driverLicenseFront",
  "driverLicenseBack",
  "vehicleFront",
  "vehicleBack",
];
const requiredExpirationKeys = ["identity", "driverLicense"];
const documentGroups = {
  identity: ["identityFront", "identityBack"],
  driverLicense: ["driverLicenseFront", "driverLicenseBack"],
  vehicle: ["vehicleFront", "vehicleBack"],
};
const allowedIdentityDocumentTypes = [
  "identityCard",
  "passport",
  "residencePermit",
];
const allowedRelationships = [
  "owner",
  "leasingCompany",
  "authorizedUser",
];
const consentVersion = "verification-consent-1.0";
const maxDocumentBytes = 12 * 1024 * 1024;
const retentionDays = 30;

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function technicalErrorType(error) {
  const code = safeString(error?.code);
  if (code.length > 0) return code.slice(0, 80);
  return safeString(error?.constructor?.name).slice(0, 80) || "Error";
}

function timestampMillis(value) {
  if (value != null && typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (value instanceof Date) return value.getTime();
  return Number.NaN;
}

function requiredKeysForIdentityType(identityDocumentType) {
  return requiredDocumentKeys.filter((key) =>
    identityDocumentType !== "passport" || key !== "identityBack");
}

function keysForGroup(group, identityDocumentType) {
  return (documentGroups[group] ?? []).filter((key) =>
    identityDocumentType !== "passport" || key !== "identityBack");
}

function expirationKeyForGroup(group) {
  return group === "identity" || group === "driverLicense" ? group : null;
}

function validateDocumentExpirations(expirations, now, keys = requiredExpirationKeys) {
  const nowMillis = timestampMillis(now);
  const normalized = {};
  for (const key of keys) {
    const value = expirations?.[key];
    const millis = timestampMillis(value);
    if (!Number.isFinite(millis) || millis <= nowMillis) {
      throw new HttpsError(
          "failed-precondition",
          "Bitte gib für die einzureichenden Nachweise ein gültiges Ablaufdatum ein.",
      );
    }
    normalized[key] = value;
  }
  return normalized;
}

function normalizeVehicleRelationship(value) {
  const normalized = safeString(value);
  return normalized === "leasingCompanyFamily" ?
    "leasingCompany" : normalized;
}

function expectedDocumentPath(userId, documentKey) {
  return `profile_documents/${userId}/${documentKey}/${documentKey}.png`;
}

function allowedDocumentPaths(userId, documentKey) {
  const prefix = `profile_documents/${userId}/${documentKey}/${documentKey}`;
  return [`${prefix}.png`, `${prefix}.jpg`];
}

function normalizeSubmissionInput(userId, input) {
  const requestId = safeString(input?.requestId);
  const vehicleId = safeString(input?.vehicleId);
  const vehicleRelationship = normalizeVehicleRelationship(
      input?.vehicleRelationship,
  );
  const acceptedConsentVersion = safeString(input?.consentVersion);
  const identityDocumentType = safeString(input?.identityDocumentType) ||
    "identityCard";
  if (requestId !== userId || vehicleId.length === 0 || vehicleId.length > 160) {
    throw new HttpsError(
      "invalid-argument",
      "Die Verifizierung konnte nicht eindeutig zugeordnet werden.",
    );
  }
  if (!allowedRelationships.includes(vehicleRelationship)) {
    throw new HttpsError(
      "invalid-argument",
      "Bitte wähle aus, in welcher Beziehung du zum Fahrzeug stehst.",
    );
  }
  if (input?.authorizationConfirmed !== true ||
      acceptedConsentVersion !== consentVersion) {
    throw new HttpsError(
      "failed-precondition",
      "Bitte bestätige deine Berechtigung und die Datenschutzhinweise.",
    );
  }
  if (input?.vehicleAssignmentConfirmed !== true) {
    throw new HttpsError(
        "failed-precondition",
        "Bitte bestätige, welches Fahrzeug geprüft werden soll.",
    );
  }
  if (!allowedIdentityDocumentTypes.includes(identityDocumentType)) {
    throw new HttpsError(
        "invalid-argument",
        "Bitte wähle einen gültigen Identitätsnachweis aus.",
    );
  }
  return {
    requestId,
    vehicleId,
    vehicleRelationship,
    identityDocumentType,
  };
}

function isJpegHeader(buffer) {
  return Buffer.isBuffer(buffer) && buffer.length >= 3 &&
    buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
}

function inspectJpeg(buffer) {
  if (!isJpegHeader(buffer) || buffer.length < 16 ||
      buffer[buffer.length - 2] !== 0xff ||
      buffer[buffer.length - 1] !== 0xd9) {
    return {valid: false, hasExif: false, width: 0, height: 0};
  }
  const startOfFrameMarkers = new Set([
    0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7,
    0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf,
  ]);
  let offset = 2;
  let width = 0;
  let height = 0;
  let hasExif = false;
  let hasScan = false;

  while (offset < buffer.length - 1) {
    if (buffer[offset] !== 0xff) {
      if (hasScan) break;
      return {valid: false, hasExif, width, height};
    }
    while (offset < buffer.length && buffer[offset] === 0xff) offset += 1;
    if (offset >= buffer.length) break;
    const marker = buffer[offset];
    offset += 1;
    if (marker === 0xd9) break;
    if (marker === 0xd8 || marker === 0x01 ||
        (marker >= 0xd0 && marker <= 0xd7)) {
      continue;
    }
    if (offset + 2 > buffer.length) {
      return {valid: false, hasExif, width, height};
    }
    const segmentLength = buffer.readUInt16BE(offset);
    if (segmentLength < 2 || offset + segmentLength > buffer.length) {
      return {valid: false, hasExif, width, height};
    }
    const payloadStart = offset + 2;
    const payloadLength = segmentLength - 2;
    if (marker === 0xe1 && payloadLength >= 6 &&
        buffer.subarray(payloadStart, payloadStart + 6)
            .equals(Buffer.from("Exif\0\0", "binary"))) {
      hasExif = true;
    }
    if (startOfFrameMarkers.has(marker)) {
      if (payloadLength < 5) {
        return {valid: false, hasExif, width, height};
      }
      height = buffer.readUInt16BE(payloadStart + 1);
      width = buffer.readUInt16BE(payloadStart + 3);
    }
    offset += segmentLength;
    if (marker === 0xda) {
      hasScan = true;
      break;
    }
  }

  const pixelCount = width * height;
  return {
    valid: hasScan && width > 0 && height > 0 &&
      width <= 12000 && height <= 12000 && pixelCount <= 80000000,
    hasExif,
    width,
    height,
  };
}

function isPngHeader(buffer) {
  const signature = Buffer.from([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
  ]);
  return Buffer.isBuffer(buffer) && buffer.length >= signature.length &&
    buffer.subarray(0, signature.length).equals(signature);
}

function inspectPng(buffer) {
  if (!isPngHeader(buffer) || buffer.length < 33) {
    return {valid: false, hasExif: false, width: 0, height: 0};
  }
  let offset = 8;
  let width = 0;
  let height = 0;
  let hasExif = false;
  let hasHeader = false;
  let hasEnd = false;
  while (offset + 12 <= buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const typeStart = offset + 4;
    const dataStart = offset + 8;
    const chunkEnd = dataStart + length + 4;
    if (chunkEnd > buffer.length) {
      return {valid: false, hasExif, width, height};
    }
    const type = buffer.toString("ascii", typeStart, typeStart + 4);
    if (!hasHeader) {
      if (type !== "IHDR" || length !== 13) {
        return {valid: false, hasExif, width, height};
      }
      width = buffer.readUInt32BE(dataStart);
      height = buffer.readUInt32BE(dataStart + 4);
      hasHeader = true;
    }
    if (type === "eXIf") hasExif = true;
    if (type === "IEND") {
      if (length !== 0) {
        return {valid: false, hasExif, width, height};
      }
      hasEnd = true;
      offset = chunkEnd;
      break;
    }
    offset = chunkEnd;
  }
  const pixelCount = width * height;
  return {
    valid: hasHeader && hasEnd && offset === buffer.length &&
      width > 0 && height > 0 && width <= 12000 && height <= 12000 &&
      pixelCount <= 80000000,
    hasExif,
    width,
    height,
  };
}

async function validateStoredDocuments({
  bucket,
  userId,
  paths,
  documentKeys = requiredDocumentKeys,
}) {
  for (const documentKey of documentKeys) {
    const expectedPath = safeString(paths?.[documentKey]);
    if (!allowedDocumentPaths(userId, documentKey).includes(expectedPath)) {
      throw new HttpsError(
        "failed-precondition",
        "Bitte lade für alle Nachweise Vorder- und Rückseite vollständig hoch.",
      );
    }
    const file = bucket.file(expectedPath);
    const [exists] = await file.exists();
    if (!exists) {
      throw new HttpsError(
        "failed-precondition",
        "Ein ausgewählter Nachweis ist nicht mehr verfügbar. Bitte lade ihn erneut hoch.",
      );
    }
    const [metadata] = await file.getMetadata();
    const size = Number(metadata.size ?? 0);
    const isPng = expectedPath.endsWith(".png") &&
      metadata.contentType === "image/png";
    const isJpeg = expectedPath.endsWith(".jpg") &&
      metadata.contentType === "image/jpeg";
    if ((!isPng && !isJpeg) || size <= 0 || size >= maxDocumentBytes) {
      throw new HttpsError(
        "invalid-argument",
        "Ein Nachweis hat ein ungültiges Dateiformat oder ist zu groß.",
      );
    }
    const [content] = await file.download();
    const inspection = isPng ? inspectPng(content) : inspectJpeg(content);
    if (!inspection.valid) {
      throw new HttpsError(
        "invalid-argument",
        "Ein Nachweis ist keine gültige Bilddatei.",
      );
    }
    if (inspection.hasExif) {
      throw new HttpsError(
        "invalid-argument",
        "Ein Nachweis enthält noch Metadaten. Bitte bereite das Bild erneut vor.",
      );
    }
  }
}

function hasRequiredProfileData(profile) {
  return safeString(profile?.firstName).length > 0 &&
    safeString(profile?.lastName).length > 0 &&
    profile?.birthDate != null &&
    profile?.personalDataLocked === true;
}

function hasRequiredVehicleData(vehicle) {
  return safeString(vehicle?.brand).length > 0 &&
    safeString(vehicle?.model).length > 0 &&
    ["DE", "AT", "CH"].includes(safeString(vehicle?.countryCode)) &&
    safeString(vehicle?.plateRegion).length > 0 &&
    safeString(vehicle?.plateNumbers).length > 0;
}

function plateDocumentId(vehicle) {
  const country = safeString(vehicle?.countryCode).toUpperCase();
  const plateKey = [
    vehicle?.plateRegion,
    vehicle?.plateLetters,
    vehicle?.plateNumbers,
  ].map((part) => safeString(part).toUpperCase())
      .join("")
      .replace(/[^A-ZÄÖÜ0-9]/g, "");
  return country.length > 0 && plateKey.length > 0 ? `${country}_${plateKey}` : "";
}

function submissionFingerprint({
  userId,
  vehicleId,
  relationship,
  paths,
  expirations,
  identityDocumentType = "identityCard",
  documentKeys = requiredDocumentKeys,
}) {
  const expirationMillis = Object.fromEntries(
      requiredExpirationKeys.map((key) => [
        key,
        timestampMillis(expirations?.[key]),
      ]),
  );
  return createHash("sha256")
      .update(JSON.stringify({
        userId,
        vehicleId,
        relationship,
        paths,
        expirations: expirationMillis,
        identityDocumentType,
        documentKeys,
      }))
      .digest("hex");
}

function submissionGroupsForDraft(draft, identityDocumentType) {
  const statuses = draft?.documentStatuses ?? {};
  return Object.keys(documentGroups).filter((group) =>
    keysForGroup(group, identityDocumentType)
        .every((key) => safeString(statuses[key]) === "uploaded"));
}

function hasReviewedDocumentStatus(draft) {
  return Object.values(draft?.documentStatuses ?? {}).some((status) =>
    ["verified", "rejected", "expired"].includes(safeString(status)));
}

function documentKeysForGroups(groups, identityDocumentType) {
  return groups.flatMap((group) =>
    keysForGroup(group, identityDocumentType));
}

function allRequiredDocumentsVerified(statuses, identityDocumentType) {
  return requiredKeysForIdentityType(identityDocumentType)
      .every((key) => safeString(statuses?.[key]) === "verified");
}

function verificationStagesFromStatuses(statuses, identityDocumentType) {
  return Object.fromEntries(Object.keys(documentGroups).map((group) => [
    group,
    keysForGroup(group, identityDocumentType)
        .every((key) => safeString(statuses?.[key]) === "verified"),
  ]));
}

async function submitProfileVerification({
  firestore,
  bucket,
  authContext,
  input,
  now,
}) {
  const userId = safeString(authContext?.uid);
  if (userId.length === 0) {
    throw new HttpsError("unauthenticated", "Bitte melde dich erneut an.");
  }
  const normalized = normalizeSubmissionInput(userId, input);
  const requestReference = firestore.doc(`verification_requests/${userId}`);
  const profileReference = firestore.doc(`users/${userId}/profiles/main`);
  const vehicleReference = firestore.doc(
      `users/${userId}/vehicles/${normalized.vehicleId}`,
  );
  const publicVehicleReference = firestore.doc(
      `public_profiles/${userId}/vehicles/${normalized.vehicleId}`,
  );
  const publicProfileReference = firestore.doc(`public_profiles/${userId}`);

  const [requestSnapshot, profileSnapshot, vehicleSnapshot] = await Promise.all([
    requestReference.get(),
    profileReference.get(),
    vehicleReference.get(),
  ]);
  if (!profileSnapshot.exists || !hasRequiredProfileData(profileSnapshot.data())) {
    throw new HttpsError(
      "failed-precondition",
      "Bitte vervollständige und speichere zuerst deine persönlichen Daten.",
    );
  }
  if (!vehicleSnapshot.exists || !hasRequiredVehicleData(vehicleSnapshot.data())) {
    throw new HttpsError(
      "failed-precondition",
      "Bitte hinterlege zuerst ein vollständiges Fahrzeug mit Kennzeichen.",
    );
  }
  const initialVehicle = vehicleSnapshot.data();
  if (safeString(initialVehicle.ownerUserId) !== userId ||
      safeString(initialVehicle.status) === "archived") {
    throw new HttpsError(
      "failed-precondition",
      "Das ausgewählte Fahrzeug ist nicht für die Verifizierung verfügbar.",
    );
  }
  const draft = requestSnapshot.data() ?? {};
  const identityDocumentType = safeString(draft.identityDocumentType) ||
    "identityCard";
  if (identityDocumentType !== normalized.identityDocumentType) {
    throw new HttpsError(
        "aborted",
        "Der Dokumenttyp wurde zwischenzeitlich geändert. Bitte versuche es erneut.",
    );
  }
  if (safeString(draft.status) === "pending") {
    const storedGroups = Array.isArray(draft.submittedDocumentGroups) ?
      draft.submittedDocumentGroups.filter((group) =>
        Object.hasOwn(documentGroups, group)) : [];
    const storedKeys = documentKeysForGroups(
        storedGroups,
        identityDocumentType,
    );
    const storedExpirations = validateDocumentExpirations(
        draft.documentExpiresAt,
        now,
    );
    const retryFingerprint = submissionFingerprint({
      userId,
      vehicleId: normalized.vehicleId,
      relationship: normalized.vehicleRelationship,
      paths: draft.documentStoragePaths ?? {},
      expirations: storedExpirations,
      identityDocumentType,
      documentKeys: storedKeys,
    });
    if (storedKeys.length > 0 &&
        safeString(draft.submissionFingerprint) === retryFingerprint) {
      return {requestId: userId, status: "pending", idempotent: true};
    }
    throw new HttpsError(
        "failed-precondition",
        "Deine Verifizierung wird bereits geprüft.",
    );
  }
  const submittedDocumentGroups = submissionGroupsForDraft(
      draft,
      identityDocumentType,
  );
  if (submittedDocumentGroups.length === 0) {
    throw new HttpsError(
        "failed-precondition",
        "Bitte lade die einzureichenden Nachweise vollständig hoch.",
    );
  }
  if (!hasReviewedDocumentStatus(draft) &&
      submittedDocumentGroups.length !== Object.keys(documentGroups).length) {
    throw new HttpsError(
        "failed-precondition",
        "Bitte lade für die erste Prüfung alle erforderlichen Nachweise hoch.",
    );
  }
  const submittedDocumentKeys = documentKeysForGroups(
      submittedDocumentGroups,
      identityDocumentType,
  );
  const documentStoragePaths = draft.documentStoragePaths ?? {};
  const documentExpiresAt = validateDocumentExpirations(
      draft.documentExpiresAt,
      now,
  );
  await validateStoredDocuments({
    bucket,
    userId,
    paths: documentStoragePaths,
    documentKeys: submittedDocumentKeys,
  });

  const submittedAt = now;
  const fingerprint = submissionFingerprint({
    userId,
    vehicleId: normalized.vehicleId,
    relationship: normalized.vehicleRelationship,
    paths: documentStoragePaths,
    expirations: documentExpiresAt,
    identityDocumentType,
    documentKeys: submittedDocumentKeys,
  });

  return firestore.runTransaction(async (transaction) => {
    const currentRequestSnapshot = await transaction.get(requestReference);
    const currentProfileSnapshot = await transaction.get(profileReference);
    const currentVehicleSnapshot = await transaction.get(vehicleReference);
    const currentPublicVehicleSnapshot = await transaction.get(
        publicVehicleReference,
    );
    const currentPublicProfileSnapshot = await transaction.get(
        publicProfileReference,
    );
    if (!currentProfileSnapshot.exists || !currentVehicleSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Profil oder Fahrzeug ist nicht mehr verfügbar.",
      );
    }
    const currentRequest = currentRequestSnapshot.data() ?? {};
    const currentProfile = currentProfileSnapshot.data() ?? {};
    const currentVehicle = currentVehicleSnapshot.data() ?? {};
    if (!hasRequiredProfileData(currentProfile) ||
        !hasRequiredVehicleData(currentVehicle)) {
      throw new HttpsError(
          "failed-precondition",
          "Profil oder Fahrzeug ist nicht mehr vollständig.",
      );
    }
    if (safeString(currentVehicle.ownerUserId) !== userId ||
        safeString(currentVehicle.status) === "archived" ||
        currentVehicle.deactivatedAt != null) {
      throw new HttpsError(
          "failed-precondition",
          "Das ausgewählte Fahrzeug ist nicht für die Verifizierung verfügbar.",
      );
    }
    const storedRelationship = normalizeVehicleRelationship(
        currentVehicle.useRelationship || "owner",
    );
    if (storedRelationship !== normalized.vehicleRelationship) {
      throw new HttpsError(
          "failed-precondition",
          "Die gewählte Fahrzeugzuordnung stimmt nicht mit dem Fahrzeug überein.",
      );
    }
    if (safeString(currentRequest.status) === "pending" &&
        safeString(currentRequest.submissionFingerprint) === fingerprint) {
      return {requestId: userId, status: "pending", idempotent: true};
    }
    if (safeString(currentRequest.status) === "pending") {
      throw new HttpsError(
        "failed-precondition",
        "Deine Verifizierung wird bereits geprüft.",
      );
    }
    if (safeString(currentRequest.status) === "verified") {
      throw new HttpsError(
        "failed-precondition",
        "Dieses Profil ist bereits verifiziert.",
      );
    }
    const currentIdentityDocumentType =
      safeString(currentRequest.identityDocumentType) || "identityCard";
    if (currentIdentityDocumentType !== identityDocumentType) {
      throw new HttpsError(
          "aborted",
          "Der Dokumenttyp wurde zwischenzeitlich geändert. Bitte versuche es erneut.",
      );
    }
    if (currentRequest.vehicleAssignmentConfirmed !== true) {
      throw new HttpsError(
          "failed-precondition",
          "Bitte bestätige, welches Fahrzeug geprüft werden soll.",
      );
    }
    const currentSubmittedGroups = submissionGroupsForDraft(
        currentRequest,
        identityDocumentType,
    );
    if (JSON.stringify(currentSubmittedGroups) !==
        JSON.stringify(submittedDocumentGroups)) {
      throw new HttpsError(
          "aborted",
          "Der Nachreichungsumfang wurde zwischenzeitlich geändert.",
      );
    }
    const currentPaths = currentRequest.documentStoragePaths ?? {};
    for (const key of submittedDocumentKeys) {
      if (safeString(currentPaths[key]) !== safeString(documentStoragePaths[key])) {
        throw new HttpsError(
          "aborted",
          "Die Nachweise wurden zwischenzeitlich geändert. Bitte versuche es erneut.",
        );
      }
    }
    const currentExpirations = validateDocumentExpirations(
        currentRequest.documentExpiresAt,
        now,
    );
    for (const key of requiredExpirationKeys) {
      if (timestampMillis(currentExpirations[key]) !==
          timestampMillis(documentExpiresAt[key])) {
        throw new HttpsError(
            "aborted",
            "Ein Ablaufdatum wurde zwischenzeitlich geändert. Bitte versuche es erneut.",
        );
      }
    }
    const verificationExpiresAt = requiredExpirationKeys
        .map((key) => documentExpiresAt[key])
        .sort((left, right) => timestampMillis(left) - timestampMillis(right))[0];
    const documentStatuses = {
      ...(currentRequest.documentStatuses ?? {}),
    };
    const documentRejectionReasons = {
      ...(currentRequest.documentRejectionReasons ?? {}),
    };
    for (const key of submittedDocumentKeys) {
      documentStatuses[key] = "inReview";
      delete documentRejectionReasons[key];
    }
    if (identityDocumentType === "passport") {
      delete documentStatuses.identityBack;
      delete documentRejectionReasons.identityBack;
    }
    const requestData = {
      requestId: userId,
      userId,
      profilePath: `users/${userId}/profiles/main`,
      status: "pending",
      displayName: safeString(currentProfile.displayName),
      identityDocumentType,
      documentStoragePaths,
      documentStatuses,
      documentRejectionReasons,
      documentExpiresAt,
      verificationExpiresAt,
      submittedDocumentGroups,
      vehicleId: normalized.vehicleId,
      vehicleRelationship: normalized.vehicleRelationship,
      vehicleAssignmentConfirmed: true,
      authorizationConfirmed: true,
      consentVersion,
      consentAcceptedAt: submittedAt,
      countryCode: safeString(currentVehicle.countryCode).toUpperCase(),
      plateRegion: safeString(currentVehicle.plateRegion).toUpperCase(),
      plateLetters: safeString(currentVehicle.plateLetters).toUpperCase(),
      plateNumbers: safeString(currentVehicle.plateNumbers).toUpperCase(),
      vehicleBrand: safeString(currentVehicle.brand),
      vehicleModel: safeString(currentVehicle.model),
      vehicleColor: safeString(currentVehicle.color),
      photoUrl: safeString(currentProfile.photoUrl) || null,
      submittedAt,
      reviewedAt: null,
      reviewedBy: null,
      rejectionReason: null,
      retentionUntil: null,
      documentsCleanedAt: null,
      submissionFingerprint: fingerprint,
      createdAt: currentRequestSnapshot.exists ?
        currentRequest.createdAt ?? submittedAt : submittedAt,
      updatedAt: submittedAt,
    };
    transaction.set(requestReference, requestData, {merge: false});
    const submissionHistoryReference = requestReference
        .collection("history")
        .doc(`submitted_${fingerprint.slice(0, 24)}`);
    transaction.set(submissionHistoryReference, {
      status: "pending",
      reason: null,
      eventType: "submitted",
      documentGroups: submittedDocumentGroups,
      validUntil: verificationExpiresAt,
      createdAt: submittedAt,
    });
    transaction.update(profileReference, {
      verificationStatus: "pending",
      verificationSubmittedAt: submittedAt,
      verificationReviewedAt: null,
      verificationRejectionReason: null,
      verificationStages: verificationStagesFromStatuses(
          documentStatuses,
          identityDocumentType,
      ),
      updatedAt: submittedAt,
    });
    if (submittedDocumentGroups.includes("vehicle")) {
      transaction.update(vehicleReference, {
        verificationStatus: "inReview",
        verificationLocked: true,
        verificationRejectionReason: null,
        isVerified: false,
        updatedAt: submittedAt,
      });
    }
    if (currentPublicVehicleSnapshot.exists &&
        submittedDocumentGroups.includes("vehicle")) {
      transaction.update(publicVehicleReference, {
        verificationStatus: "inReview",
        isVerified: false,
        updatedAt: submittedAt,
      });
    }
    if (currentPublicProfileSnapshot.exists) {
      transaction.update(publicProfileReference, {
        verificationStatus: "unverified",
        updatedAt: submittedAt,
      });
    }
    return {requestId: userId, status: "pending", idempotent: false};
  });
}

function normalizeReviewInput(input) {
  const requestId = safeString(input?.requestId);
  const decision = safeString(input?.decision);
  const reason = safeString(input?.reason);
  if (requestId.length === 0 || requestId.length > 128 ||
      !["verified", "rejected"].includes(decision)) {
    throw new HttpsError("invalid-argument", "Die Prüfentscheidung ist ungültig.");
  }
  if (decision === "rejected" && reason.length < 5) {
    throw new HttpsError(
      "invalid-argument",
      "Bitte gib einen verständlichen Ablehnungsgrund an.",
    );
  }
  return {requestId, decision, reason};
}

async function reviewProfileVerification({
  firestore,
  authContext,
  input,
  now,
}) {
  if (safeString(authContext?.uid).length === 0) {
    throw new HttpsError("unauthenticated", "Bitte melde dich erneut an.");
  }
  if (authContext?.token?.admin !== true) {
    throw new HttpsError(
      "permission-denied",
      "Du hast keine Berechtigung für diese Prüfung.",
    );
  }
  const normalized = normalizeReviewInput(input);
  const requestReference = firestore.doc(
      `verification_requests/${normalized.requestId}`,
  );
  return firestore.runTransaction(async (transaction) => {
    const requestSnapshot = await transaction.get(requestReference);
    if (!requestSnapshot.exists) {
      throw new HttpsError("not-found", "Der Prüfauftrag wurde nicht gefunden.");
    }
    const request = requestSnapshot.data();
    const userId = safeString(request.userId);
    const vehicleId = safeString(request.vehicleId);
    if (userId.length === 0 || vehicleId.length === 0) {
      throw new HttpsError("failed-precondition", "Der Prüfauftrag ist unvollständig.");
    }
    if (safeString(request.status) !== "pending") {
      if (safeString(request.status) === normalized.decision) {
        return {requestId: normalized.requestId, status: normalized.decision, idempotent: true};
      }
      throw new HttpsError(
        "failed-precondition",
        "Dieser Prüfauftrag ist nicht mehr offen.",
      );
    }
    const profileReference = firestore.doc(`users/${userId}/profiles/main`);
    const publicProfileReference = firestore.doc(`public_profiles/${userId}`);
    const vehicleReference = firestore.doc(`users/${userId}/vehicles/${vehicleId}`);
    const publicVehicleReference = firestore.doc(
        `public_profiles/${userId}/vehicles/${vehicleId}`,
    );
    const plateId = plateDocumentId(request);
    const plateReference = plateId.length > 0 ?
      firestore.doc(`plates/${plateId}`) : null;
    const profileSnapshot = await transaction.get(profileReference);
    const vehicleSnapshot = await transaction.get(vehicleReference);
    const publicProfileSnapshot = await transaction.get(publicProfileReference);
    const publicVehicleSnapshot = await transaction.get(publicVehicleReference);
    const plateSnapshot = plateReference == null ? null :
      await transaction.get(plateReference);
    if (!profileSnapshot.exists || !vehicleSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Profil oder Fahrzeug ist nicht mehr verfügbar.",
      );
    }
    const verified = normalized.decision === "verified";
    const reviewedAt = now;
    const identityDocumentType = safeString(request.identityDocumentType) ||
      "identityCard";
    const submittedDocumentGroups = Array.isArray(
        request.submittedDocumentGroups,
    ) ? request.submittedDocumentGroups.filter((group) =>
      Object.hasOwn(documentGroups, group)) : Object.keys(documentGroups);
    const submittedDocumentKeys = documentKeysForGroups(
        submittedDocumentGroups,
        identityDocumentType,
    );
    if (verified) {
      validateDocumentExpirations(request.documentExpiresAt, reviewedAt);
    }
    const firestoreRetentionUntil = Timestamp.fromMillis(
        reviewedAt.toMillis() + retentionDays * 24 * 60 * 60 * 1000,
    );
    const documentStatuses = {...(request.documentStatuses ?? {})};
    const rejectionReasons = {...(request.documentRejectionReasons ?? {})};
    for (const key of submittedDocumentKeys) {
      documentStatuses[key] = verified ? "verified" : "rejected";
      if (verified) {
        delete rejectionReasons[key];
      } else {
        rejectionReasons[key] = normalized.reason;
      }
    }
    if (identityDocumentType === "passport") {
      delete documentStatuses.identityBack;
      delete rejectionReasons.identityBack;
    }
    const fullyVerified = verified && allRequiredDocumentsVerified(
        documentStatuses,
        identityDocumentType,
    );
    const finalStatus = fullyVerified ? "verified" : "rejected";
    const remainingReason = fullyVerified ? null :
      (verified ? Object.values(rejectionReasons)
          .map(safeString)
          .find((reason) => reason.length > 0) ||
        "Weitere Nachweise müssen noch nachgereicht werden." :
        normalized.reason);
    const verificationStages = verificationStagesFromStatuses(
        documentStatuses,
        identityDocumentType,
    );
    transaction.update(requestReference, {
      status: finalStatus,
      documentStatuses,
      documentRejectionReasons: rejectionReasons,
      reviewedAt,
      reviewedBy: safeString(authContext.uid),
      rejectionReason: remainingReason,
      verificationExpiresAt: fullyVerified ? request.verificationExpiresAt : null,
      retentionUntil: firestoreRetentionUntil,
      updatedAt: reviewedAt,
    });
    transaction.update(profileReference, {
      verificationStatus: finalStatus,
      verificationReviewedAt: reviewedAt,
      verificationRejectionReason: remainingReason,
      verificationStages,
      updatedAt: reviewedAt,
    });
    if (submittedDocumentGroups.includes("vehicle")) {
      transaction.update(vehicleReference, {
        verificationStatus: verified ? "verified" : "rejected",
        verificationLocked: false,
        verificationRejectionReason: remainingReason,
        isVerified: fullyVerified,
        updatedAt: reviewedAt,
      });
    } else if (vehicleSnapshot.exists) {
      transaction.update(vehicleReference, {
        verificationLocked: false,
        isVerified: fullyVerified,
        updatedAt: reviewedAt,
      });
    }
    if (publicProfileSnapshot.exists) {
      transaction.update(publicProfileReference, {
        verificationStatus: fullyVerified ? "verified" : "rejected",
        updatedAt: reviewedAt,
      });
    }
    if (publicVehicleSnapshot.exists) {
      transaction.update(publicVehicleReference, {
        verificationStatus: fullyVerified ? "verified" : "rejected",
        isVerified: fullyVerified,
        updatedAt: reviewedAt,
      });
    }
    if (plateSnapshot?.exists && safeString(plateSnapshot.data()?.ownerUserId) === userId) {
      transaction.update(plateReference, {
        verificationStatus: fullyVerified ? "verified" : "rejected",
        isVerified: fullyVerified,
        updatedAt: reviewedAt,
      });
    }
    const historyReference = requestReference.collection("history").doc();
    transaction.set(historyReference, {
      status: finalStatus,
      reason: remainingReason,
      eventType: fullyVerified ? "reviewed" : "resubmissionRequested",
      documentGroups: submittedDocumentGroups,
      validUntil: fullyVerified ? request.verificationExpiresAt : null,
      createdAt: reviewedAt,
    });
    const notificationReference = firestore.doc(
        `users/${userId}/verification_notifications/${historyReference.id}`,
    );
    transaction.set(notificationReference, {
      notificationId: historyReference.id,
      requestId: normalized.requestId,
      status: finalStatus,
      message: fullyVerified ?
        "Deine Verifizierung wurde bestätigt." :
        "Für deine Verifizierung ist eine Nachreichung erforderlich.",
      documentGroup: submittedDocumentGroups.length === 1 ?
        submittedDocumentGroups[0] : null,
      isRead: false,
      createdAt: reviewedAt,
    });
    return {requestId: normalized.requestId, status: finalStatus, idempotent: false};
  });
}

function germanDate(value) {
  const millis = timestampMillis(value);
  if (!Number.isFinite(millis)) return "unbekannt";
  const date = new Date(millis);
  return `${String(date.getUTCDate()).padStart(2, "0")}.` +
    `${String(date.getUTCMonth() + 1).padStart(2, "0")}.` +
    `${date.getUTCFullYear()}`;
}

function reminderMilestone(daysRemaining) {
  if (daysRemaining <= 0 || daysRemaining > 30) return null;
  if (daysRemaining <= 3) return 3;
  if (daysRemaining <= 14) return 14;
  return 30;
}

async function createVerificationExpiryReminders({
  firestore,
  now,
  limit = 100,
}) {
  const nowMillis = timestampMillis(now);
  const threshold = Timestamp.fromMillis(nowMillis + 30 * 24 * 60 * 60 * 1000);
  const snapshot = await firestore.collection("verification_requests")
      .where("verificationExpiresAt", "<=", threshold)
      .limit(limit)
      .get();
  let created = 0;
  let failed = 0;
  for (const document of snapshot.docs) {
    const requestReference = document.ref;
    try {
      created += await firestore.runTransaction(async (transaction) => {
        const currentSnapshot = await transaction.get(requestReference);
        if (!currentSnapshot.exists) return 0;
        const request = currentSnapshot.data();
        if (safeString(request.status) !== "verified") return 0;
        const userId = safeString(request.userId);
        if (userId.length === 0) return 0;
        const reminderState = {...(request.expiryReminderState ?? {})};
        let createdForRequest = 0;
        for (const group of ["identity", "driverLicense"]) {
          const expiresAt = request.documentExpiresAt?.[group];
          const expiryMillis = timestampMillis(expiresAt);
          if (!Number.isFinite(expiryMillis)) continue;
          const daysRemaining = Math.ceil(
              (expiryMillis - nowMillis) / (24 * 60 * 60 * 1000),
          );
          const milestone = reminderMilestone(daysRemaining);
          if (milestone == null) continue;
          const existingState = reminderState[group] ?? {};
          const sameExpiry =
            Number(existingState.expiryMillis) === expiryMillis;
          const sentMilestones = sameExpiry &&
            Array.isArray(existingState.sentMilestones) ?
            existingState.sentMilestones.filter(Number.isInteger) : [];
          if (sentMilestones.includes(milestone)) continue;
          const notificationId =
            `expiry_${group}_${expiryMillis}_${milestone}`;
          const groupLabel = group === "identity" ?
            "Ausweis" : "Führerschein";
          transaction.set(firestore.doc(
              `users/${userId}/verification_notifications/${notificationId}`,
          ), {
            notificationId,
            requestId: requestReference.id,
            status: "verified",
            message: `${groupLabel} läuft am ${germanDate(expiresAt)} ab. ` +
              `Noch ${daysRemaining} Tage.`,
            documentGroup: group,
            expiresAt,
            daysRemaining,
            reminderMilestone: milestone,
            isRead: false,
            createdAt: now,
          });
          reminderState[group] = {
            expiryMillis,
            sentMilestones: [...sentMilestones, milestone]
                .sort((left, right) => right - left),
          };
          createdForRequest += 1;
        }
        if (createdForRequest > 0) {
          transaction.update(requestReference, {
            expiryReminderState: reminderState,
            updatedAt: now,
          });
        }
        return createdForRequest;
      });
    } catch (error) {
      failed += 1;
      logger.error("Verification reminder item failed", {
        errorType: technicalErrorType(error),
      });
    }
  }
  return {created, failed, hasMore: snapshot.size === limit};
}

async function cleanupVerificationDocuments({firestore, bucket, now, limit = 100}) {
  const reminderResult = await createVerificationExpiryReminders({
    firestore,
    now,
    limit,
  });
  const expirationResult = await expireVerifiedRequests({
    firestore,
    now,
    limit,
  });
  const snapshot = await firestore.collection("verification_requests")
      .where("retentionUntil", "<=", now)
      .limit(limit)
      .get();
  let cleaned = 0;
  let cleanupFailed = 0;
  for (const document of snapshot.docs) {
    try {
      const data = document.data();
      if (!["verified", "rejected", "expired"].includes(
        safeString(data.status),
      )) continue;
      if (data.documentsCleanedAt != null) continue;
      const userId = safeString(data.userId);
      if (userId.length === 0) continue;
      for (const key of requiredDocumentKeys) {
        const path = safeString(data.documentStoragePaths?.[key]);
        if (allowedDocumentPaths(userId, key).includes(path)) {
          await bucket.file(path).delete({ignoreNotFound: true});
        }
      }
      await document.ref.update({
        documentStoragePaths: {},
        documentsCleanedAt: now,
        retentionUntil: null,
        updatedAt: now,
      });
      cleaned += 1;
    } catch (error) {
      cleanupFailed += 1;
      logger.error("Verification cleanup item failed", {
        errorType: technicalErrorType(error),
      });
    }
  }
  return {
    cleaned,
    failed: cleanupFailed + reminderResult.failed + expirationResult.failed,
    remindersCreated: reminderResult.created,
    expired: expirationResult.expired,
    hasMore: snapshot.size === limit || expirationResult.hasMore ||
      reminderResult.hasMore,
  };
}

async function expireVerifiedRequests({firestore, now, limit = 100}) {
  const snapshot = await firestore.collection("verification_requests")
      .where("verificationExpiresAt", "<=", now)
      .limit(limit)
      .get();
  let expired = 0;
  let failed = 0;
  for (const document of snapshot.docs) {
    const requestReference = document.ref;
    let changed = false;
    try {
      changed = await firestore.runTransaction(async (transaction) => {
      const currentSnapshot = await transaction.get(requestReference);
      if (!currentSnapshot.exists) return false;
      const request = currentSnapshot.data();
      if (safeString(request.status) !== "verified" ||
          timestampMillis(request.verificationExpiresAt) > timestampMillis(now)) {
        return false;
      }
      const userId = safeString(request.userId);
      const vehicleId = safeString(request.vehicleId);
      if (userId.length === 0 || vehicleId.length === 0) return false;
      const identityDocumentType = safeString(request.identityDocumentType) ||
        "identityCard";
      const expiredGroups = ["identity", "driverLicense"].filter((group) =>
        timestampMillis(request.documentExpiresAt?.[group]) <=
          timestampMillis(now));
      if (expiredGroups.length === 0) return false;
      const documentStatuses = {...(request.documentStatuses ?? {})};
      const documentRejectionReasons = {
        ...(request.documentRejectionReasons ?? {}),
      };
      for (const group of expiredGroups) {
        for (const key of keysForGroup(group, identityDocumentType)) {
          documentStatuses[key] = "expired";
          documentRejectionReasons[key] =
            `${group === "identity" ? "Ausweis" : "Führerschein"} ist abgelaufen.`;
        }
      }
      const expiredLabels = expiredGroups.map((group) =>
        group === "identity" ? "Ausweis" : "Führerschein");
      const expiryReason =
        `${expiredLabels.join(" und ")} ${expiredLabels.length === 1 ? "ist" : "sind"} abgelaufen.`;
      const profileReference = firestore.doc(`users/${userId}/profiles/main`);
      const publicProfileReference = firestore.doc(`public_profiles/${userId}`);
      const vehicleReference = firestore.doc(
          `users/${userId}/vehicles/${vehicleId}`,
      );
      const publicVehicleReference = firestore.doc(
          `public_profiles/${userId}/vehicles/${vehicleId}`,
      );
      const plateId = plateDocumentId(request);
      const plateReference = plateId.length > 0 ?
        firestore.doc(`plates/${plateId}`) : null;
      const profile = await transaction.get(profileReference);
      const publicProfile = await transaction.get(publicProfileReference);
      const vehicle = await transaction.get(vehicleReference);
      const publicVehicle = await transaction.get(publicVehicleReference);
      const plate = plateReference == null ? null :
        await transaction.get(plateReference);
      transaction.update(requestReference, {
        status: "expired",
        documentStatuses,
        documentRejectionReasons,
        verificationExpiresAt: null,
        submittedDocumentGroups: [],
        rejectionReason: `${expiryReason} Bitte reiche nur diese Nachweise neu ein.`,
        updatedAt: now,
      });
      if (profile.exists) {
        transaction.update(profileReference, {
          verificationStatus: "expired",
          verificationRejectionReason:
            expiryReason,
          verificationStages: verificationStagesFromStatuses(
              documentStatuses,
              identityDocumentType,
          ),
          updatedAt: now,
        });
      }
      if (publicProfile.exists) {
        transaction.update(publicProfileReference, {
          verificationStatus: "expired",
          updatedAt: now,
        });
      }
      if (vehicle.exists) {
        transaction.update(vehicleReference, {
          verificationStatus: "expired",
          verificationLocked: false,
          verificationRejectionReason:
            expiryReason,
          isVerified: false,
          updatedAt: now,
        });
      }
      if (publicVehicle.exists) {
        transaction.update(publicVehicleReference, {
          verificationStatus: "expired",
          isVerified: false,
          updatedAt: now,
        });
      }
      if (plate?.exists && safeString(plate.data()?.ownerUserId) === userId) {
        transaction.update(plateReference, {
          verificationStatus: "expired",
          isVerified: false,
          updatedAt: now,
        });
      }
      const historyReference = requestReference.collection("history").doc();
      transaction.set(historyReference, {
        status: "expired",
        reason: expiryReason,
        eventType: "resubmissionRequested",
        documentGroups: expiredGroups,
        validUntil: request.verificationExpiresAt,
        createdAt: now,
      });
      transaction.set(firestore.doc(
          `users/${userId}/verification_notifications/${historyReference.id}`,
      ), {
        notificationId: historyReference.id,
        requestId: requestReference.id,
        status: "expired",
        message: `${expiryReason} Bitte reiche nur diese Nachweise neu ein.`,
        documentGroup: expiredGroups.length === 1 ? expiredGroups[0] : null,
        isRead: false,
        createdAt: now,
      });
      return true;
      });
    } catch (error) {
      failed += 1;
      logger.error("Verification expiry item failed", {
        errorType: technicalErrorType(error),
      });
    }
    if (changed) expired += 1;
  }
  return {expired, failed, hasMore: snapshot.size === limit};
}

module.exports = {
  allowedIdentityDocumentTypes,
  allowedDocumentPaths,
  allowedRelationships,
  cleanupVerificationDocuments,
  consentVersion,
  createVerificationExpiryReminders,
  expectedDocumentPath,
  expireVerifiedRequests,
  inspectJpeg,
  inspectPng,
  isJpegHeader,
  isPngHeader,
  normalizeReviewInput,
  normalizeSubmissionInput,
  normalizeVehicleRelationship,
  plateDocumentId,
  reminderMilestone,
  requiredDocumentKeys,
  requiredExpirationKeys,
  requiredKeysForIdentityType,
  reviewProfileVerification,
  submitProfileVerification,
  submissionGroupsForDraft,
  validateDocumentExpirations,
  validateStoredDocuments,
};
