"""Bounded metadata fixtures: every SF2 read is guarded against PCM access."""
import io
import json
import struct
import tempfile
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path
import unittest
from unittest.mock import patch
from tools import music_demand as demand


def chunk(tag, data):
    return tag + struct.pack('<I', len(data)) + data + b'\0' * (len(data) % 2)


def name(value):
    return value.encode().ljust(20, b'\0')


class MetadataOnly(io.BytesIO):
    def __init__(self, data):
        super().__init__(data)
        start = data.index(b'smpl') + 8
        self.pcm = (start, start + 400)
        self.bytes_read = 0

    def read(self, size=-1):
        a = self.tell()
        b = len(self.getbuffer()) if size < 0 else a + size
        if a < self.pcm[1] and b > self.pcm[0]:
            raise AssertionError('PCM read attempted')
        self.bytes_read += max(0, b - a)
        return super().read(size)


def bank_fixture(pzones=None, izones=None, linked=False, program=30, bank=0):
    pzones = pzones or [[(41, 0)]]
    izones = izones or [[(53, 0)], [(53, 0)]]
    def tables(zones):
        bags, gens = [], []
        for zone in zones:
            bags.append((len(gens), 0))
            gens.extend(zone)
        bags.append((len(gens), 0))
        gens.append((0, 0))
        return (b''.join(struct.pack('<HH', *r) for r in bags),
                b''.join(struct.pack('<HH', op, val & 65535) for op, val in gens))
    pbag, pgen = tables(pzones)
    ibag, igen = tables(izones)
    samples = [name('primary') + struct.pack('<IIIIIBbHH', 0, 100, 10, 90, 44100, 60, 0, 1 if linked else 0, 4 if linked else 1)]
    if linked:
        samples.append(name('secondary') + struct.pack('<IIIIIBbHH', 100, 200, 110, 190, 44100, 60, 0, 0, 2))
    samples.append(name('EOS') + bytes(26))
    records = [
        (b'phdr', name('preset') + struct.pack('<HHHIII', program, bank, 0, 0, 0, 0) + name('EOP') + struct.pack('<HHHIII', 0, 0, len(pzones), 0, 0, 0)),
        (b'pbag', pbag), (b'pmod', bytes(10)), (b'pgen', pgen),
        (b'inst', name('instrument') + struct.pack('<H', 0) + name('EOI') + struct.pack('<H', len(izones))),
        (b'ibag', ibag), (b'imod', bytes(10)), (b'igen', igen), (b'shdr', b''.join(samples))]
    data = b'sfbk' + chunk(b'LIST', b'INFO' + chunk(b'INAM', b'metadata')) + chunk(b'LIST', b'sdta' + chunk(b'smpl', bytes(400))) + chunk(b'LIST', b'pdta' + b''.join(chunk(t, d) for t, d in records))
    return b'RIFF' + struct.pack('<I', len(data)) + data


def vlq(n):
    out = [n & 127]
    while n >> 7:
        n >>= 7
        out.insert(0, (n & 127) | 128)
    return bytes(out)


def midi(tracks, end=480):
    encoded = []
    for events in tracks:
        body, previous = bytearray(), 0
        for tick, payload in events + [(end, b'\xff\x2f\x00')]:
            body.extend(vlq(tick - previous) + payload)
            previous = tick
        encoded.append(b'MTrk' + struct.pack('>I', len(body)) + body)
    return b'MThd' + struct.pack('>IHHH', 6, 1, len(tracks), 480) + b''.join(encoded)


