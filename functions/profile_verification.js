const {createHash} = require("node:crypto");
const {Timestamp} = require("firebase-admin/firestore");
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
const allowedIdentityDocumentTypes = [
  "identityCard",
  "passport",
  "residencePermit",
];
const expirationReminderLeadDays = [30, 14, 3];
const allowedRelationships = [
  "owner",
  "leasingCompany",
  "authorizedUser",
];
const consentVersion = "verification-consent-1.0";
const maxDocumentBytes = 12 * 1024 * 1024;
const retentionDays = 30;

function normalizeIdentityDocumentType(value) {
  const normalized = safeString(value);
  return allowedIdentityDocumentTypes.includes(normalized) ?
    normalized : "identityCard";
}

function requiredDocumentKeysFor(identityDocumentType) {
  const type = normalizeIdentityDocumentType(identityDocumentType);
  return [
    "identityFront",
    ...(type === "passport" ? [] : ["identityBack"]),
    "driverLicenseFront",
    "driverLicenseBack",
    "vehicleFront",
    "vehicleBack",
  ];
}

function documentGroupKeys(documentKey, identityDocumentType) {
  if (["identityFront", "identityBack"].includes(documentKey)) {
    return requiredDocumentKeysFor(identityDocumentType)
        .filter((key) => key.startsWith("identity"));
  }
  if (["driverLicenseFront", "driverLicenseBack"].includes(documentKey)) {
    return ["driverLicenseFront", "driverLicenseBack"];
  }
  if (["vehicleFront", "vehicleBack"].includes(documentKey)) {
    return ["vehicleFront", "vehicleBack"];
  }
  return [];
}

