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
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} = require('firebase/firestore');
const {getBytes, ref, uploadBytes} = require('firebase/storage');

const projectId = 'carma-a84e4';
const ownerUserId = 'post-owner';
const contactUserId = 'post-contact';
const outsiderUserId = 'post-outsider';
const postId = 'post-1';
const fileName = 'media_0.jpg';
const mediaPath = `profile_posts/${ownerUserId}/${postId}/${fileName}`;
const firestorePort = Number(process.env.FIRESTORE_EMULATOR_PORT || 8080);
const storagePort = Number(process.env.FIREBASE_STORAGE_EMULATOR_PORT || 9199);

let testEnv;

function rulesFile(fileNameToRead) {
  return fs.readFileSync(path.join(process.cwd(), fileNameToRead), 'utf8');
}

function postData(overrides = {}) {
  const now = Timestamp.now();
  return {
    postId,
    ownerUserId,
    imageUrl: 'https://plaqa.de/post.jpg',
    imagePath: mediaPath,
    mediaUrls: ['https://plaqa.de/post.jpg'],
    mediaPaths: [mediaPath],
    mediaTypes: ['image'],
    caption: 'Testbeitrag',
    vehicleLabel: 'BMW X6 M50d',
    vehicleId: 'vehicle-1',
    locationLabel: 'Hamburg',
    section: 'posts',
    visibility: 'public',
    createdAt: now,
    updatedAt: now,
    isDeleted: false,
    isArchived: false,
    pinnedAt: null,
    ...overrides,
  };
}

async function seedProfileConnection() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    const requestId = 'request-1';
    const chatId = 'chat-1';
    const connectionId = `${contactUserId}_${ownerUserId}`;
    await setDoc(doc(database, 'public_profiles', ownerUserId), {
      uid: ownerUserId,
      displayName: 'Sehmus Y.',
      photoUrl: 'https://plaqa.de/profile.jpg',
      profileAccessEnabled: true,
    });
    await setDoc(doc(database, 'contact_requests', requestId), {
      senderUserId: contactUserId,
      receiverUserId: ownerUserId,
      status: 'accepted',
    });
    await setDoc(doc(database, 'chats', chatId), {
      requestId,
      participants: [contactUserId, ownerUserId],
      status: 'active',
      deletedBy: {},
    });
    await setDoc(doc(database, 'profile_connections', connectionId), {
      connectionId,
      userAId: contactUserId,
      userBId: ownerUserId,
      participants: [contactUserId, ownerUserId],
      requestId,
      chatId,
      status: 'active',
    });
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

describe('social post Firestore and Storage rules', () => {
  test('only the owner can create a post and upload its media', async () => {
    const owner = testEnv.authenticatedContext(ownerUserId);
    const outsider = testEnv.authenticatedContext(outsiderUserId);

    await assertSucceeds(setDoc(
      doc(owner.firestore(), 'users', ownerUserId, 'social_posts', postId),
      postData(),
    ));
    await assertFails(setDoc(
      doc(outsider.firestore(), 'users', ownerUserId, 'social_posts', 'fake'),
      postData({postId: 'fake'}),
    ));

    const bytes = Uint8Array.from([0xff, 0xd8, 0xff, 0xd9]);
    await assertSucceeds(uploadBytes(
      ref(owner.storage(), mediaPath),
      bytes,
      {contentType: 'image/jpeg'},
    ));
    await assertFails(uploadBytes(
      ref(outsider.storage(), mediaPath),
      bytes,
      {contentType: 'image/jpeg'},
    ));
  });

  test('only an active contact can read a visible post and its media', async () => {
    await seedProfileConnection();
    const owner = testEnv.authenticatedContext(ownerUserId);
    const contact = testEnv.authenticatedContext(contactUserId);
    const outsider = testEnv.authenticatedContext(outsiderUserId);
    const postReference = doc(
      owner.firestore(),
      'users', ownerUserId, 'social_posts', postId,
    );
    await setDoc(postReference, postData());
    await uploadBytes(
      ref(owner.storage(), mediaPath),
      Uint8Array.from([0xff, 0xd8, 0xff, 0xd9]),
      {contentType: 'image/jpeg'},
    );

    await assertSucceeds(getDoc(doc(
      contact.firestore(),
      'users', ownerUserId, 'social_posts', postId,
    )));
    await assertFails(getDoc(doc(
      outsider.firestore(),
      'users', ownerUserId, 'social_posts', postId,
    )));
    await assertSucceeds(getBytes(ref(contact.storage(), mediaPath)));
    await assertFails(getBytes(ref(outsider.storage(), mediaPath)));
  });

  test('a contact can manage only its own like and comment', async () => {
    await seedProfileConnection();
    const owner = testEnv.authenticatedContext(ownerUserId);
    const contact = testEnv.authenticatedContext(contactUserId);
    const outsider = testEnv.authenticatedContext(outsiderUserId);
    await setDoc(doc(
      owner.firestore(),
      'users', ownerUserId, 'social_posts', postId,
    ), postData());

    const likePath = [
      'users', ownerUserId, 'social_posts', postId, 'likes', contactUserId,
    ];
    await assertSucceeds(setDoc(doc(contact.firestore(), ...likePath), {
      userId: contactUserId,
      postOwnerUserId: ownerUserId,
      displayName: 'Kontakt N.',
      photoUrl: '',
      createdAt: Timestamp.now(),
    }));
    await assertFails(setDoc(doc(outsider.firestore(), ...likePath), {
      userId: contactUserId,
      postOwnerUserId: ownerUserId,
      displayName: 'Falscher Nutzer',
      photoUrl: '',
      createdAt: Timestamp.now(),
    }));
    await assertSucceeds(deleteDoc(doc(contact.firestore(), ...likePath)));

    const commentId = 'comment-1';
    const commentPath = [
      'users', ownerUserId, 'social_posts', postId, 'comments', commentId,
    ];
    await assertSucceeds(setDoc(doc(contact.firestore(), ...commentPath), {
      commentId,
      postId,
      postOwnerUserId: ownerUserId,
      authorUserId: contactUserId,
      authorDisplayName: 'Kontakt N.',
      authorPhotoUrl: '',
      text: 'Schönes Fahrzeug.',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      isDeleted: false,
    }));
    await assertFails(updateDoc(doc(outsider.firestore(), ...commentPath), {
      isDeleted: true,
      updatedAt: Timestamp.now(),
    }));
    await assertSucceeds(updateDoc(doc(owner.firestore(), ...commentPath), {
      isDeleted: true,
      updatedAt: Timestamp.now(),
    }));
  });
});