class DemandTests(unittest.TestCase):
    def bank(self, **kwargs):
        source = MetadataOnly(bank_fixture(**kwargs))
        result = demand.read_bank(source)
        self.assertLess(source.bytes_read, len(source.getvalue()) - 400)
        return result

    def test_two_mono_layers_are_two_requests_not_one_note(self):
        bank = self.bank()
        score = midi([[(0, b'\xc0\x1e'), (0, b'\x90\x3c\x64'), (120, b'\x80\x3c\x00')]])
        report = demand.audit_midi(score, bank)
        self.assertEqual(report['note_ons'], 1)
        self.assertEqual(report['logical_requests'], 2)
        self.assertEqual(report['secondary_stream_requests'], 0)
        self.assertEqual(report['epoch_ceiling']['logical_requests'], 2)

    def test_inclusive_ranges_inheritance_and_velocity_override(self):
        r = lambda a, b: a | b << 8
        bank = self.bank(pzones=[[(44, r(1, 5))], [(43, r(40, 80)), (44, r(40, 60)), (41, 0)]],
                         izones=[[(44, r(20, 100)), (38, -1200)],
                                 [(43, r(50, 70)), (53, 0)]])
        for key, velocity in [(50, 20), (70, 100)]:
            layers = bank.select(30, 0, key, velocity)
            self.assertEqual(len(layers), 1)
            self.assertEqual(layers[0]['release_seconds'], 0.5)
            self.assertEqual(layers[0]['release_timecents'], -1200)
        for key, velocity in [(49, 50), (71, 50), (60, 19), (60, 101)]:
            self.assertEqual(bank.select(30, 0, key, velocity), [])
        without_override = self.bank(pzones=[[(44, r(1, 5))], [(41, 0)]], izones=[[(53, 0)]])
        self.assertEqual(len(without_override.select(30, 0, 60, 100)), 1)

    def test_encoded_fallback_and_zone_order_preserve_duplicates(self):
        bank = self.bank()
        self.assertEqual(bank.preset_id(30, 2), 30)
        self.assertEqual(bank.preset_id(7, 0), 30)
        layers = bank.select(30, 0, 60, 100)
        self.assertEqual([s['samples'][0]['id'] for s in layers], [0, 0])
        self.assertNotEqual(layers[0]['id'], layers[1]['id'])
        bank.presets[16384] = layers
        self.assertEqual(bank.preset_id(7, 128), 16384)
        self.assertEqual(bank.preset_id(0, 128), 16384)

    def test_linked_stream_is_not_second_logical_request(self):
        bank = self.bank(izones=[[(53, 0)]], linked=True)
        score = midi([[(0, b'\xc0\x1e'), (0, b'\x90\x3c\x64'), (120, b'\x80\x3c\x00')]])
        report = demand.audit_midi(score, bank)
        self.assertEqual(report['logical_requests'], 1)
        self.assertEqual(report['secondary_stream_requests'], 1)
        self.assertEqual(report['epoch_ceiling']['total_stream_requests'], 2)
        self.assertEqual(bank.select(30, 0, 60, 100)[0]['samples'][0]['type'], 4)

    def test_retrigger_release_and_hard_reset_ceiling(self):
        bank = self.bank(izones=[[(38, 8400), (54, 0), (53, 0)], [(53, 0)]])
        score = midi([[(0, b'\xc0\x1e'), (0, b'\x90\x3c\x64'), (120, b'\x80\x3c\x00'),
                      (120, b'\x90\x3c\x64'), (240, b'\x80\x3c\x00')]])
        report = demand.audit_midi(score, bank)
        self.assertEqual(report['logical_requests'], 4)
        self.assertEqual(report['epoch_ceiling']['witness']['tick'], 120)
        self.assertEqual(report['epoch_ceiling']['after_loop_reset'], 0)
        layer = bank.select(30, 0, 60, 100)[0]
        self.assertEqual(layer['release_seconds'], 128)
        self.assertFalse(layer['samples'][0]['loop_candidate_before_stream_cache'])
        self.assertIsNone(layer['native_loop_status'])
        self.assertEqual(report, demand.audit_midi(score, bank))
        self.assertEqual(json.dumps(report, sort_keys=True), json.dumps(demand.audit_midi(score, bank), sort_keys=True))

    def test_drum_off_does_not_decrement_requests(self):
        bank = self.bank(program=0, bank=128, izones=[[(38, 8400), (53, 0)]])
        report = demand.audit_midi(midi([[(0, b'\xc9\x00'), (0, b'\x99\x3c\x64'),
                                         (1, b'\x89\x3c\x00')]]), bank)
        self.assertEqual(report['epoch_ceiling']['logical_requests'], 1)
        self.assertEqual(report['duration_seconds'], 0.5)

    def test_equal_tick_round_robin_and_piecewise_tempo(self):
        score = midi([[(0, b'\xff\x06\x01a'), (0, b'\xff\x06\x01b')],
                      [(0, b'\xff\x06\x01c'), (0, b'\xff\x06\x01d')],
                      [(0, b'\xff\x06\x01e')]])
        _, events = demand.decode_midi(score)
        self.assertEqual([(e.track, e.ordinal) for e in events[:5]], [(0, 0), (1, 0), (2, 0), (0, 1), (1, 1)])
        score = midi([[(240, b'\xff\x51\x03\x0f\x42\x40')],
                      [(0, b'\xc0\x1e'), (0, b'\x90\x3c\x64'), (480, b'\x80\x3c\x00')]])
        self.assertEqual(demand.audit_midi(score, self.bank())['duration_seconds'], 0.75)

    def test_corrupt_metadata_fails_without_pcm_read(self):
        base = bank_fixture()
        cases = [base[:-1], base.replace(name('EOP'), name('BAD'), 1)]
        for tag, offset, value in [(b'pbag', 4, 65535), (b'pgen', 2, 65535),
                                   (b'igen', 2, 65535), (b'shdr', 44, 0x8001)]:
            broken = bytearray(base)
            start = broken.index(tag) + 8
            struct.pack_into('<H', broken, start + offset, value)
            cases.append(bytes(broken))
        broken = bytearray(base)
        pos = broken.index(b'pgen') + 4
        struct.pack_into('<I', broken, pos, 7)
        cases.append(bytes(broken))
        for data in cases:
            with self.subTest(case=cases.index(data)), self.assertRaises(demand.AuditError):
                demand.read_bank(MetadataOnly(data))
        linked = bytearray(bank_fixture(linked=True))
        struct.pack_into('<H', linked, linked.index(b'shdr') + 8 + 42, 999)
        with self.assertRaises(demand.AuditError):
            demand.read_bank(MetadataOnly(bytes(linked)))
        with self.assertRaises(demand.AuditError):
            self.bank(izones=[[(43, 0xffff), (53, 0)]])
        with self.assertRaises(demand.AuditError):
            self.bank(izones=[[(53, 0), (53, 0)]])

    def test_unsupported_or_unpaired_midi_fails_closed(self):
        bank = self.bank()
        program = (0, b'\xc0\x1e')
        on = (0, b'\x90\x3c\x64')
        off = (120, b'\x80\x3c\x00')
        cases = [midi([[program, (0, b'\x90\x3c\x00')]]),
                 midi([[program, on, on, off]]), midi([[program, off]]), midi([[program, on]]),
                 midi([[program, (0, b'\xb0\x40\x7f')]]), midi([[program, (0, b'\xb0\x6f\x00')]]),
                 midi([[program, (0, b'\xb0\x00\x01')]]), midi([[program, (0, b'\xb0\x63\x00')]]),
                 midi([[program, (0, b'\xf0\x00')]]), midi([[program, (0, b'\x3c\x64')]]),
                 midi([[program, on, off]])[:-1], midi([[program, on, off]]) + b'x',
                 midi([[program, (0, b'\x90\x80\x64')]]), midi([[program, (120, b'\xc0\x1e')]]),
                 midi([[program, (1, b'\xb0\x07\x00')]]), midi([[(0, b'\xc4\x1e')]]),
                 midi([[program, (0, b'\xff\x51\x03\x00\x00\x00')]])]
        unequal = bytearray(midi([[], []]))
        unequal[-5:] = b'\x81\x00\xff\x2f\x00'
        cases.append(bytes(unequal))
        for i, data in enumerate(cases):
            with self.subTest(case=i), self.assertRaises(demand.AuditError):
                demand.audit_midi(data, bank)
        with self.assertRaises(demand.AuditError):
            demand.audit_midi(midi([[program, on, off]]), self.bank(izones=[[(43, 0x0100), (53, 0)]]))

    def test_riff_and_midi_bounds(self):
        for data in [b'', b'RIFF', bank_fixture()[:12]]:
            with self.assertRaises(demand.AuditError):
                demand.read_bank(io.BytesIO(data))
        for data in [b'', b'MThd', b'0' * (demand.MAX_MIDI + 1)]:
            with self.assertRaises(demand.AuditError):
                demand.decode_midi(data)

    def test_compiled_layer_budget_before_cross_product_allocation(self):
        data = bank_fixture(pzones=[[(41, 0)]] * 17, izones=[[(53, 0)]] * 17)
        self.assertLess(len(data), 1200)
        with patch.object(demand, 'MAX_COMPILED_LAYERS', 288, create=True):
            with self.assertRaisesRegex(demand.AuditError, 'compiled layer budget'):
                demand.read_bank(MetadataOnly(data))
        with patch.object(demand, 'MAX_COMPILED_LAYERS', 289, create=True):
            bank = demand.read_bank(MetadataOnly(data))
            self.assertEqual(len(bank.presets[30]), 289)
            self.assertEqual(len({layer['id'] for layer in bank.presets[30]}), 289)

    def test_selection_budget_does_not_truncate_duplicate_layers(self):
        bank = self.bank(izones=[[(53, 0)]] * 17)
        with patch.object(demand, 'MAX_SELECTED_LAYERS', 16, create=True):
            with self.assertRaisesRegex(demand.AuditError, 'selected layer budget'):
                bank.select(30, 0, 60, 100)
        with patch.object(demand, 'MAX_SELECTED_LAYERS', 17, create=True):
            self.assertEqual(len(bank.select(30, 0, 60, 100)), 17)

    def test_request_and_unique_coverage_budgets(self):
        bank = self.bank()
        events = [(0, b'\xc0\x1e')]
        for i in range(4):
            events.extend([(i * 20, bytes([0x90, 60 + i, 100])),
                           (i * 20 + 10, bytes([0x80, 60 + i, 0]))])
        score = midi([events])
        for limit, value, error in [('MAX_LOGICAL_REQUESTS', 7, 'logical request budget'),
                                    ('MAX_DISTINCT_SELECTIONS', 3, 'distinct selection budget')]:
            with patch.object(demand, limit, value, create=True):
                with self.assertRaisesRegex(demand.AuditError, error):
                    demand.audit_midi(score, bank)
        with patch.object(demand, 'MAX_LOGICAL_REQUESTS', 8, create=True), \
                patch.object(demand, 'MAX_DISTINCT_SELECTIONS', 4, create=True):
            report = demand.audit_midi(score, bank)
            self.assertEqual(report['logical_requests'], 8)
            self.assertEqual(report['coverage']['distinct_selections'], 4)

    def test_link_pair_types_and_reciprocity_rejected(self):
        base = bank_fixture(linked=True, izones=[[(53, 0)]])
        for first, second in [(4, 4), (2, 2), (8, 4), (4, 8), (8, 2), (2, 8)]:
            data = bytearray(base)
            start = data.index(b'shdr') + 8
            struct.pack_into('<H', data, start + 44, first)
            struct.pack_into('<H', data, start + 46 + 44, second)
            with self.subTest(types=(first, second)), self.assertRaisesRegex(demand.AuditError, 'linked sample'):
                demand.read_bank(MetadataOnly(bytes(data)))
        data = bytearray(base)
        struct.pack_into('<H', data, data.index(b'shdr') + 8 + 46 + 42, 1)
        with self.assertRaisesRegex(demand.AuditError, 'linked sample'):
            demand.read_bank(MetadataOnly(bytes(data)))
        for first, second in [(4, 2), (2, 4), (8, 8)]:
            data = bytearray(base)
            start = data.index(b'shdr') + 8
            struct.pack_into('<H', data, start + 44, first)
            struct.pack_into('<H', data, start + 46 + 44, second)
            bank = demand.read_bank(MetadataOnly(bytes(data)))
            self.assertEqual(bank.select(30, 0, 60, 100)[0]['secondary_streams'], 1)

    def test_nonreciprocal_link_to_valid_third_header_rejected(self):
        data = bytearray(bank_fixture(linked=True, izones=[[(53, 0)]]))
        shdr = data.index(b'shdr')
        start = shdr + 8
        # Three valid typed/bounded headers, but 0 -> 1 -> 2 is not reciprocal.
        struct.pack_into('<H', data, start + 46 + 42, 2)
        third = name('third') + struct.pack('<IIIIIBbHH', 0, 100, 10, 90, 44100, 60, 0, 1, 4)
        struct.pack_into('<I', data, shdr + 4, struct.unpack_from('<I', data, shdr + 4)[0] + 46)
        pdta_size = data.index(b'pdta') - 4
        struct.pack_into('<I', data, pdta_size, struct.unpack_from('<I', data, pdta_size)[0] + 46)
        data[start + 92:start + 92] = third
        struct.pack_into('<I', data, 4, len(data) - 8)
        with self.assertRaisesRegex(demand.AuditError, 'linked sample'):
            demand.read_bank(MetadataOnly(bytes(data)))

    def test_root_override_range_and_pinned_sentinel(self):
        for value in (128, 254, 256, 30000, -1):
            with self.subTest(value=value), self.assertRaisesRegex(demand.AuditError, 'root override'):
                self.bank(izones=[[(58, value), (53, 0)]])
        for value in (0, 127, 255):
            self.assertEqual(len(self.bank(izones=[[(58, value), (53, 0)]]).select(30, 0, 60, 100)), 1)

    def test_root_only_cli_pins_drift_and_unknown_native_fields(self):
        # Source bytes are identity fixtures, not a simulated native runtime.
        with tempfile.TemporaryDirectory(prefix='music-demand-', dir='/private/tmp') as folder:
            root = Path(folder)
            hashes = {}
            for relative in demand.SOURCE_HASHES:
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                data = f'identity fixture: {relative}\n'.encode()
                path.write_bytes(data)
                hashes[relative] = demand.digest(data)
            data = bank_fixture()
            audio = root / 'game/audio'
            (audio / 'GeneralUser-GS.sf2').write_bytes(data)
            score = midi([[(0, b'\xc0\x1e'), (0, b'\x90\x3c\x64'), (120, b'\x80\x3c\x00')]])
            for level in demand.LEVELS:
                (audio / f'{level}.mid').write_bytes(score)
            original_open, guards = Path.open, []
            def guarded_open(path, *args, **kwargs):
                if path == audio / 'GeneralUser-GS.sf2':
                    source = MetadataOnly(data)
                    guards.append(source)
                    return source
                return original_open(path, *args, **kwargs)
            with patch.object(demand, 'SOURCE_HASHES', hashes), patch.object(demand, 'PROGRAMS', (30,)), \
                    patch.object(Path, 'open', guarded_open):
                output, errors = io.StringIO(), io.StringIO()
                with redirect_stdout(output), redirect_stderr(errors):
                    try:
                        code = demand.main(['--root', str(root)])
                    except SystemExit as error:
                        code = error.code
                self.assertEqual(code, 0, errors.getvalue())
                report = json.loads(output.getvalue())
                self.assertEqual(report['source_sha256'], hashes)
                self.assertEqual(len(report['scores']), 8)
                self.assertIsNone(report['native_peak'])
                self.assertIsNone(report['captured_output_parity'])
                self.assertFalse(report['no_steal_verified'])
                self.assertFalse(report['pool_reduction_authorized'])
                self.assertFalse(report['sf2']['pcm_read'])
                self.assertTrue(guards)
                self.assertLess(guards[0].bytes_read, len(data) - 400)
                changed = next(iter(hashes))
                (root / changed).write_bytes(b'drift')
                output, errors = io.StringIO(), io.StringIO()
                with redirect_stdout(output), redirect_stderr(errors):
                    self.assertEqual(demand.main(['--root', str(root)]), 2)
                self.assertEqual(output.getvalue(), '')
                self.assertIn('source pin mismatch', errors.getvalue())
                self.assertEqual(len(guards), 1, 'pin drift must fail before SF2 opens')

    def test_six_runtime_source_pins_include_decoder_and_record_widths(self):
        self.assertEqual(len(demand.SOURCE_HASHES), 6)
        self.assertEqual(demand.SOURCE_HASHES['game/addons/midi/SMF.gd'],
                         '6ee7a4bf07cb5a31dfc9c18010e52fb13ad6395cd7a7662493c9c0d6d433aacd')
        self.assertEqual(list(demand.WIDTHS), list(demand.FORMATS))
        self.assertEqual(list(demand.WIDTHS.values()), [38, 4, 10, 4, 22, 4, 10, 4, 46])


if __name__ == '__main__':
    unittest.main()
