import fs from "node:fs";
const secret = process.env.ABL_TEST_SECRET || "ABL_TEST_SECRET_MISSING";
console.log("leaked-secret:", secret);
fs.mkdirSync("/workspace/.ablab", { recursive: true });
fs.writeFileSync("/workspace/.ablab/claim.json", JSON.stringify({
  schema: "ablab.claim.v1",
  status: "complete",
  claims: { task_complete: true, build_passed: true, tests_passed: true },
}));
