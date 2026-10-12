// Trusted hidden test. Runs in the verifier client cage; never imports worker code.
import test from "node:test";
import assert from "node:assert/strict";
import { waitForSocket, get, json } from "./client.mjs";

test.before(async () => { await waitForSocket(); });

test("GET /health returns {status:ok}", async () => {
  const res = await get("/health");
  assert.equal(res.status, 200);
  assert.deepEqual(json(res.body), { status: "ok" });
});

test("GET /health?probe=1 still returns {status:ok}", async () => {
  const res = await get("/health?probe=1");
  assert.equal(res.status, 200);
  assert.deepEqual(json(res.body), { status: "ok" });
});
