#!/usr/bin/env python3
"""Pinned campaign MIDI/SF2 request audit. No synthesis or occupancy model.

Only explicit-status format-1 PPQ MIDI in the campaign grammar is supported.
SF2 sample payloads are sought past, never read, mapped, or hashed. Logical
requests retain every matching zone, including duplicates. The ceiling keeps
all requests until the end-of-score loop reset, regardless of earlier stops.
"""
import argparse
from collections import Counter
from dataclasses import dataclass
import hashlib
import io
import json
from pathlib import Path
import struct
import sys

LEVELS = ('intake', 'foundry', 'processional', 'reliquary',
          'nursery', 'ossuary', 'inversion', 'heart')
PROGRAMS = (0, 19, 30, 34, 81, 16384)
CHANNEL_PROGRAMS = {0: 30, 1: 34, 2: 19, 3: 81, 9: 0}
MAX_MIDI = 262144
MAX_PDTA = 524288
MAX_SF2 = 134217728
MAX_EVENTS = 50000
MAX_COMPILED_LAYERS = 4096
MAX_SELECTED_LAYERS = 64
MAX_DISTINCT_SELECTIONS = 4096
MAX_LOGICAL_REQUESTS = 100000
# These identities bind the selection semantics to the inspected implementation.
SOURCE_HASHES = {
    'game/audio/midi_music.gd': 'b17967bb7e83a510b10007f334bc18b3ff008a4701b07aea6c8207fc47c3f1f6',
    'game/addons/midi/Bank.gd': 'e2ae134bb684b3ba35cdf034c26dc94e3172f221c58ff728d3be0fdc270f1db8',
    'game/addons/midi/MidiPlayer.gd': '3fc16a2b020c199218e7999adb396cefe7cd2960d8813658e29a2cca911068f9',
    'game/addons/midi/ADSR.gd': 'f6e6fe75ecf1a468d7d2fd587089abda434f0e28f9d0e198c11a31645e272327',
    'game/addons/midi/SoundFont.gd': '027616fbc1bae0340ceaabf2203ea454b2d98bf452d648907d3fac2a5a1807df',
    'game/addons/midi/SMF.gd': '6ee7a4bf07cb5a31dfc9c18010e52fb13ad6395cd7a7662493c9c0d6d433aacd',
}


class AuditError(ValueError):
    """Corrupt, uncovered, out-of-bound, or unsupported input."""


def require(condition, reason):
    if not condition:
        raise AuditError(reason)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def bounded_file(path, maximum):
    with Path(path).open('rb') as source:
        data = source.read(maximum + 1)
    require(len(data) <= maximum, f'file exceeds {maximum} bytes: {path}')
    return data


def read_exact(source, count):
    data = source.read(count)
    require(len(data) == count, 'truncated RIFF metadata')
    return data


def chunks(source, start, end):
    """Yield header boundaries, never read the chunk payload implicitly."""
    pos, count = start, 0
    while pos < end:
        count += 1
        require(count <= 64 and end - pos >= 8, 'invalid RIFF chunk boundary/count')
        source.seek(pos)
        tag, size = struct.unpack('<4sI', read_exact(source, 8))
        stop = pos + 8 + size
        require(stop + (size & 1) <= end, 'RIFF chunk exceeds parent')
        yield tag, pos + 8, stop
        pos = stop + (size & 1)
    require(pos == end, 'RIFF chunk alignment')


FORMATS = {b'phdr': '<20sHHHIII', b'pbag': '<HH', b'pmod': '<HHhHH',
           b'pgen': '<HH', b'inst': '<20sH', b'ibag': '<HH',
           b'imod': '<HHhHH', b'igen': '<HH', b'shdr': '<20sIIIIIBbHH'}
WIDTHS = {tag: struct.calcsize(fmt) for tag, fmt in FORMATS.items()}


def text_name(raw):
    return raw.split(b'\0', 1)[0].decode('ascii', errors='replace')


