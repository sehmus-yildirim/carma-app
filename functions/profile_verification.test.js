const assert = require('node:assert/strict');
const test = require('node:test');

const {
  createVerificationExpiryReminders,
  expectedDocumentPath,
  expireVerifiedRequests,
  inspectJpeg,
  inspectPng,
  isJpegHeader,
  isPngHeader,
  normalizeReviewInput,
  normalizeSubmissionInput,
  normalizeVehicleRelationship,
  plateDocumentId,
  reminderMilestone,
  requiredDocumentKeys,
  requiredExpirationKeys,
  requiredKeysForIdentityType,
  submissionGroupsForDraft,
  submitProfileVerification,
  validateDocumentExpirations,
  validateStoredDocuments,
  verificationStagesFromStatuses,
} = require('./profile_verification');

test('accepts the confirmed vehicle and identity document contract', () => {
  assert.deepEqual(normalizeSubmissionInput('user-1', {
    requestId: 'user-1',
    vehicleId: 'vehicle-1',
    vehicleRelationship: 'authorizedUser',
    authorizationConfirmed: true,
    vehicleAssignmentConfirmed: true,
    identityDocumentType: 'identityCard',
    consentVersion: 'verification-consent-1.0',
  }), {
    requestId: 'user-1',
    vehicleId: 'vehicle-1',
    vehicleRelationship: 'authorizedUser',
    identityDocumentType: 'identityCard',
    requestedDocumentGroups: ['identity', 'vehicle'],
  });
  assert.throws(() => normalizeSubmissionInput('user-1', {
    requestId: 'user-2',
    vehicleId: 'vehicle-1',
    vehicleRelationship: 'owner',
    authorizationConfirmed: true,
    vehicleAssignmentConfirmed: true,
    consentVersion: 'verification-consent-1.0',
  }), /eindeutig zugeordnet/);
  assert.throws(() => normalizeSubmissionInput('user-1', {
    requestId: 'user-1',
    vehicleId: 'vehicle-1',
    vehicleRelationship: 'owner',
    authorizationConfirmed: false,
    vehicleAssignmentConfirmed: true,
    consentVersion: 'verification-consent-1.0',
  }), /Berechtigung/);
});

test('normalizes legacy vehicle relationships without weakening validation', () => {
  assert.equal(normalizeVehicleRelationship('leasingCompanyFamily'),
    'leasingCompany');
  assert.deepEqual(normalizeSubmissionInput('user-1', {
    requestId: 'user-1',
    vehicleId: 'vehicle-1',
    vehicleRelationship: 'leasingCompanyFamily',
    authorizationConfirmed: true,
    vehicleAssignmentConfirmed: true,
    identityDocumentType: 'identityCard',
    consentVersion: 'verification-consent-1.0',
  }), {
    requestId: 'user-1',
    vehicleId: 'vehicle-1',
    vehicleRelationship: 'leasingCompany',
    identityDocumentType: 'identityCard',
    requestedDocumentGroups: ['identity', 'vehicle'],
  });
});

test('uses document-type-specific pages and rejects unknown identity types', () => {
  assert.deepEqual(requiredKeysForIdentityType('passport'), [
    'identityFront',
    'vehicleFront',
    'vehicleBack',
  ]);
  assert.equal(requiredKeysForIdentityType('identityCard').length, 4);
  assert.throws(() => normalizeSubmissionInput('user-1', {
    requestId: 'user-1',
    vehicleId: 'vehicle-1',
    vehicleRelationship: 'owner',
    authorizationConfirmed: true,
    vehicleAssignmentConfirmed: true,
    identityDocumentType: 'studentCard',
    consentVersion: 'verification-consent-1.0',
  }), /gültigen Identitätsnachweis/);
});

test('submits only complete uploaded groups during targeted resubmission', () => {
  const draft = {
    documentStatuses: {
      identityFront: 'uploaded',
      identityBack: 'uploaded',
      vehicleFront: 'rejected',
      vehicleBack: 'rejected',
    },
  };
  assert.deepEqual(
    submissionGroupsForDraft(draft, 'identityCard'),
    ['identity'],
  );
  draft.documentStatuses.identityBack = 'missing';
  assert.deepEqual(submissionGroupsForDraft(draft, 'identityCard'), []);
});

