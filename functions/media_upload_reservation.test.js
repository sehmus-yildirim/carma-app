const assert = require("node:assert/strict");
const test = require("node:test");
const {Timestamp} = require("firebase-admin/firestore");

const {
  maxUploadBytesPerWindow,
  maxUploadReservationsPerWindow,
  recordDeletedMediaUpload,
  recordFinalizedMediaUpload,
  reserveMediaUpload,
} = require("./media_upload_reservation");

const now = new Date("2026-08-29T10:00:00.000Z");

test("reserves one exact owned upload path", async () => {
  const firestore = fakeFirestore();
  const result = await reserveMediaUpload({
    firestore,
    userId: "upload-user",
    input: {
      storagePath: "chat_images/chat-1/upload-user/message-1.jpg",
      contentType: "image/jpeg",
      sizeBytes: 1024,
    },
    now,
  });

  const reservation = firestore.documents.get(
    `_media_upload_reservations/${result.reservationId}`,
  );
  assert.equal(reservation.userId, "upload-user");
  assert.equal(
    reservation.storagePath,
    "chat_images/chat-1/upload-user/message-1.jpg",
  );
  assert.equal(reservation.maxBytes, 1024);
  assert.equal(reservation.status, "reserved");
});

test("rejects paths owned by another account and oversized uploads", async () => {
  const firestore = fakeFirestore();
  for (const input of [
    {
      storagePath: "chat_images/chat-1/other-user/message-1.jpg",
      contentType: "image/jpeg",
      sizeBytes: 1024,
    },
    {
      storagePath: "chat_videos/chat-1/upload-user/message-1.mp4",
      contentType: "video/mp4",
      sizeBytes: 81 * 1024 * 1024,
    },
  ]) {
    await assert.rejects(
      reserveMediaUpload({firestore, userId: "upload-user", input, now}),
      (error) => error.code === "invalid-argument",
    );
  }
});

test("caps total daily upload bytes and reservation count", async () => {
  const firestore = fakeFirestore({
    "_media_upload_limits/upload-user": {
      userId: "upload-user",
      windowStartedAt: Timestamp.fromDate(now),
      reservationCount: maxUploadReservationsPerWindow,
      reservedBytes: maxUploadBytesPerWindow - 1,
    },
  });

  await assert.rejects(
    reserveMediaUpload({
      firestore,
      userId: "upload-user",
      input: {
        storagePath: "report_images/report-123/upload-user/evidence.jpg",
        contentType: "image/jpeg",
        sizeBytes: 1,
      },
      now,
    }),
    (error) => error.code === "resource-exhausted",
  );
  assert.equal(
    [...firestore.documents.keys()]
      .filter((path) => path.startsWith("_media_upload_reservations/")).length,
    0,
  );
});

test("tracks live storage and releases quota only after object deletion", async () => {
  const firestore = fakeFirestore();
  const result = await reserveMediaUpload({
    firestore,
    userId: "upload-user",
    input: {
      storagePath: "chat_images/chat-1/upload-user/message-1.jpg",
      contentType: "image/jpeg",
      sizeBytes: 1024,
    },
    now,
  });
  const object = {
    name: "chat_images/chat-1/upload-user/message-1.jpg",
    generation: "123456",
    contentType: "image/jpeg",
    size: "1024",
    metadata: {uploadReservationId: result.reservationId},
  };

  assert.equal(await recordFinalizedMediaUpload({
    firestore,
    object,
    now: Timestamp.fromDate(now),
  }), true);
  let limit = firestore.documents.get("_media_upload_limits/upload-user");
  assert.equal(limit.pendingBytes, 0);
  assert.equal(limit.storedBytes, 1024);

  assert.equal(await recordDeletedMediaUpload({
    firestore,
    object,
    now: Timestamp.fromDate(now),
  }), true);
  limit = firestore.documents.get("_media_upload_limits/upload-user");
  assert.equal(limit.storedBytes, 0);
});

test("does not consume a reservation for a different object size", async () => {
  const firestore = fakeFirestore();
  const result = await reserveMediaUpload({
    firestore,
    userId: "upload-user",
    input: {
      storagePath: "chat_images/chat-1/upload-user/message-1.jpg",
      contentType: "image/jpeg",
      sizeBytes: 1024,
    },
    now,
  });

  assert.equal(await recordFinalizedMediaUpload({
    firestore,
    object: {
      name: "chat_images/chat-1/upload-user/message-1.jpg",
      generation: "smaller-object",
      contentType: "image/jpeg",
      size: "512",
      metadata: {uploadReservationId: result.reservationId},
    },
    now: Timestamp.fromDate(now),
  }), false);
  assert.equal(
    firestore.documents.get(
      `_media_upload_reservations/${result.reservationId}`,
    ).status,
    "reserved",
  );
  assert.equal(
    firestore.documents.get("_media_upload_limits/upload-user").storedBytes,
    0,
  );
});

function fakeFirestore(initialDocuments = {}) {
  const documents = new Map(Object.entries(initialDocuments));
  return {
    documents,
    doc(path) {
      return {path};
    },
    async runTransaction(callback) {
      return callback({
        async get(reference) {
          const data = documents.get(reference.path);
          return {exists: data != null, data: () => data};
        },
        set(reference, data, options) {
          const current = options?.merge === true ?
            documents.get(reference.path) ?? {} : {};
          documents.set(reference.path, {...current, ...data});
        },
        create(reference, data) {
          if (documents.has(reference.path)) {
            throw new Error("already exists");
          }
          documents.set(reference.path, data);
        },
        delete(reference) {
          documents.delete(reference.path);
        },
      });
    },
  };
}
