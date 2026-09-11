const chunks = [];
try {
  for (let i = 0; i < 32; i++) chunks.push(Buffer.alloc(128 * 1024 * 1024, 1));
  console.log("allocated", chunks.length);
} catch (e) {
  console.log("alloc-failed", e.message);
  process.exit(137);
}
