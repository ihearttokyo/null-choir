"""Reviewed marker bytes only: adopted default, --candidate-root PATH, or --unit."""
import argparse
import ast
import copy
import hashlib
import json
from pathlib import Path
import runpy
import shutil
import struct
import tempfile
import unittest
from unittest.mock import patch
import zlib

from test_art import png, resolve_recipe, validate_recipe
from test_marker_art import read_json, read_model, validate_model

ROOT = Path(__file__).resolve().parents[1]
RECIPE = 'tools/build_marker_identities.py'
producer = runpy.run_path(str(ROOT / RECIPE))  # Current pure module; never execute archives/Blender.
IDS = producer['IDS']
# Exact retained generation; archives are verified data, never imported.
RETAINED_GENERATIONS = {'a5eed30aeaf2aaf55eefb8cd006e27d6d88655600d25f564c6a9e8645b45ef64': {'tools/build_art.py': '285c99ece27a834e912e90f9c5d07ca4b2f8392a1045a1c089c7aa4fb5b8f581', 'tools/build_marker_art.py': '9151707aced076b1c0040b0417499c6a32a1eab6e88f273562488a2759c67c9c'}}

FAMILY = 'source/art/marker-identities-manifest.json'


# Review evidence remains separate from source headers and self-reported geometry metadata.
REVIEWED = {'marker_ivorykey': ['4d3e7facea51457a795e5f8ea12fe4b4ead410aba7ea00746facd92ac2326c60', 'c46f7d4ee5c4c90f5ed68fcfe9f39e85cb127b744757f7dcd1432acc8998ef62', 'c0505af96976869a7a1a2d1315b9092498b3c13a77a6ef9cfcfa18de7b3eb5ef', '3c3d3e1ab60238d9ae5d0686add4faf62f335cf434c842f14370da290104ef94'], 'marker_ammo_shells': ['14ea5b849ddafde95d4336928b9631d9c3d1a8e65768d1cdacf170dabc76bef8', '865745333429cd7d5242b96459cb5a94e8a6411a663e3461da7ec94b427b0ba8', '6bb7e495b412d399550c3f7efce43b7d626fc510190d9fc5fe7b0231a57c5131', '7e26d185a6fca81becce40efaf0da9f68bf63408d02f301916f4ca821b27d918'], 'marker_ammo_sawtooth': ['57fb1d60064b7fb9e87a3ae312037fae59021f1477847b9906532486e868f7dc', '85c4925e1b989a1f5ef7e7ea97b48413db521ee28fbc0987f2d8593738d58f9e', 'd178cc1e5250c71f0d8e2d10c29507386dc755ac4fc5fc8bfe4f2504cb182dda', 'd9eac9b38c70b52c981186790360db44cb13ae46610f84fd7298acd5656d7070'], 'marker_ammo_marrow': ['374a70deb50866ef974bf2adaaaef8008618c0a26d43f00123f6a553b9e04581', 'a041e1ecca0321e0391716774437aabdaa1ed91e1cb496e3818f62a82ab9ab5a', '8fc00a46f0d493f1895fb73e911a55e641f4857c1e2663b0f3e472dba6b0d532', '5fa171b3d86a980713150e9d92841526028abfafe32572419e00c8e5d49dc39d'], 'marker_ammo_choir': ['12eca21630f90ef8ff5a7af65f5f8571de2ed656718db3b6b4f504aa50a5c3db', 'e4fb459837c383857298374db83745993eb0aa018f5eb23766de3f00c319018f', '1fb1e9eefe646be4106ad0aa7ffe2d2d0394ec715763bd8309045a54b3486bd2', '0b161b0564d29eaf3f1e2e2a2cdbec6415a46a0025184e03a3501c1d917b7c7a']}
ENTRY_KEYS = set(['blender_version', 'collision', 'device', 'facing', 'id', 'loop_id', 'material_count', 'native_source_saved_before_runtime_merge', 'origin', 'outputs', 'physical_bounds_m', 'preview', 'provenance', 'recipe_dependencies', 'recipe_sha256', 'reference_images', 'reference_sha256', 'render_engine', 'runtime_mesh_nodes', 'samples', 'source', 'source_meshes', 'source_sha256', 'threads', 'triangles'])
UNIT_ROOT = ROOT


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def exact_file(root, relative):
    root = Path(root)
    assert root.is_absolute() and root.resolve() == root, 'canonical artifact root'
    path = root / relative
    assert path.resolve() == path and path.is_relative_to(root), 'aliased/escaped artifact'
    assert not any(p.is_symlink() for p in (path, *path.parents)), 'symlinked artifact'
    assert path.is_file(), 'missing artifact: ' + relative
    return path