def validate_zones(headers, index, bags, gens, mods, label):
    indices = [row[index] for row in headers]
    require(indices[0] == 0 and indices[-1] == len(bags) - 1,
            f'{label} header terminal bag index')
    require(all(a <= b for a, b in zip(indices, indices[1:])), f'{label} bag order')
    require(bags[0] == (0, 0) and bags[-1] == (len(gens) - 1, len(mods) - 1),
            f'{label} terminal generator/modulator indices')
    require(all(0 <= g < len(gens) and 0 <= m < len(mods) for g, m in bags),
            f'{label} bag index bounds')
    require(all(a[0] <= b[0] and a[1] <= b[1] for a, b in zip(bags, bags[1:])),
            f'{label} generator/modulator order')
    require(gens[-1] == (0, 0) and not any(mods[-1]), f'{label} terminal records')
    for start, stop in zip(bags, bags[1:]):
        zone = gens[start[0]:stop[0]]
        require(len({op for op, _ in zone}) == len(zone), f'{label} duplicate generator')
        for op, value in zone:
            require(0 <= op <= 60, f'{label} unknown generator {op}')
            if op in (43, 44):
                require((value & 255) <= (value >> 8) <= 127, f'{label} key/velocity range')
            require(not (label == 'preset' and op == 53) and
                    not (label == 'instrument' and op == 41), f'{label} misplaced reference')


@dataclass
class Bank:
    presets: dict
    sf2_bytes: int
    pdta_sha256: str
    pdta_bytes: int
    ignored_generators: list

    def preset_id(self, program, bank):
        wanted = program | (bank << 7)
        if wanted not in self.presets:
            wanted = 16384 if bank == 128 else program
        if wanted not in self.presets:
            require(bool(self.presets), 'no loaded presets')
            wanted = next(iter(self.presets))
        return wanted

    def select(self, program, bank, key, velocity):
        require(0 <= key <= 127 and 1 <= velocity <= 127, 'invalid note selection')
        preset = self.preset_id(program, bank)
        selected = []
        for layer in self.presets[preset]:
            if (layer['key_range'][0] <= key <= layer['key_range'][1]
                    and layer['velocity_range'][0] <= velocity <= layer['velocity_range'][1]):
                require(len(selected) < MAX_SELECTED_LAYERS, 'selected layer budget exceeded')
                selected.append(layer)
        return selected


