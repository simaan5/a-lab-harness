# Changelog

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
