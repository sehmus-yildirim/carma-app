const allowedStorageBuckets = new Set([
  "carma-a84e4.firebasestorage.app",
  "carma-a84e4.appspot.com",
]);

function safeString(value) {
  return typeof value === "string" ? value.trim() : "";
}

function hasAllowedDownloadQuery(parsed) {
  const entries = [...parsed.searchParams.entries()];
  const altEntries = entries.filter(([key]) => key === "alt");
  const tokenEntries = entries.filter(([key]) => key === "token");
  return entries.length === altEntries.length + tokenEntries.length &&
    altEntries.length === 1 && altEntries[0][1] === "media" &&
    tokenEntries.length <= 1 &&
    (tokenEntries.length === 0 ||
      (tokenEntries[0][1].length > 0 && tokenEntries[0][1].length <= 512));
}

function trustedProfilePhotoUrl(value, userId) {
  const normalized = safeString(value);
  const normalizedUserId = safeString(userId);
  if (normalized.length === 0 || normalized.length > 2000 ||
      !/^[A-Za-z0-9_-]{1,128}$/u.test(normalizedUserId)) {
    return null;
  }

  let parsed;
  try {
    parsed = new URL(normalized);
  } catch (_) {
    return null;
  }

  const pathMatch = parsed.pathname.match(/^\/v0\/b\/([^/]+)\/o\/(.+)$/u);
  if (parsed.protocol !== "https:" ||
      parsed.hostname !== "firebasestorage.googleapis.com" ||
      parsed.username.length > 0 || parsed.password.length > 0 ||
      parsed.hash.length > 0 || pathMatch == null ||
      !allowedStorageBuckets.has(pathMatch[1]) ||
      !hasAllowedDownloadQuery(parsed)) {
    return null;
  }

  let objectPath;
  try {
    objectPath = decodeURIComponent(pathMatch[2]);
  } catch (_) {
    return null;
  }
  return objectPath === `profile_photos/${normalizedUserId}/profile.png` ?
    normalized : null;
}

module.exports = {
  trustedProfilePhotoUrl,
};
