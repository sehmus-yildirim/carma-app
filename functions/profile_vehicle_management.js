const {HttpsError} = require("firebase-functions/v2/https");

const supportedCountries = new Set(["DE", "AT", "CH"]);
const supportedStatuses = new Set([
  "active",
  "modification",
  "repair",
  "seasonal",
  "deregistered",
  "sold",
  "noLongerOwned",
]);
const activeVehicleStatuses = new Set([
  "active",
  "modification",
  "repair",
  "seasonal",
]);
const supportedRelationships = new Set([
  "owner",
  "leasingCompany",
  "authorizedUser",
]);
const supportedVehicleTypes = new Set([
  "passengerCar",
  "motorcycle",
  "transporter",
]);
const supportedPlateTypes = new Set([
  "standard",
  "electric",
  "historic",
  "seasonal",
]);
const supportedPlateDisplayModes = new Set([
  "full",
  "shortened",
  "hidden",
]);
const supportedProfileHighlights = new Set([
  "plate",
  "color",
  "mileage",
  "status",
  "ownedSince",
]);

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function nullableString(value, maxLength) {
  const normalized = safeString(value);
  if (normalized.length === 0) return null;
  if (normalized.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      "Eine Fahrzeugangabe ist zu lang.",
    );
  }
  return normalized;
}

function nullableUppercaseString(value, maxLength) {
  const normalized = nullableString(value, maxLength);
  return normalized == null ? null : normalized.toUpperCase();
}

function normalizePlatePart(value) {
  return safeString(value)
    .toUpperCase()
    .replace(/[^A-ZÄÖÜ0-9]/gu, "");
}

function normalizeVehicleId(value) {
  const vehicleId = safeString(value);
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(vehicleId)) {
    throw new HttpsError(
      "invalid-argument",
      "Das Fahrzeug konnte nicht eindeutig bestimmt werden.",
    );
  }
  return vehicleId;
}

function normalizeEnum(value, allowed, fallback, errorMessage) {
  const normalized = safeString(value) || fallback;
  if (!allowed.has(normalized)) {
    throw new HttpsError("invalid-argument", errorMessage);
  }
  return normalized;
}

function normalizeOptionalInteger(value, {minimum, maximum, label}) {
  if (value == null || value === "") return null;
  const number = Number(value);
  if (!Number.isInteger(number) || number < minimum || number > maximum) {
    throw new HttpsError(
      "invalid-argument",
      `${label} ist ungültig.`,
    );
  }
  return number;
}

function normalizeOptionalDate(value, label) {
  if (value == null || value === "") return null;
  const milliseconds = Number(value);
  const date = new Date(milliseconds);
  if (!Number.isFinite(milliseconds) || Number.isNaN(date.getTime())) {
    throw new HttpsError("invalid-argument", `${label} ist ungültig.`);
  }
  if (date.getUTCFullYear() < 1886 || date.getTime() > Date.now()) {
    throw new HttpsError("invalid-argument", `${label} ist ungültig.`);
  }
  return date;
}

function normalizeStringList(value, {
  allowed,
  maximum = 40,
  caseInsensitive = false,
  rejectExcess = false,
  label = "Einträge",
}) {
  if (!Array.isArray(value)) return [];
  const result = [];
  const seen = new Set();
  for (const item of value) {
    const normalized = safeString(item);
    if (normalized.length === 0 || normalized.length > 120) continue;
    if (allowed != null && !allowed.has(normalized)) continue;
    const key = caseInsensitive ? normalized.toLocaleLowerCase("de-DE") :
      normalized;
    if (seen.has(key)) continue;
    if (result.length >= maximum) {
      if (rejectExcess) {
        throw new HttpsError(
          "invalid-argument",
          `Maximal ${maximum} ${label} sind möglich.`,
        );
      }
      break;
    }
    seen.add(key);
    result.push(normalized);
  }
  return result;
}

function validatePlateParts({
  countryCode,
  plateRegion,
  plateLetters,
  plateNumbers,
  plateType,
  seasonStartMonth,
  seasonEndMonth,
}) {
  if (countryCode !== "DE" && ["electric", "historic"].includes(plateType)) {
    throw new HttpsError(
      "invalid-argument",
      "Dieser Kennzeichentyp ist nur für deutsche Kennzeichen verfügbar.",
    );
  }
  const regionLimits = {DE: 3, AT: 2, CH: 2};
  if (!new RegExp(`^[A-ZÄÖÜ]{1,${regionLimits[countryCode]}}$`, "u")
    .test(plateRegion)) {
    throw new HttpsError(
      "invalid-argument",
      "Zulassungsregion, Bezirk oder Kanton ist ungültig.",
    );
  }

  if (countryCode === "CH") {
    if (plateLetters.length !== 0 || !/^[0-9]{1,6}$/.test(plateNumbers)) {
      throw new HttpsError(
        "invalid-argument",
        "Das Schweizer Kennzeichen ist ungültig.",
      );
    }
  } else if (countryCode === "AT") {
    if (!/^[A-ZÄÖÜ]{1,2}$/u.test(plateLetters) ||
        !/^[0-9]{1,5}$/.test(plateNumbers)) {
      throw new HttpsError(
        "invalid-argument",
        "Das österreichische Kennzeichen ist ungültig.",
      );
    }
  } else {
    if (!/^[A-ZÄÖÜ]{1,2}$/u.test(plateLetters) ||
        !/^[0-9]{1,4}[EH]?$/.test(plateNumbers)) {
      throw new HttpsError(
        "invalid-argument",
        "Das deutsche Kennzeichen ist ungültig.",
      );
    }
    const suffix = plateNumbers.slice(-1);
    if (plateType === "electric" && suffix !== "E") {
      throw new HttpsError(
        "invalid-argument",
        "Ein Elektrokennzeichen muss mit E enden.",
      );
    }
    if (plateType === "historic" && suffix !== "H") {
      throw new HttpsError(
        "invalid-argument",
        "Ein historisches Kennzeichen muss mit H enden.",
      );
    }
    if (["standard", "seasonal"].includes(plateType) &&
        ["E", "H"].includes(suffix)) {
      throw new HttpsError(
        "invalid-argument",
        "Kennzeichentyp und Kennzeichen-Endung passen nicht zusammen.",
      );
    }
  }

  if (plateType === "seasonal") {
    if (seasonStartMonth == null || seasonEndMonth == null ||
        seasonStartMonth === seasonEndMonth) {
      throw new HttpsError(
        "invalid-argument",
        "Bitte wähle einen gültigen Saisonzeitraum.",
      );
    }
  } else if (seasonStartMonth != null || seasonEndMonth != null) {
    throw new HttpsError(
      "invalid-argument",
      "Ein Saisonzeitraum ist nur für Saisonkennzeichen erlaubt.",
    );
  }
}

