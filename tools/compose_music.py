#!/usr/bin/env python3
"""Encode editable campaign scores and the unchanged gate with Python stdlib."""
import argparse
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEVELS = ('intake', 'foundry', 'processional', 'reliquary',
          'nursery', 'ossuary', 'inversion', 'heart')
VOICES = {'guitar': (0, 30, 91, 48), 'bass': (1, 34, 94, 64),
          'organ': (2, 19, 70, 76), 'synth': (3, 81, 68, 88),
          'drums': (9, 0, 96, 64)}


def vlq(value):
    assert 0 <= value <= 0x0FFFFFFF
    result = [value & 127]
    while value >> 7:
        value >>= 7
        result.insert(0, (value & 127) | 128)
    return bytes(result)


def track(events, end):
    output = bytearray()
    previous = 0
    for tick, event in sorted(events, key=lambda item: item[0]):
        assert previous <= tick <= end
        output.extend(vlq(tick - previous) + event)
        previous = tick
    output.extend(vlq(end - previous) + b'\xff\x2f\x00')
    return b'MTrk' + struct.pack('>I', len(output)) + output


def compose(spec):
    if 'sections' in spec:
        return compose_song(spec)
    ppq = spec['ppq']
    end = spec['beats'] * ppq
    conductor = [(0, b'\xff\x03' + vlq(len(spec['title'].encode())) + spec['title'].encode())]
    conductor += [(beat * ppq, b'\xff\x51\x03' + tempo.to_bytes(3, 'big')) for beat, tempo in spec['tempos']]
    tracks = [track(conductor, end)]
    for channel, name in enumerate(['guitar', 'bass', 'organ', 'synth', 'drums']):
        if name == 'drums':
            channel = 9
        program = spec['programs'].get(name, 0)
        events = [(0, bytes([0xC0 | channel, program])),
                  (0, bytes([0xB0 | channel, 7, 95])),
                  (0, bytes([0xB0 | channel, 91, 0]))]

        def note(beat, duration, pitch, velocity):
            tick = round(beat * ppq)
            events.append((tick, bytes([0x90 | channel, pitch, velocity])))
            events.append((round((beat + duration) * ppq), bytes([0x80 | channel, pitch, 0])))

        for beat in range(15):
            root = spec['riff'][beat % len(spec['riff'])]
            if name == 'guitar':
                for part in [0, 0.25, 0.5, 0.75]:
                    for pitch in [root, root + 7, root + 12]:
                        note(beat + part, 0.18, pitch, 98 if part == 0 else 82)
            elif name == 'bass':
                note(beat, 0.42, root - 12, 100)
                note(beat + 0.5, 0.42, root - 12, 85)
            elif name == 'organ' and beat % 4 == 0 and beat < 12:
                for pitch in [52 + beat % 3, 59 + beat % 3, 64 + beat % 3]:
                    note(beat, 2.5, pitch, 66)
            elif name == 'synth' and beat % 2 == 0 and beat < 14:
                note(beat + 0.5, 0.75, 76 + beat % 5, 73)
            elif name == 'drums':
                note(beat, 0.1, 36 if beat % 2 == 0 else 38, 108)
                for part in [0, 0.25, 0.5, 0.75]:
                    note(beat + part, 0.08, 42, 68 if part % 0.5 else 85)
        if name == 'synth':
            for beat, bend in [(2, 8192), (2.6, 12000), (3.2, 6000), (4, 8192)]:
                events.append((round(beat * ppq), bytes([0xE0 | channel, bend & 127, bend >> 7])))
        tracks.append(track(events, end))
    return b'MThd' + struct.pack('>IHHH', 6, 1, len(tracks), ppq) + b''.join(tracks)


