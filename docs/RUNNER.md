# AI Benchmark Lab — runner-side harness (a-lab)

This is **not** a product UI and **not** an agent integration.

Host: `a-lab` (Ubuntu 24.04.5, dedicated).
Cage: `/usr/local/bin/ablab-cage-run`
Root: `/var/lib/ablab-runner`

Workloads never get a host shell, `docker` CLI, or docker.sock.
`docker run` without the wrapper is **not** the cage.

## Cage flags (always)

- `--network none`
- `--cap-drop ALL`
- `--security-opt no-new-privileges`
- `--pids-limit 256`
- `--memory 2g --cpus 2`
- `--read-only` plus tmpfs `/tmp`

Rejected: `--privileged`, host net/pid, docker.sock, arbitrary `-v`.

**VERIFIED FOR SCRIPTED FIXTURE EXECUTION ONLY.** Not tested against real coding agents.
