#!/usr/bin/env bash
# Install the a-lab scripted fixture harness.
#
# GitHub stores this file as 100644 (not executable).
# These both work:
#   chmod +x ./install-host.sh && sudo ./install-host.sh
#   sudo bash ./install-host.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Re-running as root: sudo bash $0 $*" >&2
  exec sudo bash "$0" "$@"
fi

if [ "$(hostname)" != "a-lab" ]; then
  echo "REFUSING: hostname is $(hostname), not a-lab" >&2
  exit 1
fi

SRC="$(cd "$(dirname "$0")" && pwd)"
ROOT="/var/lib/ablab-runner"
chmod a+x "$0" 2>/dev/null || true

need() {
  if [ ! -e "$1" ]; then
    echo "INSTALL FAIL: missing $1" >&2
    echo "From the cloned repo run:" >&2
    echo "  chmod +x ./install-host.sh && sudo ./install-host.sh" >&2
    echo "  OR: sudo bash ./install-host.sh" >&2
    exit 1
  fi
}

need "$SRC/bin/ablab-run-attempt"
need "$SRC/bin/ablab-harness-selftest"
need "$SRC/bin/ablab-cage-run"
need "$SRC/bin/ablab-verify"
need "$SRC/bin/ablab-poller"
need "$SRC/lib/analyze.py"
need "$SRC/lib/common.sh"
need "$SRC/fixtures/health-service/baseline/src/server.mjs"
need "$SRC/fixtures/workers/good.mjs"

# Refuse to install the pre-4.2 selftest that json.loads a filesystem path.
if ! grep -q 'parse_runner' "$SRC/bin/ablab-harness-selftest"; then
  echo "INSTALL FAIL: selftest in this checkout is stale (missing parse_runner)." >&2
  echo "git fetch && git checkout main && git pull" >&2
  exit 1
fi
if ! grep -q '"attempt_id"' "$SRC/bin/ablab-run-attempt"; then
  echo "INSTALL FAIL: ablab-run-attempt in this checkout is stale (no JSON stdout contract)." >&2
  exit 1
fi

echo "Installing harness from $SRC -> $ROOT"

mkdir -p "$ROOT/workspaces" "$ROOT/evidence" "$ROOT/run" "$ROOT/trusted" /etc/ablab /etc/docker
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 openssl ca-certificates

cat >/etc/docker/daemon.json <<'JSON'
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
mkdir -p /etc/systemd/system/docker.service.d
cat >/etc/systemd/system/docker.service.d/nolisten.conf <<'UNIT'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --host=unix:///var/run/docker.sock --containerd=/run/containerd/containerd.sock
UNIT
systemctl daemon-reload
systemctl restart docker
sleep 2
docker info >/dev/null

if id runner >/dev/null 2>&1; then
  usermod -aG docker runner
fi

rm -rf "$ROOT/bin" "$ROOT/lib" "$ROOT/schema" "$ROOT/docs" "$ROOT/fixtures"
mkdir -p "$ROOT"
cp -a "$SRC/bin" "$SRC/lib" "$SRC/schema" "$SRC/docs" "$SRC/fixtures" "$ROOT/"
mkdir -p "$ROOT/trusted"
cp -a "$ROOT/fixtures/health-service/trusted/." "$ROOT/trusted/"
install -m 0755 "$ROOT/bin/ablab-cage-run" /usr/local/bin/ablab-cage-run
chmod 0755 "$ROOT/bin/"* "$ROOT/lib/analyze.py" "$ROOT/lib/common.sh"
# Strip CRLF if GitHub/Windows ever injects them.
sed -i 's/\r$//' "$ROOT/bin/"* "$ROOT/lib/common.sh" "$ROOT/lib/analyze.py" || true
chown -R root:root "$ROOT"
chmod 0755 "$ROOT" "$ROOT/workspaces" "$ROOT/evidence" "$ROOT/run"

if [ ! -f /etc/ablab/HOST_CANARY.txt ]; then
  echo "HOST_SECRET_CANARY_DO_NOT_LEAK" >/etc/ablab/HOST_CANARY.txt
  chmod 600 /etc/ablab/HOST_CANARY.txt
fi

COMMIT="unknown"
if [ -d "$SRC/.git" ]; then
  COMMIT="$(git -C "$SRC" rev-parse HEAD)"
fi
date -u +%Y-%m-%dT%H:%M:%SZ >"$ROOT/INSTALLED_AT"
printf '%s\n' "$COMMIT" >"$ROOT/INSTALLED_COMMIT"
printf 'ablab-harness 5.1\n' >"$ROOT/INSTALLED_VERSION"

echo "Pulling fixture images..."
docker pull node:20-bookworm-slim
docker pull debian:bookworm-slim
docker pull busybox:1.36
docker rm -f musing_shannon >/dev/null 2>&1 || true

if [ -f "$SRC/systemd/ablab-poller.service" ]; then
  install -m 0644 "$SRC/systemd/ablab-poller.service" /etc/systemd/system/ablab-poller.service
  systemctl daemon-reload
fi

echo
echo "=================================================="
echo "SOURCE COMMIT: $COMMIT"
echo "INSTALLED RUNNER VERSION: $(cat "$ROOT/INSTALLED_VERSION")"
echo "INSTALLED COMMIT: $(cat "$ROOT/INSTALLED_COMMIT")"
echo "FILES INSTALLED:"
ls -l "$ROOT/bin"
echo "OWNERSHIP: root:root on $ROOT"
echo "INSTALL RESULT: OK"
echo "=================================================="
echo "Confirm SOURCE COMMIT equals INSTALLED COMMIT."
echo "Cage selftest (optional if already green):"
echo "  sudo $ROOT/bin/ablab-harness-selftest smoke"
echo
echo "Poller is NOT started until /etc/ablab/poller.env exists (root:root 0600)."
echo "Do not put model API keys in that file."
echo "Do not enable the service until ABL_BASE_URL is HTTPS."