function verificationLevels(statuses, identityDocumentType) {
  const allVerified = (keys) => keys.every((key) => statuses?.[key] === "verified");
  const identity = allVerified(documentGroupKeys(
      "identityFront",
      identityDocumentType,
  ));
  const driverLicense = allVerified([
    "driverLicenseFront",
    "driverLicenseBack",
  ]);
  const vehicle = allVerified(["vehicleFront", "vehicleBack"]);
  return {
    identity,
    driverLicense,
    vehicle,
    complete: identity && driverLicense && vehicle,
  };
}

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function timestampMillis(value) {
  if (value != null && typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (value instanceof Date) return value.getTime();
  return Number.NaN;
}

function validateDocumentExpirations(expirations, now) {
  const nowMillis = timestampMillis(now);
  const normalized = {};
  for (const key of requiredExpirationKeys) {
    const value = expirations?.[key];
    const millis = timestampMillis(value);
    if (!Number.isFinite(millis) || millis <= nowMillis) {
      throw new HttpsError(
          "failed-precondition",
          "Bitte gib für Ausweis und Führerschein ein gültiges Ablaufdatum ein.",
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
  return {requestId, vehicleId, vehicleRelationship};
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
  identityDocumentType,
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
      }))
      .digest("hex");
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
  const identityDocumentType = normalizeIdentityDocumentType(
      draft.identityDocumentType,
  );
  const submissionDocumentKeys = requiredDocumentKeysFor(
      identityDocumentType,
  );
  const documentStoragePaths = draft.documentStoragePaths ?? {};
  const draftDocumentStatuses = draft.documentStatuses ?? {};
  const documentsNeedingReview = submissionDocumentKeys.filter(
      (key) => safeString(draftDocumentStatuses[key]) !== "verified",
  );
  if (documentsNeedingReview.length === 0) {
    throw new HttpsError(
        "failed-precondition",
        "Es gibt keine Nachweise, die erneut geprüft werden müssen.",
    );
  }
  const documentExpiresAt = validateDocumentExpirations(
      draft.documentExpiresAt,
      now,
  );
  await validateStoredDocuments({
    bucket,
    userId,
    paths: documentStoragePaths,
    documentKeys: documentsNeedingReview,
  });

  const submittedAt = now;
  const fingerprint = submissionFingerprint({
    userId,
    vehicleId: normalized.vehicleId,
    relationship: normalized.vehicleRelationship,
    paths: documentStoragePaths,
    expirations: documentExpiresAt,
    identityDocumentType,
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
    const currentIdentityDocumentType = normalizeIdentityDocumentType(
        currentRequest.identityDocumentType,
    );
    if (currentIdentityDocumentType !== identityDocumentType) {
      throw new HttpsError(
          "aborted",
          "Der Dokumenttyp wurde zwischenzeitlich geändert. Bitte versuche es erneut.",
      );
    }
    const currentPaths = currentRequest.documentStoragePaths ?? {};
    for (const key of documentsNeedingReview) {
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
    const currentStatuses = currentRequest.documentStatuses ?? {};
    const documentStatuses = Object.fromEntries(
        requiredDocumentKeys.map((key) => [
          key,
          submissionDocumentKeys.includes(key) ?
            (safeString(currentStatuses[key]) === "verified" ?
              "verified" : "inReview") : "missing",
        ]),
    );
    const levels = verificationLevels(documentStatuses, identityDocumentType);
    const requestData = {
      requestId: userId,
      userId,
      profilePath: `users/${userId}/profiles/main`,
      status: "pending",
      displayName: safeString(currentProfile.displayName),
      identityDocumentType,
      documentStoragePaths,
      documentStatuses,
      documentRejectionReasons: {},
      documentExpiresAt,
      verificationExpiresAt,
      vehicleId: normalized.vehicleId,
      vehicleRelationship: normalized.vehicleRelationship,
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
      submissionFingerprint: fingerprint,
      verificationLevels: levels,
      lastEditedDocumentKey: currentRequest.lastEditedDocumentKey ?? null,
      documentsCleanedAt: currentRequest.documentsCleanedAt ?? null,
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
      eventType: currentRequest.reviewedAt != null ||
          ["rejected", "expired"].includes(safeString(currentRequest.status)) ?
        "review_requested" : "submitted",
      documentKeys: documentsNeedingReview,
      validUntil: verificationExpiresAt,
      createdAt: submittedAt,
    });
    transaction.update(profileReference, {
      verificationStatus: "pending",
      verificationSubmittedAt: submittedAt,
      verificationReviewedAt: null,
      verificationRejectionReason: null,
      verificationLevels: levels,
      updatedAt: submittedAt,
    });
    transaction.update(vehicleReference, {
      verificationStatus: "inReview",
      verificationLocked: true,
      verificationRejectionReason: null,
      isVerified: false,
      updatedAt: submittedAt,
    });
    if (currentPublicVehicleSnapshot.exists) {
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

function identityDocumentLabel(identityDocumentType) {
  return normalizeIdentityDocumentType(identityDocumentType) === "passport" ?
    "Reisepass" :
    normalizeIdentityDocumentType(identityDocumentType) === "residencePermit" ?
      "Aufenthaltstitel" : "Personalausweis";
}

function expirationDocumentLabel(expirationKey, identityDocumentType) {
  return expirationKey === "identity" ?
    identityDocumentLabel(identityDocumentType) : "Führerschein";
}

function daysUntilExpiration(expiration, now) {
  const remaining = timestampMillis(expiration) - timestampMillis(now);
  return Number.isFinite(remaining) ?
    Math.ceil(remaining / (24 * 60 * 60 * 1000)) : Number.NaN;
}

function expirationReminderCandidates(request, now) {
  if (safeString(request?.status) !== "verified") return [];
  const identityDocumentType = normalizeIdentityDocumentType(
      request.identityDocumentType,
  );
  const candidates = [];
  for (const expirationKey of requiredExpirationKeys) {
    const expiresAt = request.documentExpiresAt?.[expirationKey];
    const leadDays = daysUntilExpiration(expiresAt, now);
    if (!expirationReminderLeadDays.includes(leadDays)) continue;
    candidates.push({
      expirationKey,
      leadDays,
      expiresAt,
      documentLabel: expirationDocumentLabel(
          expirationKey,
          identityDocumentType,
      ),
    });
  }
  return candidates;
}

function buildDocumentReviewOutcome({request, input, fallbackDecision, fallbackReason}) {
  const identityDocumentType = normalizeIdentityDocumentType(
      request.identityDocumentType,
  );
  const requiredKeys = requiredDocumentKeysFor(identityDocumentType);
  const currentStatuses = request.documentStatuses ?? {};
  const reviewKeys = requiredKeys.filter(
      (key) => safeString(currentStatuses[key]) === "inReview",
  );
  if (reviewKeys.length === 0) {
    throw new HttpsError(
        "failed-precondition",
        "Dieser Prüfauftrag enthält keine offenen Nachweise.",
    );
  }
  const suppliedDecisions = input?.documentDecisions;
  const suppliedReasons = input?.documentReasons;
  const decisions = {};
  const reasons = {...(request.documentRejectionReasons ?? {})};
  for (const key of reviewKeys) {
    const decision = suppliedDecisions != null &&
        typeof suppliedDecisions === "object" ?
      safeString(suppliedDecisions[key]) : fallbackDecision;
    if (!["verified", "rejected"].includes(decision)) {
      throw new HttpsError(
          "invalid-argument",
          "Für jeden offenen Nachweis ist eine Prüfentscheidung erforderlich.",
      );
    }
    const reason = suppliedReasons != null &&
        typeof suppliedReasons === "object" ?
      safeString(suppliedReasons[key]) : fallbackReason;
    if (decision === "rejected" && reason.length < 5) {
      throw new HttpsError(
          "invalid-argument",
          "Bitte gib für jeden abgelehnten Nachweis einen konkreten Grund an.",
      );
    }
    decisions[key] = decision;
    if (decision === "rejected") reasons[key] = reason;
    else delete reasons[key];
  }
  if (suppliedDecisions != null && typeof suppliedDecisions === "object") {
    for (const key of Object.keys(suppliedDecisions)) {
      if (!reviewKeys.includes(key)) {
        throw new HttpsError(
            "invalid-argument",
            "Es dürfen nur offene Nachweise bewertet werden.",
        );
      }
    }
  }
  const statuses = {...currentStatuses, ...decisions};
  for (const key of requiredDocumentKeys) {
    if (!requiredKeys.includes(key)) statuses[key] = "missing";
  }
  const levels = verificationLevels(statuses, identityDocumentType);
  const rejectedKeys = requiredKeys.filter(
      (key) => statuses[key] === "rejected",
  );
  return {
    identityDocumentType,
    statuses,
    reasons,
    levels,
    reviewedDocumentKeys: reviewKeys,
    rejectedKeys,
    overallDecision: levels.complete ? "verified" : "rejected",
  };
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
    const reviewedAt = now;
    const outcome = buildDocumentReviewOutcome({
      request,
      input,
      fallbackDecision: normalized.decision,
      fallbackReason: normalized.reason,
    });
    const verified = outcome.overallDecision === "verified";
    if (verified) {
      validateDocumentExpirations(request.documentExpiresAt, reviewedAt);
    }
    const firestoreRetentionUntil = Timestamp.fromMillis(
        reviewedAt.toMillis() + retentionDays * 24 * 60 * 60 * 1000,
    );
    const rejectionReason = verified ? null :
      "Mindestens ein Nachweis muss erneut eingereicht werden.";
    transaction.update(requestReference, {
      status: outcome.overallDecision,
      documentStatuses: outcome.statuses,
      documentRejectionReasons: outcome.reasons,
      verificationLevels: outcome.levels,
      reviewedAt,
      reviewedBy: null,
      rejectionReason,
      verificationExpiresAt: verified ? request.verificationExpiresAt : null,
      retentionUntil: firestoreRetentionUntil,
      updatedAt: reviewedAt,
    });
    transaction.update(profileReference, {
      verificationStatus: outcome.overallDecision,
      verificationReviewedAt: reviewedAt,
      verificationRejectionReason: rejectionReason,
      verificationLevels: outcome.levels,
      updatedAt: reviewedAt,
    });
    transaction.update(vehicleReference, {
      verificationStatus: outcome.overallDecision,
      verificationLocked: false,
      verificationRejectionReason: rejectionReason,
      isVerified: verified,
      updatedAt: reviewedAt,
    });
    if (publicProfileSnapshot.exists) {
      transaction.update(publicProfileReference, {
        verificationStatus: verified ? "verified" : "unverified",
        updatedAt: reviewedAt,
      });
    }
    if (publicVehicleSnapshot.exists) {
      transaction.update(publicVehicleReference, {
        verificationStatus: verified ? "verified" : "unverified",
        isVerified: verified,
        updatedAt: reviewedAt,
      });
    }
    if (plateSnapshot?.exists && safeString(plateSnapshot.data()?.ownerUserId) === userId) {
      transaction.update(plateReference, {
        verificationStatus: verified ? "verified" : "unverified",
        updatedAt: reviewedAt,
      });
    }
    const historyReference = requestReference.collection("history").doc();
    transaction.set(historyReference, {
      status: outcome.overallDecision,
      reason: rejectionReason,
      eventType: "reviewed",
      documentKeys: outcome.reviewedDocumentKeys,
      validUntil: verified ? request.verificationExpiresAt : null,
      createdAt: reviewedAt,
    });
    const auditReference = firestore.doc(
        `verification_review_audit/${normalized.requestId}_${historyReference.id}`,
    );
    transaction.set(auditReference, {
      requestId: normalized.requestId,
      reviewerUserId: safeString(authContext.uid),
      decision: outcome.overallDecision,
      reviewedDocumentKeys: outcome.reviewedDocumentKeys,
      createdAt: reviewedAt,
    });
    const notificationReference = firestore.doc(
        `users/${userId}/verification_notifications/${historyReference.id}`,
    );
    transaction.set(notificationReference, {
      notificationId: historyReference.id,
      requestId: normalized.requestId,
      status: outcome.overallDecision,
      message: verified ?
        "Deine Verifizierung wurde bestätigt." :
        `Für ${outcome.rejectedKeys.length} Nachweis${outcome.rejectedKeys.length === 1 ? "" : "e"} ist eine Nachreichung erforderlich.`,
      isRead: false,
      createdAt: reviewedAt,
    });
    return {
      requestId: normalized.requestId,
      status: outcome.overallDecision,
      idempotent: false,
    };
  });
}

async function sendExpirationReminders({
  firestore,
  messaging,
  now,
  limit = 100,
}) {
  const horizon = Timestamp.fromMillis(
      timestampMillis(now) + 31 * 24 * 60 * 60 * 1000,
  );
  const snapshot = await firestore.collection("verification_requests")
      .where("verificationExpiresAt", "<=", horizon)
      .limit(limit)
      .get();
  let created = 0;
  let pushSent = 0;
  for (const requestDocument of snapshot.docs) {
    const request = requestDocument.data();
    const userId = safeString(request.userId);
    if (userId.length === 0) continue;
    for (const candidate of expirationReminderCandidates(request, now)) {
      const expirationMillis = timestampMillis(candidate.expiresAt);
      const notificationId = [
        "expiry",
        candidate.expirationKey,
        candidate.leadDays,
        expirationMillis,
      ].join("_");
      const notificationReference = firestore.doc(
          `users/${userId}/verification_notifications/${notificationId}`,
      );
      const expirationLabel = new Date(expirationMillis).toLocaleDateString(
          "de-DE",
          {timeZone: "Europe/Berlin"},
      );
      const message = `${candidate.documentLabel} läuft am ${expirationLabel} ab. Bitte erneuere den Nachweis rechtzeitig.`;
      const wasCreated = await firestore.runTransaction(async (transaction) => {
        const existing = await transaction.get(notificationReference);
        if (existing.exists) return false;
        transaction.set(notificationReference, {
          notificationId,
          requestId: requestDocument.id,
          status: "verified",
          kind: "expirationReminder",
          documentKey: candidate.expirationKey,
          expiresAt: candidate.expiresAt,
          leadDays: candidate.leadDays,
          message,
          isRead: false,
          pushSentAt: null,
          createdAt: now,
        });
        return true;
      });
      if (!wasCreated) continue;
      created += 1;
      if (messaging == null) continue;
      const [settingsSnapshot, devicesSnapshot] = await Promise.all([
        firestore.doc(`users/${userId}/settings/notifications`).get(),
        firestore.collection(`users/${userId}/notification_devices`).get(),
      ]);
      if (settingsSnapshot.exists &&
          settingsSnapshot.data()?.verification === false) {
        continue;
      }
      const tokens = [...new Set(devicesSnapshot.docs
          .map((document) => safeString(document.data()?.token))
          .filter((token) => token.length > 0))]
          .slice(0, 500);
      if (tokens.length === 0) continue;
      const response = await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: "Dokument läuft bald ab",
          body: message,
        },
        data: {
          type: "verification_expiration_reminder",
          requestId: requestDocument.id,
          documentKey: candidate.expirationKey,
          leadDays: String(candidate.leadDays),
        },
        android: {priority: "high"},
      });
      pushSent += response.successCount;
      await notificationReference.update({
        pushSentAt: response.successCount > 0 ? now : null,
        pushSuccessCount: response.successCount,
        pushFailureCount: response.failureCount,
      });
    }
  }
  return {
    created,
    pushSent,
    hasMore: snapshot.size === limit,
  };
}

