"""Pure version allocation/display joins; no engine, export, Git or network calls."""
import copy
import importlib.util
import json
import plistlib
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
        # Fixed historical allocator fixture; real current identity is tested separately.
        self.data = json.loads((ROOT / build.LEDGER).read_text())
        self.data['allocations'] = self.data['allocations'][:2]
        self.assertEqual(build.validate(self.data), 95)

    def fixture(self, directory):
        root = Path(directory)
        for relative in ('game/project.godot', 'game/export_presets.cfg', 'game/scripts/build_info.gd', str(build.LEDGER)):
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((ROOT / relative).read_bytes())
        (root / build.LEDGER).write_text(json.dumps(self.data))
        for path, text in build.metadata(root, self.data).items():
            path.write_text(text)
        return root

    def test_current97_metadata_exact(self):
        current = json.loads((ROOT / build.LEDGER).read_text())
        self.assertEqual(build.validate(current), 97)
        self.assertEqual(current['allocations'][:-1], [
            {'ordinal': 94, 'candidate': 'seal-wardens-and-dimensional-walls', 'status': 'failed',
             'failure_reason': 'Committed production state 4b437a8: verified P1 wall front-face winding defect; ordinal94 retired, no release.'},
            {'ordinal': 95, 'candidate': 'seal-wardens-dimensional-walls-frontfaces', 'status': 'reserved'},
            {'ordinal': 96, 'candidate': 'earned-arsenal-momentum-local-horror', 'status': 'reserved'},
        ])
        self.assertEqual(current['allocations'][-1], {
            'ordinal': 97, 'candidate': 'readable-pursuit-autorun', 'status': 'reserved'})
        self.assertEqual(build.identity(97), {
            'ordinal': 97, 'version': '0.097', 'display_name': 'Null Choir v0.097',
            'app_name': 'Null Choir v0.097.app', 'archive_name': 'Null-Choir-v0.097.zip',
            'cfbundle_version': '97'})
        for path, expected in build.metadata(ROOT, current).items():
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
        updated = build.reserve(self.data, 'next-authored-candidate', 95)
        self.assertEqual(self.data, before)
        self.assertEqual(build.validate(updated), 96)
        self.assertEqual(updated['allocations'][:-1], self.data['allocations'])
        self.assertEqual(updated['allocations'][-1]['candidate'], 'next-authored-candidate')

    def test_same_source_candidate_retry_is_idempotent(self):
        self.assertEqual(build.reserve(self.data, 'seal-wardens-dimensional-walls-frontfaces', 95), self.data)

    def test_stale_reservation_refuses_even_for_retry(self):
        for expected in (93, 94, 96, True, 95.0, '95', None):
            with self.subTest(expected=expected), self.assertRaises(ValueError):
                build.reserve(self.data, 'seal-wardens-dimensional-walls-frontfaces', expected)

    def test_failed_ordinal_is_retained_never_reused(self):
        self.data['allocations'][0]['status'] = 'failed'
        with self.assertRaises(ValueError):
            build.reserve(self.data, 'seal-wardens-and-dimensional-walls', 95)
        updated = build.reserve(self.data, 'replacement-source', 95)
        self.assertEqual(updated['allocations'][0]['status'], 'failed')
        self.assertEqual(updated['allocations'][-1]['ordinal'], 96)

    def test_earlier_candidate_cannot_be_reissued(self):
        updated = build.reserve(self.data, 'next-source', 95)
        with self.assertRaises(ValueError):
            build.reserve(updated, 'seal-wardens-and-dimensional-walls', 96)

    def test_invalid_candidate_keys_refuse(self):
        for key in ('', '../escape', 'Preview 08', '-candidate', 'source--two', 96, None):
            with self.subTest(key=key), self.assertRaises(ValueError):
                build.reserve(self.data, key, 95)

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
            elif change == 'gap': data['allocations'].append({'ordinal': 97, 'candidate': 'next', 'status': 'reserved'})
            elif change == 'bool': data['allocations'][0]['ordinal'] = True
            elif change == 'foreign': data['allocations'][0]['final_commit'] = '0' * 40
            else: data['allocations'][0]['candidate'] = 'rewritten-initial'
            with self.subTest(change=change), self.assertRaises(ValueError):
                build.validate(data)

    def test_decimal_integer_format_does_not_roll_over_at999(self):
        self.assertEqual(build.identity(1000)['version'], '0.1000')
        for ordinal in (True, 95.0, '95', 93):
            with self.assertRaises(ValueError): build.identity(ordinal)

    def test_sync_changes_only_display_fields_and_preserves_saves_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            next_data = build.reserve(self.data, 'next-source', 95)
            current = build.metadata(root, self.data)
            updated = build.metadata(root, next_data)
            for path, text in updated.items():
                build.atomic_write(path, text)
                # Re-rendering for95 must restore the exact original source bytes.
            self.assertEqual(build.metadata(root, self.data), current)
            self.assertIn('config/name="NULL CHOIR"', (root / 'game/project.godot').read_text())
            self.assertIn('application/bundle_identifier="com.ihearttokyo.nullchoir"', (root / 'game/export_presets.cfg').read_text())
            self.assertIn('config/version="0.096"', (root / 'game/project.godot').read_text())
            self.assertIn('application/version="96"', (root / 'game/export_presets.cfg').read_text())

    def test_save_namespace_and_bundle_mutations_refuse(self):
        for kind in ('project', 'bundle', 'custom'):
            with tempfile.TemporaryDirectory() as directory:
                root = self.fixture(directory)
                p = root / ('game/export_presets.cfg' if kind == 'bundle' else 'game/project.godot')
                text = p.read_text()
                if kind == 'project': text = text.replace('config/name="NULL CHOIR"', 'config/name="Null Choir v0.095"')
                elif kind == 'bundle': text = text.replace('com.ihearttokyo.nullchoir', 'com.foreign.nullchoir')
                else: text += '\nconfig/use_custom_user_dir=true\n'
                p.write_text(text)
                with self.subTest(kind=kind), self.assertRaises(ValueError): build.metadata(root, self.data)

    def test_duplicate_display_field_refuses(self):
        with self.assertRaises(ValueError):
            build.replace_field('config/version="a"\nconfig/version="b"\n', 'config/version', '0.095')

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
            with patch.object(build, 'ROOT', root), patch('sys.argv', ['build_iterations.py', '--reserve', 'next', '--expect-last', '95']):
                with self.assertRaises(FileExistsError): build.main()
            self.assertEqual(lock.read_text(), 'another owner')
            self.assertEqual((root / build.LEDGER).read_bytes(), before[root / build.LEDGER])

    def test_reserve_then_explicit_sync_and_check(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            def cli(*args):
                with patch.object(build, 'ROOT', root), patch('sys.argv', ['build_iterations.py', *args]):
                    build.main()
            cli('--reserve', 'next-source', '--expect-last', '95')
            self.assertEqual(build.validate(json.loads((root / build.LEDGER).read_text())), 96)
            with self.assertRaises(ValueError): cli('--check')
            with self.assertRaises(ValueError): cli('--sync', '--expect-last', '95')
            cli('--sync', '--expect-last', '96')
            cli('--check')
            self.assertFalse((root / (str(build.LEDGER) + '.lock')).exists())

    def test_public_buildinfo_api(self):
        text = (ROOT / 'game/scripts/build_info.gd').read_text()
        self.assertIn('const APP_NAME = DISPLAY_NAME', text)
        self.assertIn('static func display_name() -> String:\n\treturn DISPLAY_NAME', text)

    def test_failed94_history_and_historical_identity_are_retained(self):
        old, current = self.data['allocations']
        self.assertEqual(old['ordinal'], 94)
        self.assertEqual(old['candidate'], 'seal-wardens-and-dimensional-walls')
        self.assertEqual(old['status'], 'failed')
        self.assertIn('winding defect', old['failure_reason'])
        self.assertEqual(current, {'ordinal': 95, 'candidate': 'seal-wardens-dimensional-walls-frontfaces', 'status': 'reserved'})
        self.assertEqual(build.identity(94)['display_name'], 'Null Choir v0.094')
        self.assertEqual(build.identity(94)['archive_name'], 'Null-Choir-v0.094.zip')

    def test_mark_failed_is_explicit_immutable_and_never_reuses_ordinal(self):
        before = copy.deepcopy(self.data)
        key = self.data['allocations'][-1]['candidate']
        failed = build.mark_failed(self.data, key, 95, 'controlled test failure')
        self.assertEqual(build.validate(failed), 95)  # Retired history remains auditable/reservable.
        self.assertEqual(build.active_identity(self.data), build.identity(95))
        with self.assertRaisesRegex(ValueError, 'Failed ordinal'): build.active_identity(failed)
        self.assertEqual(self.data, before)
        self.assertEqual(failed['allocations'][-1]['status'], 'failed')
        self.assertEqual(build.mark_failed(failed, key, 95, 'controlled test failure'), failed)
        for reason in ('', None, 'x' * 513, 'overwrite failure'):
            with self.assertRaises(ValueError): build.mark_failed(failed, key, 95, reason)
        for candidate, expected in [('foreign', 95), (key, 94), (key, True)]:
            with self.assertRaises(ValueError): build.mark_failed(self.data, candidate, expected, 'reason')
        with self.assertRaises(ValueError): build.reserve(failed, key, 95)
        with self.assertRaises(ValueError): build.metadata(ROOT, failed)
        replacement = build.reserve(failed, 'replacement-source', 95)
        self.assertEqual(replacement['allocations'][:-1], failed['allocations'])
        self.assertEqual(replacement['allocations'][-1]['ordinal'], 96)

    def test_failed_reason_is_required_and_cannot_attach_to_reserved(self):
        for change in ('missing', 'empty', 'reserved'):
            data = copy.deepcopy(self.data)
            if change == 'missing': data['allocations'][0].pop('failure_reason')
            elif change == 'empty': data['allocations'][0]['failure_reason'] = ''
            else: data['allocations'][-1]['failure_reason'] = 'not failed'
            with self.subTest(change=change), self.assertRaises(ValueError): build.validate(data)

    def test_cli_fail_then_reserve_next_preserves_history(self):
        with tempfile.TemporaryDirectory() as directory:
            root = self.fixture(directory)
            def cli(*args):
                with patch.object(build, 'ROOT', root), patch('sys.argv', ['build_iterations.py', *args]): build.main()
            key = self.data['allocations'][-1]['candidate']
            cli('--fail', key, '--expect-last', '95', '--reason', 'controlled fixture failure')
            failed = json.loads((root / build.LEDGER).read_text())
            self.assertEqual(failed['allocations'][-1]['status'], 'failed')
            with self.assertRaises(ValueError): cli('--check')
            cli('--reserve', 'replacement-source', '--expect-last', '95')
            cli('--sync', '--expect-last', '96')
            cli('--check')
            self.assertEqual(json.loads((root / build.LEDGER).read_text())['allocations'][:-1], failed['allocations'])

    def test_macos_default_name_and_actual_metadata_gate(self):
        spec = importlib.util.spec_from_file_location('null_choir_macos_version_test', ROOT / 'tools/build_macos.py')
        mac = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mac)
        self.assertEqual(mac.OUTPUT.name, 'Null-Choir-v0.097.zip')
        app = Path('/synthetic/Null Choir v0.097.app')
        info = {'CFBundleName': 'Null Choir v0.097', 'CFBundleIdentifier': 'com.ihearttokyo.nullchoir',
                'CFBundleDisplayName': 'Null Choir v0.097',
                'CFBundleShortVersionString': '0.097', 'CFBundleVersion': '97'}
        mac.check_build_identity(app, info)
        with self.assertRaises(ValueError): mac.check_build_identity(Path('/synthetic/Alpha4.app'), info)
        for key, value in (('CFBundleName', 'NULL CHOIR'), ('CFBundleDisplayName', 'Preview07'),
                           ('CFBundleIdentifier', 'com.foreign.nullchoir'),
                           ('CFBundleShortVersionString', '0.2.3'), ('CFBundleVersion', '0.096')):
            changed = {**info, key: value}
            with self.subTest(key=key), self.assertRaises(ValueError): mac.check_build_identity(app, changed)

    def test_builder_refuses_failed_last_before_any_native_work(self):
        failed = build.mark_failed(self.data, self.data['allocations'][-1]['candidate'], 95, 'test only')
        read = Path.read_text
        def altered(path, *args, **kwargs):
            return json.dumps(failed) if path == ROOT / build.LEDGER else read(path, *args, **kwargs)
        spec = importlib.util.spec_from_file_location('failed_macos_build_test', ROOT / 'tools/build_macos.py')
        mac = importlib.util.module_from_spec(spec)
        with patch.object(Path, 'read_text', altered), self.assertRaisesRegex(ValueError, 'Failed ordinal'):
            spec.loader.exec_module(mac)


