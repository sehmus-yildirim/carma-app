import { initializeApp } from "https://www.gstatic.com/firebasejs/12.2.1/firebase-app.js";
import {
  applyActionCode,
  checkActionCode,
  confirmPasswordReset,
  getAuth,
  verifyPasswordResetCode,
} from "https://www.gstatic.com/firebasejs/12.2.1/firebase-auth.js";

const firebaseConfig = {
  apiKey: "AIzaSyBOv-zud409BruVEHwM7kmjWnyi9OBr0eA",
  authDomain: "auth.plaqa.de",
  projectId: "carma-a84e4",
  appId: "1:493803183324:web:7f020f8de3d24360896819",
};

const auth = getAuth(initializeApp(firebaseConfig));
auth.languageCode = "de";

const params = new URLSearchParams(window.location.search);
const mode = params.get("mode") ?? "";
const actionCode = params.get("oobCode") ?? "";
const previewMode = params.get("preview") ?? "";
const continueUrl = safeContinueUrl(params.get("continueUrl"));

const loadingState = document.querySelector("#loading-state");
const previewNote = document.querySelector("#preview-note");
const messageState = document.querySelector("#message-state");
const messageIcon = document.querySelector("#message-icon");
const messageEyebrow = document.querySelector("#message-eyebrow");
const messageTitle = document.querySelector("#message-title");
const messageText = document.querySelector("#message-text");
const messageNotice = document.querySelector("#message-notice");
const continueLink = document.querySelector("#continue-link");
const passwordForm = document.querySelector("#password-form");
const resetAccount = document.querySelector("#reset-account");
const newPassword = document.querySelector("#new-password");
const confirmPassword = document.querySelector("#confirm-password");
const passwordSubmit = document.querySelector("#password-submit");
const formError = document.querySelector("#form-error");

document.querySelectorAll(".visibility-button").forEach((button) => {
  button.addEventListener("click", () => {
    const field = document.querySelector(`#${button.dataset.target}`);
    const show = field.type === "password";
    field.type = show ? "text" : "password";
    button.textContent = show ? "Verbergen" : "Anzeigen";
    button.setAttribute("aria-label", show ? "Passwort verbergen" : "Passwort anzeigen");
  });
});

function safeContinueUrl(value) {
  if (!value) return null;
  try {
    const url = new URL(value);
    if (url.protocol === "https:" && (url.hostname === "plaqa.de" || url.hostname.endsWith(".plaqa.de"))) {
      return url.href;
    }
  } catch (_) {
    return null;
  }
  return null;
}

function showMessage({
  title,
  text,
  eyebrow = "Bestätigung abgeschlossen",
  notice = "Du kannst dieses Fenster jetzt schließen oder sicher zu plaqa weitergehen.",
  error = false,
  showContinue = true,
  continueLabel,
}) {
  loadingState.classList.add("hidden");
  passwordForm.classList.add("hidden");
  messageState.classList.remove("hidden");
  messageIcon.textContent = error ? "!" : "✓";
  messageIcon.classList.toggle("error", error);
  messageEyebrow.textContent = eyebrow;
  messageTitle.textContent = title;
  messageText.textContent = text;
  messageNotice.textContent = notice;
  continueLink.classList.toggle("hidden", !showContinue);
  continueLink.href = continueUrl ?? "https://plaqa.de";
  continueLink.textContent = continueLabel ?? (continueUrl ? "Sicher weiter" : "Zur plaqa Startseite");
}

function showPasswordForm(email) {
  loadingState.classList.add("hidden");
  messageState.classList.add("hidden");
  passwordForm.classList.remove("hidden");
  resetAccount.textContent = email ? `Für ${email}` : "Lege ein sicheres neues Passwort fest.";
  newPassword.focus();
}

function friendlyError(error) {
  switch (error?.code) {
    case "auth/expired-action-code":
      return "Dieser Link ist abgelaufen. Fordere in der plaqa App einen neuen Link an.";
    case "auth/invalid-action-code":
      return "Dieser Link ist ungültig oder wurde bereits verwendet.";
    case "auth/user-disabled":
      return "Dieses Konto ist deaktiviert. Bitte wende dich an den plaqa Support.";
    case "auth/user-not-found":
      return "Das zugehörige Konto wurde nicht gefunden.";
    case "auth/weak-password":
      return "Das Passwort ist nicht sicher genug. Verwende mindestens acht Zeichen.";
    default:
      return "Die Aktion konnte nicht abgeschlossen werden. Fordere in der plaqa App einen neuen Link an.";
  }
}

async function handleVerifyEmail({ emailChange = false } = {}) {
  await checkActionCode(auth, actionCode);
  await applyActionCode(auth, actionCode);
  showMessage({
    title: emailChange ? "Neue E-Mail-Adresse bestätigt" : "E-Mail-Adresse bestätigt",
    text: emailChange
      ? "Deine neue E-Mail-Adresse wurde sicher übernommen. Du kannst jetzt zur plaqa App zurückkehren."
      : "Deine E-Mail-Adresse wurde erfolgreich bestätigt. Dein plaqa Konto ist jetzt besser geschützt.",
    eyebrow: emailChange ? "Änderung abgeschlossen" : "Konto bestätigt",
  });
}

