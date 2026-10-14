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

## a-lab upgrade with userns-remap OFF (shared host)

a-lab also hosts other projects' images and containers (listing-prep-studio contract images,
postgres, a buildx builder). `userns-remap` would hide them (Docker stores remapped data under a
separate root), so install with `ABL_USERNS_REMAP=0`. All other cage hardening still applies.
The installer backs up and **merges** `/etc/docker/daemon.json` (existing keys kept; `icc:false` and
`no-new-privileges:true` enforced; `userns-remap` never added in this mode, never removed) and
restarts Docker **only** if `daemon.json` or the dockerd drop-in actually changed. With
`live-restore: true`, running containers survive that restart.

Note: daemon-wide `no-new-privileges` also applies to the other projects' containers (setuid
helpers such as `su`/`sudo` inside them stop gaining privileges). Check them after install.

### 1. Pause and back up
```bash
sudo systemctl stop ablab-poller || true
sudo /var/lib/ablab-runner/bin/ablab-stop-all
TS=$(date -u +%Y%m%dT%H%M%SZ); BK=/root/ablab-backup-$TS; sudo mkdir -p "$BK"
sudo tar -C / -czf "$BK/ablab.tgz" --ignore-failed-read \
  var/lib/ablab-runner/bin var/lib/ablab-runner/lib var/lib/ablab-runner/fixtures \
  var/lib/ablab-runner/trusted var/lib/ablab-runner/schema var/lib/ablab-runner/docs \
  var/lib/ablab-runner/INSTALLED_COMMIT var/lib/ablab-runner/INSTALLED_VERSION \
  usr/local/bin/ablab-cage-run etc/systemd/system/ablab-poller.service \
  etc/docker/daemon.json etc/systemd/system/docker.service.d etc/ablab/poller.env
sudo docker ps -a --format '{{.Names}} {{.Status}}' | sudo tee "$BK/containers-before.txt"
echo "backup: $BK"
```

### 2. Install the branch
```bash
cd /tmp && rm -rf a-lab-harness && git clone https://github.com/simaan5/a-lab-harness.git
cd a-lab-harness && git checkout hardening/audit-2026-10-12 && git rev-parse HEAD
sudo ABL_USERNS_REMAP=0 bash ./install-host.sh
sudo docker ps -a --format '{{.Names}} {{.Status}}' | diff "$BK/containers-before.txt" - && echo "containers unchanged"
```

### 3. Selftest (expect `userns_remap=off` warning, FAIL 0 / ERROR 0)
```bash
sudo /var/lib/ablab-runner/bin/ablab-harness-selftest smoke && \
sudo /var/lib/ablab-runner/bin/ablab-harness-selftest full
sudo sh -c 'cat $(ls -t /var/lib/ablab-runner/evidence/HARNESS_READINESS_*.json | head -1)'
```
Leave the poller stopped until review; then `sudo systemctl enable --now ablab-poller`
(it now runs as user `ablab`; installer already chowned `/etc/ablab/poller.env`).

### 4. Roll back
```bash
sudo systemctl stop ablab-poller || true
sudo /var/lib/ablab-runner/bin/ablab-stop-all || true
sudo systemctl disable --now ablab-retention.timer 2>/dev/null || true
sudo rm -f /etc/sudoers.d/ablab-poller /etc/systemd/system/ablab-retention.{service,timer}
sudo cp -a /etc/docker/daemon.json /root/daemon.json.after-branch
sudo tar -C / -xzf "$BK/ablab.tgz"
sudo chown root:root /etc/ablab/poller.env && sudo chmod 600 /etc/ablab/poller.env
sudo systemctl daemon-reload
cmp -s /etc/docker/daemon.json /root/daemon.json.after-branch || sudo systemctl restart docker
sudo /var/lib/ablab-runner/bin/ablab-harness-selftest smoke
```

## Violations (`ablab.violations.v1`, since 5.7.0)

`result.json.violations` (also `evidence/<att>/violations.json`, uploaded as evidence kind
`violations` and inside the `/api/runner/complete` `result`). Hit counts only, never secret values.

| field | type | source | meaning |
|---|---|---|---|
| `schema` | str | — | `ablab.violations.v1` |
| `network_attempted` | bool\|null | worker_log | worker printed a network attempt marker; `null` = no harness detector, unknown |
| `network_blocked` | bool | harness_config | cage ran with `--network none` (manifest) |
| `host_read_attempted` | bool\|null | worker_log (harness if canary leaked) | |
| `host_read_blocked` | bool | harness | host canary string absent from captured container output |
| `host_write_attempted` | bool\|null | worker_log (harness if canary changed) | |
| `host_write_succeeded` | bool\|null | harness | `!host_canary_intact` |
| `pids_limit_hit` | bool\|null | harness (cgroup `pids.events` max>0); worker_log fallback | fork refused at `--pids-limit` |
| `oom_killed` | bool | harness (`docker inspect`) | reported, **not** listed as an integrity violation |
| `trusted_write_attempted` | bool\|null | worker_log (harness if tree changed) | |
| `trusted_tampered` | bool\|null | harness | `!trusted_intact` (sha256 of trusted tree) |
| `protected_violation` | bool\|null | harness | `verified.protected_ok == false`; `null` when verifier skipped |
| `secret_redaction_hits` | int | harness | redaction hits across stdout, stderr and all evidence files |
| `secret_plaintext_remaining` | bool | harness | any secret variant survived redaction |
| `list` | [str] | — | reasons, most severe first: `secret_leak`, `host_write`, `verifier_tamper`, `protected_files`, `host_read`, `network_attempt`, `host_read_attempt`, `host_write_attempt`, `verifier_tamper_attempt`, `pids_limit` |
| `sources` | {field: source} | — | `harness`, `harness_config`, `worker_log` (untrusted, can only set true), `unavailable` |

Rules: worker output can only turn a signal **on**, never off; a harness-side `true` is never
cleared. `null` means "not detectable", not "clean". Empty `list` = no violation detected.
If violation extraction itself fails, `list` is `["harness_error"]` (fails closed).
