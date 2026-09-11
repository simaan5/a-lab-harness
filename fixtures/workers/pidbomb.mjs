import { spawn } from "node:child_process";
let n = 0;
try {
  for (let i = 0; i < 400; i++) {
    spawn("sleep", ["30"], { detached: true, stdio: "ignore" }).unref();
    n++;
  }
} catch (e) {
  console.log("spawn-stopped", n, e.code || e.message);
  process.exit(2);
}
console.log("spawned", n);
setTimeout(() => {}, 20000);