class FreshExportNormalization(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('fresh_export_normalization_test', ROOT / 'tools/build_macos.py')
        cls.mac = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.mac)

    def fixture(self, root, identity=None, friendly=False):
        identity = identity or self.mac._build_identity
        app = root / (identity['app_name'] if friendly else 'NULL CHOIR.app')
        (app / 'Contents/MacOS').mkdir(parents=True)
        (app / 'Contents/Resources').mkdir()
        binary = app / 'Contents/MacOS/NULL CHOIR'
        binary.write_bytes(b'fixture executable bytes, not native code')
        binary.chmod(0o755)
        (app / 'Contents/Resources/NULL CHOIR.pck').write_bytes(b'unchanged fixture PCK bytes')
        info = {'CFBundleName': identity['display_name'] if friendly else 'NULL CHOIR',
                'CFBundleIdentifier': 'com.ihearttokyo.nullchoir', 'CFBundleExecutable': 'NULL CHOIR',
                'CFBundleShortVersionString': identity['version'], 'CFBundleVersion': identity['cfbundle_version']}
        if friendly: info['CFBundleDisplayName'] = identity['display_name']
        (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
        return app

    def temporary(self):
        tmp = tempfile.TemporaryDirectory(dir=str(Path(tempfile.gettempdir()).resolve()))
        self.addCleanup(tmp.cleanup)
        return Path(tmp.name)

    def test_raw_godot_name_normalizes_without_executable_or_pck_change(self):
        app = self.fixture(self.temporary())
        before = {p.relative_to(app): (p.read_bytes(), p.stat().st_ino) for p in app.rglob('*')
                  if p.is_file() and p.name != 'Info.plist'}
        normalized, info = self.mac.normalize_exported_app(app)
        self.assertFalse(app.exists())
        self.assertEqual(normalized.name, self.mac._build_identity['app_name'])
        self.mac.check_build_identity(normalized, info)
        self.assertEqual(info['CFBundleDisplayName'], self.mac._build_identity['display_name'])
        self.assertEqual(info['CFBundleExecutable'], 'NULL CHOIR')
        self.assertEqual(before, {p.relative_to(normalized): (p.read_bytes(), p.stat().st_ino)
                                 for p in normalized.rglob('*') if p.is_file() and p.name != 'Info.plist'})

    def test_exact_friendly_identity_is_byte_and_metadata_idempotent(self):
        app = self.fixture(self.temporary(), friendly=True)
        p = app / 'Contents/Info.plist'
        before = (p.read_bytes(), p.stat().st_ino, p.stat().st_mtime_ns)
        normalized, _ = self.mac.normalize_exported_app(app)
        self.assertEqual(normalized, app)
        self.assertEqual((p.read_bytes(), p.stat().st_ino, p.stat().st_mtime_ns), before)

    def test_direct_app_export_raw_plist_friendly_folder_never_renames(self):
        raw = self.fixture(self.temporary())
        app = raw.with_name(self.mac._build_identity['app_name'])
        raw.rename(app)  # Model Godot's explicit .app destination, raw pkg_name plist.
        payload = {p.relative_to(app): (p.read_bytes(), p.stat().st_ino) for p in app.rglob('*')
                   if p.is_file() and p.name != 'Info.plist'}
        with patch.object(self.mac, '_rename_no_replace', side_effect=AssertionError('must not rename')) as rename:
            normalized, info = self.mac.normalize_exported_app(app)
        rename.assert_not_called()
        self.assertEqual(normalized, app)
        self.mac.check_build_identity(app, info)
        self.assertEqual(payload, {p.relative_to(app): (p.read_bytes(), p.stat().st_ino)
                                  for p in app.rglob('*') if p.is_file() and p.name != 'Info.plist'})

    def test_foreign_stale_missing_metadata_refused_before_mutation(self):
        for key, value in [('CFBundleIdentifier', 'com.foreign.game'), ('CFBundleName', 'FOREIGN'),
                           ('CFBundleDisplayName', 'FOREIGN'), ('CFBundleShortVersionString', '0.094'),
                           ('CFBundleVersion', '96'), ('CFBundleVersion', '98'),
                           ('CFBundleExecutable', '../outside'), ('CFBundleExecutable', 'missing')]:
            with self.subTest(key=key, value=value):
                app = self.fixture(self.temporary())
                p = app / 'Contents/Info.plist'
                info = plistlib.loads(p.read_bytes()); info[key] = value
                p.write_bytes(plistlib.dumps(info)); before = p.read_bytes()
                with self.assertRaises(ValueError): self.mac.normalize_exported_app(app)
                self.assertEqual(p.read_bytes(), before)
                self.assertFalse(app.with_name(self.mac._build_identity['app_name']).exists())
        for key in ['CFBundleName', 'CFBundleIdentifier', 'CFBundleVersion', 'CFBundleShortVersionString', 'CFBundleExecutable']:
            app = self.fixture(self.temporary()); p = app / 'Contents/Info.plist'
            info = plistlib.loads(p.read_bytes()); info.pop(key); p.write_bytes(plistlib.dumps(info))
            with self.subTest(missing=key), self.assertRaises(ValueError): self.mac.normalize_exported_app(app)
            self.assertTrue(app.exists())

    def test_existing_and_raced_empty_target_are_never_overwritten(self):
        for raced in [False, True]:
            app = self.fixture(self.temporary()); target = app.with_name(self.mac._build_identity['app_name'])
            before = (app / 'Contents/Info.plist').read_bytes()
            rename = self.mac._rename_no_replace
            def collision(source, dest):
                target.mkdir()
                return rename(source, dest)
            if not raced: target.mkdir()
            with self.subTest(raced=raced), patch.object(self.mac, '_rename_no_replace', collision if raced else rename):
                with self.assertRaises(FileExistsError): self.mac.normalize_exported_app(app)
            self.assertTrue(app.exists()); self.assertTrue(target.is_dir())
            self.assertEqual(list(target.iterdir()), [])
            self.assertEqual((app / 'Contents/Info.plist').read_bytes(), before)

    def test_missing_symlink_or_empty_pck_refuses_before_any_mutation(self):
        for defect in ['missing', 'symlink', 'empty']:
            app = self.fixture(self.temporary()); pck = app / 'Contents/Resources/NULL CHOIR.pck'
            before = (app / 'Contents/Info.plist').read_bytes()
            if defect == 'empty': pck.write_bytes(b'')
            else:
                pck.unlink()
                if defect == 'symlink':
                    target = pck.with_name('owned-fixture-target.bin')
                    target.write_bytes(b'owned target, never touched')
                    pck.symlink_to(target)
            try:
                with self.subTest(defect=defect), self.assertRaises(ValueError): self.mac.normalize_exported_app(app)
                self.assertTrue(app.exists())
                self.assertEqual((app / 'Contents/Info.plist').read_bytes(), before)
                self.assertFalse(app.with_name(self.mac._build_identity['app_name']).exists())
                if defect == 'symlink': self.assertEqual(target.read_bytes(), b'owned target, never touched')
            finally:
                if pck.is_symlink(): pck.unlink()  # Exact own synthetic leaf; never its target.

    def test_failed_last_after_builder_import_refuses_before_patch(self):
        root = self.temporary(); app = self.fixture(root)
        ledger = json.loads((ROOT / build.LEDGER).read_text())
        failed = build.mark_failed(ledger, ledger['allocations'][-1]['candidate'], 97, 'fixture failure')
        (root / build.LEDGER).parent.mkdir(parents=True)
        (root / build.LEDGER).write_text(json.dumps(failed))
        before = (app / 'Contents/Info.plist').read_bytes()
        with patch.object(self.mac, 'ROOT', root), self.assertRaisesRegex(ValueError, 'Failed ordinal'):
            self.mac.normalize_exported_app(app)
        with patch.object(self.mac, 'ROOT', root), patch.object(self.mac, 'run') as engine:
            with self.assertRaisesRegex(ValueError, 'Failed ordinal'): self.mac.main(allow_window=True)
            engine.assert_not_called()
        self.assertEqual((app / 'Contents/Info.plist').read_bytes(), before)

    def test_plist_write_failure_restores_raw_folder_and_retains_payload(self):
        app = self.fixture(self.temporary()); before = (app / 'Contents/Info.plist').read_bytes()
        with patch.object(Path, 'replace', side_effect=OSError('controlled plist promotion failure')):
            with self.assertRaises(OSError): self.mac.normalize_exported_app(app)
        self.assertTrue(app.exists())
        self.assertEqual((app / 'Contents/Info.plist').read_bytes(), before)
        self.assertFalse(app.with_name(self.mac._build_identity['app_name']).exists())
        self.assertFalse(list((app / 'Contents').glob('Info.plist.*.tmp')))


if __name__ == '__main__':
    unittest.main()
