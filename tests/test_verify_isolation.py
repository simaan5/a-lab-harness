"""ablab-cage-run / ablab-verify / ablab-run-attempt against a stub `docker` (no Docker, no root, no a-lab).

The real scripts are copied into a temp dir with /var/lib/ablab-runner rewritten to it; `docker`
and `chown` on PATH are stubs. The docker stub records every invocation so the tests can assert
exactly which host directories each container would have been given.
"""
import json
import os
import shutil
import signal
import stat
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PROD_ROOT = "/var/lib/ablab-runner"

DOCKER_STUB = r'''#!/usr/bin/env python3
import json, os, subprocess, sys, time
argv = sys.argv[1:]
with open(os.environ["STUB_LOG"], "a") as f:
    f.write(json.dumps(argv) + "\n")
cmd = argv[0] if argv else ""
if cmd == "run":
    name = argv[argv.index("--name") + 1] if "--name" in argv else ""
    binds = [argv[i + 1] for i, a in enumerate(argv) if a == "-v"]
    kind = name.rsplit("-", 1)[-1] if name.rsplit("-", 1)[-1] in ("vbuild", "vsrv", "vvis", "vhid") else "worker"
    if os.environ.get("STUB_HANG") == kind:
        with open(os.environ["STUB_LOG"] + ".pids", "a") as f:
            f.write("%d\n" % os.getpid())
        time.sleep(30)
        sys.exit(1)
    if kind == "worker" and os.environ.get("STUB_WORKER_HOOK"):
        ws = [b.split(":")[0] for b in binds if b.split(":")[1] == "/workspace"][0]
        subprocess.run([os.environ["STUB_WORKER_HOOK"], ws], check=True)
    if kind == "vvis":
        print("TAP version 13\nok 1 - GET / returns json\n1..1\n# pass 1\n# fail 0")
    if kind == "vhid":
        print("TAP version 13\nok 1 - GET /health returns {status:ok}\n"
              "ok 2 - GET /health?probe=1 still returns {status:ok}\n1..2\n# pass 2\n# fail 0")
elif cmd == "wait":
    print("0")
elif cmd == "inspect":
    print("false" if "OOMKilled" in " ".join(argv) else "0")
elif cmd == "image":
    print("sha256:stub")
'''


def sandbox(tmp: Path, overrides: dict | None = None) -> tuple[Path, dict]:
    root = tmp / "root"
    for d in ("bin", "lib", "config", "fixtures"):
        shutil.copytree(REPO / d, root / d, ignore=shutil.ignore_patterns("__pycache__"))
    shutil.copy(REPO / "VERSION", root / "VERSION")
    shutil.copytree(root / "fixtures/health-service/trusted", root / "trusted")
    shutil.copytree(root / "fixtures/health-service/launcher", root / "launcher")
    for d in ("workspaces", "evidence", "run/secrets", "run/sock"):
        (root / d).mkdir(parents=True)
    for f in [*(root / "bin").iterdir(), root / "lib/common.sh"]:
        f.write_text(f.read_text().replace(PROD_ROOT, str(root)))
    common = root / "lib/common.sh"
    text = common.read_text()
    for key, value in (overrides or {}).items():
        assert f"\n{key}=" in text, key
        text = "\n".join(f"{key}={value}" if ln.startswith(f"{key}=") else ln for ln in text.splitlines()) + "\n"
    common.write_text(text)
    stubs = tmp / "stubs"
    stubs.mkdir()
    (stubs / "docker").write_text(DOCKER_STUB)
    (stubs / "chown").write_text("#!/bin/sh\nexit 0\n")
    for s in stubs.iterdir():
        s.chmod(0o755)
    env = {"PATH": f"{stubs}:{os.environ['PATH']}", "STUB_LOG": str(tmp / "docker.log"), "ABL_ALLOW_HOST": "ci", "HOME": str(tmp)}
    return root, env


