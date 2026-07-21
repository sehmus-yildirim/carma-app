const fs = require('node:fs');
const path = require('node:path');
const { after, afterEach, before, describe, test } = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  Timestamp,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  writeBatch,
} = require('firebase/firestore');
const { getBytes, ref, uploadBytes } = require('firebase/storage');

const projectId = 'carma-a84e4';
const senderUserId = 'report-sender';
const targetUserId = 'report-target';
const outsiderUserId = 'report-outsider';
const plateId = 'DE_HHSY4700';
const plateKey = 'HHSY4700';
const firestorePort = Number(process.env.FIRESTORE_EMULATOR_PORT || 8080);
const storagePort = Number(process.env.FIREBASE_STORAGE_EMULATOR_PORT || 9199);

let testEnv;

function rulesFile(fileName) {
  return fs.readFileSync(path.join(process.cwd(), fileName), 'utf8');
}

function reportData(reportId, overrides = {}) {
  const createdAt = Timestamp.fromMillis(Date.now());
  return {
    reportId,
    type: 'plate_hint',
    reporterUserId: senderUserId,
    targetUserId,
    countryCode: 'DE',
    plateKey,
    plateRegion: 'HH',
    plateLetters: 'SY',
    plateNumbers: '4700',
    category: 'vehicleOpen',
    message: 'Das Fenster ist noch geöffnet.',
    locationMode: 'manual',
    manualAddress: 'Bremer Straße 254e, Hamburg',
    locationLabel: 'Bremer Straße 254e, Hamburg',
    status: 'submitted',
    hasImage: false,
    anonymousToTarget: true,
    createdAt,
    updatedAt: createdAt,
    expiresAt: Timestamp.fromMillis(
      createdAt.toMillis() + 23 * 60 * 60 * 1000,
    ),
    isDeleted: false,
    ...overrides,
  };
}

function incomingNotification(report) {
  const { reporterUserId: _, ...withoutReporter } = report;
  return { ...withoutReporter, status: 'unread' };
}

function sentNotification(report) {
  const {
    reporterUserId: _,
    targetUserId: __,
    ...withoutUsers
  } = report;
  return withoutUsers;
}

async function seedPlate(overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'plates', plateId), {
      ownerUserId: targetUserId,
      countryCode: 'DE',
      plateKey,
      isActive: true,
      isDeleted: false,
      allowAnonymousReports: true,
      ...overrides,
    });
  });
}

async function attemptClientReportBatch(reportId, overrides = {}) {
  const db = testEnv.authenticatedContext(senderUserId).firestore();
  const report = reportData(reportId, overrides);
  const batch = writeBatch(db);
  batch.set(doc(db, 'reports', reportId), report);
  batch.set(
    doc(db, 'users', targetUserId, 'report_notifications', reportId),
    incomingNotification(report),
  );
  batch.set(
    doc(db, 'users', senderUserId, 'sent_report_notifications', reportId),
    sentNotification(report),
  );
  await batch.commit();
  return report;
}

async function seedValidReportDocuments(reportId, overrides = {}) {
  const report = reportData(reportId, overrides);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, 'reports', reportId), report);
    batch.set(
      doc(db, 'users', targetUserId, 'report_notifications', reportId),
      incomingNotification(report),
    );
    batch.set(
      doc(db, 'users', senderUserId, 'sent_report_notifications', reportId),
      sentNotification(report),
    );
    await batch.commit();
  });
  return report;
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: firestorePort,
      rules: rulesFile('firestore.rules'),
    },
    storage: {
      host: '127.0.0.1',
      port: storagePort,
      rules: rulesFile('storage.rules'),
    },
  });
});

afterEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

after(async () => {
  await testEnv.cleanup();
});