async function handleRecoverEmail() {
  const info = await checkActionCode(auth, actionCode);
  await applyActionCode(auth, actionCode);
  const restoredEmail = info.data.email;
  showMessage({
    title: "E-Mail Änderung zurückgenommen",
    text: restoredEmail
      ? `Deine Konto-Adresse wurde wieder auf ${restoredEmail} gesetzt.`
      : "Deine vorherige Konto-Adresse wurde wiederhergestellt.",
    eyebrow: "Sicherheitsänderung abgeschlossen",
    notice: "Prüfe deine Kontodaten in der plaqa App. Wende dich an den Support, falls du die ursprüngliche Änderung nicht selbst veranlasst hast.",
  });
}

async function handleResetPassword() {
  const email = await verifyPasswordResetCode(auth, actionCode);
  showPasswordForm(email);
}

passwordForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  formError.classList.add("hidden");

  if (previewMode === "password-reset") {
    formError.textContent = "Designvorschau: Das Passwort wird nicht verändert.";
    formError.classList.remove("hidden");
    return;
  }

  if (newPassword.value.length < 8) {
    formError.textContent = "Verwende mindestens acht Zeichen.";
    formError.classList.remove("hidden");
    return;
  }
  if (newPassword.value !== confirmPassword.value) {
    formError.textContent = "Die Passwörter stimmen nicht überein.";
    formError.classList.remove("hidden");
    return;
  }

  passwordSubmit.disabled = true;
  passwordSubmit.textContent = "Wird gespeichert ...";
  try {
    await confirmPasswordReset(auth, actionCode, newPassword.value);
    showMessage({
      title: "Passwort geändert",
      text: "Dein neues Passwort wurde gespeichert. Du kannst dich jetzt in der plaqa App anmelden.",
      eyebrow: "Passwort aktualisiert",
      notice: "Warst du das nicht? Wende dich sofort an den plaqa Support und sichere dein E-Mail-Konto.",
    });
  } catch (error) {
    formError.textContent = friendlyError(error);
    formError.classList.remove("hidden");
    passwordSubmit.disabled = false;
    passwordSubmit.textContent = "Passwort speichern";
  }
});

function renderPreview() {
  previewNote.classList.remove("hidden");
  switch (previewMode) {
    case "verify-email":
      showMessage({
        title: "E-Mail-Adresse bestätigt",
        text: "Deine E-Mail-Adresse wurde erfolgreich bestätigt. Dein plaqa Konto ist jetzt besser geschützt.",
        eyebrow: "Konto bestätigt",
      });
      return true;
    case "email-change":
      showMessage({
        title: "Neue E-Mail-Adresse bestätigt",
        text: "Deine neue E-Mail-Adresse wurde sicher übernommen. Du kannst jetzt zur plaqa App zurückkehren.",
        eyebrow: "Änderung abgeschlossen",
      });
      return true;
    case "password-reset":
      showPasswordForm("plaqa.nutzer@beispiel.de");
      return true;
    case "password-reset-success":
      showMessage({
        title: "Passwort geändert",
        text: "Dein neues Passwort wurde gespeichert. Du kannst dich jetzt in der plaqa App anmelden.",
        eyebrow: "Passwort aktualisiert",
        notice: "Warst du das nicht? Wende dich sofort an den plaqa Support und sichere dein E-Mail-Konto.",
      });
      return true;
    case "recover-email":
      showMessage({
        title: "E-Mail-Änderung zurückgenommen",
        text: "Deine vorherige Konto-Adresse wurde sicher wiederhergestellt.",
        eyebrow: "Sicherheitsänderung abgeschlossen",
        notice: "Prüfe deine Kontodaten in der plaqa App. Wende dich an den Support, falls du die ursprüngliche Änderung nicht selbst veranlasst hast.",
      });
      return true;
    case "invalid-link":
      showMessage({
        title: "Link nicht mehr gültig",
        text: "Dieser Sicherheitslink ist abgelaufen, unvollständig oder wurde bereits verwendet.",
        eyebrow: "Sicherheitsprüfung",
        notice: "Fordere die gewünschte Aktion direkt in der plaqa App erneut an. Teile Sicherheitslinks niemals mit anderen Personen.",
        error: true,
      });
      return true;
    default:
      previewNote.classList.add("hidden");
      return false;
  }
}

async function run() {
  if (renderPreview()) return;

  if (!actionCode) {
    showMessage({
      title: "Link unvollständig",
      text: "Der aufgerufene Link enthält keinen gültigen Bestätigungscode.",
      eyebrow: "Sicherheitsprüfung",
      notice: "Öffne den vollständigen Link aus der neuesten plaqa E-Mail oder fordere die Aktion in der App erneut an.",
      error: true,
    });
    return;
  }

  try {
    switch (mode) {
      case "verifyEmail":
        await handleVerifyEmail();
        break;
      case "verifyAndChangeEmail":
        await handleVerifyEmail({ emailChange: true });
        break;
      case "resetPassword":
        await handleResetPassword();
        break;
      case "recoverEmail":
        await handleRecoverEmail();
        break;
      default:
        showMessage({
          title: "Aktion nicht unterstützt",
          text: "Öffne den vollständigen Link aus deiner plaqa E-Mail erneut.",
          eyebrow: "Sicherheitsprüfung",
          notice: "Fordere die gewünschte Aktion direkt in der plaqa App erneut an, wenn der Link weiterhin nicht funktioniert.",
          error: true,
        });
    }
  } catch (error) {
    showMessage({
      title: "Aktion nicht möglich",
      text: friendlyError(error),
      eyebrow: "Sicherheitsprüfung",
      notice: "Fordere die gewünschte Aktion in der plaqa App erneut an. Bei weiteren Problemen hilft dir support@plaqa.de.",
      error: true,
    });
  }
}

run();
