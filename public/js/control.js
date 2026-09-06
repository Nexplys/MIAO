"use strict";

(function startMiaoControl() {
  const messageInput = document.getElementById("message");
  const statsElement = document.getElementById("stats");
  const statusElement = document.getElementById("status");
  const currentSongElement = document.getElementById("current-song");
  const transmissionSettings = document.getElementById("transmission-settings");
  const displaySettings = document.getElementById("display-settings");
  const playerActions = document.getElementById("player-actions");
  const shortcutList = document.getElementById("shortcut-list");

  let schema = null;
  let settings = {};
  let messageTimer = null;
  let settingsTimer = null;
  let messageQueue = Promise.resolve();
  let settingsQueue = Promise.resolve();
  let lastSavedMessage = "";
  let messageEditRevision = 0;
  let settingsEditRevision = 0;
  let applicationReady = false;

  function normalizeLineEndings(value) {
    return String(value || "").replace(/\r\n?/g, "\n");
  }

  function normalizeMission(value) {
    return normalizeLineEndings(value).replace(/\0/g, "").trim();
  }

  function setStatus(message, type = "") {
    statusElement.textContent = message;
    statusElement.className = `status ${type}`.trim();
  }

  function createElement(tagName, options = {}) {
    const element = document.createElement(tagName);
    if (options.className) element.className = options.className;
    if (options.text !== undefined) element.textContent = options.text;
    return element;
  }

  function getAllFields() {
    if (!schema) return [];
    return schema.groups.flatMap((group) => group.fields);
  }

  function getDefaultSettings() {
    const defaults = { version: schema.version };
    for (const field of getAllFields()) {
      defaults[field.key] = field.default;
    }
    return defaults;
  }

  function createSwitchField(field) {
    const row = createElement("div", { className: "switch-row" });
    const copy = createElement("div", { className: "switch-copy" });
    copy.appendChild(createElement("strong", { text: field.label }));
    if (field.description) {
      copy.appendChild(createElement("small", { text: field.description }));
    }

    const label = createElement("label", { className: "switch" });
    label.setAttribute("aria-label", field.label);
    const input = document.createElement("input");
    input.type = "checkbox";
    input.dataset.setting = field.key;
    label.append(input, createElement("span", { className: "slider" }));
    row.append(copy, label);
    return row;
  }

  function configureInput(input, field) {
    input.dataset.setting = field.key;
    if (field.minimum !== undefined) input.min = field.minimum;
    if (field.maximum !== undefined) input.max = field.maximum;
    if (field.step !== undefined) input.step = field.step;
    if (field.maximumLength !== undefined) input.maxLength = field.maximumLength;
  }

  function createStandardField(field) {
    const wrapper = createElement("div", {
      className: `field${field.wide ? " full" : ""}`
    });
    const label = createElement("label", {
      className: "field-label",
      text: field.label
    });
    label.htmlFor = `setting-${field.key}`;

    let input;
    if (field.type === "select") {
      input = document.createElement("select");
      for (const optionDefinition of field.options) {
        const option = document.createElement("option");
        option.value = optionDefinition.value;
        option.textContent = optionDefinition.label;
        input.appendChild(option);
      }
    } else {
      input = document.createElement("input");
      input.type = field.type === "color"
        ? "color"
        : ["integer", "number"].includes(field.type)
          ? "number"
          : "text";
    }

    input.id = `setting-${field.key}`;
    configureInput(input, field);
    wrapper.appendChild(label);

    if (field.unit) {
      const unitWrapper = createElement("div", { className: "unit-input" });
      unitWrapper.append(input, createElement("span", {
        className: "unit",
        text: field.unit
      }));
      wrapper.appendChild(unitWrapper);
    } else {
      wrapper.appendChild(input);
    }

    if (field.description) {
      wrapper.appendChild(createElement("small", {
        className: "field-description",
        text: field.description
      }));
    }

    return wrapper;
  }

  function createGroup(group) {
    const container = group.presentation === "card"
      ? createElement("div", { className: "card" })
      : document.createElement("details");

    if (container.tagName === "DETAILS") {
      container.open = Boolean(group.open);
      container.appendChild(createElement("summary", { text: group.title }));
    } else {
      container.appendChild(createElement("h2", {
        className: "section-title",
        text: group.title
      }));
    }

    const content = container.tagName === "DETAILS"
      ? createElement("div", { className: "details-content" })
      : container;
    const grid = createElement("div", { className: "grid" });
    let hasGridFields = false;

    for (const field of group.fields) {
      if (field.type === "boolean") {
        content.appendChild(createSwitchField(field));
      } else {
        grid.appendChild(createStandardField(field));
        hasGridFields = true;
      }
    }

    if (hasGridFields) content.appendChild(grid);
    if (content !== container) container.appendChild(content);
    return container;
  }

  function renderSettingsForm() {
    transmissionSettings.replaceChildren();
    displaySettings.replaceChildren();

    for (const group of schema.groups) {
      const target = group.tab === "transmission"
        ? transmissionSettings
        : displaySettings;
      target.appendChild(createGroup(group));
    }

    bindSettingEvents();
  }

  function renderPlayer(configuration) {
    playerActions.replaceChildren();
    shortcutList.replaceChildren();

    for (const action of configuration.actions) {
      const button = createElement("button", {
        className: `action ${action.tone || ""}`.trim(),
        text: action.label
      });
      button.type = "button";
      button.addEventListener("click", () => sendPlayerAction(action));
      playerActions.appendChild(button);

      shortcutList.append(
        createElement("span", { text: action.label }),
        createElement("code", {
          text: `${configuration.shortcutPrefix}${action.key}`
        })
      );
    }
  }

  function getSettingInputs() {
    return Array.from(document.querySelectorAll("[data-setting]"));
  }

  function fillSettings(nextSettings) {
    settings = { ...getDefaultSettings(), ...(nextSettings || {}) };

    for (const input of getSettingInputs()) {
      const value = settings[input.dataset.setting];
      if (input.type === "checkbox") input.checked = Boolean(value);
      else input.value = value;
    }
  }

  function collectSettings() {
    const nextSettings = { ...settings };

    for (const input of getSettingInputs()) {
      const key = input.dataset.setting;
      if (input.type === "checkbox") nextSettings[key] = input.checked;
      else if (input.type === "number") nextSettings[key] = Number(input.value);
      else nextSettings[key] = input.value;
    }

    return nextSettings;
  }

  function renderStats() {
    const text = normalizeLineEndings(messageInput.value);
    const characters = text.length;
    const lines = text.length === 0 ? 0 : text.split("\n").length;
    statsElement.textContent = `${lines} ${lines === 1 ? "ligne" : "lignes"} · ${characters} ${characters === 1 ? "caractère" : "caractères"}`;
    statsElement.classList.toggle("warning", lines > 6 || characters > 260);
  }

  async function sendMessage(text, revision) {
    setStatus("Synchronisation de la transmission…");
    const result = await window.MiaoApi.postJson("/api/mission", { text });
    lastSavedMessage = normalizeMission(result.mission);
    if (revision === messageEditRevision) {
      messageInput.value = lastSavedMessage;
      renderStats();
      setStatus(lastSavedMessage ? "Transmission synchronisée." : "Transmission vide enregistrée.", "ok");
    }
  }

  function queueMessageSave() {
    if (!applicationReady) {
      setStatus("La console n’est pas encore prête.", "error");
      return;
    }

    clearTimeout(messageTimer);
    const snapshot = normalizeMission(messageInput.value);
    const revision = messageEditRevision;
    messageQueue = messageQueue
      .then(() => sendMessage(snapshot, revision))
      .catch((error) => setStatus(error.message, "error"));
  }

  function scheduleMessageSave() {
    clearTimeout(messageTimer);
    setStatus("Modification de la transmission en attente…");
    messageTimer = setTimeout(queueMessageSave, 650);
  }

  async function sendSettings(nextSettings, revision) {
    setStatus("Application des réglages…");
    const result = await window.MiaoApi.postJson("/api/settings", nextSettings);
    settings = { ...getDefaultSettings(), ...result.settings };
    if (revision === settingsEditRevision) {
      fillSettings(result.settings);
      setStatus("Réglages appliqués à l’affichage.", "ok");
    }
  }

  function queueSettingsSave() {
    if (!applicationReady || !schema) {
      setStatus("La configuration n’est pas encore chargée.", "error");
      return;
    }

    clearTimeout(settingsTimer);
    const snapshot = collectSettings();
    const revision = settingsEditRevision;
    settingsQueue = settingsQueue
      .then(() => sendSettings(snapshot, revision))
      .catch((error) => setStatus(error.message, "error"));
  }

  function scheduleSettingsSave(immediate = false) {
    clearTimeout(settingsTimer);
    setStatus("Modification des réglages en attente…");
    settingsTimer = setTimeout(queueSettingsSave, immediate ? 0 : 450);
  }

  function bindSettingEvents() {
    for (const input of getSettingInputs()) {
      input.addEventListener("input", () => {
        settingsEditRevision += 1;
        if (input.type !== "checkbox") scheduleSettingsSave();
      });
      input.addEventListener("change", () => {
        if (input.type === "checkbox" || input.tagName === "SELECT") {
          scheduleSettingsSave(true);
        }
      });
    }
  }

  async function sendPlayerAction(action) {
    if (action.confirmation && !window.confirm(action.confirmation)) return;

    try {
      setStatus("Transmission de la commande à Moobot…");
      const result = await window.MiaoApi.postJson("/api/player", {
        action: action.id
      });
      setStatus(result.message || "Commande envoyée.", "ok");
    } catch (error) {
      setStatus(error.message, "error");
    }
  }

  async function loadApplication() {
    try {
      const [stateResult, schemaResult, playerResult] = await Promise.all([
        window.MiaoApi.getJson("/api/state"),
        window.MiaoApi.getJson("/api/schema"),
        window.MiaoApi.getJson("/api/player/actions")
      ]);

      schema = schemaResult.schema;
      renderSettingsForm();
      renderPlayer(playerResult.configuration);
      fillSettings(stateResult.settings);
      messageInput.value = normalizeMission(stateResult.mission);
      lastSavedMessage = messageInput.value;
      currentSongElement.textContent = stateResult.song || "Aucun morceau détecté";
      renderStats();
      applicationReady = true;
      setStatus("Console connectée.", "ok");
    } catch (error) {
      setStatus(`Impossible de charger M.I.A.O. : ${error.message}`, "error");
    }
  }

  async function reloadState() {
    const result = await window.MiaoApi.getJson("/api/state");
    settingsEditRevision += 1;
    messageEditRevision += 1;
    fillSettings(result.settings);
    messageInput.value = normalizeMission(result.mission);
    lastSavedMessage = messageInput.value;
    currentSongElement.textContent = result.song || "Aucun morceau détecté";
    renderStats();
  }

  async function refreshSong() {
    try {
      const result = await window.MiaoApi.getJson("/api/song");
      currentSongElement.textContent = result.song || "Aucun morceau détecté";
    } catch (_) {
      // The next refresh retries automatically.
    }
  }

  document.querySelectorAll("[data-tab]").forEach((button) => {
    button.addEventListener("click", () => {
      document.querySelectorAll("[data-tab]").forEach((tab) => tab.classList.remove("active"));
      document.querySelectorAll("[data-panel]").forEach((panel) => panel.classList.remove("active"));
      button.classList.add("active");
      document.querySelector(`[data-panel="${button.dataset.tab}"]`).classList.add("active");
    });
  });

  messageInput.addEventListener("input", () => {
    messageEditRevision += 1;
    renderStats();
    scheduleMessageSave();
  });

  messageInput.addEventListener("keydown", (event) => {
    if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
      event.preventDefault();
      queueMessageSave();
    }
  });

  document.getElementById("save-message").addEventListener("click", queueMessageSave);
  document.getElementById("save-settings").addEventListener("click", queueSettingsSave);

  document.getElementById("reload").addEventListener("click", async () => {
    if (!applicationReady) {
      setStatus("La console n’est pas encore prête.", "error");
      return;
    }

    const missionChanged = normalizeMission(messageInput.value) !== lastSavedMessage;
    const settingsChanged = schema &&
      JSON.stringify(collectSettings()) !== JSON.stringify(settings);

    if ((missionChanged || settingsChanged) &&
        !window.confirm("Abandonner les modifications non enregistrées ?")) {
      return;
    }

    try {
      clearTimeout(messageTimer);
      clearTimeout(settingsTimer);
      await Promise.all([messageQueue, settingsQueue]);
      await reloadState();
      setStatus("Dernière version rechargée.", "ok");
    } catch (error) {
      setStatus(error.message, "error");
    }
  });

  document.getElementById("reset-settings").addEventListener("click", async () => {
    if (!applicationReady || !schema) {
      setStatus("La configuration n’est pas encore chargée.", "error");
      return;
    }
    if (!window.confirm("Rétablir tous les réglages d’affichage par défaut ?")) return;

    try {
      clearTimeout(settingsTimer);
      const revision = settingsEditRevision + 1;
      settingsEditRevision = revision;
      settingsQueue = settingsQueue
        .then(async () => {
          const result = await window.MiaoApi.postJson("/api/settings/reset");
          settings = { ...getDefaultSettings(), ...result.settings };
          if (revision === settingsEditRevision) {
            fillSettings(result.settings);
            setStatus("Valeurs par défaut restaurées.", "ok");
          }
        })
        .catch((error) => setStatus(error.message, "error"));
      await settingsQueue;
    } catch (error) {
      setStatus(error.message, "error");
    }
  });

  loadApplication();
  setInterval(refreshSong, 1000);
})();
