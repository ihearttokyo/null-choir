"""Pure version allocation/display joins; no engine, export, Git or network calls."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('build_iterations', ROOT / 'tools/build_iterations.py')
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class BuildIterations(unittest.TestCase):
    def setUp(self):
        self.data = json.loads((ROOT / build.LEDGER).read_text())

    def fixture(self, directory):
        root = Path(directory)
        for relative in ('game/project.godot', 'game/export_presets.cfg', 'game/scripts/build_info.gd', str(build.LEDGER)):
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((ROOT / relative).read_bytes())
        return root

    def test_current94_metadata_exact(self):
        self.assertEqual(build.validate(self.data), 94)
        self.assertEqual(build.identity(94), {
            'ordinal': 94, 'version': '0.094', 'display_name': 'Null Choir v0.094',
            'app_name': 'Null Choir v0.094.app', 'archive_name': 'Null-Choir-v0.094.zip',
            'cfbundle_version': '94'})
        for path, expected in build.metadata(ROOT, self.data).items():
            self.assertEqual(path.read_text(), expected, str(path))

    def test_audited_seed_is_not_an_export_or_lifetime_count(self):
        seed = self.data['seed']
        self.assertEqual(seed['first_parent_states'] + seed['additional_branch_states'], 93)
        self.assertIn('Not an exact lifetime/uncommitted', seed['scope'])
        self.assertIn('exported-build count', seed['scope'])
        self.assertEqual(seed['source_commit'], build.SEED_COMMIT)
        self.assertEqual(seed['projection_identity_set_sha256'], build.SEED_SET)
        self.assertNotIn('source_commit', self.data['allocations'][0])

    def test_reserve_is_monotonic_and_does_not_mutate_input(self):
        before = copy.deepcopy(self.data)
        updated = build.reserve(self.data, 'next-authored-candidate', 94)
        self.assertEqual(self.data, before)
        self.assertEqual(build.validate(updated), 95)
        self.assertEqual(updated['allocations'][:-1], self.data['allocations'])
        self.assertEqual(updated['allocations'][-1]['candidate'], 'next-authored-candidate')

    def test_same_source_candidate_retry_is_idempotent(self):
        self.assertEqual(build.reserve(self.data, 'seal-wardens-and-dimensional-walls', 94), self.data)

    def test_stale_reservation_refuses_even_for_retry(self):
        for expected in (93, 95, True, 94.0, '94', None):
            with self.subTest(expected=expected), self.assertRaises(ValueError):
                build.reserve(self.data, 'seal-wardens-and-dimensional-walls', expected)

    def test_failed_ordinal_is_retained_never_reused(self):
        self.data['allocations'][0]['status'] = 'failed'
        with self.assertRaises(ValueError):
            build.reserve(self.data, 'seal-wardens-and-dimensional-walls', 94)
        updated = build.reserve(self.data, 'replacement-source', 94)
        self.assertEqual(updated['allocations'][0]['status'], 'failed')
        self.assertEqual(updated['allocations'][-1]['ordinal'], 95)

    def test_earlier_candidate_cannot_be_reissued(self):
        updated = build.reserve(self.data, 'next-source', 94)
        with self.assertRaises(ValueError):
            build.reserve(updated, 'seal-wardens-and-dimensional-walls', 95)

    def test_invalid_candidate_keys_refuse(self):
        for key in ('', '../escape', 'Preview 08', '-candidate', 'source--two', 95, None):
            with self.subTest(key=key), self.assertRaises(ValueError):
                build.reserve(self.data, key, 94)

    def test_seed_tampering_refuses(self):
        for field, value in (('ordinal', 235), ('reachable_commits', 290), ('source_commit', '0' * 40),
                             ('projection_identity_set_sha256', '0' * 64), ('missing_trees', True)):
            data = copy.deepcopy(self.data)
            data['seed'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                build.validate(data)

    def test_missing_duplicate_reordered_or_foreign_allocations_refuse(self):
        for change in ('empty', 'duplicate', 'gap', 'bool', 'foreign', 'initial'):
            data = copy.deepcopy(self.data)
            if change == 'empty': data['allocations'] = []
            elif change == 'duplicate': data['allocations'].append(copy.deepcopy(data['allocations'][0]))
            elif change == 'gap': data['allocations'].append({'ordinal': 96, 'candidate': 'next', 'status': 'reserved'})
            elif change == 'bool': data['allocations'][0]['ordinal'] = True
            elif change == 'foreign': data['allocations'][0]['final_commit'] = '0' * 40
            else: data['allocations'][0]['candidate'] = 'rewritten-initial'
            with self.subTest(change=change), self.assertRaises(ValueError):
                build.validate(data)

    def test_decimal_integer_format_does_not_roll_over_at999(self):
        self.assertEqual(build.identity(1000)['version'], '0.1000')
        for ordinal in (True, 94.0, '94', 93):
            with self.assertRaises(ValueError): build.identity(ordinal)

    def test_sync_changes_only_display_fields_and_preserves_saves_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            next_data = build.reserve(self.data, 'next-source', 94)
            current = build.metadata(root, self.data)
            updated = build.metadata(root, next_data)
            for path, text in updated.items():
                build.atomic_write(path, text)
                # Re-rendering for94 must restore the exact original source bytes.
            self.assertEqual(build.metadata(root, self.data), current)
            self.assertIn('config/name="NULL CHOIR"', (root / 'game/project.godot').read_text())
            self.assertIn('application/bundle_identifier="com.ihearttokyo.nullchoir"', (root / 'game/export_presets.cfg').read_text())
            self.assertIn('config/version="0.095"', (root / 'game/project.godot').read_text())
            self.assertIn('application/version="95"', (root / 'game/export_presets.cfg').read_text())

    def test_save_namespace_and_bundle_mutations_refuse(self):
        for kind in ('project', 'bundle', 'custom'):
            with tempfile.TemporaryDirectory() as directory:
                root = self.fixture(directory)
                p = root / ('game/export_presets.cfg' if kind == 'bundle' else 'game/project.godot')
                text = p.read_text()
                if kind == 'project': text = text.replace('config/name="NULL CHOIR"', 'config/name="Null Choir v0.094"')
                elif kind == 'bundle': text = text.replace('com.ihearttokyo.nullchoir', 'com.foreign.nullchoir')
                else: text += '\nconfig/use_custom_user_dir=true\n'
                p.write_text(text)
                with self.subTest(kind=kind), self.assertRaises(ValueError): build.metadata(root, self.data)

    def test_duplicate_display_field_refuses(self):
        with self.assertRaises(ValueError):
            build.replace_field('config/version="a"\nconfig/version="b"\n', 'config/version', '0.094')

    def test_atomic_write_failure_keeps_original_ledger(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'ledger.json'
            path.write_text('original')
            with patch.object(build.os, 'replace', side_effect=OSError('simulated interruption')):
                with self.assertRaises(OSError): build.atomic_write(path, 'replacement')
            self.assertEqual(path.read_text(), 'original')
            self.assertEqual(list(Path(directory).iterdir()), [path])

    def test_default_cli_is_readonly_and_lock_collision_refuses(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            before = {p: p.read_bytes() for p in root.rglob('*') if p.is_file()}
            with patch.object(build, 'ROOT', root), patch('sys.argv', ['build_iterations.py']):
                build.main()
            self.assertEqual({p: p.read_bytes() for p in before}, before)
            lock = root / (str(build.LEDGER) + '.lock')
            lock.write_text('another owner')
            with patch.object(build, 'ROOT', root), patch('sys.argv', ['build_iterations.py', '--reserve', 'next', '--expect-last', '94']):
                with self.assertRaises(FileExistsError): build.main()
            self.assertEqual(lock.read_text(), 'another owner')
            self.assertEqual((root / build.LEDGER).read_bytes(), before[root / build.LEDGER])

    def test_reserve_then_explicit_sync_and_check(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            def cli(*args):
                with patch.object(build, 'ROOT', root), patch('sys.argv', ['build_iterations.py', *args]):
                    build.main()
            cli('--reserve', 'next-source', '--expect-last', '94')
            self.assertEqual(build.validate(json.loads((root / build.LEDGER).read_text())), 95)
            with self.assertRaises(ValueError): cli('--check')
            with self.assertRaises(ValueError): cli('--sync', '--expect-last', '94')
            cli('--sync', '--expect-last', '95')
            cli('--check')
            self.assertFalse((root / (str(build.LEDGER) + '.lock')).exists())

    def test_public_buildinfo_api(self):
        text = (ROOT / 'game/scripts/build_info.gd').read_text()
        self.assertIn('const APP_NAME = DISPLAY_NAME', text)
        self.assertIn('static func display_name() -> String:\n\treturn DISPLAY_NAME', text)

    def test_macos_default_name_and_actual_metadata_gate(self):
        spec = importlib.util.spec_from_file_location('null_choir_macos_version_test', ROOT / 'tools/build_macos.py')
        mac = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mac)
        self.assertEqual(mac.OUTPUT.name, 'Null-Choir-v0.094.zip')
        app = Path('/synthetic/Null Choir v0.094.app')
        info = {'CFBundleName': 'Null Choir v0.094', 'CFBundleIdentifier': 'com.ihearttokyo.nullchoir',
                'CFBundleShortVersionString': '0.094', 'CFBundleVersion': '94'}
        mac.check_build_identity(app, info)
        with self.assertRaises(ValueError): mac.check_build_identity(Path('/synthetic/Alpha4.app'), info)
        for key, value in (('CFBundleName', 'NULL CHOIR'), ('CFBundleDisplayName', 'Preview07'),
                           ('CFBundleIdentifier', 'com.foreign.nullchoir'),
                           ('CFBundleShortVersionString', '0.2.3'), ('CFBundleVersion', '0.094')):
            changed = {**info, key: value}
            with self.subTest(key=key), self.assertRaises(ValueError): mac.check_build_identity(app, changed)


if __name__ == '__main__':
    unittest.main()