test('keeps identity and vehicle verification stages independent', () => {
  const vehicleOnly = verificationStagesFromStatuses({
    vehicleFront: 'verified',
    vehicleBack: 'verified',
  }, 'identityCard');
  assert.deepEqual(vehicleOnly, {identity: false, vehicle: true});

  const identityOnly = verificationStagesFromStatuses({
    identityFront: 'verified',
    identityBack: 'verified',
  }, 'identityCard');
  assert.deepEqual(identityOnly, {identity: true, vehicle: false});

  assert.deepEqual(verificationStagesFromStatuses({
    identityFront: 'verified',
    identityBack: 'verified',
    vehicleFront: 'verified',
    vehicleBack: 'verified',
  }, 'identityCard'), {identity: true, vehicle: true});
});

test('maps expiry reminder windows to 30, 14 and 3 day milestones', () => {
  assert.equal(reminderMilestone(30), 30);
  assert.equal(reminderMilestone(29), 30);
  assert.equal(reminderMilestone(14), 14);
  assert.equal(reminderMilestone(4), 14);
  assert.equal(reminderMilestone(3), 3);
  assert.equal(reminderMilestone(1), 3);
  assert.equal(reminderMilestone(0), null);
  assert.equal(reminderMilestone(31), null);
});

test('validates review decisions and meaningful rejection reasons', () => {
  assert.deepEqual(normalizeReviewInput({
    requestId: 'request-1',
    decision: 'verified',
  }), {requestId: 'request-1', decision: 'verified', reason: ''});
  assert.throws(() => normalizeReviewInput({
    requestId: 'request-1',
    decision: 'rejected',
    reason: 'nein',
  }), /Ablehnungsgrund/);
});

test('builds canonical private paths and canonical plate IDs', () => {
  assert.equal(
    expectedDocumentPath('user-1', 'identityFront'),
    'profile_documents/user-1/identityFront/identityFront.png',
  );
  assert.equal(plateDocumentId({
    countryCode: 'de',
    plateRegion: 'hh',
    plateLetters: 'cr',
    plateNumbers: '2026',
  }), 'DE_HHCR2026');
});

test('recognizes JPEG magic bytes instead of trusting the extension', () => {
  assert.equal(isJpegHeader(Buffer.from([0xff, 0xd8, 0xff, 0x00])), true);
  assert.equal(isJpegHeader(Buffer.from([0x89, 0x50, 0x4e, 0x47])), false);
});

test('validates PNG structure, dimensions and removed EXIF metadata', () => {
  const valid = validPng();
  assert.equal(isPngHeader(valid), true);
  assert.deepEqual(inspectPng(valid), {
    valid: true,
    hasExif: false,
    width: 1600,
    height: 1000,
  });
  assert.equal(inspectPng(validPng({withExif: true})).hasExif, true);
  assert.equal(inspectPng(Buffer.from([0x89, 0x50, 0x4e])).valid, false);
});

test('validates JPEG structure, dimensions and removed EXIF metadata', () => {
  const valid = validJpeg();
  assert.deepEqual(inspectJpeg(valid), {
    valid: true,
    hasExif: false,
    width: 1600,
    height: 1000,
  });
  assert.equal(inspectJpeg(Buffer.from([0xff, 0xd8, 0xff])).valid, false);
  assert.equal(inspectJpeg(validJpeg({withExif: true})).hasExif, true);
});

function validJpeg({withExif = false} = {}) {
  const segments = [Buffer.from([0xff, 0xd8])];
  if (withExif) {
    segments.push(Buffer.concat([
      Buffer.from([0xff, 0xe1, 0x00, 0x08]),
      Buffer.from('Exif\0\0', 'binary'),
    ]));
  }
  segments.push(
    Buffer.from([
      0xff, 0xc0, 0x00, 0x0b, 0x08,
      0x03, 0xe8, 0x06, 0x40,
      0x01, 0x01, 0x11, 0x00,
    ]),
    Buffer.from([
      0xff, 0xda, 0x00, 0x08,
      0x01, 0x01, 0x00, 0x00, 0x3f, 0x00,
      0x11, 0x22, 0x33,
    ]),
    Buffer.from([0xff, 0xd9]),
  );
  return Buffer.concat(segments);
}