def compose_song(spec):
    ppq = spec['ppq']
    assert isinstance(ppq, int) and 0 < ppq < 32768
    end = round(spec['beats'] * ppq)
    assert end > 0 and sum(section['beats'] for section in spec['sections']) == spec['beats']
    assert set(spec['phrases']) <= VOICES.keys()

    def meta(kind, text):
        data = text.encode('utf-8')
        return b'\xff' + bytes([kind]) + vlq(len(data)) + data

    conductor = [(0, meta(3, spec['title']))]
    previous = -1
    for beat, tempo in spec['tempos']:
        tick = round(beat * ppq)
        assert previous < tick < end and 0 < tempo <= 0xFFFFFF
        assert previous != -1 or tick == 0
        conductor.append((tick, b'\xff\x51\x03' + tempo.to_bytes(3, 'big')))
        previous = tick
    assert previous >= 0
    for beat, numerator, denominator in spec.get('meters', [[0, 4, 4]]):
        assert numerator in range(1, 128) and denominator in (2, 4, 8, 16)
        tick = round(beat * ppq)
        assert 0 <= tick < end
        conductor.append((tick, b'\xff\x58\x04' + bytes([
            numerator, denominator.bit_length() - 1, 24, 8])))
    start = 0
    for section in spec['sections']:
        assert section['beats'] > 0 and set(section['parts']) <= VOICES.keys()
        conductor.append((start, meta(6, section['name'])))
        start += round(section['beats'] * ppq)
    tracks = [track(conductor, end)]
    for name, (channel, program, volume, pan) in VOICES.items():
        assert spec['programs'].get(name, program) == program, 'Use the approved instrument palette'
        volume, pan = spec.get('mix', {}).get(name, [volume, pan])
        assert volume in range(128) and pan in range(128)
        events = [(0, meta(3, name)), (0, bytes([0xB0 | channel, 0, 0])),
                  (0, bytes([0xB0 | channel, 32, 0])), (0, bytes([0xC0 | channel, program])),
                  (0, bytes([0xB0 | channel, 7, volume])), (0, bytes([0xB0 | channel, 10, pan])),
                  (0, bytes([0xB0 | channel, 64, 0])), (0, bytes([0xB0 | channel, 91, 0])),
                  (0, bytes([0xE0 | channel, 0, 64]))]
        section_start = 0
        for section in spec['sections']:
            length = round(section['beats'] * ppq)
            names = section['parts'].get(name, [])
            if names:
                phrases = [spec['phrases'][name][key] for key in names]
                cycle = sum(round(phrase['beats'] * ppq) for phrase in phrases)
                assert cycle > 0 and length % cycle == 0, 'Phrase cycle must fit its section exactly'
                offset = section_start
                for _ in range(length // cycle):
                    for phrase in phrases:
                        phrase_length = round(phrase['beats'] * ppq)
                        assert phrase_length > 0
                        spans = {}
                        for beat, duration, pitches, velocity in phrase['notes']:
                            on, off = round(beat * ppq), round((beat + duration) * ppq)
                            assert 0 <= on < off <= phrase_length and velocity in range(1, 128)
                            assert pitches and len(pitches) == len(set(pitches))
                            for pitch in pitches:
                                assert pitch in range(128)
                                spans.setdefault(pitch, []).append((on, off))
                                events.extend([(offset + on, bytes([0x90 | channel, pitch, velocity])),
                                               (offset + off, bytes([0x80 | channel, pitch, 0]))])
                        for intervals in spans.values():
                            ordered = sorted(intervals)
                            assert all(a[1] <= b[0] for a, b in zip(ordered, ordered[1:])), 'Same-key overlaps lose voices'
                        bends = phrase.get('bends', [])
                        previous_bend = -1
                        for beat, value in bends:
                            tick = round(beat * ppq)
                            assert channel != 9 and previous_bend < tick <= phrase_length and value in range(16384)
                            events.append((offset + tick, bytes([0xE0 | channel, value & 127, value >> 7])))
                            previous_bend = tick
                        assert not bends or bends[-1][1] == 8192, 'Every bent phrase must return to center'
                        offset += phrase_length
            section_start += length
        # Note-offs precede retriggers at the same tick; initialization stays before notes.
        events.sort(key=lambda item: (item[0], 0 if item[1][0] & 0xF0 == 0x80 else
                                     2 if item[1][0] & 0xF0 == 0x90 else 1))
        tracks.append(track(events, end))
    return b'MThd' + struct.pack('>IHHH', 6, 1, len(tracks), ppq) + b''.join(tracks)


if __name__ == '__main__':
    assert vlq(0) == b'\x00' and vlq(127) == b'\x7f'
    assert vlq(128) == b'\x81\x00' and vlq(0x0FFFFFFF) == b'\xff\xff\xff\x7f'
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gate', action='store_true', help='Verify the frozen fixture; never overwrite it')
    args = parser.parse_args()
    if args.gate:
        data = compose(json.loads((ROOT / 'source/music/gate.json').read_text()))
        assert data == (ROOT / 'game/audio/gate.mid').read_bytes()
        print('GATE_GREEN: byte-identical; six tracks; 7680 ticks; 7.2 seconds')
    else:
        scores = []
        for level in LEVELS:
            spec = json.loads((ROOT / f'source/music/{level}.json').read_text())
            data = compose(spec)
            scores.append((level, spec['beats'], data))
        for level, beats, data in scores:
            (ROOT / f'game/audio/{level}.mid').write_bytes(data)
            print(f'COMPOSE_GREEN: {level}: {len(data)} bytes; {beats} beats')
