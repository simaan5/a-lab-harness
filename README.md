# a-lab scripted fixture harness

Dedicated host only (`hostname` must be `a-lab`).

This is **not** an agent and is **not** connected to the AI Benchmark Lab control plane.
No Claude, Grok, Codex, or provider keys.

## Install and selftest on a-lab

```bash
sudo apt-get update
sudo apt-get install -y git
git clone https://github.com/simaan5/a-lab-harness.git /tmp/a-lab-harness
cd /tmp/a-lab-harness
sudo ./install-host.sh
sudo /var/lib/ablab-runner/bin/ablab-harness-selftest
```

Takes several minutes. Kernel OOM lines during the MEMORY test are expected.
Paste the full `HARNESS SUMMARY` output back to Grok.
