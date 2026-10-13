// Trusted launcher: runs the WORKER's server in its own cage, listening on a unix socket.
// Mounted alone at /launcher: hidden tests (/trusted) are never in this container.
// The trusted test client runs in a different container and never imports worker code,
// so worker code cannot fake test results (e.g. process.exit(0)).
import fs from "node:fs";
const sock = process.env.ABL_SOCK;
if (!sock) { console.error("ABL_SOCK missing"); process.exit(2); }
try { fs.rmSync(sock, { force: true }); } catch {}
const mod = await import("file:///workspace/src/server.mjs");
const server = mod.createServer();
server.listen(sock, () => console.log("serve-listening", sock));
