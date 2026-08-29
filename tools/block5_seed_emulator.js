const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore, Timestamp} = require('firebase-admin/firestore');

const projectId = 'carma-a84e4';
const password = 'Plaqa-Test-2026!';
const latitude = 53.432363;
const longitude = 9.971651;

const users = {
  a: {
    email: 'block5.redmi.a@plaqa.test',
    displayName: 'Block5 Nutzer A',
    vehicleId: 'block5-vehicle-a',
    plateKey: 'HHAA2026',
    plateLetters: 'AA',
    displayPlate: 'HH-AA 2026',
    vehicleBrand: 'Volkswagen',
    vehicleModel: 'Golf',
    vehicleColor: 'Blau',
  },
  b: {
    email: 'block5.redmi.b@plaqa.test',
    displayName: 'Block5 Nutzer B',
    vehicleId: 'block5-vehicle-b',
    plateKey: 'HHCR2026',
    plateLetters: 'CR',
    displayPlate: 'HH-CR 2026',
    vehicleBrand: 'BMW',
    vehicleModel: 'X6',
    vehicleColor: 'Schwarz',
  },
};

function assertLocalEmulator(name, expectedPort) {
  const value = process.env[name] || '';
  const allowed = new Set([
    `127.0.0.1:${expectedPort}`,
    `localhost:${expectedPort}`,
  ]);
  if (!allowed.has(value)) {
    throw new Error(
      `${name} must explicitly target a local emulator on port ${expectedPort}.`,
    );
  }
}

async function ensureAuthUser(auth, definition) {
  let record;
  try {
    record = await auth.getUserByEmail(definition.email);
    record = await auth.updateUser(record.uid, {
      password,
      displayName: definition.displayName,
      emailVerified: true,
      disabled: false,
    });
  } catch (error) {
    if (error.code !== 'auth/user-not-found') {
      throw error;
    }
    record = await auth.createUser({
      email: definition.email,
      password,
      displayName: definition.displayName,
      emailVerified: true,
    });
  }
  return {...definition, uid: record.uid};
}

function vehicleData(user, now) {
  return {
    ownerUserId: user.uid,
    userId: user.uid,
    vehicleId: user.vehicleId,
    isPrimary: true,
    countryCode: 'DE',
    plateKey: user.plateKey,
    normalizedPlate: user.plateKey,
    plateRegion: 'HH',
    plateLetters: user.plateLetters,
    plateNumbers: '2026',
    displayPlate: user.displayPlate,
    plateDisplayLabel: user.displayPlate,
    brand: user.vehicleBrand,
    model: user.vehicleModel,
    color: user.vehicleColor,
    vehicleBrand: user.vehicleBrand,
    vehicleModel: user.vehicleModel,
    vehicleColor: user.vehicleColor,
    vehicleLabel: `${user.vehicleBrand} ${user.vehicleModel}`,
    useRelationship: 'owner',
    vehicleType: 'passengerCar',
    plateType: 'standard',
    showOnPublicProfile: true,
    discoverable: true,
    selectable: true,
    allowContactRequests: true,
    plateDisplayMode: 'full',
    isVerified: true,
    verificationStatus: 'verified',
    isActive: true,
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  };
}

