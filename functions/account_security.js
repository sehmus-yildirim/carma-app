const {createHash, randomUUID} = require("node:crypto");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");

const recentAuthenticationWindowSeconds = 5 * 60;
const staleProcessingWindowMs = 15 * 60 * 1000;
const firestoreBatchSize = 200;
const storagePageSize = 100;
const storageDeleteConcurrency = 20;

function requireRecentAuthentication(authContext, now = new Date()) {
  const userId = safeString(authContext?.uid);
  if (userId.length === 0) {
    throw new HttpsError("unauthenticated", "Bitte melde dich neu an.");
  }

  const authTime = Number(authContext?.token?.auth_time);
  const nowSeconds = Math.floor(now.getTime() / 1000);
  if (!Number.isFinite(authTime) ||
      nowSeconds - authTime > recentAuthenticationWindowSeconds ||
      authTime > nowSeconds + 60) {
    throw new HttpsError(
      "failed-precondition",
      "Bitte bestätige deine Anmeldung erneut.",
      {reason: "requires-recent-login"},
    );
  }

  return userId;
}

async function requestAccountDeletion({
  firestore,
  authAdmin,
  bucket,
  authContext,
  input,
  logger,
  now = new Date(),
  cleanup = cleanupAccountData,
}) {
  const userId = requireRecentAuthentication(authContext, now);
  const platform = normalizedPlatform(input?.platform);
  const deletionReference = firestore.doc(`account_deletions/${userId}`);
  const reservation = await reserveDeletionRequest({
    firestore,
    deletionReference,
    userId,
    platform,
    now,
  });

  if (!reservation.shouldProcess) {
    return {
      accepted: true,
      status: reservation.status,
      alreadyRequested: true,
    };
  }

  try {
    await deletionReference.set({
      status: "processing",
      processingAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    }, {merge: true});
    await writeSecurityActivity({
      firestore,
      userId,
      eventType: "account_deletion_requested",
      platform,
      status: "succeeded",
      now,
    });

    await cleanup({firestore, bucket, userId, now});

    try {
      await authAdmin.deleteUser(userId);
    } catch (error) {
      if (!isAuthUserNotFound(error)) {
        throw error;
      }
    }

    const completedAt = new Date();
    await deletionReference.set({
      status: "completed",
      completedAt: Timestamp.fromDate(completedAt),
      updatedAt: Timestamp.fromDate(completedAt),
      failureCode: FieldValue.delete(),
    }, {merge: true});

    return {accepted: true, status: "completed", alreadyRequested: false};
  } catch (error) {
    const failedAt = new Date();
    await deletionReference.set({
      status: "failed",
      failedAt: Timestamp.fromDate(failedAt),
      updatedAt: Timestamp.fromDate(failedAt),
      failureCode: publicFailureCode(error),
    }, {merge: true});
    logger?.error("Account deletion failed", {
      errorType: errorType(error),
    });
    throw new HttpsError(
      "internal",
      "Das Konto konnte gerade nicht vollständig gelöscht werden.",
    );
  }
}

async function reserveDeletionRequest({
  firestore,
  deletionReference,
  userId,
  platform,
  now,
}) {
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(deletionReference);
    const data = snapshot.exists ? snapshot.data() ?? {} : {};
    const status = safeString(data.status);
    const updatedAt = timestampDate(data.updatedAt);
    const processingIsStale = status === "processing" &&
      updatedAt != null &&
      now.getTime() - updatedAt.getTime() > staleProcessingWindowMs;

    if (status === "completed" ||
        ((status === "requested" || status === "processing") &&
          !processingIsStale)) {
      return {shouldProcess: false, status};
    }

    const attempts = Number.isInteger(data.attempts) ? data.attempts + 1 : 1;
    transaction.set(deletionReference, {
      userId,
      status: "requested",
      platform,
      requestedAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
      attempts,
      failureCode: FieldValue.delete(),
    }, {merge: true});
    return {shouldProcess: true, status: "requested"};
  });
}

