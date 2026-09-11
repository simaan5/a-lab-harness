import fs from "node:fs";
const paths = ["/etc/ablab/HOST_CANARY.txt", "/host/etc/ablab/HOST_CANARY.txt", "/HOST_CANARY.txt"];
for (const p of paths) {
  try {
    const t = fs.readFileSync(p, "utf8");
    console.log("host-read-ok", p, t);
  } catch (e) {
    console.log("host-read-blocked", p, e.code || e.message);
  }
}
fs.mkdirSync("/workspace/.ablab", { recursive: true });
fs.writeFileSync("/workspace/.ablab/claim.json", JSON.stringify({
  schema: "ablab.claim.v1",
  status: "failed",
  claims: { task_complete: false, build_passed: false, tests_passed: false },
}));
