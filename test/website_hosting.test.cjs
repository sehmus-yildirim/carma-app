const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const {
  hostingRoot,
  resolveHostingRequest,
  startWebsiteServer,
} = require("./helpers/website_test_server.cjs");
const {storeConfiguration, storeTarget} = require("../hosting/store-links.js");

const publicRoutes = new Map([
  ["/", "index.html"],
  ["/community-richtlinien", "community-richtlinien/index.html"],
  ["/datenschutz", "datenschutz/index.html"],
  ["/impressum", "impressum/index.html"],
  ["/kinderschutz", "kinderschutz/index.html"],
  ["/konto-loeschen", "konto-loeschen/index.html"],
  ["/meldestelle", "meldestelle/index.html"],
  ["/nutzungsbedingungen", "nutzungsbedingungen/index.html"],
  ["/partner", "partner/index.html"],
  ["/support", "support/index.html"],
]);

test("serves all canonical routes and redirects compatible slash URLs", () => {
  for (const [route, relativePath] of publicRoutes) {
    const canonical = resolveHostingRequest(route);
    assert.equal(canonical.status, 200, route);
    assert.equal(path.relative(hostingRoot, canonical.filePath).replaceAll("\\", "/"), relativePath);

    if (route !== "/") {
      const slashVariant = resolveHostingRequest(`${route}/`);
      assert.equal(slashVariant.status, 301, `${route}/`);
      assert.equal(slashVariant.redirect, route);
    }
  }
});

test("returns the custom plaqa page with a real 404 status", async () => {
  const server = await startWebsiteServer();
  try {
    const response = await fetch(`${server.baseUrl}/diese-seite-gibt-es-nicht`);
    const html = await response.text();
    assert.equal(response.status, 404);
    assert.match(html, /Hier führt gerade kein Weg weiter\./);
    assert.match(html, /<meta name="robots" content="noindex,follow">/);
    assert.match(html, /plaqa_logo_512\.png/);
    assert.match(html, /href="\/"/);
    assert.match(html, /href="\/support\/"/);
  } finally {
    await server.close();
  }
});

test("keeps every public page indexable with one exact canonical URL", () => {
  for (const [route, relativePath] of publicRoutes) {
    const html = read(relativePath);
    const expected = route === "/" ? "https://plaqa.de/" : `https://plaqa.de${route}`;
    assert.equal(attributeValues(html, "link", "href", "canonical").length, 1, relativePath);
    assert.match(html, /<meta name="robots" content="index,follow">/);
    assert.match(html, new RegExp(`<link rel="canonical" href="${escapeRegExp(expected)}">`));
    assert.match(
      html,
      /<meta\b[^>]*\bname="viewport"[^>]*\bcontent="width=device-width, initial-scale=1"[^>]*>/i,
    );
    assert.match(html, /<h1(?:\s[^>]*)?>[\s\S]+?<\/h1>/i);
  }
});

test("every public page exposes consistent social metadata and keyboard access", () => {
  for (const [route, relativePath] of publicRoutes) {
    const html = read(relativePath);
    const expectedUrl = route === "/" ? "https://plaqa.de/" : `https://plaqa.de${route}/`;
    assert.match(html, /<meta property="og:title" content="[^"]+">/, relativePath);
    assert.match(html, /<meta property="og:description" content="[^"]+">/, relativePath);
    assert.match(html, new RegExp(`<meta property="og:url" content="${escapeRegExp(expectedUrl)}">`));
    assert.match(html, /<meta property="og:image" content="https:\/\/plaqa\.de\/assets\/social\/plaqa-social-card\.png">/);
    assert.match(html, /<meta name="twitter:card" content="summary_large_image">/);
    assert.match(html, /<link rel="manifest" href="\/manifest\.webmanifest">/);
    assert.match(html, /class="skip-link"[^>]*href="#main-content"/);
    assert.match(html, /<main\b[^>]*id="main-content"/);
  }
});

test("homepage publishes structured organization, app, FAQ and contact data", () => {
  const html = read("index.html");
  assert.match(html, /<script type="application\/ld\+json">/);
  for (const schemaType of ["Organization", "SoftwareApplication", "FAQPage", "ContactPoint"]) {
    assert.match(html, new RegExp(`"@type": "${schemaType}"`), schemaType);
  }
});

