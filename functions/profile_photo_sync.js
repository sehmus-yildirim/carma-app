const {FieldValue} = require("firebase-admin/firestore");

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function photoValue(value) {
  const normalized = safeString(value);
  return normalized.length === 0 ? null : normalized;
}

function profilePhotoUpdateFor({collection, data, userId, photoUrl}) {
  const update = {updatedAt: FieldValue.serverTimestamp()};

  if (collection === "chats") {
    if (safeString(data.senderUserId) === userId) {
      update.senderPhotoUrl = photoUrl;
    }
    if (safeString(data.receiverUserId) === userId) {
      update.receiverPhotoUrl = photoUrl;
    }
  } else if (collection === "contact_requests") {
    if (safeString(data.senderUserId) === userId) {
      update.senderPhotoUrl = photoUrl;
    }
    if (safeString(data.receiverUserId) === userId) {
      update.receiverPhotoUrl = photoUrl;
    }
  } else if (collection === "follow_relationships") {
    if (safeString(data.followerUserId) === userId) {
      update.followerPhotoUrl = photoUrl;
    }
    if (safeString(data.followedUserId) === userId) {
      update.followedPhotoUrl = photoUrl;
    }
  } else if (collection === "chat_stories") {
    update.ownerPhotoUrl = photoUrl;
  } else if (collection === "vehicle_encounters") {
    if (safeString(data.initiatorUserId) === userId) {
      update.initiatorPhotoUrl = photoUrl;
    }
    if (safeString(data.recipientUserId) === userId) {
      update.recipientPhotoUrl = photoUrl;
    }
  } else if (collection === "plates") {
    update.profilePhotoUrl = photoUrl;
  }

  return Object.keys(update).length === 1 ? null : update;
}

async function syncProfilePhotoReferences({firestore, userId, photoUrl}) {
  const normalizedUserId = safeString(userId);
  if (normalizedUserId.length === 0) {
    throw new TypeError("userId is required");
  }
  const normalizedPhotoUrl = photoValue(photoUrl);
  const querySpecs = [
    {
      collection: "chats",
      query: firestore.collection("chats")
        .where("participants", "array-contains", normalizedUserId),
    },
    {
      collection: "contact_requests",
      query: firestore.collection("contact_requests")
        .where("senderUserId", "==", normalizedUserId),
    },
    {
      collection: "contact_requests",
      query: firestore.collection("contact_requests")
        .where("receiverUserId", "==", normalizedUserId),
    },
    {
      collection: "follow_relationships",
      query: firestore.collection("follow_relationships")
        .where("followerUserId", "==", normalizedUserId),
    },
    {
      collection: "follow_relationships",
      query: firestore.collection("follow_relationships")
        .where("followedUserId", "==", normalizedUserId),
    },
    {
      collection: "chat_stories",
      query: firestore.collection("chat_stories")
        .where("ownerUserId", "==", normalizedUserId),
    },
    {
      collection: "vehicle_encounters",
      query: firestore.collection("vehicle_encounters")
        .where("participantUserIds", "array-contains", normalizedUserId),
    },
    {
      collection: "plates",
      query: firestore.collection("plates")
        .where("ownerUserId", "==", normalizedUserId),
    },
  ];
  const snapshots = await Promise.all(
    querySpecs.map(({query}) => query.get()),
  );
  const writer = firestore.bulkWriter();
  const writtenPaths = new Set();

  querySpecs.forEach(({collection}, index) => {
    for (const document of snapshots[index].docs) {
      if (writtenPaths.has(document.ref.path)) continue;
      const update = profilePhotoUpdateFor({
        collection,
        data: document.data() ?? {},
        userId: normalizedUserId,
        photoUrl: normalizedPhotoUrl,
      });
      if (update == null) continue;
      writtenPaths.add(document.ref.path);
      writer.set(document.ref, update, {merge: true});
    }
  });

  await writer.close();
  return {updatedReferenceCount: writtenPaths.size};
}

module.exports = {
  photoValue,
  profilePhotoUpdateFor,
  syncProfilePhotoReferences,
};
