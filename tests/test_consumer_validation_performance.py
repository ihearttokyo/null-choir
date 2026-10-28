"""Pure privacy equivalence/full-byte replay tests; no native or resident edits."""
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]

def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value

c = module('performance_consumer', ROOT / 'tools/art_consumer_compatibility.py')
p = module('performance_portable', ROOT / 'source/art/consumer-qualification-v0096/portable96.py')

# Exact original privacy predicate, before necessary-literal prefilters.
PATTERNS = [r'/Users/', r'/home/', r'/private/(?:tmp|var)/', r'\\Users\\', r'\.codex/',
    r'(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    r'(?<!\w)\+[1-9][0-9][0-9 ()-]{6,}[0-9]',
    r'(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b',
    r'(?i)"(?:pid|ppid|pgid|argv|wrapper_argv|environment|access_token|refresh_token|password)"\s*:']

def original_refuses(text):
    views = [text]
    try:
        views.append(json.dumps(json.loads(text), ensure_ascii=False))
    except (ValueError, TypeError):
        pass
    views += [view.replace(chr(92), '/') for view in views]
    return any(re.search(pattern, view) for pattern in PATTERNS for view in views)

class ValidationPerformance(unittest.TestCase):
    def test_privacy_predicate_equivalence_all_patterns_and_encoded_views(self):
        tokens = ['/Users/person', '/home/person', '/private/tmp/run', '/private/var/file',
                  r'C:\Users\person', '.codex/file', 'person@example.invalid', '+12345678901',
                  '01234567-89ab-cdef-0123-456789abcdef', '"PID" : 1',
                  '"wrapper_argv":[]', '"password":"x"']
        texts = ['', '123.456 00000000000000000000000000000000', '/private/not-tmp/file',
                 'person at example.invalid', 'a+12345678901', '"pid_without_colon"',
                 '{"current_source_sha256":"' + 'a' * 64 + '"}']
        for token in tokens:
            texts.extend([token, json.dumps({'text': token}),
                          json.dumps({'text': token}).replace('@', r'\u0040').replace('/', r'\/')])
        texts.extend(['{"\\u0070id":1}', '{"x":"\\u002fUsers\\u002fperson"}'])
        for text in texts:
            with self.subTest(text=text):
                expected = original_refuses(text)
                try:
                    p._privacy_text(text)
                    refused = False
                except ValueError:
                    refused = True
                self.assertEqual(refused, expected)

    def test_absent_sentinel_does_not_run_expensive_email_regex(self):
        original = re.search
        patterns = []
        def search(pattern, value):
            patterns.append(pattern)
            return original(pattern, value)
        with patch.object(p.re, 'search', side_effect=search):
            p._privacy_text('0123456789abcdef' * 4096)
        self.assertNotIn(PATTERNS[5], patterns)

    def fixture(self, root, raw=b'original'):
        rel = 'source/art/proof.json'
        path = root / rel
        path.parent.mkdir(parents=True)
        path.write_bytes(raw)
        folder = root / 'source/art/case'
        folder.mkdir()
        (folder / 'frame.png').write_bytes(b'png')
        return path, {'root': str(root.absolute()),
                      'files': {rel: (len(raw), hashlib.sha256(raw).hexdigest())},
                      'directories': {'source/art/case': ('frame.png',)}}

    def test_full_bytes_same_stat_invalidation_and_directory_membership(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            path, observed = self.fixture(root)
            self.assertTrue(c._memo96_replay(root, observed))
            before = path.stat()
            path.write_bytes(b'changed!')  # Same length and restored mtime cannot hide drift.
            os.utime(path, ns=(before.st_atime_ns, before.st_mtime_ns))
            self.assertEqual(path.stat().st_size, before.st_size)
            self.assertFalse(c._memo96_replay(root, observed))
            path.write_bytes(b'original')
            (root / 'source/art/case/foreign.png').write_bytes(b'foreign')
            self.assertFalse(c._memo96_replay(root, observed))

    def test_cache_read_rejects_symlinks_missing_and_cross_root_content(self):
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            root = Path(first).resolve()
            path, observed = self.fixture(root)
            other = Path(second).resolve()
            self.fixture(other, b'foreign!')
            self.assertFalse(c._memo96_replay(other, observed))
            moved = path.with_suffix('.held')
            path.rename(moved)
            with self.assertRaises(FileNotFoundError):
                c._memo96_replay(root, observed)
            path.symlink_to(moved)
            with self.assertRaisesRegex(ValueError, 'symlink'):
                c._memo96_replay(root, observed)
            self.assertNotEqual(c._memo96_key(root), c._memo96_key(other))

    def test_config_and_code_identity_are_in_content_key(self):
        key = c._memo96_key(ROOT)
        with patch.object(c, 'RECEIPT96_SHA', '0' * 64):
            self.assertNotEqual(c._memo96_key(ROOT), key)
        original = Path.read_bytes
        with patch.object(Path, 'read_bytes', lambda path: original(path) + b'\ncode-change'):
            self.assertNotEqual(c._memo96_key(ROOT), key)

    def test_custom_or_patched_validator_cannot_consume_or_poison_success_cache(self):
        with patch.object(c, '_qualify96_uncached', return_value={'custom': True}) as mocked:
            self.assertEqual(c.qualify96(ROOT), {'custom': True})
            mocked.assert_called_once_with(ROOT, None)

if __name__ == '__main__':
    unittest.main()
