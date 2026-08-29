const {initializeApp, deleteApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');

const projectId = 'carma-a84e4';
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || '';
const allowedHosts = new Set(['127.0.0.1:8080', 'localhost:8080']);

if (!allowedHosts.has(firestoreHost)) {
  throw new Error(
    'FIRESTORE_EMULATOR_HOST must explicitly target the local emulator on port 8080.',
  );
}

async function main() {
  const app = initializeApp({projectId}, 'block5-inspector');
  const firestore = getFirestore(app);

  try {
    const chats = await firestore.collection('chats').get();
    const output = [];

    for (const chat of chats.docs) {
      const messages = await chat.ref.collection('messages').orderBy('createdAt').get();
      output.push({
        id: chat.id,
        status: chat.get('status') || null,
        blockedBy: chat.get('blockedBy') || null,
        participants: chat.get('participants') || [],
        messages: messages.docs.map((message) => ({
          id: message.id,
          senderUserId: message.get('senderUserId') || null,
          text: message.get('text') || null,
        })),
      });
    }

    console.log(JSON.stringify({projectId, chats: output}, null, 2));
  } finally {
    await deleteApp(app);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