test("manifest, icons and responsive screen formats are present", () => {
  const manifest = JSON.parse(read("manifest.webmanifest"));
  assert.equal(manifest.name, "plaqa");
  assert.equal(manifest.display, "standalone");
  for (const icon of manifest.icons) {
    assert.ok(fs.existsSync(path.join(hostingRoot, icon.src.replace(/^\//, ""))), icon.src);
  }

  const homepage = read("index.html");
  assert.match(homepage, /<div class="detail-phone">[\s\S]*?<picture>/);
  assert.match(homepage, /type="image\/avif"/);
  assert.match(homepage, /type="image\/webp"/);
  for (const extension of ["avif", "webp"]) {
    assert.equal(
      fs.readdirSync(path.join(hostingRoot, "assets", "site")).filter((name) => name.endsWith(`.${extension}`)).length,
      8,
      extension,
    );
  }
});

test("hosting enables restrictive security policies and versioned asset caching", () => {
  const firebase = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "firebase.json"), "utf8"));
  const headerGroups = firebase.hosting.headers;
  const globalHeaders = Object.fromEntries(headerGroups[0].headers.map(({key, value}) => [key, value]));
  assert.match(globalHeaders["Content-Security-Policy"], /default-src 'self'/);
  assert.match(globalHeaders["Content-Security-Policy"], /frame-ancestors 'none'/);
  assert.match(globalHeaders["Content-Security-Policy"], /https:\/\/www\.gstatic\.com/);
  assert.match(globalHeaders["Permissions-Policy"], /camera=\(\)/);
  assert.match(globalHeaders["Permissions-Policy"], /geolocation=\(\)/);
  assert.ok(headerGroups.some(({source}) => source === "**/*.@(css|js)"));
  assert.ok(headerGroups.some(({source}) => source.includes("avif")));
});

test("all versioned CSS and JavaScript references share one release token", () => {
  const versions = new Set();
  for (const relativePath of publicRoutes.values()) {
    const html = read(relativePath);
    for (const match of html.matchAll(/\/(?:[^"']+\.(?:css|js))\?v=([0-9-]+)/g)) {
      versions.add(match[1]);
    }
  }
  for (const relativePath of ["404.html", "auth/action/index.html"]) {
    const html = read(relativePath);
    for (const match of html.matchAll(/\/(?:[^"']+\.(?:css|js))\?v=([0-9-]+)/g)) {
      versions.add(match[1]);
    }
  }
  assert.deepEqual([...versions], ["20260827-9"]);
});

test("robots and sitemap describe exactly the public URL contract", () => {
  const robots = read("robots.txt");
  assert.match(robots, /^User-agent: \*$/m);
  assert.match(robots, /^Allow: \/$/m);
  assert.match(robots, /^Disallow: \/auth\/action$/m);
  assert.match(robots, /^Disallow: \/email-templates\/$/m);
  assert.match(robots, /^Sitemap: https:\/\/plaqa\.de\/sitemap\.xml$/m);

  const sitemap = read("sitemap.xml");
  assert.match(sitemap, /^<\?xml version="1\.0" encoding="UTF-8"\?>/);
  assertWellFormedXml(sitemap);
  const locations = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => match[1]);
  const expected = [...publicRoutes.keys()].map((route) =>
    route === "/" ? "https://plaqa.de/" : `https://plaqa.de${route}`,
  );
  assert.deepEqual(locations, expected);
  assert.equal(new Set(locations).size, locations.length);
  assert.doesNotMatch(sitemap, /auth\/action|404|email-templates/);
});

test("retains the non-indexable Firebase auth action route", () => {
  const auth = resolveHostingRequest("/auth/action");
  assert.equal(auth.status, 200);
  const html = read("auth/action/index.html");
  assert.match(html, /<meta name="robots" content="noindex,nofollow">/);
  assert.match(html, /id="continue-link"/);
  assert.match(read("auth/action/action.js"), /oobCode/);
  assert.match(read("auth/action/action.js"), /continueUrl/);
});

test("all internal public links, fragments and local assets resolve", () => {
  for (const [route, relativePath] of publicRoutes) {
    const html = read(relativePath);
    for (const href of attributeValues(html, "a", "href")) {
      assert.notEqual(href, "", `${relativePath}: leeres href`);
      assert.notEqual(href, "#", `${relativePath}: nackter Hash-Link`);
      if (/^(?:mailto:|tel:|https?:\/\/)/.test(href)) {
        if (!href.startsWith("https://plaqa.de")) continue;
      }
      verifyInternalReference(href, route, html, relativePath);
    }

    for (const src of [
      ...attributeValues(html, "img", "src"),
      ...attributeValues(html, "script", "src"),
      ...attributeValues(html, "link", "href").filter((value) => !value.startsWith("https://")),
    ]) {
      if (!src || src.startsWith("data:") || src.startsWith("#")) continue;
      const cleanPath = src.split(/[?#]/, 1)[0];
      if (!cleanPath.startsWith("/")) continue;
      const resolved = resolveHostingRequest(cleanPath);
      assert.equal(resolved.status, 200, `${relativePath}: ${src}`);
    }
  }
});

test("pre-release store behavior exposes no public or placeholder download link", () => {
  assert.equal(storeConfiguration.state, "pre_release");
  assert.equal(storeConfiguration.googlePlayUrl, null);
  assert.equal(storeConfiguration.appStoreUrl, null);
  for (const platform of ["google-play", "app-store"]) {
    assert.deepEqual(storeTarget(platform), {
      available: false,
      label: "Bald verfügbar",
      url: null,
    });
  }

  for (const relativePath of publicRoutes.values()) {
    const html = read(relativePath);
    assert.doesNotMatch(
      html,
      /play\.google\.com|apps\.apple\.com|testflight\.apple\.com|appstoreconnect\.apple\.com/i,
      relativePath,
    );
  }
});

test("all four secure contact channels remain wired into their public pages", () => {
  const pages = new Map([
    ["support", "support/index.html"],
    ["privacy", "datenschutz/index.html"],
    ["partners", "partner/index.html"],
    ["report", "meldestelle/index.html"],
  ]);
  for (const [channel, relativePath] of pages) {
    const html = read(relativePath);
    assert.match(html, new RegExp(`data-contact-form="${channel}"`));
    assert.match(html, /\/contact-form\.css/);
    assert.match(html, /\/contact-form\.js/);
  }
});

function verifyInternalReference(href, currentRoute, currentHtml, relativePath) {
  let normalized = href;
  if (normalized.startsWith("https://plaqa.de")) {
    const parsed = new URL(normalized);
    normalized = parsed.pathname + parsed.hash;
  }

  if (normalized.startsWith("#")) {
    assert.match(currentHtml, new RegExp(`id="${escapeRegExp(normalized.slice(1))}"`), relativePath);
    return;
  }

  const [pathname, fragment] = normalized.split("#", 2);
  const targetPath = pathname.startsWith("/") ? pathname : resolveRelativeRoute(currentRoute, pathname);
  const result = resolveHostingRequest(targetPath || currentRoute);
  assert.ok(result.status === 200 || result.status === 301, `${relativePath}: ${href}`);
  if (fragment) {
    const resolved = result.redirect ? resolveHostingRequest(result.redirect) : result;
    const targetHtml = fs.readFileSync(resolved.filePath, "utf8");
    assert.match(targetHtml, new RegExp(`id="${escapeRegExp(fragment)}"`), `${relativePath}: ${href}`);
  }
}

function resolveRelativeRoute(currentRoute, target) {
  const base = currentRoute === "/" ? "/" : `${currentRoute}/`;
  return new URL(target, `https://plaqa.de${base}`).pathname;
}

function attributeValues(html, tag, attribute, requiredRel) {
  const values = [];
  const tagPattern = new RegExp(`<${tag}\\b([^>]*)>`, "gi");
  for (const match of html.matchAll(tagPattern)) {
    const attributes = match[1];
    if (requiredRel && !new RegExp(`\\brel=["']${requiredRel}["']`, "i").test(attributes)) continue;
    const attributeMatch = attributes.match(new RegExp(`\\b${attribute}=["']([^"']+)["']`, "i"));
    if (attributeMatch) values.push(attributeMatch[1]);
  }
  return values;
}

function read(relativePath) {
  return fs.readFileSync(path.join(hostingRoot, relativePath), "utf8");
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function assertWellFormedXml(xml) {
  const stack = [];
  const withoutDeclaration = xml
    .replace(/^<\?xml[^?]*\?>\s*/, "")
    .replace(/<!--[\s\S]*?-->/g, "");
  for (const match of withoutDeclaration.matchAll(/<([^>]+)>/g)) {
    const token = match[1].trim();
    if (!token || token.startsWith("!") || token.endsWith("/")) continue;
    if (token.startsWith("/")) {
      const closing = token.slice(1).trim();
      assert.equal(stack.pop(), closing, `XML closing tag ${closing}`);
      continue;
    }
    stack.push(token.split(/\s+/, 1)[0]);
  }
  assert.deepEqual(stack, [], "XML has unclosed tags");
}
