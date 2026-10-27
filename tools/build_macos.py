#!/usr/bin/env python3
"""Export offline Mac app; temporary files stay outside cloud-backed folders."""
from pathlib import Path
import argparse
import ctypes
import hashlib
import importlib.util
import json
import os
import plistlib
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
_version_spec = importlib.util.spec_from_file_location('null_choir_build_iterations', ROOT / 'tools/build_iterations.py')
_versions = importlib.util.module_from_spec(_version_spec)
_version_spec.loader.exec_module(_versions)
_build_identity = _versions.active_identity(json.loads((ROOT / _versions.LEDGER).read_text()))
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
    if info.get('CFBundleDisplayName') != _build_identity['display_name']:
        raise ValueError('Exported display name does not match the reserved iteration')


def _rename_no_replace(source, target):
    """Atomic same-filesystem no-clobber rename, including a raced-in empty dir."""
    libc = ctypes.CDLL(None, use_errno=True)
    if sys.platform == 'darwin':
        rename = libc.renamex_np
        rename.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
        args = (os.fsencode(source), os.fsencode(target), 0x4)  # RENAME_EXCL
    elif sys.platform == 'linux':
        rename = libc.renameat2
        rename.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
        args = (-100, os.fsencode(source), -100, os.fsencode(target), 1)  # RENAME_NOREPLACE
    else:
        raise RuntimeError('Exclusive directory rename unavailable; refusing overwrite fallback')
    rename.restype = ctypes.c_int
    if rename(*args) != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), str(target))


def _current_export_identity():
    active = _versions.active_identity(json.loads((ROOT / _versions.LEDGER).read_text()))
    if active != _build_identity:
        raise ValueError('Reserved identity changed during export; refuse stale output')
    return active


def normalize_exported_app(app):
    """Normalize ONLY this builder's fresh current export, not an old app upgrade.

    Godot4.7.2 derives pkg_name from config/name; application/name is unsupported.
    Keep internal config/name/userdata, executable and PCK names/bytes untouched.
    """
    app = Path(app)
    active = _current_export_identity()
    if any(p.is_symlink() for p in (app, *app.parents)) or not app.is_dir():
        raise ValueError('Fresh regular exported app directory required')
    plist = app / 'Contents/Info.plist'
    if any(p.is_symlink() for p in (plist, plist.parent)) or not plist.is_file():
        raise ValueError('Actual exported Info.plist required')
    before = plist.read_bytes()
    info = plistlib.loads(before)
    expected = {'CFBundleIdentifier': 'com.ihearttokyo.nullchoir',
                'CFBundleShortVersionString': active['version'], 'CFBundleVersion': active['cfbundle_version']}
    if any(info.get(k) != v for k, v in expected.items()):
        raise ValueError('Foreign/stale/missing export metadata; never upgrade an old app')
    # ZIP exports use pkg_name for the folder; explicit .app exports already
    # have the requested folder name but still retain Godot's raw plist name.
    raw_metadata = (app.name in ('NULL CHOIR.app', active['app_name'])
                    and info.get('CFBundleName') == 'NULL CHOIR')
    friendly = (app.name == active['app_name'] and info.get('CFBundleName') == active['display_name']
                and info.get('CFBundleDisplayName') == active['display_name'])
    if not (raw_metadata or friendly) or info.get('CFBundleDisplayName', info['CFBundleName']) != info['CFBundleName']:
        raise ValueError('Only the known raw Godot name or exact friendly identity is supported')
    executable = info.get('CFBundleExecutable')
    if (not isinstance(executable, str) or executable in ('', '.', '..')
            or any(c in executable for c in ('/', '\\', '\0'))):
        raise ValueError('Safe existing CFBundleExecutable required')
    binary = app / 'Contents/MacOS' / executable
    if any(p.is_symlink() for p in (binary, binary.parent)) or not binary.is_file() or not os.access(binary, os.X_OK):
        raise ValueError('Actual regular executable missing from fresh export')
    resources = app / 'Contents/Resources'
    pck = resources / 'NULL CHOIR.pck'
    if resources.is_symlink() or not resources.is_dir() or pck.is_symlink():
        raise ValueError('Expected fresh Godot PCK without resource symlinks')
    try:
        pck_info = pck.lstat()
    except FileNotFoundError as exc:
        raise ValueError('Expected fresh Godot PCK is missing') from exc
    if (not stat.S_ISREG(pck_info.st_mode) or pck_info.st_size <= 0
            or getattr(pck_info, 'st_flags', 0) & 0x40000000):
        raise ValueError('Expected fresh Godot PCK must be regular, resident and nonempty')
    target = app.with_name(active['app_name'])
    needs_rename = app != target
    if needs_rename and os.path.lexists(target):
        raise FileExistsError('Friendly export target already exists; never overwrite it')
    info = {**info, 'CFBundleName': active['display_name'], 'CFBundleDisplayName': active['display_name']}
    # Already exact is byte-idempotent, including binary-vs-XML plist encoding.
    if friendly and plistlib.loads(before) == info:
        check_build_identity(app, info)
        return app, info
    fmt = plistlib.FMT_BINARY if before.startswith(b'bplist') else plistlib.FMT_XML
    encoded = plistlib.dumps(info, fmt=fmt, sort_keys=False)
    if needs_rename:
        _rename_no_replace(app, target)
        plist = target / 'Contents/Info.plist'
    try:
        with tempfile.NamedTemporaryFile(dir=plist.parent, prefix='Info.plist.', suffix='.tmp', delete=False) as stream:
            temporary = Path(stream.name)
            try:
                stream.write(encoded)
                stream.flush()
                os.fsync(stream.fileno())
                temporary.chmod(plist.stat().st_mode & 0o777)
                temporary.replace(plist)
            finally:
                # Clean this generated leaf BEFORE any enclosing-dir rollback.
                temporary.unlink(missing_ok=True)
    except BaseException:
        if needs_rename:
            _rename_no_replace(target, app)  # No rollback overwrite either.
        raise
    check_build_identity(target, info)
    return target, info


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
    _current_export_identity()  # Recheck a long-lived importer before any engine/workspace writes.
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
        app, info = normalize_exported_app(app)
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
