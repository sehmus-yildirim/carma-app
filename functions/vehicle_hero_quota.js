const {HttpsError} = require("firebase-functions/v2/https");

const accountVehicleHeroWindowMs = 24 * 60 * 60 * 1000;
const maxAccountVehicleHeroRequestsPerWindow = 6;

function timestampMillis(value) {
  if (value != null && typeof value.toMillis === "function") {
    return value.toMillis();
  }
  if (value instanceof Date) {
    return value.getTime();
  }
  return null;
}

async function reserveAccountVehicleHeroQuota({
  firestore,
  transaction,
  userId,
  now,
}) {
  const reference = firestore.doc(`vehicle_hero_rate_limits/${userId}`);
  const snapshot = await transaction.get(reference);
  const data = snapshot.exists ? snapshot.data() ?? {} : {};
  const windowStartedAtMs = timestampMillis(data.windowStartedAt);
  const hasActiveWindow = windowStartedAtMs != null &&
    now.toMillis() - windowStartedAtMs < accountVehicleHeroWindowMs;
  const currentCount = Number.isInteger(data.requestCount) ?
    data.requestCount :
    0;
  const requestCount = hasActiveWindow ? currentCount + 1 : 1;

  if (requestCount > maxAccountVehicleHeroRequestsPerWindow) {
    throw new HttpsError(
      "resource-exhausted",
      "Das tägliche Erstellungslimit für dein Konto ist erreicht.",
    );
  }

  transaction.set(reference, {
    userId,
    windowStartedAt: hasActiveWindow ? data.windowStartedAt : now,
    requestCount,
    updatedAt: now,
  }, {merge: true});
  return reference;
}

module.exports = {
  accountVehicleHeroWindowMs,
  maxAccountVehicleHeroRequestsPerWindow,
  reserveAccountVehicleHeroQuota,
};