async function seedUser(db, user, now) {
  const batch = db.batch();
  const privateVehicle = vehicleData(user, now);
  const publicVehicle = {...privateVehicle};

  batch.set(db.doc(`users/${user.uid}`), {
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    accountStatus: 'active',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  }, {merge: true});
  batch.set(db.doc(`users/${user.uid}/profiles/main`), {
    uid: user.uid,
    email: user.email,
    firstName: 'Block5',
    lastName: user.email === users.a.email ? 'Nutzer A' : 'Nutzer B',
    displayName: user.displayName,
    country: 'Deutschland',
    countryCode: 'DE',
    plateRegion: 'HH',
    plateLetters: user.plateLetters,
    plateNumbers: '2026',
    vehicleBrand: user.vehicleBrand,
    vehicleModel: user.vehicleModel,
    vehicleColor: user.vehicleColor,
    allowContactRequests: true,
    allowAnonymousReports: true,
    phoneNumber: null,
    birthDate: Timestamp.fromDate(new Date('1990-01-01T12:00:00.000Z')),
    photoUrl: null,
    profilePhotoLocalPath: null,
    publicBio: null,
    publicRegion: 'Hamburg',
    showVehicleOnPublicProfile: true,
    showPlateOnPublicProfile: true,
    isPrivateProfile: false,
    profileAccessEnabled: true,
    followersVisibility: 'contacts',
    followingVisibility: 'contacts',
    primaryVehicleId: user.vehicleId,
    documentLocalPaths: {},
    documentRemoteUrls: {},
    personalDataLocked: true,
    verificationStatus: 'verified',
    verificationSubmittedAt: now,
    verificationReviewedAt: now,
    verificationRejectionReason: null,
    updatedAt: now,
  });
  batch.set(db.doc(`public_profiles/${user.uid}`), {
    uid: user.uid,
    displayName: user.displayName,
    photoUrl: null,
    publicBio: null,
    publicRegion: 'Hamburg',
    showVehicleOnPublicProfile: true,
    showPlateOnPublicProfile: true,
    isPrivateProfile: false,
    profileAccessEnabled: true,
    followersVisibility: 'contacts',
    followingVisibility: 'contacts',
    verificationStatus: 'verified',
    primaryVehicleId: user.vehicleId,
    vehicleBrand: user.vehicleBrand,
    vehicleModel: user.vehicleModel,
    vehicleColor: user.vehicleColor,
    countryCode: 'DE',
    plateRegion: 'HH',
    plateLetters: user.plateLetters,
    plateNumbers: '2026',
    updatedAt: now,
  });
  batch.set(db.doc(`users/${user.uid}/vehicles/${user.vehicleId}`), privateVehicle);
  batch.set(
    db.doc(`public_profiles/${user.uid}/vehicles/${user.vehicleId}`),
    publicVehicle,
  );
  batch.set(db.doc(`users/${user.uid}/settings/visibility`), {
    userId: user.uid,
    allowContactRequests: true,
    plateSearchVisibility: 'everyone',
    showVehicle: true,
    showPlate: true,
    updatedAt: now,
  }, {merge: true});
  batch.set(db.doc(`users/${user.uid}/settings/contact_filters`), {
    userId: user.uid,
    requireVerifiedRequester: false,
    requesterVerificationLevel: 'all',
    allowedContactReasons: [
      'vehicle_question',
      'compliment',
      'meet_and_drive',
      'get_to_know',
    ],
    autoRejectUnverified: false,
    contactRequestQuietModeUntil: null,
    updatedAt: now,
  }, {merge: true});
  await batch.commit();
}

async function deleteRequestState(db, sender, receiver) {
  const requestId = `${sender.uid}_DE_${receiver.vehicleId}`;
  const chatReference = db.doc(`chats/request_${requestId}`);
  if (typeof db.recursiveDelete === 'function') {
    await db.recursiveDelete(chatReference);
  } else {
    const messages = await chatReference.collection('messages').get();
    await Promise.all(messages.docs.map((document) => document.ref.delete()));
    await chatReference.delete();
  }
  await db.doc(`contact_requests/${requestId}`).delete();
}

async function main() {
  assertLocalEmulator('FIRESTORE_EMULATOR_HOST', 8080);
  assertLocalEmulator('FIREBASE_AUTH_EMULATOR_HOST', 9099);

  const app = initializeApp({projectId});
  try {
    const auth = getAuth(app);
    const db = getFirestore(app);
    const now = Timestamp.now();
    const userA = await ensureAuthUser(auth, users.a);
    const userB = await ensureAuthUser(auth, users.b);

    await Promise.all([
      seedUser(db, userA, now),
      seedUser(db, userB, now),
    ]);
    await deleteRequestState(db, userA, userB);

    await db.doc(`plates/DE_${userA.plateKey}`).set({
      ...vehicleData(userA, now),
      displayName: userA.displayName,
      profilePhotoUrl: null,
      latitude,
      longitude,
      locationUpdatedAt: Timestamp.now(),
    });
    await db.doc(`plates/DE_${userB.plateKey}`).set({
      ...vehicleData(userB, now),
      displayName: userB.displayName,
      profilePhotoUrl: null,
      latitude,
      longitude,
      locationUpdatedAt: Timestamp.now(),
    });

    console.log(JSON.stringify({
      projectId,
      password,
      userA: {uid: userA.uid, email: userA.email, plate: userA.displayPlate},
      userB: {uid: userB.uid, email: userB.email, plate: userB.displayPlate},
      location: {latitude, longitude},
    }, null, 2));
  } finally {
    await deleteApp(app);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