async function revokeAccountSessions({
  firestore,
  authAdmin,
  authContext,
  input,
  now = new Date(),
}) {
  const userId = requireRecentAuthentication(authContext, now);
  await authAdmin.revokeRefreshTokens(userId);
  await writeSecurityActivity({
    firestore,
    userId,
    eventType: "sessions_revoked",
    platform: normalizedPlatform(input?.platform),
    status: "succeeded",
    now,
  });
  return {
    revoked: true,
    requiresLocalSignOut: true,
  };
}

async function cleanupAccountData({firestore, bucket, userId, now}) {
  const pseudonym = deletedUserPseudonym(userId);
  const chatSnapshots = await firestore.collection("chats")
    .where("participants", "array-contains", userId)
    .get();
  const reportSnapshots = await uniqueQueryDocuments([
    firestore.collection("reports").where("reporterUserId", "==", userId),
    firestore.collection("reports").where("targetUserId", "==", userId),
  ]);

  const storagePrefixes = accountStoragePrefixes(userId);
  for (const chatDocument of chatSnapshots.docs) {
    storagePrefixes.push(
      `chat_images/${chatDocument.id}/${userId}/`,
      `chat_documents/${chatDocument.id}/${userId}/`,
      `chat_voice_memos/${chatDocument.id}/${userId}/`,
      `chat_videos/${chatDocument.id}/${userId}/`,
    );
  }
  for (const reportDocument of reportSnapshots) {
    const imagePath = safeString(reportDocument.data()?.imagePath);
    if (imagePath.length > 0) {
      storagePrefixes.push(imagePath);
    }
  }

  await deleteStoragePrefixes(bucket, storagePrefixes);
  await anonymizeSharedChats({
    firestore,
    chatDocuments: chatSnapshots.docs,
    userId,
    pseudonym,
    now,
  });
  await cleanupReports({
    firestore,
    reportDocuments: reportSnapshots,
    userId,
    pseudonym,
    now,
  });
  await removeUserFromStoryAudiences({firestore, userId, now});
  await cleanupCrossOwnerSocialData({
    firestore,
    userId,
    pseudonym,
    now,
  });
  await cleanupVehicleEncounters({firestore, userId});

  await deleteQueryDocuments(firestore, [
    firestore.collection("plates").where("ownerUserId", "==", userId),
    firestore.collection("contact_requests")
      .where("senderUserId", "==", userId),
    firestore.collection("contact_requests")
      .where("receiverUserId", "==", userId),
    firestore.collection("profile_connections")
      .where("participants", "array-contains", userId),
    firestore.collection("follow_relationships")
      .where("followerUserId", "==", userId),
    firestore.collection("follow_relationships")
      .where("followedUserId", "==", userId),
    firestore.collection("chat_stories")
      .where("ownerUserId", "==", userId),
    firestore.collection("verification_requests")
      .where("userId", "==", userId),
    firestore.collection("plate_search_probes")
      .where("requesterUserId", "==", userId),
    firestore.collection("_media_upload_reservations")
      .where("userId", "==", userId),
    firestore.collection("_media_upload_objects")
      .where("userId", "==", userId),
  ]);

  await deleteDocumentIfPresent(
    firestore.doc(`report_rate_limits/${userId}`),
  );
  await deleteDocumentIfPresent(
    firestore.doc(`plate_search_rate_limits/${userId}`),
  );
  await deleteDocumentIfPresent(
    firestore.doc(`vehicle_hero_rate_limits/${userId}`),
  );
  await deleteDocumentIfPresent(
    firestore.doc(`_media_upload_limits/${userId}`),
  );
  await recursiveDeleteIfPresent(
    firestore,
    firestore.doc(`mfa_recovery_requests/${userId}`),
  );
  await recursiveDeleteIfPresent(
    firestore,
    firestore.doc(`public_profiles/${userId}`),
  );
  await recursiveDeleteIfPresent(
    firestore,
    firestore.doc(`users/${userId}`),
  );
}

