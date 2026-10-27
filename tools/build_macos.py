#!/usr/bin/env python3
"""Export offline Mac app; temporary files stay outside cloud-backed folders."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import os
import plistlib
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
_version_spec = importlib.util.spec_from_file_location('null_choir_build_iterations', ROOT / 'tools/build_iterations.py')
_versions = importlib.util.module_from_spec(_version_spec)
_version_spec.loader.exec_module(_versions)
_build_identity = _versions.identity(_versions.validate(json.loads((ROOT / _versions.LEDGER).read_text())))
OUTPUT = ROOT / 'builds/macos' / _build_identity['archive_name']


def check_build_identity(app, info):
    """Refuse a mismatched newly exported name/version before signing/archiving."""
    expected = {
        'CFBundleName': _build_identity['display_name'],
        'CFBundleIdentifier': 'com.ihearttokyo.nullchoir',
        'CFBundleShortVersionString': _build_identity['version'],
        'CFBundleVersion': _build_identity['cfbundle_version'],
    }
    if app.name != _build_identity['app_name'] or any(info.get(k) != v for k, v in expected.items()):
        raise ValueError('Exported app identity does not match the reserved development iteration')
    if info.get('CFBundleDisplayName', _build_identity['display_name']) != _build_identity['display_name']:
        raise ValueError('Exported display name does not match the reserved iteration')


def file_sha256(path):
    with Path(path).open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def archive_app(app, output):
    files = sorted(file for file in app.rglob('*') if file.is_file())
    if app.suffix != '.app' or not files:
        raise ValueError(f'Missing or empty application bundle: {app}')
    output.parent.mkdir(parents=True, exist_ok=True)
    mask = os.umask(0)
    os.umask(mask)
    mode = output.stat().st_mode & 0o777 if output.is_file() else 0o666 & ~mask
    with tempfile.NamedTemporaryFile(dir=output.parent, prefix=output.name + '.', suffix='.tmp', delete=False) as partial:
        path = Path(partial.name)
    try:
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as archive:
            for file in files:
                archive.write(file, file.relative_to(app.parent))
        with zipfile.ZipFile(path) as archive:
            if archive.testzip() is not None:
                raise ValueError('Application ZIP failed its CRC check')
        path.chmod(mode)
        path.replace(output)
    finally:
        path.unlink(missing_ok=True)


def run(*args, timeout=180):
    result = subprocess.run(args, timeout=timeout, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode: raise RuntimeError(result.stdout)
    return result.stdout


def main(*, allow_window=False):
    if not allow_window:
        raise RuntimeError('Metal shader baking requires a graphics window and may activate Godot. Run with --allow-window only when foreground use is intended.')
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='null-choir-build-', dir='/private/tmp') as tmp:
        tmp = Path(tmp)
        export = tmp / 'export.zip'
        game = tmp / 'game'
        shutil.copytree(ROOT / 'game', game, ignore=shutil.ignore_patterns('.godot'))
        print(run('godot', '--headless', '--path', str(game), '--script', str(ROOT / 'tools/export_engine_licenses.gd')))
        print(run('godot', '--headless', '--editor', '--path', str(game), '--import'))
        print(run('godot', '--rendering-method', 'mobile', '--rendering-driver', 'metal', '--path', str(game), '--export-release', 'macOS', str(export), timeout=600))
        run('ditto', '-x', '-k', str(export), str(tmp))
        app, = tmp.glob('*.app')
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        check_build_identity(app, info)
        binary = app / 'Contents/MacOS' / info['CFBundleExecutable']
        thin = binary.with_suffix('.arm64')
        run('lipo', str(binary), '-thin', 'arm64', '-output', str(thin))
        thin.replace(binary)
        print(run('codesign', '--force', '--deep', '--sign', '-', str(app)))
        print(run('codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)))
        archive_app(app, OUTPUT)
    print(f'BUILT {OUTPUT} SHA256 {file_sha256(OUTPUT)}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--allow-window', action='store_true', help='Permit Godot to open/activate a graphics window for native Metal baking')
    args = parser.parse_args()
    main(allow_window=args.allow_window)
