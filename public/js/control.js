"use strict";

(function startMiaoControlHost() {
  const tabsElement = document.getElementById("module-tabs");
  const panelsElement = document.getElementById("module-panels");
  const statusElement = document.getElementById("status");
  const loadedStyles = new Map();
  const loadedScripts = new Map();
  const moduleInitializers = new Map();
  let activeModuleId = "";

  function setStatus(message, type = "") {
    statusElement.textContent = message;
    statusElement.className = `status ${type}`.trim();
  }

  function assertModuleUrl(moduleId, url) {
    const value = String(url || "");
    const prefix = `/modules/${moduleId}/`;
    let decoded = "";
    try {
      decoded = decodeURIComponent(value.slice(prefix.length));
    } catch (_) {
      throw new Error(`Ressource invalide déclarée par le module ${moduleId}.`);
    }
    const segments = decoded.split("/");
    if (!value.startsWith(prefix) || /[?#\\]/.test(value) || /[?#\\]/.test(decoded) ||
        segments.some((segment) => !segment || segment === "." || segment === "..")) {
      throw new Error(`Ressource invalide déclarée par le module ${moduleId}.`);
    }
    return value;
  }

  function registerModule(moduleId, initializer) {
    if (!/^[a-z][a-z0-9-]*$/.test(moduleId) || typeof initializer !== "function") {
      throw new Error("Initialiseur de module invalide.");
    }
    if (moduleInitializers.has(moduleId)) {
      throw new Error(`Le module ${moduleId} est déjà enregistré.`);
    }
    moduleInitializers.set(moduleId, initializer);
  }

  function loadStyle(moduleId, url) {
    const safeUrl = assertModuleUrl(moduleId, url);
    if (loadedStyles.has(safeUrl)) return loadedStyles.get(safeUrl);

    const loading = new Promise((resolve, reject) => {
      const link = document.createElement("link");
      link.rel = "stylesheet";
      link.href = safeUrl;
      link.addEventListener("load", resolve, { once: true });
      link.addEventListener("error", () => {
        reject(new Error(`Impossible de charger ${safeUrl}.`));
      }, { once: true });
      document.head.appendChild(link);
    });
    loadedStyles.set(safeUrl, loading);
    return loading;
  }

  function loadScript(moduleId, url) {
    const safeUrl = assertModuleUrl(moduleId, url);
    if (loadedScripts.has(safeUrl)) return loadedScripts.get(safeUrl);

    const loading = new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = safeUrl;
      script.addEventListener("load", resolve, { once: true });
      script.addEventListener("error", () => {
        reject(new Error(`Impossible de charger ${safeUrl}.`));
      }, { once: true });
      document.head.appendChild(script);
    });
    loadedScripts.set(safeUrl, loading);
    return loading;
  }

  async function loadFragment(moduleId, url) {
    const safeUrl = assertModuleUrl(moduleId, url);
    const response = await fetch(safeUrl, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`Impossible de charger ${safeUrl} (${response.status}).`);
    }
    return response.text();
  }

  function activateTab(tabKey) {
    let found = false;
    document.querySelectorAll("[data-control-tab]").forEach((button) => {
      const active = button.dataset.controlTab === tabKey;
      button.classList.toggle("active", active);
      button.setAttribute("aria-selected", String(active));
      if (active) found = true;
    });
    document.querySelectorAll("[data-control-panel]").forEach((panel) => {
      panel.classList.toggle("active", panel.dataset.controlPanel === tabKey);
    });
    if (found) sessionStorage.setItem(`miao-active-tab:${activeModuleId}`, tabKey);
    return found;
  }

  async function createModuleInterface(moduleDefinition) {
    const { id, control } = moduleDefinition;
    await Promise.all((control.styles || []).map((style) => loadStyle(id, style)));

    for (const tab of control.tabs || []) {
      const tabKey = `${id}:${tab.id}`;
      const button = document.createElement("button");
      button.className = "tab";
      button.type = "button";
      button.dataset.controlTab = tabKey;
      button.setAttribute("role", "tab");
      button.setAttribute("aria-selected", "false");
      button.textContent = tab.label;
      button.addEventListener("click", () => activateTab(tabKey));
      tabsElement.appendChild(button);

      const panel = document.createElement("section");
      panel.className = "panel";
      panel.dataset.controlPanel = tabKey;
      panel.dataset.module = id;
      panel.setAttribute("role", "tabpanel");
      panel.innerHTML = await loadFragment(id, tab.fragment);
      panelsElement.appendChild(panel);
    }

    for (const script of control.scripts || []) {
      await loadScript(id, script);
    }

    if ((control.scripts || []).length > 0) {
      const initializer = moduleInitializers.get(id);
      if (!initializer) {
        throw new Error(`Le module ${id} n’a enregistré aucun initialiseur.`);
      }
      await initializer(Object.freeze({
        id,
        name: moduleDefinition.name,
        version: moduleDefinition.version
      }));
    }
  }

  async function initialize() {
    try {
      const result = await window.MiaoApi.getJson("/api/modules");
      const modules = Array.isArray(result.modules) ? result.modules : [];
      const path = window.location.pathname;
      const match = /^\/control\/([a-z][a-z0-9-]*)\/?$/.exec(path);
      const legacy = path === "/control" || path === "/miao-control.html";
      const selected = match
        ? modules.filter((module) => module.id === match[1])
        : legacy ? modules.filter((module) => module.control?.legacyDefault === true) : [];
      if (selected.length !== 1) {
        throw new Error("Ce dock est indisponible ou son module est désactivé.");
      }
      const moduleDefinition = selected[0];
      activeModuleId = moduleDefinition.id;
      document.title = `M.I.A.O. - ${moduleDefinition.name}`;
      document.querySelector("h1").textContent = `M.I.A.O. // ${moduleDefinition.name}`;
      document.querySelector(".subtitle").textContent = "Pupitre indépendant du module.";
      await createModuleInterface(moduleDefinition);

      const preferredTab = sessionStorage.getItem(`miao-active-tab:${activeModuleId}`);
      const firstTab = document.querySelector("[data-control-tab]")?.dataset.controlTab;
      if (!preferredTab || !activateTab(preferredTab)) activateTab(firstTab);
      setStatus("Console connectée.", "ok");
    } catch (error) {
      setStatus(`Impossible de charger la console : ${error.message}`, "error");
    }
  }

  window.MiaoControlHost = Object.freeze({ registerModule, setStatus });
  initialize();
})();
