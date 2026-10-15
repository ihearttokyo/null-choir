#!/usr/bin/env python3
"""Run earned Ossuary preparation with strict complete-output receipts."""
from pathlib import Path
import argparse
import math
import os
import re
import shutil
import subprocess
import tempfile

from check_game import accepted as accepted_clean

ROOT = Path(__file__).resolve().parents[1]
PASS = "PASS bounded earned Ossuary saved checkpoint/original gate preparation; synthetic native input, not finale/app acceptance"
READY = "OSSUARY_PREPARATION_OMITTED_GATE_READY checkpoint_saved=true gate_live=true finale_dormant=true prior_frozen=true"
ERROR = "ERROR: OSSUARY_WITNESS NATIVE RED preparation requires queued rebound E original gate after saved checkpoint"
MANAGED_PATH = "/opt/homebrew/bin:/usr/bin:/bin"


def accepted(result, omit_gate=False):
    lines = result.stdout.splitlines()
    for label in ("OSSUARY_SECOND_EARNED", "OSSUARY_STORY_EARNED"):
        receipts = [line for line in lines if label.lower() in line.lower()]
        if len(receipts) != 1 or not re.fullmatch(label + r" frames=[0-9]+ .+ prior_frozen=true", receipts[0]):
            return False
    preparations = [line for line in lines if "ossuary_preparation_earned" in line.lower()]
    passes = [line for line in lines if "pass bounded earned ossuary saved checkpoint/original gate preparation" in line.lower()]
    readies = [line for line in lines if "OSSUARY_" in line.upper() and "_OMITTED" in line.upper()]
    if omit_gate:
        if result.returncode != 1 or readies != [READY] or preparations or passes or lines.count(ERROR) != 1:
            return False
        # Exempt only the exact intended error, never its surrounding diagnostics.
        clean = "\n".join(line for line in lines if line != ERROR)
    else:
        if passes != [PASS] or len(preparations) != 1 or readies:
            return False
        if not re.fullmatch(r"OSSUARY_PREPARATION_EARNED frames=[0-9]+ .+ prior_frozen=true", preparations[0]):
            return False
        clean = result.stdout
    if any(marker in clean.lower() for marker in (
        "error:", "warning:", "parse error", "parse_error", "assertion failed",
        "assert failed", "assertion failure", "leaked", "resources still in use",
        "resource still in use", "resource-use", "resource use",
    )):
        return False
    return True if omit_gate else accepted_clean(result)


def arguments(argv=None):
    def deadline(value):
        value = float(value)
        if not math.isfinite(value) or value <= 0:
            raise argparse.ArgumentTypeError("timeout must be finite and positive")
        return value
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--fixed-fps", action="store_true")
    parser.add_argument("--omit-gate", action="store_true")
    parser.add_argument("--timeout", type=deadline, default=1800)
    return parser.parse_args(argv)


def main(argv=None):
    args = arguments(argv)
    godot = shutil.which("godot", path=MANAGED_PATH)
    if godot is None:
        print("FAIL Ossuary preparation: managed Godot not found")
        return 1
    command = [godot, "--headless", "--audio-driver", "CoreAudio", "--path", str(ROOT / "game"),
               "--script", "res://tests/test_ossuary_finale_preparation.gd"]
    if args.fixed_fps:
        command += ["--fixed-fps", "60"]
    if args.omit_gate:
        command += ["--", "--omit-ossuary-preparation-gate"]
    with tempfile.TemporaryDirectory(prefix="null-choir-preparation-") as temporary:
        home = Path(temporary)
        for directory in ("tmp", "data", "config", "cache"):
            (home / directory).mkdir()
        env = {"PATH": MANAGED_PATH, "LANG": os.environ.get("LANG", "en_US.UTF-8"),
               "HOME": str(home), "TMPDIR": str(home / "tmp"), "TMP": str(home / "tmp"), "TEMP": str(home / "tmp"),
               "XDG_DATA_HOME": str(home / "data"), "XDG_CONFIG_HOME": str(home / "config"),
               "XDG_CACHE_HOME": str(home / "cache")}
        try:
            result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    text=True, timeout=args.timeout, env=env)
        except (OSError, subprocess.TimeoutExpired) as error:
            output = getattr(error, "stdout", None) or ""
            print(output.decode(errors="replace") if isinstance(output, bytes) else output, end="")
            print("FAIL Ossuary preparation:", error)
            return 1
        print(result.stdout, end="")
        if not accepted(result, omit_gate=args.omit_gate):
            print("FAIL Ossuary preparation exit, receipt or diagnostic contract")
            return 1
    print("PASS strict Ossuary preparation runner: " + ("expected omitted gate" if args.omit_gate else "earned saved checkpoint/gate"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
