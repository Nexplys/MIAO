"use strict";
(function exposeTunicCore(root) {
  function describeCell(cell, state) {
    const { items, appearance } = state;
    if (cell.id === "hexagons" && appearance.hexagonQuest) {
      return { label: "Hexagones dorés", pieces: [{ key: "gold", image: "hex_gold.png", value: items.gold }],
        counter: `${items.gold}/${appearance.hexagonGoal}` };
    }
    if (cell.id === "sword") {
      const level = Math.max(0, Math.min(4, items.sword));
      return { label: cell.label, pieces: [{ key: "sword", image: cell.images[Math.max(0, level - 1)], value: level }],
        counter: level > 0 ? `${level}/4` : "" };
    }
    return { label: cell.label, pieces: cell.keys.map((key, i) => ({ key, image: cell.images[i], value: items[key] })), counter: "" };
  }
  function shouldAnimate(previous, state, key) {
    return Boolean(previous && previous.visible && state.visible && previous.session === state.session &&
      previous.mode === state.mode && state.appearance.animateAcquisitions && state.items[key] > previous.items[key]);
  }
  root.MiaoTunicCore = Object.freeze({ describeCell, shouldAnimate });
})(typeof window === "undefined" ? globalThis : window);
