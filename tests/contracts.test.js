"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), "utf8");
const readJson = (relativePath) => JSON.parse(read(relativePath));

function walk(relativeDirectory) {
  const absoluteDirectory = path.join(root, relativeDirectory);
  return fs.readdirSync(absoluteDirectory, { withFileTypes: true })
    .filter((entry) => !(entry.isDirectory() && [".git", "node_modules"].includes(entry.name)))
    .flatMap((entry) => {
      const relativePath = path.join(relativeDirectory, entry.name);
      return entry.isDirectory() ? walk(relativePath) : [relativePath];
    });
}

function compileJavaScript(relativePath) {
  assert.doesNotThrow(
    () => new Function(read(relativePath)),
    `${relativePath} doit avoir une syntaxe JavaScript valide`
  );
}

const schema = readJson("config/settings.schema.json");
const player = readJson("config/player-actions.json");
const applicationVersion = read("VERSION").trim();
const fields = schema.groups.flatMap((group) => group.fields);
const keys = fields.map((field) => field.key);
const supportedTypes = new Set(["boolean", "integer", "number", "string", "color", "select"]);

assert.equal(new Set(keys).size, keys.length, "Les clés de réglage doivent être uniques");
assert.equal(fields.length, 42, "Le schéma doit exposer les 42 réglages attendus");
assert.match(applicationVersion, /^\d+\.\d+\.\d+$/, "VERSION doit utiliser le format SemVer");

for (const field of fields) {
  assert.ok(field.key, "Chaque champ doit avoir une clé");
  assert.ok(field.label, `${field.key} doit avoir un libellé`);
  assert.ok(supportedTypes.has(field.type), `${field.key} utilise un type pris en charge`);
  assert.notEqual(field.default, undefined, `${field.key} doit avoir une valeur par défaut`);

  if (["integer", "number"].includes(field.type)) {
    assert.ok(Number.isFinite(field.minimum), `${field.key} doit avoir un minimum`);
    assert.ok(Number.isFinite(field.maximum), `${field.key} doit avoir un maximum`);
    assert.ok(field.minimum <= field.default && field.default <= field.maximum, `${field.key} doit avoir une valeur par défaut valide`);
  }

  if (field.type === "select") {
    assert.ok(field.options.some((option) => option.value === field.default), `${field.key} doit proposer sa valeur par défaut`);
  }

  if (field.minimumFrom) {
    assert.ok(keys.includes(field.minimumFrom), `${field.key} référence un minimum inconnu`);
  }
}

const actionIds = player.actions.map((action) => action.id);
const actionKeys = player.actions.map((action) => action.key);
assert.equal(player.actions.length, 8, "Les huit commandes Moobot doivent être déclarées");
assert.equal(new Set(actionIds).size, actionIds.length, "Les identifiants Moobot doivent être uniques");
assert.equal(new Set(actionKeys).size, actionKeys.length, "Les raccourcis Moobot doivent être uniques");
assert.deepEqual(actionKeys, ["1", "2", "3", "4", "5", "6", "7", "8"]);

for (const file of [
  "public/js/api.js",
  "public/js/widget-core.js",
  "public/js/widget.js",
  "public/js/control.js"
]) {
  compileJavaScript(file);
}

const widgetJavaScript = [
  read("public/js/widget-core.js"),
  read("public/js/widget.js")
].join("\n");
const usedSettings = new Set(
  [...widgetJavaScript.matchAll(/settings(?:\?\.|\.)([A-Za-z][A-Za-z0-9]*)/g)].map((match) => match[1])
);
for (const key of keys) {
  assert.ok(usedSettings.has(key), `Le widget doit utiliser le réglage ${key}`);
}

const widgetContext = { window: {} };
vm.createContext(widgetContext);
vm.runInContext(read("public/js/widget-core.js"), widgetContext);
const core = widgetContext.window.MiaoWidgetCore;
assert.ok(core, "Le noyau fonctionnel du widget doit être exposé");
assert.equal(core.normalizeText("  A\r\nB\r  "), "A\nB");
assert.equal(core.hexToRgba("#ff8000", 0.5), "rgba(255, 128, 0, 0.5)");
assert.equal(core.hexToRgba("invalide", 1), "rgba(0, 0, 0, 1)");

const longTitle = core.wrapSongTitle(
  "The Unreasonably Long Artist Name - A Very Long Song Title For Testing",
  18
);
assert.ok(longTitle.includes(" -\n"), "Le séparateur artiste-titre doit être conservé");
for (const line of longTitle.split("\n")) {
  assert.ok(Array.from(line).length <= 18, `La ligne « ${line} » dépasse la limite configurée`);
}

const emojiTitle = core.wrapWords("A😀B😀C", 2);
assert.equal(emojiTitle.replaceAll("\n", ""), "A😀B😀C");
assert.ok(
  emojiTitle.split("\n").every((line) => Array.from(line).length <= 2),
  "Le retour à la ligne ne doit pas couper les caractères Unicode"
);

