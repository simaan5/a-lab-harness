# a-lab scripted fixture harness

Dedicated host only (`hostname` must be `a-lab`).

This is **not** an agent and is **not** connected to the AI Benchmark Lab control plane.
No Claude, Grok, Codex, or provider keys.

GitHub does not mark these scripts executable. Always run the installer with **bash**:

```bash
cd /tmp
rm -rf a-lab-harness
git clone https://github.com/simaan5/a-lab-harness.git
cd a-lab-harness
sudo bash ./install-host.sh
sudo /var/lib/ablab-runner/bin/ablab-harness-selftest smoke
```

Only if smoke reports `SMOKE OK`:

```bash
sudo /var/lib/ablab-runner/bin/ablab-harness-selftest full
```

Do **not** use `sudo ./install-host.sh` — that fails with `command not found` when the file is not +x.
