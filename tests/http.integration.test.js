"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const http = require("node:http");
const net = require("node:net");
const { spawn } = require("node:child_process");
const { once } = require("node:events");

const root = path.resolve(__dirname, "..");
const temporaryRoot = fs.mkdtempSync(path.join(os.tmpdir(), "miao-http-tests-"));
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const sockets = new Set();
let server;
let port;
let output = "";

function write(relative, content) {
  const target = path.join(temporaryRoot, relative);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, content);
}

function request(url, { method = "GET", body, headers = {} } = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request({ host: "127.0.0.1", port, path: url, method,
      headers: { ...headers, ...(body === undefined ? {} : { "Content-Length": Buffer.byteLength(body) }) },
      agent: false }, (res) => {
      const chunks = [];
      res.on("data", (data) => chunks.push(data));
      res.on("error", reject);
      res.on("end", () => resolve({ status: res.statusCode, headers: res.headers,
        body: Buffer.concat(chunks), json() { return JSON.parse(this.body.toString()); } }));
    });
    req.on("error", reject);
    req.setTimeout(5000, () => req.destroy(new Error(`HTTP timeout: ${url}`)));
    req.end(body);
  });
}

async function connect() {
  const socket = net.connect({ host: "127.0.0.1", port });
  socket.on("error", () => {});
  sockets.add(socket);
  socket.once("close", () => sockets.delete(socket));
  await once(socket, "connect");
  return socket;
}

async function raw(parts) {
  const socket = await connect();
  const chunks = [];
  socket.on("data", (data) => chunks.push(data));
  socket.setTimeout(5000, () => socket.destroy(new Error("Raw HTTP timeout")));
  const ended = new Promise((resolve) => socket.once("close", resolve));
  for (const part of parts) {
    socket.write(part);
    await delay(25);
  }
  await ended;
  return Buffer.concat(chunks).toString();
}

