(function initializePlaqaContactForms(root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  }
  if (root != null) {
    root.PlaqaContactForms = api;
    if (root.document != null) {
      const start = () => api.initializeContactForms(root.document);
      if (root.document.readyState === "loading") {
        root.document.addEventListener("DOMContentLoaded", start, {once: true});
      } else {
        start();
      }
    }
  }
})(typeof window === "undefined" ? globalThis : window, function contactFormFactory() {
  "use strict";

  const maxRequestBytes = 16 * 1024;
  const minimumFillTimeMs = 1500;
  const maximumFillTimeMs = 2 * 60 * 60 * 1000;
  const localFunctionEndpoint =
    "http://127.0.0.1:5001/carma-a84e4/europe-west3/submitWebsiteContact";
  const emailPattern = /^[^\s@]+@(?:[^\s@.]+\.)+[^\s@.]{2,}$/;
  const forbiddenHeaderCharacters = /[\u0000-\u001f\u007f]/;
  const forbiddenTextCharacters = /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/;

  const channelDefinitions = Object.freeze({
    support: Object.freeze({
      fields: [
        "channel", "category", "email", "subject", "message",
        "appVersion", "device", "honeypot", "startedAt",
      ],
      categories: [
        "technical_issue", "account_access", "verification", "feedback", "other",
      ],
    }),
    privacy: Object.freeze({
      fields: [
        "channel", "requestType", "email", "message", "honeypot", "startedAt",
      ],
      categories: [
        "access", "correction", "deletion", "restriction", "objection",
        "portability", "other",
      ],
    }),
    partners: Object.freeze({
      fields: [
        "channel", "name", "organization", "email", "partnershipType",
        "message", "honeypot", "startedAt",
      ],
      categories: [
        "strategic", "business", "technology", "media", "community", "other",
      ],
    }),
    report: Object.freeze({
      fields: [
        "channel", "category", "reference", "description", "contactEmail",
        "honeypot", "startedAt",
      ],
      categories: [
        "content", "profile", "harassment", "minor_safety", "fraud", "other",
      ],
    }),
  });

  const responseMessages = Object.freeze({
    400: "Bitte prüfe die markierten Eingaben und versuche es erneut.",
    403: "Diese Anfrage ist über den aktuellen Aufruf nicht möglich. Öffne die Seite bitte neu.",
    405: "Bitte sende das Formular erneut über diese Website.",
    413: "Die Anfrage ist zu groß. Bitte kürze deine Nachricht.",
    415: "Bitte lade die Seite neu und sende das Formular erneut.",
    429: "Du hast in kurzer Zeit mehrere Anfragen gesendet. Bitte versuche es später erneut.",
    500: "Die Anfrage konnte gerade nicht verarbeitet werden. Bitte versuche es später erneut.",
    503: "Der Versand ist momentan nicht verfügbar. Nutze bitte die angezeigte E-Mail-Adresse oder versuche es später erneut.",
  });

  function initializeContactForms(documentRoot, dependencies = {}) {
    return Array.from(documentRoot.querySelectorAll("[data-contact-form]"))
      .map((form) => createContactFormController(form, dependencies));
  }

  function createContactFormController(form, dependencies = {}) {
    const channel = String(form.dataset.contactForm || "");
    const definition = channelDefinitions[channel];
    if (definition == null) return null;

    const now = dependencies.now || (() => Date.now());
    const locationLike = dependencies.location || globalThis.location;
    const fetchRequest = dependencies.fetchImpl ||
      ((...argumentsList) => globalThis.fetch(...argumentsList));
    const status = form.parentElement?.querySelector("[data-contact-status]");
    const submitButton = form.querySelector("button[type='submit']");
    const retryButton = status?.querySelector("[data-contact-retry]");
    const startedAt = form.elements.namedItem("startedAt");
    if (startedAt != null) startedAt.value = String(now());

    bindCharacterCounters(form);
    retryButton?.addEventListener("click", () => {
      hideStatus(status);
      const firstControl = form.querySelector("input:not([type='hidden']), select, textarea");
      firstControl?.focus();
    });

    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      hideStatus(status);
      clearFieldErrors(form);

      const values = valuesFromForm(form);
      const validation = validateChannelValues(channel, values, now());
      if (!validation.valid) {
        applyFieldErrors(form, validation.errors);
        showStatus(status, {
          type: "error",
          title: "Eingaben prüfen",
          message: validation.errors._form || responseMessages[400],
          retry: false,
        });
        focusFirstInvalidField(form, validation.errors);
        return;
      }

      const endpoint = endpointForLocation(locationLike);
      if (endpoint.length === 0) {
        showStatus(status, {
          type: "error",
          title: "Formular noch nicht freigeschaltet",
          message: "Der Online-Versand ist noch nicht veröffentlicht. Nutze bitte die unten angezeigte E-Mail-Adresse.",
          retry: false,
        });
        status?.focus();
        return;
      }

      setLoadingState(form, submitButton, true);
      try {
        const result = await submitContactPayload({
          endpoint,
          payload: validation.payload,
          fetchImpl: fetchRequest,
        });
        if (!result.accepted) {
          showStatus(status, {
            type: "error",
            title: "Anfrage nicht gesendet",
            message: responseMessageForStatus(result.status),
            retry: result.status >= 500,
          });
          status?.focus();
          return;
        }

        form.hidden = true;
        form.reset();
        if (startedAt != null) startedAt.value = String(now());
        showStatus(status, {
          type: "success",
          title: "Anfrage erhalten",
          message: "Deine Anfrage wurde sicher übermittelt. Bewahre die Anfrage-ID für Rückfragen auf.",
          requestId: result.requestId,
          retry: false,
        });
        status?.focus();
      } catch (_) {
        showStatus(status, {
          type: "error",
          title: "Verbindung unterbrochen",
          message: responseMessages[503],
          retry: true,
        });
        status?.focus();
      } finally {
        setLoadingState(form, submitButton, false);
      }
    });

    return Object.freeze({channel, form});
  }

  function valuesFromForm(form) {
    const values = {};
    new FormData(form).forEach((value, key) => {
      if (typeof value === "string") values[key] = value;
    });
    return values;
  }

  function validateChannelValues(channel, rawValues, nowMs = Date.now()) {
    const definition = channelDefinitions[channel];
    if (definition == null) {
      return invalidResult({_form: "Bitte wähle einen gültigen Kontaktweg."});
    }

    const values = rawValues != null && typeof rawValues === "object" ? rawValues : {};
    const payload = {channel};
    const errors = {};
    const honeypot = stringValue(values.honeypot);
    const startedAt = Number(values.startedAt);
    payload.honeypot = honeypot;
    payload.startedAt = startedAt;

    if (honeypot.length !== 0) {
      errors._form = "Diese Anfrage konnte nicht verarbeitet werden.";
    }
    const elapsed = nowMs - startedAt;
    if (!Number.isInteger(startedAt) || elapsed < minimumFillTimeMs || elapsed > maximumFillTimeMs) {
      errors._form = "Bitte lade das Formular neu und versuche es erneut.";
    }

    if (channel === "support") {
      payload.category = categoryValue(values.category, definition.categories, "category", errors);
      payload.email = emailValue(values.email, true, "email", errors);
      payload.subject = headerValue(values.subject, 5, 120, "subject", errors);
      payload.message = textValue(values.message, 20, 5000, "message", errors);
      payload.appVersion = optionalHeaderValue(values.appVersion, 40, "appVersion", errors);
      payload.device = optionalHeaderValue(values.device, 120, "device", errors);
    } else if (channel === "privacy") {
      payload.requestType = categoryValue(values.requestType, definition.categories, "requestType", errors);
      payload.email = emailValue(values.email, true, "email", errors);
      payload.message = textValue(values.message, 20, 5000, "message", errors);
    } else if (channel === "partners") {
      payload.name = headerValue(values.name, 2, 100, "name", errors);
      payload.organization = optionalHeaderValue(values.organization, 160, "organization", errors);
      payload.email = emailValue(values.email, true, "email", errors);
      payload.partnershipType = categoryValue(
        values.partnershipType,
        definition.categories,
        "partnershipType",
        errors,
      );
      payload.message = textValue(values.message, 20, 5000, "message", errors);
    } else if (channel === "report") {
      payload.category = categoryValue(values.category, definition.categories, "category", errors);
      payload.reference = optionalTextValue(values.reference, 300, "reference", errors);
      payload.description = textValue(values.description, 20, 5000, "description", errors);
      payload.contactEmail = emailValue(values.contactEmail, false, "contactEmail", errors);
    }

    if (Object.keys(payload).some((key) => !definition.fields.includes(key))) {
      errors._form = "Bitte prüfe deine Eingaben und versuche es erneut.";
    }
    if (requestByteLength(payload) > maxRequestBytes) {
      errors._form = "Die Anfrage ist zu groß. Bitte kürze deine Nachricht.";
    }
    return Object.keys(errors).length === 0 ?
      {valid: true, payload: Object.freeze(payload), errors: {}} :
      invalidResult(errors);
  }

  function categoryValue(value, allowed, field, errors) {
    const normalized = normalizeHeader(value);
    if (!allowed.includes(normalized)) {
      errors[field] = "Bitte wähle eine gültige Option.";
    }
    return normalized;
  }

  function emailValue(value, required, field, errors) {
    const normalized = normalizeHeader(value).toLowerCase();
    if (normalized.length === 0 && !required) return "";
    if (normalized.length === 0 || normalized.length > 254 || !emailPattern.test(normalized)) {
      errors[field] = "Bitte gib eine gültige E-Mail-Adresse ein.";
    }
    return normalized;
  }

  function headerValue(value, minimum, maximum, field, errors) {
    const original = stringValue(value);
    const normalized = normalizeHeader(original);
    if (forbiddenHeaderCharacters.test(original) ||
        normalized.length < minimum || normalized.length > maximum) {
      errors[field] = `Bitte gib zwischen ${minimum} und ${maximum} Zeichen ein.`;
    }
    return normalized;
  }

  function optionalHeaderValue(value, maximum, field, errors) {
    const original = stringValue(value);
    const normalized = normalizeHeader(original);
    if (forbiddenHeaderCharacters.test(original) || normalized.length > maximum) {
      errors[field] = `Bitte verwende höchstens ${maximum} Zeichen.`;
    }
    return normalized;
  }

  function textValue(value, minimum, maximum, field, errors) {
    const original = stringValue(value);
    const normalized = normalizeText(original);
    if (forbiddenTextCharacters.test(original) ||
        normalized.length < minimum || normalized.length > maximum) {
      errors[field] = `Bitte gib zwischen ${minimum} und ${maximum} Zeichen ein.`;
    }
    return normalized;
  }

  function optionalTextValue(value, maximum, field, errors) {
    const original = stringValue(value);
    const normalized = normalizeText(original);
    if (forbiddenTextCharacters.test(original) || normalized.length > maximum) {
      errors[field] = `Bitte verwende höchstens ${maximum} Zeichen.`;
    }
    return normalized;
  }

  function normalizeHeader(value) {
    return stringValue(value).trim().replace(/\s+/g, " ");
  }

  function normalizeText(value) {
    return stringValue(value).replace(/\r\n?/g, "\n").trim();
  }

  function stringValue(value) {
    return typeof value === "string" ? value : "";
  }

  function invalidResult(errors) {
    return {valid: false, payload: null, errors: Object.freeze(errors)};
  }

  function requestByteLength(payload) {
    const serialized = JSON.stringify(payload);
    if (typeof TextEncoder === "function") {
      return new TextEncoder().encode(serialized).length;
    }
    return Buffer.byteLength(serialized, "utf8");
  }

  function endpointForLocation(locationLike) {
    const hostname = String(locationLike?.hostname || "").toLowerCase();
    return hostname === "localhost" || hostname === "127.0.0.1" ?
      localFunctionEndpoint : "";
  }

  async function submitContactPayload({endpoint, payload, fetchImpl}) {
    const response = await fetchImpl(endpoint, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(payload),
    });
    let body = {};
    try {
      body = await response.json();
    } catch (_) {
      body = {};
    }
    return {
      accepted: response.status === 202 && body.accepted === true,
      status: response.status,
      requestId: safeRequestId(body.requestId),
    };
  }

  function responseMessageForStatus(status) {
    return responseMessages[status] || responseMessages[500];
  }

  function safeRequestId(value) {
    const requestId = stringValue(value);
    return /^[A-Za-z0-9_-]{8,128}$/.test(requestId) ? requestId : "Nicht verfügbar";
  }

  function clearFieldErrors(form) {
    form.querySelectorAll("[aria-invalid='true']").forEach((control) => {
      control.removeAttribute("aria-invalid");
    });
    form.querySelectorAll("[data-field-error]").forEach((element) => {
      element.textContent = "";
    });
  }

  function applyFieldErrors(form, errors) {
    Object.entries(errors).forEach(([field, message]) => {
      if (field === "_form") return;
      const control = form.elements.namedItem(field);
      const error = form.querySelector(`[data-field-error="${field}"]`);
      control?.setAttribute("aria-invalid", "true");
      if (error != null) error.textContent = message;
    });
  }

  function focusFirstInvalidField(form, errors) {
    const firstField = Object.keys(errors).find((field) => field !== "_form");
    if (firstField != null) {
      form.elements.namedItem(firstField)?.focus();
    }
  }

  function setLoadingState(form, button, loading) {
    form.setAttribute("aria-busy", String(loading));
    if (button == null) return;
    button.disabled = loading;
    const label = button.querySelector("[data-submit-label]");
    if (label != null) {
      label.textContent = loading ? "Wird gesendet …" : String(button.dataset.label || "Anfrage senden");
    }
  }

  function showStatus(status, {type, title, message, requestId = "", retry}) {
    if (status == null) return;
    status.hidden = false;
    status.dataset.statusType = type;
    const titleElement = status.querySelector("[data-status-title]");
    const messageElement = status.querySelector("[data-status-message]");
    const requestElement = status.querySelector("[data-status-request]");
    const retryElement = status.querySelector("[data-contact-retry]");
    if (titleElement != null) titleElement.textContent = title;
    if (messageElement != null) messageElement.textContent = message;
    if (requestElement != null) {
      requestElement.textContent = requestId.length === 0 ? "" : `Anfrage-ID: ${requestId}`;
      requestElement.hidden = requestId.length === 0;
    }
    if (retryElement != null) retryElement.hidden = !retry;
  }

  function hideStatus(status) {
    if (status == null) return;
    status.hidden = true;
    status.removeAttribute("data-status-type");
  }

  function bindCharacterCounters(form) {
    form.querySelectorAll("[data-character-field]").forEach((field) => {
      const counter = form.querySelector(`[data-character-count="${field.name}"]`);
      if (counter == null) return;
      const update = () => {
        counter.textContent = `${field.value.length} / ${field.maxLength}`;
      };
      field.addEventListener("input", update);
      update();
    });
  }

  return Object.freeze({
    channelDefinitions,
    endpointForLocation,
    initializeContactForms,
    requestByteLength,
    responseMessageForStatus,
    submitContactPayload,
    validateChannelValues,
  });
});
