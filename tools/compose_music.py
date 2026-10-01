#!/usr/bin/env python3
"""Generate the original MIDI gate fixture with only the Python standard library."""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


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


if __name__ == '__main__':
    assert vlq(0) == b'\x00' and vlq(127) == b'\x7f'
    assert vlq(128) == b'\x81\x00' and vlq(0x0FFFFFFF) == b'\xff\xff\xff\x7f'
    spec = json.loads((ROOT / 'source/music/gate.json').read_text())
    data = compose(spec)
    assert data[:14] == b'MThd' + struct.pack('>IHHH', 6, 1, 6, 480)
    assert data.count(b'MTrk') == 6 and data.endswith(b'\xff\x2f\x00')
    target = ROOT / 'game/audio/gate.mid'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    print(f'COMPOSE_GREEN: {len(data)} bytes; six tracks; 7680 ticks; 7.2 seconds')
