const assert = require("node:assert/strict");
const test = require("node:test");
const {Timestamp} = require("firebase-admin/firestore");

const {
  maxAccountVehicleHeroRequestsPerWindow,
  reserveAccountVehicleHeroQuota,
} = require("./vehicle_hero_quota");

test("enforces one paid image budget across all account vehicles", async () => {
  const firestore = fakeFirestore();
  const now = Timestamp.fromDate(new Date("2026-08-29T10:00:00.000Z"));

  for (let index = 0;
    index < maxAccountVehicleHeroRequestsPerWindow;
    index += 1) {
    await firestore.runTransaction((transaction) =>
      reserveAccountVehicleHeroQuota({
        firestore,
        transaction,
        userId: "image-user",
        now,
      }));
  }

  await assert.rejects(
    firestore.runTransaction((transaction) =>
      reserveAccountVehicleHeroQuota({
        firestore,
        transaction,
        userId: "image-user",
        now,
      })),
    (error) => error.code === "resource-exhausted",
  );
  assert.equal(
    firestore.documents.get("vehicle_hero_rate_limits/image-user")
      .requestCount,
    maxAccountVehicleHeroRequestsPerWindow,
  );
});

function fakeFirestore() {
  const documents = new Map();
  const firestore = {
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
      });
    },
  };
  return firestore;
}