async function cleanupCrossOwnerSocialData({
  firestore,
  userId,
  pseudonym,
  now,
}) {
  const [likes, comments, replies, reactions, reports] = await Promise.all([
    uniqueQueryDocuments([
      firestore.collectionGroup("likes").where("userId", "==", userId),
    ]),
    uniqueQueryDocuments([
      firestore.collectionGroup("comments")
        .where("authorUserId", "==", userId),
    ]),
    uniqueQueryDocuments([
      firestore.collectionGroup("replies")
        .where("authorUserId", "==", userId),
    ]),
    uniqueQueryDocuments([
      firestore.collectionGroup("reactions").where("userId", "==", userId),
    ]),
    uniqueQueryDocuments([
      firestore.collectionGroup("reports")
        .where("reporterUserId", "==", userId),
    ]),
  ]);
  const timestamp = Timestamp.fromDate(now);
  const mutations = [];

  for (const document of [...likes, ...reactions]) {
    mutations.push({type: "delete", reference: document.ref});
  }
  for (const document of reports) {
    if (document.ref.path.includes("/social_posts/")) {
      mutations.push({type: "delete", reference: document.ref});
    }
  }
  for (const document of [...comments, ...replies]) {
    mutations.push({
      type: "set",
      reference: document.ref,
      data: {
        authorUserId: pseudonym,
        authorDisplayName: "Gelöschtes Konto",
        authorPhotoUrl: "",
        text: "",
        isDeleted: true,
        accountDeleted: true,
        updatedAt: timestamp,
      },
    });
  }

  await commitMutations(firestore, mutations);
}

async function cleanupVehicleEncounters({firestore, userId}) {
  const snapshot = await firestore.collection("vehicle_encounters")
    .where("participantUserIds", "array-contains", userId)
    .get();
  const references = new Map();

  for (const document of snapshot.docs) {
    const encounter = document.data() ?? {};
    const endpoints = [
      [encounter.initiatorUserId, encounter.initiatorVehicleId],
      [encounter.recipientUserId, encounter.recipientVehicleId],
    ];
    for (const [participantUserId, vehicleId] of endpoints) {
      const safeUserId = safeDocumentId(participantUserId);
      const safeVehicleId = safeDocumentId(vehicleId);
      if (safeUserId.length === 0 || safeVehicleId.length === 0) {
        continue;
      }
      const reference = firestore.doc(
        `public_profiles/${safeUserId}/vehicles/${safeVehicleId}/` +
        `encounters/${document.id}`,
      );
      references.set(reference.path, reference);
    }
    references.set(document.ref.path, document.ref);
  }

  await commitMutations(
    firestore,
    [...references.values()].map((reference) => ({
      type: "delete",
      reference,
    })),
  );
}

async function anonymizeSharedChats({
  firestore,
  chatDocuments,
  userId,
  pseudonym,
  now,
}) {
  const timestamp = Timestamp.fromDate(now);
  const mutations = [];

  for (const chatDocument of chatDocuments) {
    const chat = chatDocument.data() ?? {};
    const update = {
      participants: listValue(chat.participants)
        .map((participant) => participant === userId ? pseudonym : participant),
      status: "blocked",
      blockedBy: pseudonym,
      blockedAt: timestamp,
      updatedAt: timestamp,
      favoriteBy: withoutMapKey(chat.favoriteBy, userId),
      pinnedBy: withoutMapKey(chat.pinnedBy, userId),
      mutedBy: withoutMapKey(chat.mutedBy, userId),
      archivedBy: withoutMapKey(chat.archivedBy, userId),
      manualUnreadBy: withoutMapKey(chat.manualUnreadBy, userId),
      lastReadAtBy: withoutMapKey(chat.lastReadAtBy, userId),
      deletedBy: {
        ...withoutMapKey(chat.deletedBy, userId),
        [pseudonym]: true,
      },
      accountDeletedBy: {
        ...withoutMapKey(chat.accountDeletedBy, userId),
        [pseudonym]: true,
      },
    };

    if (safeString(chat.senderUserId) === userId) {
      update.senderDisplayName = "Gelöschtes Konto";
      update.senderPhotoUrl = null;
      update.senderUserId = pseudonym;
    }
    if (safeString(chat.receiverUserId) === userId) {
      update.receiverDisplayName = "Gelöschtes Konto";
      update.receiverPhotoUrl = null;
      update.receiverUserId = pseudonym;
      update.displayPlate = null;
      update.vehicleBrand = null;
      update.vehicleModel = null;
      update.vehicleColor = null;
      update.vehicleLabel = null;
    }
    mutations.push({type: "set", reference: chatDocument.ref, data: update});

    const messages = await chatDocument.ref.collection("messages").get();
    for (const message of messages.docs) {
      const messageData = message.data() ?? {};
      const sentByDeletedUser = safeString(messageData.senderUserId) === userId;
      mutations.push({
        type: "set",
        reference: message.ref,
        data: {
          ...(sentByDeletedUser ? {
            senderUserId: pseudonym,
            senderAccountDeleted: true,
            imageUrl: null,
            imagePath: null,
            fileUrl: null,
            filePath: null,
          } : {}),
          viewOnceOpenedAtBy: withoutMapKey(
            messageData.viewOnceOpenedAtBy,
            userId,
          ),
          reactionBy: withoutMapKey(messageData.reactionBy, userId),
          deletedFor: withoutMapKey(messageData.deletedFor, userId),
          updatedAt: timestamp,
        },
      });
    }
  }

  await commitMutations(firestore, mutations);
}