class Sandboxed(unittest.TestCase):
    OVERRIDES: dict = {}

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.root, self.env = sandbox(self.tmp, self.OVERRIDES)
        self.image = [ln.split("=", 1)[1] for ln in (self.root / "config/images.lock").read_text().splitlines()
                      if ln.startswith("node=")][0]

    def tearDown(self):
        pids = self.tmp / "docker.log.pids"
        if pids.exists():
            for pid in pids.read_text().split():
                try:
                    os.kill(int(pid), signal.SIGKILL)
                except ProcessLookupError:
                    pass
        shutil.rmtree(self.tmp, ignore_errors=True)

    def calls(self):
        log = self.tmp / "docker.log"
        return [json.loads(ln) for ln in log.read_text().splitlines()] if log.exists() else []

    def runs(self):
        """{container kind: [bind specs]} for every `docker run` the cage issued, in order."""
        out = []
        for argv in self.calls():
            if argv[0] != "run":
                continue
            name = argv[argv.index("--name") + 1]
            tail = name.rsplit("-", 1)[-1]
            kind = tail if tail in ("vbuild", "vsrv", "vvis", "vhid") else "worker"
            out.append((kind, [argv[i + 1] for i, a in enumerate(argv) if a == "-v"]))
        return out

    def hook(self, body: str) -> None:
        h = self.tmp / "hook.sh"
        h.write_text('#!/bin/sh\nset -e\ncd "$1"\n' + body + "\n")
        h.chmod(0o755)
        self.env["STUB_WORKER_HOOK"] = str(h)

    def attempt(self, worker="good", wall=90):
        t0 = time.monotonic()
        r = subprocess.run([str(self.root / "bin/ablab-run-attempt"), worker], env=self.env, capture_output=True, text=True, timeout=wall)
        self.elapsed = time.monotonic() - t0
        self.assertEqual(r.returncode, 0, r.stderr)
        out = json.loads(r.stdout.strip().splitlines()[-1])
        ev = Path(out["evidence_dir"])
        load = lambda n: json.loads((ev / n).read_text())  # noqa: E731
        return ev, load("result.json"), load("verified.json"), load("score.json")

    def cage(self, *args):
        return subprocess.run([str(self.root / "bin/ablab-cage-run"), *args], env=self.env, capture_output=True, text=True, timeout=30)


class CageBinds(Sandboxed):
    def setUp(self):
        super().setUp()
        self.ws = self.root / "workspaces/tcage"
        self.ws.mkdir()

    def test_trusted_with_workspace_rejected(self):
        for mode in ("ro", "rw"):
            r = self.cage("-v", f"{self.ws}:/workspace:{mode}", "-v", f"{self.root}/trusted:/trusted:ro", self.image, "true")
            self.assertEqual(r.returncode, 2)
            self.assertIn("REJECTED", r.stderr)
        r = self.cage("-v", f"{self.root}/trusted:/trusted:ro", "-v", f"{self.ws}:/workspace", self.image, "true")
        self.assertEqual(r.returncode, 2)
        self.assertEqual(self.calls(), [])

    def test_trusted_alone_and_launcher_with_workspace_allowed(self):
        self.assertEqual(self.cage("-v", f"{self.root}/trusted:/trusted:ro", self.image, "true").returncode, 0)
        self.assertEqual(self.cage("-v", f"{self.ws}:/workspace:ro", "-v", f"{self.root}/launcher:/launcher:ro", self.image, "true").returncode, 0)
        self.assertEqual(len(self.calls()), 2)

    def test_launcher_must_be_read_only_and_exact(self):
        for spec in (f"{self.root}/launcher:/launcher:rw", f"{self.root}/launcher:/launcher", f"{self.root}/trusted:/launcher:ro"):
            r = self.cage("-v", spec, self.image, "true")
            self.assertEqual(r.returncode, 2, spec)
            self.assertIn("REJECTED", r.stderr)


