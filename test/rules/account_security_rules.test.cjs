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
