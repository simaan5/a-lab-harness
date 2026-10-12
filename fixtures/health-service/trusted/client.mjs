// Trusted black-box HTTP client over the unix socket in ABL_SOCK.
import http from "node:http";
import fs from "node:fs";

export async function waitForSocket(ms = 8000) {
  const sock = process.env.ABL_SOCK;
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (fs.existsSync(sock)) {
      try { await get("/__ablab_ping"); return; } catch {}
    }
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error("server socket never became ready");
}

export function get(path) {
  return new Promise((resolve, reject) => {
    const req = http.request({ socketPath: process.env.ABL_SOCK, path, method: "GET", timeout: 3000 }, (res) => {
      let body = "";
      res.setEncoding("utf8");
      res.on("data", (c) => { body += c; if (body.length > 65536) req.destroy(new Error("body too large")); });
      res.on("end", () => resolve({ status: res.statusCode, body }));
    });
    req.on("timeout", () => req.destroy(new Error("timeout")));
    req.on("error", reject);
    req.end();
  });
}

export function json(body) {
  try { return JSON.parse(body); } catch { return Symbol("not-json"); }
}
