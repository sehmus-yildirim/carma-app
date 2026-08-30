const {createHash} = require("node:crypto");
const {Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const {trustedProfilePhotoUrl} = require("./trusted_media_url");
const {
  isEffectiveIdentityVerification,
  isEffectiveVehicleVerification,
  usesVerificationV1,
} = require("./verification_v1_policy");

const supportedCountries = new Set(["DE", "AT", "CH"]);
const supportedReasons = new Set([
  "vehicle_question",
  "compliment",
  "meet_and_drive",
  "get_to_know",
]);
const requestExpiryMs = 48 * 60 * 60 * 1000;
const requestWindowMs = 24 * 60 * 60 * 1000;
const requestCooldownMs = 10 * 60 * 1000;
const maxRequestsPerWindow = 20;
const maxRequestsPerTargetWindow = 3;

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function safeOptionalString(value, maxLength) {
  const normalized = safeString(value).replace(/\s+/gu, " ");
  return normalized.length > 0 ? normalized.slice(0, maxLength) : null;
}

function timestampMillis(value) {
  if (value != null && typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (value instanceof Date) return value.getTime();
  return null;
}

function dailyWindowKey(date) {
  return date.toISOString().slice(0, 10);
}

function digestId(parts) {
  return createHash("sha256").update(parts.join("\u0000")).digest("hex");
}

function contactGrantId(userId, countryCode, vehicleId) {
  return digestId([userId, countryCode, vehicleId]);
}

function isSafeDocumentId(value, maxLength = 160) {
  return value.length > 0 && value.length <= maxLength &&
    /^[A-Za-z0-9_-]+$/u.test(value);
}

function contactRequestDocumentId(senderUserId, countryCode, vehicleId) {
  return `${senderUserId}_${countryCode}_${vehicleId}`;
}

async function findVerifiedSenderVehicle(firestore, senderUserId) {
  const [profileSnapshot, identitySnapshot] = await Promise.all([
    firestore.doc(`public_profiles/${senderUserId}`).get(),
    firestore.doc(`users/${senderUserId}/private_verification/identity`).get(),
  ]);
  const primaryVehicleId = safeString(
    profileSnapshot.data()?.primaryVehicleId,
  );
  if (identitySnapshot.exists) {
    const identity = identitySnapshot.data() ?? {};
    if (!isEffectiveIdentityVerification(identity)) return null;
    const verificationSnapshot = await firestore
      .collection(`users/${senderUserId}/vehicle_verifications`)
      .where("status", "==", "verified")
      .limit(20)
      .get();
    const candidates = [...verificationSnapshot.docs].sort((left, right) =>
      Number(right.id === primaryVehicleId) - Number(left.id === primaryVehicleId),
    );
    for (const candidate of candidates) {
      const vehicleSnapshot = await firestore
        .doc(`users/${senderUserId}/vehicles/${candidate.id}`)
        .get();
      if (vehicleSnapshot.exists && isEffectiveVehicleVerification({
        identity,
        verification: candidate.data() ?? {},
        vehicle: vehicleSnapshot.data() ?? {},
      })) {
        return candidate.id;
      }
    }
    return null;
  }
  if (isSafeDocumentId(primaryVehicleId)) {
    const primaryReference = firestore.doc(
      `public_profiles/${senderUserId}/vehicles/${primaryVehicleId}`,
    );
    const primarySnapshot = await primaryReference.get();
    if (primarySnapshot.exists && primarySnapshot.data()?.isVerified === true) {
      return primaryVehicleId;
    }
  }

  const snapshot = await firestore
    .collection(`public_profiles/${senderUserId}/vehicles`)
    .where("isVerified", "==", true)
    .limit(1)
    .get();
  const vehicleId = safeString(snapshot.docs?.[0]?.id);
  return isSafeDocumentId(vehicleId) ? vehicleId : null;
}

function profileDisplayName(privateProfile, publicProfile) {
  const fullName = [
    safeOptionalString(privateProfile.firstName, 80),
    safeOptionalString(privateProfile.lastName, 80),
  ].filter(Boolean).join(" ").trim();
  return safeOptionalString(
    fullName || privateProfile.displayName || publicProfile.displayName,
    80,
  ) || "plaqa Nutzer";
}

function isIdentityVerified(privateProfile, publicProfile, v1Identity, now) {
  if (v1Identity != null) {
    return isEffectiveIdentityVerification(v1Identity, now);
  }
  return privateProfile.verificationStatus === "verified" ||
    privateProfile.isVerified === true ||
    publicProfile.verificationStatus === "verified" ||
    publicProfile.isVerified === true;
}

function activeRequest(data, now) {
  if (data == null || data.isDeleted === true) return false;
  if (data.status === "accepted") return true;
  const expiresAt = timestampMillis(data.expiresAt);
  return data.status === "pending" && expiresAt != null &&
    expiresAt > now.getTime();
}

function activeWindow(data, now) {
  const startedAt = timestampMillis(data.windowStartedAt);
  return startedAt != null && now.getTime() - startedAt < requestWindowMs;
}

function accountDeletionBlocksWrites(data) {
  return ["requested", "processing", "completed"].includes(
    safeString(data?.status),
  );
}

function safeProjection(value, maxLength) {
  return safeOptionalString(value, maxLength);
}

async function createContactRequest({
  firestore,
  senderUserId,
  input,
  now = new Date(),
}) {
  const senderId = safeString(senderUserId);
  const targetUserId = safeString(input?.targetUserId);
  const countryCode = safeString(input?.countryCode).toUpperCase();
  const vehicleId = safeString(input?.vehicleId);
  const plateKey = safeString(input?.plateKey)
    .toUpperCase().replace(/[^A-ZÄÖÜ0-9]/gu, "");
  const requestReason = safeString(input?.requestReason);
  const message = safeString(input?.message).replace(/[\u0000-\u001F\u007F]/gu, " ")
    .replace(/\s+/gu, " ");

  if (!isSafeDocumentId(senderId, 128) ||
      !isSafeDocumentId(targetUserId, 128) ||
      senderId === targetUserId ||
      !supportedCountries.has(countryCode) ||
      !isSafeDocumentId(vehicleId) ||
      !/^[A-ZÄÖÜ0-9]{2,20}$/u.test(plateKey) ||
      !supportedReasons.has(requestReason) ||
      message.length === 0 || message.length > 1000) {
    throw new HttpsError(
      "invalid-argument",
      "Die Kontaktanfrage enthält ungültige Angaben.",
    );
  }

  const senderVehicleId = await findVerifiedSenderVehicle(
    firestore,
    senderId,
  );
  if (senderVehicleId == null) {
    throw new HttpsError(
      "failed-precondition",
      "Bestätige zuerst eines deiner Fahrzeuge.",
    );
  }

  const requestId = contactRequestDocumentId(
    senderId,
    countryCode,
    vehicleId,
  );
  const chatId = `request_${requestId}`;
  const messageId = `contact_request_${requestId}_initial`;
  const dayKey = dailyWindowKey(now);
  const requestReference = firestore.doc(`contact_requests/${requestId}`);
  const chatReference = firestore.doc(`chats/${chatId}`);
  const messageReference = firestore.doc(
    `chats/${chatId}/messages/${messageId}`,
  );
  const plateReference = firestore.doc(`plates/${countryCode}_${plateKey}`);
  const senderProfileReference = firestore.doc(
    `users/${senderId}/profiles/main`,
  );
  const senderPublicProfileReference = firestore.doc(
    `public_profiles/${senderId}`,
  );
  const senderVehicleReference = firestore.doc(
    `public_profiles/${senderId}/vehicles/${senderVehicleId}`,
  );
  const senderPrivateVehicleReference = firestore.doc(
    `users/${senderId}/vehicles/${senderVehicleId}`,
  );
  const senderIdentityV1Reference = firestore.doc(
    `users/${senderId}/private_verification/identity`,
  );
  const senderVehicleV1Reference = firestore.doc(
    `users/${senderId}/vehicle_verifications/${senderVehicleId}`,
  );
  const receiverProfileReference = firestore.doc(
    `public_profiles/${targetUserId}`,
  );
  const receiverPrivateVehicleReference = firestore.doc(
    `users/${targetUserId}/vehicles/${vehicleId}`,
  );
  const receiverIdentityV1Reference = firestore.doc(
    `users/${targetUserId}/private_verification/identity`,
  );
  const receiverVehicleV1Reference = firestore.doc(
    `users/${targetUserId}/vehicle_verifications/${vehicleId}`,
  );
  const receiverDeletionReference = firestore.doc(
    `account_deletions/${targetUserId}`,
  );
  const senderDeletionReference = firestore.doc(
    `account_deletions/${senderId}`,
  );
  const visibilityReference = firestore.doc(
    `users/${targetUserId}/settings/visibility`,
  );
  const filterReference = firestore.doc(
    `users/${targetUserId}/settings/contact_filters`,
  );
  const grantReference = firestore.doc(
    `plate_contact_grants/${contactGrantId(senderId, countryCode, vehicleId)}`,
  );
  const senderLimitReference = firestore.doc(
    `contact_request_rate_limits/${digestId([senderId, dayKey])}`,
  );
  const targetLimitReference = firestore.doc(
    `contact_request_target_limits/${digestId([
      senderId,
      targetUserId,
      dayKey,
    ])}`,
  );
  const nowTimestamp = Timestamp.fromDate(now);
  const expiresAt = Timestamp.fromDate(new Date(now.getTime() + requestExpiryMs));
  const quotaExpiresAt = Timestamp.fromDate(
    new Date(now.getTime() + 2 * requestWindowMs),
  );

  return firestore.runTransaction(async (transaction) => {
    const existingSnapshot = await transaction.get(requestReference);
    const existing = existingSnapshot.exists ? existingSnapshot.data() || {} : {};
    if (activeRequest(existing, now)) {
      if (existing.receiverUserId !== targetUserId) {
        throw new HttpsError("permission-denied", "Anfrageziel ungültig.");
      }
      return {
        requestId,
        chatId: safeString(existing.chatId) || chatId,
        status: safeString(existing.status) || "pending",
        created: false,
      };
    }

    const [
      plateSnapshot,
      senderProfileSnapshot,
      senderPublicProfileSnapshot,
      senderVehicleSnapshot,
      senderPrivateVehicleSnapshot,
      senderIdentityV1Snapshot,
      senderVehicleV1Snapshot,
      receiverProfileSnapshot,
      receiverPrivateVehicleSnapshot,
      receiverIdentityV1Snapshot,
      receiverVehicleV1Snapshot,
      visibilitySnapshot,
      filterSnapshot,
      grantSnapshot,
      senderLimitSnapshot,
      targetLimitSnapshot,
      chatSnapshot,
      receiverDeletionSnapshot,
      senderDeletionSnapshot,
    ] = await Promise.all([
      transaction.get(plateReference),
      transaction.get(senderProfileReference),
      transaction.get(senderPublicProfileReference),
      transaction.get(senderVehicleReference),
      transaction.get(senderPrivateVehicleReference),
      transaction.get(senderIdentityV1Reference),
      transaction.get(senderVehicleV1Reference),
      transaction.get(receiverProfileReference),
      transaction.get(receiverPrivateVehicleReference),
      transaction.get(receiverIdentityV1Reference),
      transaction.get(receiverVehicleV1Reference),
      transaction.get(visibilityReference),
      transaction.get(filterReference),
      transaction.get(grantReference),
      transaction.get(senderLimitReference),
      transaction.get(targetLimitReference),
      transaction.get(chatReference),
      transaction.get(receiverDeletionReference),
      transaction.get(senderDeletionReference),
    ]);

    const plate = plateSnapshot.exists ? plateSnapshot.data() || {} : {};
    const senderProfile = senderProfileSnapshot.exists ?
      senderProfileSnapshot.data() || {} : {};
    const senderPublicProfile = senderPublicProfileSnapshot.exists ?
      senderPublicProfileSnapshot.data() || {} : {};
    const senderVehicle = senderVehicleSnapshot.exists ?
      senderVehicleSnapshot.data() || {} : {};
    const senderPrivateVehicle = senderPrivateVehicleSnapshot.exists ?
      senderPrivateVehicleSnapshot.data() || {} : {};
    const senderIdentityV1 = senderIdentityV1Snapshot.exists ?
      senderIdentityV1Snapshot.data() || {} : null;
    const senderVehicleV1 = senderVehicleV1Snapshot.exists ?
      senderVehicleV1Snapshot.data() || {} : null;
    const receiverProfile = receiverProfileSnapshot.exists ?
      receiverProfileSnapshot.data() || {} : {};
    const receiverPrivateVehicle = receiverPrivateVehicleSnapshot.exists ?
      receiverPrivateVehicleSnapshot.data() || {} : {};
    const receiverIdentityV1 = receiverIdentityV1Snapshot.exists ?
      receiverIdentityV1Snapshot.data() || {} : null;
    const receiverVehicleV1 = receiverVehicleV1Snapshot.exists ?
      receiverVehicleV1Snapshot.data() || {} : null;
    const visibility = visibilitySnapshot.exists ?
      visibilitySnapshot.data() || {} : {};
    const filters = filterSnapshot.exists ? filterSnapshot.data() || {} : {};
    const grant = grantSnapshot.exists ? grantSnapshot.data() || {} : {};
    const receiverDeletion = receiverDeletionSnapshot.exists ?
      receiverDeletionSnapshot.data() || {} : {};
    const senderDeletion = senderDeletionSnapshot.exists ?
      senderDeletionSnapshot.data() || {} : {};
    const expectedPlateHash = createHash("sha256")
      .update(plateKey)
      .digest("hex");
    const senderUsesV1 = usesVerificationV1(senderIdentityV1, senderVehicleV1);
    const receiverUsesV1 = usesVerificationV1(
      receiverIdentityV1,
      receiverVehicleV1,
    );
    const senderVehicleVerified = senderUsesV1 ?
      isEffectiveVehicleVerification({
        identity: senderIdentityV1,
        verification: senderVehicleV1,
        vehicle: senderPrivateVehicle,
        now,
      }) : senderVehicle.isVerified === true;
    const receiverVehicleVerified = receiverUsesV1 ?
      isEffectiveVehicleVerification({
        identity: receiverIdentityV1,
        verification: receiverVehicleV1,
        vehicle: receiverPrivateVehicle,
        now,
      }) : plate.isVerified === true;

    if (accountDeletionBlocksWrites(senderDeletion) ||
        accountDeletionBlocksWrites(receiverDeletion) ||
        !plateSnapshot.exists || plate.ownerUserId !== targetUserId ||
        plate.vehicleId !== vehicleId || plate.countryCode !== countryCode ||
        safeString(plate.plateKey).toUpperCase() !== plateKey ||
        plate.isActive !== true || plate.isDeleted !== false ||
        !receiverVehicleVerified || plate.allowContactRequests !== true ||
        !senderVehicleVerified) {
      throw new HttpsError("not-found", "Das Fahrzeug ist nicht verfügbar.");
    }
    if (!grantSnapshot.exists || grant.requesterUserId !== senderId ||
        grant.targetUserId !== targetUserId || grant.countryCode !== countryCode ||
        grant.vehicleId !== vehicleId ||
        grant.plateHash !== expectedPlateHash ||
        (timestampMillis(grant.expiresAt) || 0) <= now.getTime()) {
      throw new HttpsError(
        "failed-precondition",
        "Suche das Kennzeichen erneut, bevor du Kontakt anfragst.",
      );
    }
    if (visibility.allowContactRequests === false ||
        visibility.plateSearchVisibility === "onlyMe") {
      throw new HttpsError("permission-denied", "Kontaktanfragen sind deaktiviert.");
    }
    const quietUntil = timestampMillis(filters.contactRequestQuietModeUntil);
    if (quietUntil != null && quietUntil > now.getTime()) {
      throw new HttpsError("permission-denied", "Kontaktanfragen sind pausiert.");
    }
    const verificationLevel = safeString(filters.requesterVerificationLevel) ||
      ((filters.requireVerifiedRequester === true ||
        filters.autoRejectUnverified === true) ? "identityVerified" : "all");
    if (verificationLevel === "identityVerified" &&
        !isIdentityVerified(
          senderProfile,
          senderPublicProfile,
          senderIdentityV1,
          now,
        )) {
      throw new HttpsError(
        "permission-denied",
        "Für diese Anfrage ist eine bestätigte Identität erforderlich.",
      );
    }
    const allowedReasons = Array.isArray(filters.allowedContactReasons) ?
      filters.allowedContactReasons.filter((value) => typeof value === "string") :
      [...supportedReasons];
    if (!allowedReasons.includes(requestReason)) {
      throw new HttpsError("permission-denied", "Dieser Anfragegrund ist gesperrt.");
    }

    const senderLimit = senderLimitSnapshot.exists ?
      senderLimitSnapshot.data() || {} : {};
    const targetLimit = targetLimitSnapshot.exists ?
      targetLimitSnapshot.data() || {} : {};
    const senderCount = activeWindow(senderLimit, now) &&
      Number.isInteger(senderLimit.requestCount) ? senderLimit.requestCount + 1 : 1;
    const targetCount = activeWindow(targetLimit, now) &&
      Number.isInteger(targetLimit.requestCount) ? targetLimit.requestCount + 1 : 1;
    const lastTargetRequestAt = timestampMillis(targetLimit.lastRequestedAt);
    if (lastTargetRequestAt != null &&
        now.getTime() - lastTargetRequestAt < requestCooldownMs) {
      throw new HttpsError(
        "resource-exhausted",
        "Bitte warte, bevor du dieses Fahrzeug erneut kontaktierst.",
      );
    }
    if (senderCount > maxRequestsPerWindow ||
        targetCount > maxRequestsPerTargetWindow) {
      throw new HttpsError(
        "resource-exhausted",
        "Das Kontaktanfrage-Limit ist erreicht.",
      );
    }

    const existingChat = chatSnapshot.exists ? chatSnapshot.data() || {} : {};
    if (existingChat.status === "blocked" ||
        existingChat.blockedBy === targetUserId ||
        existingChat.deletedBy?.[targetUserId] === true) {
      throw new HttpsError("permission-denied", "Kontakt ist nicht möglich.");
    }

    const senderDisplayName = profileDisplayName(
      senderProfile,
      senderPublicProfile,
    );
    const receiverDisplayName = safeProjection(
      receiverProfile.displayName || plate.displayName,
      80,
    ) || "plaqa Nutzer";
    const senderPhotoUrl = trustedProfilePhotoUrl(
      senderPublicProfile.photoUrl || senderProfile.photoUrl,
      senderId,
    );
    const receiverPhotoUrl = trustedProfilePhotoUrl(
      receiverProfile.photoUrl || plate.profilePhotoUrl || plate.photoUrl,
      targetUserId,
    );
    const displayPlate = safeProjection(
      plate.displayPlate || plate.plateDisplayLabel,
      32,
    );
    const vehicleBrand = safeProjection(plate.vehicleBrand, 120);
    const vehicleModel = safeProjection(plate.vehicleModel, 120);
    const vehicleColor = safeProjection(plate.vehicleColor, 80);
    const vehicleLabel = safeProjection(plate.vehicleLabel, 160);
    const participants = [senderId, targetUserId].sort();
    const requestData = {
      senderUserId: senderId,
      receiverUserId: targetUserId,
      targetUserId,
      countryCode,
      vehicleId,
      senderVehicleId,
      plateKey,
      senderDisplayName,
      senderPhotoUrl,
      receiverDisplayName,
      receiverPhotoUrl,
      displayPlate,
      vehicleBrand,
      vehicleModel,
      vehicleColor,
      vehicleLabel,
      requestReason,
      message,
      status: "pending",
      chatId,
      createdAt: nowTimestamp,
      updatedAt: nowTimestamp,
      expiresAt,
      isDeleted: false,
    };
    const chatData = {
      participants,
      status: "active",
      requestId,
      createdAt: nowTimestamp,
      updatedAt: nowTimestamp,
      lastMessage: message,
      lastMessageAt: nowTimestamp,
      isDeleted: false,
      senderUserId: senderId,
      receiverUserId: targetUserId,
      senderDisplayName,
      senderPhotoUrl,
      receiverDisplayName,
      receiverPhotoUrl,
      countryCode,
      vehicleId,
      displayPlate,
      vehicleBrand,
      vehicleModel,
      vehicleColor,
      vehicleLabel,
      blockedBy: null,
      deletedBy: {[senderId]: false, [targetUserId]: false},
      archivedBy: {[senderId]: false, [targetUserId]: false},
      archivedUpdatedAtBy: {
        [senderId]: nowTimestamp,
        [targetUserId]: nowTimestamp,
      },
      lastReadAtBy: {[senderId]: nowTimestamp},
      manualUnreadBy: {[senderId]: false, [targetUserId]: false},
      manualUnreadUpdatedAtBy: {
        [senderId]: nowTimestamp,
        [targetUserId]: nowTimestamp,
      },
    };
    const messageData = {
      chatId,
      senderUserId: senderId,
      type: "text",
      text: message,
      createdAt: nowTimestamp,
      updatedAt: nowTimestamp,
      isDeleted: false,
      replyToMessageId: null,
      replyToText: null,
    };

    transaction.set(requestReference, requestData);
    transaction.set(chatReference, chatData);
    transaction.set(messageReference, messageData);
    transaction.set(senderLimitReference, {
      userId: senderId,
      windowStartedAt: activeWindow(senderLimit, now) ?
        senderLimit.windowStartedAt : nowTimestamp,
      requestCount: senderCount,
      updatedAt: nowTimestamp,
      expiresAt: quotaExpiresAt,
    });
    transaction.set(targetLimitReference, {
      senderUserId: senderId,
      receiverUserId: targetUserId,
      windowStartedAt: activeWindow(targetLimit, now) ?
        targetLimit.windowStartedAt : nowTimestamp,
      requestCount: targetCount,
      lastRequestedAt: nowTimestamp,
      updatedAt: nowTimestamp,
      expiresAt: quotaExpiresAt,
    });
    transaction.delete(grantReference);

    return {requestId, chatId, status: "pending", created: true};
  });
}

module.exports = {
  contactGrantId,
  contactRequestDocumentId,
  createContactRequest,
  maxRequestsPerTargetWindow,
  maxRequestsPerWindow,
  requestCooldownMs,
};
