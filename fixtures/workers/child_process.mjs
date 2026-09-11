import { spawn } from "node:child_process";
import fs from "node:fs";

fs.mkdirSync("/workspace/.ablab", { recursive: true });
fs.writeFileSync(
  "/workspace/.ablab/lineage.json",
  JSON.stringify({
    parent: "ablab-cancel-parent",
    child: "ablab-cancel-child",
    grandchild: "ablab-cancel-grandchild",
  }),
);
fs.writeFileSync(
  "/workspace/.ablab/claim.json",
  JSON.stringify({
    schema: "ablab.claim.v1",
    status: "running",
    claims: { task_complete: false, build_passed: false, tests_passed: false },
  }),
);

process.title = "ablab-cancel-parent";
spawn("bash", ["-c", "exec -a ablab-cancel-child bash -c 'exec -a ablab-cancel-grandchild sleep 300'"], {
  detached: true,
  stdio: "ignore",
}).unref();
setTimeout(() => {}, 120000);
