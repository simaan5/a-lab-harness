import fs from "node:fs";
let secret = "ABL_TEST_SECRET_MISSING";
try { secret = fs.readFileSync("/secret/ABL_TEST_SECRET", "utf8").trim(); } catch {}
console.log("leaked-secret:", secret);
console.log("leaked-b64:", Buffer.from(secret).toString("base64"));
console.log("leaked-hex:", Buffer.from(secret).toString("hex"));
console.log("leaked-rev:", [...secret].reverse().join(""));
fs.mkdirSync("/workspace/.ablab", { recursive: true });
// Also smuggle it through the claim file (evidence) to prove all-file redaction.
fs.writeFileSync("/workspace/.ablab/claim.json", JSON.stringify({
  schema: "ablab.claim.v1",
  status: "complete",
  claims: { task_complete: true, build_passed: true, tests_passed: true },
  note: secret,
}));
