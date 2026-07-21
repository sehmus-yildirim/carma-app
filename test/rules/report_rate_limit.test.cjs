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
  isOwnedReportImagePath,
  submitPlateHintTransaction,
} = require('../../functions/report_submission');

const projectId = 'carma-a84e4';
const senderUserId = 'rate-limit-sender';
const otherSenderUserId = 'rate-limit-other';
const targetUserId = 'rate-limit-target';
const firestorePort = Number(process.env.FIRESTORE_EMULATOR_PORT || 8080);

let adminApp;
let db;
let testEnv;

function submission(reportId, overrides = {}) {
  return {
    reportId,
    countryCode: 'DE',
    plateRegion: 'HH',
    plateLetters: 'SY',
    plateNumbers: '4700',
    category: 'vehicleOpen',
    message: 'Das Fenster ist noch geöffnet.',
    locationMode: 'manual',
    manualAddress: 'Bremer Straße 254e, Hamburg',
    locationLabel: 'Bremer Straße 254e, Hamburg',
    ...overrides,
  };
}

async function seedPlate(overrides = {}) {
  await db.doc('plates/DE_HHSY4700').set({
    ownerUserId: targetUserId,
    countryCode: 'DE',
    plateKey: 'HHSY4700',
    isActive: true,
    isDeleted: false,
    allowAnonymousReports: true,
    ...overrides,
  });
}

async function submit({
  reportId,
  userId = senderUserId,
  now,
  overrides,
}) {
  return submitPlateHintTransaction({
    firestore: db,
    reporterUserId: userId,
    input: submission(reportId, overrides),
    now,
  });
}

async function assertRejected(action, expectedMessage) {
  await assert.rejects(action, (error) => {
    assert.equal(error.message, expectedMessage);
    return true;
  });
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: firestorePort,
    },
  });
  adminApp = initializeApp({ projectId }, `report-limits-${process.pid}`);
  db = getFirestore(adminApp);
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
  await deleteApp(adminApp);
});

