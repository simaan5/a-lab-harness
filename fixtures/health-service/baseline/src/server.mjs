import http from "node:http";

export function createServer() {
  return http.createServer((req, res) => {
    const url = req.url || "/";
    const path = url.split("?")[0];
    if (path === "/") {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ ok: true }));
      return;
    }
    res.writeHead(404, { "content-type": "text/plain" });
    res.end("not found");
  });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  createServer().listen(3000, "127.0.0.1");
}
