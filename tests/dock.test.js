"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const source = fs.readFileSync(path.join(__dirname, "../public/js/control.js"), "utf8");

async function loadDock(pathname, failingModule = "broken") {
  const nodes = [];
  class Element {
    constructor(tag) {
      this.tag = tag;
      this.dataset = {};
      this.textContent = "";
      this.children = [];
      this.events = {};
      this.classes = new Set();
      this.classList = { toggle: (name, active) => active ? this.classes.add(name) : this.classes.delete(name) };
      nodes.push(this);
    }
    setAttribute() {}
    addEventListener(name, callback) { this.events[name] = callback; }
    appendChild(child) {
      this.children.push(child);
      if (this === document.head) {
        const url = child.src || child.href;
        loaded.push(url);
        const id = url.split("/")[2];
        queueMicrotask(() => {
          if (id === failingModule) return child.events.error();
          if (child.tag === "script") {
            window.MiaoControlHost.registerModule(id, async () => { initialized.push(id); });
          }
          child.events.load();
        });
      }
      return child;
    }
  }
  const ids = Object.fromEntries(["module-tabs", "module-panels", "status"].map((id) => [id, new Element("div")]));
  const heading = new Element("h1");
  const subtitle = new Element("p");
  const document = {
    head: new Element("head"), title: "", createElement: (tag) => new Element(tag),
    getElementById: (id) => ids[id],
    querySelectorAll: (selector) => nodes.filter((node) => selector === "[data-control-tab]"
      ? node.dataset.controlTab : node.dataset.controlPanel),
    querySelector(selector) {
      if (selector === "h1") return heading;
      if (selector === ".subtitle") return subtitle;
      return this.querySelectorAll(selector)[0];
    }
  };
  const loaded = [];
  const initialized = [];
  const storage = new Map();
  const modules = ["broken", "broadcast", "alpha"].map((id) => ({
    id, name: id, version: "1.0.0", control: {
      legacyDefault: id === "broadcast",
      styles: [`/modules/${id}/control.css`], scripts: [`/modules/${id}/control.js`],
      tabs: [{ id: "main", label: id, fragment: `/modules/${id}/control.html` }]
    }
  }));
  const window = { location: { pathname }, MiaoApi: { getJson: async () => ({ modules }) } };
  vm.runInNewContext(source, { window, document,
    sessionStorage: { getItem: (key) => storage.get(key), setItem: (key, value) => storage.set(key, value) },
    fetch: async (url) => {
      loaded.push(url);
      return { ok: true, text: async () => "<p>fixture</p>" };
    }
  });
  for (let i = 0; i < 30; i++) {
    await new Promise((resolve) => setImmediate(resolve));
    if (/connectée|Impossible/.test(ids.status.textContent)) break;
  }
  return { loaded, initialized, storage, status: ids.status.textContent,
    tabs: ids["module-tabs"].children, document };
}

(async () => {
  for (const route of ["/control", "/miao-control.html", "/control/broadcast"]) {
    const dock = await loadDock(route);
    assert.deepEqual(dock.initialized, ["broadcast"], route);
    assert.ok(dock.loaded.every((url) => url.startsWith("/modules/broadcast/")));
    assert.equal(dock.tabs.length, 1);
    assert.ok(dock.tabs[0].classes.has("active"));
    assert.equal(dock.storage.get("miao-active-tab:broadcast"), "broadcast:main");
  }
  const [alpha, broken] = await Promise.all([loadDock("/control/alpha"), loadDock("/control/broken")]);
  assert.deepEqual(alpha.initialized, ["alpha"]);
  assert.match(alpha.status, /connectée/);
  assert.match(broken.status, /Impossible/);
  assert.ok(alpha.loaded.every((url) => url.startsWith("/modules/alpha/")));
  assert.equal(alpha.storage.has("miao-active-tab:broadcast"), false);
  const absent = await loadDock("/control/absent");
  assert.match(absent.status, /indisponible/);
  assert.deepEqual(absent.loaded, []);
  console.log("OK - Docks : ressources isolees, alias historiques, onglets et panne independante.");
})().catch((error) => { console.error(error); process.exitCode = 1; });
