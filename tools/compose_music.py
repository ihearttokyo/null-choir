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
    if not (0 <= value <= 0x0FFFFFFF):
        raise AssertionError
    result = [value & 127]
    while value >> 7:
        value >>= 7
        result.insert(0, (value & 127) | 128)
    return bytes(result)


def track(events, end):
    output = bytearray()
    previous = 0
    for tick, event in sorted(events, key=lambda item: item[0]):
        if not (previous <= tick <= end):
            raise AssertionError
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
    if not (isinstance(ppq, int) and 0 < ppq < 32768):
        raise AssertionError
    end = round(spec['beats'] * ppq)
    if not (end > 0 and sum(section['beats'] for section in spec['sections']) == spec['beats']):
        raise AssertionError
    if not (set(spec['phrases']) <= VOICES.keys()):
        raise AssertionError

    def meta(kind, text):
        data = text.encode('utf-8')
        return b'\xff' + bytes([kind]) + vlq(len(data)) + data

    conductor = [(0, meta(3, spec['title']))]
    previous = -1
    for beat, tempo in spec['tempos']:
        tick = round(beat * ppq)
        if not (previous < tick < end and 0 < tempo <= 0xFFFFFF):
            raise AssertionError
        if not (previous != -1 or tick == 0):
            raise AssertionError
        conductor.append((tick, b'\xff\x51\x03' + tempo.to_bytes(3, 'big')))
        previous = tick
    if not (previous >= 0):
        raise AssertionError
    for beat, numerator, denominator in spec.get('meters', [[0, 4, 4]]):
        if not (numerator in range(1, 128) and denominator in (2, 4, 8, 16)):
            raise AssertionError
        tick = round(beat * ppq)
        if not (0 <= tick < end):
            raise AssertionError
        conductor.append((tick, b'\xff\x58\x04' + bytes([
            numerator, denominator.bit_length() - 1, 24, 8])))
    start = 0
    for section in spec['sections']:
        if not (section['beats'] > 0 and set(section['parts']) <= VOICES.keys()):
            raise AssertionError
        conductor.append((start, meta(6, section['name'])))
        start += round(section['beats'] * ppq)
    tracks = [track(conductor, end)]
    for name, (channel, program, volume, pan) in VOICES.items():
        if not (spec['programs'].get(name, program) == program):
            raise AssertionError('Use the approved instrument palette')
        volume, pan = spec.get('mix', {}).get(name, [volume, pan])
        if not (volume in range(128) and pan in range(128)):
            raise AssertionError
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
                if not (cycle > 0 and length % cycle == 0):
                    raise AssertionError('Phrase cycle must fit its section exactly')
                offset = section_start
                for _ in range(length // cycle):
                    for phrase in phrases:
                        phrase_length = round(phrase['beats'] * ppq)
                        if not (phrase_length > 0):
                            raise AssertionError
                        spans = {}
                        for beat, duration, pitches, velocity in phrase['notes']:
                            on, off = round(beat * ppq), round((beat + duration) * ppq)
                            if not (0 <= on < off <= phrase_length and velocity in range(1, 128)):
                                raise AssertionError
                            if not (pitches and len(pitches) == len(set(pitches))):
                                raise AssertionError
                            for pitch in pitches:
                                if not (pitch in range(128)):
                                    raise AssertionError
                                spans.setdefault(pitch, []).append((on, off))
                                events.extend([(offset + on, bytes([0x90 | channel, pitch, velocity])),
                                               (offset + off, bytes([0x80 | channel, pitch, 0]))])
                        for intervals in spans.values():
                            ordered = sorted(intervals)
                            if not (all(a[1] <= b[0] for a, b in zip(ordered, ordered[1:]))):
                                raise AssertionError('Same-key overlaps lose voices')
                        bends = phrase.get('bends', [])
                        previous_bend = -1
                        for beat, value in bends:
                            tick = round(beat * ppq)
                            if not (channel != 9 and previous_bend < tick <= phrase_length and value in range(16384)):
                                raise AssertionError
                            events.append((offset + tick, bytes([0xE0 | channel, value & 127, value >> 7])))
                            previous_bend = tick
                        if not (not bends or bends[-1][1] == 8192):
                            raise AssertionError('Every bent phrase must return to center')
                        offset += phrase_length
            section_start += length
        # Note-offs precede retriggers at the same tick; initialization stays before notes.
        events.sort(key=lambda item: (item[0], 0 if item[1][0] & 0xF0 == 0x80 else
                                     2 if item[1][0] & 0xF0 == 0x90 else 1))
        tracks.append(track(events, end))
    return b'MThd' + struct.pack('>IHHH', 6, 1, len(tracks), ppq) + b''.join(tracks)


if __name__ == '__main__':
    if not (vlq(0) == b'\x00' and vlq(127) == b'\x7f'):
        raise AssertionError
    if not (vlq(128) == b'\x81\x00' and vlq(0x0FFFFFFF) == b'\xff\xff\xff\x7f'):
        raise AssertionError
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gate', action='store_true', help='Verify the frozen fixture; never overwrite it')
    args = parser.parse_args()
    if args.gate:
        data = compose(json.loads((ROOT / 'source/music/gate.json').read_text()))
        if not (data == (ROOT / 'game/audio/gate.mid').read_bytes()):
            raise AssertionError
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
