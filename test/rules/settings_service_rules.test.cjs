const fs = require('node:fs');
const path = require('node:path');
const {after, afterEach, before, describe, test} = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  serverTimestamp: firestoreServerTimestamp,
} = require('firebase/firestore');

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

function daysFromNow(days) {
  return new Date(Date.now() + days * 24 * 60 * 60 * 1000);
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
      retentionUntil: daysFromNow(365),
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
          retentionUntil: daysFromNow(730),
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
      retentionUntil: daysFromNow(365),
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
      retentionUntil: daysFromNow(1095),
    };

    await assertSucceeds(setDoc(doc(owner, ...pathParts), payload));
    await assertSucceeds(getDoc(doc(owner, ...pathParts)));
    await assertFails(getDoc(doc(outsider, ...pathParts)));
    await assertFails(
      setDoc(doc(owner, ...pathParts), {...payload, status: 'completed'}),
    );
  });
});

describe('legal consent rules', () => {
  test('only the current explicit immutable consent can be recorded', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const outsider = testEnv.authenticatedContext(outsiderId).firestore();
    const consentId = `${userId}_terms_1.1.0`;
    const payload = {
      id: consentId,
      userId,
      type: 'terms',
      typeLabel: 'AGB',
      version: '1.1.0',
      acceptedAt: new Date().toISOString(),
      ipAddress: null,
      userAgent: null,
      createdAt: firestoreServerTimestamp(),
      source: 'renewal',
    };
    const reference = doc(owner, 'users', userId, 'legal_consents', consentId);

    await assertSucceeds(setDoc(reference, payload));
    const staleId = `${userId}_terms_0.9.0`;
    await assertFails(setDoc(
      doc(owner, 'users', userId, 'legal_consents', staleId),
      {...payload, id: staleId, version: '0.9.0'},
    ));
    const automaticId = `${userId}_privacy_1.1.0`;
    await assertFails(setDoc(
      doc(owner, 'users', userId, 'legal_consents', automaticId),
      {
        ...payload,
        id: automaticId,
        type: 'privacy',
        typeLabel: 'Datenschutz',
        source: 'automatic',
      },
    ));
    await assertFails(setDoc(
      doc(outsider, 'users', userId, 'legal_consents', consentId),
      payload,
    ));
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

describe('website contact system metadata rules', () => {
  test('deny reads and writes for anonymous and authenticated clients', async () => {
    const anonymous = testEnv.unauthenticatedContext().firestore();
    const owner = testEnv.authenticatedContext(userId).firestore();
    const paths = [
      ['_system_website_contact_rate_limits', 'rate-test'],
      ['_system_website_contact_duplicates', 'duplicate-test'],
      ['_system_website_contact_submissions', 'submission-test'],
    ];

    for (const pathParts of paths) {
      const payload = {
        requestId: 'request-test',
        channel: 'support',
        count: 1,
        expiresAt: serverTimestamp(),
      };
      await assertFails(getDoc(doc(anonymous, ...pathParts)));
      await assertFails(setDoc(doc(anonymous, ...pathParts), payload));
      await assertFails(getDoc(doc(owner, ...pathParts)));
      await assertFails(setDoc(doc(owner, ...pathParts), payload));
    }
  });
});