function formatDisplayPlate(vehicle) {
  if (vehicle.countryCode === "CH") {
    return `${vehicle.plateRegion} ${vehicle.plateNumbers}`;
  }
  if (vehicle.countryCode === "AT") {
    return [
      vehicle.plateRegion,
      vehicle.plateNumbers,
      vehicle.plateLetters,
    ].join(" ");
  }
  return `${vehicle.plateRegion}-${vehicle.plateLetters} ` +
    vehicle.plateNumbers;
}

function shortenedPlateLabel(vehicle) {
  const firstLetter = vehicle.plateLetters.length === 0 ?
    "" : ` ${vehicle.plateLetters.slice(0, 1)}`;
  return `${vehicle.plateRegion}${firstLetter} •••`;
}

function normalizeVehicleInput(userId, input) {
  const vehicleId = normalizeVehicleId(input?.vehicleId);
  const brand = nullableString(input?.brand, 120);
  const model = nullableString(input?.model, 120);
  const color = nullableString(input?.color, 80);
  if (brand == null || model == null || color == null) {
    throw new HttpsError(
      "invalid-argument",
      "Marke, Modell und Farbe müssen vollständig angegeben werden.",
    );
  }

  const countryCode = safeString(input?.countryCode).toUpperCase();
  if (!supportedCountries.has(countryCode)) {
    throw new HttpsError(
      "invalid-argument",
      "Das Kennzeichenland wird nicht unterstützt.",
    );
  }
  const plateRegion = normalizePlatePart(input?.plateRegion);
  const plateLetters = countryCode === "CH" ?
    "" : normalizePlatePart(input?.plateLetters);
  const plateNumbers = normalizePlatePart(input?.plateNumbers);
  const plateType = normalizeEnum(
    input?.plateType,
    supportedPlateTypes,
    "standard",
    "Der Kennzeichentyp ist ungültig.",
  );
  const seasonStartMonth = normalizeOptionalInteger(
    input?.seasonStartMonth,
    {minimum: 1, maximum: 12, label: "Der Saisonbeginn"},
  );
  const seasonEndMonth = normalizeOptionalInteger(
    input?.seasonEndMonth,
    {minimum: 1, maximum: 12, label: "Das Saisonende"},
  );
  validatePlateParts({
    countryCode,
    plateRegion,
    plateLetters,
    plateNumbers,
    plateType,
    seasonStartMonth,
    seasonEndMonth,
  });

  const status = normalizeEnum(
    input?.status,
    supportedStatuses,
    "active",
    "Der Fahrzeugstatus ist ungültig.",
  );
  const useRelationship = normalizeEnum(
    input?.useRelationship,
    supportedRelationships,
    "owner",
    "Die Fahrzeugzuordnung ist ungültig.",
  );
  const vehicleType = normalizeEnum(
    input?.vehicleType,
    supportedVehicleTypes,
    "passengerCar",
    "Die Fahrzeugart ist ungültig.",
  );
  const plateDisplayMode = normalizeEnum(
    input?.plateDisplayMode,
    supportedPlateDisplayModes,
    "hidden",
    "Die Kennzeichenanzeige ist ungültig.",
  );
  const showOnPublicProfile = input?.showOnPublicProfile === true;
  const year = normalizeOptionalInteger(input?.year, {
    minimum: 1886,
    maximum: new Date().getUTCFullYear() + 1,
    label: "Das Baujahr",
  });
  const mileage = normalizeOptionalInteger(input?.mileage, {
    minimum: 0,
    maximum: 99999999,
    label: "Der Kilometerstand",
  });
  const profileHighlights = normalizeStringList(input?.profileHighlights, {
    allowed: supportedProfileHighlights,
    maximum: 5,
  });
  const vehicle = {
    vehicleId,
    ownerUserId: userId,
    brand,
    model,
    series: nullableString(input?.series, 120),
    color,
    countryCode,
    plateRegion,
    plateLetters,
    plateNumbers,
    isPrimary: input?.isPrimary === true,
    status,
    visibility: showOnPublicProfile ? "contacts" : "onlyMe",
    showPlate: plateDisplayMode !== "hidden",
    useRelationship,
    vehicleType,
    plateType,
    seasonStartMonth,
    seasonEndMonth,
    showOnPublicProfile,
    discoverableByPlate: input?.discoverableByPlate === true,
    selectableInStories: input?.selectableInStories !== false,
    allowContactRequests: input?.allowContactRequests === true,
    plateDisplayMode,
    year,
    firstRegistration: normalizeOptionalDate(
      input?.firstRegistration,
      "Die Erstzulassung",
    ),
    bodyStyle: nullableString(input?.bodyStyle, 80),
    engineDescription: nullableString(input?.engineDescription, 80),
    displacementCcm: normalizeOptionalInteger(input?.displacementCcm, {
      minimum: 0,
      maximum: 20000,
      label: "Der Hubraum",
    }),
    horsepower: normalizeOptionalInteger(input?.horsepower, {
      minimum: 0,
      maximum: 5000,
      label: "Die Leistung",
    }),
    kilowatts: normalizeOptionalInteger(input?.kilowatts, {
      minimum: 0,
      maximum: 4000,
      label: "Die Leistung",
    }),
    fuelType: nullableString(input?.fuelType, 80),
    transmission: nullableString(input?.transmission, 80),
    drivetrain: nullableString(input?.drivetrain, 80),
    equipment: normalizeStringList(input?.equipment, {
      maximum: 40,
      caseInsensitive: true,
      rejectExcess: true,
      label: "Ausstattungen",
    }),
    hsn: nullableUppercaseString(input?.hsn, 8),
    tsn: nullableUppercaseString(input?.tsn, 8),
    vin: nullableUppercaseString(input?.vin, 40),
    ownedSince: normalizeOptionalDate(input?.ownedSince, "Besitz seit"),
    mileage,
    profileHighlights: profileHighlights.length === 0 ?
      ["plate", "color", "mileage", "ownedSince"] : profileHighlights,
  };
  if (vehicle.firstRegistration != null &&
      vehicle.ownedSince != null &&
      vehicle.ownedSince.getTime() < vehicle.firstRegistration.getTime()) {
    throw new HttpsError(
      "invalid-argument",
      "Besitz seit darf nicht vor der Erstzulassung liegen.",
    );
  }
  vehicle.displayPlate = formatDisplayPlate(vehicle);
  vehicle.plateKey = [
    vehicle.plateRegion,
    vehicle.plateLetters,
    vehicle.plateNumbers,
  ].join("");
  vehicle.plateDocumentId = `${countryCode}_${vehicle.plateKey}`;
  vehicle.plateDisplayLabel = plateDisplayMode === "full" ?
    vehicle.displayPlate :
    plateDisplayMode === "shortened" ?
      shortenedPlateLabel(vehicle) :
      "Kennzeichen verborgen";
  return vehicle;
}

