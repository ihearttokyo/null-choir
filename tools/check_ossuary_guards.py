"""Run mixed Ossuary guards; whitelist only their exact intentional errors."""
from collections import Counter
from pathlib import Path
import os
import subprocess
import tempfile

from check_game import accepted as accepted_clean

ROOT = Path(__file__).resolve().parents[1]
PASS = "PASS 22 controlled guardian geometry/callback/identity/lifetime cases; not earned campaign"
ERRORS = Counter({
    "ERROR: OSSUARY_WITNESS original guardian birth identity/origin1.65/pattern direction/speed12/lifetime4/budget": 7,
    "ERROR: OSSUARY_WITNESS guardian projectile uses actual single-pattern release, not caster assumptions": 3,
    "ERROR: OSSUARY_WITNESS once-only native queued projectile contact": 3,
    "ERROR: OSSUARY_WITNESS actual current-map finite native projectile callback": 4,
    "ERROR: OSSUARY_WITNESS committed native attack release": 1,
})


def accepted(result):
    lines = result.stdout.splitlines()
    if lines.count(PASS) != 1 or Counter(line for line in lines if line.startswith("ERROR:")) != ERRORS:
        return False
    # Remove exact expected lines, leaving all other diagnostics for rejection.
    clean = "\n".join(line for line in lines if line not in ERRORS)
    if any(marker in clean.lower() for marker in ("error:", "warning:", "parse error", "leaked", "resources still in use")):
        return False
    return accepted_clean(subprocess.CompletedProcess(result.args, result.returncode, clean))


def main():
    with tempfile.TemporaryDirectory(prefix="null-choir-guards-") as temporary:
        home = Path(temporary)
        tmp = home / "tmp"
        tmp.mkdir()
        env = {**os.environ, "HOME": str(home), "TMPDIR": str(tmp),
               "XDG_DATA_HOME": str(home / "data"), "XDG_CONFIG_HOME": str(home / "config")}
        try:
            result = subprocess.run(
                ["godot", "--headless", "--audio-driver", "CoreAudio", "--path", str(ROOT / "game"),
                 "--script", "res://tests/test_ossuary_second_guards.gd"],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60, env=env,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            print("FAIL Ossuary guards:", error)
            return 1
        print(result.stdout, end="")
        if not accepted(result):
            print("FAIL Ossuary guard exit, receipt or diagnostic contract")
            return 1
    print("PASS strict Ossuary guardian runner: exactly 18 expected errors; no unexpected diagnostics")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
