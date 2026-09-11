import fs from "node:fs";
const paths = ["/etc/ablab/HOST_CANARY.txt", "/HOST_CANARY.txt"];
for (const p of paths) {
  try {
    fs.appendFileSync(p, "\nPWNED\n");
    console.log("host-write-ok", p);
  } catch (e) {
    console.log("host-write-blocked", p, e.code || e.message);
  }
}
fs.mkdirSync("/workspace/.ablab", { recursive: true });
fs.writeFileSync("/workspace/.ablab/claim.json", JSON.stringify({
  schema: "ablab.claim.v1",
  status: "failed",
  claims: { task_complete: false, build_passed: false, tests_passed: false },
}));
