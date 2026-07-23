const fs = require('node:fs');
const path = require('node:path');
const { after, afterEach, before, describe, test } = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  Timestamp,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  writeBatch,
} = require('firebase/firestore');
const { getBytes, ref, uploadBytes } = require('firebase/storage');

const projectId = 'carma-a84e4';
const senderUserId = 'chat-sender';
const receiverUserId = 'chat-receiver';
const outsiderUserId = 'chat-outsider';
const firestorePort = Number(process.env.FIRESTORE_EMULATOR_PORT || 8080);
const storagePort = Number(process.env.FIREBASE_STORAGE_EMULATOR_PORT || 9199);

let testEnv;

function rulesFile(fileName) {
  return fs.readFileSync(path.join(process.cwd(), fileName), 'utf8');
}

async function seedChat(chatId, overrides = {}) {
  const now = Timestamp.fromMillis(Date.now());
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'chats', chatId), {
      participants: [senderUserId, receiverUserId],
      status: 'active',
      createdAt: now,
      updatedAt: now,
      lastMessage: null,
      lastMessageAt: null,
      deletedBy: {
        [senderUserId]: false,
        [receiverUserId]: false,
      },
      ...overrides,
    });
  });
}

async function seedContactRequestChat({ requestId, status }) {
  const chatId = `request_${requestId}`;
  const now = Timestamp.fromMillis(Date.now());
  const message = 'Hallo, ich habe eine Frage zu deinem Fahrzeug.';

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'contact_requests', requestId), {
      senderUserId,
      receiverUserId,
      targetUserId: receiverUserId,
      plateKey: 'HHCR2026',
      message,
      status,
      chatId,
      createdAt: now,
      updatedAt: now,
      expiresAt: Timestamp.fromMillis(Date.now() + 60 * 60 * 1000),
      isDeleted: false,
    });
  });
  await seedChat(chatId, { requestId });
  return { chatId, message };
}

async function sendTextMessage({ db, chatId, messageId, text }) {
  const timestamp = Timestamp.fromMillis(Date.now());
  const batch = writeBatch(db);

  batch.set(doc(db, 'chats', chatId, 'messages', messageId), {
    chatId,
    senderUserId,
    type: 'text',
    text,
    createdAt: timestamp,
    updatedAt: timestamp,
    isDeleted: false,
    replyToMessageId: null,
    replyToText: null,
  });
  batch.set(
    doc(db, 'chats', chatId),
    {
      lastMessage: text,
      lastMessageAt: timestamp,
      lastReadAtBy: { [senderUserId]: timestamp },
      manualUnreadBy: { [senderUserId]: false },
      manualUnreadUpdatedAtBy: { [senderUserId]: timestamp },
      archivedBy: {
        [senderUserId]: false,
        [receiverUserId]: false,
      },
      archivedUpdatedAtBy: {
        [senderUserId]: timestamp,
        [receiverUserId]: timestamp,
      },
      updatedAt: timestamp,
    },
    { merge: true },
  );

  return batch.commit();
}

function imageMessage(chatId, messageId, overrides = {}) {
  const now = Timestamp.fromMillis(Date.now());
  return {
    chatId,
    senderUserId,
    type: 'image',
    text: 'Foto',
    imageUrl: 'https://example.invalid/image.jpg',
    imagePath: `chat_images/${chatId}/${senderUserId}/${messageId}.jpg`,
    isViewOnce: false,
    viewOnceOpenedAtBy: {},
    createdAt: now,
    updatedAt: now,
    isDeleted: false,
    ...overrides,
  };
}

async function seedImageMessage(chatId, messageId, overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'chats', chatId, 'messages', messageId),
      imageMessage(chatId, messageId, overrides),
    );
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

after(async () => {
  await testEnv.cleanup();
});

