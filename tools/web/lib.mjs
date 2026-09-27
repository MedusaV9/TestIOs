// Shared helpers for the browser checks: start the real dev server, drive a
// Chromium (playwright-core) and collect console errors.
import { spawn } from "node:child_process";
import { createRequire } from "node:module";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const here = path.dirname(fileURLToPath(import.meta.url));
export const IOS = path.resolve(here, "../../MonkeyMoney/ios");

function loadPlaywright() {
  const candidates = [
    "playwright-core",
    "playwright",
    "/opt/toolchains/.nvm/versions/node/v22.23.2/lib/node_modules/@playwright/mcp/node_modules/playwright-core",
  ];
  for (const c of candidates) { try { return require(c); } catch (_) {} }
  throw new Error("playwright-core not found (npm i -D playwright-core)");
}
export const { chromium } = loadPlaywright();

export function chromePath() {
  if (process.env.CHROME) return process.env.CHROME;
  const p = "/opt/playwright/chromium-1232/chrome-linux64/chrome";
  return existsSync(p) ? p : undefined;
}

export async function startServer(port, args = []) {
  const bin = path.join(IOS, ".build/debug/mm-dev-server");
  const proc = spawn(bin, [String(port), ...args, "storage=/tmp/mm-web-check"], { stdio: ["ignore", "pipe", "pipe"] });
  let out = "";
  proc.stdout.on("data", d => (out += d));
  proc.stderr.on("data", d => (out += d));
  for (let i = 0; i < 100; i++) {
    try { const r = await fetch(`http://127.0.0.1:${port}/healthz`); if (r.ok) break; } catch (_) {}
    await sleep(100);
  }
  return { proc, log: () => out, stop: () => proc.kill("SIGTERM") };
}

export const sleep = ms => new Promise(r => setTimeout(r, ms));

export async function launch() {
  return chromium.launch({ executablePath: chromePath(), args: ["--autoplay-policy=no-user-gesture-required", "--no-sandbox"] });
}

export function watchConsole(page, name, errors) {
  page.on("console", m => { if (m.type() === "error") errors.push(`[${name}] ${m.text()}`); });
  page.on("pageerror", e => errors.push(`[${name}] ${e.message}`));
}

export async function api(port, p, body) {
  const r = await fetch(`http://127.0.0.1:${port}${p}`, body === undefined ? {} : { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  const t = await r.text();
  try { return JSON.parse(t); } catch (_) { return t; }
}