describe('Firestore report rules', () => {
  test('reject a direct client report and notification batch', async () => {
    await seedPlate();
    await assertFails(attemptClientReportBatch('report-valid'));
  });

  test('reject an unauthenticated report', async () => {
    await seedPlate();
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(
        doc(db, 'reports', 'report-unauthenticated'),
        reportData('report-unauthenticated'),
      ),
    );
  });

  test('reject a mismatching reporter user id', async () => {
    await seedPlate();
    const db = testEnv.authenticatedContext(senderUserId).firestore();
    await assertFails(
      setDoc(
        doc(db, 'reports', 'report-wrong-reporter'),
        reportData('report-wrong-reporter', { reporterUserId: outsiderUserId }),
      ),
    );
  });

  test('reject reporting an own plate', async () => {
    await seedPlate({ ownerUserId: senderUserId });
    const db = testEnv.authenticatedContext(senderUserId).firestore();
    await assertFails(
      setDoc(
        doc(db, 'reports', 'report-own-plate'),
        reportData('report-own-plate', { targetUserId: senderUserId }),
      ),
    );
  });

  for (const [name, plateOverride] of [
    ['inactive', { isActive: false }],
    ['deleted', { isDeleted: true }],
    ['disabled-anonymous-reports', { allowAnonymousReports: false }],
  ]) {
    test(`reject a report for a plate that is ${name}`, async () => {
      await seedPlate(plateOverride);
      const db = testEnv.authenticatedContext(senderUserId).firestore();
      const reportId = `report-${name}`;
      await assertFails(
        setDoc(doc(db, 'reports', reportId), reportData(reportId)),
      );
    });
  }

  test('reject invalid category and mismatching plate segments', async () => {
    await seedPlate();
    const db = testEnv.authenticatedContext(senderUserId).firestore();
    await assertFails(
      setDoc(
        doc(db, 'reports', 'report-invalid-category'),
        reportData('report-invalid-category', { category: 'unknown' }),
      ),
    );
    await assertFails(
      setDoc(
        doc(db, 'reports', 'report-invalid-plate'),
        reportData('report-invalid-plate', { plateRegion: 'B' }),
      ),
    );
  });

  test('reject invalid timestamps and an expiry beyond 24 hours', async () => {
    await seedPlate();
    const db = testEnv.authenticatedContext(senderUserId).firestore();
    await assertFails(
      setDoc(
        doc(db, 'reports', 'report-invalid-timestamp'),
        reportData('report-invalid-timestamp', { createdAt: 'now' }),
      ),
    );

    const createdAt = Timestamp.fromMillis(Date.now());
    await assertFails(
      setDoc(
        doc(db, 'reports', 'report-invalid-expiry'),
        reportData('report-invalid-expiry', {
          createdAt,
          updatedAt: createdAt,
          expiresAt: Timestamp.fromMillis(
            createdAt.toMillis() + 25 * 60 * 60 * 1000,
          ),
        }),
      ),
    );
  });

  test('allow only owner reads for incoming and sent notifications', async () => {
    await seedPlate();
    const reportId = 'report-read-access';
    await seedValidReportDocuments(reportId);

    const targetDb = testEnv.authenticatedContext(targetUserId).firestore();
    const senderDb = testEnv.authenticatedContext(senderUserId).firestore();
    const outsiderDb = testEnv.authenticatedContext(outsiderUserId).firestore();
    const incomingPath = [
      'users',
      targetUserId,
      'report_notifications',
      reportId,
    ];
    const sentPath = [
      'users',
      senderUserId,
      'sent_report_notifications',
      reportId,
    ];

    await assertSucceeds(getDoc(doc(targetDb, ...incomingPath)));
    await assertSucceeds(getDoc(doc(senderDb, ...sentPath)));
    await assertFails(getDoc(doc(outsiderDb, ...incomingPath)));
    await assertFails(getDoc(doc(outsiderDb, ...sentPath)));
    await assertFails(getDoc(doc(senderDb, ...incomingPath)));
  });

  test('allow only the target to mark an incoming notification read', async () => {
    await seedPlate();
    const reportId = 'report-read-update';
    await seedValidReportDocuments(reportId);
    const targetDb = testEnv.authenticatedContext(targetUserId).firestore();
    const senderDb = testEnv.authenticatedContext(senderUserId).firestore();
    const now = Timestamp.now();

    await assertSucceeds(
      updateDoc(
        doc(
          targetDb,
          'users',
          targetUserId,
          'report_notifications',
          reportId,
        ),
        { status: 'read', readAt: now, updatedAt: now },
      ),
    );
    await assertFails(
      updateDoc(
        doc(
          senderDb,
          'users',
          targetUserId,
          'report_notifications',
          reportId,
        ),
        { status: 'read', readAt: now, updatedAt: now },
      ),
    );
  });
});

describe('Storage report image rules', () => {
  const reportId = 'report-image';
  const filePath = `report_images/${reportId}/${senderUserId}/evidence.jpg`;

  async function seedImageNotifications() {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(
        doc(db, 'users', targetUserId, 'report_notifications', reportId),
        { imagePath: filePath },
      );
      await setDoc(
        doc(
          db,
          'users',
          senderUserId,
          'sent_report_notifications',
          reportId,
        ),
        { imagePath: filePath },
      );
    });
  }

  test('allow the sender to upload and both parties to read evidence', async () => {
    await seedImageNotifications();
    const senderStorage = testEnv.authenticatedContext(senderUserId).storage();
    await assertSucceeds(
      uploadBytes(ref(senderStorage, filePath), new Uint8Array([1, 2, 3]), {
        contentType: 'image/jpeg',
      }),
    );

    const targetStorage = testEnv.authenticatedContext(targetUserId).storage();
    const outsiderStorage = testEnv
      .authenticatedContext(outsiderUserId)
      .storage();
    await assertSucceeds(getBytes(ref(senderStorage, filePath)));
    await assertSucceeds(getBytes(ref(targetStorage, filePath)));
    await assertFails(getBytes(ref(outsiderStorage, filePath)));
  });

  test('reject uploads to another user path or with invalid metadata', async () => {
    const senderStorage = testEnv.authenticatedContext(senderUserId).storage();
    await assertFails(
      uploadBytes(
        ref(
          senderStorage,
          `report_images/${reportId}/${targetUserId}/evidence.jpg`,
        ),
        new Uint8Array([1]),
        { contentType: 'image/jpeg' },
      ),
    );
    await assertFails(
      uploadBytes(
        ref(
          senderStorage,
          `report_images/${reportId}/${senderUserId}/photo.jpg`,
        ),
        new Uint8Array([1]),
        { contentType: 'image/jpeg' },
      ),
    );
    await assertFails(
      uploadBytes(ref(senderStorage, filePath), new Uint8Array([1]), {
        contentType: 'image/png',
      }),
    );
  });

  test('reject an evidence image at the 10 MB limit', async () => {
    const senderStorage = testEnv.authenticatedContext(senderUserId).storage();
    await assertFails(
      uploadBytes(
        ref(senderStorage, filePath),
        new Uint8Array(10 * 1024 * 1024),
        { contentType: 'image/jpeg' },
      ),
    );
  });
});
