"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const fromRoot = (relativePath) => path.join(root, relativePath);
const read = (relativePath) => fs.readFileSync(fromRoot(relativePath), "utf8");
const readJson = (relativePath) => JSON.parse(read(relativePath));
const toPosix = (value) => value.split(path.sep).join("/");

function walk(relativeDirectory) {
  const absoluteDirectory = fromRoot(relativeDirectory);
  return fs.readdirSync(absoluteDirectory, { withFileTypes: true })
    .filter((entry) => !(
      entry.isDirectory() && (
        [".git", "node_modules"].includes(entry.name) ||
        (relativeDirectory === "." && entry.name === "var")
      )
    ))
    .flatMap((entry) => {
      const relativePath = path.join(relativeDirectory, entry.name);
      return entry.isDirectory() ? walk(relativePath) : [relativePath];
    });
}

function resolveContained(basePath, childPath, label) {
  assert.equal(path.isAbsolute(childPath), false, `${label} doit être relatif`);
  const base = path.resolve(basePath);
  const candidate = path.resolve(base, childPath);
  const relative = path.relative(base, candidate);
  assert.ok(
    relative && !relative.startsWith(`..${path.sep}`) && relative !== ".." && !path.isAbsolute(relative),
    `${label} doit rester dans ${base}`
  );
  return candidate;
}

function compileJavaScript(relativePath) {
  assert.doesNotThrow(
    () => new Function(read(relativePath)),
    `${relativePath} doit avoir une syntaxe JavaScript valide`
  );
}

function collectIds(html) {
  return [...html.matchAll(/\bid="([^"]+)"/g)].map((match) => match[1]);
}

function assertNoInlineCode(html, label) {
  assert.equal(
    /<script(?![^>]*\bsrc=)/i.test(html),
    false,
    `${label} ne doit pas contenir de script inline`
  );
  assert.equal(/<style\b/i.test(html), false, `${label} ne doit pas contenir de CSS inline`);
}

