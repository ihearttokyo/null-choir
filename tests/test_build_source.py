"""Native build must preserve the editable source, including editor defaults."""
from pathlib import Path
import hashlib
import subprocess
import os
import signal

def run_isolated(args, timeout):
    with subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True) as process:
        try:
            stdout, stderr = process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.communicate()
            raise
        return subprocess.CompletedProcess(args, process.returncode, stdout, stderr)


def main():
    ROOT = Path(__file__).resolve().parents[1]
    paths = [ROOT / 'game' / name for name in ('project.godot', 'export_presets.cfg', 'scripts/main.gd', 'licenses/Godot-Third-Party.txt')]
    before = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
    result = run_isolated(['python3', str(ROOT / 'tools/build_macos.py')], 300)
    print(result.stdout + result.stderr)
    assert result.returncode == 0, 'Native build must succeed before source preservation can be accepted'
    assert all(hashlib.sha256(path.read_bytes()).hexdigest() == digest for path, digest in before.items()), 'INTENDED RED: native build rewrote the editable source'
    print('PASS native build preserves project settings, export preset, main source and license notices')


if __name__ == '__main__':
    main()
