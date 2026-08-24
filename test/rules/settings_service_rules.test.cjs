const fs = require('node:fs');
const path = require('node:path');
const {after, afterEach, before, describe, test} = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {doc, getDoc, setDoc} = require('firebase/firestore');

const projectId = 'carma-a84e4';
const userId = 'settings-owner';
const outsiderId = 'settings-outsider';
const firestorePort = Number(process.env.FIRESTORE_EMULATOR_PORT || 8080);

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(path.join(process.cwd(), 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: firestorePort,
    },
  });
});

afterEach(async () => testEnv.clearFirestore());
after(async () => testEnv?.cleanup());

function serverTimestamp() {
  return new Date();
}

describe('settings service request rules', () => {
  test('owner creates and reads a valid support request only', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const outsider = testEnv.authenticatedContext(outsiderId).firestore();
    const pathParts = ['users', userId, 'support_requests', 'support-1'];
    const payload = {
      requestId: 'support-1',
      userId,
      type: 'problem',
      category: 'Darstellung oder Bedienung',
      affectedArea: 'Chat',
      description: 'Der Composer verschiebt sich nach dem Öffnen der Tastatur.',
      reproductionSteps: null,
      allowContact: false,
      accountEmail: null,
      appVersion: 'plaqa 1.0.0',
      status: 'received',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };

    await assertSucceeds(setDoc(doc(owner, ...pathParts), payload));
    await assertSucceeds(getDoc(doc(owner, ...pathParts)));
    await assertFails(getDoc(doc(outsider, ...pathParts)));
    await assertFails(setDoc(doc(outsider, ...pathParts), payload));

    await assertSucceeds(setDoc(
        doc(owner, 'users', userId, 'support_requests', 'support-safety'),
        {
          ...payload,
          requestId: 'support-safety',
          type: 'safety',
          category: 'Schutz von Minderjährigen',
          affectedArea: 'Chat',
          description:
            'Ich möchte ein mögliches Sicherheitsproblem im Chat melden.',
        },
    ));
  });

  test('invalid support requests and later client edits fail', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const reference = doc(
      owner,
      'users',
      userId,
      'support_requests',
      'support-2',
    );
    const base = {
      requestId: 'support-2',
      userId,
      type: 'feedback',
      category: 'Allgemeines Feedback',
      affectedArea: null,
      description: 'Diese Beschreibung ist ausreichend lang und sachlich.',
      reproductionSteps: null,
      allowContact: true,
      accountEmail: 'user@example.com',
      appVersion: 'plaqa 1.0.0',
      status: 'received',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };

    await assertFails(setDoc(reference, {...base, description: 'Zu kurz'}));
    await assertSucceeds(setDoc(reference, base));
    await assertFails(setDoc(reference, {...base, status: 'closed'}));
  });

  test('export request is private, valid and idempotent by immutable document', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const outsider = testEnv.authenticatedContext(outsiderId).firestore();
    const pathParts = ['users', userId, 'data_rights_requests', 'export-1'];
    const payload = {
      requestId: 'export-1',
      userId,
      type: 'export',
      status: 'requested',
      accountEmail: 'user@example.com',
      note: null,
      appVersion: 'plaqa 1.0.0',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };

    await assertSucceeds(setDoc(doc(owner, ...pathParts), payload));
    await assertSucceeds(getDoc(doc(owner, ...pathParts)));
    await assertFails(getDoc(doc(outsider, ...pathParts)));
    await assertFails(
      setDoc(doc(owner, ...pathParts), {...payload, status: 'completed'}),
    );
  });
});

describe('app preference rules', () => {
  function appPreferencesPayload(themeMode) {
    return {
      userId,
      languageCode: 'de',
      themeMode,
      hapticsEnabled: true,
      messageSoundsEnabled: true,
      distanceUnit: 'km',
      defaultPlateCountry: 'DE',
      updatedAt: serverTimestamp(),
    };
  }

  test('owner can save every supported theme mode', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const reference = doc(owner, 'users', userId, 'settings', 'app_preferences');

    for (const themeMode of ['dark', 'light', 'system']) {
      await assertSucceeds(setDoc(reference, appPreferencesPayload(themeMode)));
    }
  });

  test('unknown theme modes and writes for another user fail', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const outsider = testEnv.authenticatedContext(outsiderId).firestore();
    const ownerReference = doc(
        owner,
        'users',
        userId,
        'settings',
        'app_preferences',
    );
    const outsiderReference = doc(
        outsider,
        'users',
        userId,
        'settings',
        'app_preferences',
    );

    await assertFails(
        setDoc(ownerReference, appPreferencesPayload('sepia')),
    );
    await assertFails(
        setDoc(outsiderReference, appPreferencesPayload('light')),
    );
  });
});
