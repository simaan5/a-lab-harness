#!/usr/bin/env bash
ROOT="${ABL_ROOT:-/var/lib/ablab-runner}"
IMAGE="${ABL_IMAGE:-node:20-bookworm-slim}"
CAGE="${ROOT}/bin/ablab-cage-run"
PY="${ROOT}/lib/analyze.py"
FIX_BASE="${ROOT}/fixtures/health-service/baseline"
FIX_TRUST="${ROOT}/fixtures/health-service/trusted"
WORKERS="${ROOT}/fixtures/workers"
WS_ROOT="${ROOT}/workspaces"
EVID_ROOT="${ROOT}/evidence"
TRUSTED="${ROOT}/trusted"
STOP_FLAG="${ROOT}/run/STOP_ALL"
export ROOT IMAGE CAGE PY FIX_BASE FIX_TRUST WORKERS WS_ROOT EVID_ROOT TRUSTED STOP_FLAG

die() { echo "ERROR: $*" >&2; exit 1; }

need_host() {
  [ "$(hostname)" = "a-lab" ] || die "refusing to run on $(hostname); expected a-lab"
}

stop_all_requested() {
  [ -f "$STOP_FLAG" ]
}

sha_tree() {
  python3 - "$1" <<'PY'
import hashlib, os, sys
root = sys.argv[1]
h = hashlib.sha256()
for dirpath, _, files in os.walk(root):
    for name in sorted(files):
        path = os.path.join(dirpath, name)
        rel = os.path.relpath(path, root)
        h.update(rel.encode())
        h.update(b"\0")
        with open(path, "rb") as f:
            h.update(f.read())
print(h.hexdigest())
PY
}
