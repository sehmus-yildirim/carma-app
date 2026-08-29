const fs = require('node:fs');
const assert = require('node:assert/strict');
const path = require('node:path');
const {after, afterEach, before, describe, test} = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  Timestamp,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

const projectId = 'carma-a84e4';
const senderUserId = 'request-sender';
const receiverUserId = 'request-receiver';
const vehicleId = 'vehicle-bmw-x6';
const senderVehicleId = 'vehicle-sender';
const countryCode = 'DE';
const plateKey = 'HHCR2026';
const requestId = `${senderUserId}_${countryCode}_${vehicleId}`;
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

function strictRequestData(overrides = {}) {
  const createdAt = Timestamp.fromMillis(Date.now());
  return {
    senderUserId,
    receiverUserId,
    targetUserId: receiverUserId,
    countryCode,
    vehicleId,
    senderVehicleId,
    plateKey,
    senderDisplayName: 'Sina Sender',
    senderPhotoUrl: null,
    receiverDisplayName: 'Rene Receiver',
    receiverPhotoUrl: null,
    displayPlate: 'HH-CR 2026',
    vehicleBrand: 'BMW',
    vehicleModel: 'X6',
    vehicleColor: 'Schwarz',
    vehicleLabel: 'BMW X6',
    requestReason: 'vehicle_question',
    message: 'Hallo, ich habe eine Frage zu deinem BMW X6.',
    status: 'pending',
    chatId: `request_${requestId}`,
    createdAt,
    updatedAt: createdAt,
    expiresAt: Timestamp.fromMillis(createdAt.toMillis() + 48 * 60 * 60 * 1000),
    isDeleted: false,
    ...overrides,
  };
}

async function seedRequest(overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'contact_requests', requestId),
      strictRequestData(overrides),
    );
  });
}

describe('server-owned contact request rules', () => {
  test('lets only the sender check its missing deterministic request', async () => {
    const sender = testEnv.authenticatedContext(senderUserId).firestore();
    const outsider = testEnv.authenticatedContext('request-outsider').firestore();
    const missing = await assertSucceeds(
      getDoc(doc(sender, 'contact_requests', requestId)),
    );
    assert.equal(missing.exists(), false);
    await assertFails(getDoc(doc(outsider, 'contact_requests', requestId)));
  });

  test('rejects all client-side request and chat creation', async () => {
    const sender = testEnv.authenticatedContext(senderUserId).firestore();
    await assertFails(
      setDoc(doc(sender, 'contact_requests', requestId), strictRequestData()),
    );
    await assertFails(setDoc(doc(sender, 'chats', `request_${requestId}`), {
      participants: [senderUserId, receiverUserId],
      requestId,
      status: 'active',
      isDeleted: false,
    }));
  });

  test('keeps server-created requests private to both participants', async () => {
    await seedRequest();
    const sender = testEnv.authenticatedContext(senderUserId).firestore();
    const receiver = testEnv.authenticatedContext(receiverUserId).firestore();
    const outsider = testEnv.authenticatedContext('request-outsider').firestore();
    await assertSucceeds(getDoc(doc(sender, 'contact_requests', requestId)));
    await assertSucceeds(getDoc(doc(receiver, 'contact_requests', requestId)));
    await assertFails(getDoc(doc(outsider, 'contact_requests', requestId)));
  });

  test('allows only receiver accept or decline and sender withdrawal', async () => {
    await seedRequest();
    const receiver = testEnv.authenticatedContext(receiverUserId).firestore();
    await assertSucceeds(updateDoc(
      doc(receiver, 'contact_requests', requestId),
      {status: 'accepted', updatedAt: serverTimestamp()},
    ));

    await testEnv.clearFirestore();
    await seedRequest();
    await assertSucceeds(updateDoc(
      doc(receiver, 'contact_requests', requestId),
      {status: 'declined', updatedAt: serverTimestamp()},
    ));

    await testEnv.clearFirestore();
    await seedRequest();
    const sender = testEnv.authenticatedContext(senderUserId).firestore();
    await assertSucceeds(updateDoc(
      doc(sender, 'contact_requests', requestId),
      {status: 'withdrawn', updatedAt: serverTimestamp()},
    ));
  });

  test('rejects poisoned schemas, forged projections and client resend', async () => {
    await seedRequest();
    const sender = testEnv.authenticatedContext(senderUserId).firestore();
    const receiver = testEnv.authenticatedContext(receiverUserId).firestore();
    await assertFails(updateDoc(
      doc(receiver, 'contact_requests', requestId),
      {
        status: 'accepted',
        receiverDisplayName: 'Gefälscht',
        updatedAt: serverTimestamp(),
      },
    ));
    await assertFails(updateDoc(
      doc(receiver, 'contact_requests', requestId),
      {status: 'accepted', poison: ['x'], updatedAt: serverTimestamp()},
    ));
    await assertFails(setDoc(
      doc(sender, 'contact_requests', requestId),
      strictRequestData({message: 'Erneut senden'}),
    ));
  });

  test('rejects acceptance after the server expiry', async () => {
    const createdAt = Timestamp.fromMillis(Date.now() - 49 * 60 * 60 * 1000);
    await seedRequest({
      createdAt,
      updatedAt: createdAt,
      expiresAt: Timestamp.fromMillis(createdAt.toMillis() + 48 * 60 * 60 * 1000),
    });
    const receiver = testEnv.authenticatedContext(receiverUserId).firestore();
    await assertFails(updateDoc(
      doc(receiver, 'contact_requests', requestId),
      {status: 'accepted', updatedAt: serverTimestamp()},
    ));
  });
});