function pngChunk(type, data = Buffer.alloc(0)) {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  return Buffer.concat([
    length,
    Buffer.from(type, 'ascii'),
    data,
    Buffer.alloc(4),
  ]);
}

function validPng({withExif = false} = {}) {
  const header = Buffer.alloc(13);
  header.writeUInt32BE(1600, 0);
  header.writeUInt32BE(1000, 4);
  header[8] = 8;
  header[9] = 6;
  const chunks = [
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    pngChunk('IHDR', header),
  ];
  if (withExif) chunks.push(pngChunk('eXIf', Buffer.from([1, 2, 3])));
  chunks.push(pngChunk('IDAT', Buffer.from([1])), pngChunk('IEND'));
  return Buffer.concat(chunks);
}

function fakeBucket(files) {
  return {
    file(filePath) {
      const value = files[filePath];
      return {
        async exists() {
          return [value != null];
        },
        async getMetadata() {
          return [value?.metadata ?? {}];
        },
        async download() {
          return [value?.content ?? Buffer.alloc(0)];
        },
      };
    },
  };
}

function fakeFirestore(initialDocuments) {
  const documents = new Map(Object.entries(initialDocuments));
  const writes = [];
  let generatedDocumentId = 0;

  function reference(documentPath) {
    return {
      id: documentPath.split('/').at(-1),
      path: documentPath,
      async get() {
        const value = documents.get(documentPath);
        return {exists: value != null, data: () => value};
      },
      collection(collectionName) {
        return {
          doc(documentId) {
            const id = documentId ?? `generated-${++generatedDocumentId}`;
            return reference(`${documentPath}/${collectionName}/${id}`);
          },
        };
      },
      async update(data) {
        if (!documents.has(documentPath)) {
          throw new Error(`missing document: ${documentPath}`);
        }
        write(this, data, true);
      },
    };
  }

  function write(document, data, merge) {
    const current = merge ? documents.get(document.path) ?? {} : {};
    documents.set(document.path, {...current, ...data});
    writes.push({path: document.path, data});
  }

  return {
    documents,
    writes,
    doc: reference,
    collection(collectionPath) {
      const filters = [];
      let queryLimit = Number.POSITIVE_INFINITY;
      const query = {
        where(field, operator, expected) {
          filters.push({field, operator, expected});
          return query;
        },
        limit(value) {
          queryLimit = value;
          return query;
        },
        async get() {
          const prefix = `${collectionPath}/`;
          const docs = [...documents.entries()]
              .filter(([documentPath]) => {
                if (!documentPath.startsWith(prefix)) return false;
                return !documentPath.slice(prefix.length).includes('/');
              })
              .filter(([, data]) => filters.every(({field, operator, expected}) => {
                if (operator !== '<=') throw new Error(`unsupported: ${operator}`);
                return valueMillis(data[field]) <= valueMillis(expected);
              }))
              .slice(0, queryLimit)
              .map(([documentPath, data]) => ({
                id: documentPath.split('/').at(-1),
                ref: reference(documentPath),
                data: () => data,
              }));
          return {docs, size: docs.length};
        },
      };
      return query;
    },
    async runTransaction(callback) {
      return callback({
        get: (document) => document.get(),
        set(document, data, options) {
          write(document, data, options?.merge === true);
        },
        update(document, data) {
          if (!documents.has(document.path)) {
            throw new Error(`missing document: ${document.path}`);
          }
          write(document, data, true);
        },
      });
    },
  };
}