function plateIdentityFromData(data) {
  const countryCode = safeString(data?.countryCode).toUpperCase();
  const region = normalizePlatePart(data?.plateRegion);
  const letters = countryCode === "CH" ?
    "" : normalizePlatePart(data?.plateLetters);
  const numbers = normalizePlatePart(data?.plateNumbers);
  if (!supportedCountries.has(countryCode) || region.length === 0 ||
      numbers.length === 0 || (countryCode !== "CH" && letters.length === 0)) {
    return null;
  }
  const plateKey = `${region}${letters}${numbers}`;
  return {
    countryCode,
    plateKey,
    plateDocumentId: `${countryCode}_${plateKey}`,
  };
}

const verificationCoreFields = [
  "brand",
  "model",
  "series",
  "color",
  "countryCode",
  "plateRegion",
  "plateLetters",
  "plateNumbers",
  "status",
  "useRelationship",
  "vehicleType",
  "plateType",
  "seasonStartMonth",
  "seasonEndMonth",
  "year",
  "firstRegistration",
  "hsn",
  "tsn",
  "vin",
];

function comparableVerificationValue(value) {
  if (value instanceof Date) return value.getTime();
  if (value != null && typeof value.toMillis === "function") {
    return value.toMillis();
  }
  return value ?? null;
}

function verificationCoreChanged(previous, next) {
  if (previous == null) return false;
  return verificationCoreFields.some((field) =>
    comparableVerificationValue(previous[field]) !==
      comparableVerificationValue(next[field]));
}

function profileDisplayName(profile) {
  const displayName = safeString(profile?.displayName);
  if (displayName.length > 0) return displayName;
  const firstName = safeString(profile?.firstName);
  const lastName = safeString(profile?.lastName);
  if (firstName.length === 0 && lastName.length === 0) return "plaqa Nutzer";
  if (lastName.length === 0) return firstName;
  const initial = `${lastName.slice(0, 1).toUpperCase()}.`;
  return firstName.length === 0 ? initial : `${firstName} ${initial}`;
}

function vehicleLabel(vehicle) {
  return [vehicle.color, vehicle.brand, vehicle.model]
    .filter((part) => safeString(part).length > 0)
    .join(" ");
}

function publicVehicleData(vehicle, privateData, profile) {
  const showPlateGlobally = profile?.showPlateOnPublicProfile === true;
  const fullPlate = showPlateGlobally &&
    vehicle.plateDisplayMode === "full";
  const publicData = {
    vehicleId: vehicle.vehicleId,
    ownerUserId: vehicle.ownerUserId,
    brand: vehicle.brand,
    model: vehicle.model,
    series: vehicle.series,
    color: vehicle.color,
    countryCode: vehicle.countryCode,
    plateRegion: fullPlate ? vehicle.plateRegion : null,
    plateLetters: fullPlate ? vehicle.plateLetters : null,
    plateNumbers: fullPlate ? vehicle.plateNumbers : null,
    plateDisplayLabel: showPlateGlobally ? vehicle.plateDisplayLabel : null,
    isPrimary: privateData.isPrimary === true,
    isVerified: privateData.isVerified === true,
    verificationStatus: safeString(privateData.verificationStatus) ||
      "unverified",
    status: vehicle.status,
    visibility: "contacts",
    showPlate: showPlateGlobally && vehicle.showPlate,
    vehicleType: vehicle.vehicleType,
    plateType: vehicle.plateType,
    seasonStartMonth: vehicle.seasonStartMonth,
    seasonEndMonth: vehicle.seasonEndMonth,
    showOnPublicProfile: true,
    selectableInStories: vehicle.selectableInStories,
    allowContactRequests: profile?.allowContactRequests !== false &&
      vehicle.allowContactRequests,
    plateDisplayMode: vehicle.plateDisplayMode,
    year: vehicle.year,
    firstRegistration: privateData.firstRegistration ?? null,
    bodyStyle: vehicle.bodyStyle,
    engineDescription: privateData.engineDescription ?? null,
    displacementCcm: privateData.displacementCcm ?? null,
    horsepower: privateData.horsepower ?? null,
    kilowatts: privateData.kilowatts ?? null,
    fuelType: privateData.fuelType ?? null,
    transmission: privateData.transmission ?? null,
    drivetrain: privateData.drivetrain ?? null,
    equipment: Array.isArray(privateData.equipment) ?
      privateData.equipment : [],
    ownedSince: privateData.ownedSince ?? null,
    mileage: vehicle.mileage,
    profileHighlights: vehicle.profileHighlights,
    createdAt: privateData.createdAt,
    updatedAt: privateData.updatedAt,
  };
  for (const field of [
    "heroImageUrl",
    "heroImagePath",
    "heroImageStatus",
    "heroSourceHash",
    "heroPromptVersion",
    "heroProvider",
    "heroError",
    "heroRequestedAt",
    "heroGeneratedAt",
    "heroRequestWindowStartedAt",
    "heroRequestCount",
  ]) {
    if (privateData[field] !== undefined) publicData[field] = privateData[field];
  }
  return publicData;
}

