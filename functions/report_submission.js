const {createHash} = require("node:crypto");
const {Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");

const reportCooldownMs = 60 * 1000;
const reportDailyWindowMs = 24 * 60 * 60 * 1000;
const reportDuplicateWindowMs = 15 * 60 * 1000;
const maxReportsPerDailyWindow = 10;
const allowedCountries = new Set(["DE", "AT", "CH"]);
const allowedCategories = new Set([
  "vehicleOpen",
  "lightsOrElectric",
  "vehicleBlocked",
  "visibleDamage",
  "acuteDanger",
  "policeOnSite",
]);

async function submitPlateHintTransaction({
  firestore,
  reporterUserId,
  input,
  now = Timestamp.now(),
}) {
  const userId = safeString(reporterUserId);
  if (userId.length === 0) {
    throw new HttpsError("unauthenticated", "Bitte melde dich neu an.");
  }

  const submission = validateSubmissionInput(userId, input);
  const reportReference = firestore.doc(`reports/${submission.reportId}`);
  const plateReference = firestore.doc(
    `plates/${submission.countryCode}_${submission.plateKey}`,
  );
  const rateLimitReference = firestore.doc(`report_rate_limits/${userId}`);

  return firestore.runTransaction(async (transaction) => {
    const reportSnapshot = await transaction.get(reportReference);
    if (reportSnapshot.exists) {
      const existing = reportSnapshot.data() ?? {};
      if (safeString(existing.reporterUserId) === userId) {
        return {
          accepted: true,
          duplicate: true,
          reportId: submission.reportId,
          status: safeString(existing.status) || "submitted",
        };
      }
      throw new HttpsError(
        "already-exists",
        "Dieser Hinweis wurde bereits verarbeitet.",
        {reason: "report-id-conflict"},
      );
    }

    const plateSnapshot = await transaction.get(plateReference);
    if (!plateSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "Für dieses Kennzeichen wurde kein aktiver Nutzer gefunden.",
      );
    }
    const plate = plateSnapshot.data() ?? {};
    const targetUserId = safeString(plate.ownerUserId);
    if (plate.isActive !== true || plate.isDeleted === true ||
        targetUserId.length === 0) {
      throw new HttpsError(
        "not-found",
        "Für dieses Kennzeichen wurde kein aktiver Nutzer gefunden.",
      );
    }
    if (plate.allowAnonymousReports !== true) {
      throw new HttpsError(
        "permission-denied",
        "Dieser Nutzer nimmt aktuell keine anonymen Hinweise an.",
      );
    }
    if (targetUserId === userId) {
      throw new HttpsError(
        "invalid-argument",
        "Du kannst dir nicht selbst einen Hinweis senden.",
      );
    }

    const rateLimitSnapshot = await transaction.get(rateLimitReference);
    const nextRateLimit = evaluateRateLimit({
      userId,
      current: rateLimitSnapshot.data() ?? {},
      submission,
      now,
    });
    const expiresAt = Timestamp.fromMillis(
      now.toMillis() + reportDailyWindowMs,
    );
    const report = reportDocument({
      submission,
      reporterUserId: userId,
      targetUserId,
      now,
      expiresAt,
    });

    transaction.create(reportReference, report);
    transaction.create(
      firestore.doc(
        `users/${targetUserId}/report_notifications/${submission.reportId}`,
      ),
      incomingNotificationDocument(report),
    );
    transaction.create(
      firestore.doc(
        `users/${userId}/sent_report_notifications/${submission.reportId}`,
      ),
      sentNotificationDocument(report),
    );
    transaction.set(rateLimitReference, nextRateLimit, {merge: false});

    return {
      accepted: true,
      duplicate: false,
      reportId: submission.reportId,
      status: "submitted",
    };
  });
}