def read_bank(source, programs=PROGRAMS):
    """Read RIFF headers and bounded pdta. sdta/smpl is never read."""
    source.seek(0, 2)
    size = source.tell()
    require(12 <= size <= MAX_SF2, 'SF2 size outside bound')
    source.seek(0)
    tag, declared, form = struct.unpack('<4sI4s', read_exact(source, 12))
    require(tag == b'RIFF' and form == b'sfbk' and declared + 8 == size, 'invalid SF2 RIFF size/type')
    pdta, frames, lists = None, None, []
    for tag, start, stop in chunks(source, 12, size):
        require(tag == b'LIST' and stop - start >= 4, 'unsupported SF2 top-level chunk')
        source.seek(start)
        kind = read_exact(source, 4)
        require(kind in (b'INFO', b'sdta', b'pdta') and kind not in lists, 'unsupported/duplicate SF2 LIST')
        lists.append(kind)
        if kind == b'sdta':
            for sample_tag, a, b in chunks(source, start + 4, stop):
                require(sample_tag == b'smpl' and frames is None and (b - a) % 2 == 0,
                        'unsupported/duplicate sample payload')
                frames = (b - a) // 2
                # No read, including zero-byte or sentinel reads, from smpl.
        elif kind == b'pdta':
            require(stop - start <= MAX_PDTA, 'pdta exceeds bound')
            pdta = kind + read_exact(source, stop - start - 4)
    require(lists == [b'INFO', b'sdta', b'pdta'] and frames and pdta, 'required SF2 LIST order/content')
    tables = {}
    metadata = io.BytesIO(pdta)
    for tag, start, stop in chunks(metadata, 4, len(pdta)):
        require(tag in WIDTHS and tag not in tables, 'unknown/duplicate pdta chunk')
        require(0 < stop - start <= MAX_PDTA and (stop - start) % WIDTHS[tag] == 0,
                f'invalid {tag!r} record width')
        metadata.seek(start)
        tables[tag] = list(struct.iter_unpack(FORMATS[tag], read_exact(metadata, stop - start)))
    require(list(tables) == list(WIDTHS), 'pdta chunk order/missing table')
    phdr, inst, shdr = (tables[key] for key in (b'phdr', b'inst', b'shdr'))
    require(len(phdr) > 1 and len(inst) > 1 and len(shdr) > 1, 'empty SF2 tables')
    require(text_name(phdr[-1][0]) == 'EOP' and text_name(inst[-1][0]) == 'EOI'
            and text_name(shdr[-1][0]) == 'EOS', 'invalid SF2 terminal name')
    validate_zones(phdr, 3, tables[b'pbag'], tables[b'pgen'], tables[b'pmod'], 'preset')
    validate_zones(inst, 1, tables[b'ibag'], tables[b'igen'], tables[b'imod'], 'instrument')
    for op, value in tables[b'pgen'][:-1]:
        if op == 41:
            require(value < len(inst) - 1, 'instrument reference out of bounds')
    for op, value in tables[b'igen'][:-1]:
        if op == 53:
            require(value < len(shdr) - 1, 'sample reference out of bounds')
        if op == 54:
            require(value in (0, 1, 3), 'unsupported sample mode')
        if op == 58:
            require(value <= 127 or value == 255, 'unsupported root override')
    for i, row in enumerate(shdr[:-1]):
        _, start, end, loop_a, loop_b, rate, root, _, link, kind = row
        require(0 <= start < end <= frames and 0 <= loop_a <= loop_b <= frames
                and 0 < rate <= 384000 and (root <= 127 or root == 255), f'invalid sample header bounds: sample={i} frames={frames} start={start} end={end} loop={loop_a},{loop_b} rate={rate} root={root}')
        require(kind in (1, 2, 4, 8), 'unsupported sample type (including ROM)')
        if kind != 1:
            require(link < len(shdr) - 1 and link != i, 'invalid linked sample reference')
            partner = shdr[link]
            require((kind, partner[-1]) in ((2, 4), (4, 2), (8, 8))
                    and partner[-2] == i, 'invalid linked sample pair/reciprocity')
    def zones(headers, index, bags, gens, number):
        for bag in range(headers[number][index], headers[number + 1][index]):
            yield bag, gens[bags[bag][0]:bags[bag + 1][0]]
    instruments = []
    handled = {0, 1, 2, 3, 4, 12, 34, 36, 37, 38, 43, 44, 45, 48, 50, 51, 52, 53, 54, 58}
    for i in range(len(inst) - 1):
        global_zone, layers = {}, []
        for bag, gens in zones(inst, 1, tables[b'ibag'], tables[b'igen'], i):
            inherited = dict(global_zone)
            # Bank.gd offset generators add to global values; other fields replace.
            for op, raw in gens:
                value = raw if op in (43, 44, 53, 54) else raw - 65536 if raw >= 32768 else raw
                inherited[op] = inherited.get(op, 0) + value if op in (0, 1, 2, 3, 4, 12, 45, 50) else value
            if 53 in inherited:
                layers.append((bag, inherited))
            else:
                global_zone = inherited
        instruments.append(layers)
    presets = {}
    compiled_layers = 0
    for i, header in enumerate(phdr[:-1]):
        _, program, bank, _, *_ = header
        require(program <= 127 and bank <= 16383, 'invalid preset bank/program')
        encoded = program | (bank << 7)
        if encoded not in programs:
            continue
        require(encoded not in presets, 'duplicate loaded preset')
        layers = []
        for pbag, gens in zones(phdr, 3, tables[b'pbag'], tables[b'pgen'], i):
            # Bank.gd does NOT inherit preset global zones.
            preset_zone = dict(gens)
            if 41 not in preset_zone:
                continue
            for ibag, zone in instruments[preset_zone[41]]:
                require(compiled_layers < MAX_COMPILED_LAYERS, 'compiled layer budget exceeded')
                compiled_layers += 1
                def span(value):
                    return [value & 255, value >> 8]
                pk, ik = span(preset_zone.get(43, 0x7f00)), span(zone.get(43, 0x7f00))
                sample_id = zone[53]
                row = shdr[sample_id]
                sample_ids = [sample_id]
                if row[-1] != 1:
                    sample_ids = [sample_id, row[-2]] if row[-1] == 4 else [row[-2], sample_id]
                sample_metadata = []
                for sid in sample_ids:
                    s = shdr[sid]
                    start = s[1] + zone.get(0, 0) + 32768 * zone.get(4, 0)
                    end = s[2] + zone.get(1, 0) + 32768 * zone.get(12, 0)
                    a = s[3] + zone.get(2, 0) + 32768 * zone.get(45, 0)
                    b = s[4] + zone.get(3, 0) + 32768 * zone.get(50, 0)
                    require(0 <= start < end <= frames and 0 <= a <= b <= frames,
                            'effective sample offsets outside payload bounds')
                    mode = zone.get(54, -1)
                    loop_candidate = (mode in (1, 3)) if len(sample_ids) == 1 else (
                        mode == 1 or (mode == -1 and start + 64 <= a and encoded != 16384))
                    require(not loop_candidate or start <= a < b <= end, 'active loop outside sample bounds')
                    sample_metadata.append({'id': sid, 'name': text_name(s[0]), 'type': s[-1],
                                            'frames': [start, end], 'loop_frames': [a, b],
                                            'sample_rate': s[5], 'root_key': s[6], 'pitch_correction': s[7],
                                            'loop_candidate_before_stream_cache': loop_candidate})
                layers.append({'id': f'{encoded}:{pbag}:{ibag}', 'preset': encoded,
                               'preset_zone': pbag, 'instrument': preset_zone[41], 'instrument_zone': ibag,
                               'key_range': [max(pk[0], ik[0]), min(pk[1], ik[1])],
                               'velocity_range': span(zone.get(44, preset_zone.get(44, 0x7f00))),
                               'release_timecents': zone.get(38),
                               'release_seconds': 2 ** (zone[38] / 1200) if 38 in zone else 0.001,
                               'sample_modes': zone.get(54, -1), 'samples': sample_metadata,
                               'secondary_streams': len(sample_ids) - 1,
                               'native_loop_status': None})
        presets[encoded] = layers
    ignored = sorted({op for op, _ in tables[b'igen'][:-1] if op not in handled})
    return Bank(presets, size, digest(pdta), len(pdta), ignored)