describe('Chat Firestore and Storage rules', () => {
  test('lock manual messages and uploads until the request is accepted', async () => {
    const requestId = 'pending-request';
    const { chatId, message } = await seedContactRequestChat({
      requestId,
      status: 'pending',
    });
    const senderContext = testEnv.authenticatedContext(senderUserId);
    const senderDb = senderContext.firestore();
    const senderStorage = senderContext.storage();

    await assertSucceeds(
      sendTextMessage({
        db: senderDb,
        chatId,
        messageId: `contact_request_${requestId}_initial`,
        text: message,
      }),
    );
    await assertFails(
      sendTextMessage({
        db: senderDb,
        chatId,
        messageId: 'manual-message-before-accept',
        text: 'Noch eine Nachricht',
      }),
    );
    await assertFails(
      uploadBytes(
        ref(
          senderStorage,
          `chat_images/${chatId}/${senderUserId}/before-accept.jpg`,
        ),
        new Uint8Array([1]),
        { contentType: 'image/jpeg' },
      ),
    );
  });

  test('unlock messages and uploads after the request is accepted', async () => {
    const requestId = 'accepted-request';
    const { chatId } = await seedContactRequestChat({
      requestId,
      status: 'accepted',
    });
    const senderContext = testEnv.authenticatedContext(senderUserId);

    await assertSucceeds(
      sendTextMessage({
        db: senderContext.firestore(),
        chatId,
        messageId: 'message-after-accept',
        text: 'Jetzt können wir schreiben.',
      }),
    );
    await assertSucceeds(
      uploadBytes(
        ref(
          senderContext.storage(),
          `chat_images/${chatId}/${senderUserId}/after-accept.jpg`,
        ),
        new Uint8Array([1]),
        { contentType: 'image/jpeg' },
      ),
    );
  });

  test('allow participants and reject outsiders for every attachment path', async () => {
    const chatId = 'chat-active';
    await seedChat(chatId);
    const senderStorage = testEnv.authenticatedContext(senderUserId).storage();
    const receiverStorage = testEnv
      .authenticatedContext(receiverUserId)
      .storage();
    const outsiderStorage = testEnv
      .authenticatedContext(outsiderUserId)
      .storage();
    const uploads = [
      ['chat_images/chat-active/chat-sender/image-message.jpg', 'image/jpeg'],
      [
        'chat_documents/chat-active/chat-sender/document-message_note.pdf',
        'application/pdf',
      ],
      [
        'chat_voice_memos/chat-active/chat-sender/audio-message_Sprachmemo.m4a',
        'audio/mp4',
      ],
      ['chat_videos/chat-active/chat-sender/video-message.mp4', 'video/mp4'],
    ];

    for (const [filePath, contentType] of uploads) {
      await assertSucceeds(
        uploadBytes(
          ref(senderStorage, filePath),
          new Uint8Array([1, 2, 3]),
          { contentType },
        ),
      );
      await assertSucceeds(getBytes(ref(receiverStorage, filePath)));
      await assertFails(getBytes(ref(outsiderStorage, filePath)));
    }
  });

  test('reject attachment uploads for blocked and locally deleted chats', async () => {
    await seedChat('chat-blocked', {
      status: 'blocked',
      blockedBy: senderUserId,
      blockedAt: Timestamp.fromMillis(Date.now()),
    });
    await seedChat('chat-deleted', {
      deletedBy: { [senderUserId]: true, [receiverUserId]: false },
    });
    const storage = testEnv.authenticatedContext(senderUserId).storage();

    await assertFails(
      uploadBytes(
        ref(
          storage,
          'chat_images/chat-blocked/chat-sender/blocked-message.jpg',
        ),
        new Uint8Array([1]),
        { contentType: 'image/jpeg' },
      ),
    );
    await assertFails(
      uploadBytes(
        ref(
          storage,
          'chat_images/chat-deleted/chat-sender/deleted-message.jpg',
        ),
        new Uint8Array([1]),
        { contentType: 'image/jpeg' },
      ),
    );
  });

  test('bind image messages to participant, chat and message path', async () => {
    const chatId = 'chat-message';
    const messageId = 'image-message';
    await seedChat(chatId);
    const senderDb = testEnv.authenticatedContext(senderUserId).firestore();
    const outsiderDb = testEnv.authenticatedContext(outsiderUserId).firestore();

    await assertSucceeds(
      setDoc(
        doc(senderDb, 'chats', chatId, 'messages', messageId),
        imageMessage(chatId, messageId),
      ),
    );
    await assertFails(
      setDoc(
        doc(outsiderDb, 'chats', chatId, 'messages', 'outsider-message'),
        imageMessage(chatId, 'outsider-message', {
          senderUserId: outsiderUserId,
          imagePath:
            'chat_images/chat-message/chat-outsider/outsider-message.jpg',
        }),
      ),
    );
    await assertFails(
      setDoc(
        doc(senderDb, 'chats', chatId, 'messages', 'wrong-path'),
        imageMessage(chatId, 'wrong-path', {
          imagePath: 'chat_images/chat-message/chat-sender/other.jpg',
        }),
      ),
    );
  });

  test('allow the repository image transaction and first status-map merge', async () => {
    const chatId = 'chat-transaction';
    const messageId = 'transaction-image';
    await seedChat(chatId);
    const senderDb = testEnv.authenticatedContext(senderUserId).firestore();
    const timestamp = Timestamp.fromMillis(Date.now());
    const batch = writeBatch(senderDb);

    batch.set(
      doc(senderDb, 'chats', chatId, 'messages', messageId),
      imageMessage(chatId, messageId, {
        createdAt: timestamp,
        updatedAt: timestamp,
      }),
    );
    batch.set(
      doc(senderDb, 'chats', chatId),
      {
        lastMessage: 'Foto',
        lastMessageAt: timestamp,
        lastReadAtBy: { [senderUserId]: timestamp },
        manualUnreadBy: { [senderUserId]: false },
        manualUnreadUpdatedAtBy: { [senderUserId]: timestamp },
        archivedBy: {
          [senderUserId]: false,
          [receiverUserId]: false,
        },
        archivedUpdatedAtBy: {
          [senderUserId]: timestamp,
          [receiverUserId]: timestamp,
        },
        updatedAt: timestamp,
      },
      { merge: true },
    );

    await assertSucceeds(batch.commit());
  });

  test('allow view-once open exactly once and only for the receiver', async () => {
    const chatId = 'chat-view-once';
    const messageId = 'view-once-image';
    await seedChat(chatId);
    await seedImageMessage(chatId, messageId, { isViewOnce: true });
    const receiverDb = testEnv
      .authenticatedContext(receiverUserId)
      .firestore();
    const senderDb = testEnv.authenticatedContext(senderUserId).firestore();
    const messagePath = ['chats', chatId, 'messages', messageId];
    const openedAt = Timestamp.fromMillis(Date.now());

    await assertSucceeds(
      updateDoc(doc(receiverDb, ...messagePath), {
        viewOnceOpenedAtBy: { [receiverUserId]: openedAt },
        updatedAt: openedAt,
      }),
    );
    await assertFails(
      updateDoc(doc(receiverDb, ...messagePath), {
        viewOnceOpenedAtBy: {
          [receiverUserId]: Timestamp.fromMillis(Date.now() + 1),
        },
        updatedAt: Timestamp.fromMillis(Date.now() + 1),
      }),
    );
    await assertFails(
      updateDoc(doc(senderDb, ...messagePath), {
        viewOnceOpenedAtBy: { [senderUserId]: openedAt },
        updatedAt: openedAt,
      }),
    );
  });

  test('keep per-user and delete-for-everyone semantics separate', async () => {
    const chatId = 'chat-delete';
    await seedChat(chatId);
    await seedImageMessage(chatId, 'delete-for-me');
    await seedImageMessage(chatId, 'delete-for-all');
    const receiverDb = testEnv
      .authenticatedContext(receiverUserId)
      .firestore();
    const senderDb = testEnv.authenticatedContext(senderUserId).firestore();
    const now = Timestamp.fromMillis(Date.now());

    await assertSucceeds(
      updateDoc(doc(receiverDb, 'chats', chatId, 'messages', 'delete-for-me'), {
        deletedFor: { [receiverUserId]: true },
        updatedAt: now,
      }),
    );
    await assertFails(
      updateDoc(
        doc(receiverDb, 'chats', chatId, 'messages', 'delete-for-all'),
        { isDeleted: true, updatedAt: now },
      ),
    );
    await assertSucceeds(
      updateDoc(
        doc(senderDb, 'chats', chatId, 'messages', 'delete-for-all'),
        { isDeleted: true, updatedAt: now },
      ),
    );

    const outsiderDb = testEnv.authenticatedContext(outsiderUserId).firestore();
    await assertFails(
      getDoc(doc(outsiderDb, 'chats', chatId, 'messages', 'delete-for-me')),
    );
  });
});
