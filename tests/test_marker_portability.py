"""Engine-free metadata/accounting fixtures; never native art evidence."""
import copy
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import test_marker_art as marker

P = Path(__file__).resolve().parents[1]
HELPERS = dict(marker.HELPER_SHA)


@contextmanager
def metadata_root(legacy=False):
    # Tiny source/metadata only. No bpy import, GLB, blend or production image fixture.
    with tempfile.TemporaryDirectory(prefix='.portable-fixture-', dir=P) as temporary:
        root = Path(temporary)
        for rel in HELPERS:
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((P / rel).read_bytes())
            archive = root / 'source/art/recipe_history' / HELPERS[rel] / (rel + '.txt')
            original = P / archive.relative_to(root)
            assert marker.sha(original) == HELPERS[rel], 'exact retained fixture bytes required'
            archive.parent.mkdir(parents=True, exist_ok=True)
            archive.write_bytes(original.read_bytes())
        reference = root / marker.REFERENCE
        reference.parent.mkdir(parents=True, exist_ok=True)
        reference.write_bytes(b'unit metadata reference; not image/art evidence')
        digest = marker.sha(reference)
        (root / marker.RECIPE).write_text('# metadata-only recipe fixture; never imported\n')
        inputs = {'schema_version': 1, 'helper_sha256': HELPERS,
                  'reference': {'path': marker.REFERENCE, 'sha256': digest,
                                'inspection': {'inspected_actual_pixels': True,
                                               'observations': ['Unit metadata attestation only.']}}}
        input_path = root / 'source/art/marker-inputs.json'
        input_path.write_text(json.dumps(inputs))
        (root / 'source/art/marker-manifest.json').write_text(json.dumps({'schema_version': 1, 'assets': []}))
        if legacy:
            (root / 'HELPER-SOURCE.json').write_text(json.dumps({'unchanged_source_helpers': HELPERS}))
            (root / 'IMAGE-INSPECTION.json').write_text(json.dumps({'inspected_actual_pixels': True, 'sha256': digest}))
        with patch.object(marker, 'ROOT', root), patch.object(marker, 'IDS', ()), patch.object(marker, 'REFERENCE_SHA', digest):
            # Empty family isolates check's deterministic metadata/budget seam, not native acceptance.
            yield root, inputs, input_path


