const {randomUUID} = require("node:crypto");
const {Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");

const recoveryCooldownMs = 24 * 60 * 60 * 1000;
const processingLeaseMs = 15 * 60 * 1000;
const approvalConfirmation = "MFA WIEDERHERSTELLEN";
const caseCreationConfirmation = "MFA FALL ANLEGEN";
const identityVerificationConfirmation = "IDENTITÄT GEPRÜFT";
const activeStatuses = new Set([
  "pending",
  "identity_verified",
  "awaiting_second_approval",
  "processing",
  "processing_failed",
]);
const reviewReasonCodes = new Set([
  "identity-verified",
  "insufficient-evidence",
  "duplicate-request",
  "security-risk",
  "manual-review",
]);

async function requestMfaRecovery({
  firestore,
  authAdmin,
  authContext,
  input,
  now = new Date(),
  createId = randomUUID,
}) {
  const userId = requireAuthenticated(authContext);
  const userRecord = await requireActiveSession({
    authAdmin,
    authContext,
    userId,
  });
  const factors = userRecord.multiFactor?.enrolledFactors ?? [];
  if (userRecord.emailVerified !== true) {
    throw new HttpsError(
      "failed-precondition",
      "Bestätige zuerst deine E-Mail Adresse.",
      {reason: "email-not-verified"},
    );
  }
  if (factors.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Für dieses Konto ist kein zweiter Faktor eingerichtet.",
      {reason: "mfa-not-enrolled"},
    );
  }

  const reference = firestore.doc(`mfa_recovery_requests/${userId}`);
  const requestId = createId();
  const platform = normalizedPlatform(input?.platform);
  const providerTypes = providerIds(userRecord, authContext);
  const reservation = await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.exists ? snapshot.data() ?? {} : {};
    const status = safeString(data.status);
    if (activeStatuses.has(status)) {
      return {
        created: false,
        requestId: safeString(data.requestId),
        status,
      };
    }

    const updatedAt = timestampDate(data.updatedAt);
    if (updatedAt != null &&
        now.getTime() - updatedAt.getTime() < recoveryCooldownMs) {
      throw new HttpsError(
        "resource-exhausted",
        "Eine neue Wiederherstellungsanfrage ist noch nicht möglich.",
        {reason: "recovery-cooldown"},
      );
    }

    transaction.set(reference, {
      requestId,
      userId,
      status: "pending",
      maskedEmail: maskEmail(userRecord.email),
      providerTypes,
      factorCount: factors.length,
      platform,
      requestedAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    });
    return {created: true, requestId, status: "pending"};
  });

  if (reservation.created) {
    await Promise.all([
      writeRecoveryAudit({
        firestore,
        userId,
        requestId: reservation.requestId,
        eventType: "mfa_recovery_requested",
        actorUserId: userId,
        result: "succeeded",
        now,
      }),
      writeSecurityActivity({
        firestore,
        userId,
        eventType: "mfa_recovery_requested",
        platform,
        status: "succeeded",
        now,
      }),
    ]);
  }

  return {
    accepted: true,
    alreadyRequested: !reservation.created,
    requestId: reservation.requestId,
    status: publicStatus(reservation.status),
  };
}

async function getMfaRecoveryStatus({firestore, authAdmin, authContext}) {
  const userId = requireAuthenticated(authContext);
  await requireActiveSession({authAdmin, authContext, userId});
  const snapshot = await firestore.doc(`mfa_recovery_requests/${userId}`).get();
  if (!snapshot.exists) {
    return {status: "none"};
  }
  return publicRecoveryStatus(snapshot.data() ?? {});
}

async function listMfaRecoveryCases({
  firestore,
  authAdmin,
  authContext,
  input,
}) {
  await requireActiveAdmin({authAdmin, authContext});
  const requestedLimit = Number(input?.limit);
  const limit = Number.isInteger(requestedLimit) ?
    Math.min(Math.max(requestedLimit, 1), 50) : 25;
  const snapshot = await firestore.collection("mfa_recovery_requests")
    .orderBy("updatedAt", "desc")
    .limit(limit)
    .get();
  return {
    cases: snapshot.docs
      .map((document) => adminRecoveryCase(document.data() ?? {}))
      .filter((item) => item.targetUserId.length > 0),
  };
}