function valueMillis(value) {
  if (typeof value?.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  return Number(value);
}

function validVerificationFiles(userId) {
  const validFile = {
    metadata: {contentType: 'image/png', size: '2048'},
    content: validPng(),
  };
  return Object.fromEntries(requiredPaths(userId)
    .map((filePath) => [filePath, validFile]));
}

function requiredPaths(userId) {
  return requiredDocumentKeys.map((key) => expectedDocumentPath(userId, key));
}

function verificationDocuments(userId, relationship = 'authorizedUser') {
  const paths = Object.fromEntries(requiredDocumentKeys
    .map((key) => [key, expectedDocumentPath(userId, key)]));
  return {
    [`verification_requests/${userId}`]: {
      requestId: userId,
      userId,
      status: 'draft',
      identityDocumentType: 'identityCard',
      documentStoragePaths: paths,
      documentStatuses: Object.fromEntries(
          requiredDocumentKeys.map((key) => [key, 'uploaded']),
      ),
      documentExpiresAt: {
        identity: new Date('2030-08-14T00:00:00Z'),
        driverLicense: new Date('2031-08-14T00:00:00Z'),
      },
      vehicleId: 'vehicle-1',
      vehicleRelationship: relationship,
      vehicleAssignmentConfirmed: true,
    },
    [`users/${userId}/profiles/main`]: {
      uid: userId,
      firstName: 'Mara',
      lastName: 'Beispiel',
      displayName: 'Mara Beispiel',
      birthDate: new Date('1990-01-01T00:00:00Z'),
      personalDataLocked: true,
      verificationStatus: 'unverified',
    },
    [`users/${userId}/vehicles/vehicle-1`]: {
      id: 'vehicle-1',
      ownerUserId: userId,
      brand: 'Mercedes-Benz',
      model: 'GLS',
      color: 'Weiß',
      countryCode: 'DE',
      plateRegion: 'FD',
      plateLetters: 'RT',
      plateNumbers: '2918',
      status: 'active',
      useRelationship: relationship,
      verificationStatus: 'evidenceMissing',
      verificationLocked: false,
    },
  };
}

test('requires a current expiration date only for identity evidence', () => {
  const now = new Date('2026-08-14T08:00:00Z');
  const valid = Object.fromEntries(requiredExpirationKeys.map((key, index) => [
    key,
    new Date(`${2030 + index}-08-14T00:00:00Z`),
  ]));
  assert.deepEqual(validateDocumentExpirations(valid, now), valid);
  assert.throws(() => validateDocumentExpirations({
    ...valid,
    identity: new Date('2025-08-14T00:00:00Z'),
  }, now), /gültiges Ablaufdatum/);
  assert.throws(
    () => validateDocumentExpirations({}, now),
    /gültiges Ablaufdatum/,
  );
});

test('checks all stored pages, mime type, size and image content', async () => {
  const paths = Object.fromEntries(requiredDocumentKeys
    .map((key) => [key, expectedDocumentPath('user-1', key)]));
  const validFile = {
    metadata: {contentType: 'image/png', size: '2048'},
    content: validPng(),
  };
  await validateStoredDocuments({
    bucket: fakeBucket(Object.fromEntries(requiredDocumentKeys
      .map((key) => [paths[key], validFile]))),
    userId: 'user-1',
    paths,
  });

  await assert.rejects(validateStoredDocuments({
    bucket: fakeBucket({
      ...Object.fromEntries(requiredDocumentKeys
        .map((key) => [paths[key], validFile])),
      [paths.vehicleBack]: {
        metadata: {contentType: 'image/png', size: '2048'},
        content: Buffer.from([0x89, 0x50, 0x4e]),
      },
    }),
    userId: 'user-1',
    paths,
  }), /gültige Bilddatei/);

  await assert.rejects(validateStoredDocuments({
    bucket: fakeBucket({
      ...Object.fromEntries(requiredDocumentKeys
        .map((key) => [paths[key], validFile])),
      [paths.vehicleBack]: {
        metadata: {contentType: 'image/png', size: '2048'},
        content: validPng({withExif: true}),
      },
    }),
    userId: 'user-1',
    paths,
  }), /Metadaten/);
});

test('submits profile and vehicle verification atomically', async () => {
  const userId = 'user-atomic';
  const firestore = fakeFirestore(verificationDocuments(userId));
  const result = await submitProfileVerification({
    firestore,
    bucket: fakeBucket(validVerificationFiles(userId)),
    authContext: {uid: userId},
    input: {
      requestId: userId,
      vehicleId: 'vehicle-1',
      vehicleRelationship: 'authorizedUser',
      authorizationConfirmed: true,
      vehicleAssignmentConfirmed: true,
      identityDocumentType: 'identityCard',
      consentVersion: 'verification-consent-1.0',
    },
    now: new Date('2026-08-14T08:00:00Z'),
  });

  assert.equal(result.status, 'pending');
  assert.equal(result.idempotent, false);
  assert.equal(firestore.documents.get(
    `verification_requests/${userId}`,
  ).status, 'pending');
  assert.equal(firestore.documents.get(
    `verification_requests/${userId}`,
  ).verificationExpiresAt.getTime(), new Date(
    '2030-08-14T00:00:00Z',
  ).getTime());
  assert.equal(firestore.documents.get(
    `users/${userId}/profiles/main`,
  ).verificationStatus, 'pending');
  assert.equal(firestore.documents.get(
    `users/${userId}/vehicles/vehicle-1`,
  ).verificationLocked, true);
  assert.equal([...firestore.documents.keys()].filter((path) =>
    path.startsWith(`verification_requests/${userId}/history/`)).length, 1);
});

test('rejects a relationship that differs from the selected vehicle', async () => {
  const userId = 'user-mismatch';
  const firestore = fakeFirestore(verificationDocuments(userId, 'owner'));

  await assert.rejects(submitProfileVerification({
    firestore,
    bucket: fakeBucket(validVerificationFiles(userId)),
    authContext: {uid: userId},
    input: {
      requestId: userId,
      vehicleId: 'vehicle-1',
      vehicleRelationship: 'authorizedUser',
      authorizationConfirmed: true,
      vehicleAssignmentConfirmed: true,
      identityDocumentType: 'identityCard',
      consentVersion: 'verification-consent-1.0',
    },
    now: new Date('2026-08-14T08:00:00Z'),
  }), /stimmt nicht mit dem Fahrzeug überein/);
  assert.equal(firestore.writes.length, 0);
});

test('repeated identical submission stays idempotent', async () => {
  const userId = 'user-idempotent';
  const firestore = fakeFirestore(verificationDocuments(userId));
  const parameters = {
    firestore,
    bucket: fakeBucket(validVerificationFiles(userId)),
    authContext: {uid: userId},
    input: {
      requestId: userId,
      vehicleId: 'vehicle-1',
      vehicleRelationship: 'authorizedUser',
      authorizationConfirmed: true,
      vehicleAssignmentConfirmed: true,
      identityDocumentType: 'identityCard',
      consentVersion: 'verification-consent-1.0',
    },
    now: new Date('2026-08-14T08:00:00Z'),
  };

  await submitProfileVerification(parameters);
  const writeCount = firestore.writes.length;
  const repeated = await submitProfileVerification(parameters);

  assert.equal(repeated.idempotent, true);
  assert.equal(firestore.writes.length, writeCount);
  assert.equal([...firestore.documents.keys()].filter((path) =>
    path.startsWith(`verification_requests/${userId}/history/`)).length, 1);
});

test('creates 30, 14 and 3 day reminders once per document milestone', async () => {
  const userId = 'user-reminders';
  const expiration = new Date('2026-09-14T08:00:00Z');
  const firestore = fakeFirestore({
    [`verification_requests/${userId}`]: {
      requestId: userId,
      userId,
      status: 'verified',
      verificationExpiresAt: expiration,
      documentExpiresAt: {
        identity: expiration,
        driverLicense: new Date('2030-01-01T00:00:00Z'),
      },
    },
  });

  const first = await createVerificationExpiryReminders({
    firestore,
    now: new Date('2026-08-15T08:00:00Z'),
  });
  const repeated = await createVerificationExpiryReminders({
    firestore,
    now: new Date('2026-08-15T08:00:00Z'),
  });
  const secondMilestone = await createVerificationExpiryReminders({
    firestore,
    now: new Date('2026-09-01T08:00:00Z'),
  });
  const finalMilestone = await createVerificationExpiryReminders({
    firestore,
    now: new Date('2026-09-11T08:00:00Z'),
  });

  assert.deepEqual(first, {created: 1, failed: 0, hasMore: false});
  assert.deepEqual(repeated, {created: 0, failed: 0, hasMore: false});
  assert.equal(secondMilestone.created, 1);
  assert.equal(finalMilestone.created, 1);
  const notifications = [...firestore.documents.entries()].filter(([path]) =>
    path.startsWith(`users/${userId}/verification_notifications/`));
  assert.equal(notifications.length, 3);
  assert.deepEqual(notifications.map(([, data]) => data.reminderMilestone), [
    30,
    14,
    3,
  ]);
  assert.equal(notifications.some(([, data]) =>
    JSON.stringify(data).includes('profile_documents/')), false);
});

test('continues reminder batches after an isolated transaction failure', async () => {
  const expiration = new Date('2026-09-14T08:00:00Z');
  const request = (userId) => ({
    requestId: userId,
    userId,
    status: 'verified',
    verificationExpiresAt: expiration,
    documentExpiresAt: {
      identity: expiration,
      driverLicense: new Date('2030-01-01T00:00:00Z'),
    },
  });
  const firestore = fakeFirestore({
    'verification_requests/failing-user': request('failing-user'),
    'verification_requests/healthy-user': request('healthy-user'),
  });
  const runTransaction = firestore.runTransaction.bind(firestore);
  let transactionCount = 0;
  firestore.runTransaction = async (callback) => {
    transactionCount += 1;
    if (transactionCount === 1) throw new Error('isolated test failure');
    return runTransaction(callback);
  };

  const result = await createVerificationExpiryReminders({
    firestore,
    now: new Date('2026-08-15T08:00:00Z'),
  });

  assert.deepEqual(result, {created: 1, failed: 1, hasMore: false});
  assert.equal([...firestore.documents.keys()].some((path) =>
    path.startsWith(
        'users/healthy-user/verification_notifications/expiry_identity_',
    )), true);
});

test('expired identity preserves a confirmed vehicle', async () => {
  const userId = 'user-expired';
  const now = new Date('2026-08-15T08:00:00Z');
  const requestPath = `verification_requests/${userId}`;
  const firestore = fakeFirestore({
    [requestPath]: {
      requestId: userId,
      userId,
      status: 'verified',
      identityDocumentType: 'identityCard',
      vehicleId: 'vehicle-1',
      countryCode: 'DE',
      plateRegion: 'HH',
      plateLetters: 'CR',
      plateNumbers: '2026',
      verificationExpiresAt: now,
      documentExpiresAt: {
        identity: now,
      },
      documentStatuses: Object.fromEntries(
          requiredDocumentKeys.map((key) => [key, 'verified']),
      ),
      documentRejectionReasons: {},
    },
    [`users/${userId}/profiles/main`]: {verificationStatus: 'verified'},
    [`public_profiles/${userId}`]: {verificationStatus: 'verified'},
    [`users/${userId}/vehicles/vehicle-1`]: {
      verificationStatus: 'verified',
      verificationLocked: true,
    },
    [`public_profiles/${userId}/vehicles/vehicle-1`]: {
      verificationStatus: 'verified',
    },
    'plates/DE_HHCR2026': {
      ownerUserId: userId,
      verificationStatus: 'verified',
    },
  });

  const result = await expireVerifiedRequests({firestore, now});

  assert.deepEqual(result, {expired: 1, failed: 0, hasMore: false});
  const request = firestore.documents.get(requestPath);
  assert.equal(request.status, 'expired');
  assert.equal(request.documentStatuses.identityFront, 'expired');
  assert.equal(request.documentStatuses.identityBack, 'expired');
  assert.equal(firestore.documents.get(
      `public_profiles/${userId}`,
  ).verificationStatus, 'expired');
  assert.equal(firestore.documents.get(
      `users/${userId}/vehicles/vehicle-1`,
  ).verificationLocked, true);
  assert.equal(firestore.documents.get(
      'plates/DE_HHCR2026',
  ).verificationStatus, 'verified');
});
