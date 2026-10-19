"""Read-only title-cue contract through the existing encoder and MIDI/SF2 auditor."""
import copy
import hashlib
import json
from pathlib import Path
import sys

Q = Path(__file__).resolve().parents[1]
HERE = Q / 'source/music'
sys.path.insert(0, str(Q / 'tools'))
from compose_music import compose_song, VOICES
from music_demand import audit_midi, decode_midi, read_bank


def material(spec, section, voice):
    result, offset = [], 0
    phrases = [spec['phrases'][voice][name] for name in section['parts'][voice]]
    cycle = sum(p['beats'] for p in phrases)
    assert cycle > 0 and section['beats'] % cycle == 0
    for _ in range(int(section['beats'] / cycle)):
        for phrase in phrases:
            result.extend((offset + beat, duration, tuple(pitches))
                          for beat, duration, pitches, _ in phrase['notes'])
            offset += phrase['beats']
    return result


def test_title():
    spec = json.loads((HERE / 'title_theme.json').read_text())
    data = compose_song(spec)
    sections = {s['name']: s for s in spec['sections']}
    assert [row[2][0] for row in spec['phrases']['guitar']['hook']['notes'][:6]] == [38, 39, 45, 44, 41, 38]
    hook = material(spec, sections['The restraint turns'], 'guitar')
    reprise = material(spec, sections['The restraint remembers'], 'guitar')
    assert hook[:6] == reprise[:6], 'Return must retain the identifiable opening hook'
    assert hook != reprise, 'Return must develop guitar pitches/rhythm beyond the retained hook'
    assert material(spec, sections['The restraint turns'], 'bass') != material(
        spec, sections['The restraint remembers'], 'bass'), 'Return needs an independent changed bass route'
    assert data == compose_song(spec) == (HERE / 'title_theme.mid').read_bytes()
    assert spec['ppq'] == 480 and spec['programs'] == {k: v[1] for k, v in VOICES.items()}
    assert set(spec['phrases']) == set(VOICES)
    assert spec['sections'][-1]['parts'] == {} and len(spec['sections']) >= 7
    assert len({json.dumps(s['parts'], sort_keys=True) for s in spec['sections']}) >= 6
    for voice, phrases in spec['phrases'].items():
        used = {name for s in spec['sections'] for name in s['parts'].get(voice, [])}
        assert used == set(phrases) and len(used) >= 3
        assert all(p['beats'] >= 8 for p in phrases.values()), 'Use developed multi-bar phrases'
        assert spec['mix'][voice][0] <= VOICES[voice][2]
    assert spec['mix']['bass'][1] == spec['mix']['drums'][1] == 64
    assert {p for ph in spec['phrases']['drums'].values() for _, _, ps, _ in ph['notes'] for p in ps} == {36, 38, 42}
    with (Q / 'game/audio/GeneralUser-GS.sf2').open('rb') as source:
        bank = read_bank(source)
    assert {19, 30, 34, 81, 16384} <= bank.presets.keys(), 'Exact bank presets, not fallback'
    report = audit_midi(data, bank)
    ppq, events = decode_midi(data)
    end = round(spec['beats'] * ppq)
    bends, controls, active, peak = {}, {}, set(), 0
    for event in events:
        assert 0 <= event.tick <= end
        if event.kind == 'bend':
            channel, low, high = event.values
            bends[channel] = low | high << 7
        elif event.kind == 'cc':
            channel, controller, value = event.values
            controls[channel, controller] = value
        elif event.kind == 'on':
            channel, pitch, _ = event.values
            assert (channel, pitch) not in active
            active.add((channel, pitch))
            peak = max(peak, len(active))
        elif event.kind == 'off':
            channel, pitch, _ = event.values
            active.remove((channel, pitch))
    assert not active and bends == dict.fromkeys([0, 1, 2, 3, 9], 8192)
    assert all(controls[c, 64] == 0 for c in (0, 1, 2, 3, 9))
    assert len([e for e in events if e.kind == 'end' and e.tick == end]) == 6
    assert peak <= 10, 'Bound score-key density; this is not native synth occupancy'
    duration = report['duration_seconds']
    assert 64 <= duration <= 96
    # This cue is constant-tempo; parent rendering owns PCM-tail and seam approval.
    assert spec['tempos'] == [[0, 416667]]
    release = spec['sections'][-1]['beats'] * 416667 / 1_000_000
    last_off = max(e.tick for e in events if e.kind == 'off')
    assert release >= 2 and last_off < end - spec['sections'][-1]['beats'] * ppq
    for damage in ('overlap', 'tail', 'unresolved_bend', 'bend_order', 'palette', 'tiling'):
        bad = copy.deepcopy(spec)
        phrase = bad['phrases']['guitar']['hook']
        if damage == 'overlap':
            phrase['notes'].append(copy.deepcopy(phrase['notes'][0]))
        elif damage == 'tail':
            phrase['notes'][0][1] = 9
        elif damage == 'unresolved_bend':
            phrase['bends'] = [[0, 8192], [1, 9000]]
        elif damage == 'bend_order':
            phrase['bends'] = [[1, 9000], [0, 8192]]
        elif damage == 'palette':
            bad['programs']['guitar'] = 31
        else:
            phrase['beats'] = 9
        try:
            compose_song(bad)
        except AssertionError:
            pass
        else:
            raise AssertionError(f'Existing encoder must reject {damage}')
    print(json.dumps({'result': 'GREEN', 'title': spec['title'], 'seconds': duration,
                      'empty_release_seconds': release, 'last_noteoff_seconds': last_off / ppq * 0.416667,
                      'sections': len(spec['sections']), 'phrases': sum(map(len, spec['phrases'].values())),
                      'score_key_peak': peak, 'midi_bytes': len(data), 'note_ons': report['note_ons'],
                      'covered_note_ons': report['coverage']['covered_note_ons'],
                      'sf2_pdta_sha256': bank.pdta_sha256, 'sha256': hashlib.sha256(data).hexdigest()}, sort_keys=True))


if __name__ == '__main__':
    test_title()
