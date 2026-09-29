// Tiny 127.0.0.1 HTTP server for the encoder tools: static mounts (with Range
// support so <video> can seek), a few JSON/POST hooks. Node built-ins only.
import http from "node:http";
import { createReadStream, statSync, createWriteStream, renameSync, rmSync, mkdirSync } from "node:fs";
import path from "node:path";

const TYPES = {
  ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp",
  ".m4a": "audio/mp4", ".mp3": "audio/mpeg", ".wav": "audio/wav", ".ogg": "audio/ogg", ".opus": "audio/ogg",
  ".mp4": "video/mp4", ".webm": "video/webm", ".css": "text/css",
};

/** Serve one file (supports `Range: bytes=a-b`). */
export function sendFile(req, res, file) {
  let st;
  try { st = statSync(file); } catch (_) { st = null; }
  if (!st || !st.isFile()) { res.writeHead(404, { "Content-Type": "text/plain" }); return res.end("not found"); }
  const type = TYPES[path.extname(file).toLowerCase()] || "application/octet-stream";
  const base = { "Content-Type": type, "Accept-Ranges": "bytes", "Cache-Control": "no-store" };
  const m = /^bytes=(\d*)-(\d*)$/.exec(req.headers.range || "");
  if (m && (m[1] || m[2])) {
    let start = m[1] ? Number(m[1]) : st.size - Number(m[2]);
    let end = m[1] && m[2] ? Number(m[2]) : st.size - 1;
    start = Math.max(0, start); end = Math.min(end, st.size - 1);
    if (start > end) { res.writeHead(416, { "Content-Range": `bytes */${st.size}` }); return res.end(); }
    res.writeHead(206, { ...base, "Content-Length": end - start + 1, "Content-Range": `bytes ${start}-${end}/${st.size}` });
    if (req.method === "HEAD") return res.end();
    return createReadStream(file, { start, end }).pipe(res);
  }
  res.writeHead(200, { ...base, "Content-Length": st.size });
  if (req.method === "HEAD") return res.end();
  createReadStream(file).pipe(res);
}

/** Stream a request body to `file` atomically (tmp file in the same dir + rename). Resolves to byte count. */
export function receiveFile(req, file) {
  mkdirSync(path.dirname(file), { recursive: true });
  const tmp = `${file}.part-${process.pid}-${Date.now()}`;
  return new Promise((resolve, reject) => {
    const ws = createWriteStream(tmp);
    let n = 0;
    req.on("data", d => (n += d.length));
    req.on("error", e => { ws.destroy(); rmSync(tmp, { force: true }); reject(e); });
    ws.on("error", e => { rmSync(tmp, { force: true }); reject(e); });
    ws.on("finish", () => { try { renameSync(tmp, file); resolve(n); } catch (e) { rmSync(tmp, { force: true }); reject(e); } });
    req.pipe(ws);
  });
}

export function sendJSON(res, obj, code = 200) {
  const body = JSON.stringify(obj);
  res.writeHead(code, { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(body), "Cache-Control": "no-store" });
  res.end(body);
}

/** Resolve `rel` below `dir`, refusing anything that escapes it. */
export function safeJoin(dir, rel) {
  const p = path.resolve(dir, "." + path.posix.normalize("/" + rel));
  return p === dir || p.startsWith(dir.endsWith(path.sep) ? dir : dir + path.sep) ? p : null;
}

/**
 * start({ mounts: { "/enc/": dir, ... }, files: { "/abs/x": absPath }, handle(req,res,url) → bool|Promise<bool> })
 * Resolves { port, url, close }.
 */
export async function start({ mounts = {}, files = {}, handle } = {}) {
  const server = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, "http://127.0.0.1");
      const pathname = decodeURIComponent(url.pathname);
      if (handle && (await handle(req, res, url, pathname))) return;
      if (pathname === "/favicon.ico") { res.writeHead(204); return res.end(); }
      if (files[pathname]) return sendFile(req, res, files[pathname]);
      for (const [prefix, dir] of Object.entries(mounts)) {
        if (pathname.startsWith(prefix)) {
          const f = safeJoin(path.resolve(dir), pathname.slice(prefix.length));
          if (f) return sendFile(req, res, f);
        }
      }
      res.writeHead(404, { "Content-Type": "text/plain" }); res.end("not found");
    } catch (e) {
      if (!res.headersSent) res.writeHead(500, { "Content-Type": "text/plain" });
      res.end(String(e && e.stack || e));
    }
  });
  await new Promise(r => server.listen(0, "127.0.0.1", r));
  const port = server.address().port;
  return { port, url: `http://127.0.0.1:${port}`, close: () => new Promise(r => { server.closeAllConnections?.(); server.close(r); }) };
}