@dataclass(frozen=True)
class Event:
    tick: int
    track: int
    ordinal: int
    kind: str
    values: tuple


def merge_tracks(tracks):
    """One event per track per equal-tick round, matching MidiPlayer.gd."""
    pointers = [0] * len(tracks)
    result = []
    while any(p < len(t) for p, t in zip(pointers, tracks)):
        tick = min(t[p].tick for p, t in zip(pointers, tracks) if p < len(t))
        while True:
            advanced = False
            for i, track in enumerate(tracks):
                p = pointers[i]
                if p < len(track) and track[p].tick == tick:
                    result.append(track[p])
                    pointers[i] += 1
                    advanced = True
            if not advanced:
                break
    return result


def decode_midi(data):
    require(14 <= len(data) <= MAX_MIDI and data[:4] == b'MThd', 'MIDI size/header')
    size, fmt, count, ppq = struct.unpack_from('>IHHH', data, 4)
    require(size == 6 and fmt == 1 and 1 <= count <= 16 and 0 < ppq <= 32767,
            'unsupported MIDI header (format-1 PPQ only)')
    tracks, pos, event_count = [], 14, 0
    for track in range(count):
        require(pos + 8 <= len(data) and data[pos:pos + 4] == b'MTrk', 'missing/truncated MIDI track')
        length = struct.unpack_from('>I', data, pos + 4)[0]
        pos += 8
        end = pos + length
        require(end <= len(data), 'truncated MIDI track payload')
        events, tick, ended = [], 0, False
        def take(n):
            nonlocal pos
            require(0 <= n <= end - pos, 'truncated MIDI event')
            out = data[pos:pos + n]
            pos += n
            return out
        def variable():
            value = 0
            for _ in range(4):
                byte = take(1)[0]
                value = (value << 7) | (byte & 127)
                if byte < 128:
                    return value
            raise AuditError('MIDI VLQ exceeds four bytes')
        while pos < end:
            require(not ended, 'events after MIDI end-of-track')
            tick += variable()
            require(tick <= 10000000, 'MIDI tick bound')
            status = take(1)[0]
            if status == 255:
                kind, n = take(1)[0], variable()
                require(n <= 2048, 'MIDI meta payload bound')
                payload = take(n)
                if kind == 0x2f:
                    require(n == 0, 'invalid end-of-track')
                    event_kind, values, ended = 'end', (), True
                elif kind == 0x51:
                    require(n == 3 and int.from_bytes(payload, 'big') > 0, 'invalid MIDI tempo')
                    event_kind, values = 'tempo', (int.from_bytes(payload, 'big'),)
                elif kind == 0x58:
                    require(n == 4 and 1 <= payload[0] <= 127 and payload[1] in (1, 2, 3, 4)
                            and payload[2:] == bytes([24, 8]), 'unsupported MIDI meter')
                    event_kind, values = 'meta', (kind,)
                else:
                    require(kind in (3, 6), f'unsupported MIDI meta {kind}')
                    event_kind, values = 'meta', (kind,)
            else:
                high, channel = status & 0xf0, status & 15
                require(status >= 128 and high in (0x80, 0x90, 0xb0, 0xc0, 0xe0)
                        and channel in CHANNEL_PROGRAMS, 'unsupported MIDI status/channel (no running status/SysEx)')
                payload = take(1 if high == 0xc0 else 2)
                require(all(byte < 128 for byte in payload), 'invalid MIDI data byte')
                event_kind = {0x80: 'off', 0x90: 'on', 0xb0: 'cc', 0xc0: 'program', 0xe0: 'bend'}[high]
                require(event_kind != 'on' or payload[1] > 0, 'unsupported velocity-zero note-on')
                values = (channel, *payload)
            event_count += 1
            require(event_count <= MAX_EVENTS, 'MIDI event bound')
            events.append(Event(tick, track, len(events), event_kind, values))
        require(ended, 'missing MIDI end-of-track')
        tracks.append(events)
    require(pos == len(data) and len({t[-1].tick for t in tracks}) == 1, 'MIDI trailing bytes/unequal track endpoints')
    return ppq, merge_tracks(tracks)


