const {createHash} = require("node:crypto");
const {Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const {trustedProfilePhotoUrl} = require("./trusted_media_url");
const {
  isEffectiveIdentityVerification,
  isEffectiveVehicleVerification,
  usesVerificationV1,
} = require("./verification_v1_policy");

const supportedCountries = new Set(["DE", "AT", "CH"]);
const maxSearchRadiusKm = 5;
const locationFreshnessMs = 60 * 60 * 1000;
const plateSearchWindowMs = 24 * 60 * 60 * 1000;
const plateSearchProbeCooldownMs = 24 * 60 * 60 * 1000;
const maxPlateSearchesPerWindow = 20;
const maxPlateTargetSearchesPerWindow = 8;
const coarseLocationCellSizeKm = 3;
const contactGrantLifetimeMs = 10 * 60 * 1000;

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function accountDeletionBlocksWrites(data) {
  return ["requested", "processing", "completed"].includes(
    safeString(data?.status),
  );
}

function normalizePlatePart(value) {
  return safeString(value)
    .toUpperCase()
    .replace(/[^A-ZÄÖÜ0-9]/gu, "");
}

function normalizePlateKey(value) {
  return normalizePlatePart(value);
}

function contactGrantId(requesterUserId, countryCode, vehicleId) {
  return createHash("sha256")
    .update(`${requesterUserId}\u0000${countryCode}\u0000${vehicleId}`)
    .digest("hex");
}

async function recordPlateContactGrant({
  firestore,
  requesterUserId,
  targetUserId,
  countryCode,
  vehicleId,
  plateKey,
  now,
}) {
  const reference = firestore.doc(
    `plate_contact_grants/${contactGrantId(
      requesterUserId,
      countryCode,
      vehicleId,
    )}`,
  );
  const targetDeletionReference = firestore.doc(
    `account_deletions/${targetUserId}`,
  );
  const requesterDeletionReference = firestore.doc(
    `account_deletions/${requesterUserId}`,
  );
  return firestore.runTransaction(async (transaction) => {
    const [targetDeletionSnapshot, requesterDeletionSnapshot] =
      await Promise.all([
        transaction.get(targetDeletionReference),
        transaction.get(requesterDeletionReference),
      ]);
    if (accountDeletionBlocksWrites(
      targetDeletionSnapshot.exists ? targetDeletionSnapshot.data() : null,
    ) || accountDeletionBlocksWrites(
      requesterDeletionSnapshot.exists ?
        requesterDeletionSnapshot.data() : null,
    )) {
      return false;
    }
    transaction.set(reference, {
      requesterUserId,
      targetUserId,
      countryCode,
      vehicleId,
      plateHash: createHash("sha256").update(plateKey).digest("hex"),
      createdAt: Timestamp.fromDate(now),
      expiresAt: Timestamp.fromDate(
        new Date(now.getTime() + contactGrantLifetimeMs),
      ),
    });
    return true;
  });
}

function dateFromValue(value) {
  if (value instanceof Date) {
    return value;
  }
  if (value != null && typeof value.toDate === "function") {
    return value.toDate();
  }
  if (value != null && typeof value.toMillis === "function") {
    return new Date(value.toMillis());
  }
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function hasValidCoordinates(latitude, longitude) {
  return Number.isFinite(latitude) &&
    Number.isFinite(longitude) &&
    latitude >= -90 && latitude <= 90 &&
    longitude >= -180 && longitude <= 180;
}

function distanceKmBetween(latitudeA, longitudeA, latitudeB, longitudeB) {
  const toRadians = (degrees) => degrees * Math.PI / 180;
  const earthRadiusKm = 6371;
  const latitudeDelta = toRadians(latitudeB - latitudeA);
  const longitudeDelta = toRadians(longitudeB - longitudeA);
  const startLatitude = toRadians(latitudeA);
  const endLatitude = toRadians(latitudeB);
  const haversine = Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(startLatitude) * Math.cos(endLatitude) *
    Math.sin(longitudeDelta / 2) ** 2;
  return earthRadiusKm * 2 * Math.atan2(
    Math.sqrt(haversine),
    Math.sqrt(1 - haversine),
  );
}

function coarseLocationCell(latitude, longitude) {
  const latitudeCellSize = coarseLocationCellSizeKm / 111.32;
  const latitudeCenter =
    (Math.floor(latitude / latitudeCellSize) + 0.5) * latitudeCellSize;
  const longitudeScale = Math.max(
    Math.cos(latitudeCenter * Math.PI / 180),
    0.2,
  );
  const longitudeCellSize = coarseLocationCellSizeKm /
    (111.32 * longitudeScale);
  const longitudeCenter =
    (Math.floor(longitude / longitudeCellSize) + 0.5) * longitudeCellSize;
  return {latitude: latitudeCenter, longitude: longitudeCenter};
}

function parseDisplayPlate(countryCode, displayPlate) {
  const normalized = safeString(displayPlate).toUpperCase();
  let match;

  if (countryCode === "DE") {
    match = normalized.match(
      /^([A-ZÄÖÜ]{1,3})-([A-ZÄÖÜ]{1,2})\s+([0-9]{1,4}[EH]?)$/u,
    );
    return match == null ? null : {
      region: match[1],
      letters: match[2],
      numbers: match[3],
    };
  }

  if (countryCode === "AT") {
    match = normalized.match(
      /^([A-ZÄÖÜ]{1,2})\s+([0-9]{1,5})\s+([A-ZÄÖÜ]{1,2})$/u,
    );
    return match == null ? null : {
      region: match[1],
      letters: match[3],
      numbers: match[2],
    };
  }

  match = normalized.match(/^([A-ZÄÖÜ]{1,2})\s+([0-9]{1,6})$/u);
  return match == null ? null : {
    region: match[1],
    letters: "",
    numbers: match[2],
  };
}

function platePartsFromData(countryCode, data, input) {
  const storedParts = {
    region: normalizePlatePart(data.region || data.plateRegion),
    letters: normalizePlatePart(data.letters || data.plateLetters),
    numbers: normalizePlatePart(data.numbers || data.plateNumbers),
  };
  const parsedDisplayPlate = parseDisplayPlate(
    countryCode,
    data.displayPlate,
  );
  const requestedParts = {
    region: normalizePlatePart(input?.region),
    letters: normalizePlatePart(input?.letters),
    numbers: normalizePlatePart(input?.numbers),
  };

  const candidates = [storedParts, parsedDisplayPlate, requestedParts];
  for (const candidate of candidates) {
    if (candidate == null || candidate.region.length === 0 ||
        candidate.numbers.length === 0) {
      continue;
    }
    if (countryCode !== "CH" && candidate.letters.length === 0) {
      continue;
    }
    return candidate;
  }
  return null;
}

function notFoundResult() {
  return {found: false};
}

function timestampMillis(value) {
  if (value != null && typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  return null;
}

async function reservePlateSearchProbe({
  firestore,
  requesterUserId,
  countryCode,
  plateKey,
  now,
}) {
  const probeId = createHash("sha256")
    .update(`${requesterUserId}\u0000${countryCode}\u0000${plateKey}`)
    .digest("hex");
  const limitReference = firestore.doc(
    `plate_search_rate_limits/${requesterUserId}`,
  );
  const probeReference = firestore.doc(`plate_search_probes/${probeId}`);
  const targetId = createHash("sha256")
    .update(`${countryCode}\u0000${plateKey}`)
    .digest("hex");
  const targetReference = firestore.doc(
    `plate_search_target_limits/${targetId}`,
  );
  const requesterDeletionReference = firestore.doc(
    `account_deletions/${requesterUserId}`,
  );
  const nowTimestamp = Timestamp.fromDate(now);
  const metadataExpiresAt = Timestamp.fromDate(
    new Date(now.getTime() + 2 * plateSearchWindowMs),
  );

  await firestore.runTransaction(async (transaction) => {
    const requesterDeletionSnapshot = await transaction.get(
      requesterDeletionReference,
    );
    const limitSnapshot = await transaction.get(limitReference);
    const probeSnapshot = await transaction.get(probeReference);
    const targetSnapshot = await transaction.get(targetReference);
    const limit = limitSnapshot.exists ? limitSnapshot.data() ?? {} : {};
    const probe = probeSnapshot.exists ? probeSnapshot.data() ?? {} : {};
    const target = targetSnapshot.exists ? targetSnapshot.data() ?? {} : {};
    if (accountDeletionBlocksWrites(
      requesterDeletionSnapshot.exists ?
        requesterDeletionSnapshot.data() : null,
    )) {
      throw new HttpsError(
        "failed-precondition",
        "Das Konto ist nicht verfügbar.",
      );
    }
    const windowStartedAtMs = timestampMillis(limit.windowStartedAt);
    const hasActiveWindow = windowStartedAtMs != null &&
      now.getTime() - windowStartedAtMs < plateSearchWindowMs;
    const currentCount = Number.isInteger(limit.searchCount) ?
      limit.searchCount :
      0;
    const searchCount = hasActiveWindow ? currentCount + 1 : 1;
    const lastSearchedAtMs = timestampMillis(probe.lastSearchedAt);
    const targetWindowStartedAtMs = timestampMillis(target.windowStartedAt);
    const hasActiveTargetWindow = targetWindowStartedAtMs != null &&
      now.getTime() - targetWindowStartedAtMs < plateSearchWindowMs;
    const currentTargetCount = Number.isInteger(target.searchCount) ?
      target.searchCount : 0;
    const targetSearchCount = hasActiveTargetWindow ?
      currentTargetCount + 1 : 1;

    if (lastSearchedAtMs != null &&
        now.getTime() - lastSearchedAtMs < plateSearchProbeCooldownMs) {
      throw new HttpsError(
        "resource-exhausted",
        "Dieses Kennzeichen kann erst später erneut gesucht werden.",
      );
    }
    if (searchCount > maxPlateSearchesPerWindow) {
      throw new HttpsError(
        "resource-exhausted",
        "Das tägliche Suchlimit ist erreicht.",
      );
    }
    if (targetSearchCount > maxPlateTargetSearchesPerWindow) {
      throw new HttpsError(
        "resource-exhausted",
        "Dieses Kennzeichen ist momentan nicht erneut suchbar.",
      );
    }

    transaction.set(limitReference, {
      userId: requesterUserId,
      windowStartedAt: hasActiveWindow ? limit.windowStartedAt : nowTimestamp,
      searchCount,
      updatedAt: nowTimestamp,
      expiresAt: metadataExpiresAt,
    }, {merge: true});
    transaction.set(probeReference, {
      requesterUserId,
      countryCode,
      plateHash: createHash("sha256").update(plateKey).digest("hex"),
      lastSearchedAt: nowTimestamp,
      updatedAt: nowTimestamp,
      expiresAt: metadataExpiresAt,
    }, {merge: true});
    transaction.set(targetReference, {
      plateHash: createHash("sha256")
        .update(`${countryCode}\u0000${plateKey}`)
        .digest("hex"),
      windowStartedAt: hasActiveTargetWindow ?
        target.windowStartedAt : nowTimestamp,
      searchCount: targetSearchCount,
      updatedAt: nowTimestamp,
      expiresAt: metadataExpiresAt,
    }, {merge: true});
  });
}

async function loadVisibilitySettings(firestore, userId) {
  try {
    const snapshot = await firestore
      .doc(`users/${userId}/settings/visibility`)
      .get();
    return snapshot.exists ? snapshot.data() || {} : {};
  } catch (_) {
    return {};
  }
}

async function loadEffectiveVerificationStatus(
  firestore,
  userId,
  vehicleId,
  now,
) {
  try {
    const [
      publicProfileSnapshot,
      identitySnapshot,
      verificationSnapshot,
      vehicleSnapshot,
    ] = await Promise.all([
      firestore.doc(`public_profiles/${userId}`).get(),
      firestore.doc(`users/${userId}/private_verification/identity`).get(),
      firestore.doc(`users/${userId}/vehicle_verifications/${vehicleId}`).get(),
      firestore.doc(`users/${userId}/vehicles/${vehicleId}`).get(),
    ]);
    const publicProfile = publicProfileSnapshot.exists ?
      publicProfileSnapshot.data() || {} : {};
    const identity = identitySnapshot.exists ? identitySnapshot.data() || {} : null;
    const verification = verificationSnapshot.exists ?
      verificationSnapshot.data() || {} : null;
    if (usesVerificationV1(identity, verification)) {
      return {
        identityVerified: isEffectiveIdentityVerification(identity, now),
        vehicleVerified: vehicleSnapshot.exists &&
          isEffectiveVehicleVerification({
            identity,
            verification,
            vehicle: vehicleSnapshot.data() || {},
            now,
          }),
      };
    }
    return {
      identityVerified:
        safeString(publicProfile.verificationStatus) === "verified" ||
        publicProfile.isVerified === true,
      vehicleVerified: true,
    };
  } catch (_) {
    return {identityVerified: false, vehicleVerified: false};
  }
}

async function searchPlateDocument({
  firestore,
  requesterUserId,
  input,
  now = new Date(),
}) {
  const userId = safeString(requesterUserId);
  if (userId.length === 0) {
    throw new HttpsError("unauthenticated", "Bitte melde dich neu an.");
  }

  const countryCode = safeString(input?.countryCode).toUpperCase();
  const plateKey = normalizePlateKey(input?.plate);
  const latitude = Number(input?.latitude);
  const longitude = Number(input?.longitude);
  const requestedRadiusKm = Number(input?.radiusKm);

  if (!supportedCountries.has(countryCode) || plateKey.length === 0 ||
      !hasValidCoordinates(latitude, longitude)) {
    throw new HttpsError(
      "invalid-argument",
      "Kennzeichen oder Standort sind ungültig.",
    );
  }

  await reservePlateSearchProbe({
    firestore,
    requesterUserId: userId,
    countryCode,
    plateKey,
    now,
  });

  const radiusKm = Number.isFinite(requestedRadiusKm) ?
    Math.min(Math.max(requestedRadiusKm, 1), maxSearchRadiusKm) :
    maxSearchRadiusKm;
  const plateSnapshot = await firestore
    .doc(`plates/${countryCode}_${plateKey}`)
    .get();

  if (!plateSnapshot.exists) {
    return notFoundResult();
  }

  const data = plateSnapshot.data() || {};
  const ownerUserId = safeString(data.ownerUserId);
  const vehicleId = safeString(data.vehicleId);
  const storedCountryCode = safeString(data.countryCode).toUpperCase();
  const storedPlateKey = normalizePlateKey(data.plateKey || data.normalizedPlate);
  if (ownerUserId.length === 0 || vehicleId.length === 0 ||
      ownerUserId === userId ||
      data.isActive !== true || data.isDeleted !== false ||
      data.isVerified !== true ||
      data.allowContactRequests !== true ||
      storedCountryCode !== countryCode || storedPlateKey !== plateKey) {
    return notFoundResult();
  }

  const [visibilitySettings, verificationStatus] = await Promise.all([
    loadVisibilitySettings(firestore, ownerUserId),
    loadEffectiveVerificationStatus(
      firestore,
      ownerUserId,
      vehicleId,
      now,
    ),
  ]);
  const settingsAllowContactRequests =
    visibilitySettings.allowContactRequests !== false;
  const settingsPlateSearchVisibility =
    safeString(visibilitySettings.plateSearchVisibility) || "contacts";
  const settingsShowVehicle = visibilitySettings.showVehicle !== false;
  const settingsShowPlate = visibilitySettings.showPlate !== false;
  if (!settingsAllowContactRequests ||
      !verificationStatus.vehicleVerified ||
      settingsPlateSearchVisibility === "onlyMe") {
    return notFoundResult();
  }

  const locationUpdatedAt = dateFromValue(data.locationUpdatedAt);
  const storedLatitude = Number(data.latitude);
  const storedLongitude = Number(data.longitude);
  if (locationUpdatedAt == null ||
      now.getTime() - locationUpdatedAt.getTime() > locationFreshnessMs ||
      locationUpdatedAt.getTime() > now.getTime() + 60 * 1000 ||
      !hasValidCoordinates(storedLatitude, storedLongitude)) {
    return notFoundResult();
  }

  const coarseTargetLocation = coarseLocationCell(
    storedLatitude,
    storedLongitude,
  );
  const distanceKm = distanceKmBetween(
    latitude,
    longitude,
    coarseTargetLocation.latitude,
    coarseTargetLocation.longitude,
  );
  if (distanceKm > radiusKm) {
    return notFoundResult();
  }

  const parts = platePartsFromData(countryCode, data, input);
  if (parts == null) {
    return notFoundResult();
  }

  const plateDisplayMode = safeString(data.plateDisplayMode) || "full";
  const vehicleIsPublic = data.showOnPublicProfile !== false;
  const showFullPlate = settingsShowPlate && plateDisplayMode === "full";
  const showAnyPlate = settingsShowPlate && plateDisplayMode !== "hidden";
  const grantRecorded = await recordPlateContactGrant({
    firestore,
    requesterUserId: userId,
    targetUserId: ownerUserId,
    countryCode,
    vehicleId,
    plateKey,
    now,
  });
  if (!grantRecorded) return notFoundResult();
  return {
    found: true,
    targetUid: ownerUserId,
    displayName: safeString(data.displayName) || null,
    profilePhotoUrl: trustedProfilePhotoUrl(
      data.profilePhotoUrl || data.photoUrl,
      ownerUserId,
    ),
    isVerified: verificationStatus.identityVerified,
    vehicleId,
    plateKey,
    displayPlate: showAnyPlate ?
      (plateDisplayMode === "shortened" ?
        safeString(data.plateDisplayLabel) || null :
        safeString(data.displayPlate) || plateKey) : null,
    countryCode,
    region: showFullPlate ? parts.region : null,
    letters: showFullPlate ? parts.letters : null,
    numbers: showFullPlate ? parts.numbers : null,
    vehicleBrand: settingsShowVehicle && vehicleIsPublic ?
      safeString(data.vehicleBrand) || null :
      null,
    vehicleModel: settingsShowVehicle && vehicleIsPublic ?
      safeString(data.vehicleModel) || null :
      null,
    vehicleColor: settingsShowVehicle && vehicleIsPublic ?
      safeString(data.vehicleColor) || null :
      null,
    vehicleLabel: settingsShowVehicle && vehicleIsPublic ?
      safeString(data.vehicleLabel) || null :
      null,
  };
}

module.exports = {
  coarseLocationCell,
  contactGrantId,
  distanceKmBetween,
  maxPlateTargetSearchesPerWindow,
  normalizePlateKey,
  parseDisplayPlate,
  recordPlateContactGrant,
  reservePlateSearchProbe,
  searchPlateDocument,
};
