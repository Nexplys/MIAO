"use strict";

(function startMiaoWidget() {
  const core = window.MiaoWidgetCore;
  const widget = document.getElementById("widget");
  const terminal = document.getElementById("terminal");

  let state = null;
  let renderRevision = 0;
  let displayedSignature = "";

  const sleep = (milliseconds) =>
    new Promise((resolve) => setTimeout(resolve, milliseconds));

  function applySettings(settings) {
    const root = document.documentElement.style;
    const shadow = core.hexToRgba(settings.shadowColor, settings.shadowOpacity);
    const horizontalMap = {
      left: "flex-start",
      center: "center",
      right: "flex-end"
    };
    const verticalMap = {
      top: "flex-start",
      center: "center",
      bottom: "flex-end"
    };

    const variables = {
      "--text-color": settings.textColor,
      "--header-color": settings.headerColor,
      "--label-color": settings.labelColor,
      "--base-size": `${settings.baseFontSize}px`,
      "--header-size": `${settings.headerFontSize}px`,
      "--label-scale": settings.labelScale,
      "--compact-size": `${settings.compactFontSize}px`,
      "--compact-header-size": `${settings.compactHeaderSize}px`,
      "--very-compact-size": `${settings.veryCompactFontSize}px`,
      "--very-compact-header-size": `${settings.veryCompactHeaderSize}px`,
      "--line-height": settings.lineHeight,
      "--font-weight": settings.fontWeight,
      "--cursor-blink": `${settings.cursorBlinkMs}ms`,
      "--fade-duration": `${settings.fadeMs}ms`,
      "--terminal-shadow": [
        `-2px -2px 0 ${shadow}`,
        `2px -2px 0 ${shadow}`,
        `-2px 2px 0 ${shadow}`,
        `2px 2px 0 ${shadow}`,
        `0 3px 5px ${shadow}`
      ].join(", ")
    };

    for (const [name, value] of Object.entries(variables)) {
      root.setProperty(name, value);
    }

    document.body.style.fontFamily = settings.fontFamily;
    document.body.classList.toggle("cursor-off", !settings.cursorEnabled);
    widget.style.padding = `${settings.paddingY}px ${settings.paddingX}px`;
    widget.style.justifyContent = horizontalMap[settings.horizontalAlign] || "flex-start";
    widget.style.alignItems = verticalMap[settings.verticalAlign] || "flex-start";
    terminal.style.width = `${settings.contentWidth}%`;
    terminal.style.textAlign = settings.horizontalAlign;
  }

  function normalizeState(payload) {
    return {
      song: core.normalizeText(payload.song),
      mission: core.normalizeText(payload.mission),
      settings: payload.settings
    };
  }

  async function refreshState() {
    try {
      const nextState = normalizeState(await window.MiaoApi.getJson("/api/state"));
      if (!state || JSON.stringify(nextState) !== JSON.stringify(state)) {
        state = nextState;
        applySettings(state.settings);
        renderRevision += 1;
      }
    } catch (_) {
      // The polling loop retries automatically.
    }
  }

  function updateDensity(text) {
    const settings = state.settings;
    const length = Array.from(text).length;
    const compact = settings.autoCompactEnabled && length > settings.compactThreshold;
    const veryCompact = settings.autoCompactEnabled && length > settings.veryCompactThreshold;

    document.body.classList.toggle("compact", compact && !veryCompact);
    document.body.classList.toggle("very-compact", veryCompact);
  }

  function createLine(index) {
    const line = document.createElement("div");
    line.className = "line";
    if (index === 0) line.classList.add("line-header");
    if (index === 1) line.classList.add("line-label");
    terminal.appendChild(line);
    return line;
  }

  function createCursor() {
    const cursor = document.createElement("span");
    cursor.className = "cursor";
    cursor.textContent = "▌";
    return cursor;
  }

  function delayFor(character) {
    const settings = state.settings;
    let delay = settings.keyMs + Math.random() * settings.keyVarianceMs;
    if (character === "\n") delay += settings.newlinePauseMs;
    else if (".:;!?".includes(character)) delay += settings.punctuationPauseMs;
    else if (character === "/") delay += settings.slashPauseMs;
    return delay;
  }

  function renderInstant(text) {
    terminal.replaceChildren();
    updateDensity(text);
    const lines = text.split("\n");

    lines.forEach((content, index) => {
      const line = createLine(index);
      line.append(content);
      if (index === lines.length - 1) {
        line.appendChild(createCursor());
      }
    });
  }

  async function typeText(text, revision) {
    if (!state.settings.typewriterEnabled) {
      renderInstant(text);
      return revision === renderRevision;
    }

    terminal.replaceChildren();
    updateDensity(text);
    let lineIndex = 0;
    let currentLine = createLine(lineIndex);
    const cursor = createCursor();
    currentLine.appendChild(cursor);

    for (const character of Array.from(text)) {
      if (revision !== renderRevision) return false;
      cursor.remove();

      if (character === "\n") {
        lineIndex += 1;
        currentLine = createLine(lineIndex);
      } else {
        currentLine.append(character);
      }

      currentLine.appendChild(cursor);
      await sleep(delayFor(character));
    }

    return revision === renderRevision;
  }

  async function transitionTo(text, revision) {
    terminal.classList.add("is-hiding");
    await sleep(state.settings.fadeMs);
    if (revision !== renderRevision) return false;
    terminal.classList.remove("is-hiding");
    return typeText(text, revision);
  }

  async function clearDisplay(revision) {
    if (!terminal.hasChildNodes()) return;
    terminal.classList.add("is-hiding");
    await sleep(state.settings.fadeMs);
    if (revision !== renderRevision) return;
    terminal.replaceChildren();
    terminal.classList.remove("is-hiding");
    displayedSignature = "";
  }

  async function holdUntil(duration, revision) {
    const startedAt = performance.now();
    while (performance.now() - startedAt < duration) {
      await sleep(100);
      if (revision !== renderRevision) return false;
    }
    return true;
  }

  async function waitForRevision(revision) {
    while (revision === renderRevision) {
      await sleep(100);
    }
  }

  async function renderLoop() {
    while (!state) await sleep(100);

    while (true) {
      const revision = renderRevision;
      const pages = core.getAvailablePages(state);

      if (pages.length === 0) {
        await clearDisplay(revision);
        await waitForRevision(revision);
        continue;
      }

      if (pages.length === 1) {
        const page = pages[0];
        const signature = `${page.id}:${page.text}`;
        if (signature !== displayedSignature) {
          const rendered = await transitionTo(page.text, revision);
          if (!rendered) continue;
          displayedSignature = signature;
        }
        await waitForRevision(revision);
        continue;
      }

      for (const page of pages) {
        if (revision !== renderRevision) break;
        const rendered = await transitionTo(page.text, revision);
        if (!rendered) break;
        displayedSignature = `${page.id}:${page.text}`;
        if (!await holdUntil(page.duration, revision)) break;
      }
    }
  }

  async function pollingLoop() {
    while (true) {
      await refreshState();
      await sleep(state?.settings?.pollMs || 500);
    }
  }

  pollingLoop();
  renderLoop();
})();