async function main() {
  for (const relative of ["src", "public", "modules/broadcast", "modules/tunic", "VERSION"]) {
    fs.cpSync(path.join(root, relative), path.join(temporaryRoot, relative), { recursive: true });
  }
  for (const id of ["alpha", "broken"]) {
    write(`modules/${id}/module.json`, JSON.stringify({ schemaVersion: 1, id, name: id,
      version: "1.0.0", enabled: true, entry: `server/${id}.psm1`, updateIntervalMs: 50,
      hooks: { initialize: `Initialize-${id}`, update: `Update-${id}`, route: `Route-${id}` },
      public: { root: "public", aliases: [{ route: `/${id}`, file: "widget.html" }] },
      control: { styles: [], scripts: [], tabs: [{ id: "main", label: id,
        fragment: `/modules/${id}/control.html` }] } }));
    write(`modules/${id}/public/widget.html`, `<p>${id} widget</p>`);
    write(`modules/${id}/public/control.html`, `<p id="${id}-panel">${id}</p>`);
    write(`modules/${id}/server/${id}.psm1`, `
Import-Module (Join-Path $PSScriptRoot '../../../src/Miao.Http.psm1') -ErrorAction Stop
function Initialize-${id} { param($ApplicationContext, $ModulePath, $Options) return [pscustomobject]@{Ticks=0} }
function Update-${id} { param($State, $Now) ${id === "broken" ? 'throw "simulated update failure"' : '$State.Ticks++'} }
function Route-${id} {
    param($Request, $State, $ApplicationContext, $Client)
    if ($Request.Path -ne '/api/${id}/state') { return $false }
    Send-MiaoJsonResponse -Client $Client -Value @{ok=$true;ticks=$State.Ticks}
    return $true
}
Export-ModuleMember -Function Initialize-${id},Update-${id},Route-${id}
`);
  }
  const binary = Buffer.from([0, 128, 255, 13, 10, 42]);
  write("modules/alpha/public/binary.png", binary);
  write("modules/alpha/public/large.png", Buffer.alloc(8 * 1024 * 1024, 123));
  write("run.ps1", `param([int]$Port)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'src/Miao.App.psm1')
Start-MiaoApplication -RootPath $PSScriptRoot -Port $Port -ModuleOptions @{tunic=@{TrackerPath=(Join-Path $PSScriptRoot 'tracker.json')}}
`);
  const reservation = net.createServer();
  reservation.listen(0, "127.0.0.1");
  await once(reservation, "listening");
  port = reservation.address().port;
  await new Promise((resolve) => reservation.close(resolve));
  server = spawn("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    path.join(temporaryRoot, "run.ps1"), "-Port", String(port)], { windowsHide: true });
  server.stdout.on("data", (data) => { output = (output + data).slice(-12000); });
  server.stderr.on("data", (data) => { output = (output + data).slice(-12000); });
  let health;
  for (let attempt = 0; attempt < 100; attempt++) {
    if (server.exitCode !== null) throw new Error(`Server stopped: ${output}`);
    try { health = await request("/health"); break; } catch (_) { await delay(100); }
  }
  assert.equal(health?.status, 200, output);
  assert.deepEqual(health.json().modules, ["alpha", "broadcast", "broken", "tunic"]);
  const post = (route, value) => request(route, { method: "POST", body: Buffer.from(JSON.stringify(value)).toString("base64") });
  assert.equal((await request("/tunic")).status, 200);
  assert.equal((await request("/control/tunic")).status, 200);
  assert.deepEqual((await request("/modules/tunic/images/sword4.png")).body,
    fs.readFileSync(path.join(root, "modules/tunic/public/images/sword4.png")));
  const initialTunic = (await request("/api/tunic/state")).json();
  assert.equal(initialTunic.visible, false);
  assert.equal(initialTunic.status, "missing");
  assert.equal((await post("/api/tunic/simulation", { enabled: true })).json().visible, true);
  assert.equal((await post("/api/tunic/simulation", { enabled: false })).json().visible, false);
  assert.equal((await post("/api/tunic/simulation", { enabled: "true" })).status, 400);
  assert.equal((await request("/api/tunic/simulation")).status, 405);
  const yaml = "name: PrivateSlot\ngame: TUNIC\nTUNIC:\n  sword_progression: true\n  ability_shuffling: false\n  hexagon_quest: true\n  hexagon_goal: 30\n";
  const imported = await post("/api/tunic/profile", { yaml });
  assert.equal(imported.status, 200);
  assert.equal(imported.json().settings.hexagonGoal, 30);
  assert.equal(imported.json().settings.abilityShuffling, false);
  assert.ok(!fs.readFileSync(path.join(temporaryRoot, "var/tunic/settings.json"), "utf8").includes("PrivateSlot"));
  const failedImport = await post("/api/tunic/profile", { yaml: yaml.replace("30", "random") });
  assert.equal(failedImport.status, 400);
  assert.equal((await request("/api/tunic/config")).json().settings.hexagonGoal, 30);
  const descriptors = (await request("/api/modules")).json().modules;
  assert.equal(descriptors.find((m) => m.id === "broadcast").control.legacyDefault, true);
  assert.equal(descriptors.find((m) => m.id === "alpha").control.url, "/control/alpha");
  for (const route of ["/control", "/miao-control.html", "/control/broadcast", "/control/alpha",
    "/control/broken", "/", "/miao-widget.html", "/alpha"]) {
    assert.equal((await request(route)).status, 200, route);
  }
  assert.equal((await request("/control/missing")).status, 404);
  assert.deepEqual((await request("/modules/alpha/binary.png")).body, binary);
  assert.equal((await request("/modules/alpha/%2e%2e/server/alpha.psm1")).status, 404);
  assert.equal((await request("/modules/alpha/module.json")).status, 404);

  // Incomplete clients and a client not consuming a large response must not
  // prevent module updates, API replies, or Broadcast control operations.
  const before = (await request("/api/alpha/state")).json().ticks;
  const slowHeader = await connect();
  slowHeader.write("GET /health HTTP/1.1\r\nHost: local\r\nX-Slow: ");
  const slowBody = await connect();
  slowBody.write("POST /api/mission HTTP/1.1\r\nContent-Length: 200\r\n\r\ne30=");
  const slowWriter = await connect();
  slowWriter.pause();
  slowWriter.write("GET /modules/alpha/large.png HTTP/1.1\r\nHost: local\r\n\r\n");
  await delay(150);
  const started = Date.now();
  const concurrent = await Promise.all(Array.from({ length: 6 }, () => request("/health")));
  assert.ok(concurrent.every((res) => res.status === 200));
  assert.ok(Date.now() - started < 1500, "Incomplete clients stalled HTTP service");
  assert.ok((await request("/api/alpha/state")).json().ticks > before, "Module updates stalled");

  const mission = "Transmission accentuée : étoile 🐱";
  const body = Buffer.from(JSON.stringify({ text: mission })).toString("base64");
  const saved = await request("/api/mission", { method: "POST", body });
  assert.equal(saved.status, 200);
  assert.equal(saved.json().mission, mission);
  assert.equal((await request("/api/state")).json().mission, mission);
  assert.equal((await request("/api/mission", { method: "POST", body,
    headers: { Origin: "http://example.invalid" } })).status, 403);
  assert.equal((await request("/api/mission")).status, 405);
  assert.equal((await request("/api/mission", { method: "POST", body: "bad base64!" })).status, 400);
  assert.equal((await request("/unknown", { method: "POST", body: "a".repeat(262144) })).status, 404,
    "A body at the maximum supported size must reach the router");

  assert.match(await raw(["GET /health HTTP/1.1\r\nHost: local\r\n\r", "\n"]), /^HTTP\/1.1 200/);
  for (const invalid of [
    "POST /api/mission HTTP/1.1\r\nContent-Length: -1\r\n\r\n",
    "POST /api/mission HTTP/1.1\r\nContent-Length: 999999\r\n\r\n",
    "POST /api/mission HTTP/1.1\r\nContent-Length: 0\r\nContent-Length: 1\r\n\r\n",
    "POST /api/mission HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n",
    `GET /health HTTP/1.1\r\nX-Large: ${"a".repeat(17000)}\r\n\r\n`
  ]) assert.match(await raw([invalid]), /^HTTP\/1.1 400/);

  await delay(3200);
  assert.equal(slowHeader.destroyed, true, "Incomplete header did not expire");
  assert.equal(slowBody.destroyed, true, "Incomplete body did not expire");
  slowWriter.destroy();
  assert.equal((await request("/health")).status, 200);
  console.log("OK - HTTP reel : clients lents, erreurs, Unicode, binaire, docks et quatre modules dont Tunic.");
}

main().catch((error) => { console.error(error); console.error(output); process.exitCode = 1; })
  .finally(async () => {
    for (const socket of sockets) socket.destroy();
    if (server && server.exitCode === null) {
      const exited = once(server, "exit");
      server.kill();
      await exited;
    }
    const resolved = path.resolve(temporaryRoot);
    const parent = path.resolve(os.tmpdir());
    assert.equal(path.dirname(resolved), parent);
    assert.ok(path.basename(resolved).startsWith("miao-http-tests-"));
    fs.rmSync(resolved, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  });
