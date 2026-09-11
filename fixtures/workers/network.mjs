import fs from "node:fs";

const ac = new AbortController();
const t = setTimeout(() => ac.abort(), 4000);
try {
  const res = await fetch("http://1.1.1.1/", { signal: ac.signal });
  console.log("network-ok", res.status);
  process.exitCode = 0;
} catch (e) {
  console.log("network-blocked", e.name, e.message);
  process.exitCode = 12;
} finally {
  clearTimeout(t);
  fs.mkdirSync("/workspace/.ablab", { recursive: true });
  fs.writeFileSync("/workspace/.ablab/claim.json", JSON.stringify({
    schema: "ablab.claim.v1",
    status: "failed",
    claims: { task_complete: false, build_passed: false, tests_passed: false },
  }));
}
