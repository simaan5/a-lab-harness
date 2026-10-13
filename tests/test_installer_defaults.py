"""install-host.sh must not enable userns-remap unless asked (static checks; the installer is never run)."""
import os
import re
import subprocess
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
INSTALL = (REPO / "install-host.sh").read_text()


class UsernsDefault(unittest.TestCase):
    def test_every_default_expansion_is_zero(self):
        defaults = re.findall(r"\$\{ABL_USERNS_REMAP:-([^}]*)\}", INSTALL)
        self.assertGreaterEqual(len(defaults), 2)  # sudo re-exec and the root path
        self.assertEqual(set(defaults), {"0"})

    def resolve(self, env):
        # Evaluate only the installer's own default/validation lines, nothing else.
        lines = [ln for ln in INSTALL.splitlines() if ln.startswith(("USERNS_REMAP=", 'case "$USERNS_REMAP"'))]
        self.assertEqual(len(lines), 2)
        script = "set -eu\n" + "\n".join(lines) + '\nprintf %s "$USERNS_REMAP"\n'
        return subprocess.run(["bash", "-c", script], env={"PATH": os.environ["PATH"], **env}, capture_output=True, text=True)

    def test_unset_means_off(self):
        r = self.resolve({})
        self.assertEqual((r.returncode, r.stdout), (0, "0"))

    def test_explicit_opt_in(self):
        self.assertEqual(self.resolve({"ABL_USERNS_REMAP": "1"}).stdout, "1")
        self.assertEqual(self.resolve({"ABL_USERNS_REMAP": "0"}).stdout, "0")

    def test_garbage_rejected(self):
        self.assertNotEqual(self.resolve({"ABL_USERNS_REMAP": "yes"}).returncode, 0)

    def test_docs_say_opt_in(self):
        readme = (REPO / "README.md").read_text()
        runner = (REPO / "docs/RUNNER.md").read_text()
        selftest = (REPO / "bin/ablab-harness-selftest").read_text()
        self.assertIn("ABL_USERNS_REMAP=1", readme)
        self.assertIn("off by default", readme)
        self.assertIn("ABL_USERNS_REMAP=1", runner)
        self.assertIn("opt in with ABL_USERNS_REMAP=1", selftest)
        for text in (INSTALL, readme, runner, selftest):
            self.assertNotIn("ABL_USERNS_REMAP=0 bash", text)
            self.assertNotIn("ABL_USERNS_REMAP=1 (default)", text)


if __name__ == "__main__":
    unittest.main()
