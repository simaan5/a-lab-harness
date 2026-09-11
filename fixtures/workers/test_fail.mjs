import fs from "node:fs";
const p = "/workspace/src/server.mjs";
let s = fs.readFileSync(p, "utf8");
s = s.replace(
  `    res.writeHead(404, { "content-type": "text/plain" });`,
  `    if (path === "/health") {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ status: "nope" }));
      return;
    }
    res.writeHead(404, { "content-type": "text/plain" });`
);
fs.writeFileSync(p, s);
fs.mkdirSync("/workspace/.ablab", { recursive: true });
fs.writeFileSync(
  "/workspace/.ablab/claim.json",
  JSON.stringify({
    schema: "ablab.claim.v1",
    status: "complete",
    claims: { task_complete: false, build_passed: true, tests_passed: false },
  })
);