def audit_midi(data, bank):
    ppq, events = decode_midi(data)
    active, programs, started = set(), {}, set()
    channels, histogram, coverage, used = {}, Counter(), {}, set()
    requests = secondary = notes = elapsed = tick = 0
    tempo, witness = 500000, None
    for event in events:
        elapsed += (event.tick - tick) * tempo
        tick = event.tick
        kind, values = event.kind, event.values
        if kind == 'tempo':
            tempo = values[0]
        elif kind == 'cc':
            channel, controller, value = values
            require(event.tick == 0 and channel not in started and controller in (0, 32, 7, 10, 64, 91),
                    'unsupported controller/state transition')
            require(controller in (7, 10) or value == 0, 'unsupported bank/hold/reverb value')
        elif kind == 'program':
            channel, program = values
            require(event.tick == 0 and channel not in started and channel not in programs
                    and program == CHANNEL_PROGRAMS[channel], 'unsupported campaign program/state transition')
            programs[channel] = program
        elif kind == 'bend':
            channel, low, high = values
            require(channel != 9 or (event.tick == 0 and (low | high << 7) == 8192), 'unsupported drum pitch bend')
        elif kind == 'off':
            channel, key, _ = values
            require((channel, key) in active, 'unmatched MIDI note-off')
            active.remove((channel, key))
            # Neither melodic release nor drum note-off reduces this ceiling.
        elif kind == 'on':
            channel, key, velocity = values
            require(channel in programs and (channel, key) not in active, 'uninitialized program/same-key overlap')
            active.add((channel, key))
            started.add(channel)
            selection = (channel, programs[channel], key, velocity)
            require(selection in coverage or len(coverage) < MAX_DISTINCT_SELECTIONS,
                    'distinct selection budget exceeded')
            layers = bank.select(programs[channel], 128 if channel == 9 else 0, key, velocity)
            require(bool(layers), f'uncovered note channel={channel} key={key} velocity={velocity}')
            n, linked = len(layers), sum(layer['secondary_streams'] for layer in layers)
            require(requests + n <= MAX_LOGICAL_REQUESTS, 'logical request budget exceeded')
            notes += 1
            requests += n
            secondary += linked
            row = channels.setdefault(str(channel), {'note_ons': 0, 'logical_requests': 0,
                                                     'secondary_stream_requests': 0, 'layer_histogram': Counter()})
            row['note_ons'] += 1
            row['logical_requests'] += n
            row['secondary_stream_requests'] += linked
            row['layer_histogram'][str(n)] += 1
            histogram[str(n)] += 1
            identities = tuple(layer['id'] for layer in layers)
            coverage[selection] = (identities, coverage.get(selection, ((), 0))[1] + 1)
            used.update(identities)
            witness = {'tick': tick, 'seconds': elapsed / ppq / 1000000, 'track': event.track,
                       'ordinal': event.ordinal, 'channel': channel, 'key': key, 'velocity': velocity,
                       'layers': list(identities), 'cumulative_logical_requests': requests,
                       'cumulative_secondary_stream_requests': secondary}
    require(not active and notes > 0, 'unresolved notes/empty score')
    coverage_bytes = json.dumps([[*key, identities, count] for key, (identities, count) in sorted(coverage.items())],
                               separators=(',', ':')).encode()
    return {'midi_sha256': digest(data), 'midi_bytes': len(data), 'ppq': ppq,
            'duration_seconds': elapsed / ppq / 1000000, 'end_tick': tick,
            'note_ons': notes, 'logical_requests': requests, 'secondary_stream_requests': secondary,
            'layer_histogram': dict(sorted(histogram.items())), 'channels': channels,
            'coverage': {'covered_note_ons': notes, 'uncovered_note_ons': 0,
                         'distinct_selections': len(coverage), 'selection_sha256': digest(coverage_bytes)},
            'used_layer_ids': sorted(used),
            'epoch_ceiling': {'definition': 'sum of every request until end-of-score loop reset; not concurrency',
                              'logical_requests': requests, 'secondary_stream_requests': secondary,
                              'total_stream_requests': requests + secondary,
                              'witness': witness, 'after_loop_reset': 0}}


