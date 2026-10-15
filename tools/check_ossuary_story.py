#!/usr/bin/env python3
"""Run earned Ossuary Story with strict complete-output receipts."""
from pathlib import Path
import argparse
import math
import os
import shutil
import subprocess
import tempfile

from check_game import accepted as accepted_clean

ROOT = Path(__file__).resolve().parents[1]
PASS = "PASS bounded earned Ossuary Story spur/return; synthetic native input, not human/app/fullcampaign acceptance"
READY = "OSSUARY_STORY_OMITTED_READY marker_live=true discovery_absent=true prior_frozen=true"
ERROR = "ERROR: OSSUARY_WITNESS NATIVE RED Story requires one queued rebound E interaction, original marker drain, discovery5 and authored notification"
MANAGED_PATH = "/opt/homebrew/bin:/usr/bin:/bin"


def accepted(result, omit_interact=False):
    lines = result.stdout.splitlines()
    passes = [line for line in lines if line.startswith("PASS bounded earned Ossuary Story")]
    stories = [line for line in lines if line.startswith("OSSUARY_STORY_EARNED")]
    seconds = [line for line in lines if line.startswith("OSSUARY_SECOND_EARNED")]
    readies = [line for line in lines if line.startswith("OSSUARY_STORY_OMITTED_READY")]
    if len(seconds) != 1 or not seconds[0].startswith("OSSUARY_SECOND_EARNED frames="):
        return False
    if omit_interact:
        if result.returncode != 1 or readies != [READY] or stories or passes or lines.count(ERROR) != 1:
            return False
        # Only this exact intentional failure is exempt from diagnostic rejection.
        clean = "\n".join(line for line in lines if line != ERROR)
    else:
        if passes != [PASS] or len(stories) != 1 or not stories[0].startswith("OSSUARY_STORY_EARNED frames=") or readies:
            return False
        clean = result.stdout
    if any(marker in clean.lower() for marker in (
        "error:", "warning:", "parse error", "parse_error", "assertion failed",
        "assert failed", "assertion failure", "leaked", "resources still in use",
        "resource still in use", "resource-use", "resource use",
    )):
        return False
    return True if omit_interact else accepted_clean(result)


def arguments(argv=None):
    def deadline(value):
        value = float(value)
        if not math.isfinite(value) or value <= 0:
            raise argparse.ArgumentTypeError("timeout must be finite and positive")
        return value
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixed-fps", action="store_true")
    parser.add_argument("--omit-interact", action="store_true")
    parser.add_argument("--timeout", type=deadline, default=1800)
    return parser.parse_args(argv)


def main(argv=None):
    args = arguments(argv)
    godot = shutil.which("godot", path=MANAGED_PATH)
    if godot is None:
        print("FAIL Ossuary Story: managed Godot not found")
        return 1
    command = [godot, "--headless", "--audio-driver", "CoreAudio", "--path", str(ROOT / "game"),
               "--script", "res://tests/test_ossuary_story.gd"]
    if args.fixed_fps:
        command += ["--fixed-fps", "60"]
    if args.omit_interact:
        command += ["--", "--omit-ossuary-story-interact"]
    with tempfile.TemporaryDirectory(prefix="null-choir-story-") as temporary:
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
            print("FAIL Ossuary Story:", error)
            return 1
        print(result.stdout, end="")
        if not accepted(result, omit_interact=args.omit_interact):
            print("FAIL Ossuary Story exit, receipt or diagnostic contract")
            return 1
    print("PASS strict Ossuary Story runner: " + ("expected omitted interaction" if args.omit_interact else "earned spur/return"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