class HiddenTestsIsolation(Sandboxed):
    def test_fixture_layout(self):
        trusted = sorted(p.name for p in (REPO / "fixtures/health-service/trusted").iterdir())
        launcher = sorted(p.name for p in (REPO / "fixtures/health-service/launcher").iterdir())
        self.assertEqual(launcher, ["serve.mjs"])
        self.assertIn("hidden.test.mjs", trusted)
        self.assertNotIn("serve.mjs", trusted)

    def assert_isolated(self, runs):
        trusted, launcher = str(self.root / "trusted"), str(self.root / "launcher")
        for kind, binds in runs:
            srcs = [b.split(":")[0] for b in binds]
            dsts = [b.split(":")[1] for b in binds]
            if kind in ("worker", "vbuild", "vsrv"):   # containers that hold or run worker code
                self.assertNotIn(trusted, srcs, kind)
                self.assertNotIn("/trusted", dsts, kind)
            else:                                      # test clients: tests, but no worker files
                self.assertIn(f"{trusted}:/trusted:ro", binds, kind)
                self.assertNotIn("/workspace", dsts, kind)
                self.assertNotIn(launcher, srcs, kind)

    def test_good_attempt_never_shows_hidden_tests_to_worker_code(self):
        ev, result, verified, score = self.attempt("good")
        runs = self.runs()
        self.assertEqual([k for k, _ in runs], ["worker", "vbuild", "vsrv", "vvis", "vhid"])
        self.assert_isolated(runs)
        self.assertIn(f"{self.root}/launcher:/launcher:ro", dict(runs)["vsrv"])
        self.assertTrue(verified["task_complete"])
        self.assertTrue(verified["trusted_intact"])
        self.assertFalse(json.loads((ev / "manifest.json").read_text())["trusted_mounted"])

    def test_hidden_tests_mounted_only_after_worker_container_is_gone(self):
        self.attempt("good")
        calls = self.calls()
        worker = next(a[a.index("--name") + 1] for a in calls if a[0] == "run")
        removed = next(i for i, a in enumerate(calls) if a[:2] == ["rm", "-f"] and a[2:] == [worker])
        first_trusted = next(i for i, a in enumerate(calls) if a[0] == "run" and any(":/trusted:" in x for x in a))
        self.assertLess(removed, first_trusted)

    def test_tamper_worker_gets_launcher_not_hidden_tests(self):
        ev, *_ = self.attempt("tamper_verifier")
        runs = self.runs()
        self.assert_isolated(runs)
        self.assertIn(f"{self.root}/launcher:/launcher:ro", runs[0][1])
        manifest = json.loads((ev / "manifest.json").read_text())
        self.assertEqual((manifest["launcher_mounted"], manifest["trusted_mounted"]), (True, False))

    def test_no_worker_manifest_entry_can_request_trusted(self):
        manifest = json.loads((REPO / "fixtures/workers/manifest.json").read_text())["workers"]
        self.assertFalse([w for w, spec in manifest.items() if "mount_trusted" in spec])
        self.assertNotIn("TRUSTED", (REPO / "bin/ablab-run-attempt").read_text())


class SpecialFilesRejected(Sandboxed):
    def assert_rejected(self, path, kind):
        ev, result, verified, score = self.attempt("good", wall=60)
        self.assertEqual(verified["rejected"], "special_files")
        self.assertIn({"path": path, "type": kind}, verified["protected"]["special_files"])
        self.assertFalse(verified["task_complete"])
        self.assertIs(verified["protected_ok"], False)
        self.assertEqual((score["score"]["score"], score["score"]["reason"]), (0, "constraint_violation_hard_fail"))
        # nothing was copied and no verifier container was started
        self.assertEqual([k for k, _ in self.runs()], ["worker"])
        self.assertFalse(list((self.root / "workspaces").glob("*-verify")))
        self.assertFalse(result["verify_timeout"])
        self.assertTrue(result["cleanup_ok"])

    def test_fifo_server_file(self):
        self.hook("rm src/server.mjs && mkfifo src/server.mjs")
        self.assert_rejected("src/server.mjs", "fifo")
        self.assertLess(self.elapsed, 30)

    def test_symlink_server_file(self):
        self.hook("rm src/server.mjs && ln -s /etc/passwd src/server.mjs")
        self.assert_rejected("src/server.mjs", "symlink")

    def test_directory_symlink(self):
        self.hook("ln -s /etc src/lib")
        self.assert_rejected("src/lib", "symlink")

    def test_fifo_in_new_subdirectory(self):
        self.hook("mkdir -p src/a/b && mkfifo src/a/b/p")
        self.assert_rejected("src/a/b/p", "fifo")

    def test_fifo_is_really_a_fifo_when_verify_sees_it(self):
        # guard for the test itself: the hook must leave a FIFO in the kept workspace
        self.hook("rm src/server.mjs && mkfifo src/server.mjs")
        self.env["ABL_KEEP_WORKSPACE"] = "1"
        self.attempt("good", wall=60)
        ws = [p for p in (self.root / "workspaces").iterdir()][0]
        self.assertTrue(stat.S_ISFIFO(os.lstat(ws / "src/server.mjs").st_mode))


