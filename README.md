# a-lab scripted fixture harness

Dedicated host only (`hostname` must be `a-lab`).

This is **not** an agent and is **not** connected to the AI Benchmark Lab control plane.
No Claude, Grok, Codex, or provider keys.

## Why `sudo ./install-host.sh` said "command not found"

GitHub stores these scripts as `100644` (not executable). On Ubuntu, `sudo ./file`
on a non-executable file reports **command not found** even though the file exists.
That is not a missing installer.

Fix: `chmod +x` first, **or** invoke with `bash`.

## Install + smoke (copy this whole block)

```bash
cd /tmp
rm -rf a-lab-harness
git clone https://github.com/simaan5/a-lab-harness.git
cd a-lab-harness
git rev-parse HEAD
chmod +x install-host.sh
sudo ./install-host.sh
```

The installer must print matching:

```
SOURCE COMMIT: <sha>
INSTALLED COMMIT: <sha>
INSTALL RESULT: OK
```

Only then:

```bash
sudo /var/lib/ablab-runner/bin/ablab-harness-selftest smoke
```

Do **not** run `full` until smoke prints `SMOKE OK`.

Equivalent if you skip chmod:

```bash
sudo bash ./install-host.sh
```

## Runner stdout contract

`ablab-run-attempt` prints **one JSON object** on stdout:

```json
{"attempt":"<id>","attempt_id":"<id>","result_json":"/var/lib/ablab-runner/evidence/<id>/result.json","evidence_dir":"/var/lib/ablab-runner/evidence/<id>","status":"DESTROYED"}
```

STATE lines go to stderr. Empty stdout or `evidence//` is a harness error.

## Do not

- run agents
- create `/etc/ablab/poller.env`
- connect the control plane
- treat the historical `PASS 21 / FAIL 27` run as cage evidence