async function syncProfileVisibilityReferences({
  firestore,
  userId,
  settings,
  now,
}) {
  const normalizedUserId = safeString(userId);
  if (normalizedUserId.length === 0) {
    throw new HttpsError("invalid-argument", "Nutzer-ID fehlt.");
  }

  const profileReference = firestore.doc(
    `users/${normalizedUserId}/profiles/main`,
  );
  const publicProfileReference = firestore.doc(
    `public_profiles/${normalizedUserId}`,
  );
  const vehiclesReference = firestore.collection(
    `users/${normalizedUserId}/vehicles`,
  );
  const [profileSnapshot, vehiclesSnapshot] = await Promise.all([
    profileReference.get(),
    vehiclesReference.get(),
  ]);
  if (!profileSnapshot.exists) {
    return {updated: false, updatedVehicleCount: 0};
  }

  const profile = profileSnapshot.data() ?? {};
  const effectiveProfile = {
    ...profile,
    showVehicleOnPublicProfile: settings?.showVehicle === true,
    showPlateOnPublicProfile: settings?.showPlate === true,
    allowContactRequests: settings?.allowContactRequests !== false,
    profileAccessEnabled: settings?.profileVisibility !== "onlyMe",
  };
  const batch = firestore.batch();
  const updatedAt = now ?? new Date();

  batch.set(profileReference, {
    showVehicleOnPublicProfile:
      effectiveProfile.showVehicleOnPublicProfile,
    showPlateOnPublicProfile: effectiveProfile.showPlateOnPublicProfile,
    allowContactRequests: effectiveProfile.allowContactRequests,
    profileAccessEnabled: effectiveProfile.profileAccessEnabled,
    updatedAt,
  }, {merge: true});
  batch.set(publicProfileReference, {
    showVehicleOnPublicProfile:
      effectiveProfile.showVehicleOnPublicProfile,
    showPlateOnPublicProfile: effectiveProfile.showPlateOnPublicProfile,
    allowContactRequests: effectiveProfile.allowContactRequests,
    profileAccessEnabled: effectiveProfile.profileAccessEnabled,
    publicRegion: settings?.showRegion === true ?
      nullableString(profile.publicRegion, 120) : null,
    updatedAt,
  }, {merge: true});

  let updatedVehicleCount = 0;
  for (const vehicleSnapshot of vehiclesSnapshot.docs) {
    const privateData = vehicleSnapshot.data() ?? {};
    const vehicleId = normalizeVehicleId(vehicleSnapshot.id);
    const publicVehicleReference = firestore.doc(
      `public_profiles/${normalizedUserId}/vehicles/${vehicleId}`,
    );
    let vehicle;
    try {
      vehicle = normalizeVehicleInput(normalizedUserId, {
        ...privateData,
        vehicleId,
        showOnPublicProfile:
          privateData.showOnPublicProfile === true ||
          privateData.visibility === "contacts",
        discoverableByPlate: privateData.discoverableByPlate !== false,
        selectableInStories: privateData.selectableInStories !== false,
        allowContactRequests: privateData.allowContactRequests !== false,
      });
    } catch (_) {
      batch.delete(publicVehicleReference);
      continue;
    }

    const vehicleIsPublic =
      effectiveProfile.showVehicleOnPublicProfile === true &&
      vehicle.showOnPublicProfile;
    if (vehicleIsPublic) {
      batch.set(
        publicVehicleReference,
        publicVehicleData(vehicle, privateData, effectiveProfile),
        {merge: false},
      );
    } else {
      batch.delete(publicVehicleReference);
    }

    const plateIdentity = plateIdentityFromData(privateData);
    if (plateIdentity != null) {
      batch.set(firestore.doc(`plates/${plateIdentity.plateDocumentId}`), {
        allowContactRequests:
          effectiveProfile.allowContactRequests &&
          vehicle.discoverableByPlate &&
          vehicle.allowContactRequests &&
          activeVehicleStatuses.has(vehicle.status),
        updatedAt,
      }, {merge: true});
    }
    updatedVehicleCount += 1;
  }

  const primaryVehicle = vehiclesSnapshot.docs.find((snapshot) =>
    snapshot.id === safeString(profile.primaryVehicleId));
  if (primaryVehicle != null) {
    try {
      const primaryData = primaryVehicle.data() ?? {};
      const normalizedPrimary = normalizeVehicleInput(normalizedUserId, {
        ...primaryData,
        vehicleId: primaryVehicle.id,
        isPrimary: true,
        showOnPublicProfile:
          primaryData.showOnPublicProfile === true ||
          primaryData.visibility === "contacts",
        discoverableByPlate: primaryData.discoverableByPlate !== false,
        selectableInStories: primaryData.selectableInStories !== false,
        allowContactRequests: primaryData.allowContactRequests !== false,
      });
      const projection = profileVehicleProjection(
        normalizedPrimary,
        effectiveProfile,
      );
      batch.set(publicProfileReference, {
        ...projection.public,
        updatedAt,
      }, {merge: true});
    } catch (_) {
      batch.set(publicProfileReference, {
        vehicleBrand: null,
        vehicleModel: null,
        vehicleColor: null,
        countryCode: null,
        plateRegion: null,
        plateLetters: null,
        plateNumbers: null,
        plateDisplayLabel: null,
        updatedAt,
      }, {merge: true});
    }
  } else {
    batch.set(publicProfileReference, {
      primaryVehicleId: null,
      vehicleBrand: null,
      vehicleModel: null,
      vehicleColor: null,
      countryCode: null,
      plateRegion: null,
      plateLetters: null,
      plateNumbers: null,
      plateDisplayLabel: null,
      updatedAt,
    }, {merge: true});
  }

  await batch.commit();
  return {updated: true, updatedVehicleCount};
}

function profileVehicleProjection(vehicle, profile) {
  const showVehicle = profile?.showVehicleOnPublicProfile === true &&
    vehicle.showOnPublicProfile;
  const showPlate = profile?.showPlateOnPublicProfile === true &&
    vehicle.plateDisplayMode === "full";
  return {
    private: {
      primaryVehicleId: vehicle.vehicleId,
      vehicleBrand: vehicle.brand,
      vehicleModel: vehicle.model,
      vehicleColor: vehicle.color,
      countryCode: vehicle.countryCode,
      plateRegion: vehicle.plateRegion,
      plateLetters: vehicle.plateLetters,
      plateNumbers: vehicle.plateNumbers,
    },
    public: {
      primaryVehicleId: vehicle.vehicleId,
      vehicleBrand: showVehicle ? vehicle.brand : null,
      vehicleModel: showVehicle ? vehicle.model : null,
      vehicleColor: showVehicle ? vehicle.color : null,
      countryCode: showPlate ? vehicle.countryCode : null,
      plateRegion: showPlate ? vehicle.plateRegion : null,
      plateLetters: showPlate ? vehicle.plateLetters : null,
      plateNumbers: showPlate ? vehicle.plateNumbers : null,
      plateDisplayLabel: profile?.showPlateOnPublicProfile === true ?
        vehicle.plateDisplayLabel : null,
      // Public identity verification is independent from the selected
      // vehicle's verification state.
      verificationStatus:
        safeString(profile?.verificationStatus) || "unverified",
      isVerified: safeString(profile?.verificationStatus) === "verified",
    },
  };
}

function vehicleVerificationResetPatch(request, now, reason) {
  const documentStatuses = {...(request?.documentStatuses ?? {})};
  const documentRejectionReasons = {
    ...(request?.documentRejectionReasons ?? {}),
  };
  for (const key of ["vehicleFront", "vehicleBack"]) {
    documentStatuses[key] = "expired";
    documentRejectionReasons[key] = reason;
  }
  const submittedDocumentGroups = Array.isArray(
      request?.submittedDocumentGroups,
  ) ? request.submittedDocumentGroups.filter(
      (group) => group !== "vehicle",
  ) : [];
  const currentStatus = safeString(request?.status);
  return {
    status: currentStatus === "verified" ? "draft" : currentStatus || "draft",
    documentStatuses,
    documentRejectionReasons,
    submittedDocumentGroups,
    rejectionReason: null,
    recheckReason: reason,
    documentsLocked: currentStatus === "pending" &&
      submittedDocumentGroups.includes("identity"),
    updatedAt: now,
  };
}

