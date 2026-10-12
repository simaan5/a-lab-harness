#!/usr/bin/env bash
# Install the a-lab scripted fixture harness.
#   sudo bash ./install-host.sh
# CI only (never on a-lab):  sudo ABL_ALLOW_HOST=ci bash ./install-host.sh
#   -> skips the hostname check and leaves the CI runner's dockerd config alone.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Re-running as root: sudo bash $0 $*" >&2
  exec sudo ABL_ALLOW_HOST="${ABL_ALLOW_HOST:-}" bash "$0" "$@"
fi

CI_MODE=0
if [ "${ABL_ALLOW_HOST:-}" = "ci" ]; then
  CI_MODE=1
  echo "CI MODE: hostname check and docker daemon reconfiguration skipped" >&2
elif [ "$(hostname)" != "a-lab" ]; then
  echo "REFUSING: hostname is $(hostname), not a-lab" >&2
  exit 1
fi

SRC="$(cd "$(dirname "$0")" && pwd)"
ROOT="/var/lib/ablab-runner"
VERSION="$(cat "$SRC/VERSION")"

for f in bin/ablab-run-attempt bin/ablab-harness-selftest bin/ablab-cage-run bin/ablab-verify bin/ablab-poller \
         lib/analyze.py lib/common.sh config/images.lock config/seccomp-default.json \
         fixtures/workers/manifest.json fixtures/health-service/baseline/src/server.mjs; do
  [ -e "$SRC/$f" ] || { echo "INSTALL FAIL: missing $f" >&2; exit 1; }
done
python3 - "$SRC" <<'PY'
import json, os, sys
src = sys.argv[1]
ids = set(json.load(open(f"{src}/fixtures/workers/manifest.json"))["workers"])
files = {f[:-4] for f in os.listdir(f"{src}/fixtures/workers") if f.endswith(".mjs")}
if ids != files:
    sys.exit(f"INSTALL FAIL: manifest/worker mismatch: {sorted(ids ^ files)}")
PY

echo "Installing harness ${VERSION} from $SRC -> $ROOT"
mkdir -p "$ROOT/workspaces" "$ROOT/evidence" "$ROOT/run/secrets" "$ROOT/run/sock" "$ROOT/trusted" /etc/ablab
if command -v apt-get >/dev/null 2>&1 && [ "${ABL_SKIP_APT:-0}" != "1" ]; then
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y python3 openssl ca-certificates sudo
fi

if [ "$CI_MODE" -eq 0 ]; then
  mkdir -p /etc/docker
  if [ -f /etc/docker/daemon.json ]; then
    bak="/etc/docker/daemon.json.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    cp -a /etc/docker/daemon.json "$bak"
    echo "Backed up existing daemon.json -> $bak"
  fi
  # userns-remap: container root/65534 map to unprivileged subordinate uids on the host.
  cat >/etc/docker/daemon.json <<'JSON'
{
  "icc": false,
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "userns-remap": "default",
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
fi
docker info >/dev/null

# Non-root poller account (no docker group: docker group == root).
if ! id ablab >/dev/null 2>&1; then
  useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin ablab
fi

rm -rf "${ROOT:?}/bin" "${ROOT:?}/lib" "${ROOT:?}/schema" "${ROOT:?}/docs" "${ROOT:?}/fixtures" "${ROOT:?}/config"
cp -a "$SRC/bin" "$SRC/lib" "$SRC/schema" "$SRC/docs" "$SRC/fixtures" "$SRC/config" "$ROOT/"
cp -a "$SRC/VERSION" "$ROOT/VERSION"
rm -rf "$ROOT/trusted"; mkdir -p "$ROOT/trusted"
cp -a "$ROOT/fixtures/health-service/trusted/." "$ROOT/trusted/"
install -m 0755 "$ROOT/bin/ablab-cage-run" /usr/local/bin/ablab-cage-run
sed -i 's/\r$//' "$ROOT/bin/"* "$ROOT/lib/common.sh" "$ROOT/lib/analyze.py" || true
chown -R root:root "$ROOT"
chmod 0755 "$ROOT" "$ROOT/bin/"* "$ROOT/lib/analyze.py"
chmod 0644 "$ROOT/lib/common.sh"
chmod 0711 "$ROOT/workspaces" "$ROOT/run/secrets" "$ROOT/run/sock"
chmod 0750 "$ROOT/evidence" && chgrp ablab "$ROOT/evidence"
chmod 0755 "$ROOT/run" "$ROOT/trusted"
find "$ROOT/trusted" -type f -exec chmod 0644 {} +

if [ ! -f /etc/ablab/HOST_CANARY.txt ]; then
  echo "HOST_SECRET_CANARY_DO_NOT_LEAK" >/etc/ablab/HOST_CANARY.txt
  chmod 600 /etc/ablab/HOST_CANARY.txt
fi

COMMIT="unknown"
if [ -d "$SRC/.git" ]; then
  COMMIT="$(git -C "$SRC" rev-parse HEAD)"
  if [ -n "$(git -C "$SRC" status --porcelain)" ]; then
    COMMIT="${COMMIT}-dirty"
  fi
fi
date -u +%Y-%m-%dT%H:%M:%SZ >"$ROOT/INSTALLED_AT"
printf '%s\n' "$COMMIT" >"$ROOT/INSTALLED_COMMIT"
printf 'ablab-harness %s\n' "$VERSION" >"$ROOT/INSTALLED_VERSION"
docker version --format '{{.Server.Version}}' >"$ROOT/DOCKER_VERSION" 2>/dev/null || echo unknown >"$ROOT/DOCKER_VERSION"

echo "Pulling digest-pinned fixture images..."
awk -F= '!/^#/ && NF==2 {print $2}' "$ROOT/config/images.lock" | while read -r ref; do
  docker pull -q "$ref"
done

if [ "$CI_MODE" -eq 0 ]; then
  install -m 0644 "$SRC/systemd/ablab-poller.service" /etc/systemd/system/ablab-poller.service
  install -m 0644 "$SRC/systemd/ablab-retention.service" /etc/systemd/system/ablab-retention.service
  install -m 0644 "$SRC/systemd/ablab-retention.timer" /etc/systemd/system/ablab-retention.timer
  install -m 0440 "$SRC/systemd/ablab-poller.sudoers" /etc/sudoers.d/ablab-poller.new
  if visudo -cf /etc/sudoers.d/ablab-poller.new; then
    mv /etc/sudoers.d/ablab-poller.new /etc/sudoers.d/ablab-poller
  else
    rm -f /etc/sudoers.d/ablab-poller.new
    echo "INSTALL FAIL: sudoers rule did not validate" >&2; exit 1
  fi
  if [ -f /etc/ablab/poller.env ]; then
    chown ablab:ablab /etc/ablab/poller.env && chmod 0600 /etc/ablab/poller.env
  fi
  systemctl daemon-reload
  systemctl enable --now ablab-retention.timer
fi

echo
echo "=================================================="
echo "SOURCE COMMIT: $COMMIT"
echo "INSTALLED VERSION: $(cat "$ROOT/INSTALLED_VERSION")"
echo "INSTALL RESULT: OK"
echo "=================================================="
echo "Next: sudo $ROOT/bin/ablab-harness-selftest smoke"
echo "Poller runs as user 'ablab'; /etc/ablab/poller.env must be ablab:ablab 0600."
echo "Do not put model API keys in that file. ABL_BASE_URL must be HTTPS."
