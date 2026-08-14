const fs = require('node:fs');
const path = require('node:path');
const {after, afterEach, before, describe, test} = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {doc, setDoc, updateDoc, writeBatch} = require('firebase/firestore');

const projectId = 'carma-a84e4';
const userId = 'personal-data-owner';
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

function privateProfile({locked = false} = {}) {
  return {
    uid: userId,
    firstName: 'Sehmus',
    lastName: 'Yildirim',
    displayName: 'Sehmus Yildirim',
    birthDate: new Date('1990-01-01T00:00:00Z'),
    personalDataLocked: locked,
    photoUrl: null,
    verificationStatus: 'unverified',
    verificationSubmittedAt: null,
    verificationReviewedAt: null,
    verificationRejectionReason: null,
    updatedAt: new Date(),
  };
}

function utcBirthday({yearsAgo, dayOffset = 0}) {
  const now = new Date();
  const value = new Date(Date.UTC(
    now.getUTCFullYear() - yearsAgo,
    now.getUTCMonth(),
    now.getUTCDate(),
    12,
  ));
  value.setUTCDate(value.getUTCDate() + dayOffset);
  return value;
}

describe('personal profile data lock', () => {
  test('account provisioning metadata remains updateable', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const reference = doc(owner, 'users', userId);

    await assertSucceeds(setDoc(reference, {
      ...privateProfile({locked: true}),
      email: 'old@plaqa.de',
    }));
    await assertSucceeds(updateDoc(reference, {
      email: 'new@plaqa.de',
      updatedAt: new Date(),
    }));
  });

  test('owner can save and lock personal data once', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const reference = doc(owner, 'users', userId, 'profiles', 'main');

    await assertSucceeds(setDoc(reference, privateProfile()));
    await assertSucceeds(updateDoc(reference, {
      firstName: 'Sehmus',
      lastName: 'Yildirim',
      displayName: 'Sehmus Yildirim',
      birthDate: new Date('1990-01-01T00:00:00Z'),
      personalDataLocked: true,
      updatedAt: new Date(),
    }));
  });

  test('profile exactly at the sixteenth birthday can be locked', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const reference = doc(owner, 'users', userId, 'profiles', 'main');

    await assertSucceeds(setDoc(reference, {
      ...privateProfile({locked: true}),
      birthDate: utcBirthday({yearsAgo: 16}),
    }));
  });

  test('underage or incomplete locked personal data is rejected', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const underageReference = doc(
      owner,
      'users',
      userId,
      'profiles',
      'main',
    );

    await assertFails(setDoc(underageReference, {
      ...privateProfile({locked: true}),
      birthDate: utcBirthday({yearsAgo: 16, dayOffset: 1}),
    }));
    await assertFails(setDoc(underageReference, {
      ...privateProfile({locked: true}),
      firstName: '',
    }));
  });

  test('empty unlocked provisioning profile remains allowed', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const reference = doc(owner, 'users', userId, 'profiles', 'main');

    await assertSucceeds(setDoc(reference, {
      ...privateProfile(),
      firstName: '',
      lastName: '',
      displayName: '',
      birthDate: null,
    }));
  });

  test('locked identity fields and lock flag cannot be changed', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const reference = doc(owner, 'users', userId, 'profiles', 'main');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'users', userId, 'profiles', 'main'),
        privateProfile({locked: true}),
      );
    });

    await assertFails(updateDoc(reference, {firstName: 'Anders'}));
    await assertFails(updateDoc(reference, {lastName: 'Anders'}));
    await assertFails(updateDoc(reference, {
      birthDate: new Date('1991-01-01T00:00:00Z'),
    }));
    await assertFails(updateDoc(reference, {personalDataLocked: false}));
  });

  test('locked profile still allows profile photo updates', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const reference = doc(owner, 'users', userId, 'profiles', 'main');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'users', userId, 'profiles', 'main'),
        privateProfile({locked: true}),
      );
    });

    await assertSucceeds(updateDoc(reference, {
      photoUrl: 'https://plaqa.de/profile.jpg',
      updatedAt: new Date(),
    }));
  });

  test('complete legacy profile is treated as locked', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const reference = doc(owner, 'users', userId, 'profiles', 'main');
    const legacyProfile = privateProfile();
    delete legacyProfile.personalDataLocked;
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'users', userId, 'profiles', 'main'),
        legacyProfile,
      );
    });

    await assertFails(updateDoc(reference, {firstName: 'Anders'}));
    await assertSucceeds(updateDoc(reference, {
      personalDataLocked: true,
      photoUrl: 'https://plaqa.de/legacy-profile.jpg',
      updatedAt: new Date(),
    }));
  });

  test('legacy profile can initialize verification metadata exactly once', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const reference = doc(owner, 'users', userId, 'profiles', 'main');
    const legacyProfile = privateProfile({locked: true});
    delete legacyProfile.verificationStatus;
    delete legacyProfile.verificationSubmittedAt;
    delete legacyProfile.verificationReviewedAt;
    delete legacyProfile.verificationRejectionReason;

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'users', userId, 'profiles', 'main'),
        legacyProfile,
      );
    });

    await assertSucceeds(updateDoc(reference, {
      verificationStatus: 'unverified',
      verificationSubmittedAt: null,
      verificationReviewedAt: null,
      verificationRejectionReason: null,
      updatedAt: new Date(),
    }));
    await assertFails(updateDoc(reference, {
      verificationStatus: 'verified',
      updatedAt: new Date(),
    }));
  });

  test('auth provisioning can migrate legacy private and public profiles atomically', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const privateReference = doc(
      owner,
      'users',
      userId,
      'profiles',
      'main',
    );
    const publicReference = doc(owner, 'public_profiles', userId);
    const legacyProfile = privateProfile({locked: true});
    delete legacyProfile.verificationStatus;
    delete legacyProfile.verificationSubmittedAt;
    delete legacyProfile.verificationReviewedAt;
    delete legacyProfile.verificationRejectionReason;

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'users', userId, 'profiles', 'main'),
        legacyProfile,
      );
    });

    const batch = writeBatch(owner);
    batch.set(privateReference, {
      uid: userId,
      email: 'owner@plaqa.de',
      displayName: 'Sehmus Yildirim',
      photoUrl: null,
      verificationStatus: 'unverified',
      verificationSubmittedAt: null,
      verificationReviewedAt: null,
      verificationRejectionReason: null,
      updatedAt: new Date(),
    }, {merge: true});
    batch.set(publicReference, {
      uid: userId,
      displayName: 'Sehmus Yildirim',
      photoUrl: null,
      publicBio: null,
      publicRegion: null,
      showVehicleOnPublicProfile: false,
      showPlateOnPublicProfile: false,
      isPrivateProfile: true,
      profileAccessEnabled: true,
      followersVisibility: 'contacts',
      followingVisibility: 'contacts',
      verificationStatus: 'unverified',
      primaryVehicleId: null,
      vehicleBrand: null,
      vehicleModel: null,
      vehicleColor: null,
      countryCode: null,
      plateRegion: null,
      plateLetters: null,
      plateNumbers: null,
      updatedAt: new Date(),
    });

    await assertSucceeds(batch.commit());
  });

  test('existing verification status cannot be reset by the owner', async () => {
    const owner = testEnv.authenticatedContext(userId).firestore();
    const reference = doc(owner, 'users', userId, 'profiles', 'main');
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'users', userId, 'profiles', 'main'),
        {
          ...privateProfile({locked: true}),
          verificationStatus: 'verified',
          verificationReviewedAt: new Date(),
        },
      );
    });

    await assertFails(updateDoc(reference, {
      verificationStatus: 'unverified',
      verificationReviewedAt: null,
      updatedAt: new Date(),
    }));
  });
});
