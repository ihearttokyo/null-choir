"""Synthetic ZIP security/contract checks; no provider, engine or external I/O."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import stat
import struct
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from PIL import Image, ImageDraw

SPEC = importlib.util.spec_from_file_location('ingest_pro_art', Path(__file__).resolve().parents[1] / 'tools/ingest_pro_art.py')
m = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(m)


def png(size=(1024, 640), mode='RGBA', clone=False, empty=False):
    im = Image.new(mode, size)
    if not empty:
        draw = ImageDraw.Draw(im)
        columns, rows = (8, 5) if size != (960, 200) else (3, 1)
        for row in range(rows):
            for col in range(columns):
                color = (100 if clone else 20 + col * 25, 50 + row * 30, 70, 255)
                if mode == 'RGB': color = color[:3]
                x, y = col * (size[0] // columns), row * (size[1] // rows)
                draw.rectangle((x + 10, y + 10, x + 25, y + 25), fill=color)
    out = io.BytesIO()
    im.save(out, format='PNG')
    return out.getvalue()


class IntakeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.archive = self.root / 'input.zip'

    def write(self, pairs, compression=zipfile.ZIP_STORED):
        with zipfile.ZipFile(self.archive, 'w', compression=compression) as zf:
            for name, data in pairs: zf.writestr(name, data)

    def ingest(self, pairs):
        self.write(pairs)
        return m.ingest(self.archive, 'intake/result', self.root, 'source/art/input.zip')

    def rejected(self, pairs):
        self.write(pairs)
        with self.assertRaises(m.IntakeError):
            m.ingest(self.archive, 'intake/result', self.root)
        self.assertFalse((self.root / 'intake/result').exists())

    def test_exact_originals_public_metadata_no_integration(self):
        data = png()
        result = self.ingest([('runtime/crawler.png', data)])
        item = result['records'][0]
        self.assertEqual(item['status'], 'TECHNICAL_CANDIDATE')
        self.assertEqual(item['dimensions'], [1024, 640])
        self.assertEqual(item['sha256'], hashlib.sha256(data).hexdigest())
        self.assertEqual((self.root / item['retained_path']).read_bytes(), data)
        self.assertNotIn(str(self.root), json.dumps(result))
        self.assertEqual(result['visual_9_plus'], 'NOT_ASSESSED')
        self.assertEqual(len(result['missing_atlas_ids']), 13)
        with self.assertRaises(m.IntakeError):
            m.ingest(self.archive, 'intake/result', self.root)

    def test_all_14_atlas_contracts(self):
        self.assertEqual(len(m.ATLAS), 14)
        for name, (w, h, _, _) in m.ATLAS.items():
            with self.subTest(name=name):
                self.assertEqual(m.inspect_png(png((w, h)), 'atlas', name)['status'], 'TECHNICAL_CANDIDATE')

    def test_invalid_atlas_is_concept_only_no_repair(self):
        for data in [png((960, 200)), png(mode='RGB'), png(empty=True), png(clone=True)]:
            with self.subTest(size=len(data)):
                self.assertEqual(m.inspect_png(data, 'atlas', 'crawler')['status'], 'CONCEPT_ONLY')
        item = self.ingest([('crawler.png', png((960, 200)))])['records'][0]
        self.assertEqual(item['dimensions'], [960, 200])
        self.assertEqual(item['status'], 'CONCEPT_ONLY')

    def test_no_clone_all_eight_views(self):
        result = m.inspect_png(png(clone=True), 'atlas', 'crawler')
        self.assertTrue(any('eight directional views cloned' in r for r in result['reasons']))

    def test_nine_painting_ids_and_actual_dimensions(self):
        for i, name in enumerate(m.CHAPTERS):
            self.assertEqual(m.classify(f'null_choir_{i:02d}_{name}.png'), ('painting', f'{i:02d}_{name}'))
        data = png((1672, 941))
        result = self.ingest([('null_choir_05_the_nursery.png', data)])
        self.assertEqual(result['records'][0]['dimensions'], [1672, 941])
        self.assertFalse(result['records'][0]['native_8k'])
        self.assertEqual(result['records'][0]['status'], 'TECHNICAL_CANDIDATE')
        self.assertEqual(len(result['missing_painting_ids']), 8)

    def test_palette_painting_and_empty_live_cell(self):
        im = Image.new('P', (640, 360))
        im.putpalette([v for i in range(256) for v in (i, i, i)])
        ImageDraw.Draw(im).rectangle((20, 20, 100, 100), fill=1)
        out = io.BytesIO()
        im.save(out, format='PNG')
        self.assertEqual(m.inspect_png(out.getvalue(), 'painting', '00_title')['status'], 'TECHNICAL_CANDIDATE')
        im = Image.open(io.BytesIO(png()))
        ImageDraw.Draw(im).rectangle((0, 0, 127, 127), fill=(0, 0, 0, 0))
        out = io.BytesIO()
        im.save(out, format='PNG')
        result = m.inspect_png(out.getvalue(), 'atlas', 'crawler')
        self.assertIn('Empty atlas cell row0 column0', result['reasons'])

    def test_path_and_duplicate_guards(self):
        for name in ['../escape.png', '/escape.png', 'C:/escape.png', r'a\escape.png', 'a/../b.png', 'a//b.png']:
            with self.subTest(name=name): self.rejected([(name, b'x')])
        self.rejected([('a.png', b'a'), ('A.png', b'b')])
        self.rejected([('folder', b'a'), ('folder/a.png', b'b')])
        self.rejected([('crawler.png', png()), ('nested/crawler.png', png())])

    def test_symlink_archive_and_destination(self):
        link = zipfile.ZipInfo('symlink')
        link.create_system = 3
        link.external_attr = (stat.S_IFLNK | 0o777) << 16
        self.rejected([(link, b'../outside')])
        self.write([('notes.txt', b'notes')])
        (self.root / 'alias').symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(m.IntakeError): m.ingest(self.archive, 'alias/fresh', self.root)
        with self.assertRaises(m.IntakeError): m.ingest(self.archive, self.root.parent / 'outside', self.root)

    def test_budgets_before_output(self):
        self.write([('large.txt', b'a' * 10000)], zipfile.ZIP_DEFLATED)
        with self.assertRaises(m.IntakeError): m.ingest(self.archive, 'fresh', self.root)
        self.write([('one', b'a'), ('two', b'b')])
        with patch.object(m, 'MAX_FILES', 1):
            with self.assertRaises(m.IntakeError): m.ingest(self.archive, 'fresh', self.root)
        with patch.object(m, 'MAX_TOTAL', 1):
            with self.assertRaises(m.IntakeError): m.ingest(self.archive, 'fresh', self.root)
        self.assertFalse((self.root / 'fresh').exists())

    def test_crc_and_invalid_png(self):
        self.write([('test.txt', b'unique payload')])
        raw = bytearray(self.archive.read_bytes())
        # Corrupt the stored member data, not its central-directory CRC.
        name_len, extra_len = struct.unpack_from('<HH', raw, 26)
        raw[30 + name_len + extra_len] ^= 1
        self.archive.write_bytes(raw)
        with self.assertRaises(m.IntakeError): m.ingest(self.archive, 'fresh', self.root)
        self.assertFalse((self.root / 'fresh').exists())
        result = self.ingest([('crawler.png', b'not an image')])
        self.assertEqual(result['records'][0]['status'], 'CONCEPT_ONLY')


if __name__ == '__main__': unittest.main()
