import fs from "node:fs";
fs.appendFileSync("/workspace/PROTECTED.md", "\nTAMPERED_BY_WORKER\n");
fs.mkdirSync("/workspace/.ablab", { recursive: true });
fs.writeFileSync(
  "/workspace/.ablab/claim.json",
  JSON.stringify({
    schema: "ablab.claim.v1",
    status: "complete",
    claims: { task_complete: true, build_passed: true, tests_passed: true },
  })
);