async function cleanupVerificationDocuments({firestore, bucket, now, limit = 100}) {
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
  for (const document of snapshot.docs) {
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
      documentStatuses: data.documentStatuses ?? {},
      documentsCleanedAt: now,
      retentionUntil: null,
      updatedAt: now,
    });
    await document.ref.collection("history").doc(
        `documents_deleted_${timestampMillis(now)}`,
    ).set({
      status: safeString(data.status) || "draft",
      reason: "Die privaten Dokumentdateien wurden fristgerecht gelöscht.",
      eventType: "documents_deleted",
      createdAt: now,
    });
    cleaned += 1;
  }
  return {
    cleaned,
    expired: expirationResult.expired,
    hasMore: snapshot.size === limit || expirationResult.hasMore,
  };
}

async function expireVerifiedRequests({firestore, now, limit = 100}) {
  const snapshot = await firestore.collection("verification_requests")
      .where("verificationExpiresAt", "<=", now)
      .limit(limit)
      .get();
  let expired = 0;
  for (const document of snapshot.docs) {
    const requestReference = document.ref;
    const changed = await firestore.runTransaction(async (transaction) => {
      const currentSnapshot = await transaction.get(requestReference);
      if (!currentSnapshot.exists) return false;
      const request = currentSnapshot.data();
      if (!["verified", "pending"].includes(safeString(request.status)) ||
          timestampMillis(request.verificationExpiresAt) > timestampMillis(now)) {
        return false;
      }
      const userId = safeString(request.userId);
      const vehicleId = safeString(request.vehicleId);
      if (userId.length === 0 || vehicleId.length === 0) return false;
      const identityDocumentType = normalizeIdentityDocumentType(
          request.identityDocumentType,
      );
      const expiredExpirationKeys = requiredExpirationKeys.filter(
          (key) => timestampMillis(request.documentExpiresAt?.[key]) <=
            timestampMillis(now),
      );
      const expiredDocumentKeys = [...new Set(expiredExpirationKeys.flatMap(
          (key) => key === "identity" ?
            documentGroupKeys("identityFront", identityDocumentType) :
            documentGroupKeys("driverLicenseFront", identityDocumentType),
      ))];
      const documentStatuses = {...(request.documentStatuses ?? {})};
      const documentRejectionReasons = {
        ...(request.documentRejectionReasons ?? {}),
      };
      for (const key of expiredDocumentKeys) {
        documentStatuses[key] = "expired";
        documentRejectionReasons[key] =
          "Dieser Nachweis ist abgelaufen. Bitte reiche eine aktuelle Version ein.";
      }
      const levels = verificationLevels(
          documentStatuses,
          identityDocumentType,
      );
      const expiredLabels = expiredExpirationKeys.map(
          (key) => key === "identity" ?
            (identityDocumentType === "passport" ? "Reisepass" :
              identityDocumentType === "residencePermit" ?
                "Aufenthaltstitel" : "Personalausweis") : "Führerschein",
      );
      const expirationReason =
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
        verificationLevels: levels,
        verificationExpiresAt: null,
        rejectionReason: `${expirationReason} Bitte reiche aktuelle Nachweise ein.`,
        updatedAt: now,
      });
      if (profile.exists) {
        transaction.update(profileReference, {
          verificationStatus: "expired",
          verificationRejectionReason: expirationReason,
          verificationLevels: levels,
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
            expirationReason,
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
        reason: expirationReason,
        eventType: "expired",
        documentKeys: expiredDocumentKeys,
        validUntil: request.verificationExpiresAt ?? null,
        createdAt: now,
      });
      transaction.set(firestore.doc(
          `users/${userId}/verification_notifications/${historyReference.id}`,
      ), {
        notificationId: historyReference.id,
        requestId: requestReference.id,
        status: "expired",
        kind: "expiration",
        documentKey: expiredExpirationKeys.length === 1 ?
          expiredExpirationKeys[0] : null,
        expiresAt: request.verificationExpiresAt ?? null,
        message: `${expirationReason} Bitte reiche aktuelle Nachweise ein.`,
        isRead: false,
        createdAt: now,
      });
      return true;
    });
    if (changed) expired += 1;
  }
  return {expired, hasMore: snapshot.size === limit};
}

module.exports = {
  allowedIdentityDocumentTypes,
  allowedDocumentPaths,
  allowedRelationships,
  buildDocumentReviewOutcome,
  cleanupVerificationDocuments,
  consentVersion,
  daysUntilExpiration,
  expectedDocumentPath,
  expirationReminderCandidates,
  expireVerifiedRequests,
  inspectJpeg,
  inspectPng,
  isJpegHeader,
  isPngHeader,
  normalizeIdentityDocumentType,
  normalizeReviewInput,
  normalizeSubmissionInput,
  normalizeVehicleRelationship,
  plateDocumentId,
  requiredDocumentKeys,
  requiredDocumentKeysFor,
  requiredExpirationKeys,
  reviewProfileVerification,
  sendExpirationReminders,
  submitProfileVerification,
  validateDocumentExpirations,
  validateStoredDocuments,
  verificationLevels,
};
