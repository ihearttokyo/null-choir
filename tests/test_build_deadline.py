"""Bounded build validation terminates its own process group, not just Python."""
from pathlib import Path
import importlib.util
import os
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('build_source_test', ROOT / 'tests/test_build_source.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
result = module.run_isolated([sys.executable, '-c', 'print("normal")'], 5)
assert result.returncode == 0 and result.stdout.strip() == 'normal'
result = module.run_isolated([sys.executable, '-c', 'raise SystemExit(7)'], 5)
assert result.returncode == 7
with tempfile.TemporaryDirectory(prefix='null-choir-build-deadline-', dir='/private/tmp') as directory:
    base = Path(directory)
    child = base / 'owned_child.py'
    child.write_text('import time\ntime.sleep(30)\n')
    parent = base / 'owned_parent.py'
    parent.write_text('import subprocess,sys,time\nfrom pathlib import Path\np=subprocess.Popen([sys.executable,sys.argv[1]])\nPath(sys.argv[2]).write_text(str(p.pid))\ntime.sleep(30)\n')
    pidfile = base / 'child.pid'
    pid = None
    try:
        try:
            module.run_isolated([sys.executable, str(parent), str(child), str(pidfile)], 1)
        except subprocess.TimeoutExpired:
            pass
        else:
            raise AssertionError('Deadline must fail, not accept a partial build')
        pid = int(pidfile.read_text())
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            status = subprocess.run(['ps', '-p', str(pid), '-o', 'stat='], capture_output=True, text=True)
            if status.returncode != 0 or status.stdout.strip().startswith('Z'):
                break
            time.sleep(0.05)
        else:
            raise AssertionError('Timed-out build left a live owned descendant')
    finally:
        if pid is not None:
            row = subprocess.run(['ps', '-p', str(pid), '-o', 'command='], capture_output=True, text=True)
            if str(child) in row.stdout:
                os.kill(pid, signal.SIGKILL)
print('PASS isolated build normal/error results, deadline failure and no live owned descendant')
