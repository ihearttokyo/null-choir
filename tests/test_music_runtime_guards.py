"""Resident Python guards; no engine, renderer, listening or network evidence."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SOURCE_ROOT = Path(os.environ.get('SCORE_GUARD_ROOT', Path(__file__).resolve().parents[1]))
MODES = ((), ('-O',), ('-OO',))
PROBE = r'''
import copy, hashlib, importlib.util, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location('score_encoder', root/'tools/compose_music.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
task = sys.argv[2]
if task == 'vlq':
    try:
        m.vlq(int(sys.argv[3]))
    except AssertionError:
        print('REJECTED')
    else:
        print('ACCEPTED')
elif task == 'valid':
    result = {}
    for level in ('gate', *m.LEVELS):
        data = m.compose(json.loads((root/f'source/music/{level}.json').read_text()))
        result[level] = {'matches': data == (root/f'game/audio/{level}.mid').read_bytes(),
                         'sha256': hashlib.sha256(data).hexdigest()}
    print(json.dumps(result, sort_keys=True))
else:
    base = json.loads((root/'source/music/gate.json').read_text())
    base.update(sections=[{'name':'Phrase', 'beats':12, 'parts':{'guitar':['a']}},
                          {'name':'Release', 'beats':4, 'parts':{}}],
                phrases={'guitar':{'a':{'beats':4,
                         'notes':[[0,0.5,[72],100],[0.5,0.5,[72],90]]}}})
    cases = ('ppq', 'sections', 'voices', 'first_tempo', 'missing_tempo',
             'meter', 'meter_end', 'parts', 'palette', 'mix', 'cycle',
             'overlap', 'tail', 'velocity', 'empty_pitches', 'duplicate_pitch',
             'pitch', 'bend_order', 'bend_end', 'bend_center', 'drum_bend')
    result = {}
    for name in cases:
        score = copy.deepcopy(base)
        phrase = score['phrases']['guitar']['a']
        if name == 'ppq': score['ppq'] = 0
        elif name == 'sections': score['sections'][0]['beats'] = 11
        elif name == 'voices': score['phrases']['other'] = {}
        elif name == 'first_tempo': score['tempos'] = [[1,500000]]
        elif name == 'missing_tempo': score['tempos'] = []
        elif name == 'meter': score['meters'] = [[0,4,3]]
        elif name == 'meter_end': score['meters'] = [[16,4,4]]
        elif name == 'parts': score['sections'][0]['parts']['other'] = []
        elif name == 'palette': score['programs']['guitar'] = 31
        elif name == 'mix': score['mix'] = {'guitar':[128,48]}
        elif name == 'cycle': phrase['beats'] = 5
        elif name == 'overlap': phrase['notes'][0][1] = 0.75
        elif name == 'tail': phrase['notes'][0][1] = 5
        elif name == 'velocity': phrase['notes'][0][3] = 0
        elif name == 'empty_pitches': phrase['notes'][0][2] = []
        elif name == 'duplicate_pitch': phrase['notes'][0][2] = [72,72]
        elif name == 'pitch': phrase['notes'][0][2] = [128]
        elif name == 'bend_order': phrase['bends'] = [[1,8192],[0,9000],[2,8192]]
        elif name == 'bend_end': phrase['bends'] = [[5,8192]]
        elif name == 'bend_center': phrase['bends'] = [[0,8192],[1,9000]]
        else:
            score['phrases']['drums'] = {'a': copy.deepcopy(phrase)}
            score['phrases']['drums']['a']['bends'] = [[1,8192]]
            score['sections'][0]['parts']['drums'] = ['a']
        try:
            m.compose(score)
        except AssertionError:
            result[name] = 'REJECTED'
        except Exception as exc:
            result[name] = type(exc).__name__
        else:
            result[name] = 'ACCEPTED'
    print(json.dumps(result, sort_keys=True))
'''


class MusicRuntimeGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Never mutate the source project's scores/tracks; retain the private fixture.
        cls.root = Path(tempfile.mkdtemp(prefix='music-runtime-guards-'))
        for folder, names in (('tools', ['compose_music.py']),
                              ('source/music', [p.name for p in (SOURCE_ROOT/'source/music').glob('*.json')]),
                              ('game/audio', [p.name for p in (SOURCE_ROOT/'game/audio').glob('*.mid')])):
            target = cls.root/folder
            target.mkdir(parents=True)
            for name in names:
                (target/name).write_bytes((SOURCE_ROOT/folder/name).read_bytes())

    def run_python(self, mode, args):
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
        env.pop('PYTHONOPTIMIZE', None)
        try:
            completed = subprocess.run([sys.executable, *mode, *args],
                                       cwd=self.root, env=env, capture_output=True,
                                       text=True, timeout=2)
        except subprocess.TimeoutExpired:
            self.fail('Encoder did not reject promptly; owned Python child stopped at deadline')
        self.assertLess(len(completed.stdout) + len(completed.stderr), 65536)
        return completed

    def probe(self, mode, task, *args):
        return self.run_python(mode, ['-c', PROBE, str(self.root), task, *map(str, args)])

    def test_invalid_vlq_rejected_in_all_modes(self):
        for mode in MODES:
            for value in (-1, 0x10000000):
                with self.subTest(mode=mode, value=value):
                    result = self.probe(mode, 'vlq', value)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.strip(), 'REJECTED')

    def test_invalid_authored_scores_rejected_in_all_modes(self):
        for mode in MODES:
            with self.subTest(mode=mode):
                result = self.probe(mode, 'invalid')
                self.assertEqual(result.returncode, 0, result.stderr)
                cases = json.loads(result.stdout)
                self.assertEqual(len(cases), 21)
                self.assertEqual(cases, dict.fromkeys(cases, 'REJECTED'))

    def test_gate_mismatch_never_reports_green(self):
        gate = self.root/'game/audio/gate.mid'
        before = gate.read_bytes()
        try:
            gate.write_bytes(before[:-1] + bytes([before[-1] ^ 1]))
            for mode in MODES:
                with self.subTest(mode=mode):
                    result = self.run_python(mode, [str(self.root/'tools/compose_music.py'), '--gate'])
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertNotIn('GATE_GREEN', result.stdout)
                    self.assertEqual(gate.read_bytes(), before[:-1] + bytes([before[-1] ^ 1]))
        finally:
            gate.write_bytes(before)

    def test_late_invalid_score_preserves_all_campaign_files(self):
        intake, heart = (self.root/f'source/music/{name}.json' for name in ('intake', 'heart'))
        sources = {p:p.read_bytes() for p in (intake, heart)}
        tracks = {p:p.read_bytes() for p in (self.root/'game/audio').glob('*.mid')}
        try:
            score = json.loads(sources[intake])
            score.setdefault('mix', {})['guitar'] = [91, 0]
            intake.write_text(json.dumps(score))
            score = json.loads(sources[heart])
            score['programs']['guitar'] = 31
            heart.write_text(json.dumps(score))
            for mode in MODES:
                with self.subTest(mode=mode):
                    result = self.run_python(mode, [str(self.root/'tools/compose_music.py')])
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertNotIn('COMPOSE_GREEN', result.stdout)
                    self.assertEqual({p:p.read_bytes() for p in tracks}, tracks)
                for p, data in tracks.items():
                    p.write_bytes(data)
        finally:
            for p, data in {**sources, **tracks}.items():
                p.write_bytes(data)

    def test_valid_gate_and_eight_scores_are_byte_identical(self):
        expected = {p.stem:hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in (self.root/'game/audio').glob('*.mid')}
        self.assertEqual(len(expected), 9)
        for mode in MODES:
            with self.subTest(mode=mode):
                result = self.probe(mode, 'valid')
                self.assertEqual(result.returncode, 0, result.stderr)
                encoded = json.loads(result.stdout)
                self.assertEqual({k:v['sha256'] for k,v in encoded.items()}, expected)
                self.assertTrue(all(v['matches'] for v in encoded.values()))


if __name__ == '__main__':
    unittest.main()
