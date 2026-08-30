const verificationMethod = "on_device_ocr_front_v1";
const assuranceLevel = "document_data_match";

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function dateFromValue(value) {
  if (value instanceof Date) return value;
  if (value != null && typeof value.toDate === "function") {
    return value.toDate();
  }
  if (typeof value === "string" || typeof value === "number") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function serverDateKey(now = new Date()) {
  const date = dateFromValue(now);
  if (date == null) return "";
  return date.toISOString().slice(0, 10);
}

function normalizePlate(value) {
  return safeString(value).toUpperCase().replace(/[\s-]+/gu, "")
    .replace(/[^A-ZÄÖÜ0-9]/gu, "");
}

function plateFromVehicle(vehicle) {
  if (safeString(vehicle?.countryCode).toUpperCase() !== "DE") return "";
  return normalizePlate(
    `${safeString(vehicle?.plateRegion)}${safeString(vehicle?.plateLetters)}` +
    safeString(vehicle?.plateNumbers),
  );
}

function isEffectiveIdentityVerification(identity, now = new Date()) {
  const today = serverDateKey(now);
  const expiresAt = safeString(identity?.documentExpiresAt);
  return safeString(identity?.status) === "verified" &&
    safeString(identity?.verificationMethod) === verificationMethod &&
    safeString(identity?.assuranceLevel) === assuranceLevel &&
    /^\d{4}-\d{2}-\d{2}$/u.test(expiresAt) &&
    expiresAt >= today;
}

function isEffectiveVehicleVerification({
  identity,
  verification,
  vehicle,
  now = new Date(),
}) {
  const expectedPlate = plateFromVehicle(vehicle);
  const identityVersion = safeString(identity?.identityVersion);
  return isEffectiveIdentityVerification(identity, now) &&
    identityVersion.length > 0 &&
    safeString(verification?.status) === "verified" &&
    safeString(verification?.verificationMethod) === verificationMethod &&
    safeString(verification?.assuranceLevel) === assuranceLevel &&
    safeString(verification?.identityVersion) === identityVersion &&
    normalizePlate(verification?.plateNormalized) === expectedPlate &&
    expectedPlate.length > 0 &&
    vehicle?.isDeleted !== true &&
    safeString(vehicle?.status || "active") === "active";
}

function usesVerificationV1(identity, verification = null) {
  return identity != null || verification != null;
}

module.exports = {
  assuranceLevel,
  isEffectiveIdentityVerification,
  isEffectiveVehicleVerification,
  normalizePlate,
  plateFromVehicle,
  serverDateKey,
  usesVerificationV1,
  verificationMethod,
};
