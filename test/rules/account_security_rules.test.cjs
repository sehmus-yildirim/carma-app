const fs = require('node:fs');
const path = require('node:path');
const {after, afterEach, before, describe, test} = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc} = require('firebase/firestore');
const {getBytes, ref, uploadBytes} = require('firebase/storage');

const projectId = 'carma-a84e4';
const userId = 'security-owner';
const outsiderId = 'security-outsider';
const firestorePort = Number(process.env.FIRESTORE_EMULATOR_PORT || 8080);
const storagePort = Number(process.env.FIREBASE_STORAGE_EMULATOR_PORT || 9199);

let testEnv;

function rulesFile(fileName) {
  return fs.readFileSync(path.join(process.cwd(), fileName), 'utf8');
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: rulesFile('firestore.rules'),
      host: '127.0.0.1',
      port: firestorePort,
    },
    storage: {
      rules: rulesFile('storage.rules'),
      host: '127.0.0.1',
      port: storagePort,
    },
  });
});

afterEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

after(async () => {
  if (testEnv != null) {
    await testEnv.cleanup();
  }
});

describe('account security rules', () => {
  test('only owner uploads the canonical metadata-free PNG profile photo', async () => {
    const imagePath = `profile_photos/${userId}/profile.png`;
    const pngBytes = Uint8Array.from([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    ]);
    const owner = testEnv.authenticatedContext(userId).storage();
    const outsider = testEnv.authenticatedContext(outsiderId).storage();

    await assertSucceeds(uploadBytes(ref(owner, imagePath), pngBytes, {
      contentType: 'image/png',
    }));
    await assertFails(uploadBytes(ref(
      outsider,
      `profile_photos/${userId}/profile.png`,
    ), pngBytes, {contentType: 'image/png'}));
    await assertFails(uploadBytes(
      ref(owner, `profile_photos/${userId}/wrong.png`),
      pngBytes,
      {contentType: 'image/png'},
    ));
    await assertFails(uploadBytes(ref(owner, imagePath), pngBytes, {
      contentType: 'image/jpeg',
    }));
  });

  test('profile photo reads require owner access or a live profile connection', async () => {
    const imagePath = `profile_photos/${userId}/profile.png`;
    const connectedId = 'security-connected';
    const connectionId = `${connectedId}_${userId}`;
    const pngBytes = Uint8Array.from([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
    ]);
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(ref(context.storage(), imagePath), pngBytes, {
        contentType: 'image/png',
      });
      await setDoc(doc(context.firestore(), 'public_profiles', userId), {
        uid: userId,
        profileAccessEnabled: true,
      });
      await setDoc(doc(
        context.firestore(),
        'profile_connections',
        connectionId,
      ), {
        status: 'active',
        participants: [connectedId, userId],
        chatId: 'profile-photo-chat',
      });
      await setDoc(doc(context.firestore(), 'chats', 'profile-photo-chat'), {
        status: 'active',
        participants: [connectedId, userId],
        deletedBy: {[connectedId]: false, [userId]: false},
      });
    });

    const owner = testEnv.authenticatedContext(userId).storage();
    const connected = testEnv.authenticatedContext(connectedId).storage();
    const outsider = testEnv.authenticatedContext(outsiderId).storage();
    await assertSucceeds(getBytes(ref(owner, imagePath)));
    await assertSucceeds(getBytes(ref(connected, imagePath)));
    await assertFails(getBytes(ref(outsider, imagePath)));

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'public_profiles', userId), {
        profileAccessEnabled: false,
      }, {merge: true});
    });
    await assertFails(getBytes(ref(connected, imagePath)));
  });

  test('only owner reads server-written security activities', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          'users',
          userId,
          'security_activities',
          'activity-1',
        ),
        {
          eventType: 'sessions_revoked',
          occurredAt: new Date(),
          platform: 'android',
          status: 'succeeded',
        },
      );
    });

    const owner = testEnv.authenticatedContext(userId).firestore();
    const outsider = testEnv.authenticatedContext(outsiderId).firestore();
    const activityPath = [
      'users',
      userId,
      'security_activities',
      'activity-1',
    ];

    await assertSucceeds(getDoc(doc(owner, ...activityPath)));
    await assertFails(getDoc(doc(outsider, ...activityPath)));
    await assertFails(setDoc(doc(owner, ...activityPath), {
      eventType: 'forged',
    }));
  });

  test('clients cannot create or read deletion jobs', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const deletion = doc(owner, 'account_deletions', userId);

    await assertFails(setDoc(deletion, {status: 'requested'}));
    await assertFails(getDoc(deletion));
  });

  test('recovery internals are admin readable and server writable only', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'mfa_recovery_requests', userId), {
        requestId: 'recovery-1',
        userId,
        status: 'pending',
        requestedAt: new Date(),
        updatedAt: new Date(),
      });
      await setDoc(doc(
        context.firestore(),
        'mfa_recovery_requests',
        userId,
        'audit',
        'audit-1',
      ), {
        requestId: 'recovery-1',
        eventType: 'mfa_recovery_requested',
        actorUserId: userId,
        result: 'succeeded',
        occurredAt: new Date(),
      });
    });

    const owner = testEnv.authenticatedContext(userId).firestore();
    const outsider = testEnv.authenticatedContext(outsiderId).firestore();
    const admin = testEnv.authenticatedContext('security-admin', {
      admin: true,
    }).firestore();
    const requestPath = ['mfa_recovery_requests', userId];
    const auditPath = [...requestPath, 'audit', 'audit-1'];

    await assertFails(getDoc(doc(owner, ...requestPath)));
    await assertSucceeds(getDoc(doc(admin, ...requestPath)));
    await assertFails(getDoc(doc(outsider, ...requestPath)));
    await assertFails(setDoc(doc(owner, ...requestPath), {status: 'completed'}));
    await assertSucceeds(getDoc(doc(admin, ...auditPath)));
    await assertFails(getDoc(doc(owner, ...auditPath)));
    await assertFails(setDoc(doc(admin, ...auditPath), {result: 'forged'}));
  });

  test('admin claim audit is admin readable and never client writable', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'admin_claim_audit', 'claim-1'), {
        action: 'admin_claim_granted',
        actorUserId: 'security-admin',
        targetUserId: 'second-admin',
        occurredAt: new Date(),
      });
    });

    const owner = testEnv.authenticatedContext(userId).firestore();
    const admin = testEnv.authenticatedContext('security-admin', {
      admin: true,
    }).firestore();
    const audit = doc(admin, 'admin_claim_audit', 'claim-1');

    await assertSucceeds(getDoc(audit));
    await assertFails(getDoc(doc(owner, 'admin_claim_audit', 'claim-1')));
    await assertFails(setDoc(audit, {action: 'forged'}));
  });

  test('requested deletion blocks Firestore and Storage actions', async () => {
    const imagePath = `profile_photos/${userId}/profile.jpg`;
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users', userId), {
        userId,
        state: 'registered',
      });
      await uploadBytes(
        ref(context.storage(), imagePath),
        Uint8Array.from([255, 216, 255, 217]),
        {contentType: 'image/jpeg'},
      );
      await setDoc(doc(context.firestore(), 'account_deletions', userId), {
        userId,
        status: 'requested',
        requestedAt: new Date(),
      });
    });

    const ownerContext = testEnv.authenticatedContext(userId);
    await assertFails(getDoc(doc(ownerContext.firestore(), 'users', userId)));
    await assertFails(
      getBytes(ref(ownerContext.storage(), imagePath)),
    );
    await assertFails(
      uploadBytes(
        ref(ownerContext.storage(), imagePath),
        Uint8Array.from([255, 216, 255, 217]),
        {contentType: 'image/jpeg'},
      ),
    );
  });
});
