const fs = require('node:fs');
const path = require('node:path');
const {after, afterEach, before, describe, test} = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {Timestamp, doc, getDoc, setDoc, updateDoc} = require('firebase/firestore');
const {getBytes, ref, uploadBytes} = require('firebase/storage');

const projectId = 'carma-a84e4';
const ownerUserId = 'verification-owner';
const outsiderUserId = 'verification-outsider';
const firestorePort = Number(process.env.FIRESTORE_EMULATOR_PORT || 8080);
const storagePort = Number(process.env.FIREBASE_STORAGE_EMULATOR_PORT || 9199);

let testEnv;

function rulesFile(fileName) {
  return fs.readFileSync(path.join(process.cwd(), fileName), 'utf8');
}

function draftData(overrides = {}) {
  const now = Timestamp.now();
  return {
    requestId: ownerUserId,
    userId: ownerUserId,
    profilePath: `users/${ownerUserId}/profiles/main`,
    status: 'draft',
    displayName: '',
    identityDocumentType: 'identityCard',
    documentStoragePaths: {
      identityFront:
        `profile_documents/${ownerUserId}/identityFront/identityFront.png`,
    },
    documentStatuses: {identityFront: 'uploaded'},
    documentRejectionReasons: {},
    documentExpiresAt: {
      identity: Timestamp.fromDate(new Date('2030-08-14T00:00:00Z')),
    },
    vehicleId: 'vehicle-1',
    vehicleRelationship: 'owner',
    vehicleAssignmentConfirmed: false,
    authorizationConfirmed: false,
    consentVersion: null,
    consentAcceptedAt: null,
    submittedAt: null,
    reviewedAt: null,
    reviewedBy: null,
    rejectionReason: null,
    retentionUntil: null,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

async function seedRequest(data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'verification_requests', ownerUserId),
      data,
    );
  });
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

after(async () => testEnv?.cleanup());

