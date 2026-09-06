"use strict";
const assert = require("node:assert/strict");
require("../modules/tunic/public/js/widget-core.js");
const catalog = require("../modules/tunic/public/catalog.json");
const { describeCell, shouldAnimate } = globalThis.MiaoTunicCore;
assert.equal(catalog.length, 10);
const state = { visible: true, session: "one", mode: "live", items: { sword: 0, gold: 8 },
  appearance: { hexagonQuest: false, hexagonGoal: 20, animateAcquisitions: true } };
const sword = catalog.find(cell => cell.id === "sword");
for (let level = 0; level <= 4; level++) {
  state.items.sword = level;
  assert.equal(describeCell(sword, state).pieces[0].image, `sword${Math.max(1, level)}.png`);
}
assert.equal(describeCell(catalog[0], state).pieces.length, 3);
state.appearance.hexagonQuest = true;
assert.equal(describeCell(catalog[0], state).counter, "8/20");
const next = structuredClone(state);
next.items.gold++;
assert.equal(shouldAnimate(state, next, "gold"), true);
for (const change of [{ session: "two" }, { visible: false }, { mode: "simulation" }]) {
  assert.equal(shouldAnimate(state, { ...next, ...change }, "gold"), false);
}
assert.equal(shouldAnimate(null, next, "gold"), false);
assert.equal(shouldAnimate(next, state, "gold"), false);
console.log("OK - Tunic widget : grille, epees, objectifs et animations par session.");
