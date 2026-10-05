#!/usr/bin/env python3
"""Run direct Godot assertions with a deadline and require their PASS receipt."""
from pathlib import Path
import argparse
import math
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def accepted(result):
    return result.returncode == 0 and "PASS " in result.stdout and not any(
        marker in result.stdout for marker in ("ERROR:", "SCRIPT ERROR:", "Assertion failed", "leaked at exit", "resources still in use")
    )


def arguments(argv=None):
    def deadline(value):
        value = float(value)
        if not math.isfinite(value) or value <= 0:
            raise argparse.ArgumentTypeError('timeout must be finite and positive')
        return value
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--timeout', type=deadline, default=30)
    parser.add_argument('scripts', nargs='*', default=['tests/test_campaign.gd'])
    return parser.parse_args(argv)


def main():
    assert accepted(subprocess.CompletedProcess([], 0, "PASS test"))
    assert not accepted(subprocess.CompletedProcess([], 0, "ERROR: failure\nPASS test"))
    assert not accepted(subprocess.CompletedProcess([], 0, ""))
    assert not accepted(subprocess.CompletedProcess([], 1, "PASS test"))
    assert not accepted(subprocess.CompletedProcess([], 0, "PASS test\nWARNING: 15 ObjectDB instances were leaked at exit"))
    assert not accepted(subprocess.CompletedProcess([], 0, "PASS test\nWARNING: 1 resources still in use at exit"))
    args = arguments()
    for script in args.scripts:
        try:
            result = subprocess.run(
                ["godot", "--headless", "--audio-driver", "CoreAudio", "--path", str(ROOT / "game"), "--script", script],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=args.timeout,
            )
        except subprocess.TimeoutExpired as error:
            print(error.stdout or "", "FAIL: Godot deadline exceeded", file=sys.stderr)
            return 1
        print(result.stdout, end="")
        if not accepted(result):
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
