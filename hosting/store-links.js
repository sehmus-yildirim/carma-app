(function initializeStoreLinks(root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root != null) root.PlaqaStoreLinks = api;
})(typeof globalThis === "undefined" ? this : globalThis, function createStoreLinks() {
  "use strict";

  const storeConfiguration = Object.freeze({
    state: "pre_release",
    publicLabel: "Bald verfügbar",
    googlePlayUrl: null,
    appStoreUrl: null,
  });

  function storeTarget(platform) {
    if (platform === "google-play") {
      return Object.freeze({
        available: Boolean(storeConfiguration.googlePlayUrl),
        label: storeConfiguration.publicLabel,
        url: storeConfiguration.googlePlayUrl,
      });
    }
    if (platform === "app-store") {
      return Object.freeze({
        available: Boolean(storeConfiguration.appStoreUrl),
        label: storeConfiguration.publicLabel,
        url: storeConfiguration.appStoreUrl,
      });
    }
    return Object.freeze({available: false, label: storeConfiguration.publicLabel, url: null});
  }

  return Object.freeze({storeConfiguration, storeTarget});
});