function resolveModuleUrl(moduleDefinition, url, expectedExtension) {
  const prefix = `/modules/${moduleDefinition.manifest.id}/`;
  assert.ok(url.startsWith(prefix), `${url} doit commencer par ${prefix}`);
  assert.equal(/[?#\\]/.test(url), false, `${url} ne doit contenir ni requête ni séparateur Windows`);

  const decoded = decodeURIComponent(url.slice(prefix.length));
  const segments = decoded.split("/");
  assert.ok(
    segments.length > 0 && segments.every((segment) => segment && segment !== "." && segment !== ".."),
    `${url} contient un segment invalide`
  );

  const absolutePath = resolveContained(
    moduleDefinition.publicRoot,
    segments.join(path.sep),
    `La ressource ${url}`
  );
  assert.equal(fs.existsSync(absolutePath), true, `${url} doit pointer vers un fichier existant`);
  if (expectedExtension) {
    assert.equal(path.extname(absolutePath), expectedExtension, `${url} doit être un fichier ${expectedExtension}`);
  }
  return absolutePath;
}

const semVerPattern = /^\d+\.\d+\.\d+$/;
const moduleIdPattern = /^[a-z][a-z0-9-]*$/;
const hookPattern = /^[A-Za-z][A-Za-z0-9-]*$/;
const reservedAliases = new Set([
  "/control",
  "/miao-control.html",
  "/assets/control.css",
  "/assets/api.js",
  "/assets/control.js",
  "/api/modules",
  "/health",
  "/favicon.ico"
]);
const applicationVersion = read("VERSION").trim();
assert.match(applicationVersion, semVerPattern, "VERSION doit utiliser le format SemVer");

const requiredRootProjectFiles = [
  ".gitignore",
  "CHANGELOG.md",
  "Lancer MIAO.bat",
  "LICENSE",
  "README.md",
  "VERSION"
];
const legacyRootDataFiles = new Set(["miao-mission.txt", "miao-settings.json"]);
const localRootArtifacts = new Set([".DS_Store", "Desktop.ini", "Thumbs.db"]);
const actualRootProjectFiles = fs.readdirSync(root, { withFileTypes: true })
  .filter((entry) => entry.isFile())
  .map((entry) => entry.name)
  .filter((name) => !legacyRootDataFiles.has(name))
  .filter((name) => !localRootArtifacts.has(name))
  .filter((name) => !/\.(?:bak|log|tmp|zip)$/i.test(name))
  .filter((name) => !/-files-to-delete\.txt$/i.test(name))
  .sort();
assert.deepEqual(
  actualRootProjectFiles,
  [...requiredRootProjectFiles].sort(),
  "L’arborescence racine du projet doit rester stable"
);

const modulesDirectory = fromRoot("modules");
assert.equal(fs.existsSync(modulesDirectory), true, "Le dossier modules doit exister");
const claimedAliases = new Map();
const moduleDefinitions = fs.readdirSync(modulesDirectory, { withFileTypes: true })
  .filter((entry) => entry.isDirectory() && fs.existsSync(path.join(modulesDirectory, entry.name, "module.json")))
  .sort((left, right) => left.name.localeCompare(right.name))
  .map((entry) => {
    const moduleRoot = path.join(modulesDirectory, entry.name);
    const manifest = JSON.parse(fs.readFileSync(path.join(moduleRoot, "module.json"), "utf8"));

    assert.equal(manifest.schemaVersion, 1, `${entry.name} doit utiliser le manifeste v1`);
    assert.match(manifest.id, moduleIdPattern, `${entry.name} a un identifiant invalide`);
    assert.equal(manifest.id, entry.name, `Le dossier ${entry.name} doit porter l’identifiant du module`);
    assert.ok(manifest.name, `${entry.name} doit avoir un nom`);
    assert.match(manifest.version, semVerPattern, `${entry.name} doit avoir une version SemVer`);
    assert.equal(typeof manifest.enabled, "boolean", `${entry.name}.enabled doit être booléen`);
    assert.match(manifest.hooks?.initialize || "", hookPattern, `${entry.name} doit déclarer son hook initialize`);
    for (const optionalHook of ["update", "route", "shutdown"]) {
      if (manifest.hooks?.[optionalHook]) {
        assert.match(manifest.hooks[optionalHook], hookPattern, `${entry.name}.${optionalHook} est invalide`);
      }
    }
    assert.ok(
      Number.isInteger(manifest.updateIntervalMs) && manifest.updateIntervalMs >= 50 && manifest.updateIntervalMs <= 60000,
      `${entry.name}.updateIntervalMs doit rester entre 50 et 60000`
    );

    const entryPath = resolveContained(moduleRoot, manifest.entry, `${entry.name}.entry`);
    assert.equal(path.extname(entryPath), ".psm1", `${entry.name}.entry doit être un module PowerShell`);
    assert.equal(fs.existsSync(entryPath), true, `Le point d’entrée de ${entry.name} doit exister`);

    const publicRoot = resolveContained(moduleRoot, manifest.public.root, `${entry.name}.public.root`);
    assert.equal(fs.statSync(publicRoot).isDirectory(), true, `Le dossier public de ${entry.name} doit exister`);
    const definition = { manifest, moduleRoot, publicRoot };

    const localAliases = new Set();
    for (const alias of manifest.public.aliases || []) {
      assert.match(alias.route, /^\/[^\s?#\\]*$/, `${entry.name} contient un alias invalide`);
      assert.equal(alias.route.startsWith("/modules/"), false, `${alias.route} empiète sur les ressources modulaires`);
      assert.equal(alias.route.startsWith("/api/"), false, `${alias.route} empiète sur l’API`);
      assert.equal(reservedAliases.has(alias.route), false, `${alias.route} est réservé au noyau`);
      assert.equal(localAliases.has(alias.route), false, `${alias.route} est déclaré deux fois par ${entry.name}`);
      assert.equal(claimedAliases.has(alias.route), false, `${alias.route} est partagé par plusieurs modules`);
      localAliases.add(alias.route);
      claimedAliases.set(alias.route, entry.name);

      const aliasPath = resolveContained(publicRoot, alias.file, `La cible de ${alias.route}`);
      assert.equal(fs.existsSync(aliasPath), true, `La cible de ${alias.route} doit exister`);
    }

    const tabIds = new Set();
    for (const style of manifest.control?.styles || []) resolveModuleUrl(definition, style, ".css");
    for (const script of manifest.control?.scripts || []) resolveModuleUrl(definition, script, ".js");
    for (const tab of manifest.control?.tabs || []) {
      assert.match(tab.id, moduleIdPattern, `L’onglet ${entry.name}:${tab.id} a un identifiant invalide`);
      assert.ok(tab.label, `L’onglet ${entry.name}:${tab.id} doit avoir un libellé`);
      assert.equal(tabIds.has(tab.id), false, `L’onglet ${entry.name}:${tab.id} est dupliqué`);
      tabIds.add(tab.id);
      resolveModuleUrl(definition, tab.fragment, ".html");
    }
    assert.ok(tabIds.size > 0, `${entry.name} doit exposer au moins un onglet de contrôle`);

    return definition;
  });

assert.deepEqual(
  moduleDefinitions.map((definition) => definition.manifest.id),
  ["broadcast"],
  "La version 4.0 doit commencer avec le seul module Broadcast"
);

const broadcast = moduleDefinitions.find((definition) => definition.manifest.id === "broadcast");
const broadcastRelative = (relativePath) => toPosix(path.relative(root, path.join(broadcast.moduleRoot, relativePath)));
const schema = readJson(broadcastRelative("config/settings.schema.json"));
const player = readJson(broadcastRelative("config/player-actions.json"));
const fields = schema.groups.flatMap((group) => group.fields);
const keys = fields.map((field) => field.key);
const supportedTypes = new Set(["boolean", "integer", "number", "string", "color", "select"]);

assert.equal(new Set(keys).size, keys.length, "Les clés de réglage doivent être uniques");
assert.equal(fields.length, 42, "Broadcast doit conserver les 42 réglages existants");
for (const field of fields) {
  assert.ok(field.key, "Chaque champ doit avoir une clé");
  assert.ok(field.label, `${field.key} doit avoir un libellé`);
  assert.ok(supportedTypes.has(field.type), `${field.key} utilise un type pris en charge`);
  assert.notEqual(field.default, undefined, `${field.key} doit avoir une valeur par défaut`);

  if (["integer", "number"].includes(field.type)) {
    assert.ok(Number.isFinite(field.minimum), `${field.key} doit avoir un minimum`);
    assert.ok(Number.isFinite(field.maximum), `${field.key} doit avoir un maximum`);
    assert.ok(
      field.minimum <= field.default && field.default <= field.maximum,
      `${field.key} doit avoir une valeur par défaut valide`
    );
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

const javaScriptFiles = walk(".").filter((file) => file.endsWith(".js") && !file.includes(`${path.sep}.git${path.sep}`));
for (const file of javaScriptFiles) compileJavaScript(file);

const widgetCorePath = broadcastRelative("public/js/widget-core.js");
const widgetControllerPath = broadcastRelative("public/js/widget.js");
const widgetJavaScript = [read(widgetCorePath), read(widgetControllerPath)].join("\n");
const usedSettings = new Set(
  [...widgetJavaScript.matchAll(/settings(?:\?\.|\.)([A-Za-z][A-Za-z0-9]*)/g)].map((match) => match[1])
);
for (const key of keys) {
  assert.ok(usedSettings.has(key), `Le widget doit utiliser le réglage ${key}`);
}

const widgetContext = { window: {} };
vm.createContext(widgetContext);
vm.runInContext(read(widgetCorePath), widgetContext);
const widgetCore = widgetContext.window.MiaoWidgetCore;
assert.ok(widgetCore, "Le noyau fonctionnel du widget doit être exposé");
assert.equal(widgetCore.normalizeText("  A\r\nB\r  "), "A\nB");
assert.equal(widgetCore.hexToRgba("#ff8000", 0.5), "rgba(255, 128, 0, 0.5)");
assert.equal(widgetCore.hexToRgba("invalide", 1), "rgba(0, 0, 0, 1)");

const longTitle = widgetCore.wrapSongTitle(
  "The Unreasonably Long Artist Name - A Very Long Song Title For Testing",
  18
);
assert.ok(longTitle.includes(" -\n"), "Le séparateur artiste-titre doit être conservé");
for (const line of longTitle.split("\n")) {
  assert.ok(Array.from(line).length <= 18, `La ligne « ${line} » dépasse la limite configurée`);
}

const emojiTitle = widgetCore.wrapWords("A😀B😀C", 2);
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
  widgetCore.getAvailablePages({
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
assert.deepEqual(pageIds({ radioAutoHideWhenEmpty: true }, { song: "" }), ["mission"]);

const coreControlHtml = read("public/control.html");
assertNoInlineCode(coreControlHtml, "public/control.html");
const fragmentHtml = broadcast.manifest.control.tabs
  .map((tab) => fs.readFileSync(resolveModuleUrl(broadcast, tab.fragment, ".html"), "utf8"))
  .join("\n");
assertNoInlineCode(fragmentHtml, "Les fragments Broadcast");
const dockIds = [...collectIds(coreControlHtml), ...collectIds(fragmentHtml)];
assert.equal(new Set(dockIds).size, dockIds.length, "Le dock assemblé ne doit contenir aucun identifiant dupliqué");
for (const id of collectIds(fragmentHtml)) {
  assert.ok(id.startsWith("broadcast-"), `L’identifiant ${id} doit être préfixé par le nom du module`);
}

const coreRoutes = read("src/Miao.Routes.psm1");
for (const asset of [...coreControlHtml.matchAll(/(?:src|href)="(\/assets\/[^"]+)"/g)].map((match) => match[1])) {
  assert.ok(coreRoutes.includes(`"${asset}"`), `${asset} doit être servi par le noyau`);
}

const widgetHtmlPath = broadcastRelative("public/widget.html");
const widgetHtml = read(widgetHtmlPath);
assertNoInlineCode(widgetHtml, widgetHtmlPath);
const widgetIds = collectIds(widgetHtml);
assert.equal(new Set(widgetIds).size, widgetIds.length, "Le widget Broadcast ne doit contenir aucun identifiant dupliqué");
for (const asset of [...widgetHtml.matchAll(/(?:src|href)="([^"]+)"/g)].map((match) => match[1])) {
  if (asset.startsWith("/modules/")) resolveModuleUrl(broadcast, asset);
  else assert.ok(coreRoutes.includes(`"${asset}"`), `${asset} doit être servi par le noyau`);
}
assert.ok(
  widgetHtml.indexOf("/modules/broadcast/js/widget-core.js") < widgetHtml.indexOf("/modules/broadcast/js/widget.js"),
  "Le noyau du widget doit être chargé avant son contrôleur"
);

for (const route of ["/api/modules", "/health"]) {
  assert.ok(coreRoutes.includes(`"${route}"`), `La route centrale ${route} doit être déclarée`);
}
assert.ok(coreRoutes.includes("$ApplicationContext.Version"), "La santé doit utiliser VERSION");
assert.ok(coreRoutes.includes("Test-MiaoMutationOrigin"), "Les mutations HTTP doivent vérifier leur origine");
const coreControlJavaScript = read("public/js/control.js");
const broadcastControlJavaScript = read(broadcastRelative("public/js/control.js"));
assert.ok(coreControlJavaScript.includes("registerModule"), "Le dock doit exposer un contrat d’initialisation modulaire");
assert.ok(
  broadcastControlJavaScript.includes('registerModule("broadcast"'),
  "Broadcast doit s’enregistrer auprès du dock commun"
);
assert.ok(
  read(broadcastRelative("public/css/control.css")).includes('[data-module="broadcast"]'),
  "Le CSS du dock Broadcast doit être isolé sous son module"
);

const genericCoreSource = [
  ...walk("src").map(read),
  read("public/control.html"),
  read("public/css/control.css"),
  coreControlJavaScript
].join("\n");
assert.equal(/\bbroadcast\b/i.test(genericCoreSource), false, "Le noyau ne doit connaître aucun module concret");
assert.equal(/\bmoobot\b/i.test(genericCoreSource), false, "Le noyau ne doit contenir aucune logique Moobot");

const broadcastRoutes = read(broadcastRelative("server/Miao.Broadcast.psm1"));
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
  assert.ok(broadcastRoutes.includes(`"${route}"`), `Broadcast doit conserver la route ${route}`);
  assert.equal(coreRoutes.includes(`"${route}"`), false, `${route} ne doit plus appartenir au noyau`);
}

const titlePipeline = [
  read("scripts/start-miao.ps1"),
  read(broadcastRelative("server/Miao.Broadcast.psm1")),
  read(broadcastRelative("server/Miao.TitleCleaner.psm1"))
].join("\n");
assert.equal(/CleanPath/.test(titlePipeline), false, "Le titre nettoyé doit rester en mémoire");
assert.match(read("scripts/start-miao.ps1"), /\[string\]\$Channel = ""/, "Le lanceur ne doit imposer aucun nom de chaîne");
assert.ok(
  read("Lancer MIAO.bat").includes("scripts\\start-miao.ps1"),
  "Le lanceur utilisateur doit cibler le script stable"
);

const applicationSource = read("src/Miao.App.psm1");
assert.ok(applicationSource.includes("RuntimePath") && applicationSource.includes('"var"'), "Le noyau doit définir le dossier runtime");
assert.ok(
  broadcastRoutes.includes('$ApplicationContext.RuntimePath "broadcast"'),
  "Broadcast doit isoler ses données sous var/broadcast"
);
assert.ok(broadcastRoutes.includes('"mission.txt"'), "Le chemin runtime de la mission doit être déclaré");
assert.ok(broadcastRoutes.includes('"settings.json"'), "Le chemin runtime des réglages doit être déclaré");

const releaseScript = read("tools/build-release.ps1");
for (const entry of ["Lancer MIAO.bat", "LICENSE", "scripts", "modules"]) {
  assert.ok(releaseScript.includes(`"${entry}"`), `${entry} doit être inclus dans l’archive complète`);
}
assert.equal(/^\s*"config",\s*$/m.test(releaseScript), false, "L’ancien dossier config ne doit plus être distribué");
const updateScript = read("tools/build-update.ps1");
assert.ok(updateScript.includes("git") && updateScript.includes("--name-status"), "La mise à jour doit être construite depuis Git");
assert.ok(updateScript.includes("$deletePaths.Remove"), "Un fichier remplacé ne doit jamais être aussi marqué à supprimer");

const powerShellFiles = walk(".").filter((file) => /\.(?:ps1|psm1)$/.test(file));
for (const file of powerShellFiles) {
  const bytes = fs.readFileSync(fromRoot(file));
  assert.ok([...bytes].every((byte) => byte <= 0x7f), `${file} doit rester en ASCII`);
  assert.equal(/`[ \t]+$/m.test(bytes.toString("ascii")), false, `${file} contient un espace après une continuation`);
}
const reusablePowerShellModules = powerShellFiles.filter((file) => {
  const normalized = toPosix(file);
  return normalized.startsWith("src/") || /^modules\/[^/]+\/server\//.test(normalized);
});
for (const file of reusablePowerShellModules) {
  assert.equal(
    /^Import-Module .*\s-Force(?:\s|$)/m.test(read(file)),
    false,
    `${file} ne doit pas recharger de force ses dépendances`
  );
}

const sourceFiles = walk(".").filter((file) => /\.(?:ps1|psm1|js|json|html|css|md|txt|bat|ya?ml)$/.test(file));
const allSource = [...sourceFiles.map(read), read("LICENSE")].join("\n");
assert.equal(/C:\\Users\\/i.test(allSource), false, "Le projet ne doit contenir aucun profil Windows figé");
assert.equal(/(?:ghp_|github_pat_)[A-Za-z0-9_]+/.test(allSource), false, "Le projet ne doit contenir aucun jeton GitHub");
assert.equal(allSource.includes("\u2014"), false, "Le projet doit employer le tiret simple à la place du tiret cadratin");

for (const obsoletePath of [
  "config/settings.schema.json",
  "config/player-actions.json",
  "config/default-mission.txt",
  "public/widget.html",
  "public/css/widget.css",
  "public/js/widget-core.js",
  "public/js/widget.js",
  "src/Miao.Hotkeys.psm1",
  "src/Miao.Mission.psm1",
  "src/Miao.Moobot.psm1",
  "src/Miao.TitleCleaner.psm1",
  "miao-widget.html",
  "miao-control.html",
  "miao-clean-title.ps1",
  "miao-launch-stream.ps1",
  "INSTALLATION-MIAO.md"
]) {
  assert.equal(fs.existsSync(fromRoot(obsoletePath)), false, `${obsoletePath} doit avoir été migré ou retiré`);
}

console.log(
  `OK - M.I.A.O. ${applicationVersion}, ${moduleDefinitions.length} module, ` +
  `${fields.length} réglages, ${player.actions.length} actions et ${powerShellFiles.length} fichiers PowerShell validés.`
);
