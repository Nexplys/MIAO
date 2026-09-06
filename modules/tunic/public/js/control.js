"use strict";

window.MiaoControlHost.registerModule("tunic", async function initializeTunicControl() {
  const api = window.MiaoApi;
  const status = window.MiaoControlHost.setStatus;
  const get = (id) => document.getElementById(`tunic-${id}`);
  const config = await api.getJson("/api/tunic/config");
  let settings = config.settings;
  let busy = false;
  let editRevision = 0;
  let actionRevision = 0;
  let lastStatus = "";
  const inputs = new Map();
  const simulationInputs = new Map();
  const fields = config.schema.groups.flatMap((group) => group.fields);

  for (const group of config.schema.groups) {
    const title = document.createElement("h3");
    title.className = "tunic-group-title";
    title.textContent = group.title;
    get("settings").appendChild(title);
    for (const field of group.fields) {
      const label = document.createElement("label");
      label.className = `tunic-setting${field.type === "string" ? " tunic-setting-path" : ""}`;
      label.htmlFor = `tunic-setting-${field.key}`;
      const name = document.createElement("span");
      name.textContent = field.label;
      const input = document.createElement("input");
      input.id = `tunic-setting-${field.key}`;
      input.type = field.type === "boolean" ? "checkbox" : field.type === "string" ? "text" : "number";
      if (field.minimum !== undefined) { input.min = field.minimum; input.max = field.maximum; }
      if (field.maximumLength) input.maxLength = field.maximumLength;
      if (field.type === "number") input.step = "0.05";
      if (field.type === "string") input.placeholder = "Détection automatique";
      if (field.description) input.title = field.description;
      input.addEventListener("input", () => { editRevision++; });
      inputs.set(field.key, input);
      label.append(name, input);
      get("settings").appendChild(label);
    }
  }

  const simulationFields = [
    ["red", "Hexagone rouge"], ["green", "Hexagone vert"], ["blue", "Hexagone bleu"],
    ["sword", "Épée"], ["laurels", "Lauriers"], ["prayer", "Prière"], ["holyCross", "Sainte-Croix"],
    ["wand", "Baguette"], ["orb", "Orbe"], ["lantern", "Lanterne"], ["mask", "Masque"],
    ["houseKey", "Clé de maison"], ["gold", "Hexagones dorés"]
  ];
  for (const [key, name] of simulationFields) {
    const label = document.createElement("label");
    label.textContent = name;
    const input = document.createElement(key === "sword" ? "select" : "input");
    input.id = `tunic-sim-${key}`;
    if (key === "sword") {
      ["Absent", "Bâton", "Épée", "Épée améliorée", "Épée ultime"].forEach((name, index) => {
        const option = document.createElement("option");
        option.value = index;
        option.textContent = name;
        input.appendChild(option);
      });
    } else {
      input.type = key === "gold" ? "number" : "checkbox";
      if (key === "gold") { input.min = 0; input.max = 999; input.value = 0; }
    }
    input.addEventListener("change", () => saveSimulation());
    simulationInputs.set(key, input);
    label.appendChild(input);
    get("simulation-items").appendChild(label);
  }

  function sizePreview() {
    const width = settings.iconSize * 7.5 + settings.gap * 4 + 16;
    const height = settings.iconSize * 2 + settings.gap + 16 + (settings.showLabels ? 32 : 0);
    const iframe = get("preview");
    const scale = Math.min(1, (iframe.parentElement.clientWidth - 2) / width);
    iframe.style.width = `${width}px`;
    iframe.style.height = `${height}px`;
    iframe.style.transformOrigin = "top left";
    iframe.style.transform = `scale(${scale})`;
    iframe.parentElement.style.height = `${Math.ceil(height * scale) + 2}px`;
  }
  function fillSettings(value) {
    settings = value;
    for (const [key, input] of inputs) {
      if (input.type === "checkbox") input.checked = value[key];
      else input.value = value[key];
    }
    sizePreview();
  }
  function collectSettings() {
    const value = { version: config.schema.version };
    for (const field of fields) {
      const input = inputs.get(field.key);
      if (!input.checkValidity()) { input.reportValidity(); throw new Error("Vérifie les réglages saisis."); }
      value[field.key] = input.type === "checkbox" ? input.checked : input.type === "number" ? Number(input.value) : input.value;
    }
    return value;
  }
  function collectSimulation() {
    return Object.fromEntries([...simulationInputs].map(([key, input]) => [key,
      input.type === "checkbox" ? Number(input.checked) : Number(input.value)]));
  }
  function showSimulation(items) {
    for (const [key, input] of simulationInputs) {
      if (input.type === "checkbox") input.checked = items[key] > 0;
      else input.value = items[key];
    }
  }
  async function action(callback) {
    if (busy) return;
    busy = true;
    actionRevision++;
    get("simulate").disabled = true;
    get("simulation-controls").disabled = true;
    get("save").disabled = true;
    get("yaml").disabled = true;
    try { await callback(); }
    catch (error) { status(error.message, "error"); }
    finally {
      busy = false;
      get("simulate").disabled = false;
      get("simulation-controls").disabled = !get("simulate").checked;
      get("save").disabled = false;
      get("yaml").disabled = false;
    }
  }
  async function saveSimulation() {
    const enabled = get("simulate").checked;
    const items = collectSimulation();
    await action(async () => {
      const state = await api.postJson("/api/tunic/simulation", { enabled, items });
      applyState(state);
      status(enabled ? "Simulation active dans le widget OBS." : "Suivi de la partie rétabli.", "ok");
    });
  }
  function applyState(state) {
    const labels = { live: "Partie détectée", waiting: "En attente d'une partie", closed: "TUNIC est fermé",
      missing: "Fichier introuvable", retrying: "Lecture en attente" };
    get("status").textContent = labels[state.status] || "Connexion…";
    get("mode").textContent = state.mode === "simulation" ? "SIMULATION" : "EN DIRECT";
    get("simulate").checked = state.mode === "simulation";
    showSimulation(state.items);
    get("simulation-controls").disabled = busy || !get("simulate").checked;
  }

  get("simulate").addEventListener("change", saveSimulation);
  for (const preset of ["start", "progress", "complete"]) {
    get(`demo-${preset}`).addEventListener("click", () => {
      const items = Object.fromEntries(simulationFields.map(([key]) => [key, 0]));
      if (preset === "progress") Object.assign(items, { red: 1, sword: 2, prayer: 1, wand: 1, orb: 1, houseKey: 1, gold: 8 });
      if (preset === "complete") {
        for (const key of Object.keys(items)) items[key] = 1;
        items.sword = 4; items.gold = settings.hexagonGoal;
      }
      showSimulation(items);
      saveSimulation();
    });
  }
  get("save").addEventListener("click", () => action(async () => {
    const value = collectSettings();
    const revision = editRevision;
    const result = await api.postJson("/api/tunic/settings", value);
    if (revision === editRevision) fillSettings(result.settings);
    lastStatus = "";
    status("Réglages Tunic enregistrés.", "ok");
  }));
  get("yaml").addEventListener("change", () => action(async () => {
    const file = get("yaml").files[0];
    if (!file) return;
    if (file.size > 65536) throw new Error("Le YAML ne doit pas dépasser 64 Kio.");
    const revision = editRevision;
    const result = await api.postJson("/api/tunic/profile", { yaml: await file.text() });
    if (revision === editRevision) fillSettings(result.settings);
    get("import-result").textContent = result.unsupported.length
      ? `Options importées. Éléments non affichés par cette grille : ${result.unsupported.join(", ")}.`
      : "Options importées : objectif, épée et capacités. Aucune donnée personnelle conservée.";
    status("Configuration Archipelago importée.", "ok");
    get("yaml").value = "";
  }));
  window.addEventListener("resize", sizePreview);
  if (window.ResizeObserver) new ResizeObserver(sizePreview).observe(get("preview").parentElement);
  fillSettings(settings);
  get("source-detail").textContent = config.detail || config.sourcePath || "Détection automatique…";

  async function refresh() {
    while (true) {
      try {
        const revision = actionRevision;
        const state = await api.getJson("/api/tunic/state");
        if (!busy && revision === actionRevision) applyState(state);
        if (lastStatus !== state.status) {
          lastStatus = state.status;
          const current = await api.getJson("/api/tunic/config");
          get("source-detail").textContent = current.detail || current.sourcePath;
        }
      } catch (_) {
        get("status").textContent = "Connexion interrompue";
        get("simulation-controls").disabled = true;
      }
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  }
  applyState(await api.getJson("/api/tunic/state"));
  refresh();
});
