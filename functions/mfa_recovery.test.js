const assert = require("node:assert/strict");
const test = require("node:test");

const {
  approvalConfirmation,
  caseCreationConfirmation,
  identityVerificationConfirmation,
  listMfaRecoveryCases,
  markMfaRecoveryIdentityVerified,
  openMfaRecoveryCase,
  requestMfaRecovery,
  reviewMfaRecovery,
} = require("./mfa_recovery");

const now = new Date("2026-08-12T12:00:00.000Z");
const userAuth = {
  uid: "user-1",
  token: {firebase: {sign_in_provider: "password"}},
};
const adminAuth = {
  uid: "admin-1",
  token: {admin: true, auth_time: Math.floor(now.getTime() / 1000)},
};
const secondAdminAuth = {
  uid: "admin-2",
  token: {admin: true, auth_time: Math.floor(now.getTime() / 1000)},
};

test("recovery request requires an authenticated user", async () => {
  await assert.rejects(
    requestMfaRecovery({
      firestore: fakeFirestore(),
      authAdmin: {async getUser() { throw new Error("must not run"); }},
      authContext: null,
      input: {},
      now,
    }),
    (error) => error.code === "unauthenticated",
  );
});

test("request uses auth uid, stays private, and is idempotent", async () => {
  const firestore = fakeFirestore();
  const authAdmin = enrolledAuthAdmin();
  const first = await requestMfaRecovery({
    firestore,
    authAdmin,
    authContext: userAuth,
    input: {
      platform: "android",
      targetUserId: "attacker-selected-user",
      phoneNumber: "+491701234567",
      smsCode: "123456",
    },
    now,
    createId: () => "recovery-1",
  });
  const second = await requestMfaRecovery({
    firestore,
    authAdmin,
    authContext: userAuth,
    input: {platform: "android"},
    now,
    createId: () => "recovery-2",
  });

  assert.equal(first.requestId, "recovery-1");
  assert.equal(second.requestId, "recovery-1");
  assert.equal(second.alreadyRequested, true);
  const request = firestore.documents.get("mfa_recovery_requests/user-1");
  assert.equal(request.userId, "user-1");
  assert.equal(request.maskedEmail, "k***@e***.com");
  assert.deepEqual(request.providerTypes, ["google.com", "password"]);
  assert.equal(request.factorCount, 1);

  const serialized = JSON.stringify(firestore.writes);
  assert.equal(serialized.includes("attacker-selected-user"), false);
  assert.equal(serialized.includes("+491701234567"), false);
  assert.equal(serialized.includes("123456"), false);
  assert.equal(serialized.includes("konto@example.com"), false);
  assert.equal(serialized.includes("password\":"), false);
});

test("normal users and forged firestore roles cannot review recovery", async () => {
  const firestore = fakeFirestore({
    "mfa_recovery_requests/user-1": pendingRequest(),
    "users/user-2": {admin: true},
  });
  await assert.rejects(
    reviewMfaRecovery({
      firestore,
      authAdmin: {},
      authContext: {uid: "user-2", token: {admin: false}},
      input: {
        targetUserId: "user-1",
        requestId: "recovery-1",
        decision: "approve",
        confirmation: approvalConfirmation,
      },
      now,
    }),
    (error) => error.code === "permission-denied",
  );
});

test("admin case list returns only reduced technical metadata", async () => {
  const firestore = fakeFirestore({
    "mfa_recovery_requests/user-1": {
      ...pendingRequest(),
      maskedEmail: "k***@e***.com",
      phoneNumber: "+491701234567",
      smsCode: "123456",
    },
  });
  const result = await listMfaRecoveryCases({
    firestore,
    authAdmin: recoveryAuthAdmin(),
    authContext: adminAuth,
    input: {limit: 25},
  });

  assert.equal(result.cases.length, 1);
  assert.equal(result.cases[0].targetUserId, "user-1");
  const serialized = JSON.stringify(result);
  assert.equal(serialized.includes("+491701234567"), false);
  assert.equal(serialized.includes("123456"), false);
});

test("only a confirmed custom-claim admin can open a locked-out case", async () => {
  const firestore = fakeFirestore();
  const authAdmin = enrolledAuthAdmin();
  const input = {
    targetUserId: "user-1",
    confirmation: caseCreationConfirmation,
    accountEmail: "must-not-be-stored@example.com",
  };
  await assert.rejects(
    openMfaRecoveryCase({
      firestore,
      authAdmin,
      authContext: {uid: "support-1", token: {admin: false}},
      input,
      now,
    }),
    (error) => error.code === "permission-denied",
  );

  const result = await openMfaRecoveryCase({
    firestore,
    authAdmin,
    authContext: adminAuth,
    input,
    now,
    createId: () => "admin-recovery-1",
  });
  assert.equal(result.status, "pending");
  const request = firestore.documents.get("mfa_recovery_requests/user-1");
  assert.equal(request.source, "admin-support");
  assert.equal(request.maskedEmail, "k***@e***.com");
  assert.equal(
    JSON.stringify(firestore.writes).includes("must-not-be-stored"),
    false,
  );
});

