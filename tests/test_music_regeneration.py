"""Exercise score regeneration through the actual CLI, without an engine."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from compose_music import LEVELS, ROOT, compose


class MusicRegenerationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='null-choir-score-')
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        paths = ['tools/compose_music.py']
        for name in (*LEVELS, 'gate'):
            paths.extend([f'source/music/{name}.json', f'game/audio/{name}.mid'])
        for name in paths:
            destination = self.root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, destination)
        self.originals = self.outputs()
        # An earlier valid edit must genuinely change the would-be output.
        path = self.root / 'source/music/intake.json'
        spec = json.loads(path.read_text())
        spec['mix']['guitar'][0] -= 1
        self.assertNotEqual(compose(spec), self.originals['intake.mid'])
        path.write_text(json.dumps(spec))

    def outputs(self):
        return {path.name: path.read_bytes()
                for path in (self.root / 'game/audio').glob('*.mid')}

    def run_cli(self, *arguments):
        return subprocess.run(
            [sys.executable, '-B', str(self.root / 'tools/compose_music.py'), *arguments],
            capture_output=True, text=True, timeout=10, cwd=self.root)

    def test_late_invalid_score_preserves_all_existing_tracks(self):
        path = self.root / 'source/music/heart.json'
        original = path.read_text()
        for failure in ('missing', 'json', 'palette'):
            with self.subTest(failure=failure):
                for name, data in self.originals.items():
                    (self.root / 'game/audio' / name).write_bytes(data)
                if failure == 'missing':
                    path.unlink()
                elif failure == 'json':
                    path.write_text('{')
                else:
                    spec = json.loads(original)
                    spec['programs']['guitar'] = 31
                    path.write_text(json.dumps(spec))
                result = self.run_cli()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.outputs(), self.originals)
                self.assertNotIn('COMPOSE_GREEN', result.stdout)
                path.write_text(original)

    def test_successful_regeneration_matches_all_authored_scores(self):
        result = self.run_cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count('COMPOSE_GREEN:'), len(LEVELS))
        for name in LEVELS:
            spec = json.loads((self.root / f'source/music/{name}.json').read_text())
            self.assertEqual((self.root / f'game/audio/{name}.mid').read_bytes(), compose(spec))
        self.assertEqual(self.outputs()['gate.mid'], self.originals['gate.mid'])

    def test_gate_verification_never_regenerates_campaign(self):
        (self.root / 'source/music/heart.json').write_text('{')
        result = self.run_cli('--gate')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('GATE_GREEN:', result.stdout)
        self.assertEqual(self.outputs(), self.originals)


if __name__ == '__main__':
    unittest.main()