def paths(name):
    assert name in IDS, 'unrecognized identity'
    return (f'source/art/{name}.blend', f'game/assets/art/world/{name}.glb',
            f'builds/marker-identities/{name}_preview.png', f'builds/marker-identities/{name}_geometry.json')


def validate_ids(entries):
    assert isinstance(entries, list) and all(isinstance(e, dict) and isinstance(e.get('id'), str) for e in entries), 'identity entries'
    ids = [e['id'] for e in entries]
    assert len(ids) == len(set(ids)) == 5 and set(ids) == set(IDS), 'closed five identities'


def validate_budget(source_bytes, sizes):
    assert 0 < source_bytes <= 8 * 1024 * 1024, 'family source budget'
    assert len(sizes) == 5 and all(type(n) is int and 0 < n <= producer['GLB_CAP'] for n in sizes), 'per-model GLB budget'


def validate_entry(entry, artifact_root=ROOT, provenance_root=ROOT):
    assert isinstance(entry, dict) and set(entry) == ENTRY_KEYS, 'identity entry fields'
    name = entry['id']
    source_rel, model_rel, preview_rel, receipt_rel = paths(name)
    assert entry['source'] == source_rel and len(entry['outputs']) == 1, 'closed source/output identity'
    output, preview = entry['outputs'][0], entry['preview']
    assert set(output) == {'path', 'sha256', 'bytes'} and output['path'] == model_rel, 'GLB path/fields'
    assert set(preview) == {'path', 'sha256', 'bytes', 'dimensions'} and preview['path'] == preview_rel, 'preview path/fields'
    assert entry['provenance'] == {'method': 'image-derived original Blender geometry', 'authoring_script': RECIPE,
                                  'imports': [], 'license': 'Original NULL CHOIR project art'}, 'provenance'
    generations = {**RETAINED_GENERATIONS, sha(ROOT / RECIPE): producer['HELPER_SHA']}
    assert entry['recipe_sha256'] in generations, 'trusted recipe generation'
    assert entry['recipe_dependencies'] == generations[entry['recipe_sha256']], 'helper inventory/pins'
    validate_recipe(provenance_root, entry, RECIPE, producer['HELPER_SHA'])
    assert entry['reference_images'] == [{'path': producer['REFERENCE'], 'sha256': producer['REFERENCE_SHA']}], 'reference inventory'
    assert entry['reference_sha256'] == producer['REFERENCE_SHA'] == sha(exact_file(provenance_root, producer['REFERENCE'])), 'reference pin'
    assert entry['origin'] == 'ground-centered at Blender (0,0,0); GLB Y up'
    assert entry['facing'] == 'front Blender -Y; exported Godot +Z'
    assert entry['collision'] == 'none; marker visuals only' and entry['loop_id'] is None, 'visual-only marker'
    assert entry['native_source_saved_before_runtime_merge'] is True, 'recorded source ordering'
    assert (entry['render_engine'], entry['device'], entry['threads'], entry['samples']) == ('CYCLES', 'CPU', 4, 16), 'recorded build'
    assert isinstance(entry['blender_version'], str) and entry['blender_version']
    source, model, image, receipt = [exact_file(artifact_root, p) for p in paths(name)]
    source_data = source.read_bytes()
    assert source_data[:7] == b'BLENDER' and sha(source) == entry['source_sha256'], 'source bytes/header'
    for file, metadata in ((model, output), (image, preview)):
        assert type(metadata['bytes']) is int and file.stat().st_size == metadata['bytes'] and sha(file) == metadata['sha256'], 'artifact hash/size'
    assert 0 < output['bytes'] <= producer['GLB_CAP'], 'per-model GLB budget'
    validate_model(*read_model(model.read_bytes()), entry)
    assert image.read_bytes()[-12:] == b'\x00\x00\x00\x00IEND\xaeB`\x82', 'PNG closure'
    size, pixels = png(image)
    assert size == (128, 128) and preview['dimensions'] == [128, 128], 'preview dimensions'
    alpha = pixels[3::4]
    assert set(alpha) == {0, 255} and 128 <= alpha.count(255) < 128 * 128 * .85, 'hard transparent/nonempty preview'
    assert not any(alpha[:128] + alpha[-128:] + alpha[::128] + alpha[127::128]), 'preview clipping'
    parts = entry['source_meshes']
    assert isinstance(parts, list) and len(parts) >= 4 and len({p['name'] for p in parts}) == len(parts), 'named source parts'
    assert all(set(p) == {'name', 'vertices', 'triangles'} and isinstance(p['name'], str) and p['name'] and
               type(p['vertices']) is int and p['vertices'] > 0 and type(p['triangles']) is int and p['triangles'] > 0 for p in parts), 'source part metadata'
    assert sum(p['triangles'] for p in parts) == entry['triangles'], 'source triangle parity'
    assert read_json(receipt) == entry, 'receipt exact entry parity'
    assert [sha(p) for p in (source, model, image, receipt)] == REVIEWED[name], 'reviewed native byte pins; rehash is not adoption'
    return {'source_bytes': len(source_data), 'GLB_bytes': output['bytes'], 'triangles': entry['triangles']}


