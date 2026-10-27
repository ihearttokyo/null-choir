"""Packed-app wrapper safety; extraction and native execution are mocked only."""
from contextlib import redirect_stdout
import io
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).with_name('test_macos.py')


class PackedAppImportTests(unittest.TestCase):
    def test_import_does_not_allocate_or_launch(self):
        forbidden = AssertionError('Filesystem and native execution forbidden during import')
        with patch.object(tempfile, 'TemporaryDirectory', side_effect=forbidden) as directory, \
             patch.object(subprocess, 'run', side_effect=forbidden) as run, \
             patch.object(subprocess, 'check_output', side_effect=forbidden) as output:
            namespace = runpy.run_path(str(SCRIPT), run_name='packed_app_import_probe')
            directory.assert_not_called()
            run.assert_not_called()
            output.assert_not_called()
        self.assertTrue(callable(namespace['main']))

    def test_explicit_entry_selects_zip_before_mocked_extraction(self):
        class ExtractionStopped(Exception):
            pass

        namespace = runpy.run_path(str(SCRIPT), run_name='packed_app_selection_identity')
        default = str(SCRIPT.resolve().parents[1] / 'builds/macos' / namespace['build_identity']()['archive_name'])
        for argv, expected in (([str(SCRIPT)], default),
                               ([str(SCRIPT), '/private/tmp/explicit-app.zip'], '/private/tmp/explicit-app.zip')):
            with self.subTest(argv=argv), patch.object(sys, 'argv', argv), \
                 patch.object(tempfile, 'TemporaryDirectory') as directory, \
                 patch.object(Path, 'is_file', autospec=True, side_effect=lambda path: str(path) == expected), \
                 patch.object(subprocess, 'run', side_effect=ExtractionStopped) as run, \
                 patch.object(subprocess, 'check_output', side_effect=AssertionError('Native execution forbidden')), \
                 redirect_stdout(io.StringIO()):
                directory.return_value.__enter__.return_value = '/private/tmp/mocked-validation'
                with self.assertRaises(ExtractionStopped):
                    runpy.run_path(str(SCRIPT), run_name='__main__')
                directory.assert_called_once_with(prefix='null-choir-check-', dir='/private/tmp')
                run.assert_called_once_with(['ditto', '-x', '-k', expected, '/private/tmp/mocked-validation'], check=True)


if __name__ == '__main__':
    unittest.main()
