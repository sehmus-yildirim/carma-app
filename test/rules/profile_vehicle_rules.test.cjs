const fs = require('node:fs');
const path = require('node:path');
const {after, afterEach, before, describe, test} = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  Timestamp,
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

const projectId = 'carma-a84e4';
const ownerUserId = 'vehicle-owner';
const outsiderUserId = 'vehicle-outsider';
const vehicleId = 'vehicle-1';
const plateId = 'DE_HH_SY_4700';
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

async function seedVehicleData({
  withConnection = false,
  showVehicle = true,
} = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    await setDoc(doc(database, 'users', ownerUserId, 'vehicles', vehicleId), {
      ownerUserId,
      vehicleId,
      brand: 'BMW',
      model: 'X6',
      status: 'active',
      isPrimary: true,
    });
    await setDoc(doc(database, 'users', ownerUserId, 'vehicles', 'vehicle-2'), {
      ownerUserId,
      vehicleId: 'vehicle-2',
      brand: 'Mercedes-Benz',
      model: 'GLS',
      status: 'active',
      isPrimary: false,
    });
    await setDoc(doc(database, 'public_profiles', ownerUserId), {
      uid: ownerUserId,
      profileAccessEnabled: true,
      showVehicleOnPublicProfile: showVehicle,
      displayName: 'Sehmus Y.',
    });
    await setDoc(
      doc(database, 'public_profiles', ownerUserId, 'vehicles', vehicleId),
      {
        ownerUserId,
        vehicleId,
        brand: 'BMW',
        model: 'X6',
        status: 'active',
        isPrimary: true,
      },
    );
    await setDoc(doc(database, 'plates', plateId), {
      ownerUserId,
      vehicleId,
      countryCode: 'DE',
      region: 'HH',
      letters: 'SY',
      numbers: '4700',
      isActive: true,
    });

    if (!withConnection) return;
    const requestId = 'request-1';
    const chatId = 'chat-1';
    const connectionId = `${outsiderUserId}_${ownerUserId}`;
    await setDoc(doc(database, 'contact_requests', requestId), {
      senderUserId: outsiderUserId,
      receiverUserId: ownerUserId,
      status: 'accepted',
    });
    await setDoc(doc(database, 'chats', chatId), {
      requestId,
      participants: [outsiderUserId, ownerUserId],
      status: 'active',
      deletedBy: {},
    });
    await setDoc(doc(database, 'profile_connections', connectionId), {
      connectionId,
      userAId: outsiderUserId,
      userBId: ownerUserId,
      participants: [outsiderUserId, ownerUserId],
      requestId,
      chatId,
      status: 'active',
    });
  });
}

