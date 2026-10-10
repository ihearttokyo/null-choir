"""Native Metal export is windowed; refuse it by default without side effects."""
import importlib.util
from pathlib import Path
import tempfile
import subprocess
import sys
from unittest.mock import patch

source = Path(__file__).resolve().parents[1] / 'tools/build_macos.py'
spec = importlib.util.spec_from_file_location('build_macos', source)
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    with patch.object(build, 'ROOT', root), patch.object(build, 'OUTPUT', root / 'builds/app.zip'), patch.object(build, 'run') as engine:
        try:
            build.main()
        except RuntimeError as error:
            assert '--allow-window' in str(error) and 'Metal' in str(error)
        else:
            raise AssertionError('Export must refuse window activation without explicit opt-in')
        engine.assert_not_called()
        assert list(root.iterdir()) == [], 'Refusal must precede scratch/output creation'

    (root / 'game').mkdir()
    commands = []
    deadlines = []

    class ExportBoundary(Exception):
        pass

    def record(*args, **kwargs):
        commands.append(args)
        deadlines.append(kwargs)
        if '--export-release' in args:
            raise ExportBoundary()
        return ''

    with patch.object(build, 'ROOT', root), patch.object(build, 'OUTPUT', root / 'builds/app.zip'), patch.object(build, 'run', record):
        try:
            build.main(allow_window=True)
        except ExportBoundary:
            pass
        else:
            raise AssertionError('Mock must stop before native export')
    assert len(commands) == 3
    assert deadlines == [{}, {}, {"timeout":600}], "INTENDED RED: cold Mobile Metal shader baking needs its own bounded 600s deadline; other commands retain 180s"
    assert all('--headless' in command for command in commands[:2])
    export = commands[2]
    assert '--headless' not in export, 'Dummy rendering cannot bake native Metal shaders'
    assert export[export.index('--rendering-driver') + 1] == 'metal'
    assert '--rendering-method' in export and export[export.index('--rendering-method') + 1] == 'mobile', 'INTENDED RED: bake the shipped Mobile renderer, not driver-default Forward+'
print('PASS default build has no engine/filesystem effects; explicit window opt-in retains native Metal export')


# Exercise the connected native canary without an engine or real source mutation.
canary_spec = importlib.util.spec_from_file_location("build_source_canary", source.parents[1] / "tests/test_build_source.py")
canary = importlib.util.module_from_spec(canary_spec)
canary_spec.loader.exec_module(canary)
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    for name in ("project.godot", "export_presets.cfg", "scripts/main.gd", "licenses/Godot-Third-Party.txt"):
        path = root / "game" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("preserved fixture source")
    with patch.object(canary, "__file__", str(root / "tests/test_build_source.py")), patch.object(sys, "argv", ["test_build_source.py", "--allow-window"]), patch.object(canary, "run_isolated") as run:
        run.return_value = subprocess.CompletedProcess([], 0, "", "")
        canary.main()
    assert run.call_args.args[1] == 750, "INTENDED RED: source-preservation canary must outlast 600s export plus orchestration"