describe('profile verification Firestore rules', () => {
  test('owner can read an own request path before a draft exists', async () => {
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const outsider = testEnv.authenticatedContext(outsiderUserId).firestore();

    await assertSucceeds(getDoc(
      doc(owner, 'verification_requests', ownerUserId),
    ));
    await assertFails(getDoc(
      doc(outsider, 'verification_requests', ownerUserId),
    ));
  });

  test('owner can create only a private draft with canonical paths', async () => {
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const request = doc(owner, 'verification_requests', ownerUserId);

    await assertSucceeds(setDoc(request, draftData()));
    await assertFails(setDoc(request, draftData({status: 'pending'})));
    await assertFails(setDoc(request, draftData({
      documentStoragePaths: {
        identityFront: 'profile_documents/other/private.jpg',
      },
    })));
    await assertFails(setDoc(request, {
      ...draftData(),
      documentRemoteUrls: {identityFront: 'https://example.test/private'},
    }));
    await assertFails(setDoc(request, draftData({
      documentExpiresAt: {
        identity: Timestamp.fromDate(new Date('2020-01-01T00:00:00Z')),
      },
    })));
  });

  test('outsiders cannot create or read another verification request', async () => {
    await seedRequest(draftData());
    const outsider = testEnv.authenticatedContext(outsiderUserId).firestore();

    await assertFails(getDoc(
      doc(outsider, 'verification_requests', ownerUserId),
    ));
    await assertFails(setDoc(
      doc(outsider, 'verification_requests', ownerUserId),
      draftData(),
    ));
  });

  test('owner can replace rejected draft but cannot mutate pending review', async () => {
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const request = doc(owner, 'verification_requests', ownerUserId);
    const rejected = draftData({status: 'rejected'});
    await seedRequest(rejected);

    await assertSucceeds(setDoc(request, draftData({
      createdAt: rejected.createdAt,
      documentStoragePaths: {},
      documentStatuses: {identityFront: 'missing'},
    })));

    await seedRequest(draftData({status: 'pending'}));
    await assertFails(updateDoc(request, {
      status: 'draft',
      updatedAt: Timestamp.now(),
    }));
  });

  test('owner can resubmit a rejected group but cannot alter verified evidence', async () => {
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const request = doc(owner, 'verification_requests', ownerUserId);
    const canonical = (key) =>
      `profile_documents/${ownerUserId}/${key}/${key}.png`;
    const reviewed = draftData({
      status: 'rejected',
      documentStoragePaths: {
        identityFront: canonical('identityFront'),
        identityBack: canonical('identityBack'),
        driverLicenseFront: canonical('driverLicenseFront'),
        driverLicenseBack: canonical('driverLicenseBack'),
        vehicleFront: canonical('vehicleFront'),
        vehicleBack: canonical('vehicleBack'),
      },
      documentStatuses: {
        identityFront: 'verified',
        identityBack: 'verified',
        driverLicenseFront: 'verified',
        driverLicenseBack: 'verified',
        vehicleFront: 'rejected',
        vehicleBack: 'rejected',
      },
      documentRejectionReasons: {
        vehicleFront: 'Fahrzeugschein ist nicht lesbar.',
        vehicleBack: 'Fahrzeugschein ist nicht lesbar.',
      },
    });
    await seedRequest(reviewed);

    await assertSucceeds(setDoc(request, draftData({
      createdAt: reviewed.createdAt,
      documentStoragePaths: reviewed.documentStoragePaths,
      documentStatuses: {
        ...reviewed.documentStatuses,
        vehicleFront: 'uploaded',
        vehicleBack: 'uploaded',
      },
      documentRejectionReasons: reviewed.documentRejectionReasons,
      vehicleAssignmentConfirmed: true,
    })));

    await seedRequest(reviewed);
    await assertFails(setDoc(request, draftData({
      createdAt: reviewed.createdAt,
      documentStoragePaths: reviewed.documentStoragePaths,
      documentStatuses: {
        ...reviewed.documentStatuses,
        identityFront: 'uploaded',
      },
      documentRejectionReasons: reviewed.documentRejectionReasons,
    })));
  });

  test('client cannot create a draft with forged review statuses', async () => {
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    await assertFails(setDoc(
      doc(owner, 'verification_requests', ownerUserId),
      draftData({documentStatuses: {identityFront: 'verified'}}),
    ));
  });

  test('new drafts cannot add legacy driving-licence fields', async () => {
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    await assertFails(setDoc(
      doc(owner, 'verification_requests', ownerUserId),
      draftData({
        documentStoragePaths: {
          driverLicenseFront:
            `profile_documents/${ownerUserId}/driverLicenseFront/driverLicenseFront.png`,
        },
        documentStatuses: {driverLicenseFront: 'uploaded'},
      }),
    ));
  });

  test('verification support references are scoped and contain no document data', async () => {
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const valid = {
      requestId: 'support-1',
      userId: ownerUserId,
      type: 'verification',
      category: 'Dokumentenprüfung',
      affectedArea: 'Verifizierung',
      description: 'Mein Identitätsnachweis wurde abgelehnt und ich benötige Hilfe.',
      reproductionSteps: null,
      technicalReferenceId: ownerUserId,
      technicalReferenceGroup: 'identity',
      allowContact: false,
      accountEmail: null,
      appVersion: '1.0.0',
      status: 'received',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    };
    await assertSucceeds(setDoc(
      doc(owner, 'users', ownerUserId, 'support_requests', 'support-1'),
      valid,
    ));
    await assertFails(setDoc(
      doc(owner, 'users', ownerUserId, 'support_requests', 'support-2'),
      {
        ...valid,
        requestId: 'support-2',
        technicalReferenceId: outsiderUserId,
      },
    ));
    await assertFails(setDoc(
      doc(owner, 'users', ownerUserId, 'support_requests', 'support-3'),
      {...valid, requestId: 'support-3', documentUrl: 'private'},
    ));
  });

  test('owner cannot grant a verification badge to the private profile', async () => {
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const profile = doc(owner, 'users', ownerUserId, 'profiles', 'main');
    await assertSucceeds(setDoc(profile, {
      uid: ownerUserId,
      firstName: 'Mara',
      lastName: 'Beispiel',
      displayName: 'Mara Beispiel',
      birthDate: Timestamp.fromDate(new Date('1990-01-01T00:00:00Z')),
      personalDataLocked: true,
      verificationStatus: 'unverified',
      verificationSubmittedAt: null,
      verificationReviewedAt: null,
      verificationRejectionReason: null,
      updatedAt: Timestamp.now(),
    }));

    await assertFails(updateDoc(profile, {
      verificationStatus: 'verified',
      verificationReviewedAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    }));
    await assertFails(updateDoc(profile, {
      verificationStatus: 'pending',
      verificationSubmittedAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    }));
  });

  test('history is readable by owner and admin but not writable by clients', async () => {
    await seedRequest(draftData({status: 'pending'}));
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          'verification_requests',
          ownerUserId,
          'history',
          'submitted',
        ),
        {status: 'pending', reason: null, createdAt: Timestamp.now()},
      );
    });

    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const admin = testEnv.authenticatedContext(
      'verification-admin',
      {admin: true},
    ).firestore();
    const outsider = testEnv.authenticatedContext(outsiderUserId).firestore();
    const ownerHistory = doc(
      owner,
      'verification_requests',
      ownerUserId,
      'history',
      'submitted',
    );

    await assertSucceeds(getDoc(ownerHistory));
    await assertSucceeds(getDoc(doc(
      admin,
      'verification_requests',
      ownerUserId,
      'history',
      'submitted',
    )));
    await assertFails(getDoc(doc(
      outsider,
      'verification_requests',
      ownerUserId,
      'history',
      'submitted',
    )));
    await assertFails(updateDoc(ownerHistory, {status: 'verified'}));
  });

  test('verification notifications are private and owner can only mark read', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          'users',
          ownerUserId,
          'verification_notifications',
          'notice-1',
        ),
        {
          notificationId: 'notice-1',
          requestId: ownerUserId,
          status: 'rejected',
          message: 'Für deine Verifizierung ist eine Nachreichung erforderlich.',
          isRead: false,
          createdAt: Timestamp.now(),
        },
      );
    });

    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const outsider = testEnv.authenticatedContext(outsiderUserId).firestore();
    const ownerNotice = doc(
      owner,
      'users',
      ownerUserId,
      'verification_notifications',
      'notice-1',
    );

    await assertSucceeds(getDoc(ownerNotice));
    await assertSucceeds(updateDoc(ownerNotice, {isRead: true}));
    await assertFails(updateDoc(ownerNotice, {message: 'Manipuliert'}));
    await assertFails(getDoc(doc(
      outsider,
      'users',
      ownerUserId,
      'verification_notifications',
      'notice-1',
    )));
  });
});

