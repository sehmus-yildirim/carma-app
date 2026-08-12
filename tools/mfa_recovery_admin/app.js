import {initializeApp} from "https://www.gstatic.com/firebasejs/12.1.0/firebase-app.js";
import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from "https://www.gstatic.com/firebasejs/12.1.0/firebase-auth.js";
import {
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
} from "https://www.gstatic.com/firebasejs/12.1.0/firebase-functions.js";
import {firebaseConfig, functionsRegion} from "./config.js";

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const functions = getFunctions(app, functionsRegion);
if (location.hostname === "127.0.0.1" && location.search.includes("emulator=1")) {
  connectFunctionsEmulator(functions, "127.0.0.1", 5001);
}

const call = (name) => httpsCallable(functions, name);
const listCases = call("listMfaRecoveryCases");
const openCase = call("openMfaRecoveryCase");
const verifyIdentity = call("markMfaRecoveryIdentityVerified");
const reviewCase = call("reviewMfaRecovery");
const elements = Object.fromEntries(
  [...document.querySelectorAll("[id]")].map((item) => [item.id, item]),
);

elements.signIn.addEventListener("click", async () => {
  await run(async () => {
    const credential = await signInWithEmailAndPassword(
      auth,
      elements.email.value.trim(),
      elements.password.value,
    );
    const token = await credential.user.getIdTokenResult(true);
    if (token.claims.admin !== true) {
      await signOut(auth);
      throw new Error("Dieses Konto besitzt kein gültiges Admin-Claim.");
    }
  });
});
elements.signOut.addEventListener("click", () => signOut(auth));
elements.reload.addEventListener("click", refreshCases);
elements.openCase.addEventListener("click", async () => {
  const targetUserId = elements.targetUid.value.trim();
  const confirmation = await confirmExact("Recovery-Fall öffnen", "MFA FALL ANLEGEN");
  if (confirmation == null) return;
  await run(async () => {
    await openCase({targetUserId, confirmation});
    elements.targetUid.value = "";
    await refreshCases();
  });
});

onAuthStateChanged(auth, async (user) => {
  elements.workspace.hidden = user == null;
  elements.caseSection.hidden = user == null;
  elements.signIn.hidden = user != null;
  elements.signOut.hidden = user == null;
  elements.email.disabled = user != null;
  elements.password.disabled = user != null;
  if (user != null) {
    const token = await user.getIdTokenResult(true);
    if (token.claims.admin !== true) {
      showMessage("Admin-Claim fehlt. Nach einer Claim-Änderung vollständig neu anmelden.", true);
      await signOut(auth);
      return;
    }
    await refreshCases();
  } else {
    elements.cases.replaceChildren();
  }
});

async function refreshCases() {
  await run(async () => {
    const response = await listCases({limit: 50});
    renderCases(response.data.cases ?? []);
  });
}

function renderCases(cases) {
  elements.cases.replaceChildren(...cases.map(renderCase));
  if (cases.length === 0) {
    const empty = document.createElement("p");
    empty.className = "muted";
    empty.textContent = "Keine Recovery-Fälle vorhanden.";
    elements.cases.append(empty);
  }
}

