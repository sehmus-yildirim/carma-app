const assert = require('node:assert/strict');
const test = require('node:test');

const {
  expectedDocumentPath,
  inspectJpeg,
  inspectPng,
  isJpegHeader,
  isPngHeader,
  normalizeReviewInput,
  normalizeSubmissionInput,
  normalizeVehicleRelationship,
  plateDocumentId,
  requiredDocumentKeys,
  requiredExpirationKeys,
  submitProfileVerification,
  validateDocumentExpirations,
  validateStoredDocuments,
} = require('./profile_verification');

test('accepts only the fixed six-page submission contract', () => {
  assert.deepEqual(normalizeSubmissionInput('user-1', {
    requestId: 'user-1',
    vehicleId: 'vehicle-1',
    vehicleRelationship: 'authorizedUser',
    authorizationConfirmed: true,
    consentVersion: 'verification-consent-1.0',
  }), {
    requestId: 'user-1',
    vehicleId: 'vehicle-1',
    vehicleRelationship: 'authorizedUser',
  });
  assert.throws(() => normalizeSubmissionInput('user-1', {
    requestId: 'user-2',
    vehicleId: 'vehicle-1',
    vehicleRelationship: 'owner',
    authorizationConfirmed: true,
    consentVersion: 'verification-consent-1.0',
  }), /eindeutig zugeordnet/);
  assert.throws(() => normalizeSubmissionInput('user-1', {
    requestId: 'user-1',
    vehicleId: 'vehicle-1',
    vehicleRelationship: 'owner',
    authorizationConfirmed: false,
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
    consentVersion: 'verification-consent-1.0',
  }), {
    requestId: 'user-1',
    vehicleId: 'vehicle-1',
    vehicleRelationship: 'leasingCompany',
  });
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

  function reference(documentPath) {
    return {
      path: documentPath,
      async get() {
        const value = documents.get(documentPath);
        return {exists: value != null, data: () => value};
      },
      collection(collectionName) {
        return {
          doc(documentId) {
            return reference(`${documentPath}/${collectionName}/${documentId}`);
          },
        };
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

test('requires current expiration dates for identity and driver license', () => {
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
  assert.throws(() => validateDocumentExpirations({
    identity: valid.identity,
  }, now), /gültiges Ablaufdatum/);
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
      [paths.driverLicenseBack]: {
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