test("two different admins are required before sessions and MFA change", async () => {
  const firestore = fakeFirestore({
    "mfa_recovery_requests/user-1": pendingRequest(),
  });
  const operations = [];
  const authAdmin = recoveryAuthAdmin(operations);

  await markMfaRecoveryIdentityVerified({
    firestore,
    authAdmin,
    authContext: adminAuth,
    input: {
      targetUserId: "user-1",
      requestId: "recovery-1",
      confirmation: identityVerificationConfirmation,
    },
    now,
  });
  const first = await reviewMfaRecovery({
    firestore,
    authAdmin,
    authContext: adminAuth,
    input: approvalInput(),
    now,
  });

  assert.equal(first.requiresSecondAdmin, true);
  assert.deepEqual(operations, []);
  await assert.rejects(
    reviewMfaRecovery({
      firestore,
      authAdmin,
      authContext: adminAuth,
      input: approvalInput(),
      now,
    }),
    (error) => error.code === "permission-denied",
  );

  const completed = await reviewMfaRecovery({
    firestore,
    authAdmin,
    authContext: secondAdminAuth,
    input: approvalInput(),
    now,
    createId: () => "lease-1",
  });
  const repeated = await reviewMfaRecovery({
    firestore,
    authAdmin,
    authContext: secondAdminAuth,
    input: approvalInput(),
    now,
  });

  assert.deepEqual(operations, ["revoke", "remove-mfa"]);
  assert.equal(completed.status, "completed");
  assert.equal(repeated.changed, false);
  const request = firestore.documents.get("mfa_recovery_requests/user-1");
  assert.equal(request.firstApprovedBy, "admin-1");
  assert.equal(request.secondApprovedBy, "admin-2");
  assert.equal(request.status, "completed");
});

test("rejection never changes authentication or MFA", async () => {
  const firestore = fakeFirestore({
    "mfa_recovery_requests/user-1": pendingRequest(),
  });
  let authCalls = 0;
  const authAdmin = recoveryAuthAdmin();
  authAdmin.revokeRefreshTokens = async () => { authCalls += 1; };
  authAdmin.updateUser = async () => { authCalls += 1; };
  const result = await reviewMfaRecovery({
    firestore,
    authAdmin,
    authContext: adminAuth,
    input: {
      targetUserId: "user-1",
      requestId: "recovery-1",
      decision: "reject",
      reasonCode: "insufficient-evidence",
    },
    now,
  });

  assert.equal(result.status, "rejected");
  assert.equal(authCalls, 0);
});

test("failed technical completion remains safe and retryable", async () => {
  const firestore = fakeFirestore({
    "mfa_recovery_requests/user-1": {
      ...pendingRequest(),
      status: "awaiting_second_approval",
      identityVerifiedBy: "admin-1",
      firstApprovedBy: "admin-1",
    },
  });
  let updateAttempts = 0;
  const authAdmin = recoveryAuthAdmin();
  authAdmin.updateUser = async () => {
      updateAttempts += 1;
      if (updateAttempts === 1) throw new Error("temporary admin failure");
  };

  await assert.rejects(
    reviewMfaRecovery({
      firestore,
      authAdmin,
      authContext: secondAdminAuth,
      input: approvalInput(),
      now,
      createId: () => "failed-lease",
    }),
    (error) => error.code === "internal",
  );
  assert.equal(
    firestore.documents.get("mfa_recovery_requests/user-1").status,
    "processing_failed",
  );

  const retry = await reviewMfaRecovery({
    firestore,
    authAdmin,
    authContext: adminAuth,
    input: approvalInput(),
    now: new Date(now.getTime() + 16 * 60 * 1000),
    createId: () => "retry-lease",
  });
  assert.equal(retry.status, "completed");
  assert.equal(updateAttempts, 2);
});

test("parallel second approval cannot complete recovery twice", async () => {
  const firestore = fakeFirestore({
    "mfa_recovery_requests/user-1": {
      ...pendingRequest(),
      status: "awaiting_second_approval",
      identityVerifiedBy: "admin-1",
      firstApprovedBy: "admin-1",
    },
  });
  const operations = [];
  const authAdmin = recoveryAuthAdmin(operations);

  const results = await Promise.all([
    reviewMfaRecovery({
      firestore,
      authAdmin,
      authContext: secondAdminAuth,
      input: approvalInput(),
      now,
      createId: () => "parallel-lease-1",
    }),
    reviewMfaRecovery({
      firestore,
      authAdmin,
      authContext: secondAdminAuth,
      input: approvalInput(),
      now,
      createId: () => "parallel-lease-2",
    }),
  ]);

  assert.deepEqual(operations, ["revoke", "remove-mfa"]);
  assert.equal(results.filter((result) => result.changed).length, 1);
});