function renderCase(item) {
  const article = document.createElement("article");
  article.innerHTML = `
    <div class="case-head">
      <strong>${escapeText(item.maskedEmail || "E-Mail geschützt")}</strong>
      <span class="badge">${escapeText(statusLabel(item.status))}</span>
    </div>
    <dl>
      <dt>Ziel-UID</dt><dd>${escapeText(item.targetUserId)}</dd>
      <dt>Anfrage-ID</dt><dd>${escapeText(item.requestId)}</dd>
      <dt>Quelle</dt><dd>${escapeText(item.source || "user")}</dd>
      <dt>Faktoren</dt><dd>${Number(item.factorCount || 0)}</dd>
      <dt>Plattform</dt><dd>${escapeText(item.platform || "unbekannt")}</dd>
      <dt>Fehlerstatus</dt><dd>${escapeText(item.failureCode || "Keiner")}</dd>
    </dl>`;
  const actions = document.createElement("div");
  actions.className = "actions";
  if (item.status === "pending") {
    actions.append(actionButton("Identität extern geprüft", async () => {
      const confirmation = await confirmExact("Identitätsprüfung", "IDENTITÄT GEPRÜFT");
      if (confirmation != null) await verifyIdentity({...caseInput(item), confirmation});
    }));
  }
  if (item.status === "identity_verified") {
    actions.append(actionButton("Erste Freigabe", () => approve(item)));
  }
  if (item.status === "awaiting_second_approval") {
    actions.append(actionButton("Zweite Freigabe", () => approve(item)));
  }
  if (item.status === "processing_failed") {
    actions.append(actionButton("Technischen Abschluss wiederholen", () => approve(item)));
  }
  if (["pending", "identity_verified", "awaiting_second_approval"].includes(item.status)) {
    actions.append(actionButton("Ablehnen", async () => {
      await reviewCase({...caseInput(item), decision: "reject", reasonCode: "manual-review"});
    }, true));
  }
  article.append(actions);
  return article;
}

async function approve(item) {
  const confirmation = await confirmExact("Recovery freigeben", "MFA WIEDERHERSTELLEN");
  if (confirmation == null) return;
  await reviewCase({
    ...caseInput(item),
    decision: "approve",
    reasonCode: "identity-verified",
    confirmation,
  });
}

function actionButton(label, action, danger = false) {
  const button = document.createElement("button");
  button.textContent = label;
  if (danger) button.className = "danger";
  button.addEventListener("click", async () => {
    try {
      await action();
      await refreshCases();
    } catch (error) {
      showMessage(publicError(error), true);
    }
  });
  return button;
}

function caseInput(item) {
  return {targetUserId: item.targetUserId, requestId: item.requestId};
}

async function confirmExact(title, phrase) {
  elements.confirmationTitle.textContent = title;
  elements.confirmationPhrase.textContent = phrase;
  elements.confirmationInput.value = "";
  elements.confirmationDialog.showModal();
  const result = await new Promise((resolve) => {
    elements.confirmationDialog.addEventListener("close", () => resolve(
      elements.confirmationDialog.returnValue === "confirm" ?
        elements.confirmationInput.value.trim() : null,
    ), {once: true});
  });
  if (result != null && result !== phrase) {
    showMessage(`Exakte Bestätigung erforderlich: ${phrase}`, true);
    return null;
  }
  return result;
}

async function run(operation) {
  try {
    setBusy(true);
    await operation();
    showMessage("Aktion erfolgreich abgeschlossen.");
  } catch (error) {
    showMessage(publicError(error), true);
  } finally {
    setBusy(false);
  }
}

function setBusy(value) {
  document.querySelectorAll("button").forEach((button) => {
    button.disabled = value;
  });
}

function showMessage(message, isError = false) {
  elements.message.textContent = message;
  elements.message.className = isError ? "error" : "success";
}

function publicError(error) {
  const code = String(error?.code ?? "");
  if (code.includes("permission-denied")) return "Diese Admin-Aktion ist nicht erlaubt.";
  if (code.includes("unauthenticated")) return "Die Sitzung ist abgelaufen. Bitte neu anmelden.";
  return error?.message || "Die Aktion konnte nicht abgeschlossen werden.";
}

function statusLabel(status) {
  return ({
    pending: "Offen",
    identity_verified: "Identität geprüft",
    awaiting_second_approval: "Zweite Freigabe erforderlich",
    processing: "Technische Verarbeitung",
    processing_failed: "Technischer Fehler",
    completed: "Abgeschlossen",
    rejected: "Abgelehnt",
  })[status] ?? "Unbekannt";
}

function escapeText(value) {
  const span = document.createElement("span");
  span.textContent = String(value ?? "");
  return span.innerHTML;
}