function plateProjection({vehicle, profile, isPrimary, isVerified, now}) {
  const operationallyActive = activeVehicleStatuses.has(vehicle.status);
  return {
    ownerUserId: vehicle.ownerUserId,
    vehicleId: vehicle.vehicleId,
    isPrimary,
    countryCode: vehicle.countryCode,
    plateKey: vehicle.plateKey,
    normalizedPlate: vehicle.plateKey,
    region: vehicle.plateRegion,
    letters: vehicle.plateLetters,
    numbers: vehicle.plateNumbers,
    plateRegion: vehicle.plateRegion,
    plateLetters: vehicle.plateLetters,
    plateNumbers: vehicle.plateNumbers,
    displayPlate: vehicle.displayPlate,
    plateDisplayMode: vehicle.plateDisplayMode,
    plateDisplayLabel: vehicle.plateDisplayLabel,
    showOnPublicProfile: vehicle.showOnPublicProfile,
    selectableInStories: vehicle.selectableInStories,
    displayName: profileDisplayName(profile),
    profilePhotoUrl: nullableString(profile?.photoUrl, 1000),
    vehicleBrand: vehicle.brand,
    vehicleModel: vehicle.model,
    vehicleColor: vehicle.color,
    vehicleLabel: vehicleLabel(vehicle),
    allowContactRequests: operationallyActive &&
      vehicle.discoverableByPlate &&
      vehicle.allowContactRequests &&
      profile?.allowContactRequests !== false,
    allowAnonymousReports: operationallyActive &&
      profile?.allowAnonymousReports !== false,
    verificationStatus: isVerified ? "verified" : "unverified",
    isVerified,
    ownerIdentityVerified:
      safeString(profile?.verificationStatus) === "verified",
    isActive: operationallyActive,
    isDeleted: false,
    updatedAt: now,
  };
}

function deactivatedPlateProjection(now) {
  return {
    vehicleId: null,
    isPrimary: false,
    displayPlate: null,
    displayName: null,
    profilePhotoUrl: null,
    vehicleBrand: null,
    vehicleModel: null,
    vehicleColor: null,
    vehicleLabel: null,
    allowContactRequests: false,
    allowAnonymousReports: false,
    verificationStatus: "unverified",
    isVerified: false,
    isActive: false,
    updatedAt: now,
  };
}

function ensureAuthenticated(authContext) {
  const userId = safeString(authContext?.uid);
  if (userId.length === 0) {
    throw new HttpsError("unauthenticated", "Bitte melde dich neu an.");
  }
  return userId;
}

function ensurePlateAvailable(
  snapshot,
  userId,
  vehicleId,
  currentPrimaryId,
) {
  if (!snapshot.exists) return;
  const data = snapshot.data() ?? {};
  if (data.isActive !== true) return;
  const existingOwner = safeString(data.ownerUserId);
  const existingVehicle = safeString(data.vehicleId);
  const belongsToDifferentVehicle = existingVehicle.length > 0 ?
    existingVehicle !== vehicleId :
    currentPrimaryId.length > 0 && currentPrimaryId !== vehicleId;
  if (existingOwner !== userId || belongsToDifferentVehicle) {
    throw new HttpsError(
      "already-exists",
      "Dieses Kennzeichen ist bereits einem aktiven Fahrzeug zugeordnet.",
    );
  }
}

