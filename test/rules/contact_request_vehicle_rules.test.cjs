const fs = require('node:fs');
const path = require('node:path');
const {after, afterEach, before, describe, test} = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {Timestamp, doc, setDoc} = require('firebase/firestore');

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

async function seedPlate(overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'plates', `${countryCode}_${plateKey}`), {
      ownerUserId: receiverUserId,
      vehicleId,
      countryCode,
      plateKey,
      displayPlate: 'HH-CR 2026',
      vehicleBrand: 'BMW',
      vehicleModel: 'X6',
      vehicleColor: 'Schwarz',
      vehicleLabel: 'BMW X6',
      allowContactRequests: true,
      isVerified: true,
      isActive: true,
      isDeleted: false,
      ...overrides,
    });
    await setDoc(doc(
      context.firestore(),
      'public_profiles',
      senderUserId,
      'vehicles',
      senderVehicleId,
    ), {
      ownerUserId: senderUserId,
      vehicleId: senderVehicleId,
      isVerified: true,
      verificationStatus: 'verified',
    });
  });
}

async function seedContactFilter(level) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(
      context.firestore(),
      'users',
      receiverUserId,
      'settings',
      'contact_filters',
    ), {
      userId: receiverUserId,
      requireVerifiedRequester: level === 'identityVerified',
      requesterVerificationLevel: level,
      allowedContactReasons: ['vehicle_question'],
      autoRejectUnverified: level === 'identityVerified',
      contactRequestQuietModeUntil: null,
      updatedAt: Timestamp.now(),
    });
  });
}

async function seedSenderIdentity({verified}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'public_profiles', senderUserId), {
      userId: senderUserId,
      isVerified: verified,
      verificationStatus: verified ? 'verified' : 'unverified',
    });
  });
}

function requestData(overrides = {}) {
  const now = Date.now();
  return {
    senderUserId,
    receiverUserId,
    targetUserId: receiverUserId,
    countryCode,
    vehicleId,
    senderVehicleId,
    plateKey,
    displayPlate: 'HH-CR 2026',
    vehicleBrand: 'BMW',
    vehicleModel: 'X6',
    vehicleColor: 'Schwarz',
    vehicleLabel: 'BMW X6',
    requestReason: 'vehicle_question',
    message: 'Hallo, ich habe eine Frage zu deinem BMW X6.',
    status: 'pending',
    chatId: `request_${requestId}`,
    createdAt: Timestamp.fromMillis(now),
    updatedAt: Timestamp.fromMillis(now),
    expiresAt: Timestamp.fromMillis(now + 48 * 60 * 60 * 1000),
    isDeleted: false,
    ...overrides,
  };
}

function chatData(overrides = {}) {
  const now = Timestamp.fromMillis(Date.now());
  return {
    participants: [senderUserId, receiverUserId],
    status: 'active',
    requestId,
    countryCode,
    vehicleId,
    displayPlate: 'HH-CR 2026',
    vehicleBrand: 'BMW',
    vehicleModel: 'X6',
    vehicleColor: 'Schwarz',
    vehicleLabel: 'BMW X6',
    createdAt: now,
    updatedAt: now,
    lastMessage: 'Hallo, ich habe eine Frage zu deinem BMW X6.',
    lastMessageAt: now,
    isDeleted: false,
    senderUserId,
    receiverUserId,
    ...overrides,
  };
}

async function createValidRequest() {
  const sender = testEnv.authenticatedContext(senderUserId).firestore();
  await assertSucceeds(
    setDoc(doc(sender, 'contact_requests', requestId), requestData()),
  );
  return sender;
}

describe('contact request stable vehicle identity rules', () => {
  test('allows a request and chat bound to the active plate vehicle', async () => {
    await seedPlate();
    const sender = await createValidRequest();

    await assertSucceeds(
      setDoc(doc(sender, 'chats', `request_${requestId}`), chatData()),
    );
  });

  test('rejects forged vehicle identity, receiver and vehicle projection', async () => {
    await seedPlate();
    const sender = testEnv.authenticatedContext(senderUserId).firestore();

    await assertFails(
      setDoc(
        doc(sender, 'contact_requests', `${senderUserId}_${countryCode}_forged`),
        requestData({vehicleId: 'forged'}),
      ),
    );
    await assertFails(
      setDoc(
        doc(sender, 'contact_requests', requestId),
        requestData({receiverUserId: 'other-user', targetUserId: 'other-user'}),
      ),
    );
    await assertFails(
      setDoc(
        doc(sender, 'contact_requests', requestId),
        requestData({vehicleModel: 'Gefälschtes Modell'}),
      ),
    );
  });

  test('rejects requests for inactive or non-contactable plate projections', async () => {
    await seedPlate({isActive: false});
    const sender = testEnv.authenticatedContext(senderUserId).firestore();
    await assertFails(
      setDoc(doc(sender, 'contact_requests', requestId), requestData()),
    );

    await testEnv.clearFirestore();
    await seedPlate({allowContactRequests: false});
    await assertFails(
      setDoc(doc(sender, 'contact_requests', requestId), requestData()),
    );
  });

  test('requires a confirmed sender vehicle', async () => {
    await seedPlate();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(
        context.firestore(),
        'public_profiles',
        senderUserId,
        'vehicles',
        senderVehicleId,
      ), {isVerified: false}, {merge: true});
    });
    const sender = testEnv.authenticatedContext(senderUserId).firestore();
    await assertFails(
      setDoc(doc(sender, 'contact_requests', requestId), requestData()),
    );
  });

  test('allows a vehicle-confirmed sender when that filter is selected', async () => {
    await seedPlate();
    await seedContactFilter('vehicleVerified');

    await createValidRequest();
  });

  test('identity filter requires identity in addition to the confirmed vehicle', async () => {
    await seedPlate();
    await seedContactFilter('identityVerified');
    await seedSenderIdentity({verified: false});
    const sender = testEnv.authenticatedContext(senderUserId).firestore();

    await assertFails(
      setDoc(doc(sender, 'contact_requests', requestId), requestData()),
    );

    await seedSenderIdentity({verified: true});
    await assertSucceeds(
      setDoc(doc(sender, 'contact_requests', requestId), requestData()),
    );
  });

  test('rejects a chat that changes the request vehicle reference', async () => {
    await seedPlate();
    const sender = await createValidRequest();

    await assertFails(
      setDoc(
        doc(sender, 'chats', `request_${requestId}`),
        chatData({vehicleId: 'other-vehicle'}),
      ),
    );
  });

  test('does not let a non-sender create the request', async () => {
    await seedPlate();
    const outsider = testEnv.authenticatedContext('request-outsider').firestore();
    await assertFails(
      setDoc(doc(outsider, 'contact_requests', requestId), requestData()),
    );
  });
});
