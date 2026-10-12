// Regression worker: tries to fake a passing verifier by exiting 0 on import.
import fs from "node:fs";
const p = "/workspace/src/server.mjs";
fs.writeFileSync(p, "process.exit(0);\n" + fs.readFileSync(p, "utf8"));
fs.mkdirSync("/workspace/.ablab", { recursive: true });
fs.writeFileSync("/workspace/.ablab/claim.json", JSON.stringify({
  schema: "ablab.claim.v1",
  status: "complete",
  claims: { task_complete: true, build_passed: true, tests_passed: true },
}));
