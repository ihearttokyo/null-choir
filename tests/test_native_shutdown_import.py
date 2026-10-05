"""Import/entry safety with mocked launches only; never run a native engine."""
from contextlib import redirect_stdout
import io
import os
from pathlib import Path
import runpy
import subprocess
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).with_name('test_native_shutdown.py')


class NativeShutdownImportTests(unittest.TestCase):
    def test_import_does_not_attempt_native_launch(self):
        with patch.object(subprocess, 'run', side_effect=AssertionError('Engine launch forbidden during import')) as launch:
            namespace = runpy.run_path(str(SCRIPT), run_name='shutdown_import_probe')
            launch.assert_not_called()
        self.assertTrue(callable(namespace['main']))

    def test_explicit_entry_retains_modes_isolation_deadline_and_assertions(self):
        good = subprocess.CompletedProcess([], 0, 'Metal\nPASS native CoreAudio shutdown\n', '')
        with patch.object(subprocess, 'run', return_value=good) as launch, redirect_stdout(io.StringIO()):
            runpy.run_path(str(SCRIPT), run_name='__main__')
        self.assertEqual(launch.call_count, 2)
        for call, mode in zip(launch.call_args_list, ('normal', 'discard')):
            args = call.args[0]
            self.assertEqual(args[:-2], ['godot', '--audio-driver', 'CoreAudio', '--path',
                                        str(SCRIPT.resolve().parents[1] / 'game'), '--script',
                                        'tests/test_shutdown.gd', '--'])
            self.assertEqual(args[-2], mode)
            self.assertEqual(call.kwargs['timeout'], 30)
            self.assertTrue(call.kwargs['capture_output'] and call.kwargs['text'])
            home = str(Path(args[-1]) / 'validation-home')
            self.assertEqual(call.kwargs['env']['HOME'], home)
            self.assertNotEqual(home, os.environ.get('HOME'))
            self.assertEqual(call.kwargs['env']['XDG_DATA_HOME'], str(Path(home) / 'data'))
            self.assertEqual(call.kwargs['env']['XDG_CONFIG_HOME'], str(Path(home) / 'config'))
        for result in (subprocess.CompletedProcess([], 1, good.stdout, ''),
                       subprocess.CompletedProcess([], 0, 'PASS native CoreAudio shutdown', ''),
                       subprocess.CompletedProcess([], 0, good.stdout, 'WARNING: leak')):
            with self.subTest(result=result), patch.object(subprocess, 'run', return_value=result), redirect_stdout(io.StringIO()):
                with self.assertRaises(AssertionError):
                    runpy.run_path(str(SCRIPT), run_name='__main__')


if __name__ == '__main__':
    unittest.main()
