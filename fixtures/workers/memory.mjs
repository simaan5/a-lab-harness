// Tries to touch ~4 GiB. The cage (--memory 2g --memory-swap 2g) must OOM-kill it.
const chunks = [];
for (let i = 0; i < 32; i++) {
  chunks.push(Buffer.alloc(128 * 1024 * 1024, 1));
  console.log("allocated", chunks.length);
}
console.log("memory-unconstrained", chunks.length);