async function saveProfileVehicle({
  firestore,
  authContext,
  input,
  now,
}) {
  const userId = ensureAuthenticated(authContext);
  const vehicle = normalizeVehicleInput(userId, input);
  const profileReference = firestore.doc(`users/${userId}/profiles/main`);
  const publicProfileReference = firestore.doc(`public_profiles/${userId}`);
  const vehicleReference = firestore.doc(
    `users/${userId}/vehicles/${vehicle.vehicleId}`,
  );
  const publicVehicleReference = firestore.doc(
    `public_profiles/${userId}/vehicles/${vehicle.vehicleId}`,
  );
  const targetPlateReference = firestore.doc(
    `plates/${vehicle.plateDocumentId}`,
  );
  const legacyVerificationReference = firestore.doc(
    `verification_requests/${userId}`,
  );
  const vehicleVerificationReference = firestore.doc(
    `users/${userId}/vehicle_verifications/${vehicle.vehicleId}`,
  );

  return firestore.runTransaction(async (transaction) => {
    const [
      profileSnapshot,
      existingVehicleSnapshot,
      targetPlateSnapshot,
      legacyVerificationSnapshot,
      vehicleVerificationSnapshot,
    ] = await Promise.all([
      transaction.get(profileReference),
      transaction.get(vehicleReference),
      transaction.get(targetPlateReference),
      transaction.get(legacyVerificationReference),
      transaction.get(vehicleVerificationReference),
    ]);
    if (!profileSnapshot.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Speichere zuerst deine persönlichen Daten.",
      );
    }

    const profile = profileSnapshot.data() ?? {};
    const existing = existingVehicleSnapshot.exists ?
      existingVehicleSnapshot.data() ?? {} : null;
    if (existing != null && safeString(existing.ownerUserId) !== userId) {
      throw new HttpsError(
        "permission-denied",
        "Dieses Fahrzeug darf nicht geändert werden.",
      );
    }
    const coreChanged = verificationCoreChanged(existing, vehicle);
    if (existing?.verificationLocked === true && coreChanged) {
      throw new HttpsError(
        "failed-precondition",
        "Während der Prüfung können verifizierungsrelevante Fahrzeugdaten nicht geändert werden.",
      );
    }
    const currentPrimaryId = safeString(profile.primaryVehicleId);
    ensurePlateAvailable(
      targetPlateSnapshot,
      userId,
      vehicle.vehicleId,
      currentPrimaryId,
    );
    const becomesPrimary = vehicle.isPrimary || currentPrimaryId.length === 0 ||
      currentPrimaryId === vehicle.vehicleId;
    if (becomesPrimary && !activeVehicleStatuses.has(vehicle.status)) {
      throw new HttpsError(
        "failed-precondition",
        "Wähle zuerst ein anderes aktives Hauptfahrzeug aus.",
      );
    }
    let oldPrimarySnapshot = null;
    let oldPublicPrimarySnapshot = null;
    if (becomesPrimary && currentPrimaryId.length > 0 &&
        currentPrimaryId !== vehicle.vehicleId) {
      oldPrimarySnapshot = await transaction.get(firestore.doc(
        `users/${userId}/vehicles/${currentPrimaryId}`,
      ));
      oldPublicPrimarySnapshot = await transaction.get(firestore.doc(
        `public_profiles/${userId}/vehicles/${currentPrimaryId}`,
      ));
    }

    const previousPlate = plateIdentityFromData(existing);
    let previousPlateSnapshot = null;
    if (previousPlate != null &&
        previousPlate.plateDocumentId !== vehicle.plateDocumentId) {
      previousPlateSnapshot = await transaction.get(firestore.doc(
        `plates/${previousPlate.plateDocumentId}`,
      ));
    }

    const vehicleVerification = vehicleVerificationSnapshot.exists ?
      vehicleVerificationSnapshot.data() ?? {} : null;
    const declarationId = safeString(vehicleVerification?.declarationId);
    const declarationReference = declarationId.length === 0 ? null :
      firestore.doc(
        `users/${userId}/verification_declarations/${declarationId}`,
      );
    const declarationSnapshot = declarationReference == null ? null :
      await transaction.get(declarationReference);

    const wasVerified = existing?.isVerified === true ||
      safeString(existing?.verificationStatus) === "verified";
    const hasActiveV1Verification = ["verified", "requires_declaration"]
      .includes(safeString(vehicleVerification?.status));
    const resetVerification = coreChanged &&
      (wasVerified || hasActiveV1Verification);
    const isVerified = resetVerification ? false : wasVerified;
    const verificationStatus = resetVerification ? "evidenceMissing" :
      safeString(existing?.verificationStatus) || "unverified";
    const createdAt = existing?.createdAt ?? now;
    const privateData = {
      ...(existing ?? {}),
      ...vehicle,
      vehicleId: vehicle.vehicleId,
      ownerUserId: userId,
      isPrimary: becomesPrimary,
      isVerified,
      verificationStatus,
      verificationLocked: resetVerification ? false :
        existing?.verificationLocked === true,
      verificationRejectionReason: resetVerification ? null :
        existing?.verificationRejectionReason ?? null,
      equipment: vehicle.equipment,
      createdAt,
      updatedAt: now,
      deactivatedAt: null,
    };
    delete privateData.displayPlate;
    delete privateData.plateKey;
    delete privateData.plateDocumentId;
    delete privateData.plateDisplayLabel;

    transaction.set(vehicleReference, privateData, {merge: false});
    if (profile.showVehicleOnPublicProfile === true &&
        vehicle.showOnPublicProfile) {
      transaction.set(
        publicVehicleReference,
        publicVehicleData(vehicle, privateData, profile),
        {merge: false},
      );
    } else {
      transaction.delete(publicVehicleReference);
    }

    if (oldPrimarySnapshot?.exists === true) {
      transaction.set(
        oldPrimarySnapshot.ref,
        {isPrimary: false, updatedAt: now},
        {merge: true},
      );
      if (oldPublicPrimarySnapshot?.exists === true) {
        transaction.set(
          oldPublicPrimarySnapshot.ref,
          {isPrimary: false, updatedAt: now},
          {merge: true},
        );
      }
    }

    const verificationRequest = legacyVerificationSnapshot.exists ?
      legacyVerificationSnapshot.data() ?? {} : {};
    const vehicleRequestReset = resetVerification &&
      safeString(verificationRequest.vehicleId) === vehicle.vehicleId;
    if (becomesPrimary) {
      const projection = profileVehicleProjection(
        vehicle,
        profile,
      );
      transaction.set(profileReference, {
        ...projection.private,
        ...(vehicleRequestReset ? {
          verificationStages: {
            ...(profile.verificationStages ?? {}),
            vehicle: false,
          },
        } : {}),
        updatedAt: now,
      }, {merge: true});
      transaction.set(publicProfileReference, {
        ...projection.public,
        updatedAt: now,
      }, {merge: true});
    }

    if (previousPlateSnapshot?.exists === true &&
        safeString(previousPlateSnapshot.data()?.ownerUserId) === userId &&
        safeString(previousPlateSnapshot.data()?.vehicleId) ===
          vehicle.vehicleId) {
      transaction.set(
        previousPlateSnapshot.ref,
        deactivatedPlateProjection(now),
        {merge: true},
      );
    }
    transaction.set(
      targetPlateReference,
      {
        ...plateProjection({
          vehicle,
          profile,
          isPrimary: becomesPrimary,
          isVerified,
          now,
        }),
        createdAt: targetPlateSnapshot.exists ?
          targetPlateSnapshot.data()?.createdAt ?? now : now,
      },
      {merge: true},
    );

    if (!existingVehicleSnapshot.exists) {
      const timelineData = {
        entryId: "vehicle_created",
        ownerUserId: userId,
        vehicleId: vehicle.vehicleId,
        type: "vehicleCreated",
        title: "Fahrzeug hinzugefügt",
        description: `${vehicle.brand} ${vehicle.model}`,
        eventDate: now,
        isAutomaticallyCreated: true,
        visibility: vehicle.visibility,
        createdAt: now,
        updatedAt: now,
      };
      transaction.set(firestore.doc(
        `users/${userId}/vehicles/${vehicle.vehicleId}/timeline/vehicle_created`,
      ), timelineData, {merge: false});
      if (profile.showVehicleOnPublicProfile === true &&
          vehicle.showOnPublicProfile) {
        transaction.set(firestore.doc(
          `public_profiles/${userId}/vehicles/${vehicle.vehicleId}/timeline/vehicle_created`,
        ), timelineData, {merge: false});
      }
    }

    if (vehicleRequestReset) {
      transaction.set(
        legacyVerificationReference,
        vehicleVerificationResetPatch(
            verificationRequest,
            now,
            "Fahrzeugdaten geändert. Bitte reiche den Fahrzeugnachweis erneut ein.",
        ),
        {merge: true},
      );
    }

    if (resetVerification && vehicleVerificationSnapshot.exists) {
      transaction.set(vehicleVerificationReference, {
        status: "invalidated",
        invalidatedReason: "vehicle_core_changed",
        invalidatedAt: now,
        updatedAt: now,
      }, {merge: true});
      if (declarationSnapshot?.exists === true) {
        transaction.set(declarationReference, {
          status: "revoked",
          revokedReason: "vehicle_core_changed",
          revokedAt: now,
          updatedAt: now,
        }, {merge: true});
      }
    }

    return {
      vehicleId: vehicle.vehicleId,
      isPrimary: becomesPrimary,
      verificationReset: resetVerification,
    };
  });
}