describe('profile verification Storage rules', () => {
  const validPath =
    `profile_documents/${ownerUserId}/identityFront/identityFront.png`;
  const pngBytes = Uint8Array.from([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
  ]);
  const jpegBytes = Uint8Array.from([0xff, 0xd8, 0xff, 0xd9]);

  test('owner can upload canonical PNG and JPEG evidence pages', async () => {
    const storage = testEnv.authenticatedContext(ownerUserId).storage();
    await assertSucceeds(uploadBytes(ref(storage, validPath), pngBytes, {
      contentType: 'image/png',
    }));
    const jpegPath =
      `profile_documents/${ownerUserId}/vehicleBack/vehicleBack.jpg`;
    await assertSucceeds(uploadBytes(ref(storage, jpegPath), jpegBytes, {
      contentType: 'image/jpeg',
    }));
  });

  test('rejects old types, wrong names, wrong mime and foreign uploads', async () => {
    const owner = testEnv.authenticatedContext(ownerUserId).storage();
    const outsider = testEnv.authenticatedContext(outsiderUserId).storage();

    await assertFails(uploadBytes(
      ref(owner, `profile_documents/${ownerUserId}/driverLicenseFront/driverLicenseFront.png`),
      pngBytes,
      {contentType: 'image/png'},
    ));
    await assertFails(uploadBytes(
      ref(owner, `profile_documents/${ownerUserId}/identityEvidence/identityEvidence.jpg`),
      jpegBytes,
      {contentType: 'image/jpeg'},
    ));
    await assertFails(uploadBytes(
      ref(owner, `profile_documents/${ownerUserId}/identityFront/other.jpg`),
      jpegBytes,
      {contentType: 'image/jpeg'},
    ));
    await assertFails(uploadBytes(ref(owner, validPath), jpegBytes, {
      contentType: 'image/jpeg',
    }));
    await assertFails(uploadBytes(ref(
      outsider,
      `profile_documents/${ownerUserId}/identityFront/identityFront.png`,
    ), pngBytes, {contentType: 'image/png'}));
  });

  test('only owner and admin can read verification evidence', async () => {
    const ownerStorage = testEnv.authenticatedContext(ownerUserId).storage();
    await uploadBytes(ref(ownerStorage, validPath), pngBytes, {
      contentType: 'image/png',
    });

    const outsider = testEnv.authenticatedContext(outsiderUserId).storage();
    const admin = testEnv.authenticatedContext(
      'verification-admin',
      {admin: true},
    ).storage();
    await assertFails(getBytes(ref(outsider, validPath)));
    await assertSucceeds(getBytes(ref(admin, validPath)));
  });

  test('owner cannot replace or delete evidence during review', async () => {
    const ownerStorage = testEnv.authenticatedContext(ownerUserId).storage();
    await uploadBytes(ref(ownerStorage, validPath), pngBytes, {
      contentType: 'image/png',
    });
    await seedRequest(draftData({status: 'pending'}));

    await assertFails(uploadBytes(ref(ownerStorage, validPath), pngBytes, {
      contentType: 'image/png',
    }));
    const {deleteObject} = require('firebase/storage');
    await assertFails(deleteObject(ref(ownerStorage, validPath)));
  });

  test('targeted resubmission cannot replace verified storage objects', async () => {
    const ownerStorage = testEnv.authenticatedContext(ownerUserId).storage();
    const vehiclePath =
      `profile_documents/${ownerUserId}/vehicleFront/vehicleFront.png`;
    await seedRequest(draftData({
      status: 'rejected',
      documentStatuses: {
        identityFront: 'verified',
        vehicleFront: 'rejected',
      },
    }));

    await assertFails(uploadBytes(ref(ownerStorage, validPath), pngBytes, {
      contentType: 'image/png',
    }));
    await assertSucceeds(uploadBytes(ref(ownerStorage, vehiclePath), pngBytes, {
      contentType: 'image/png',
    }));
  });
});