describe('server-side report limits', () => {
  test('rejects a request without an authenticated reporter', async () => {
    await assertRejected(
      () =>
        submitPlateHintTransaction({
          firestore: db,
          reporterUserId: '',
          input: submission('rate-unauthenticated'),
          now: Timestamp.fromMillis(1_800_000_000_000),
        }),
      'Bitte melde dich neu an.',
    );
  });

  test('accepts the first report and writes all documents atomically', async () => {
    await seedPlate();
    const now = Timestamp.fromMillis(1_800_000_000_000);

    const result = await submit({ reportId: 'rate-first', now });

    assert.equal(result.accepted, true);
    assert.equal(result.duplicate, false);
    assert.equal((await db.doc('reports/rate-first').get()).exists, true);
    assert.equal(
      (
        await db
          .doc(`users/${targetUserId}/report_notifications/rate-first`)
          .get()
      ).exists,
      true,
    );
    assert.equal(
      (
        await db
          .doc(
            `users/${senderUserId}/sent_report_notifications/rate-first`,
          )
          .get()
      ).exists,
      true,
    );
    const rateLimit = (
      await db.doc(`report_rate_limits/${senderUserId}`).get()
    ).data();
    assert.equal(rateLimit.windowCount, 1);
    assert.equal(rateLimit.lastSubmittedAt.toMillis(), now.toMillis());
  });

  test('rejects a second report within 60 seconds', async () => {
    await seedPlate();
    const start = Timestamp.fromMillis(1_800_000_000_000);
    await submit({ reportId: 'rate-cooldown-one', now: start });

    await assertRejected(
      () =>
        submit({
          reportId: 'rate-cooldown-two',
          now: Timestamp.fromMillis(start.toMillis() + 30_000),
          overrides: { category: 'visibleDamage' },
        }),
      'Bitte warte kurz, bevor du einen weiteren Hinweis sendest.',
    );
    assert.equal(
      (await db.doc('reports/rate-cooldown-two').get()).exists,
      false,
    );
  });

  test('rejects the eleventh report in a 24-hour window', async () => {
    await seedPlate();
    const now = Timestamp.fromMillis(1_800_000_000_000);
    await db.doc(`report_rate_limits/${senderUserId}`).set({
      userId: senderUserId,
      lastSubmittedAt: Timestamp.fromMillis(now.toMillis() - 61_000),
      windowStartedAt: Timestamp.fromMillis(now.toMillis() - 3_600_000),
      windowCount: 10,
      recentDuplicateUntilByKey: {},
      updatedAt: now,
    });

    await assertRejected(
      () => submit({ reportId: 'rate-daily-limit', now }),
      'Du hast das tägliche Limit für Hinweise erreicht.',
    );
  });

  test('counts only reports inside the rolling 24-hour window', async () => {
    await seedPlate();
    const now = Timestamp.fromMillis(1_800_000_000_000);
    await db.doc(`report_rate_limits/${senderUserId}`).set({
      userId: senderUserId,
      lastSubmittedAt: Timestamp.fromMillis(now.toMillis() - 61_000),
      windowStartedAt: Timestamp.fromMillis(now.toMillis() - 86_000_000),
      windowCount: 10,
      recentSubmissionTimestamps: [
        Timestamp.fromMillis(now.toMillis() - 86_500_000),
        Timestamp.fromMillis(now.toMillis() - 3_600_000),
      ],
      recentDuplicateUntilByKey: {},
      updatedAt: now,
    });

    const result = await submit({ reportId: 'rate-rolling-window', now });

    assert.equal(result.accepted, true);
    const rateLimit = (
      await db.doc(`report_rate_limits/${senderUserId}`).get()
    ).data();
    assert.equal(rateLimit.windowCount, 2);
    assert.equal(rateLimit.recentSubmissionTimestamps.length, 2);
  });

  test('rejects the same plate and category within 15 minutes', async () => {
    await seedPlate();
    const start = Timestamp.fromMillis(1_800_000_000_000);
    await submit({ reportId: 'rate-duplicate-one', now: start });

    await assertRejected(
      () =>
        submit({
          reportId: 'rate-duplicate-two',
          now: Timestamp.fromMillis(start.toMillis() + 61_000),
        }),
      'Dieser Hinweis wurde vor Kurzem bereits gesendet.',
    );
  });

  test('keeps limits isolated per reporter', async () => {
    await seedPlate();
    const start = Timestamp.fromMillis(1_800_000_000_000);
    await submit({ reportId: 'rate-user-one', now: start });

    const result = await submit({
      reportId: 'rate-user-two',
      userId: otherSenderUserId,
      now: Timestamp.fromMillis(start.toMillis() + 1_000),
    });

    assert.equal(result.accepted, true);
    assert.equal(
      (await db.doc(`report_rate_limits/${otherSenderUserId}`).get()).data()
        .windowCount,
      1,
    );
  });

  test('ignores manipulated client timestamps', async () => {
    await seedPlate();
    const serverNow = Timestamp.fromMillis(1_800_000_000_000);
    await submit({
      reportId: 'rate-server-time',
      now: serverNow,
      overrides: {
        createdAt: Timestamp.fromMillis(0),
        updatedAt: Timestamp.fromMillis(9_000_000_000_000),
      },
    });

    const report = (await db.doc('reports/rate-server-time').get()).data();
    assert.equal(report.createdAt.toMillis(), serverNow.toMillis());
    assert.equal(report.updatedAt.toMillis(), serverNow.toMillis());
  });

  test('ignores a manipulated reporter id in client data', async () => {
    await seedPlate();
    const now = Timestamp.fromMillis(1_800_000_000_000);

    await submit({
      reportId: 'rate-server-reporter',
      now,
      overrides: { reporterUserId: otherSenderUserId },
    });

    const report = (await db.doc('reports/rate-server-reporter').get()).data();
    assert.equal(report.reporterUserId, senderUserId);
  });

  test('treats a repeated report id as idempotent', async () => {
    await seedPlate();
    const start = Timestamp.fromMillis(1_800_000_000_000);
    await submit({ reportId: 'rate-idempotent', now: start });

    const repeated = await submit({
      reportId: 'rate-idempotent',
      now: Timestamp.fromMillis(start.toMillis() + 1_000),
    });

    assert.equal(repeated.accepted, true);
    assert.equal(repeated.duplicate, true);
    const rateLimit = (
      await db.doc(`report_rate_limits/${senderUserId}`).get()
    ).data();
    assert.equal(rateLimit.windowCount, 1);
  });

  test('leaves no partial documents after a rejected transaction', async () => {
    await seedPlate({ allowAnonymousReports: false });

    await assertRejected(
      () =>
        submit({
          reportId: 'rate-atomic-reject',
          now: Timestamp.fromMillis(1_800_000_000_000),
        }),
      'Dieser Nutzer nimmt aktuell keine anonymen Hinweise an.',
    );

    assert.equal(
      (await db.doc('reports/rate-atomic-reject').get()).exists,
      false,
    );
    assert.equal(
      (
        await db
          .doc(
            `users/${targetUserId}/report_notifications/rate-atomic-reject`,
          )
          .get()
      ).exists,
      false,
    );
    assert.equal(
      (
        await db
          .doc(
            `users/${senderUserId}/sent_report_notifications/rate-atomic-reject`,
          )
          .get()
      ).exists,
      false,
    );
    assert.equal(
      (await db.doc(`report_rate_limits/${senderUserId}`).get()).exists,
      false,
    );
  });
});

describe('rejected report image cleanup guard', () => {
  test('accepts only the exact report image path owned by the caller', () => {
    assert.equal(
      isOwnedReportImagePath(senderUserId, {
        reportId: 'rate-image-owned',
        imagePath:
          `report_images/rate-image-owned/${senderUserId}/evidence.jpg`,
      }),
      true,
    );
    assert.equal(
      isOwnedReportImagePath(senderUserId, {
        reportId: 'rate-image-owned',
        imagePath:
          `report_images/rate-image-owned/${otherSenderUserId}/evidence.jpg`,
      }),
      false,
    );
  });
});
