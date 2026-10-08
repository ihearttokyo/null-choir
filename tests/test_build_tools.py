"""Atomic Mac delivery and explicit native-fixture deadlines."""
import importlib.util
import hashlib
import os
from pathlib import Path
import tempfile
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check_notice_isolation(build):
    class ExportHeld(Exception):
        pass

    # Real copy/export orchestration, simulated external engine writes; no Godot launch.
    for interrupted in (True, False):
        with tempfile.TemporaryDirectory(prefix='null-choir-notice-test-') as directory:
            root = Path(directory)
            files = ('project.godot', 'export_presets.cfg', 'scripts/main.gd', 'licenses/Godot-Third-Party.txt')
            for name in files:
                path = root / 'game' / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b'original editable source: ' + name.encode())
            before = {name: (root / 'game' / name).read_bytes() for name in files}
            targets = []

            def engine(*args):
                project = Path(args[args.index('--path') + 1])
                if '--script' in args:
                    assert Path(args[args.index('--script') + 1]).name == 'export_engine_licenses.gd'
                    targets.append(project)
                    notice = project / 'licenses/Godot-Third-Party.txt'
                    assert notice.read_bytes() == before['licenses/Godot-Third-Party.txt']
                    notice.write_bytes(b'partial notice' if interrupted else b'new engine notice')
                    if interrupted:
                        raise ExportHeld()
                    return 'simulated generated notices'
                assert '--import' in args and targets == [project]
                assert (project / 'licenses/Godot-Third-Party.txt').read_bytes() == b'new engine notice'
                raise ExportHeld()

            with patch.object(build, 'ROOT', root), patch.object(build, 'OUTPUT', root / 'builds/delivery.zip'), patch.object(build, 'run', engine):
                try:
                    build.main(allow_window=True)
                except ExportHeld:
                    pass
                else:
                    raise AssertionError('Fixture must hold before native import/export')
            assert all((root / 'game' / name).read_bytes() == data for name, data in before.items()), 'INTENDED RED: notice generation rewrote or truncated editable source'
            assert len(targets) == 1 and targets[0] != root / 'game', 'Generate notices only in the scratch project'


def main():
    build = load('build_macos')
    check = load('check_game')
    check_notice_isolation(build)
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        app = root / 'Example.app'
        binary = app / 'Contents/MacOS/Example'
        binary.parent.mkdir(parents=True)
        binary.write_bytes(b'fixture executable')
        binary.chmod(0o755)
        output = root / 'delivery.zip'
        output.write_bytes(b'previous validated delivery')
        output.chmod(0o640)
        before = output.read_bytes()
        try:
            build.archive_app(root / 'Missing.app', output)
        except (ValueError, FileNotFoundError):
            pass
        else:
            raise AssertionError('Invalid source must not replace an existing delivery')
        assert output.read_bytes() == before
        build.archive_app(app, output)
        assert output.stat().st_mode & 0o777 == 0o640, 'Retain existing delivery permissions'
        with zipfile.ZipFile(output) as archive:
            assert archive.testzip() is None
            assert archive.namelist() == ['Example.app/Contents/MacOS/Example']
            assert archive.read(archive.namelist()[0]) == binary.read_bytes()
            assert archive.getinfo(archive.namelist()[0]).external_attr >> 16 & 0o111 == 0o111
        assert build.file_sha256(output) == hashlib.sha256(output.read_bytes()).hexdigest()
        assert set(root.iterdir()) == {app, output}, 'No abandoned partial ZIP'
        # A real filesystem error, not a mocked exporter: the destination is a directory.
        blocked = root / 'blocked.zip'
        blocked.mkdir()
        try:
            build.archive_app(app, blocked)
        except OSError:
            pass
        else:
            raise AssertionError('Failed promotion must be reported')
        assert blocked.is_dir() and set(root.iterdir()) == {app, output, blocked}
        for mask, expected in [(0o022, 0o644), (0o077, 0o600)]:
            fresh = root / f'fresh-{mask}.zip'
            previous_mask = os.umask(mask)
            try:
                build.archive_app(app, fresh)
            finally:
                os.umask(previous_mask)
            assert fresh.stat().st_mode & 0o777 == expected, 'Respect creation umask'
    args = check.arguments(['--timeout', '150', 'tests/test_late_encounters.gd'])
    assert args.timeout == 150 and args.scripts == ['tests/test_late_encounters.gd']
    assert check.arguments([]).timeout == 30
    for invalid in ['0', '-1', 'nan', 'inf']:
        try:
            check.arguments(['--timeout', invalid])
        except SystemExit as error:
            assert error.code == 2
        else:
            raise AssertionError('Reject invalid deadline: ' + invalid)
    print('PASS offline scratch notice isolation including interrupted generation, atomic complete ZIP, failed-promotion preservation, executable permissions, streaming checksum and explicit finite deadlines')


if __name__ == '__main__':
    main()
