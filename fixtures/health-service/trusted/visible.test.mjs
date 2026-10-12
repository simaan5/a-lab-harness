// Trusted black-box copy of baseline test/visible.test.mjs (the workspace copy is hash-checked).
import test from "node:test";
import assert from "node:assert/strict";
import { waitForSocket, get, json } from "./client.mjs";

test.before(async () => { await waitForSocket(); });

test("GET / returns json", async () => {
  const res = await get("/");
  assert.equal(res.status, 200);
  assert.equal(json(res.body).ok, true);
});
