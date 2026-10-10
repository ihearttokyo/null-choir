"""Offline generation resolution; fixtures never use production assets."""
import hashlib
from pathlib import Path
import tempfile
import unittest
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from art_recipe import resolve_recipe, validate_recipe


class RecipeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.logical = 'tools/build_art.py'
        self.current = self.write(self.logical, b'current recipe')
        self.old = b'original recipe'
        self.pin = hashlib.sha256(self.old).hexdigest()
        self.archived = self.write('source/art/recipe_history/' + self.pin + '/' + self.logical + '.txt', self.old)

    def write(self, path, data):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        return target

    def test_mixed_generation(self):
        current_pin = hashlib.sha256(self.current.read_bytes()).hexdigest()
        self.assertEqual(resolve_recipe(self.root, self.logical, current_pin), self.current)
        self.assertEqual(resolve_recipe(self.root, self.logical, self.pin), self.archived)
        entry = {'provenance': {'authoring_script': self.logical}, 'recipe_sha256': self.pin,
                 'recipe_dependencies': {self.logical: current_pin}}
        validate_recipe(self.root, entry, self.logical, [self.logical])
        with self.assertRaises(AssertionError):
            validate_recipe(self.root, entry, self.logical, [])
        entry['recipe_dependencies'][self.logical] = '0' * 64
        with self.assertRaises(ValueError):
            validate_recipe(self.root, entry, self.logical, [self.logical])

    def test_missing_unknown_and_tamper(self):
        with self.assertRaises(ValueError):
            resolve_recipe(self.root, self.logical, '0' * 64)
        self.archived.write_bytes(b'tampered recipe')
        with self.assertRaises(ValueError):
            resolve_recipe(self.root, self.logical, self.pin)
        self.archived.unlink()
        with self.assertRaises(ValueError):
            resolve_recipe(self.root, self.logical, self.pin)
        self.current.unlink()
        self.archived.write_bytes(self.old)
        self.assertEqual(resolve_recipe(self.root, self.logical, self.pin), self.archived)

    def test_path_and_digest_boundary(self):
        for path in ['../tools/build_art.py', '/tools/build_art.py', 'tools/../build_art.py',
                     'tools//build_art.py', 'tools/./build_art.py', 'source/art/build_art.py',
                     'tools/build_art.py.txt', 'tools\\build_art.py']:
            with self.subTest(path=path), self.assertRaises(ValueError):
                resolve_recipe(self.root, path, self.pin)
        for pin in [None, '', self.pin.upper(), '../' + self.pin, 'a' * 63]:
            with self.subTest(pin=pin), self.assertRaises(ValueError):
                resolve_recipe(self.root, self.logical, pin)

    def test_symlink_file_directory_and_archive(self):
        self.current.unlink()
        self.current.symlink_to(self.archived)
        with self.assertRaises(ValueError):
            resolve_recipe(self.root, self.logical, self.pin)
        self.current.unlink()
        (self.root / 'tools').rmdir()
        (self.root / 'tools').symlink_to(self.archived.parent, target_is_directory=True)
        with self.assertRaises(ValueError):
            resolve_recipe(self.root, self.logical, self.pin)
        (self.root / 'tools').unlink()
        self.archived.unlink()
        target = self.write('other/original.txt', self.old)
        self.archived.symlink_to(target)
        with self.assertRaises(ValueError):
            resolve_recipe(self.root, self.logical, self.pin)
        self.archived.unlink()
        self.archived.parent.rmdir()
        self.archived.parent.symlink_to(target.parent, target_is_directory=True)
        with self.assertRaises(ValueError):
            resolve_recipe(self.root, self.logical, self.pin)


if __name__ == '__main__':
    unittest.main()
