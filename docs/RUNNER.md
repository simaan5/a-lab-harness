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

`bin/ablab-run-attempt <worker> [timeout]`

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

## Cage flags (always)

- `--network none`
- `--cap-drop ALL`
- `--security-opt no-new-privileges`
- `--pids-limit 256`
- `--memory 2g --cpus 2`
- `--read-only` plus tmpfs `/tmp`
- bind mounts only under `/var/lib/ablab-runner/workspaces/` → `/workspace` and `/var/lib/ablab-runner/trusted` → `/trusted:ro` (verifier)

Rejected: `--privileged`, host net/pid, docker.sock, arbitrary `-v`.

## Lifecycle

ALLOCATING → PREPARING → READY → EXECUTING → COLLECTING → VERIFYING → CLEANING → DESTROYED

## Claim schema

`ablab.claim.v1` in `.ablab/claim.json`. **Not trusted.** Verifier is authoritative.

## Verifier

Runs in a **separate** cage after the worker exits.

## Scripted workers (not models)

Never attribute these to Claude, Grok, Codex.

## Scoring / fairness

Local pure-data integration only. `kind: HARNESS_TEST`, `ranking_eligible: false`, `model: null`.

## STOP ALL

`/var/lib/ablab-runner/bin/ablab-stop-all`

**VERIFIED FOR SCRIPTED FIXTURE EXECUTION ONLY.** Not tested against real coding agents.

## Known limitations

- Host `docker run` without the wrapper can still use the default bridge.
- No control-plane connection yet.
- No real AI agents.
- Fixture is a tiny Node health-endpoint, not a production app.
