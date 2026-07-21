const {Timestamp} = require("firebase-admin/firestore");

const reportCleanupPageSize = 100;
const reportCleanupMaxPages = 5;
const rateLimitCleanupPageSize = 200;
const rateLimitCleanupMaxPages = 3;
const orphanImagePageSize = 100;
const orphanImageMaxPages = 2;
const reportRetentionMs = 24 * 60 * 60 * 1000;
const orphanImageGraceMs = 48 * 60 * 60 * 1000;

async function runReportCleanup({firestore, bucket, now = Timestamp.now()}) {
  const reports = await deleteExpiredPlateHints({
    firestore,
    bucket,
    now,
  });
  const rateLimits = await deleteExpiredReportRateLimits({
    firestore,
    now,
  });
  const orphanImages = await deleteOrphanedReportImages({
    firestore,
    bucket,
    now,
  });

  return {reports, rateLimits, orphanImages};
}

async function deleteExpiredPlateHints({
  firestore,
  bucket,
  now,
  pageSize = reportCleanupPageSize,
  maxPages = reportCleanupMaxPages,
}) {
  const result = {
    scanned: 0,
    deleted: 0,
    skippedNonPlateHints: 0,
    imageDeleteFailures: 0,
  };
  let cursor = null;

  for (let page = 0; page < maxPages; page += 1) {
    let query = firestore
      .collection("reports")
      .where("expiresAt", "<=", now)
      .orderBy("expiresAt")
      .limit(clampedPageSize(pageSize, 150));
    if (cursor != null) {
      query = query.startAfter(cursor);
    }
    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    result.scanned += snapshot.size;
    const batch = firestore.batch();
    const imagePaths = [];
    let deleteCount = 0;
    for (const reportSnapshot of snapshot.docs) {
      const report = reportSnapshot.data() ?? {};
      if (safeString(report.type) !== "plate_hint" ||
          !isExpiredTimestamp(report.expiresAt, now)) {
        result.skippedNonPlateHints += 1;
        continue;
      }

      const reporterUserId = safeDocumentId(report.reporterUserId);
      const targetUserId = safeDocumentId(report.targetUserId);
      const reportId = safeDocumentId(reportSnapshot.id);
      if (reportId.length === 0) {
        continue;
      }

      batch.delete(reportSnapshot.ref);
      if (targetUserId.length > 0) {
        batch.delete(firestore.doc(
          `users/${targetUserId}/report_notifications/${reportId}`,
        ));
      }
      if (reporterUserId.length > 0) {
        batch.delete(firestore.doc(
          `users/${reporterUserId}/sent_report_notifications/${reportId}`,
        ));
      }
      const imagePath = safeString(report.imagePath);
      if (isOwnedReportImagePath(reportId, reporterUserId, imagePath)) {
        imagePaths.push(imagePath);
      }
      deleteCount += 1;
    }

    if (deleteCount > 0) {
      await batch.commit();
      result.deleted += deleteCount;
      result.imageDeleteFailures += await deleteStorageFiles(
        bucket,
        imagePaths,
      );
    }

    cursor = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.size < clampedPageSize(pageSize, 150)) {
      break;
    }
  }

  return result;
}

async function deleteExpiredReportRateLimits({
  firestore,
  now,
  pageSize = rateLimitCleanupPageSize,
  maxPages = rateLimitCleanupMaxPages,
}) {
  const cutoff = Timestamp.fromMillis(now.toMillis() - reportRetentionMs);
  const result = {scanned: 0, deleted: 0};

  for (let page = 0; page < maxPages; page += 1) {
    const snapshot = await firestore
      .collection("report_rate_limits")
      .where("updatedAt", "<=", cutoff)
      .orderBy("updatedAt")
      .limit(clampedPageSize(pageSize, 450))
      .get();
    if (snapshot.empty) {
      break;
    }

    result.scanned += snapshot.size;
    const batch = firestore.batch();
    for (const rateLimit of snapshot.docs) {
      batch.delete(rateLimit.ref);
    }
    await batch.commit();
    result.deleted += snapshot.size;
    if (snapshot.size < clampedPageSize(pageSize, 450)) {
      break;
    }
  }

  return result;
}

async function deleteOrphanedReportImages({
  firestore,
  bucket,
  now,
  gracePeriodMs = orphanImageGraceMs,
  pageSize = orphanImagePageSize,
  maxPages = orphanImageMaxPages,
}) {
  const result = {
    scanned: 0,
    eligible: 0,
    deleted: 0,
    metadataFailures: 0,
    deleteFailures: 0,
  };
  const cutoffMs = now.toMillis() - gracePeriodMs;
  let pageToken;

  for (let page = 0; page < maxPages; page += 1) {
    const [files, nextQuery] = await bucket.getFiles({
      autoPaginate: false,
      maxResults: clampedPageSize(pageSize, 200),
      pageToken,
      prefix: "report_images/",
    });
    if (files.length === 0) {
      break;
    }

    result.scanned += files.length;
    const candidates = [];
    for (const file of files) {
      const identity = reportImageIdentity(file.name);
      if (identity == null) {
        continue;
      }
      try {
        const [metadata] = await file.getMetadata();
        const createdAtMs = Date.parse(metadata.timeCreated ?? "");
        if (Number.isFinite(createdAtMs) && createdAtMs <= cutoffMs) {
          candidates.push({file, identity});
        }
      } catch (_) {
        result.metadataFailures += 1;
      }
    }

    result.eligible += candidates.length;
    if (candidates.length > 0) {
      const reportSnapshots = await firestore.getAll(
        ...candidates.map(({identity}) =>
          firestore.doc(`reports/${identity.reportId}`)),
      );
      for (let index = 0; index < candidates.length; index += 1) {
        if (reportSnapshots[index].exists) {
          continue;
        }
        try {
          await candidates[index].file.delete({ignoreNotFound: true});
          result.deleted += 1;
        } catch (_) {
          result.deleteFailures += 1;
        }
      }
    }

    pageToken = safeString(nextQuery?.pageToken) || undefined;
    if (pageToken == null) {
      break;
    }
  }

  return result;
}

async function deleteStorageFiles(bucket, imagePaths) {
  let failures = 0;
  for (const imagePath of new Set(imagePaths)) {
    try {
      await bucket.file(imagePath).delete({ignoreNotFound: true});
    } catch (_) {
      failures += 1;
    }
  }
  return failures;
}

function isExpiredTimestamp(value, now) {
  return value instanceof Timestamp && value.toMillis() <= now.toMillis();
}

function isOwnedReportImagePath(reportId, reporterUserId, imagePath) {
  return reportId.length > 0 && reporterUserId.length > 0 &&
    imagePath ===
      `report_images/${reportId}/${reporterUserId}/evidence.jpg`;
}

function reportImageIdentity(imagePath) {
  const pattern = new RegExp(
    "^report_images/([A-Za-z0-9_-]{8,128})/" +
    "([A-Za-z0-9_-]{1,128})/evidence\\.jpg$",
  );
  const match = pattern.exec(safeString(imagePath));
  if (match == null) {
    return null;
  }
  return {reportId: match[1], reporterUserId: match[2]};
}

function safeDocumentId(value) {
  const candidate = safeString(value);
  return /^[A-Za-z0-9_-]{1,128}$/.test(candidate) ? candidate : "";
}

function clampedPageSize(value, maximum) {
  return Number.isInteger(value) && value > 0 ?
    Math.min(value, maximum) :
    1;
}

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

module.exports = {
  deleteExpiredPlateHints,
  deleteExpiredReportRateLimits,
  deleteOrphanedReportImages,
  reportImageIdentity,
  runReportCleanup,
};