test("revoked admin sessions and self approval are rejected", async () => {
  const firestore = fakeFirestore({
    "mfa_recovery_requests/admin-1": {
      ...pendingRequest(),
      userId: "admin-1",
    },
  });
  const authAdmin = recoveryAuthAdmin();
  authAdmin.getUser = async (userId) => ({
    disabled: false,
    tokensValidAfterTime: userId === "admin-1" ?
      new Date(now.getTime() + 1000).toISOString() : "",
    multiFactor: {enrolledFactors: []},
  });

  await assert.rejects(
    reviewMfaRecovery({
      firestore,
      authAdmin,
      authContext: adminAuth,
      input: {...approvalInput(), targetUserId: "admin-1"},
      now,
    }),
    (error) => ["unauthenticated", "permission-denied"].includes(error.code),
  );
});

test("target user cannot approve their own recovery even with admin claim", async () => {
  const firestore = fakeFirestore({
    "mfa_recovery_requests/admin-1": {
      ...pendingRequest(),
      userId: "admin-1",
      status: "identity_verified",
    },
  });
  const authAdmin = recoveryAuthAdmin();

  await assert.rejects(
    reviewMfaRecovery({
      firestore,
      authAdmin,
      authContext: adminAuth,
      input: {...approvalInput(), targetUserId: "admin-1"},
      now,
    }),
    (error) => error.code === "permission-denied",
  );
});

function enrolledAuthAdmin() {
  return {
    async getUser(userId) {
      if (["admin-1", "admin-2"].includes(userId)) {
        return {disabled: false, tokensValidAfterTime: ""};
      }
      assert.equal(userId, "user-1");
      return {
        email: "konto@example.com",
        emailVerified: true,
        providerData: [{providerId: "google.com"}],
        multiFactor: {
          enrolledFactors: [{factorId: "phone", phoneNumber: "+491701234567"}],
        },
      };
    },
  };
}

function recoveryAuthAdmin(operations = []) {
  let factorPresent = true;
  return {
    async getUser(userId) {
      if (["admin-1", "admin-2"].includes(userId)) {
        return {disabled: false, tokensValidAfterTime: ""};
      }
      assert.equal(userId, "user-1");
      return {
        disabled: false,
        tokensValidAfterTime: "2026-08-12T12:00:01.000Z",
        multiFactor: {
          enrolledFactors: factorPresent ? [{factorId: "phone"}] : [],
        },
      };
    },
    async revokeRefreshTokens(userId) {
      assert.equal(userId, "user-1");
      operations.push("revoke");
    },
    async updateUser(userId, update) {
      assert.equal(userId, "user-1");
      assert.deepEqual(update, {multiFactor: {enrolledFactors: []}});
      factorPresent = false;
      operations.push("remove-mfa");
    },
  };
}

function approvalInput() {
  return {
    targetUserId: "user-1",
    requestId: "recovery-1",
    decision: "approve",
    reasonCode: "identity-verified",
    confirmation: approvalConfirmation,
  };
}

function pendingRequest() {
  return {
    requestId: "recovery-1",
    userId: "user-1",
    status: "pending",
    requestedAt: now,
    updatedAt: now,
  };
}

function fakeFirestore(initialDocuments = {}) {
  const documents = new Map(Object.entries(initialDocuments));
  const writes = [];
  let transactionTail = Promise.resolve();

  function reference(path) {
    return {
      path,
      async get() {
        const data = documents.get(path);
        return {exists: data != null, data: () => data};
      },
      async set(data, options) {
        const current = options?.merge === true ? documents.get(path) ?? {} : {};
        documents.set(path, {...current, ...data});
        writes.push({path, data});
      },
    };
  }

  return {
    documents,
    writes,
    doc: reference,
    collection(collectionPath) {
      const query = {
        orderBy() { return query; },
        limit() { return query; },
        async get() {
          return {
            docs: [...documents.entries()]
              .filter(([path]) => path.startsWith(`${collectionPath}/`) &&
                path.split("/").length === 2)
              .map(([, data]) => ({data: () => data})),
          };
        },
      };
      return query;
    },
    async runTransaction(callback) {
      const previous = transactionTail;
      let release;
      transactionTail = new Promise((resolve) => { release = resolve; });
      await previous;
      try {
        return await callback({
          get: (document) => document.get(),
          set(document, data, options) {
            const current = options?.merge === true ?
              documents.get(document.path) ?? {} : {};
            documents.set(document.path, {...current, ...data});
            writes.push({path: document.path, data});
          },
        });
      } finally {
        release();
      }
    },
  };
}
