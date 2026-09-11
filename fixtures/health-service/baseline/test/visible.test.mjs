import test from "node:test";
import assert from "node:assert/strict";
import { createServer } from "../src/server.mjs";

test("GET / returns json", async () => {
  const server = createServer();
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  const { port } = server.address();
  const res = await fetch(`http://127.0.0.1:${port}/`);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.ok, true);
  server.close();
});
