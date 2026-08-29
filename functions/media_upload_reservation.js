const {createHash, randomUUID} = require("node:crypto");
const {Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");

const uploadReservationLifetimeMs = 10 * 60 * 1000;
const uploadReservationCleanupGraceMs = 24 * 60 * 60 * 1000;
const uploadQuotaWindowMs = 24 * 60 * 60 * 1000;
const maxUploadReservationsPerWindow = 100;
const maxUploadBytesPerWindow = 1024 * 1024 * 1024;
const maxStoredUploadBytesPerAccount = 2 * 1024 * 1024 * 1024;

const uploadPolicies = [
  {
    category: "chatImage",
    pattern: /^chat_images\/([^/]+)\/([^/]+)\/([^/]+\.jpg)$/,
    contentTypes: new Set(["image/jpeg"]),
    maxBytes: 10 * 1024 * 1024,
    userIndex: 2,
  },
  {
    category: "chatDocument",
    pattern: /^chat_documents\/([^/]+)\/([^/]+)\/([^/]+)$/,
    contentTypes: null,
    maxBytes: 25 * 1024 * 1024,
    userIndex: 2,
  },
  {
    category: "chatVoiceMemo",
    pattern: /^chat_voice_memos\/([^/]+)\/([^/]+)\/([^/]+\.m4a)$/,
    contentTypes: new Set(["audio/mp4"]),
    maxBytes: 15 * 1024 * 1024,
    userIndex: 2,
  },
  {
    category: "chatVideo",
    pattern: /^chat_videos\/([^/]+)\/([^/]+)\/([^/]+\.mp4)$/,
    contentTypes: new Set(["video/mp4"]),
    maxBytes: 80 * 1024 * 1024,
    userIndex: 2,
  },
  {
    category: "story",
    pattern: /^chat_stories\/([^/]+)\/[0-9]{12,24}\.(jpg|mp4)$/,
    contentTypes: new Set(["image/jpeg", "video/mp4"]),
    maxBytes: 80 * 1024 * 1024,
    userIndex: 1,
  },
  {
    category: "story",
    pattern: /^chat_stories\/([^/]+)\/([0-9]{12,24})\/media\.(jpg|mp4)$/,
    contentTypes: new Set(["image/jpeg", "video/mp4"]),
    maxBytes: 80 * 1024 * 1024,
    userIndex: 1,
  },
  {
    category: "reportImage",
    pattern: /^report_images\/([^/]+)\/([^/]+)\/evidence\.jpg$/,
    contentTypes: new Set(["image/jpeg"]),
    maxBytes: 10 * 1024 * 1024,
    userIndex: 2,
  },
  {
    category: "profilePost",
    pattern: /^profile_posts\/([^/]+)\/([^/]+)\/media_[0-9]{1,2}\.(jpg|mp4)$/,
    contentTypes: new Set(["image/jpeg", "video/mp4"]),
    maxBytes: 80 * 1024 * 1024,
    userIndex: 1,
  },
  {
    category: "vehicleGallery",
    pattern: /^vehicle_gallery\/([^/]+)\/([^/]+)\/([^/]+)$/,
    contentTypes: new Set(["image/jpeg", "video/mp4"]),
    maxBytes: 80 * 1024 * 1024,
    userIndex: 1,
  },
];

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function timestampMillis(value) {
  if (value != null && typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  return null;
}

function policyForUpload({userId, storagePath, contentType, sizeBytes}) {
  for (const policy of uploadPolicies) {
    const match = storagePath.match(policy.pattern);
    if (match == null || match[policy.userIndex] !== userId) {
      continue;
    }
    if (policy.contentTypes != null && !policy.contentTypes.has(contentType)) {
      continue;
    }
    if (sizeBytes <= 0 || sizeBytes > policy.maxBytes) {
      continue;
    }
    return policy;
  }
  return null;
}

async function reserveMediaUpload({firestore, userId, input, now = new Date()}) {
  const storagePath = safeString(input?.storagePath);
  const contentType = safeString(input?.contentType).toLowerCase();
  const sizeBytes = Number(input?.sizeBytes);
  const policy = policyForUpload({
    userId,
    storagePath,
    contentType,
    sizeBytes,
  });
  if (safeString(userId).length === 0) {
    throw new HttpsError("unauthenticated", "Bitte melde dich neu an.");
  }
  if (policy == null || !Number.isInteger(sizeBytes)) {
    throw new HttpsError(
      "invalid-argument",
      "Der Upload konnte nicht sicher reserviert werden.",
    );
  }

  const reservationId = randomUUID();
  const reservationReference = firestore.doc(
    `_media_upload_reservations/${reservationId}`,
  );
  const limitReference = firestore.doc(`_media_upload_limits/${userId}`);
  const nowTimestamp = Timestamp.fromDate(now);
  const expiresAt = Timestamp.fromMillis(
    now.getTime() + uploadReservationLifetimeMs,
  );

  await firestore.runTransaction(async (transaction) => {
    const limitSnapshot = await transaction.get(limitReference);
    const limit = limitSnapshot.exists ? limitSnapshot.data() ?? {} : {};
    const windowStartedAtMs = timestampMillis(limit.windowStartedAt);
    const hasActiveWindow = windowStartedAtMs != null &&
      now.getTime() - windowStartedAtMs < uploadQuotaWindowMs;
    const currentCount = Number.isInteger(limit.reservationCount) ?
      limit.reservationCount :
      0;
    const currentBytes = Number.isInteger(limit.reservedBytes) ?
      limit.reservedBytes :
      0;
    const storedBytes = Number.isInteger(limit.storedBytes) ?
      limit.storedBytes :
      0;
    const pendingBytes = Number.isInteger(limit.pendingBytes) ?
      limit.pendingBytes :
      0;
    const reservationCount = hasActiveWindow ? currentCount + 1 : 1;
    const reservedBytes = hasActiveWindow ? currentBytes + sizeBytes : sizeBytes;
    if (reservationCount > maxUploadReservationsPerWindow ||
        reservedBytes > maxUploadBytesPerWindow ||
        storedBytes + pendingBytes + sizeBytes >
          maxStoredUploadBytesPerAccount) {
      throw new HttpsError(
        "resource-exhausted",
        "Das tägliche Upload-Limit ist erreicht.",
      );
    }

    transaction.set(limitReference, {
      userId,
      windowStartedAt: hasActiveWindow ? limit.windowStartedAt : nowTimestamp,
      reservationCount,
      reservedBytes,
      pendingBytes: pendingBytes + sizeBytes,
      storedBytes,
      updatedAt: nowTimestamp,
    }, {merge: true});
    transaction.create(reservationReference, {
      reservationId,
      userId,
      category: policy.category,
      storagePath,
      contentType,
      maxBytes: sizeBytes,
      status: "reserved",
      createdAt: nowTimestamp,
      expiresAt,
    });
  });

  return {reservationId, expiresAt: expiresAt.toMillis()};
}

function uploadUsageId(storagePath, generation) {
  return createHash("sha256")
    .update(`${storagePath}\u0000${generation}`)
    .digest("hex");
}

async function recordFinalizedMediaUpload({
  firestore,
  object,
  now = Timestamp.now(),
}) {
  const reservationId = safeString(object?.metadata?.uploadReservationId);
  const storagePath = safeString(object?.name);
  const generation = safeString(object?.generation);
  const contentType = safeString(object?.contentType);
  const sizeBytes = Number(object?.size);
  if (!/^[0-9a-f-]{36}$/.test(reservationId) ||
      storagePath.length === 0 || generation.length === 0 ||
      !Number.isInteger(sizeBytes) || sizeBytes <= 0) {
    return false;
  }

  const reservationReference = firestore.doc(
    `_media_upload_reservations/${reservationId}`,
  );
  const usageReference = firestore.doc(
    `_media_upload_objects/${uploadUsageId(storagePath, generation)}`,
  );
  return firestore.runTransaction(async (transaction) => {
    const reservationSnapshot = await transaction.get(reservationReference);
    const usageSnapshot = await transaction.get(usageReference);
    if (usageSnapshot.exists) {
      return true;
    }
    const reservation = reservationSnapshot.exists ?
      reservationSnapshot.data() ?? {} : {};
    const userId = safeString(reservation.userId);
    const valid = safeString(reservation.status) === "reserved" &&
      safeString(reservation.storagePath) === storagePath &&
      safeString(reservation.contentType) === contentType &&
      sizeBytes === Number(reservation.maxBytes) &&
      userId.length > 0;
    if (!valid) {
      return false;
    }

    const limitReference = firestore.doc(`_media_upload_limits/${userId}`);
    const limitSnapshot = await transaction.get(limitReference);
    const limit = limitSnapshot.exists ? limitSnapshot.data() ?? {} : {};
    const pendingBytes = Number.isInteger(limit.pendingBytes) ?
      limit.pendingBytes : 0;
    const storedBytes = Number.isInteger(limit.storedBytes) ?
      limit.storedBytes : 0;
    transaction.set(reservationReference, {
      status: "consumed",
      consumedAt: now,
      updatedAt: now,
    }, {merge: true});
    transaction.set(limitReference, {
      pendingBytes: Math.max(0, pendingBytes - sizeBytes),
      storedBytes: storedBytes + sizeBytes,
      updatedAt: now,
    }, {merge: true});
    transaction.create(usageReference, {
      userId,
      storagePath,
      generation,
      sizeBytes,
      createdAt: now,
    });
    return true;
  });
}

async function recordDeletedMediaUpload({
  firestore,
  object,
  now = Timestamp.now(),
}) {
  const storagePath = safeString(object?.name);
  const generation = safeString(object?.generation);
  if (storagePath.length === 0 || generation.length === 0) {
    return false;
  }
  const usageReference = firestore.doc(
    `_media_upload_objects/${uploadUsageId(storagePath, generation)}`,
  );
  return firestore.runTransaction(async (transaction) => {
    const usageSnapshot = await transaction.get(usageReference);
    if (!usageSnapshot.exists) {
      return false;
    }
    const usage = usageSnapshot.data() ?? {};
    const userId = safeString(usage.userId);
    const sizeBytes = Number(usage.sizeBytes);
    if (userId.length === 0 || !Number.isInteger(sizeBytes)) {
      return false;
    }
    const limitReference = firestore.doc(`_media_upload_limits/${userId}`);
    const limitSnapshot = await transaction.get(limitReference);
    const limit = limitSnapshot.exists ? limitSnapshot.data() ?? {} : {};
    const storedBytes = Number.isInteger(limit.storedBytes) ?
      limit.storedBytes : 0;
    transaction.set(limitReference, {
      storedBytes: Math.max(0, storedBytes - sizeBytes),
      updatedAt: now,
    }, {merge: true});
    transaction.delete(usageReference);
    return true;
  });
}

async function cleanupExpiredMediaUploadReservations({firestore, bucket, now}) {
  const cutoff = Timestamp.fromMillis(
    now.toMillis() - uploadReservationCleanupGraceMs,
  );
  const snapshot = await firestore
    .collection("_media_upload_reservations")
    .where("expiresAt", "<=", cutoff)
    .limit(400)
    .get();
  if (snapshot.empty) {
    return 0;
  }
  for (const document of snapshot.docs) {
    const initialReservation = document.data() ?? {};
    if (safeString(initialReservation.status) === "reserved") {
      const storagePath = safeString(initialReservation.storagePath);
      if (storagePath.length > 0) {
        try {
          const [metadata] = await bucket.file(storagePath).getMetadata();
          await recordFinalizedMediaUpload({
            firestore,
            object: {
              name: storagePath,
              generation: safeString(metadata.generation),
              contentType: safeString(metadata.contentType),
              size: metadata.size,
              metadata: {uploadReservationId: document.id},
            },
            now,
          });
        } catch (error) {
          if (error?.code !== 404 && error?.code !== "404" &&
              error?.code !== "storage/object-not-found") {
            throw error;
          }
        }
      }
    }
    await firestore.runTransaction(async (transaction) => {
      const reservationSnapshot = await transaction.get(document.ref);
      if (!reservationSnapshot.exists) {
        return;
      }
      const reservation = reservationSnapshot.data() ?? {};
      if (safeString(reservation.status) === "reserved") {
        const userId = safeString(reservation.userId);
        const sizeBytes = Number(reservation.maxBytes);
        if (userId.length > 0 && Number.isInteger(sizeBytes)) {
          const limitReference = firestore.doc(
            `_media_upload_limits/${userId}`,
          );
          const limitSnapshot = await transaction.get(limitReference);
          const limit = limitSnapshot.exists ? limitSnapshot.data() ?? {} : {};
          const pendingBytes = Number.isInteger(limit.pendingBytes) ?
            limit.pendingBytes : 0;
          transaction.set(limitReference, {
            pendingBytes: Math.max(0, pendingBytes - sizeBytes),
            updatedAt: now,
          }, {merge: true});
        }
      }
      transaction.delete(document.ref);
    });
  }
  return snapshot.size;
}

module.exports = {
  cleanupExpiredMediaUploadReservations,
  maxUploadBytesPerWindow,
  maxUploadReservationsPerWindow,
  maxStoredUploadBytesPerAccount,
  policyForUpload,
  recordDeletedMediaUpload,
  recordFinalizedMediaUpload,
  reserveMediaUpload,
  uploadQuotaWindowMs,
  uploadReservationCleanupGraceMs,
  uploadReservationLifetimeMs,
};