function validateSubmissionInput(reporterUserId, input) {
  if (input == null || typeof input !== "object" || Array.isArray(input)) {
    throw new HttpsError(
      "invalid-argument",
      "Der Hinweis ist noch nicht vollständig.",
    );
  }

  const reportId = safeString(input.reportId);
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(reportId)) {
    throw new HttpsError(
      "invalid-argument",
      "Der Hinweis konnte nicht eindeutig bestimmt werden.",
    );
  }
  const countryCode = safeString(input.countryCode).toUpperCase();
  const plateRegion = normalizedPlatePart(input.plateRegion);
  const plateLetters = normalizedPlatePart(input.plateLetters);
  const plateNumbers = normalizedPlatePart(input.plateNumbers);
  const plateKey = `${plateRegion}${plateLetters}${plateNumbers}`;
  if (!allowedCountries.has(countryCode) ||
      !/^[A-ZÄÖÜ0-9]{1,3}$/.test(plateRegion) ||
      !/^[A-ZÄÖÜ0-9]{1,3}$/.test(plateLetters) ||
      !/^[A-Z0-9]{1,6}$/.test(plateNumbers) ||
      !/^[A-ZÄÖÜ0-9]{2,20}$/.test(plateKey)) {
    throw new HttpsError("invalid-argument", "Bitte prüfe das Kennzeichen.");
  }

  const category = safeString(input.category);
  if (!allowedCategories.has(category)) {
    throw new HttpsError(
      "invalid-argument",
      "Bitte wähle einen gültigen Hinweis aus.",
    );
  }
  const message = limitedString(input.message, 160);
  if (message.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "Bitte ergänze eine kurze Beschreibung.",
    );
  }
  const location = validatedLocation(input);
  const expectedImagePath =
    `report_images/${reportId}/${reporterUserId}/evidence.jpg`;
  const imagePath = safeString(input.imagePath);
  if (imagePath.length > 0 && imagePath !== expectedImagePath) {
    throw new HttpsError(
      "invalid-argument",
      "Das Beweisfoto konnte nicht zugeordnet werden.",
    );
  }

  return {
    reportId,
    countryCode,
    plateKey,
    plateRegion,
    plateLetters,
    plateNumbers,
    category,
    message,
    ...location,
    imagePath: imagePath.length === 0 ? null : imagePath,
  };
}

function validatedLocation(input) {
  const locationMode = safeString(input.locationMode);
  const locationLabel = limitedString(input.locationLabel, 160);
  if (locationLabel.length === 0) {
    throw new HttpsError("invalid-argument", "Der Standort ist ungültig.");
  }

  if (locationMode === "gps") {
    const latitude = Number(input.latitude);
    const longitude = Number(input.longitude);
    if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
        !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
      throw new HttpsError("invalid-argument", "Der Standort ist ungültig.");
    }
    return {locationMode, latitude, longitude, locationLabel};
  }

  if (locationMode === "manual") {
    const manualAddress = limitedString(input.manualAddress, 160);
    if (manualAddress.length < 3 || manualAddress !== locationLabel) {
      throw new HttpsError(
        "invalid-argument",
        "Bitte gib eine gültige Adresse ein.",
      );
    }
    return {locationMode, manualAddress, locationLabel};
  }

  throw new HttpsError("invalid-argument", "Der Standort ist ungültig.");
}

