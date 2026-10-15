"""The mixed guard runner must reject unrelated errors, even after PASS."""
from pathlib import Path
from collections import Counter
import importlib.util
import subprocess
import sys
import unittest

TOOLS = Path(__file__).resolve().parents[1] / "tools"
sys.path.insert(0, str(TOOLS))
spec = importlib.util.spec_from_file_location("ossuary_guard_runner", TOOLS / "check_ossuary_guards.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

ERRORS = Counter({
    "ERROR: OSSUARY_WITNESS original guardian birth identity/origin1.65/pattern direction/speed12/lifetime4/budget": 7,
    "ERROR: OSSUARY_WITNESS guardian projectile uses actual single-pattern release, not caster assumptions": 3,
    "ERROR: OSSUARY_WITNESS once-only native queued projectile contact": 3,
    "ERROR: OSSUARY_WITNESS actual current-map finite native projectile callback": 4,
    "ERROR: OSSUARY_WITNESS committed native attack release": 1,
})


def transcript():
    return "\n".join([*ERRORS.elements(), runner.PASS]) + "\n"


def result(output=None, code=0):
    return subprocess.CompletedProcess([], code, transcript() if output is None else output)


class DiagnosticBoundary(unittest.TestCase):
    def test_exact_intentional_rejections(self):
        self.assertTrue(runner.accepted(result()))

    def test_unexpected_diagnostics_even_after_pass(self):
        for diagnostic in [
            "ERROR: unrelated engine failure",
            "SCRIPT ERROR: Invalid access",
            "WARNING: ObjectDB instances leaked at exit",
            "WARNING: 1 resources still in use at exit",
            "warning: unrelated initialization warning",
            "Assertion failed: unrelated invariant",
        ]:
            with self.subTest(diagnostic=diagnostic):
                self.assertFalse(runner.accepted(result(transcript() + diagnostic + "\n")))

    def test_exact_label_multiplicities(self):
        line = next(iter(ERRORS))
        self.assertFalse(runner.accepted(result(transcript().replace(line + "\n", "", 1))))
        self.assertFalse(runner.accepted(result(transcript() + line + "\n")))
        self.assertFalse(runner.accepted(result(transcript().replace(line, line + " unexpected suffix", 1))))

    def test_exit_and_full_receipt_required(self):
        self.assertFalse(runner.accepted(result(code=1)))
        self.assertFalse(runner.accepted(result(transcript().replace(runner.PASS, "PASS unrelated"))))
        self.assertFalse(runner.accepted(result("")))
        self.assertFalse(runner.accepted(result(transcript() + runner.PASS + "\n")))


if __name__ == "__main__":
    unittest.main()
