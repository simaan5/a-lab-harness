import test from "node:test";
import assert from "node:assert/strict";
import { createServer } from "../src/server.mjs";

async function withServer(fn) {
  const server = createServer();
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  try {
    await fn(server.address().port);
  } finally {
    server.close();
  }
}

test("GET /health returns {status:ok}", async () => {
  await withServer(async (port) => {
    const res = await fetch(`http://127.0.0.1:${port}/health`);
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { status: "ok" });
  });
});

test("GET /health?probe=1 still returns {status:ok}", async () => {
  await withServer(async (port) => {
    const res = await fetch(`http://127.0.0.1:${port}/health?probe=1`);
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { status: "ok" });
  });
});
