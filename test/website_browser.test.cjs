const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const hostingRoot = path.resolve(__dirname, "..", "hosting");
const publicPages = [
  "index.html",
  "community-richtlinien/index.html",
  "datenschutz/index.html",
  "impressum/index.html",
  "kinderschutz/index.html",
  "konto-loeschen/index.html",
  "meldestelle/index.html",
  "nutzungsbedingungen/index.html",
  "partner/index.html",
  "support/index.html",
  "404.html",
];

test("all public pages declare a mobile viewport and responsive content", () => {
  for (const relativePath of publicPages) {
    const html = read(relativePath);
    assert.match(
      html,
      /<meta\b[^>]*\bname="viewport"[^>]*\bcontent="width=device-width, initial-scale=1"[^>]*>/i,
      relativePath,
    );
    assert.match(html, /<h1(?:\s[^>]*)?>[\s\S]+?<\/h1>/i, relativePath);
    assert.doesNotMatch(html, /style="[^"]*min-width:\s*(?:[4-9]\d{2}|\d{4,})px/i, relativePath);
    assert.match(html, /class="skip-link"[^>]*href="#main-content"/, relativePath);
    assert.match(html, /<main\b[^>]*id="main-content"/, relativePath);
  }
});

test("premium homepage keeps the two-view navigation and accessible carousel controls", () => {
  const html = read("index.html");
  assert.match(html, /href="#start"[^>]*data-section-link>App</);
  assert.match(html, /href="#service"[^>]*data-section-link>Service</);
  assert.doesNotMatch(html, /href="#(?:faq|release|funktionen)"[^>]*data-section-link/i);
  assert.match(html, /data-carousel-prev[^>]*aria-label="Vorherige App-Ansicht"/s);
  assert.match(html, /data-carousel-next[^>]*aria-label="Nächste App-Ansicht"/s);
  assert.match(html, /data-close-detail[^>]*aria-label="Detailansicht schließen"/s);
  assert.match(html, /data-current-label/);
});

test("shared styles guard the page shell against horizontal viewport drift", () => {
  const siteCss = read("site.css");
  const authCss = read("auth/action/styles.css");
  const errorCss = read("404.css");
  const contactCss = read("contact-form.css");

  assert.match(siteCss, /html\s*\{[^}]*overflow-x:\s*clip/s);
  assert.match(siteCss, /body\s*\{[^}]*overflow-x:\s*clip/s);
  assert.match(errorCss, /html\s*\{[^}]*overflow-x:\s*clip/s);
  assert.match(errorCss, /body\s*\{[^}]*overflow-x:\s*clip/s);
  assert.match(authCss, /body\s*\{[^}]*overflow-x:\s*hidden/s);

  for (const [name, css] of Object.entries({siteCss, authCss, errorCss, contactCss})) {
    assert.match(css, /@media\s*\(max-width:\s*\d+px\)/, `${name}: mobile breakpoint`);
    assert.doesNotMatch(css, /\bwidth:\s*100vw\b/, `${name}: risky full viewport width`);
    assert.doesNotMatch(
      css,
      /\bmin-width:\s*(?:[4-9]\d{2}|\d{4,})px\b/,
      `${name}: fixed wide minimum`,
    );
  }
});

test("mobile navigation starts closed and has complete toggle behavior", () => {
  const html = read("index.html");
  const script = read("site.js");
  assert.match(html, /class="menu-button"[^>]*aria-expanded="false"/);
  assert.match(html, /id="mobile-navigation"[^>]*hidden/);
  assert.match(script, /menuButton\?\.addEventListener\('click'/);
  assert.match(script, /mobileNavigation\.hidden = !willOpen/);
  assert.match(script, /mobileNavigation\?\.querySelectorAll\('a'\)/);
  assert.match(script, /window\.addEventListener\('resize'/);
});

test("auth action keeps safe continuation and all required action parameters", () => {
  const html = read("auth/action/index.html");
  const script = read("auth/action/action.js");
  assert.match(html, /<meta name="robots" content="noindex,nofollow">/);
  for (const parameter of ["mode", "oobCode", "continueUrl", "preview"]) {
    assert.match(script, new RegExp(`params\\.get\\("${parameter}"\\)`), parameter);
  }
  assert.match(script, /url\.protocol === "https:"/);
  assert.match(script, /url\.hostname === "plaqa\.de"/);
  assert.match(script, /url\.hostname\.endsWith\("\.plaqa\.de"\)/);
  assert.doesNotMatch(script, /url\.protocol === "http:"/);
});

function read(relativePath) {
  return fs.readFileSync(path.join(hostingRoot, relativePath), "utf8");
}