describe('profile vehicle Firestore rules', () => {
  test('only owner and admin can read private vehicles', async () => {
    await seedVehicleData();
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const outsider = testEnv.authenticatedContext(outsiderUserId).firestore();
    const admin = testEnv
      .authenticatedContext('vehicle-admin', {admin: true})
      .firestore();
    const path = ['users', ownerUserId, 'vehicles', vehicleId];

    await assertSucceeds(getDoc(doc(owner, ...path)));
    await assertSucceeds(getDoc(doc(admin, ...path)));
    await assertFails(getDoc(doc(outsider, ...path)));
  });

  test('clients cannot write vehicle roots directly', async () => {
    await seedVehicleData();
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const privateRef = doc(owner, 'users', ownerUserId, 'vehicles', vehicleId);
    const publicRef = doc(
      owner,
      'public_profiles',
      ownerUserId,
      'vehicles',
      vehicleId,
    );

    await assertFails(updateDoc(privateRef, {color: 'Blau'}));
    await assertFails(updateDoc(publicRef, {color: 'Blau'}));
    await assertFails(
      setDoc(doc(owner, 'users', ownerUserId, 'vehicles', 'vehicle-2'), {
        ownerUserId,
      }),
    );
  });

  test('public vehicle needs an active accepted profile connection', async () => {
    await seedVehicleData();
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const outsider = testEnv.authenticatedContext(outsiderUserId).firestore();
    const path = ['public_profiles', ownerUserId, 'vehicles', vehicleId];

    await assertSucceeds(getDoc(doc(owner, ...path)));
    await assertFails(getDoc(doc(outsider, ...path)));

    await testEnv.clearFirestore();
    await seedVehicleData({withConnection: true});
    await assertSucceeds(getDoc(doc(outsider, ...path)));
  });

  test('global vehicle visibility blocks public vehicle reads', async () => {
    await seedVehicleData({withConnection: true, showVehicle: false});
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const outsider = testEnv.authenticatedContext(outsiderUserId).firestore();
    const path = ['public_profiles', ownerUserId, 'vehicles', vehicleId];

    await assertSucceeds(getDoc(doc(owner, ...path)));
    await assertFails(getDoc(doc(outsider, ...path)));
  });

  test('exact plate metadata is owner-only and never listable', async () => {
    await seedVehicleData();
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const outsider = testEnv.authenticatedContext(outsiderUserId).firestore();

    await assertSucceeds(getDoc(doc(owner, 'plates', plateId)));
    await assertFails(getDoc(doc(outsider, 'plates', plateId)));
    await assertFails(getDocs(collection(owner, 'plates')));
    await assertFails(updateDoc(doc(owner, 'plates', plateId), {isActive: false}));
  });

  test('modifications stay assigned to their vehicle', async () => {
    await seedVehicleData();
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const now = Timestamp.now();
    const modification = {
      modificationId: 'modification-1',
      ownerUserId,
      vehicleId,
      title: 'Sportfahrwerk',
      category: 'suspension',
      manufacturer: null,
      product: null,
      description: null,
      modifiedAt: now,
      workshop: null,
      costCents: null,
      powerChangeHp: null,
      isRegistered: false,
      documentPaths: [],
      visibility: 'onlyMe',
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    };

    await assertSucceeds(setDoc(doc(
      owner,
      'users', ownerUserId, 'vehicles', vehicleId,
      'modifications', 'modification-1',
    ), modification));
    await assertFails(setDoc(doc(
      owner,
      'users', ownerUserId, 'vehicles', 'vehicle-2',
      'modifications', 'modification-1',
    ), modification));
  });

  test('public modifications omit private workshop and cost data', async () => {
    await seedVehicleData({withConnection: true});
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const outsider = testEnv.authenticatedContext(outsiderUserId).firestore();
    const now = Timestamp.now();
    const reference = doc(
      owner,
      'public_profiles', ownerUserId, 'vehicles', vehicleId,
      'modifications', 'modification-1',
    );
    const publicData = {
      modificationId: 'modification-1',
      ownerUserId,
      vehicleId,
      title: 'Sportfahrwerk',
      category: 'suspension',
      manufacturer: null,
      product: null,
      description: null,
      modifiedAt: now,
      powerChangeHp: null,
      isRegistered: false,
      visibility: 'contacts',
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    };

    await assertSucceeds(setDoc(reference, publicData));
    await assertSucceeds(getDoc(doc(
      outsider,
      'public_profiles', ownerUserId, 'vehicles', vehicleId,
      'modifications', 'modification-1',
    )));
    await assertFails(setDoc(reference, {
      ...publicData,
      workshop: 'Private Werkstatt',
      costCents: 250000,
    }));
  });

  test('timeline entries stay assigned to their vehicle and reject future dates', async () => {
    await seedVehicleData();
    const owner = testEnv.authenticatedContext(ownerUserId).firestore();
    const now = Timestamp.now();
    const timeline = {
      entryId: 'entry-1',
      ownerUserId,
      vehicleId,
      type: 'maintenance',
      title: 'Ölwechsel',
      description: null,
      eventDate: now,
      mediaUrls: [],
      linkedPostId: null,
      linkedModificationId: null,
      isAutomaticallyCreated: false,
      visibility: 'onlyMe',
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    };

    await assertSucceeds(setDoc(doc(
      owner,
      'users', ownerUserId, 'vehicles', vehicleId,
      'timeline', 'entry-1',
    ), timeline));
    await assertFails(setDoc(doc(
      owner,
      'users', ownerUserId, 'vehicles', 'vehicle-2',
      'timeline', 'entry-1',
    ), timeline));
    await assertFails(setDoc(doc(
      owner,
      'users', ownerUserId, 'vehicles', vehicleId,
      'timeline', 'entry-future',
    ), {
      ...timeline,
      entryId: 'entry-future',
      eventDate: Timestamp.fromMillis(Date.now() + 86400000),
    }));
  });
});
