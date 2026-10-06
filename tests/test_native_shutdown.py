"""Real native GPU/CoreAudio shutdown; headless rendering did not expose the leak."""
from pathlib import Path
import os
import subprocess
import tempfile
ROOT = Path(__file__).resolve().parents[1]
def main():
    for mode in ('normal', 'discard'):
        with tempfile.TemporaryDirectory(prefix='null-choir-shutdown-', dir='/private/tmp') as tmp:
            home = Path(tmp) / 'validation-home'
            home.mkdir()
            env = {**os.environ, 'HOME':str(home), 'XDG_DATA_HOME':str(home/'data'), 'XDG_CONFIG_HOME':str(home/'config')}
            result = subprocess.run(['godot', '--audio-driver', 'CoreAudio', '--path', str(ROOT/'game'), '--script', 'tests/test_shutdown.gd', '--', mode, tmp], capture_output=True, text=True, timeout=30, env=env)
            output = result.stdout + result.stderr
            print(output, end='')
            assert result.returncode == 0 and 'Metal' in output and 'PASS native CoreAudio shutdown' in output, output
            assert not any(marker in output.lower() for marker in ('error:', 'warning:', 'leaked', 'orphan', 'resources still in use')), output
    print('PASS real native normal/discard shutdown, failed-save retention and no live audio playback leak')


if __name__ == '__main__':
    main()
