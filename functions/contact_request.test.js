const assert = require("node:assert/strict");
const {createHash} = require("node:crypto");
const test = require("node:test");

const {
  contactGrantId,
  createContactRequest,
} = require("./contact_request");

const now = new Date("2026-08-29T10:00:00.000Z");

function snapshot(value, id = "") {
  return {exists: value != null, id, data: () => value};
}

function fakeFirestore(seed = {}) {
  const documents = new Map(Object.entries(seed));
  const reference = (path) => ({
    path,
    async get() {
      return snapshot(documents.get(path), path.split("/").at(-1));
    },
  });
  return {
    documents,
    doc: reference,
    collection(path) {
      return {
        where(field, operator, expected) {
          assert.equal(operator, "==");
          return {
            limit() {
              return {
                async get() {
                  const prefix = `${path}/`;
                  const docs = [...documents.entries()]
                    .filter(([key, value]) => key.startsWith(prefix) &&
                      !key.slice(prefix.length).includes("/") &&
                      value?.[field] === expected)
                    .map(([key, value]) => snapshot(
                      value,
                      key.slice(prefix.length),
                    ));
                  return {docs: docs.slice(0, 1)};
                },
              };
            },
          };
        },
      };
    },
    async runTransaction(callback) {
      return callback({
        get: (ref) => ref.get(),
        set(ref, value) {
          documents.set(ref.path, value);
        },
        update(ref, value) {
          documents.set(ref.path, {...documents.get(ref.path), ...value});
        },
        delete(ref) {
          documents.delete(ref.path);
        },
      });
    },
  };
}

function trustedPhoto(userId) {
  return "https://firebasestorage.googleapis.com/v0/b/" +
    "carma-a84e4.firebasestorage.app/o/" +
    `profile_photos%2F${userId}%2Fprofile.png?alt=media&token=test-token`;
}

function validSeed(overrides = {}) {
  const sender = "sender-user";
  const target = overrides.target || "target-user";
  const vehicle = overrides.vehicle || "target-vehicle";
  const country = "DE";
  const plate = overrides.plate || "HHCR2026";
  const grant = `plate_contact_grants/${contactGrantId(sender, country, vehicle)}`;
  return {
    [`public_profiles/${sender}`]: {
      displayName: "Sender",
      photoUrl: trustedPhoto(sender),
      primaryVehicleId: "sender-vehicle",
      verificationStatus: "verified",
    },
    [`public_profiles/${sender}/vehicles/sender-vehicle`]: {isVerified: true},
    [`users/${sender}/profiles/main`]: {
      firstName: "Sina",
      lastName: "Sender",
      verificationStatus: "verified",
    },
    [`public_profiles/${target}`]: {
      displayName: "Tara Target",
      photoUrl: trustedPhoto(target),
      profileAccessEnabled: true,
    },
    [`plates/${country}_${plate}`]: {
      ownerUserId: target,
      vehicleId: vehicle,
      countryCode: country,
      plateKey: plate,
      displayPlate: "HH-CR 2026",
      vehicleBrand: "BMW",
      vehicleModel: "X6",
      vehicleColor: "Schwarz",
      vehicleLabel: "BMW X6",
      isActive: true,
      isDeleted: false,
      isVerified: true,
      allowContactRequests: true,
    },
    [`users/${target}/settings/visibility`]: {
      allowContactRequests: true,
      plateSearchVisibility: "contacts",
    },
    [`users/${target}/settings/contact_filters`]: {
      requesterVerificationLevel: "all",
      allowedContactReasons: ["vehicle_question"],
      contactRequestQuietModeUntil: null,
    },
    [grant]: {
      requesterUserId: sender,
      targetUserId: target,
      countryCode: country,
      vehicleId: vehicle,
      plateHash: createHash("sha256").update(plate).digest("hex"),
      expiresAt: {toMillis: () => now.getTime() + 60_000},
    },
  };
}

function validInput(overrides = {}) {
  return {
    targetUserId: "target-user",
    countryCode: "DE",
    vehicleId: "target-vehicle",
    plateKey: "HHCR2026",
    requestReason: "vehicle_question",
    message: "Hallo, ich habe eine Frage zu deinem Fahrzeug.",
    ...overrides,
  };
}

test("creates a server-derived request, chat and initial message atomically", async () => {
  const firestore = fakeFirestore(validSeed());
  const result = await createContactRequest({
    firestore,
    senderUserId: "sender-user",
    input: validInput({receiverDisplayName: "Gefälscht"}),
    now,
  });

  assert.equal(result.created, true);
  const request = firestore.documents.get(`contact_requests/${result.requestId}`);
  assert.equal(request.receiverDisplayName, "Tara Target");
  assert.equal(request.senderDisplayName, "Sina Sender");
  assert.equal(request.vehicleModel, "X6");
  assert.equal(request.status, "pending");
  assert.equal(Object.keys(request).length, 24);
  assert.ok(firestore.documents.has(`chats/${result.chatId}`));
  assert.ok(firestore.documents.has(
    `chats/${result.chatId}/messages/contact_request_${result.requestId}_initial`,
  ));
  assert.equal(
    [...firestore.documents.keys()].some((path) =>
      path.startsWith("plate_contact_grants/")),
    false,
  );
});

