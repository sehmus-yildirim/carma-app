const assert = require('node:assert/strict');
const path = require('node:path');
const { createRequire } = require('node:module');
const { after, afterEach, before, describe, test } = require('node:test');

const functionsRequire = createRequire(
  path.resolve(__dirname, '../../functions/package.json'),
);
const {
  deleteApp,
  initializeApp,
} = functionsRequire('firebase-admin/app');
const {
  Timestamp,
  getFirestore,
} = functionsRequire('firebase-admin/firestore');
const {
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  deleteExpiredPlateHints,
  deleteExpiredReportRateLimits,
  deleteOrphanedReportImages,
  reportImageIdentity,
  runReportCleanup,
} = require('../../functions/report_cleanup');

const projectId = 'carma-a84e4';
const reporterUserId = 'cleanup-reporter';
const targetUserId = 'cleanup-target';
const firestorePort = Number(process.env.FIRESTORE_EMULATOR_PORT || 8080);
const hourMs = 60 * 60 * 1000;

let adminApp;
let db;
let testEnv;

class FakeFile {
  constructor(bucket, name, timeCreated, options = {}) {
    this.bucket = bucket;
    this.name = name;
    this.timeCreated = timeCreated;
    this.failMetadata = options.failMetadata === true;
    this.failDelete = options.failDelete === true;
    this.deleted = false;
  }

  async getMetadata() {
    if (this.failMetadata) {
      throw new Error('metadata unavailable');
    }
    return [{ timeCreated: this.timeCreated }];
  }

  async delete(options = {}) {
    if (this.deleted && options.ignoreNotFound === true) {
      return;
    }
    if (this.failDelete) {
      throw new Error('delete failed');
    }
    this.deleted = true;
    this.bucket.files.delete(this.name);
  }
}

class FakeBucket {
  constructor() {
    this.files = new Map();
  }

  add(name, timeCreated, options) {
    const file = new FakeFile(this, name, timeCreated, options);
    this.files.set(name, file);
    return file;
  }

  file(name) {
    const existing = this.files.get(name);
    if (existing != null) {
      return existing;
    }
    const missing = new FakeFile(this, name, new Date(0).toISOString());
    missing.deleted = true;
    return missing;
  }

  async getFiles({ maxResults, pageToken, prefix }) {
    const files = [...this.files.values()]
      .filter((file) => !file.deleted && file.name.startsWith(prefix))
      .sort((left, right) => left.name.localeCompare(right.name));
    const start = Number(pageToken || 0);
    const page = files.slice(start, start + maxResults);
    const next = start + page.length;
    return [page, next < files.length ? { pageToken: String(next) } : null];
  }
}

function reportData(reportId, expiresAt, overrides = {}) {
  return {
    reportId,
    type: 'plate_hint',
    reporterUserId,
    targetUserId,
    imagePath: '',
    createdAt: Timestamp.fromMillis(expiresAt.toMillis() - 23 * hourMs),
    updatedAt: Timestamp.fromMillis(expiresAt.toMillis() - hourMs),
    expiresAt,
    ...overrides,
  };
}

async function seedReport(reportId, expiresAt, overrides = {}) {
  const report = reportData(reportId, expiresAt, overrides);
  await db.doc(`reports/${reportId}`).set(report);
  if (overrides.skipIncoming !== true) {
    await db
      .doc(`users/${targetUserId}/report_notifications/${reportId}`)
      .set({ reportId, expiresAt });
  }
  if (overrides.skipSent !== true) {
    await db
      .doc(`users/${reporterUserId}/sent_report_notifications/${reportId}`)
      .set({ reportId, expiresAt });
  }
  return report;
}

async function exists(documentPath) {
  return (await db.doc(documentPath).get()).exists;
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: firestorePort,
    },
  });
  adminApp = initializeApp({ projectId }, `report-cleanup-${process.pid}`);
  db = getFirestore(adminApp);
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
  await deleteApp(adminApp);
});

