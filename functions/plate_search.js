const {HttpsError} = require("firebase-functions/v2/https");

const supportedCountries = new Set(["DE", "AT", "CH"]);
const maxSearchRadiusKm = 5;
const locationFreshnessMs = 60 * 60 * 1000;

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function normalizePlatePart(value) {
  return safeString(value)
    .toUpperCase()
    .replace(/[^A-ZÄÖÜ0-9]/gu, "");
}

function normalizePlateKey(value) {
  return normalizePlatePart(value);
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
      data.allowContactRequests !== true ||
      storedCountryCode !== countryCode || storedPlateKey !== plateKey) {
    return notFoundResult();
  }

  const visibilitySettings = await loadVisibilitySettings(
    firestore,
    ownerUserId,
  );
  const settingsAllowContactRequests =
    visibilitySettings.allowContactRequests !== false;
  const settingsPlateSearchVisibility =
    safeString(visibilitySettings.plateSearchVisibility) || "contacts";
  const settingsShowVehicle = visibilitySettings.showVehicle !== false;
  const settingsShowPlate = visibilitySettings.showPlate !== false;
  if (!settingsAllowContactRequests ||
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

  const distanceKm = distanceKmBetween(
    latitude,
    longitude,
    storedLatitude,
    storedLongitude,
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
  return {
    found: true,
    targetUid: ownerUserId,
    displayName: safeString(data.displayName) || null,
    profilePhotoUrl:
      safeString(data.profilePhotoUrl || data.photoUrl) || null,
    isVerified: safeString(data.verificationStatus) === "verified" ||
      data.isVerified === true,
    distanceKm: Math.round(distanceKm * 100) / 100,
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
  distanceKmBetween,
  normalizePlateKey,
  parseDisplayPlate,
  searchPlateDocument,
};
