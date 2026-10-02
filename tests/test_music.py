"""Deterministic score/encoder contracts; native SMF parsing lives in Godot."""
import copy
import hashlib
import json
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from compose_music import ROOT, LEVELS, VOICES, compose, vlq


def test_encoder():
    assert [vlq(n) for n in (0, 127, 128, 0x0FFFFFFF)] == [
        b'\x00', b'\x7f', b'\x81\x00', b'\xff\xff\xff\x7f']
    gate = (ROOT / 'source/music/gate.json').read_bytes()
    assert hashlib.sha256(gate).hexdigest() == 'e0b5300b4fef2cc08e0f9065c9ef55514d90f9c99ddc632db39fc019ca147cf4'
    spec = json.loads(gate)
    assert hashlib.sha256(compose(spec)).hexdigest() == '6dd153f678b00f3302fe18faf28a93896e33dfd597b024e0e397ee74a1f9dc99'
    spec.update(sections=[{'name': 'Authored phrase', 'beats': 12,
                          'parts': {'guitar': ['a']}},
                         {'name': 'Release', 'beats': 4, 'parts': {}}],
                phrases={'guitar': {'a': {'beats': 4,
                           'notes': [[0, 0.5, [72], 100], [0.5, 0.5, [72], 90]]}}})
    altered = copy.deepcopy(spec)
    altered['phrases']['guitar']['a']['notes'][0][2] = [73]
    assert compose(spec) != compose(altered), 'Authored section notes must drive MIDI, not the legacy gate riff'
    assert b'\x90\x48\x64' in compose(spec), 'Authored chord note must reach MIDI channel 0'
    assert b'\x80\x48\x00\x00\x90\x48\x5a' in compose(spec), 'Same-tick off must precede retrigger'
    for change in ('overlap', 'tail', 'bend', 'unresolved', 'palette', 'cycle'):
        bad = copy.deepcopy(spec)
        phrase = bad['phrases']['guitar']['a']
        if change == 'overlap':
            phrase['notes'][0][1] = 0.75
        elif change == 'tail':
            phrase['notes'][0][1] = 5
        elif change == 'bend':
            phrase['bends'] = [[1, 8192], [0, 9000], [2, 8192]]
        elif change == 'unresolved':
            phrase['bends'] = [[0, 8192], [1, 9000]]
        elif change == 'palette':
            bad['programs']['guitar'] = 31
        else:
            phrase['beats'] = 5
        try:
            compose(bad)
        except AssertionError:
            pass
        else:
            raise AssertionError(f'Unsafe {change} must be rejected')


def seconds_at(spec, beat):
    seconds = 0.0
    for i, (start, tempo) in enumerate(spec['tempos']):
        stop = spec['tempos'][i + 1][0] if i + 1 < len(spec['tempos']) else spec['beats']
        seconds += max(0, min(beat, stop) - start) * tempo / 1_000_000
    return seconds


def test_campaign():
    assert {p.stem for p in (ROOT / 'source/music').glob('*.json')} == {'gate', *LEVELS}
    assert {p.stem for p in (ROOT / 'game/audio').glob('*.mid')} == {'gate', *LEVELS}
    riffs, drum_rhythms, hashes = set(), set(), set()
    for level in LEVELS:
        spec = json.loads((ROOT / f'source/music/{level}.json').read_text())
        assert spec['level'] == level and spec['identity'] and spec['author']
        assert spec['ppq'] == 480 and spec['programs'] == {k: v[1] for k, v in VOICES.items()}
        assert set(spec['phrases']) == VOICES.keys()
        assert len(spec['sections']) >= 7 and spec['sections'][-1]['parts'] == {}
        assert len({json.dumps(s['parts'], sort_keys=True) for s in spec['sections']}) >= 5
        used = {voice: set() for voice in VOICES}
        for section in spec['sections']:
            for voice, names in section['parts'].items():
                used[voice].update(names)
        for voice in VOICES:
            assert used[voice] == spec['phrases'][voice].keys(), 'Every authored phrase must be used'
            assert len(used[voice]) >= 2
        first = next(iter(spec['phrases']['guitar'].values()))
        base = min(n for row in first['notes'] for n in row[2])
        riffs.add(json.dumps([first['beats'], [[t, d, [n - base for n in pitches]]
                   for t, d, pitches, _ in first['notes']]]))
        drums = next(iter(spec['phrases']['drums'].values()))
        drum_rhythms.add(json.dumps([drums['beats'], [[t, pitches] for t, _, pitches, _ in drums['notes']]]))
        data = compose(spec)
        assert data == compose(spec) == (ROOT / f'game/audio/{level}.mid').read_bytes()
        assert data[:14] == b'MThd' + struct.pack('>IHHH', 6, 1, 6, 480)
        digest = hashlib.sha256(data).hexdigest()
        hashes.add(digest)
        duration = seconds_at(spec, spec['beats'])
        musical_end = spec['beats'] - spec['sections'][-1]['beats']
        release = duration - seconds_at(spec, musical_end)
        assert 60 <= duration <= 120 and release >= 2
        print(f'PASS source {level}: {duration:.3f}s; release >= {release:.3f}s; {len(spec["sections"])} sections; sha256 {digest}')
    assert len(riffs) == len(drum_rhythms) == len(hashes) == 8, 'Songs need distinct relative-pitch riffs and drum rhythms, not transpositions'


if __name__ == '__main__':
    test_encoder()
    print('MUSIC_ENCODER_GREEN: VLQ, frozen gate, authored phrase changes output')
    test_campaign()
    print('PASS campaign scores: deterministic parity, duration, release, eight distinct motifs/arrangements')