describe('scheduled report cleanup', () => {
  test('keeps active plate hints and expired chat reports untouched', async () => {
    const now = Timestamp.fromMillis(1_900_000_000_000);
    await seedReport(
      'active-hint',
      Timestamp.fromMillis(now.toMillis() + hourMs),
    );
    await seedReport(
      'expired-chat-report',
      Timestamp.fromMillis(now.toMillis() - hourMs),
      { type: 'chat_report' },
    );

    const result = await deleteExpiredPlateHints({
      firestore: db,
      bucket: new FakeBucket(),
      now,
    });

    assert.equal(result.deleted, 0);
    assert.equal(await exists('reports/active-hint'), true);
    assert.equal(await exists('reports/expired-chat-report'), true);
  });

  test('removes an expired hint, both notifications and its image', async () => {
    const now = Timestamp.fromMillis(1_900_000_000_000);
    const reportId = 'expired-complete';
    const imagePath =
      `report_images/${reportId}/${reporterUserId}/evidence.jpg`;
    await seedReport(
      reportId,
      Timestamp.fromMillis(now.toMillis() - 1),
      { imagePath },
    );
    const bucket = new FakeBucket();
    bucket.add(imagePath, new Date(now.toMillis() - 25 * hourMs).toISOString());

    const result = await deleteExpiredPlateHints({
      firestore: db,
      bucket,
      now,
    });

    assert.equal(result.deleted, 1);
    assert.equal(result.imageDeleteFailures, 0);
    assert.equal(await exists(`reports/${reportId}`), false);
    assert.equal(
      await exists(
        `users/${targetUserId}/report_notifications/${reportId}`,
      ),
      false,
    );
    assert.equal(
      await exists(
        `users/${reporterUserId}/sent_report_notifications/${reportId}`,
      ),
      false,
    );
    assert.equal(bucket.files.has(imagePath), false);
  });

  test('tolerates missing image and partial notifications idempotently', async () => {
    const now = Timestamp.fromMillis(1_900_000_000_000);
    const reportId = 'expired-partial';
    await seedReport(
      reportId,
      Timestamp.fromMillis(now.toMillis() - hourMs),
      {
        imagePath:
          `report_images/${reportId}/${reporterUserId}/evidence.jpg`,
        skipIncoming: true,
      },
    );
    const bucket = new FakeBucket();

    const first = await runReportCleanup({ firestore: db, bucket, now });
    const second = await runReportCleanup({ firestore: db, bucket, now });

    assert.equal(first.reports.deleted, 1);
    assert.equal(first.reports.imageDeleteFailures, 0);
    assert.equal(second.reports.deleted, 0);
    assert.equal(await exists(`reports/${reportId}`), false);
  });

  test('respects configured report batch boundaries', async () => {
    const now = Timestamp.fromMillis(1_900_000_000_000);
    for (let index = 0; index < 5; index += 1) {
      await seedReport(
        `expired-batch-${index}`,
        Timestamp.fromMillis(now.toMillis() - (index + 1) * 1000),
      );
    }

    const first = await deleteExpiredPlateHints({
      firestore: db,
      bucket: new FakeBucket(),
      now,
      pageSize: 2,
      maxPages: 2,
    });
    const second = await deleteExpiredPlateHints({
      firestore: db,
      bucket: new FakeBucket(),
      now,
      pageSize: 2,
      maxPages: 2,
    });

    assert.equal(first.deleted, 4);
    assert.equal(second.deleted, 1);
  });

  test('deletes stale rate limits and keeps current limits', async () => {
    const now = Timestamp.fromMillis(1_900_000_000_000);
    await db.doc('report_rate_limits/stale-user').set({
      updatedAt: Timestamp.fromMillis(now.toMillis() - 25 * hourMs),
    });
    await db.doc('report_rate_limits/current-user').set({
      updatedAt: Timestamp.fromMillis(now.toMillis() - hourMs),
    });

    const result = await deleteExpiredReportRateLimits({
      firestore: db,
      now,
    });

    assert.equal(result.deleted, 1);
    assert.equal(await exists('report_rate_limits/stale-user'), false);
    assert.equal(await exists('report_rate_limits/current-user'), true);
  });

  test('deletes only old orphaned report images', async () => {
    const now = Timestamp.fromMillis(1_900_000_000_000);
    const bucket = new FakeBucket();
    const oldOrphan =
      `report_images/orphan-old/${reporterUserId}/evidence.jpg`;
    const recentOrphan =
      `report_images/orphan-new/${reporterUserId}/evidence.jpg`;
    const ownedImage =
      `report_images/owned-report/${reporterUserId}/evidence.jpg`;
    bucket.add(
      oldOrphan,
      new Date(now.toMillis() - 49 * hourMs).toISOString(),
    );
    bucket.add(
      recentOrphan,
      new Date(now.toMillis() - hourMs).toISOString(),
    );
    bucket.add(
      ownedImage,
      new Date(now.toMillis() - 49 * hourMs).toISOString(),
    );
    await db.doc('reports/owned-report').set({ type: 'plate_hint' });

    const result = await deleteOrphanedReportImages({
      firestore: db,
      bucket,
      now,
      pageSize: 2,
      maxPages: 2,
    });

    assert.equal(result.deleted, 1);
    assert.equal(bucket.files.has(oldOrphan), false);
    assert.equal(bucket.files.has(recentOrphan), true);
    assert.equal(bucket.files.has(ownedImage), true);
  });

  test('accepts only canonical report image paths', () => {
    assert.deepEqual(
      reportImageIdentity(
        `report_images/report-123/${reporterUserId}/evidence.jpg`,
      ),
      { reportId: 'report-123', reporterUserId },
    );
    assert.equal(
      reportImageIdentity('report_images/report-123/other/file.jpg'),
      null,
    );
    assert.equal(reportImageIdentity('../report_images/escape.jpg'), null);
  });
});