async function setPrimaryProfileVehicle({
  firestore,
  authContext,
  input,
  now,
}) {
  const userId = ensureAuthenticated(authContext);
  const vehicleId = normalizeVehicleId(input?.vehicleId);
  const profileReference = firestore.doc(`users/${userId}/profiles/main`);
  const publicProfileReference = firestore.doc(`public_profiles/${userId}`);
  const vehicleReference = firestore.doc(
    `users/${userId}/vehicles/${vehicleId}`,
  );

  return firestore.runTransaction(async (transaction) => {
    const profileSnapshot = await transaction.get(profileReference);
    const vehicleSnapshot = await transaction.get(vehicleReference);
    if (!profileSnapshot.exists || !vehicleSnapshot.exists) {
      throw new HttpsError("not-found", "Das Fahrzeug wurde nicht gefunden.");
    }
    const profile = profileSnapshot.data() ?? {};
    const currentPrimaryId = safeString(profile.primaryVehicleId);
    if (currentPrimaryId === vehicleId) {
      return {vehicleId, alreadyPrimary: true, verificationReset: false};
    }
    const currentVehicle = vehicleSnapshot.data() ?? {};
    if (safeString(currentVehicle.ownerUserId) !== userId ||
        !activeVehicleStatuses.has(safeString(currentVehicle.status))) {
      throw new HttpsError(
        "failed-precondition",
        "Das Fahrzeug kann nicht als Hauptfahrzeug verwendet werden.",
      );
    }
    let oldPrimarySnapshot = null;
    let oldPublicPrimarySnapshot = null;
    if (currentPrimaryId.length > 0) {
      oldPrimarySnapshot = await transaction.get(firestore.doc(
        `users/${userId}/vehicles/${currentPrimaryId}`,
      ));
      oldPublicPrimarySnapshot = await transaction.get(firestore.doc(
        `public_profiles/${userId}/vehicles/${currentPrimaryId}`,
      ));
    }
    const targetPlateIdentity = plateIdentityFromData(currentVehicle);
    if (targetPlateIdentity == null) {
      throw new HttpsError(
        "failed-precondition",
        "Das Kennzeichen des Fahrzeugs ist unvollständig.",
      );
    }
    const targetPlateReference = firestore.doc(
      `plates/${targetPlateIdentity.plateDocumentId}`,
    );
    const targetPlateSnapshot = await transaction.get(targetPlateReference);
    ensurePlateAvailable(
      targetPlateSnapshot,
      userId,
      vehicleId,
      currentPrimaryId,
    );
    const oldPrimaryData = oldPrimarySnapshot?.exists === true ?
      oldPrimarySnapshot.data() ?? {} : null;
    const oldPlateIdentity = plateIdentityFromData(oldPrimaryData);
    let oldPlateSnapshot = null;
    if (oldPlateIdentity != null &&
        oldPlateIdentity.plateDocumentId !==
          targetPlateIdentity.plateDocumentId) {
      oldPlateSnapshot = await transaction.get(firestore.doc(
        `plates/${oldPlateIdentity.plateDocumentId}`,
      ));
    }
    const normalized = normalizeVehicleInput(userId, {
      ...currentVehicle,
      vehicleId,
      isPrimary: true,
      showOnPublicProfile:
        currentVehicle.showOnPublicProfile === true ||
        currentVehicle.visibility === "contacts",
      discoverableByPlate: currentVehicle.discoverableByPlate !== false,
      selectableInStories: currentVehicle.selectableInStories !== false,
      allowContactRequests: currentVehicle.allowContactRequests !== false,
    });
    const projection = profileVehicleProjection(
      normalized,
      profile,
    );

    transaction.set(vehicleReference, {
      isPrimary: true,
      updatedAt: now,
    }, {merge: true});
    if (profile.showVehicleOnPublicProfile === true &&
        normalized.showOnPublicProfile) {
      transaction.set(
        firestore.doc(`public_profiles/${userId}/vehicles/${vehicleId}`),
        publicVehicleData(normalized, {
          ...currentVehicle,
          isPrimary: true,
          updatedAt: now,
        }, profile),
        {merge: false},
      );
    } else {
      transaction.delete(
        firestore.doc(`public_profiles/${userId}/vehicles/${vehicleId}`),
      );
    }
    if (oldPrimarySnapshot?.exists === true) {
      transaction.set(oldPrimarySnapshot.ref, {
        isPrimary: false,
        updatedAt: now,
      }, {merge: true});
      if (oldPublicPrimarySnapshot?.exists === true) {
        transaction.set(oldPublicPrimarySnapshot.ref, {
          isPrimary: false,
          updatedAt: now,
        }, {merge: true});
      }
    }
    transaction.set(profileReference, {
      ...projection.private,
      updatedAt: now,
    }, {merge: true});
    transaction.set(publicProfileReference, {
      ...projection.public,
      updatedAt: now,
    }, {merge: true});
    transaction.set(targetPlateReference, {
      ...plateProjection({
        vehicle: normalized,
        profile,
        isPrimary: true,
        isVerified: currentVehicle.isVerified === true,
        now,
      }),
      createdAt: targetPlateSnapshot.exists ?
        targetPlateSnapshot.data()?.createdAt ?? now : now,
    }, {merge: true});
    if (oldPlateSnapshot?.exists === true &&
        safeString(oldPlateSnapshot.data()?.ownerUserId) === userId &&
        safeString(oldPlateSnapshot.data()?.vehicleId) === currentPrimaryId) {
      transaction.set(oldPlateSnapshot.ref, {
        isPrimary: false,
        updatedAt: now,
      }, {merge: true});
    }

    return {
      vehicleId,
      alreadyPrimary: false,
      verificationReset: false,
    };
  });
}

