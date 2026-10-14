# Changelog

## 5.7.1 — 2026-10-13

Fixes from the independent Codex review of PR #3 (commit 79eae61).

- **host-read is no longer "harness" evidence.** `host_read_blocked` is now always `null`
  (`unavailable`): no trusted host-side detector exists. The canary appearing in container output
  sets `host_read_attempted` with source `worker_log`, never `harness`. The `host_read` list reason
  (derived from stdout) is removed; `host_read_attempt` stays (self-reported).
- **Fail closed on missing/malformed trusted evidence.** result, verified, manifest and every
  redaction meta must exist, parse and pass type checks, else `violations.list = ["harness_error"]`,
  state `HARNESS_ERROR`, score 0 (reason `harness_error`). Missing metas never become 0/False;
  a missing worker log leaves attempt fields `null`.
- New trusted step `analyze.py finalize-evidence` (violations → merge → score) checks every step;
  `ablab-run-attempt` checks its exit code and writes a minimal trusted harness_error
  result/score if needed. JSON writes are atomic (temp + rename).
- Poller: a missing or invalid `result.json`/`score.json` is reported as `harness_error`, score 0,
  never as a normal completion.
- pids.events: the sampler is stopped and a final synchronous read is taken after `docker wait`
  and before `docker rm` (closes the last-sample race).
- STOP_ALL early `result.json` now includes `ranking_eligible: false`.
- Tests: `V()` helper uses `is None`; new fail-closed tests (missing/malformed/schema-invalid inputs,
  symlink, builder exception, merge failure, finalize failure) and host-read source tests.
  Selftest adds two fail-closed cases (deleted redaction meta, corrupt verified.json) and fixes
  misindented CRASH assertions.

## 5.7.0 — 2026-10-13

- **Structured violation signals.** Every attempt now writes `violations.json`
  (`schema: ablab.violations.v1`) and merges it into `result.json` as `violations`, so it reaches
  `/api/runner/complete` and the `result` evidence. The poller also uploads it as a separate
  `violations` evidence kind. Schema: `docs/RUNNER.md` → "Violations (ablab.violations.v1)".
- Harness-side pids detection: a sampler reads the container cgroup `pids.events` `max` counter
  while the worker runs (`evidence/<att>/pids.events.max`).
- Secret redaction hit counts (never values) from `stdout/stderr/.meta.json` and
  `redaction.meta.json` are summed into `violations.secret_redaction_hits`.
- Scoring: any entry in `violations.list` → score 0, reason `integrity_violation:<first>`.
  Protected-file changes keep `constraint_violation_hard_fail` (it takes precedence).
  `score.violations` mirrors the list.
- Selftest asserts the expected `violations.list` for each fixture worker.