async function cleanupReports({
  firestore,
  reportDocuments,
  userId,
  pseudonym,
  now,
}) {
  const mutations = [];
  const timestamp = Timestamp.fromDate(now);
  for (const reportDocument of reportDocuments) {
    const report = reportDocument.data() ?? {};
    const reporterUserId = safeString(report.reporterUserId);
    const targetUserId = safeString(report.targetUserId);
    if (targetUserId.length > 0) {
      mutations.push({
        type: "delete",
        reference: firestore.doc(
          `users/${targetUserId}/report_notifications/${reportDocument.id}`,
        ),
      });
    }
    if (reporterUserId.length > 0) {
      mutations.push({
        type: "delete",
        reference: firestore.doc(
          `users/${reporterUserId}/sent_report_notifications/${reportDocument.id}`,
        ),
      });
    }
    if (safeString(report.type) === "plate_hint") {
      mutations.push({type: "delete", reference: reportDocument.ref});
      continue;
    }

    const update = {
      participantAccountDeleted: true,
      imagePath: null,
      updatedAt: timestamp,
    };
    if (safeString(report.reporterUserId) === userId) {
      update.reporterUserId = pseudonym;
    }
    if (safeString(report.targetUserId) === userId) {
      update.targetUserId = pseudonym;
    }
    mutations.push({type: "set", reference: reportDocument.ref, data: update});
  }
  await commitMutations(firestore, mutations);
}

async function removeUserFromStoryAudiences({firestore, userId, now}) {
  const snapshot = await firestore.collection("chat_stories")
    .where("viewerUserIds", "array-contains", userId)
    .get();
  const mutations = [];
  for (const document of snapshot.docs) {
    const story = document.data() ?? {};
    if (safeString(story.ownerUserId) === userId) {
      continue;
    }
    mutations.push({
      type: "set",
      reference: document.ref,
      data: {
        viewerUserIds: listValue(story.viewerUserIds)
          .filter((viewerUserId) => viewerUserId !== userId),
        viewedAtBy: withoutMapKey(story.viewedAtBy, userId),
        viewerNameBy: withoutMapKey(story.viewerNameBy, userId),
        viewerPhotoUrlBy: withoutMapKey(story.viewerPhotoUrlBy, userId),
        updatedAt: Timestamp.fromDate(now),
      },
    });
  }
  await commitMutations(firestore, mutations);
}

async function deleteQueryDocuments(firestore, queries) {
  const documents = await uniqueQueryDocuments(queries);
  await commitMutations(
    firestore,
    documents.map((document) => ({
      type: "delete",
      reference: document.ref,
    })),
  );
}

async function uniqueQueryDocuments(queries) {
  const documents = new Map();
  for (const query of queries) {
    const snapshot = await query.get();
    for (const document of snapshot.docs) {
      documents.set(document.ref.path, document);
    }
  }
  return [...documents.values()];
}

