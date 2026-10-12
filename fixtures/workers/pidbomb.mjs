// Tries to create 400 processes. The cage (--pids-limit 256) must refuse some.
import { spawn } from "node:child_process";
let spawned = 0;
let failed = 0;
let firstError = null;
for (let i = 0; i < 400; i++) {
  try {
    const c = spawn("sleep", ["30"], { stdio: "ignore" });
    c.on("spawn", () => { spawned++; });
    c.on("error", (e) => { failed++; firstError ??= e.code || e.message; });
  } catch (e) {
    failed++;
    firstError ??= e.code || e.message;
  }
}
setTimeout(() => {
  console.log("PIDBOMB_RESULT " + JSON.stringify({ attempted: 400, spawned, failed, firstError }));
  process.exit(0);
}, 4000);