async function openMfaRecoveryCase({
  firestore,
  authAdmin,
  authContext,
  input,
  now = new Date(),
  createId = randomUUID,
}) {
  const adminUserId = await requireActiveAdmin({authAdmin, authContext});
  const targetUserId = safeString(input?.targetUserId);
  requireDifferentActor(adminUserId, targetUserId);
  if (targetUserId.length === 0 ||
      safeString(input?.confirmation) !== caseCreationConfirmation) {
    throw new HttpsError(
      "failed-precondition",
      "Bestätige die Fallanlage ausdrücklich.",
      {reason: "admin-confirmation-required"},
    );
  }

  const userRecord = await authAdmin.getUser(targetUserId);
  const factors = userRecord.multiFactor?.enrolledFactors ?? [];
  if (userRecord.emailVerified !== true || factors.length === 0) {
    throw new HttpsError(
      "failed-precondition",
      "Für dieses Konto kann kein MFA-Recovery-Fall angelegt werden.",
    );
  }

  const reference = firestore.doc(`mfa_recovery_requests/${targetUserId}`);
  const requestId = createId();
  const reservation = await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.exists ? snapshot.data() ?? {} : {};
    const status = safeString(data.status);
    if (activeStatuses.has(status)) {
      return {
        created: false,
        requestId: safeString(data.requestId),
        status,
      };
    }
    const updatedAt = timestampDate(data.updatedAt);
    if (updatedAt != null &&
        now.getTime() - updatedAt.getTime() < recoveryCooldownMs) {
      throw new HttpsError(
        "resource-exhausted",
        "Für dieses Konto besteht noch eine Recovery-Sperrfrist.",
      );
    }

    transaction.set(reference, {
      requestId,
      userId: targetUserId,
      status: "pending",
      source: "admin-support",
      maskedEmail: maskEmail(userRecord.email),
      providerTypes: providerIds(userRecord, null),
      factorCount: factors.length,
      platform: "server",
      requestedAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    });
    return {created: true, requestId, status: "pending"};
  });

  if (reservation.created) {
    await recordReviewEvents({
      firestore,
      userId: targetUserId,
      requestId: reservation.requestId,
      adminUserId,
      eventType: "mfa_recovery_case_opened",
      result: "succeeded",
      now,
    });
  }
  return {
    created: reservation.created,
    requestId: reservation.requestId,
    status: reservation.status,
  };
}

async function markMfaRecoveryIdentityVerified({
  firestore,
  authAdmin,
  authContext,
  input,
  now = new Date(),
}) {
  const adminUserId = await requireActiveAdmin({authAdmin, authContext});
  const targetUserId = safeString(input?.targetUserId);
  const requestId = safeString(input?.requestId);
  requireDifferentActor(adminUserId, targetUserId);
  if (targetUserId.length === 0 || requestId.length === 0 ||
      safeString(input?.confirmation) !== identityVerificationConfirmation) {
    throw new HttpsError(
      "failed-precondition",
      "Bestätige die externe Identitätsprüfung ausdrücklich.",
      {reason: "identity-confirmation-required"},
    );
  }

  const reference = firestore.doc(`mfa_recovery_requests/${targetUserId}`);
  const result = await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    assertMatchingRequest(snapshot, requestId);
    const status = safeString(snapshot.data()?.status);
    if (status === "identity_verified") {
      return {changed: false, status};
    }
    if (status !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        "Dieser Fall kann nicht mehr als geprüft markiert werden.",
      );
    }
    transaction.set(reference, {
      status: "identity_verified",
      identityVerifiedBy: adminUserId,
      identityVerifiedAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
    }, {merge: true});
    return {changed: true, status: "identity_verified"};
  });

  if (result.changed) {
    await recordReviewEvents({
      firestore,
      userId: targetUserId,
      requestId,
      adminUserId,
      eventType: "mfa_recovery_identity_verified",
      result: "succeeded",
      now,
    });
  }
  return result;
}

