import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("daemon_config", REPO / "lib" / "daemon_config.py")
D = importlib.util.module_from_spec(spec)
spec.loader.exec_module(D)

ALAB = {"icc": False, "live-restore": True, "userland-proxy": False, "log-driver": "json-file",
        "log-opts": {"max-size": "50m", "max-file": "5"}, "features": {"buildkit": True}}


class DaemonMerge(unittest.TestCase):
    def run_main(self, content, remap):
        d = tempfile.mkdtemp()
        p = os.path.join(d, "daemon.json")
        if content is not None:
            Path(p).write_text(json.dumps(content))
        out = D.main(["x", p, "1" if remap else "0"])
        self.assertEqual(out, 0)
        return json.loads(Path(p).read_text())

    def test_optout_preserves_existing_and_adds_nnp(self):
        m = self.run_main(ALAB, False)
        self.assertNotIn("userns-remap", m)
        self.assertTrue(m["no-new-privileges"])
        self.assertEqual(m["log-opts"], {"max-size": "50m", "max-file": "5"})
        self.assertEqual(m["features"], {"buildkit": True})
        for k in ("icc", "live-restore", "userland-proxy"):
            self.assertEqual(m[k], ALAB[k])

    def test_remap_on(self):
        self.assertEqual(self.run_main(ALAB, True)["userns-remap"], "default")

    def test_unchanged_is_not_rewritten(self):
        d = tempfile.mkdtemp()
        p = os.path.join(d, "daemon.json")
        Path(p).write_text(json.dumps(D.merge(ALAB, False)))
        before = os.stat(p).st_mtime_ns
        self.assertEqual(D.main(["x", p, "0"]), 0)
        self.assertEqual(os.stat(p).st_mtime_ns, before)

    def test_icc_forced_off(self):
        self.assertFalse(self.run_main({"icc": True}, False)["icc"])

    def test_missing_file(self):
        m = self.run_main(None, False)
        self.assertTrue(m["no-new-privileges"])
        self.assertNotIn("userns-remap", m)

    def test_never_removes_existing_remap(self):
        self.assertEqual(self.run_main({"userns-remap": "default"}, False)["userns-remap"], "default")


if __name__ == "__main__":
    unittest.main()