async function commitMutations(firestore, mutations) {
  for (let index = 0; index < mutations.length; index += firestoreBatchSize) {
    const batch = firestore.batch();
    for (const mutation of mutations.slice(index, index + firestoreBatchSize)) {
      if (mutation.type === "delete") {
        batch.delete(mutation.reference);
      } else {
        batch.set(mutation.reference, mutation.data, {merge: true});
      }
    }
    await batch.commit();
  }
}

async function recursiveDeleteIfPresent(firestore, reference) {
  try {
    await firestore.recursiveDelete(reference);
  } catch (error) {
    if (error?.code !== 5 && error?.code !== "not-found") {
      throw error;
    }
  }
}

async function deleteDocumentIfPresent(reference) {
  const snapshot = await reference.get();
  if (snapshot.exists) {
    await reference.delete();
  }
}

async function deleteStoragePrefixes(bucket, prefixes) {
  for (const prefix of new Set(prefixes.filter((value) => value.length > 0))) {
    let pageToken;
    do {
      const [files, nextQuery] = await bucket.getFiles({
        prefix,
        autoPaginate: false,
        maxResults: storagePageSize,
        pageToken,
      });
      for (let index = 0; index < files.length;
        index += storageDeleteConcurrency) {
        await Promise.all(
          files.slice(index, index + storageDeleteConcurrency)
            .map((file) => file.delete({ignoreNotFound: true})),
        );
      }
      pageToken = nextQuery?.pageToken;
    } while (pageToken != null);
  }
}

function accountStoragePrefixes(userId) {
  return [
    `profile_photos/${userId}/`,
    `profile_posts/${userId}/`,
    `vehicle_gallery/${userId}/`,
    `vehicle_heroes/${userId}/`,
    `profile_documents/${userId}/`,
    `chat_stories/${userId}/`,
  ];
}

async function writeSecurityActivity({
  firestore,
  userId,
  eventType,
  platform,
  status,
  now,
}) {
  const activityId = `${now.getTime()}_${randomUUID()}`;
  await firestore.doc(
    `users/${userId}/security_activities/${activityId}`,
  ).set({
    eventType,
    occurredAt: Timestamp.fromDate(now),
    platform,
    status,
  });
}

function deletedUserPseudonym(userId) {
  return `deleted_${createHash("sha256").update(userId).digest("hex").slice(0, 20)}`;
}

function normalizedPlatform(value) {
  const platform = safeString(value).toLowerCase();
  return ["android", "ios", "web", "windows", "macos", "linux"]
    .includes(platform) ? platform : "unknown";
}

function publicFailureCode(error) {
  if (isAuthUserNotFound(error)) {
    return "auth-user-missing";
  }
  return "cleanup-failed";
}

function isAuthUserNotFound(error) {
  return error?.code === "auth/user-not-found" || error?.code === "user-not-found";
}

function timestampDate(value) {
  if (value != null && typeof value.toDate === "function") {
    return value.toDate();
  }
  return value instanceof Date ? value : null;
}

function mapValue(value) {
  return value != null && typeof value === "object" && !Array.isArray(value) ?
    value : {};
}

function listValue(value) {
  return Array.isArray(value) ? value.filter((item) => typeof item === "string") : [];
}

function withoutMapKey(value, key) {
  const result = {...mapValue(value)};
  delete result[key];
  return result;
}

function errorType(error) {
  return safeString(error?.constructor?.name) || "UnknownError";
}

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function safeDocumentId(value) {
  const documentId = safeString(value);
  return /^[^/]{1,512}$/.test(documentId) ? documentId : "";
}

module.exports = {
  accountStoragePrefixes,
  cleanupAccountData,
  cleanupCrossOwnerSocialData,
  cleanupVehicleEncounters,
  deleteStoragePrefixes,
  deletedUserPseudonym,
  normalizedPlatform,
  requestAccountDeletion,
  requireRecentAuthentication,
  revokeAccountSessions,
};