async function reviewMfaRecovery({
  firestore,
  authAdmin,
  authContext,
  input,
  now = new Date(),
  createId = randomUUID,
}) {
  const adminUserId = await requireActiveAdmin({authAdmin, authContext});
  const targetUserId = safeString(input?.targetUserId);
  const requestId = safeString(input?.requestId);
  const decision = safeString(input?.decision);
  const reasonCode = normalizedReasonCode(input?.reasonCode);
  requireDifferentActor(adminUserId, targetUserId);
  if (targetUserId.length === 0 || requestId.length === 0 ||
      !["approve", "reject"].includes(decision)) {
    throw new HttpsError("invalid-argument", "Die Anfrage ist unvollständig.");
  }
  if (decision === "approve" &&
      safeString(input?.confirmation) !== approvalConfirmation) {
    throw new HttpsError(
      "failed-precondition",
      "Bestätige die Sicherheitsaktion ausdrücklich.",
      {reason: "admin-confirmation-required"},
    );
  }

  const reference = firestore.doc(`mfa_recovery_requests/${targetUserId}`);
  const leaseId = createId();
  const reservation = await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    assertMatchingRequest(snapshot, requestId);
    const data = snapshot.data() ?? {};
    const status = safeString(data.status);
    if (["completed", "rejected"].includes(status)) {
      return {action: "none", status};
    }

    if (decision === "reject") {
      if (!["pending", "identity_verified", "awaiting_second_approval"]
        .includes(status)) {
        throw new HttpsError(
          "failed-precondition",
          "Die technische Verarbeitung hat bereits begonnen.",
        );
      }
      transaction.set(reference, {
        status: "rejected",
        rejectedBy: adminUserId,
        reviewReasonCode: reasonCode,
        rejectedAt: Timestamp.fromDate(now),
        updatedAt: Timestamp.fromDate(now),
      }, {merge: true});
      return {action: "rejected", status: "rejected"};
    }

    if (status === "identity_verified") {
      transaction.set(reference, {
        status: "awaiting_second_approval",
        firstApprovedBy: adminUserId,
        firstApprovedAt: Timestamp.fromDate(now),
        reviewReasonCode: reasonCode,
        updatedAt: Timestamp.fromDate(now),
      }, {merge: true});
      return {action: "first_approval", status: "awaiting_second_approval"};
    }

    if (status === "awaiting_second_approval") {
      if (safeString(data.firstApprovedBy) === adminUserId) {
        throw new HttpsError(
          "permission-denied",
          "Die zweite Freigabe muss durch einen anderen Admin erfolgen.",
          {reason: "second-admin-required"},
        );
      }
      transaction.set(reference, {
        status: "processing",
        secondApprovedBy: adminUserId,
        secondApprovedAt: Timestamp.fromDate(now),
        processingLeaseId: leaseId,
        processingStartedAt: Timestamp.fromDate(now),
        updatedAt: Timestamp.fromDate(now),
        failureCode: null,
      }, {merge: true});
      return {
        action: "process",
        status: "processing",
        leaseId,
        sessionsRevoked: data.sessionsRevokedAt != null,
      };
    }

    if (["processing", "processing_failed"].includes(status)) {
      const processingStartedAt = timestampDate(data.processingStartedAt);
      const hasFreshLease = status === "processing" &&
        processingStartedAt != null &&
        now.getTime() - processingStartedAt.getTime() < processingLeaseMs;
      if (hasFreshLease) {
        return {action: "none", status: "processing"};
      }
      if (safeString(data.firstApprovedBy).length === 0 ||
          safeString(data.secondApprovedBy).length === 0 ||
          safeString(data.firstApprovedBy) === safeString(data.secondApprovedBy)) {
        throw new HttpsError(
          "failed-precondition",
          "Die notwendige Vier-Augen-Freigabe fehlt.",
        );
      }
      transaction.set(reference, {
        status: "processing",
        processingLeaseId: leaseId,
        processingStartedAt: Timestamp.fromDate(now),
        updatedAt: Timestamp.fromDate(now),
        failureCode: null,
      }, {merge: true});
      return {
        action: "process",
        status: "processing",
        leaseId,
        sessionsRevoked: data.sessionsRevokedAt != null,
      };
    }

    throw new HttpsError(
      "failed-precondition",
      status === "pending" ?
        "Schließe zuerst die externe Identitätsprüfung ab." :
        "Die Anfrage ist nicht prüfbar.",
    );
  });

  if (reservation.action === "rejected") {
    await recordReviewEvents({
      firestore,
      userId: targetUserId,
      requestId,
      adminUserId,
      eventType: "mfa_recovery_rejected",
      result: "succeeded",
      now,
    });
    return {status: "rejected", changed: true};
  }
  if (reservation.action === "first_approval") {
    await recordReviewEvents({
      firestore,
      userId: targetUserId,
      requestId,
      adminUserId,
      eventType: "mfa_recovery_first_approved",
      result: "succeeded",
      now,
    });
    return {
      status: "awaiting_second_approval",
      changed: true,
      requiresSecondAdmin: true,
    };
  }
  if (reservation.action !== "process") {
    return {status: reservation.status, changed: false};
  }

  return completeApprovedRecovery({
    firestore,
    authAdmin,
    reference,
    targetUserId,
    requestId,
    adminUserId,
    leaseId: reservation.leaseId,
    sessionsRevoked: reservation.sessionsRevoked,
    now,
  });
}

