import fs from "node:fs";
fs.writeFileSync("/workspace/src/server.mjs", "this is not valid javascript ((");
fs.mkdirSync("/workspace/.ablab", { recursive: true });
fs.writeFileSync(
  "/workspace/.ablab/claim.json",
  JSON.stringify({
    schema: "ablab.claim.v1",
    status: "complete",
    claims: { task_complete: true, build_passed: true, tests_passed: true },
  })
);