test("requires a fresh successful plate-search grant", async () => {
  const seed = validSeed();
  for (const key of Object.keys(seed)) {
    if (key.startsWith("plate_contact_grants/")) delete seed[key];
  }
  await assert.rejects(
    createContactRequest({
      firestore: fakeFirestore(seed),
      senderUserId: "sender-user",
      input: validInput(),
      now,
    }),
    (error) => error.code === "failed-precondition",
  );
});

test("rejects stale public verification when receiver V1 has expired", async () => {
  const seed = validSeed();
  seed["users/target-user/private_verification/identity"] = {
    status: "verified",
    documentExpiresAt: "2026-08-28",
    verificationMethod: "on_device_ocr_front_v1",
    assuranceLevel: "document_data_match",
  };
  seed["users/target-user/vehicle_verifications/target-vehicle"] = {
    status: "verified",
    plateNormalized: "HHCR2026",
    verificationMethod: "on_device_ocr_front_v1",
    assuranceLevel: "document_data_match",
  };
  seed["users/target-user/vehicles/target-vehicle"] = {
    ownerUserId: "target-user",
    countryCode: "DE",
    plateRegion: "HH",
    plateLetters: "CR",
    plateNumbers: "2026",
    status: "active",
  };

  await assert.rejects(
    createContactRequest({
      firestore: fakeFirestore(seed),
      senderUserId: "sender-user",
      input: validInput(),
      now,
    }),
    (error) => error.code === "not-found",
  );
});

test("rejects a target account whose deletion is already reserved", async () => {
  const seed = validSeed();
  seed["account_deletions/target-user"] = {status: "processing"};
  await assert.rejects(
    createContactRequest({
      firestore: fakeFirestore(seed),
      senderUserId: "sender-user",
      input: validInput(),
      now,
    }),
    (error) => error.code === "not-found",
  );
});

test("rejects a sender account whose deletion is already reserved", async () => {
  const seed = validSeed();
  seed["account_deletions/sender-user"] = {status: "requested"};
  await assert.rejects(
    createContactRequest({
      firestore: fakeFirestore(seed),
      senderUserId: "sender-user",
      input: validInput(),
      now,
    }),
    (error) => error.code === "not-found",
  );
});

test("returns an active request idempotently without spending another grant", async () => {
  const firestore = fakeFirestore(validSeed());
  const first = await createContactRequest({
    firestore,
    senderUserId: "sender-user",
    input: validInput(),
    now,
  });
  const result = await createContactRequest({
    firestore,
    senderUserId: "sender-user",
    input: validInput(),
    now: new Date(now.getTime() + 1_000),
  });
  assert.equal(result.requestId, first.requestId);
  assert.equal(result.created, false);
});

test("enforces a sender-target cooldown after a completed request", async () => {
  const firestore = fakeFirestore(validSeed());
  const first = await createContactRequest({
    firestore,
    senderUserId: "sender-user",
    input: validInput(),
    now,
  });
  firestore.documents.set(`contact_requests/${first.requestId}`, {
    ...firestore.documents.get(`contact_requests/${first.requestId}`),
    status: "withdrawn",
  });
  const secondNow = new Date(now.getTime() + 60_000);
  firestore.documents.set(
    `plate_contact_grants/${contactGrantId("sender-user", "DE", "target-vehicle")}`,
    {
      requesterUserId: "sender-user",
      targetUserId: "target-user",
      countryCode: "DE",
      vehicleId: "target-vehicle",
      plateHash: createHash("sha256").update("HHCR2026").digest("hex"),
      expiresAt: {toMillis: () => secondNow.getTime() + 60_000},
    },
  );
  await assert.rejects(
    createContactRequest({
      firestore,
      senderUserId: "sender-user",
      input: validInput(),
      now: secondNow,
    }),
    (error) => error.code === "resource-exhausted",
  );
});

test("rejects unsupported reasons and oversized messages", async () => {
  for (const input of [
    validInput({requestReason: "custom"}),
    validInput({message: "x".repeat(1001)}),
  ]) {
    await assert.rejects(
      createContactRequest({
        firestore: fakeFirestore(validSeed()),
        senderUserId: "sender-user",
        input,
        now,
      }),
      (error) => error.code === "invalid-argument",
    );
  }
});
