const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");

const hostingRoot = path.resolve(__dirname, "..", "..", "hosting");

const mimeTypes = new Map([
  [".css", "text/css; charset=utf-8"],
  [".html", "text/html; charset=utf-8"],
  [".ico", "image/x-icon"],
  [".jpeg", "image/jpeg"],
  [".jpg", "image/jpeg"],
  [".js", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".png", "image/png"],
  [".svg", "image/svg+xml"],
  [".txt", "text/plain; charset=utf-8"],
  [".xml", "application/xml; charset=utf-8"],
]);

function resolveHostingRequest(pathname) {
  let decoded;
  try {
    decoded = decodeURIComponent(pathname);
  } catch {
    return {status: 400};
  }

  if (decoded.includes("\0") || decoded.includes("\\")) {
    return {status: 400};
  }

  if (decoded !== "/" && decoded.endsWith("/")) {
    const slashTarget = safePath(decoded.slice(1), "index.html");
    if (slashTarget && isFile(slashTarget)) {
      return {status: 301, redirect: decoded.slice(0, -1)};
    }
  }

  if (decoded === "/") {
    return {status: 200, filePath: path.join(hostingRoot, "index.html")};
  }

  const relativePath = decoded.replace(/^\/+/, "");
  const directPath = safePath(relativePath);
  if (directPath && isFile(directPath)) {
    return {status: 200, filePath: directPath};
  }

  const cleanHtmlPath = safePath(`${relativePath}.html`);
  if (cleanHtmlPath && isFile(cleanHtmlPath)) {
    return {status: 200, filePath: cleanHtmlPath};
  }

  const directoryIndex = safePath(relativePath, "index.html");
  if (directoryIndex && isFile(directoryIndex)) {
    return {status: 200, filePath: directoryIndex};
  }

  return {status: 404, filePath: path.join(hostingRoot, "404.html")};
}

async function startWebsiteServer() {
  const server = http.createServer((request, response) => {
    const requestUrl = new URL(request.url || "/", "http://127.0.0.1");
    const resolved = resolveHostingRequest(requestUrl.pathname);

    if (resolved.redirect) {
      response.writeHead(resolved.status, {
        Location: `${resolved.redirect}${requestUrl.search}`,
        "Cache-Control": "no-store",
      });
      response.end();
      return;
    }

    if (!resolved.filePath) {
      response.writeHead(resolved.status, {"Content-Type": "text/plain; charset=utf-8"});
      response.end("Ungültige Anfrage");
      return;
    }

    let body = fs.readFileSync(resolved.filePath);
    const extension = path.extname(resolved.filePath).toLowerCase();
    if (extension === ".html" && requestUrl.searchParams.has("__qa")) {
      body = Buffer.from(injectQaProbe(body.toString("utf8")), "utf8");
    }

    response.writeHead(resolved.status, {
      "Content-Type": mimeTypes.get(extension) || "application/octet-stream",
      "Content-Length": body.length,
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    });
    response.end(body);
  });

  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });

  const address = server.address();
  return {
    baseUrl: `http://127.0.0.1:${address.port}`,
    close: () => new Promise((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    }),
  };
}

function injectQaProbe(html) {
  const script = `<script>(${qaProbe.toString()})();</script>`;
  return html.includes("</head>")
    ? html.replace("</head>", `${script}</head>`)
    : `${script}${html}`;
}

function qaProbe() {
  const errors = [];
  window.addEventListener("error", (event) => {
    errors.push(event.message || "Unbekannter Seitenfehler");
  });
  window.addEventListener("unhandledrejection", (event) => {
    errors.push(String(event.reason || "Unbehandelte Promise-Ablehnung"));
  });

  window.addEventListener("load", () => {
    window.setTimeout(() => {
      const menuButton = document.querySelector(".menu-button");
      const mobileNavigation = document.querySelector("#mobile-navigation");
      let menu = null;

      if (menuButton && mobileNavigation) {
        const before = {
          expanded: menuButton.getAttribute("aria-expanded"),
          hidden: mobileNavigation.hidden,
        };
        menuButton.click();
        const afterOpen = {
          expanded: menuButton.getAttribute("aria-expanded"),
          hidden: mobileNavigation.hidden,
        };
        menuButton.click();
        const afterClose = {
          expanded: menuButton.getAttribute("aria-expanded"),
          hidden: mobileNavigation.hidden,
        };
        menu = {before, afterOpen, afterClose};
      }

      const result = {
        title: document.title,
        h1: document.querySelector("h1")?.textContent?.trim() || "",
        viewportWidth: window.innerWidth,
        documentWidth: document.documentElement.scrollWidth,
        bodyWidth: document.body.scrollWidth,
        horizontalOverflow:
          document.documentElement.scrollWidth > window.innerWidth + 1 ||
          document.body.scrollWidth > window.innerWidth + 1,
        brokenImages: Array.from(document.images)
          .filter((image) => !image.complete || image.naturalWidth === 0)
          .map((image) => image.getAttribute("src") || ""),
        errors,
        menu,
      };

      document.documentElement.innerHTML =
        '<head><meta charset="utf-8"><title>QA result</title></head>' +
        '<body><pre id="qa-result"></pre></body>';
      document.querySelector("#qa-result").textContent = JSON.stringify(result);
    }, 350);
  });
}

function safePath(...segments) {
  const candidate = path.resolve(hostingRoot, ...segments);
  if (candidate === hostingRoot || candidate.startsWith(`${hostingRoot}${path.sep}`)) {
    return candidate;
  }
  return null;
}

function isFile(filePath) {
  try {
    return fs.statSync(filePath).isFile();
  } catch {
    return false;
  }
}

module.exports = {
  hostingRoot,
  resolveHostingRequest,
  startWebsiteServer,
};