def candidate_entries(root):
    for directory, pattern, expected in (
            ('source/art', '*.blend', [paths(n)[0] for n in IDS]),
            ('game/assets/art/world', '*.glb', [paths(n)[1] for n in IDS]),
            ('builds/marker-identities', '*_preview.png', [paths(n)[2] for n in IDS]),
            ('builds/marker-identities', '*_geometry.json', [paths(n)[3] for n in IDS])):
        found = {str(p.relative_to(root)) for p in (Path(root) / directory).glob(pattern)}
        assert found == set(expected), 'closed candidate file inventory'
    return [read_json(exact_file(root, paths(n)[3])) for n in IDS]


def check(root=ROOT, candidate=False):
    root = Path(root)
    if candidate:
        entries = candidate_entries(root)
    else:
        family = read_json(exact_file(root, FAMILY))
        assert set(family) == {'schema_version', 'assets'} and type(family['schema_version']) is int and family['schema_version'] == 1, 'family schema'
        entries = family['assets']
        main = read_json(exact_file(root, 'source/art/manifest.json'))['assets']
        ids = [e['id'] for e in main]
        assert len(set(ids)) == len(ids), 'main duplicate IDs'
        assert [e for e in main if e['id'] in IDS] == entries, 'main/family exact entry parity'
    validate_ids(entries)
    results = [validate_entry(e, root, ROOT if candidate else root) for e in entries]
    validate_budget(sum(r['source_bytes'] for r in results), [r['GLB_bytes'] for r in results])
    return {'assets': len(entries), 'GLB_bytes': sum(r['GLB_bytes'] for r in results), 'source_bytes': sum(r['source_bytes'] for r in results)}