async function deactivateProfileVehicle({
  firestore,
  authContext,
  input,
  now,
}) {
  const userId = ensureAuthenticated(authContext);
  const vehicleId = normalizeVehicleId(input?.vehicleId);
  const profileReference = firestore.doc(`users/${userId}/profiles/main`);
  const vehicleReference = firestore.doc(
    `users/${userId}/vehicles/${vehicleId}`,
  );
  const publicVehicleReference = firestore.doc(
    `public_profiles/${userId}/vehicles/${vehicleId}`,
  );
  const vehicleVerificationReference = firestore.doc(
    `users/${userId}/vehicle_verifications/${vehicleId}`,
  );

  return firestore.runTransaction(async (transaction) => {
    const [profileSnapshot, vehicleSnapshot, vehicleVerificationSnapshot] =
      await Promise.all([
        transaction.get(profileReference),
        transaction.get(vehicleReference),
        transaction.get(vehicleVerificationReference),
      ]);
    if (!vehicleSnapshot.exists) {
      return {vehicleId, alreadyDeactivated: true};
    }
    const vehicle = vehicleSnapshot.data() ?? {};
    if (safeString(vehicle.ownerUserId) !== userId) {
      throw new HttpsError(
        "permission-denied",
        "Dieses Fahrzeug darf nicht entfernt werden.",
      );
    }
    if (vehicle.isPrimary === true ||
        safeString(profileSnapshot.data()?.primaryVehicleId) === vehicleId) {
      throw new HttpsError(
        "failed-precondition",
        "Wähle zuerst ein anderes Hauptfahrzeug aus.",
      );
    }
    const plateIdentity = plateIdentityFromData(vehicle);
    let plateSnapshot = null;
    if (plateIdentity != null) {
      plateSnapshot = await transaction.get(firestore.doc(
        `plates/${plateIdentity.plateDocumentId}`,
      ));
    }
    const declarationId = safeString(
      vehicleVerificationSnapshot.data()?.declarationId,
    );
    const declarationReference = declarationId.length === 0 ? null :
      firestore.doc(
        `users/${userId}/verification_declarations/${declarationId}`,
      );
    const declarationSnapshot = declarationReference == null ? null :
      await transaction.get(declarationReference);
    transaction.set(vehicleReference, {
      status: "archived",
      visibility: "onlyMe",
      showPlate: false,
      showOnPublicProfile: false,
      discoverableByPlate: false,
      selectableInStories: false,
      allowContactRequests: false,
      isVerified: false,
      verificationStatus: "unverified",
      verificationLocked: false,
      deactivatedAt: now,
      updatedAt: now,
    }, {merge: true});
    transaction.delete(publicVehicleReference);
    if (plateSnapshot?.exists === true &&
        safeString(plateSnapshot.data()?.ownerUserId) === userId &&
        safeString(plateSnapshot.data()?.vehicleId) === vehicleId) {
      transaction.set(
        plateSnapshot.ref,
        deactivatedPlateProjection(now),
        {merge: true},
      );
    }
    if (vehicleVerificationSnapshot.exists) {
      transaction.set(vehicleVerificationReference, {
        status: "revoked",
        revokedReason: "vehicle_removed",
        revokedAt: now,
        updatedAt: now,
      }, {merge: true});
    }
    if (declarationSnapshot?.exists === true) {
      transaction.set(declarationReference, {
        status: "revoked",
        revokedReason: "vehicle_removed",
        revokedAt: now,
        updatedAt: now,
      }, {merge: true});
    }
    return {vehicleId, alreadyDeactivated: false};
  });
}

async function updatePrimaryVehicleLocation({
  firestore,
  authContext,
  input,
  now,
}) {
  const userId = ensureAuthenticated(authContext);
  const hasLatitude = input?.latitude != null;
  const hasLongitude = input?.longitude != null;
  const latitude = hasLatitude ? Number(input.latitude) : null;
  const longitude = hasLongitude ? Number(input.longitude) : null;
  if (hasLatitude !== hasLongitude ||
      (hasLatitude &&
       (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
        !Number.isFinite(longitude) || longitude < -180 || longitude > 180))) {
    throw new HttpsError("invalid-argument", "Der Standort ist ungültig.");
  }
  const profileReference = firestore.doc(`users/${userId}/profiles/main`);
  const vehiclesReference = firestore.collection(`users/${userId}/vehicles`);
  return firestore.runTransaction(async (transaction) => {
    const profileSnapshot = await transaction.get(profileReference);
    if (!profileSnapshot.exists) {
      throw new HttpsError("not-found", "Das Profil wurde nicht gefunden.");
    }
    const profile = profileSnapshot.data() ?? {};
    const vehiclesSnapshot = await transaction.get(vehiclesReference);
    const activeVehicles = vehiclesSnapshot.docs
      .map((snapshot) => ({
        snapshot,
        data: snapshot.data() ?? {},
      }))
      .filter(({data}) =>
        activeVehicleStatuses.has(safeString(data.status)) &&
        data.discoverableByPlate !== false &&
        data.allowContactRequests !== false &&
        plateIdentityFromData(data) != null,
      );
    if (activeVehicles.length === 0) {
      throw new HttpsError(
        "failed-precondition",
        "Hinterlege zuerst ein aktives Fahrzeug mit Kennzeichen.",
      );
    }
    const plateEntries = [];
    for (const {snapshot, data} of activeVehicles) {
      const vehicleId = normalizeVehicleId(snapshot.id);
      const identity = plateIdentityFromData(data);
      const plateReference = firestore.doc(
        `plates/${identity.plateDocumentId}`,
      );
      const plateSnapshot = await transaction.get(plateReference);
      if (plateSnapshot.exists &&
          (safeString(plateSnapshot.data()?.ownerUserId) !== userId ||
           (safeString(plateSnapshot.data()?.vehicleId).length > 0 &&
            safeString(plateSnapshot.data()?.vehicleId) !== vehicleId))) {
        throw new HttpsError(
          "failed-precondition",
          "Ein Kennzeichen ist einem anderen Fahrzeug zugeordnet.",
        );
      }
      plateEntries.push({
        vehicleId,
        vehicleData: data,
        plateReference,
        plateSnapshot,
      });
    }

    for (const entry of plateEntries) {
      const vehicle = normalizeVehicleInput(userId, {
        ...entry.vehicleData,
        vehicleId: entry.vehicleId,
        showOnPublicProfile:
          entry.vehicleData.showOnPublicProfile === true ||
          entry.vehicleData.visibility === "contacts",
        discoverableByPlate: true,
        selectableInStories:
          entry.vehicleData.selectableInStories !== false,
        allowContactRequests: true,
      });
      transaction.set(entry.plateReference, {
        ...plateProjection({
          vehicle,
          profile,
          isPrimary:
            safeString(profile.primaryVehicleId) === entry.vehicleId,
          isVerified: entry.vehicleData.isVerified === true,
          now,
        }),
        createdAt: entry.plateSnapshot.exists ?
          entry.plateSnapshot.data()?.createdAt ?? now : now,
        ...(hasLatitude ? {
          latitude,
          longitude,
          locationUpdatedAt: now,
        } : {}),
      }, {merge: true});
    }
    return {updated: true, updatedVehicleCount: plateEntries.length};
  });
}

module.exports = {
  deactivateProfileVehicle,
  formatDisplayPlate,
  normalizeVehicleInput,
  plateIdentityFromData,
  saveProfileVehicle,
  setPrimaryProfileVehicle,
  shortenedPlateLabel,
  syncProfileVisibilityReferences,
  updatePrimaryVehicleLocation,
  verificationCoreChanged,
};
