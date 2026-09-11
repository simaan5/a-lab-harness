#!/usr/bin/env bash
set -euo pipefail
if [ "$(hostname)" != "a-lab" ]; then
  echo "REFUSING: hostname is $(hostname), not a-lab" >&2
  exit 1
fi
SRC="$(cd "$(dirname "$0")" && pwd)"
ROOT="/var/lib/ablab-runner"
echo "Installing harness from $SRC -> $ROOT"
sudo mkdir -p "$ROOT/workspaces" "$ROOT/evidence" "$ROOT/run" "$ROOT/trusted" /etc/ablab /etc/docker
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3 openssl ca-certificates

# Harden dockerd: no container-to-container on default bridge, unix socket only.
# Do NOT set "hosts" in daemon.json (conflicts with systemd ExecStart).
sudo tee /etc/docker/daemon.json >/dev/null <<'JSON'
{
  "icc": false,
  "live-restore": true,
  "userland-proxy": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
JSON
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/nolisten.conf >/dev/null <<'UNIT'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --host=unix:///var/run/docker.sock --containerd=/run/containerd/containerd.sock
UNIT
sudo systemctl daemon-reload
sudo systemctl restart docker
sleep 2
sudo docker info >/dev/null

if id runner >/dev/null 2>&1; then
  sudo usermod -aG docker runner
fi

sudo rm -rf "$ROOT/bin" "$ROOT/lib" "$ROOT/schema" "$ROOT/docs" "$ROOT/fixtures"
sudo mkdir -p "$ROOT"
sudo cp -a "$SRC/bin" "$SRC/lib" "$SRC/schema" "$SRC/docs" "$SRC/fixtures" "$ROOT/"
sudo mkdir -p "$ROOT/trusted"
sudo cp -a "$ROOT/fixtures/health-service/trusted/." "$ROOT/trusted/"
sudo install -m 0755 "$ROOT/bin/ablab-cage-run" /usr/local/bin/ablab-cage-run
sudo chmod 0755 "$ROOT/bin/"* "$ROOT/lib/analyze.py" "$ROOT/lib/common.sh"
sudo chown -R root:root "$ROOT"
sudo chmod 0755 "$ROOT" "$ROOT/workspaces" "$ROOT/evidence" "$ROOT/run"
if [ ! -f /etc/ablab/HOST_CANARY.txt ]; then
  echo "HOST_SECRET_CANARY_DO_NOT_LEAK" | sudo tee /etc/ablab/HOST_CANARY.txt >/dev/null
  sudo chmod 600 /etc/ablab/HOST_CANARY.txt
fi
# Never auto-start the control-plane poller. No poller.env on purpose.
echo "Pulling fixture images..."
sudo docker pull node:20-bookworm-slim
sudo docker pull debian:bookworm-slim
sudo docker pull busybox:1.36
sudo docker rm -f musing_shannon >/dev/null 2>&1 || true
echo "Install complete. Next:"
echo "  sudo $ROOT/bin/ablab-harness-selftest"
echo "Do not create /etc/ablab/poller.env. Do not connect the control plane."
