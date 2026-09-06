"use strict";
(async function startTunicWidget() {
  const tracker = document.getElementById("tunic-tracker");
  const grid = document.getElementById("tunic-grid");
  const simulation = document.getElementById("tunic-simulation");
  const core = window.MiaoTunicCore;
  let previous = null;
  let catalog = null;
  let signature = "";
  let lastSuccess = 0;
  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
  const cells = new Map();

  function render(state) {
    tracker.hidden = !state.visible;
    simulation.hidden = state.mode !== "simulation";
    const nextSignature = JSON.stringify(state.appearance);
    if (signature !== nextSignature) {
      signature = nextSignature;
      const style = document.documentElement.style;
      style.setProperty("--icon", `${state.appearance.iconSize}px`);
      style.setProperty("--gap", `${state.appearance.gap}px`);
      style.setProperty("--missing", state.appearance.missingOpacity);
      tracker.classList.toggle("tunic-labels", state.appearance.showLabels);
      tracker.classList.toggle("tunic-panels", state.appearance.showPanels);
    }
    for (const cell of catalog) {
      const view = core.describeCell(cell, state);
      let elements = cells.get(cell.id);
      if (!elements) {
        const container = document.createElement("div");
        container.className = "tunic-cell";
        container.dataset.item = cell.id;
        container.setAttribute("role", "img");
        const art = document.createElement("div");
        art.className = "tunic-art";
        const label = document.createElement("span");
        label.className = "tunic-label";
        const counter = document.createElement("span");
        counter.className = "tunic-level";
        container.append(art, counter, label);
        grid.appendChild(container);
        elements = { container, art, label, counter, images: [] };
        cells.set(cell.id, elements);
      }
      const { container, art, label, counter } = elements;
      if (elements.images.length !== view.pieces.length) {
        art.replaceChildren();
        elements.images = view.pieces.map(() => {
          const image = document.createElement("img");
          image.alt = "";
          image.draggable = false;
          image.addEventListener("animationend", () => image.classList.remove("tunic-acquired"));
          art.appendChild(image);
          return image;
        });
      }
      art.classList.toggle("tunic-hexagons", view.pieces.length === 3);
      view.pieces.forEach((piece, index) => {
        const image = elements.images[index];
        const url = `/modules/tunic/images/${piece.image}`;
        if (image.getAttribute("src") !== url) image.setAttribute("src", url);
        image.classList.toggle("tunic-missing", piece.value === 0);
        if (core.shouldAnimate(previous, state, piece.key)) {
          image.classList.remove("tunic-acquired");
          void image.offsetWidth;
          image.classList.add("tunic-acquired");
        }
      });
      label.textContent = view.label;
      counter.textContent = view.counter;
      counter.hidden = !view.counter;
      const acquired = view.pieces.filter((piece) => piece.value > 0).length;
      container.setAttribute("aria-label", `${view.label} : ${view.counter || `${acquired}/${view.pieces.length}`}`);
      container.title = container.getAttribute("aria-label");
    }
    previous = state;
  }

  while (true) {
    try {
      if (!catalog) {
        const response = await fetch("/modules/tunic/catalog.json", { cache: "no-store" });
        if (!response.ok) throw new Error("Catalogue indisponible");
        catalog = await response.json();
      }
      const state = await window.MiaoApi.getJson("/api/tunic/state");
      render(state);
      lastSuccess = Date.now();
    } catch (_) {
      if (Date.now() - lastSuccess > 5000) { tracker.hidden = true; previous = null; }
    }
    await sleep(500);
  }
})();
