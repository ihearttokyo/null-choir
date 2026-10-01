#!/usr/bin/env python3
"""Export offline Mac app; temporary files stay outside cloud-backed folders."""
from pathlib import Path
import hashlib
import plistlib
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'builds/macos/NULL CHOIR-arm64.zip'


def run(*args):
    result = subprocess.run(args, timeout=180, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode: raise RuntimeError(result.stdout)
    return result.stdout


def main():
    print(run('godot', '--headless', '--path', str(ROOT / 'game'), '--script', str(ROOT / 'tools/export_engine_licenses.gd')))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='null-choir-build-', dir='/private/tmp') as tmp:
        tmp = Path(tmp)
        export = tmp / 'export.zip'
        print(run('godot', '--headless', '--path', str(ROOT / 'game'), '--export-release', 'macOS', str(export)))
        run('ditto', '-x', '-k', str(export), str(tmp))
        app, = tmp.glob('*.app')
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        binary = app / 'Contents/MacOS' / info['CFBundleExecutable']
        thin = binary.with_suffix('.arm64')
        run('lipo', str(binary), '-thin', 'arm64', '-output', str(thin))
        thin.replace(binary)
        print(run('codesign', '--force', '--deep', '--sign', '-', str(app)))
        print(run('codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)))
        with zipfile.ZipFile(OUTPUT, 'w', zipfile.ZIP_DEFLATED) as archive:
            for file in sorted(app.rglob('*')):
                if file.is_file(): archive.write(file, file.relative_to(tmp))
    print(f'BUILT {OUTPUT} SHA256 {hashlib.sha256(OUTPUT.read_bytes()).hexdigest()}')


if __name__ == '__main__':
    main()
