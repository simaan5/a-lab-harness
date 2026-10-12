# AI Benchmark Lab — runner-side harness (a-lab)

This is **not** a product UI and **not** an agent integration.

Host: `a-lab` (Ubuntu 24.04.5, dedicated).
Cage: `/usr/local/bin/ablab-cage-run`
Root: `/var/lib/ablab-runner`

## Install

GitHub clones are not executable. From the repo:

```
chmod +x install-host.sh && sudo ./install-host.sh
```

or `sudo bash ./install-host.sh`.

Installer records `/var/lib/ablab-runner/INSTALLED_COMMIT`.

## Runner stdout contract

`bin/ablab-run-attempt <worker> [timeout] [job_id]`

- stdout: exactly one JSON object (last line), keys:
  - `attempt` / `attempt_id` (non-empty, filesystem-safe)
  - `result_json`
  - `evidence_dir` (must not contain `//`)
  - `status`
- stderr: `STATE <name> <attempt>`
- evidence: `/var/lib/ablab-runner/evidence/<attempt>/`
- workspace: `/var/lib/ablab-runner/workspaces/<attempt>/` then destroyed

Empty stdout, malformed JSON, or empty attempt id is a **harness error**.

## Trust boundary

| Path | Who may write |
|---|---|
| `/var/lib/ablab-runner/fixtures` | operators only |
| `/var/lib/ablab-runner/trusted` | operators only |
| `/var/lib/ablab-runner/bin` | operators only |
| `/var/lib/ablab-runner/workspaces/<id>` | one attempt, then destroyed |
| `/etc/ablab/HOST_CANARY.txt` | host only |

Workloads never get a host shell, `docker` CLI, or docker.sock.

`docker run` without the wrapper is **not** the cage. All benchmark containers must use `ablab-cage-run`.

## Cage (`bin/ablab-cage-run`, allowlist)

Accepted caller options only: `--rm`, `-d`, `--name ablab-att-*`, `-w /workspace|/trusted`,
`-e ABL_SOCK=/sock/<name>.sock`, and these binds (host side must be a real, non-symlink,
direct child, checked with `realpath`):

| host | container |
|---|---|
| `/var/lib/ablab-runner/workspaces/<id>` | `/workspace[:rw|:ro]` |
| `/var/lib/ablab-runner/trusted` | `/trusted:ro` |
| `/var/lib/ablab-runner/run/secrets/<id>` | `/secret:ro` |
| `/var/lib/ablab-runner/run/sock/<id>` | `/sock` |

The image must appear verbatim (digest-pinned) in `config/images.lock`. Anything else is `REJECTED`.

Hard flags are appended **after** caller options: `--network none --cap-drop ALL
--security-opt no-new-privileges:true --security-opt seccomp=config/seccomp-default.json
--user 65534:65534 --init --pids-limit 256 --memory 2g --memory-swap 2g --cpus 2
--ulimit nofile=1024 core=0 fsize=256MiB --read-only` + noexec tmpfs `/tmp`, `/run`.
The installer enables `userns-remap: default` and daemon-wide `no-new-privileges`.

## Verifier (`bin/ablab-verify`)

Worker code and test code never share a process or container:

1. `vbuild`: `node --check` on a read-only copy (parses only).
2. `vsrv`: trusted `/trusted/serve.mjs` imports the worker server and listens on a unix socket.
3. `vvis` / `vhid`: trusted test client containers (no workspace mount) run
   `/trusted/{visible,hidden}.test.mjs` over the socket with the TAP reporter.
4. TAP is parsed **by test name** against `expected.json`; exit codes are never trusted.
5. Every baseline file except `editable_files` is compared by sha256 (`protected.json`).
6. sha256 of `/var/lib/ablab-runner/trusted` is recorded before/after every attempt.

`exit_zero` is the regression worker for the old `process.exit(0)` bypass.

## Classification

Worker containers run detached; `docker wait` with a timeout, then `docker inspect`.
Precedence: `cancelled` > `oom_killed` (`State.OOMKilled`) > `timeout`. Output capped at 1 MiB per stream.

## Secrets and evidence

Only workers with `"secret": true` in `fixtures/workers/manifest.json` get a synthetic secret,
as the file `/secret/ABL_TEST_SECRET` (never `-e`). After each attempt every evidence file is
redacted (plain, base64, base32, hex, URL-encoded, reversed, `ablab_rt_*`); see `redaction.meta.json`.
`ABL_TOKEN` is never in any child environment.

## Retention

`ablab-retention.timer` (daily) runs `bin/ablab-retention`: evidence older than
`ABL_EVIDENCE_DAYS` (30) is removed, then oldest-first until under `ABL_EVIDENCE_MAX_MB` (2048).

## CI

`.github/workflows/ci.yml`: shellcheck, ruff, `tests/` unit tests, and the full Docker selftest on
a GitHub VM via `ABL_ALLOW_HOST=ci` (hostname override; installer skips dockerd reconfiguration, so
userns-remap is **not** exercised in CI — only on a-lab).

## Known, intentionally not changed

- This repository is **public**. That is acceptable only because it contains scripted fixtures
  and placeholders, never tokens. Consider making it private before real benchmarks exist.
- `fixtures/health-service/trusted/hidden.test.mjs` is public, so it is **not secret**. Real
  benchmark hidden tests must live in a private store and be mounted into `/trusted` at install time.
- `tamper_verifier` gets `/trusted:ro` mounted on purpose so the read-only mount itself is tested.

## Lifecycle

ALLOCATING → PREPARING → READY → EXECUTING → COLLECTING → VERIFYING → CLEANING → DESTROYED

## Claim schema

`ablab.claim.v1` in `.ablab/claim.json`. **Not trusted.** Verifier is authoritative.

## Scripted workers (not models)

Never attribute these to Claude, Grok, Codex.

## Scoring / fairness

Local pure-data integration only. `kind: HARNESS_TEST`, `ranking_eligible: false`, `model: null`.

## STOP ALL

`/var/lib/ablab-runner/bin/ablab-stop-all`

**VERIFIED FOR SCRIPTED FIXTURE EXECUTION ONLY.** Not tested against real coding agents.

## Known limitations

- Host `docker run` without the wrapper can still use the default bridge.
- Worker definitions: `fixtures/workers/manifest.json` (single source for poller, runner, selftest).
- Version: `VERSION` (single source).
- No control-plane connection yet.
- No real AI agents.
- Fixture is a tiny Node health-endpoint, not a production app.
