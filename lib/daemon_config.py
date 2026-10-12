#!/usr/bin/env python3
"""Merge AI Benchmark Lab settings into /etc/docker/daemon.json without clobbering it.

usage: daemon_config.py <daemon.json> <userns_remap:0|1>
Prints CHANGED or UNCHANGED. Writes only when the merged result differs.
Existing keys are preserved; harness keys are added only when missing, except the two
security keys (icc, no-new-privileges) which are forced, and userns-remap which is only
added when requested (never removed).
"""
from __future__ import annotations

import json
import os
import sys

FORCED = {"icc": False, "no-new-privileges": True}
DEFAULTS = {
    "live-restore": True,
    "userland-proxy": False,
    "log-driver": "json-file",
    "log-opts": {"max-size": "10m", "max-file": "3"},
}


def merge(existing: dict, userns_remap: bool) -> dict:
    out = dict(existing)
    for k, v in DEFAULTS.items():
        out.setdefault(k, v)
    out.update(FORCED)
    if userns_remap:
        out.setdefault("userns-remap", "default")
    return out


def main(argv: list[str]) -> int:
    path, remap = argv[1], argv[2] == "1"
    existing: dict = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            text = f.read().strip()
        if text:
            existing = json.loads(text)
            if not isinstance(existing, dict):
                print("daemon.json is not an object", file=sys.stderr)
                return 2
    merged = merge(existing, remap)
    if merged == existing and os.path.exists(path):
        print("UNCHANGED")
        return 0
    tmp = path + ".ablab-tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(merged, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, path)
    print("CHANGED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