function evaluateRateLimit({userId, current, submission, now}) {
  const nowMs = now.toMillis();
  const duplicateKey = duplicateKeyFor(submission);
  const recentDuplicates = activeDuplicateWindows(
    current.recentDuplicateUntilByKey,
    nowMs,
  );
  const duplicateUntil = timestampFromValue(recentDuplicates[duplicateKey]);
  if (duplicateUntil != null && duplicateUntil.toMillis() > nowMs) {
    throw new HttpsError(
      "already-exists",
      "Dieser Hinweis wurde vor Kurzem bereits gesendet.",
      {reason: "duplicate"},
    );
  }

  const lastSubmittedAt = timestampFromValue(current.lastSubmittedAt);
  if (lastSubmittedAt != null &&
      nowMs - lastSubmittedAt.toMillis() < reportCooldownMs) {
    throw new HttpsError(
      "resource-exhausted",
      "Bitte warte kurz, bevor du einen weiteren Hinweis sendest.",
      {reason: "cooldown"},
    );
  }

  const currentWindowStartedAt = timestampFromValue(current.windowStartedAt);
  const hasActiveWindow = currentWindowStartedAt != null &&
    nowMs >= currentWindowStartedAt.toMillis() &&
    nowMs - currentWindowStartedAt.toMillis() < reportDailyWindowMs;
  const recentSubmissions = activeSubmissionTimes(
    current.recentSubmissionTimestamps,
    nowMs,
  );
  if (recentSubmissions.length === 0 && hasActiveWindow &&
      Number.isInteger(current.windowCount) && current.windowCount > 0) {
    const legacyTimestamp = lastSubmittedAt ?? currentWindowStartedAt;
    const legacyCount = Math.min(
      current.windowCount,
      maxReportsPerDailyWindow,
    );
    for (let index = 0; index < legacyCount; index += 1) {
      recentSubmissions.push(legacyTimestamp);
    }
  }
  if (recentSubmissions.length >= maxReportsPerDailyWindow) {
    throw new HttpsError(
      "resource-exhausted",
      "Du hast das tägliche Limit für Hinweise erreicht.",
      {reason: "daily-limit"},
    );
  }

  recentSubmissions.push(now);
  recentDuplicates[duplicateKey] = Timestamp.fromMillis(
    nowMs + reportDuplicateWindowMs,
  );
  return {
    userId,
    lastSubmittedAt: now,
    windowStartedAt: recentSubmissions[0],
    windowCount: recentSubmissions.length,
    recentSubmissionTimestamps: recentSubmissions,
    recentDuplicateUntilByKey: recentDuplicates,
    updatedAt: now,
  };
}

function activeSubmissionTimes(value, nowMs) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map(timestampFromValue)
    .filter((timestamp) => timestamp != null &&
      timestamp.toMillis() <= nowMs &&
      nowMs - timestamp.toMillis() < reportDailyWindowMs)
    .sort((left, right) => left.toMillis() - right.toMillis());
}

function activeDuplicateWindows(value, nowMs) {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return Object.fromEntries(
    Object.entries(value).filter(([, until]) => {
      const timestamp = timestampFromValue(until);
      return timestamp != null && timestamp.toMillis() > nowMs;
    }),
  );
}

function duplicateKeyFor(submission) {
  return createHash("sha256")
    .update([
      submission.countryCode,
      submission.plateKey,
      submission.category,
    ].join("|"))
    .digest("hex");
}

function reportDocument({
  submission,
  reporterUserId,
  targetUserId,
  now,
  expiresAt,
}) {
  return compactObject({
    reportId: submission.reportId,
    type: "plate_hint",
    reporterUserId,
    targetUserId,
    countryCode: submission.countryCode,
    plateKey: submission.plateKey,
    plateRegion: submission.plateRegion,
    plateLetters: submission.plateLetters,
    plateNumbers: submission.plateNumbers,
    category: submission.category,
    message: submission.message,
    locationMode: submission.locationMode,
    latitude: submission.latitude,
    longitude: submission.longitude,
    manualAddress: submission.manualAddress,
    locationLabel: submission.locationLabel,
    status: "submitted",
    hasImage: submission.imagePath != null,
    imagePath: submission.imagePath,
    anonymousToTarget: true,
    createdAt: now,
    updatedAt: now,
    expiresAt,
    isDeleted: false,
  });
}

function incomingNotificationDocument(report) {
  const {reporterUserId: _, ...notification} = report;
  return {...notification, status: "unread"};
}

function sentNotificationDocument(report) {
  const {
    reporterUserId: _,
    targetUserId: __,
    ...notification
  } = report;
  return notification;
}

function compactObject(value) {
  return Object.fromEntries(
    Object.entries(value).filter(([, item]) => item != null),
  );
}

function timestampFromValue(value) {
  return value instanceof Timestamp ? value : null;
}

function normalizedPlatePart(value) {
  return safeString(value).toUpperCase().replace(/[^A-ZÄÖÜ0-9]/g, "");
}

function limitedString(value, maxLength) {
  return safeString(value).slice(0, maxLength).trim();
}

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function isOwnedReportImagePath(userId, input) {
  const reportId = safeString(input?.reportId);
  const imagePath = safeString(input?.imagePath);
  return /^[A-Za-z0-9_-]{8,128}$/.test(reportId) &&
    imagePath === `report_images/${reportId}/${userId}/evidence.jpg`;
}

module.exports = {
  isOwnedReportImagePath,
  submitPlateHintTransaction,
};
