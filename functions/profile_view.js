const {createHash} = require("node:crypto");
const {Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");

const profileViewWindowMs = 24 * 60 * 60 * 1000;
const maxProfileViewsPerWindow = 100;

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function safeUserId(value) {
  const normalized = safeString(value);
  return /^[A-Za-z0-9_-]{1,128}$/u.test(normalized) ? normalized : "";
}

function digestId(parts) {
  return createHash("sha256").update(parts.join("\u0000")).digest("hex");
}

function periodKey(now) {
  return now.toISOString().slice(0, 10);
}

function hasExactParticipants(value, first, second) {
  return Array.isArray(value) && value.length === 2 &&
    value.includes(first) && value.includes(second);
}

function isConnectionCandidate(data, viewerUserId, profileUserId) {
  return data?.status === "active" &&
    hasExactParticipants(data.participants, viewerUserId, profileUserId) &&
    safeString(data.requestId).length > 0 &&
    safeString(data.chatId).length > 0;
}

function accountDeletionBlocksWrites(data) {
  return ["requested", "processing", "completed"].includes(
    safeString(data?.status),
  );
}

async function recordProfileViewTransaction({
  firestore,
  viewerUserId,
  profileUserId,
  now = new Date(),
}) {
  const viewerId = safeUserId(viewerUserId);
  const targetId = safeUserId(profileUserId);
  if (viewerId.length === 0) {
    throw new HttpsError("unauthenticated", "Bitte melde dich neu an.");
  }
  if (targetId.length === 0 || targetId === viewerId) {
    return {recorded: false};
  }

  const profileReference = firestore.doc(`public_profiles/${targetId}`);
  const profileDeletionReference = firestore.doc(
    `account_deletions/${targetId}`,
  );
  const viewerDeletionReference = firestore.doc(
    `account_deletions/${viewerId}`,
  );
  const connectionReferences = [
    firestore.doc(`profile_connections/${viewerId}_${targetId}`),
    firestore.doc(`profile_connections/${targetId}_${viewerId}`),
  ];
  const day = periodKey(now);
  const eventReference = firestore.doc(
    `profile_view_events/${digestId([viewerId, targetId, day])}`,
  );
  const limitReference = firestore.doc(
    `profile_view_rate_limits/${digestId([viewerId, day])}`,
  );
  const nowTimestamp = Timestamp.fromDate(now);
  const expiresAt = Timestamp.fromDate(
    new Date(now.getTime() + 8 * profileViewWindowMs),
  );

  return firestore.runTransaction(async (transaction) => {
    const [
      profileSnapshot,
      firstConnection,
      secondConnection,
      profileDeletionSnapshot,
      viewerDeletionSnapshot,
    ] =
      await Promise.all([
        transaction.get(profileReference),
        transaction.get(connectionReferences[0]),
        transaction.get(connectionReferences[1]),
        transaction.get(profileDeletionReference),
        transaction.get(viewerDeletionReference),
      ]);
    if (accountDeletionBlocksWrites(
      viewerDeletionSnapshot.exists ? viewerDeletionSnapshot.data() : null,
    ) || accountDeletionBlocksWrites(
      profileDeletionSnapshot.exists ? profileDeletionSnapshot.data() : null,
    ) || !profileSnapshot.exists ||
        profileSnapshot.data()?.profileAccessEnabled !== true) {
      throw new HttpsError("not-found", "Das Profil ist nicht verfügbar.");
    }
    const connectionSnapshot = [firstConnection, secondConnection].find(
      (snapshot) => snapshot.exists && isConnectionCandidate(
        snapshot.data(),
        viewerId,
        targetId,
      ),
    );
    if (connectionSnapshot == null) {
      throw new HttpsError("permission-denied", "Das Profil ist nicht freigegeben.");
    }

    const connection = connectionSnapshot.data() || {};
    const requestId = safeString(connection.requestId);
    const chatId = safeString(connection.chatId);
    const [requestSnapshot, chatSnapshot, eventSnapshot, limitSnapshot] =
      await Promise.all([
        transaction.get(firestore.doc(`contact_requests/${requestId}`)),
        transaction.get(firestore.doc(`chats/${chatId}`)),
        transaction.get(eventReference),
        transaction.get(limitReference),
      ]);
    const request = requestSnapshot.exists ? requestSnapshot.data() || {} : {};
    const chat = chatSnapshot.exists ? chatSnapshot.data() || {} : {};
    if (!requestSnapshot.exists || request.status !== "accepted" ||
        !chatSnapshot.exists || chat.requestId !== requestId ||
        !["active", "archived"].includes(chat.status) ||
        !hasExactParticipants(chat.participants, viewerId, targetId) ||
        chat.deletedBy?.[viewerId] === true ||
        chat.deletedBy?.[targetId] === true || chat.status === "blocked") {
      throw new HttpsError("permission-denied", "Das Profil ist nicht freigegeben.");
    }
    if (eventSnapshot.exists) return {recorded: false};

    const limit = limitSnapshot.exists ? limitSnapshot.data() || {} : {};
    const count = Number.isInteger(limit.viewCount) ? limit.viewCount + 1 : 1;
    if (count > maxProfileViewsPerWindow) {
      throw new HttpsError(
        "resource-exhausted",
        "Das tägliche Profilaufruf-Limit ist erreicht.",
      );
    }
    const currentCount = Number(profileSnapshot.data()?.profileViewCount);
    transaction.update(profileReference, {
      profileViewCount: Number.isSafeInteger(currentCount) && currentCount >= 0 ?
        currentCount + 1 : 1,
      profileViewedAt: nowTimestamp,
    });
    transaction.set(eventReference, {
      viewerUserId: viewerId,
      profileUserId: targetId,
      period: day,
      recordedAt: nowTimestamp,
      expiresAt,
    });
    transaction.set(limitReference, {
      viewerUserId: viewerId,
      period: day,
      viewCount: count,
      updatedAt: nowTimestamp,
      expiresAt,
    });
    return {recorded: true};
  });
}

module.exports = {
  maxProfileViewsPerWindow,
  recordProfileViewTransaction,
};