async function completeApprovedRecovery({
  firestore,
  authAdmin,
  reference,
  targetUserId,
  requestId,
  adminUserId,
  leaseId,
  sessionsRevoked,
  now,
}) {
  try {
    await recordReviewEvents({
      firestore,
      userId: targetUserId,
      requestId,
      adminUserId,
      eventType: "mfa_recovery_second_approved",
      result: "succeeded",
      now,
    });
    if (!sessionsRevoked) {
      await authAdmin.revokeRefreshTokens(targetUserId);
      const refreshedUser = await authAdmin.getUser(targetUserId);
      await reference.set({
        sessionsRevokedAt: Timestamp.fromDate(now),
        tokensValidAfterTime: safeDateString(refreshedUser.tokensValidAfterTime),
        updatedAt: Timestamp.fromDate(now),
      }, {merge: true});
      await recordReviewEvents({
        firestore,
        userId: targetUserId,
        requestId,
        adminUserId,
        eventType: "mfa_recovery_sessions_revoked",
        result: "succeeded",
        now,
      });
    }

    const targetUser = await authAdmin.getUser(targetUserId);
    const factors = targetUser.multiFactor?.enrolledFactors ?? [];
    if (factors.length > 0) {
      await authAdmin.updateUser(targetUserId, {
        multiFactor: {enrolledFactors: []},
      });
    }
    await recordReviewEvents({
      firestore,
      userId: targetUserId,
      requestId,
      adminUserId,
      eventType: "mfa_recovery_factor_removed",
      result: "succeeded",
      now,
    });
    await firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (safeString(snapshot.data()?.processingLeaseId) !== leaseId) {
        throw new HttpsError(
          "aborted",
          "Der Recovery-Fall wird bereits anderweitig verarbeitet.",
        );
      }
      transaction.set(reference, {
        status: "completed",
        completedAt: Timestamp.fromDate(now),
        updatedAt: Timestamp.fromDate(now),
        failureCode: null,
        processingLeaseId: null,
      }, {merge: true});
    });
    await recordReviewEvents({
      firestore,
      userId: targetUserId,
      requestId,
      adminUserId,
      eventType: "mfa_recovery_completed",
      result: "succeeded",
      now,
    });
    return {
      status: "completed",
      changed: true,
      requiresFreshSignIn: true,
      requiresMfaEnrollment: true,
    };
  } catch (error) {
    if (error instanceof HttpsError && error.code === "aborted") {
      throw error;
    }
    const markedFailed = await firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      if (safeString(snapshot.data()?.processingLeaseId) !== leaseId) {
        return false;
      }
      transaction.set(reference, {
        status: "processing_failed",
        failureCode: "admin-action-failed",
        lastFailedAt: Timestamp.fromDate(now),
        updatedAt: Timestamp.fromDate(now),
        processingLeaseId: null,
      }, {merge: true});
      return true;
    });
    if (markedFailed) {
      await recordReviewEvents({
        firestore,
        userId: targetUserId,
        requestId,
        adminUserId,
        eventType: "mfa_recovery_failed",
        result: "failed",
        now,
      });
    }
    throw new HttpsError(
      "internal",
      "Die Wiederherstellung konnte nicht abgeschlossen werden.",
    );
  }
}

async function recordReviewEvents({
  firestore,
  userId,
  requestId,
  adminUserId,
  eventType,
  result,
  now,
}) {
  await Promise.all([
    writeRecoveryAudit({
      firestore,
      userId,
      requestId,
      eventType,
      actorUserId: adminUserId,
      result,
      now,
    }),
    writeSecurityActivity({
      firestore,
      userId,
      eventType,
      platform: "server",
      status: result,
      now,
    }),
  ]);
}

