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


def file_sha256(path):
    with Path(path).open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def archive_app(app, output):
    files = sorted(file for file in app.rglob('*') if file.is_file())
    if app.suffix != '.app' or not files:
        raise ValueError(f'Missing or empty application bundle: {app}')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=output.parent, prefix=output.name + '.', suffix='.tmp', delete=False) as partial:
        path = Path(partial.name)
    try:
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as archive:
            for file in files:
                archive.write(file, file.relative_to(app.parent))
        with zipfile.ZipFile(path) as archive:
            if archive.testzip() is not None:
                raise ValueError('Application ZIP failed its CRC check')
        path.replace(output)
    finally:
        path.unlink(missing_ok=True)


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
        archive_app(app, OUTPUT)
    print(f'BUILT {OUTPUT} SHA256 {file_sha256(OUTPUT)}')


if __name__ == '__main__':
    main()