class ArtifactFixtures(unittest.TestCase):
    def test_main_art_propagates_complete_family_refusal(self):
        import test_art
        import test_marker_identity_artifact
        with patch.object(test_marker_identity_artifact, 'check', side_effect=AssertionError('identity family refusal')):
            with self.assertRaisesRegex(AssertionError, 'identity family refusal'):
                test_art.check()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.entries = (read_json(exact_file(UNIT_ROOT, FAMILY))['assets']
                        if (UNIT_ROOT / FAMILY).is_file() else candidate_entries(UNIT_ROOT))
        validate_ids(self.entries)
        for entry in self.entries:
            for relative in paths(entry['id']):
                target = self.root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(exact_file(UNIT_ROOT, relative), target)
        self.entry = self.entries[0]
        nodes = [n for n in ast.parse((ROOT / 'tools/build_art.py').read_text()).body
                 if isinstance(n, ast.FunctionDef) and n.name == 'png']
        namespace = {'struct': struct, 'zlib': zlib, 'target': lambda p: p}
        exec(compile(ast.Module(body=nodes, type_ignores=[]), '<current PNG writer>', 'exec'), namespace)
        self.write_png = namespace['png']

    def validate(self, entry=None):
        return validate_entry(entry or self.entry, self.root, ROOT)

    def refresh(self):
        entry = self.entry
        entry['source_sha256'] = sha(self.root / entry['source'])
        for metadata in (entry['outputs'][0], entry['preview']):
            path = self.root / metadata['path']
            metadata.update(sha256=sha(path), bytes=path.stat().st_size)
        (self.root / paths(entry['id'])[3]).write_text(json.dumps(entry))

    def write_model(self, gltf, binary):
        document = json.dumps(gltf, separators=(',', ':')).encode()
        document += b' ' * (-len(document) % 4)
        binary += b'\0' * (-len(binary) % 4)
        data = (struct.pack('<4sII', b'glTF', 2, 28 + len(document) + len(binary)) +
                struct.pack('<I4s', len(document), b'JSON') + document +
                struct.pack('<I4s', len(binary), b'BIN\0') + binary)
        (self.root / self.entry['outputs'][0]['path']).write_bytes(data)
        self.refresh()

    def test_actual_reviewed_candidate_bytes(self):
        self.assertEqual(check(self.root, candidate=True)['GLB_bytes'], 153328)

    def test_manifest_proposal_and_main_parity(self):
        for relative in (RECIPE, *producer['HELPER_SHA'], producer['REFERENCE']):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(exact_file(ROOT, relative), target)
        for entry in self.entries:
            for logical, digest in {RECIPE: entry['recipe_sha256'], **entry['recipe_dependencies']}.items():
                source = resolve_recipe(ROOT, logical, digest)
                target = self.root / source.relative_to(ROOT)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
        family = {'schema_version': 1, 'assets': self.entries}
        (self.root / FAMILY).write_text(json.dumps(family))
        main_path = self.root / 'source/art/manifest.json'
        main = {'assets': [{'id': 'unrelated'}] + self.entries}
        main_path.write_text(json.dumps(main))
        self.assertEqual(check(self.root)['assets'], 5)
        main['assets'][-1] = dict(self.entries[-1], triangles=1)
        main_path.write_text(json.dumps(main))
        with self.assertRaisesRegex(AssertionError, 'main/family'):
            check(self.root)

    def test_identity_lineage_and_receipt_mutations(self):
        for field, value in (('id', 'marker_key'), ('source', '../escape.blend'), ('outputs', []),
                              ('recipe_sha256', '0' * 64), ('recipe_dependencies', {}),
                              ('reference_images', []), ('reference_sha256', '0' * 64),
                              ('collision', 'enabled'), ('native_source_saved_before_runtime_merge', False)):
            entry = copy.deepcopy(self.entry)
            entry[field] = value
            with self.subTest(field=field), self.assertRaises((AssertionError, ValueError)):
                self.validate(entry)
        path = self.root / paths(self.entry['id'])[3]
        path.write_text(json.dumps(dict(self.entry, samples=32)))
        with self.assertRaisesRegex(AssertionError, 'receipt exact'):
            self.validate()

    def test_missing_unknown_partial_and_symlink_files(self):
        model = self.root / self.entry['outputs'][0]['path']
        saved = model.read_bytes()
        model.unlink()
        with self.assertRaises(AssertionError):
            check(self.root, candidate=True)
        model.write_bytes(saved)
        unknown = model.with_name('marker_unknown.glb')
        unknown.write_bytes(saved)
        with self.assertRaises(AssertionError):
            check(self.root, candidate=True)
        unknown.unlink()
        model.unlink()
        model.symlink_to(exact_file(UNIT_ROOT, self.entry['outputs'][0]['path']))
        with self.assertRaisesRegex(AssertionError, 'aliased'):
            self.validate()
        with self.assertRaises(AssertionError):
            exact_file(Path('relative'), self.entry['source'])
        alias = self.root / 'root-alias'
        alias.symlink_to(self.root, target_is_directory=True)
        with self.assertRaisesRegex(AssertionError, 'canonical'):
            exact_file(alias, self.entry['source'])

    def test_corrupt_and_rehashed_source_bytes(self):
        source = self.root / self.entry['source']
        source.write_bytes(b'BLENDER' + b'fake editable source')
        self.refresh()
        with self.assertRaisesRegex(AssertionError, 'reviewed native byte pins'):
            self.validate()
        source.write_bytes(b'not a blend')
        self.refresh()
        with self.assertRaisesRegex(AssertionError, 'source bytes/header'):
            self.validate()

    def test_rehashed_glb_semantic_mutations(self):
        path = self.root / self.entry['outputs'][0]['path']
        original = path.read_bytes()
        for mode in ('camera', 'uri', 'collider', 'bounds', 'indices'):
            gltf, binary = read_model(original)
            if mode == 'camera':
                gltf['cameras'] = [{}]
            elif mode == 'uri':
                gltf['buffers'][0]['uri'] = 'external.bin'
            elif mode == 'collider':
                gltf['nodes'][0]['name'] = 'mesh-convcol'
            else:
                primitive = gltf['meshes'][0]['primitives'][0]
                index = primitive['attributes']['POSITION'] if mode == 'bounds' else primitive['indices']
                accessor = gltf['accessors'][index]
                view = gltf['bufferViews'][accessor['bufferView']]
                offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
                binary = bytearray(binary)
                fmt, value = ('f', 999.0) if mode == 'bounds' else ('H' if accessor['componentType'] == 5123 else 'I', 65535)
                struct.pack_into('<' + fmt, binary, offset, value)
                binary = bytes(binary)
            self.write_model(gltf, binary)
            with self.subTest(mode=mode), self.assertRaises(AssertionError):
                self.validate()
        path.write_bytes(b'corrupt GLB')
        self.refresh()
        with self.assertRaisesRegex(AssertionError, 'truncated GLB'):
            self.validate()

    def test_valid_rehashed_glb_still_requires_review(self):
        path = self.root / self.entry['outputs'][0]['path']
        gltf, binary = read_model(path.read_bytes())
        gltf['asset']['generator'] = 'unreviewed but otherwise valid bytes'
        self.write_model(gltf, binary)
        with self.assertRaisesRegex(AssertionError, 'reviewed native byte pins'):
            self.validate()

    def test_preview_alpha_border_dimensions_and_corruption(self):
        path = self.root / self.entry['preview']['path']
        size, original = png(path)
        for mode in ('alpha', 'border', 'empty', 'dimensions'):
            pixels = bytearray(original)
            if mode == 'alpha':
                pixels[3] = 128
            elif mode == 'border':
                pixels[3] = 255
            elif mode == 'empty':
                pixels = bytearray(128 * 128 * 4)
            self.write_png(path, *size, pixels)
            self.refresh()
            if mode == 'dimensions':
                self.entry['preview']['dimensions'] = [64, 128]
            with self.subTest(mode=mode), self.assertRaises(AssertionError):
                self.validate()
        path.write_bytes(b'corrupt PNG')
        self.refresh()
        with self.assertRaisesRegex(AssertionError, 'PNG closure'):
            self.validate()

    def test_duplicate_and_partial_receipt_json(self):
        receipt = self.root / paths(self.entry['id'])[3]
        for content in ('{', '{"id":"duplicate",' + json.dumps(self.entry)[1:]):
            receipt.write_text(content)
            with self.assertRaises(AssertionError):
                self.validate()

    def test_budget_boundaries(self):
        validate_budget(8 * 1024 * 1024, [150000] * 5)
        for source, sizes in ((0, [1] * 5), (8 * 1024 * 1024 + 1, [1] * 5),
                              (1, [150001] * 5), (1, [1] * 4)):
            with self.assertRaises(AssertionError):
                validate_budget(source, sizes)

    def test_exact_closed_identity_set(self):
        with self.assertRaises(AssertionError):
            validate_ids([])
        with self.assertRaises(AssertionError):
            validate_ids([{'id': name} for name in IDS] + [{'id': 'marker_key'}])
        with self.assertRaises(AssertionError):
            validate_ids([{'id': name} for name in IDS[:-1]] + [{'id': IDS[0]}])
        validate_ids([{'id': name} for name in IDS])


def main():
    global UNIT_ROOT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--unit', action='store_true')
    parser.add_argument('--candidate-root', type=Path)
    opts = parser.parse_args()
    if opts.unit:
        UNIT_ROOT = opts.candidate_root or ROOT
        unittest.main(argv=[__file__], verbosity=2)
    else:
        result = check(opts.candidate_root or ROOT, candidate=opts.candidate_root is not None)
        print('PASS reviewed marker artifact bytes/lineage/inventory:', result, '; not native geometry or visual acceptance')


if __name__ == '__main__':
    main()