async function writeRecoveryAudit({
  firestore,
  userId,
  requestId,
  eventType,
  actorUserId,
  result,
  now,
}) {
  const auditId = `${now.getTime()}_${randomUUID()}`;
  await firestore.doc(
    `mfa_recovery_requests/${userId}/audit/${auditId}`,
  ).set({
    requestId,
    eventType,
    actorUserId,
    result,
    occurredAt: Timestamp.fromDate(now),
  });
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

function publicRecoveryStatus(data) {
  return {
    requestId: safeString(data.requestId),
    status: publicStatus(safeString(data.status)),
    requestedAtMs: timestampDate(data.requestedAt)?.getTime() ?? null,
    updatedAtMs: timestampDate(data.updatedAt)?.getTime() ?? null,
  };
}

function publicStatus(status) {
  if (["completed", "rejected"].includes(status)) return status;
  if (activeStatuses.has(status) || status === "approved") return "pending";
  return "none";
}

function adminRecoveryCase(data) {
  return {
    requestId: safeString(data.requestId),
    targetUserId: safeString(data.userId),
    status: safeString(data.status) || "pending",
    source: safeString(data.source) || "user",
    maskedEmail: safeString(data.maskedEmail),
    providerTypes: Array.isArray(data.providerTypes) ?
      data.providerTypes.map(safeString).filter(Boolean) : [],
    factorCount: Number.isInteger(data.factorCount) ? data.factorCount : 0,
    platform: safeString(data.platform),
    identityVerifiedBy: safeString(data.identityVerifiedBy),
    firstApprovedBy: safeString(data.firstApprovedBy),
    secondApprovedBy: safeString(data.secondApprovedBy),
    failureCode: safeString(data.failureCode),
    requestedAtMs: timestampDate(data.requestedAt)?.getTime() ?? null,
    updatedAtMs: timestampDate(data.updatedAt)?.getTime() ?? null,
  };
}

function requireAuthenticated(authContext) {
  const userId = safeString(authContext?.uid);
  if (userId.length === 0) {
    throw new HttpsError("unauthenticated", "Bitte melde dich neu an.");
  }
  return userId;
}

async function requireActiveAdmin({authAdmin, authContext}) {
  const userId = requireAuthenticated(authContext);
  if (authContext?.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Diese Aktion ist nicht erlaubt.");
  }
  await requireActiveSession({authAdmin, authContext, userId});
  return userId;
}

async function requireActiveSession({authAdmin, authContext, userId}) {
  const userRecord = await authAdmin.getUser(userId);
  if (userRecord.disabled === true) {
    throw new HttpsError("permission-denied", "Diese Aktion ist nicht erlaubt.");
  }
  const validAfterMs = Date.parse(safeString(userRecord.tokensValidAfterTime));
  const authTimeSeconds = Number(authContext?.token?.auth_time);
  if (Number.isFinite(validAfterMs) && Number.isFinite(authTimeSeconds) &&
      authTimeSeconds * 1000 < validAfterMs) {
    throw new HttpsError(
      "unauthenticated",
      "Deine Sitzung ist abgelaufen. Melde dich neu an.",
      {reason: "session-revoked"},
    );
  }
  return userRecord;
}

function requireDifferentActor(adminUserId, targetUserId) {
  if (targetUserId.length > 0 && adminUserId === targetUserId) {
    throw new HttpsError(
      "permission-denied",
      "Der betroffene Nutzer darf den eigenen Recovery-Fall nicht freigeben.",
    );
  }
}

function assertMatchingRequest(snapshot, requestId) {
  if (!snapshot.exists || safeString(snapshot.data()?.requestId) !== requestId) {
    throw new HttpsError("not-found", "Die Anfrage wurde nicht gefunden.");
  }
}

function providerIds(userRecord, authContext) {
  const providers = new Set();
  const currentProvider = safeString(
    authContext?.token?.firebase?.sign_in_provider,
  );
  for (const provider of userRecord.providerData ?? []) {
    providers.add(safeString(provider.providerId));
  }
  providers.add(currentProvider);
  return [...providers]
    .filter((provider) => ["password", "google.com", "apple.com"]
      .includes(provider))
    .sort();
}

function maskEmail(value) {
  const email = safeString(value).toLowerCase();
  const separator = email.lastIndexOf("@");
  if (separator <= 0) return "E-Mail geschützt";
  const local = email.slice(0, separator);
  const domain = email.slice(separator + 1);
  const dot = domain.lastIndexOf(".");
  const host = dot > 0 ? domain.slice(0, dot) : domain;
  const suffix = dot > 0 ? domain.slice(dot) : "";
  return `${local[0]}***@${host[0] ?? "*"}***${suffix}`;
}

function normalizedPlatform(value) {
  const platform = safeString(value).toLowerCase();
  return ["android", "ios", "web", "windows", "macos", "linux"]
    .includes(platform) ? platform : "unknown";
}

function normalizedReasonCode(value) {
  const reasonCode = safeString(value);
  return reviewReasonCodes.has(reasonCode) ? reasonCode : "manual-review";
}

function timestampDate(value) {
  if (value != null && typeof value.toDate === "function") {
    return value.toDate();
  }
  return value instanceof Date ? value : null;
}

function safeDateString(value) {
  const date = new Date(safeString(value));
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

module.exports = {
  approvalConfirmation,
  caseCreationConfirmation,
  getMfaRecoveryStatus,
  identityVerificationConfirmation,
  listMfaRecoveryCases,
  markMfaRecoveryIdentityVerified,
  maskEmail,
  openMfaRecoveryCase,
  requestMfaRecovery,
  reviewMfaRecovery,
};
