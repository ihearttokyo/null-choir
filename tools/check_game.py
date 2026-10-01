#!/usr/bin/env python3
"""Run direct Godot assertions with a deadline and require their PASS receipt."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def accepted(result):
    return result.returncode == 0 and "PASS " in result.stdout and not any(
        marker in result.stdout for marker in ("ERROR:", "SCRIPT ERROR:", "Assertion failed")
    )


def main():
    assert accepted(subprocess.CompletedProcess([], 0, "PASS test"))
    assert not accepted(subprocess.CompletedProcess([], 0, "ERROR: failure\nPASS test"))
    assert not accepted(subprocess.CompletedProcess([], 0, ""))
    assert not accepted(subprocess.CompletedProcess([], 1, "PASS test"))
    scripts = sys.argv[1:] or ["tests/test_campaign.gd"]
    for script in scripts:
        try:
            result = subprocess.run(
                ["godot", "--headless", "--path", str(ROOT / "game"), "--quit-after", "10000", "--script", script],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=30,
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
