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
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
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
let reservationSequence = 0;

function storageUrl(storagePath) {
  return 'https://firebasestorage.googleapis.com/v0/b/' +
    'carma-a84e4.firebasestorage.app/o/' +
    `${encodeURIComponent(storagePath)}?alt=media&token=test-token`;
}

function rulesFile(fileNameToRead) {
  return fs.readFileSync(path.join(process.cwd(), fileNameToRead), 'utf8');
}

async function reservedUploadMetadata({userId, filePath, contentType, size}) {
  reservationSequence += 1;
  const reservationId =
    `10000000-0000-4000-8000-${String(reservationSequence).padStart(12, '0')}`;
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), '_media_upload_reservations', reservationId),
      {
        userId,
        storagePath: filePath,
        contentType,
        maxBytes: size,
        status: 'reserved',
        expiresAt: Timestamp.fromMillis(Date.now() + 10 * 60 * 1000),
      },
    );
  });
  return {
    contentType,
    customMetadata: {uploadReservationId: reservationId},
  };
}

function postData(overrides = {}) {
  const now = Timestamp.now();
  const mediaUrl = storageUrl(mediaPath);
  return {
    postId,
    ownerUserId,
    imageUrl: mediaUrl,
    imagePath: mediaPath,
    mediaUrls: [mediaUrl],
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
    // Production IDs are sorted, so the valid connection may be the second
    // direction checked by the rules (owner first, viewer second).
    const connectionId = `${ownerUserId}_${contactUserId}`;
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
    const externalPostId = 'external-media';
    const externalPath =
      `profile_posts/${ownerUserId}/${externalPostId}/${fileName}`;
    await assertFails(setDoc(
      doc(
        owner.firestore(),
        'users', ownerUserId, 'social_posts', externalPostId,
      ),
      postData({
        postId: externalPostId,
        imageUrl: 'https://media.example.test/tracking.jpg',
        imagePath: externalPath,
        mediaUrls: ['https://media.example.test/tracking.jpg'],
        mediaPaths: [externalPath],
      }),
    ));

    const bytes = Uint8Array.from([0xff, 0xd8, 0xff, 0xd9]);
    const metadata = await reservedUploadMetadata({
      userId: ownerUserId,
      filePath: mediaPath,
      contentType: 'image/jpeg',
      size: bytes.length,
    });
    await assertSucceeds(uploadBytes(
      ref(owner.storage(), mediaPath),
      bytes,
      metadata,
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
    const bytes = Uint8Array.from([0xff, 0xd8, 0xff, 0xd9]);
    const metadata = await reservedUploadMetadata({
      userId: ownerUserId,
      filePath: mediaPath,
      contentType: 'image/jpeg',
      size: bytes.length,
    });
    await uploadBytes(
      ref(owner.storage(), mediaPath),
      bytes,
      metadata,
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

    const feedConstraints = [
      where('visibility', 'in', ['public', 'contacts']),
      where('isDeleted', '==', false),
      where('isArchived', '==', false),
      orderBy('createdAt', 'desc'),
    ];
    await assertSucceeds(getDocs(query(
      collection(
        contact.firestore(),
        'users', ownerUserId, 'social_posts',
      ),
      ...feedConstraints,
    )));
    await assertFails(getDocs(query(
      collection(
        outsider.firestore(),
        'users', ownerUserId, 'social_posts',
      ),
      ...feedConstraints,
    )));
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
    const contactPhotoUrl = storageUrl(
      `profile_photos/${contactUserId}/profile.png`,
    );
    await assertSucceeds(getDoc(doc(contact.firestore(), ...likePath)));
    await assertFails(getDoc(doc(outsider.firestore(), ...likePath)));
    await assertFails(setDoc(doc(contact.firestore(), ...likePath), {
      userId: contactUserId,
      postOwnerUserId: ownerUserId,
      displayName: 'Kontakt N.',
      photoUrl: 'https://tracker.example/like.png',
      createdAt: Timestamp.now(),
    }));
    await assertSucceeds(setDoc(doc(contact.firestore(), ...likePath), {
      userId: contactUserId,
      postOwnerUserId: ownerUserId,
      displayName: 'Kontakt N.',
      photoUrl: contactPhotoUrl,
      createdAt: Timestamp.now(),
    }));
    await assertSucceeds(getDoc(doc(contact.firestore(), ...likePath)));
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
    await assertFails(setDoc(doc(contact.firestore(), ...commentPath), {
      commentId,
      postId,
      postOwnerUserId: ownerUserId,
      authorUserId: contactUserId,
      authorDisplayName: 'Kontakt N.',
      authorPhotoUrl: 'https://tracker.example/comment.png',
      text: 'Unsicheres Profilbild.',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      isDeleted: false,
    }));
    await assertSucceeds(setDoc(doc(contact.firestore(), ...commentPath), {
      commentId,
      postId,
      postOwnerUserId: ownerUserId,
      authorUserId: contactUserId,
      authorDisplayName: 'Kontakt N.',
      authorPhotoUrl: contactPhotoUrl,
      text: 'Schönes Fahrzeug.',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      isDeleted: false,
    }));
    await assertFails(updateDoc(doc(outsider.firestore(), ...commentPath), {
      isDeleted: true,
      updatedAt: Timestamp.now(),
    }));

    const replyId = 'reply-1';
    const replyPath = [
      ...commentPath, 'replies', replyId,
    ];
    await assertFails(setDoc(doc(contact.firestore(), ...replyPath), {
      replyId,
      commentId,
      postId,
      postOwnerUserId: ownerUserId,
      authorUserId: contactUserId,
      authorDisplayName: 'Kontakt N.',
      authorPhotoUrl: 'https://tracker.example/reply.png',
      text: 'Unsicheres Profilbild.',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      isDeleted: false,
    }));
    await assertSucceeds(setDoc(doc(contact.firestore(), ...replyPath), {
      replyId,
      commentId,
      postId,
      postOwnerUserId: ownerUserId,
      authorUserId: contactUserId,
      authorDisplayName: 'Kontakt N.',
      authorPhotoUrl: contactPhotoUrl,
      text: 'Danke für deine Rückmeldung.',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      isDeleted: false,
    }));
    await assertFails(setDoc(doc(outsider.firestore(), ...replyPath), {
      replyId,
      commentId,
      postId,
      postOwnerUserId: ownerUserId,
      authorUserId: outsiderUserId,
      authorDisplayName: 'Unbekannt',
      authorPhotoUrl: '',
      text: 'Unzulässige Antwort.',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      isDeleted: false,
    }));
    await assertSucceeds(updateDoc(doc(owner.firestore(), ...replyPath), {
      isDeleted: true,
      updatedAt: Timestamp.now(),
    }));

    await assertSucceeds(updateDoc(doc(owner.firestore(), ...commentPath), {
      isDeleted: true,
      updatedAt: Timestamp.now(),
    }));
  });
});