class VerifyTimeouts(Sandboxed):
    OVERRIDES = {"VERIFY_TIMEOUT_SECS": 3, "VERIFY_STEP_TIMEOUT_SECS": 1}

    def test_whole_verifier_is_killed(self):
        self.env["STUB_HANG"] = "vhid"     # test step limit (60s) is longer than the overall limit (3s)
        ev, result, verified, score = self.attempt("good", wall=60)
        self.assertLess(self.elapsed, 30)
        self.assertTrue(result["verify_timeout"])
        self.assertTrue(verified["verifier_timeout"])
        self.assertFalse(verified["task_complete"])
        self.assertFalse(verified["hidden_passed"])
        self.assertIn("verifier killed after 3s", (ev / "verify.out").read_text())
        self.assertTrue(result["cleanup_ok"])
        self.assertFalse(list((self.root / "workspaces").iterdir()))
        self.assertFalse(list((self.root / "run/sock").iterdir()))

    def test_build_step_times_out_on_its_own(self):
        self.env["STUB_HANG"] = "vbuild"
        ev, result, verified, score = self.attempt("good", wall=60)
        self.assertLess(self.elapsed, 30)
        self.assertFalse(result["verify_timeout"])
        self.assertEqual(verified["build_rc"], 124)
        self.assertFalse(verified["build_passed"])
        self.assertFalse(verified["task_complete"])
        self.assertIn("build check timed out", (ev / "verify-build.log").read_text())
        self.assertIn(["rm", "-f", next(a[a.index("--name") + 1] for a in self.calls() if a[0] == "run") + "-vbuild"], self.calls())

    def test_no_timeout_on_normal_run(self):
        ev, result, verified, score = self.attempt("good")
        self.assertFalse(result["verify_timeout"])
        self.assertNotIn("verifier_timeout", verified)
        self.assertTrue(verified["task_complete"])


class TimeoutWiring(unittest.TestCase):
    """The shipped (unmodified) scripts carry the limits the sandbox tests shorten."""

    def test_limits_defined_and_not_env_overridable(self):
        common = (REPO / "lib/common.sh").read_text()
        for key in ("VERIFY_TIMEOUT_SECS", "VERIFY_STEP_TIMEOUT_SECS", "VERIFY_TEST_TIMEOUT_SECS"):
            lines = [ln for ln in common.splitlines() if ln.startswith(f"{key}=")]
            self.assertEqual(len(lines), 1, key)
            self.assertRegex(lines[0], rf"^{key}=[1-9][0-9]*$")

    def test_run_attempt_bounds_verify(self):
        text = (REPO / "bin/ablab-run-attempt").read_text()
        calls = [ln.strip() for ln in text.splitlines() if "bin/ablab-verify" in ln and "sha" not in ln]
        self.assertEqual(len(calls), 1)
        self.assertTrue(calls[0].startswith('timeout -k 10 "$VERIFY_TIMEOUT_SECS" '), calls[0])

    def test_every_verify_container_step_is_bounded(self):
        lines = (REPO / "bin/ablab-verify").read_text().splitlines()
        steps = [ln.strip() for ln in lines if '"$CAGE"' in ln or ln.strip().startswith("docker logs") or " docker logs " in ln]
        self.assertEqual(len(steps), 5)
        for ln in steps:
            self.assertTrue(ln.startswith("timeout -k 5 "), ln)


if __name__ == "__main__":
    unittest.main()