class PortabilityFixtures(unittest.TestCase):
    def test_current_helper_drift_uses_exact_archived_original(self):
        with metadata_root() as (root, _, _):
            self.assertTrue(all(marker.sha(root / rel) != pin for rel, pin in HELPERS.items()))
            self.assertIsNone(marker.check())
            # Validation may read history; the unchanged producer may not author with drift.
            with self.assertRaisesRegex(AssertionError, 'authoring helper drift'):
                marker.load_inputs()

    def test_exact_live_inputs_keep_historical_authoring_compatible(self):
        with metadata_root() as (root, _, _):
            for rel, digest in HELPERS.items():
                archive = root / 'source/art/recipe_history' / digest / (rel + '.txt')
                (root / rel).write_bytes(archive.read_bytes())
                archive.unlink()
            self.assertIsNone(marker.load_inputs())
            self.assertIsNone(marker.check())

    def test_missing_family_cannot_pass_main_acceptance(self):
        with metadata_root(), patch.object(marker, 'IDS', ('marker_ammo', 'marker_exit')):
            with self.assertRaisesRegex(AssertionError, 'all eight marker outputs required'):
                marker.validate_main_entries([])

    def test_missing_bad_and_misplaced_archives_are_rejected(self):
        for rel in HELPERS:
            for state in ('missing', 'bad', 'misplaced'):
                with self.subTest(helper=rel, state=state), metadata_root() as (root, _, _):
                    archive = root / 'source/art/recipe_history' / HELPERS[rel] / (rel + '.txt')
                    if state == 'bad':
                        archive.write_bytes(b'wrong historical bytes')
                    elif state == 'misplaced':
                        archive.rename(archive.with_name(archive.name + '.other'))
                    else:
                        archive.unlink()
                    with self.assertRaises(AssertionError):
                        marker.check()

    def test_archive_aliases_and_conflicting_archive_rejected(self):
        for rel in HELPERS:
            for state in ('file-link', 'directory-link', 'conflict-with-current'):
                with self.subTest(helper=rel, state=state), metadata_root() as (root, _, _):
                    archive = root / 'source/art/recipe_history' / HELPERS[rel] / (rel + '.txt')
                    target = root / 'alias.txt'
                    target.write_bytes(archive.read_bytes())
                    if state == 'file-link':
                        archive.unlink()
                        archive.symlink_to(target)
                    elif state == 'directory-link':
                        archive.unlink()
                        archive.parent.rmdir()
                        archive.parent.symlink_to(root, target_is_directory=True)
                    else:
                        (root / rel).write_bytes(archive.read_bytes())
                        archive.write_bytes(b'conflicting archive, despite exact current bytes')
                    with self.assertRaises(AssertionError):
                        marker.check()

    def test_archived_validation_input_is_data_not_executable(self):
        import test_art as art
        with self.assertRaises(ValueError):
            art.resolve_recipe(P, 'tests/test_art.py', HELPERS['tests/test_art.py'])
        with metadata_root() as (root, _, _), patch('builtins.exec', side_effect=AssertionError('archive executed')):
            self.assertIsNone(marker.check())

    def test_main_discovery_keeps_original_103_and_eight_markers(self):
        import test_art as art
        self.assertTrue(set(marker.IDS) <= art.EXPECTED)
        original = art.EXPECTED - {'marker_glyphs'} - art.MARKER_IDENTITIES
        self.assertEqual(len(original - set(marker.IDS)), 103)
        self.assertEqual(len(original), 111)
        self.assertEqual(len(art.EXPECTED), 117)

    def test_main_manifest_requires_exact_complete_family_metadata(self):
        # Parity seam only: mock the actual-file check, never claim synthetic art passes it.
        entries = [{'id': name, 'source_sha256': 'fixture metadata only'} for name in marker.IDS]
        with patch.object(marker, 'check') as actual_check, patch.object(marker, 'load_manifest', return_value={'assets': entries}):
            self.assertIsNone(marker.validate_main_entries(entries + [{'id': 'skin_bell'}]))
            actual_check.assert_called_once_with()
            changed = copy.deepcopy(entries)
            changed[0]['source_sha256'] = 'repinned'
            for broken in (entries[:-1], entries + [entries[0]], changed):
                with self.subTest(entries=broken), self.assertRaisesRegex(AssertionError, 'main/marker manifest parity'):
                    marker.validate_main_entries(broken)
        with patch.object(marker, 'check', side_effect=AssertionError('actual family rejected')):
            with self.assertRaisesRegex(AssertionError, 'actual family rejected'):
                marker.validate_main_entries(entries)

    def test_repository_inputs_do_not_need_private_audits(self):
        with metadata_root() as (root, _, _):
            self.assertFalse((root / 'HELPER-SOURCE.json').exists())
            self.assertFalse((root / 'IMAGE-INSPECTION.json').exists())
            self.assertIsNone(marker.check())

    def test_unrelated_project_bytes_do_not_consume_family_budget(self):
        with metadata_root(legacy=True) as (root, _, _):
            owned_bytes = sum(p.stat().st_size for p in root.rglob('*') if p.is_file() and p.name not in ('HELPER-SOURCE.json', 'IMAGE-INSPECTION.json'))
            unrelated = root / 'game/assets/unrelated.dat'
            unrelated.parent.mkdir(parents=True)
            unrelated.write_bytes(b'x' * 2048)
            with patch.object(marker, 'PHASE_CAP', owned_bytes + 1024):
                self.assertIsNone(marker.check())

    def test_unrelated_logs_do_not_consume_marker_log_budget(self):
        with metadata_root(legacy=True) as (root, _, _):
            (root / 'unrelated.log').write_bytes(b'x' * 101)
            with patch.object(marker, 'LOG_CAP', 100):
                self.assertIsNone(marker.check())


    def test_malformed_duplicate_and_provenance_inputs(self):
        edits = [lambda d: d.update(schema_version=True),
                 lambda d: d.update(schema_version=2),
                 lambda d: d.update(unexpected='private audit path'),
                 lambda d: d.update(helper_sha256={}),
                 lambda d: d['helper_sha256'].update({'tools/build_art.py': '0' * 64}),
                 lambda d: d['helper_sha256'].update({'../outside.py': '0' * 64}),
                 lambda d: d['reference'].update(path='../outside.png'),
                 lambda d: d['reference'].update(sha256='0' * 64),
                 lambda d: d['reference']['inspection'].update(inspected_actual_pixels=False),
                 lambda d: d['reference']['inspection'].update(observations=[]),
                 lambda d: d['reference']['inspection'].update(observations=['']),
                 lambda d: d['reference']['inspection'].update(observations='a path is not inspection')]
        with metadata_root(legacy=True) as (_, inputs, path):
            for number, edit in enumerate(edits):
                broken = copy.deepcopy(inputs)
                edit(broken)
                path.write_text(json.dumps(broken))
                with self.subTest(case=number), self.assertRaises(AssertionError):
                    marker.check()
            for raw in ('{', '[]', json.dumps(inputs).replace('"schema_version": 1', '"schema_version": 1, "schema_version": 1'),
                        json.dumps(inputs).replace('"helper_sha256":', '"helper_sha256": {}, "helper_sha256":')):
                path.write_text(raw)
                with self.subTest(raw=raw[:60]), self.assertRaises(AssertionError):
                    marker.check()

    def test_duplicate_and_malformed_manifest_metadata(self):
        with metadata_root(legacy=True) as (root, _, _):
            path = root / 'source/art/marker-manifest.json'
            for raw in ('{"schema_version": 1, "schema_version": 1, "assets": []}',
                        '{"schema_version": true, "assets": []}',
                        '{"schema_version": 1, "assets": [], "extra": "audit"}',
                        '{"schema_version": 1, "assets": {}}'):
                path.write_text(raw)
                with self.subTest(raw=raw), self.assertRaises(AssertionError):
                    marker.check()
        # Actual ID allowlist/duplicate boundary, no fake output fixture needed.
        with metadata_root(legacy=True) as (root, _, _), patch.object(marker, 'IDS', ('marker_ammo',)):
            path = root / 'source/art/marker-manifest.json'
            for assets in ([{'id': 'marker_ammo'}, {'id': 'marker_ammo'}], [{'id': '../outside'}]):
                path.write_text(json.dumps({'schema_version': 1, 'assets': assets}))
                with self.subTest(assets=assets), self.assertRaises(AssertionError):
                    marker.check('marker_ammo')

    def test_inward_and_outward_aliases_are_rejected(self):
        for relative in ('source/art/marker-inputs.json', marker.REFERENCE, 'tools/build_art.py'):
            for outward in (False, True):
                with self.subTest(path=relative, outward=outward), metadata_root(legacy=True) as (root, _, _):
                    original = root / relative
                    alias_target = (root.parent if outward else root) / (root.name + '-alias-target')
                    # Outward target still within P; cleanup only this tiny fixture file.
                    alias_target.write_bytes(original.read_bytes())
                    try:
                        original.unlink()
                        original.symlink_to(alias_target)
                        with self.assertRaises(AssertionError):
                            marker.check()
                        with self.assertRaises(AssertionError):
                            marker.owned_file(relative, relative)
                    finally:
                        alias_target.unlink()

    def test_owned_logs_and_sources_still_enforce_caps(self):
        with metadata_root(legacy=True) as (root, _, _):
            log = root / 'builds/marker-art/marker_ammo.log'
            log.parent.mkdir(parents=True)
            log.write_bytes(b'x' * 101)
            with patch.object(marker, 'LOG_CAP', 100), self.assertRaisesRegex(AssertionError, 'log budget'):
                marker.check()
            with patch.object(marker, 'PHASE_CAP', 1), self.assertRaisesRegex(AssertionError, 'phase budget'):
                marker.check()


    def test_existing_manifest_lineage_is_checked_before_build(self):
        # Metadata only; there are deliberately no claimed native file hashes or native files.
        with metadata_root() as (root, inputs, _), patch.object(marker, 'IDS', ('marker_ammo',)):
            entry = {'id': 'marker_ammo', 'source': 'source/art/marker_ammo.blend',
                     'recipe_sha256': marker.sha(root / marker.RECIPE),
                     'recipe_dependencies': {'tools/build_art.py': HELPERS['tools/build_art.py']},
                     'reference_images': [{'path': marker.REFERENCE, 'sha256': inputs['reference']['sha256']}],
                     'provenance': {'method': 'image-derived original Blender geometry',
                                    'authoring_script': marker.RECIPE, 'imports': [],
                                    'license': 'Original NULL CHOIR project art'},
                     'origin': 'ground-centered at Blender (0,0,0); GLB Y up',
                     'facing': 'front Blender -Y; exported Godot +Z',
                     'collision': 'none; marker visuals only', 'loop_id': None,
                     'outputs': [{'path': 'game/assets/art/world/marker_ammo.glb'}],
                     'preview': {'path': 'builds/marker-art/marker_ammo_preview.png'},
                     'geometry_receipt': 'builds/marker-art/marker_ammo_geometry.json'}
            path = root / 'source/art/marker-manifest.json'
            path.write_text(json.dumps({'schema_version': 1, 'assets': [entry]}))
            self.assertEqual(marker.load_manifest()['assets'], [entry])
            edits = [lambda d: d.update(recipe_sha256='0' * 64),
                     lambda d: d.update(recipe_dependencies={}),
                     lambda d: d['reference_images'][0].update(sha256='0' * 64),
                     lambda d: d['provenance'].update(imports=['private/source.blend']),
                     lambda d: d['provenance'].update(authoring_script='../outside.py'),
                     lambda d: d.update(source='../outside.blend'),
                     lambda d: d['outputs'][0].update(path='../outside.glb'),
                     lambda d: d['outputs'].append(d['outputs'][0]),
                     lambda d: d['preview'].update(path='../outside.png'),
                     lambda d: d.update(geometry_receipt='../outside.json')]
            for number, edit in enumerate(edits):
                broken = copy.deepcopy(entry)
                edit(broken)
                path.write_text(json.dumps({'schema_version': 1, 'assets': [broken]}))
                with self.subTest(case=number), self.assertRaises(AssertionError):
                    marker.load_manifest()


if __name__ == '__main__':
    unittest.main(verbosity=2)