const pageSettings = {
  radioEnabled: true,
  radioAutoHideWhenEmpty: false,
  missionEnabled: true,
  radioHoldSeconds: 80,
  missionHoldSeconds: 20,
  radioHeader: "RADIO",
  radioLabel: "LECTURE",
  radioEmptyText: "SILENCE",
  songLineLength: 32
};
const pageIds = (overrides = {}, stateOverrides = {}) => Array.from(
  core.getAvailablePages({
    song: "Artiste - Titre",
    mission: "MISSION",
    ...stateOverrides,
    settings: { ...pageSettings, ...overrides }
  }),
  (page) => page.id
);

assert.deepEqual(pageIds(), ["radio", "mission"]);
assert.deepEqual(pageIds({ radioEnabled: false }), ["mission"]);
assert.deepEqual(pageIds({ missionEnabled: false }), ["radio"]);
assert.deepEqual(pageIds({ radioEnabled: false, missionEnabled: false }), []);
assert.deepEqual(
  pageIds({ radioAutoHideWhenEmpty: true }, { song: "" }),
  ["mission"],
  "La radio vide doit pouvoir se masquer automatiquement"
);

for (const htmlFile of ["public/widget.html", "public/control.html"]) {
  const html = read(htmlFile);
  assert.equal(/<script(?![^>]*\bsrc=)/i.test(html), false, `${htmlFile} ne doit pas contenir de script inline`);
  assert.equal(/<style\b/i.test(html), false, `${htmlFile} ne doit pas contenir de CSS inline`);

  const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map((match) => match[1]);
  assert.equal(new Set(ids).size, ids.length, `${htmlFile} ne doit pas contenir d’identifiant dupliqué`);

  const assets = [...html.matchAll(/(?:src|href)="(\/assets\/[^"]+)"/g)].map((match) => match[1]);
  for (const asset of assets) {
    assert.ok(read("src/Miao.Routes.psm1").includes(`"${asset}"`), `${asset} doit être servi par le routeur`);
  }
}

const widgetHtml = read("public/widget.html");
assert.ok(
  widgetHtml.indexOf("/assets/widget-core.js") < widgetHtml.indexOf("/assets/widget.js"),
  "Le noyau du widget doit être chargé avant son contrôleur"
);

const routeModule = read("src/Miao.Routes.psm1");
for (const route of [
  "/api/state",
  "/api/song",
  "/api/schema",
  "/api/player/actions",
  "/api/mission",
  "/api/settings",
  "/api/settings/reset",
  "/api/player"
]) {
  assert.ok(routeModule.includes(`"${route}"`), `La route ${route} doit être déclarée`);
}
assert.ok(routeModule.includes('"/assets/widget-core.js"'), "Le noyau du widget doit être servi");
assert.ok(routeModule.includes("$Context.Version"), "La route de santé doit utiliser VERSION");
assert.ok(routeModule.includes("Test-MiaoMutationOrigin"), "Les mutations HTTP doivent vérifier leur origine");

const titlePipeline = [
  read("miao-clean-title.ps1"),
  read("src/Miao.App.psm1"),
  read("src/Miao.TitleCleaner.psm1")
].join("\n");
assert.equal(/CleanPath/.test(titlePipeline), false, "Le titre nettoyé doit rester en mémoire");
assert.match(
  read("miao-clean-title.ps1"),
  /\[string\]\$Channel = ""/,
  "Le lanceur ne doit imposer aucun nom de chaîne"
);

const releaseScript = read("tools/build-release.ps1");
for (const launcher of ["Lancer MIAO.bat", "miao-launch-stream.ps1"]) {
  assert.ok(releaseScript.includes(`"${launcher}"`), `${launcher} doit être inclus dans l’archive`);
}

const powerShellFiles = walk(".").filter((file) => /\.(?:ps1|psm1)$/.test(file));
for (const file of powerShellFiles) {
  const bytes = fs.readFileSync(path.join(root, file));
  assert.ok([...bytes].every((byte) => byte <= 0x7f), `${file} doit rester en ASCII`);
  assert.equal(/`[ \t]+$/m.test(bytes.toString("ascii")), false, `${file} contient un espace après une continuation`);
}

const powerShellModules = powerShellFiles.filter((file) => file.startsWith(`src${path.sep}`));
for (const file of powerShellModules) {
  assert.equal(
    /^Import-Module .*\s-Force(?:\s|$)/m.test(read(file)),
    false,
    `${file} ne doit pas recharger de force ses modules dépendants`
  );
}

const allSource = walk(".")
  .filter((file) => /\.(?:ps1|psm1|js|json|html|css|md|txt)$/.test(file))
  .map(read)
  .join("\n");
assert.equal(/C:\\Users\\/i.test(allSource), false, "Le projet ne doit contenir aucun chemin de profil Windows figé");
assert.equal(fs.existsSync(path.join(root, "miao-widget.html")), false, "L’ancien widget racine ne doit pas être distribué");
assert.equal(fs.existsSync(path.join(root, "miao-control.html")), false, "L’ancien dock racine ne doit pas être distribué");

console.log(`OK — M.I.A.O. ${applicationVersion}, ${fields.length} réglages, ${player.actions.length} actions, ${powerShellFiles.length} fichiers PowerShell et contrats web validés.`);
