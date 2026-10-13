#!/usr/bin/env bash
# Shared settings for the a-lab harness. Sourced, not executed.
# shellcheck disable=SC2034
ROOT="/var/lib/ablab-runner"
_lock_ref() { awk -F= -v k="$1" '$1==k{print $2}' "${ROOT}/config/images.lock" 2>/dev/null; }
IMAGE="$(_lock_ref node)"
DEBIAN_IMAGE="$(_lock_ref debian)"
CAGE="${ROOT}/bin/ablab-cage-run"
PY="${ROOT}/lib/analyze.py"
FIX_BASE="${ROOT}/fixtures/health-service/baseline"
FIX_TRUST="${ROOT}/trusted"
WORKERS="${ROOT}/fixtures/workers"
WS_ROOT="${ROOT}/workspaces"
EVID_ROOT="${ROOT}/evidence"
SECRETS_ROOT="${ROOT}/run/secrets"
SOCK_ROOT="${ROOT}/run/sock"
TRUSTED="${ROOT}/trusted"
# serve.mjs only: the one trusted dir that containers running worker code may see.
LAUNCHER="${ROOT}/launcher"
STOP_FLAG="${ROOT}/run/STOP_ALL"
CAGE_UID=65534
# Hard limits for the verify step (seconds). Not overridable from the environment.
VERIFY_TIMEOUT_SECS=300
VERIFY_STEP_TIMEOUT_SECS=30
VERIFY_TEST_TIMEOUT_SECS=60
export ROOT IMAGE DEBIAN_IMAGE CAGE PY FIX_BASE FIX_TRUST WORKERS WS_ROOT EVID_ROOT SECRETS_ROOT SOCK_ROOT TRUSTED LAUNCHER STOP_FLAG CAGE_UID VERIFY_TIMEOUT_SECS VERIFY_STEP_TIMEOUT_SECS VERIFY_TEST_TIMEOUT_SECS

die() { echo "ERROR: $*" >&2; exit 1; }

# Only a-lab runs fixtures. CI may opt in explicitly with ABL_ALLOW_HOST=ci.
need_host() {
  if [ "${ABL_ALLOW_HOST:-}" = "ci" ]; then
    return 0
  fi
  [ "$(hostname)" = "a-lab" ] || die "refusing to run on $(hostname); expected a-lab (CI: ABL_ALLOW_HOST=ci)"
}

stop_all_requested() {
  [ -f "$STOP_FLAG" ]
}

# "on" if dockerd runs with userns-remap, else "off".
userns_mode() {
  if docker info --format '{{.SecurityOptions}}' 2>/dev/null | grep -q 'name=userns'; then echo on; else echo off; fi
}

# Host uid that the container's uid 65534 maps to (differs under userns-remap).
cage_host_uid() {
  local base
  if docker info --format '{{.SecurityOptions}}' 2>/dev/null | grep -q 'name=userns'; then
    base="$(awk -F: '$1=="dockremap"{print $2; exit}' /etc/subuid)"
    echo $((base + CAGE_UID))
  else
    echo "$CAGE_UID"
  fi
}

# Give a host dir to the cage user so the non-root container can use it.
chown_for_cage() {
  local u
  u="$(cage_host_uid)"
  chown -R "${u}:${u}" "$@"
}

sha_tree() {
  python3 "$PY" sha-tree "$1"
}

worker_field() {
  python3 "$PY" worker-field "${WORKERS}/manifest.json" "$1" "$2"
}