def campaign_report(root):
    root = Path(root)
    source_hashes = {}
    for path, expected in SOURCE_HASHES.items():
        actual = digest(bounded_file(root / path, 131072))
        require(expected == actual, f'source pin mismatch: {path}')
        source_hashes[path] = actual
    with (root / 'game/audio/GeneralUser-GS.sf2').open('rb') as source:
        bank = read_bank(source)
    require(set(bank.presets) == set(PROGRAMS), 'missing campaign preset')
    scores = {level: audit_midi(bounded_file(root / f'game/audio/{level}.mid', MAX_MIDI), bank)
              for level in LEVELS}
    used = set().union(*(set(score['used_layer_ids']) for score in scores.values()))
    catalogue = [layer for layers in bank.presets.values() for layer in layers if layer['id'] in used]
    return {'schema': 1, 'audit': 'actual MIDI/SF2 metadata selection and cumulative request ceiling',
            'source_sha256': source_hashes, 'sf2': {'bytes': bank.sf2_bytes,
            'pdta_bytes': bank.pdta_bytes, 'pdta_sha256': bank.pdta_sha256,
            'full_bank_sha256': None, 'pcm_read': False,
            'ignored_instrument_generators_by_Bank_gd': bank.ignored_generators},
            'defaults': {'speed': 1, 'key_shift': 0, 'loop_start_tick': 0, 'pool': 96,
                         'drum_bank': 128, 'loaded_presets': list(PROGRAMS)},
            'scores': scores, 'used_layers': catalogue,
            'native_peak': None, 'no_steal_verified': False, 'captured_output_parity': None,
            'pool_reduction_authorized': False,
            'limitations': ['Not a simultaneous demand, release, sample-completion, or synth model.',
                            'Every request retained until hard loop reset; note-offs do not decrement ceiling.',
                            'Native mixer timing, occupancy, audio parity and startup savings remain unknown.',
                            'Loop candidate is pre-cache metadata; native cached-stream loop status is unknown.',
                            'Metadata hash is not full SF2 identity. PCM was not read.',
                            'Explicit-status campaign MIDI only; no SysEx, running status, sustain, bank changes, overlaps or CC111.',
                            'SF2 ROM, sm24, unknown tables/generators, duplicate generators and invalid references fail closed.',
                            'Preset globals/modulators and unhandled generators follow pinned Bank.gd ignored behavior.']}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True, help='resident pinned source checkout (read-only)')
    args = parser.parse_args(argv)
    try:
        report = campaign_report(args.root)
        output = json.dumps(report, sort_keys=True, separators=(',', ':'), allow_nan=False)
        require(len(output.encode()) < 100000, 'report exceeds 100KB bound')
    except (AuditError, OSError, ValueError, struct.error) as error:
        print(f'music-demand: {error}', file=sys.stderr)
        return 2
    print(output)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
