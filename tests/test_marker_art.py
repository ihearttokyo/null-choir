"""Marker artifact contract (default) or engine-free fixtures (--unit)."""
import argparse
import ast
import copy
import hashlib
import json
import math
from pathlib import Path
import struct
import tempfile
from types import SimpleNamespace
import unittest

from test_art import png, world_geometry

ROOT = Path(__file__).resolve().parents[1]
IDS = tuple('marker_' + kind for kind in
            ('ammo', 'health', 'armor', 'key', 'weapon', 'story', 'checkpoint', 'exit'))
CAP = (0.9, 1.2, 0.9)  # GLB Y up, metres.
RECIPE = 'tools/build_marker_art.py'
REFERENCE = 'source/art/references/marker-system-01.png'
REFERENCE_SHA = '59c2b0db1374acfc9ab75b6978ad14df2d965c3eedd86fe8d8227db4e0895a42'
GLB_CAP, PHASE_CAP, LOG_CAP = 2_000_000, 64_000_000, 20_000_000
INPUTS = 'source/art/marker-inputs.json'
MANIFEST = 'source/art/marker-manifest.json'
HELPER_SHA = {'tools/build_art.py': '25c9dca4239b0de3929baaa53a4efee7ee7fbedfe0d0085bf6f1d30b158c2d95',
              'tests/test_art.py': '8822098e8dc522536c594ed96784be6ef1b2ed5a3936aa2f727ab79b001c2d2f'}
# Closed family scope, including partial outputs/raw frames and the parent's per-asset logs.
# Parent/coordinator resource guards still own transient peak, stdout, free space and deadlines.
FAMILY_FILES = (RECIPE, 'tests/test_marker_art.py', 'tests/test_marker_portability.py', *HELPER_SHA, REFERENCE, INPUTS, MANIFEST) + tuple(
    relative for name in IDS for relative in
    (f'source/art/{name}.blend', f'game/assets/art/world/{name}.glb',
     f'builds/marker-art/{name}_preview.png', f'builds/marker-art/{name}_geometry.json',
     f'builds/marker-art/frames/{name}.png', f'builds/marker-art/{name}.log'))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_model(data):
    # Container framing matches test_art.check; world_geometry owns vertex decoding.
    assert len(data) >= 28, 'truncated GLB'
    magic, version, length = struct.unpack_from('<4sII', data)
    assert (magic, version, length) == (b'glTF', 2, len(data)), 'GLB header'
    n, kind = struct.unpack_from('<I4s', data, 12)
    assert kind == b'JSON' and n % 4 == 0 and 20 + n + 8 <= len(data), 'JSON chunk'
    try:
        gltf = json.loads(data[20:20 + n])
    except (ValueError, UnicodeError) as error:
        raise AssertionError('GLB JSON') from error
    count, kind = struct.unpack_from('<I4s', data, 20 + n)
    assert kind == b'BIN\0' and count % 4 == 0 and 28 + n + count == len(data), 'BIN chunk'
    return gltf, data[28 + n:]


def validate_model(gltf, binary, entry):
    assert gltf['asset']['version'] == '2.0'
    assert not any(gltf.get(k) for k in ('cameras', 'animations', 'skins', 'extensions')), 'non-mesh content'
    assert set(gltf.get('extensionsUsed', [])) <= {'KHR_materials_emissive_strength'}, 'export extensions'
    assert set(gltf.get('extensionsRequired', [])) <= {'KHR_materials_emissive_strength'}
    assert len(gltf['buffers']) == 1 and 'uri' not in gltf['buffers'][0], 'external buffer'
    length = gltf['buffers'][0]['byteLength']
    assert length <= len(binary) <= length + 3, 'buffer length'
    for view in gltf['bufferViews']:
        assert view.get('buffer', 0) == 0 and view.get('byteOffset', 0) >= 0
        assert view['byteLength'] > 0 and view.get('byteOffset', 0) + view['byteLength'] <= length, 'buffer view'
    for image in gltf.get('images', []):
        assert 'uri' not in image and 0 <= image['bufferView'] < len(gltf['bufferViews']), 'external image'
    nodes, meshes = gltf['nodes'], gltf['meshes']
    assert 0 < len(nodes) <= 8 and 0 < len(gltf['materials']) <= 8, 'material budget'
    assert len(meshes) == len(nodes) and sorted(n['mesh'] for n in nodes if 'mesh' in n) == list(range(len(meshes)))
    assert len(gltf['scenes']) == 1 and set(gltf['scenes'][0]) <= {'name', 'nodes'}
    assert sorted(gltf['scenes'][0]['nodes']) == list(range(len(nodes)))
    assert gltf.get('scene', 0) == 0
    for node in nodes:
        assert set(node) <= {'name', 'mesh'}, 'node script, transform or non-mesh content'
        name = node.get('name', '').lower()
        assert not any(word in name for word in ('collider', 'collision', 'script', 'camera', 'light'))
        assert not name.endswith(('-col', '-convcol', '-colonly', '-convcolonly', '-navmesh')), 'collider import suffix'
    for mesh in meshes:
        assert set(mesh) <= {'name', 'primitives'}, 'mesh extras/extensions'
        assert len(mesh['primitives']) == 1, 'merge by material'
        primitive = mesh['primitives'][0]
        assert set(primitive) <= {'attributes', 'indices', 'material', 'mode'}, 'primitive extras/extensions'
        assert primitive.get('mode', 4) == 4 and not primitive.get('targets'), 'triangle primitive'
        assert 0 <= primitive['material'] < len(gltf['materials'])
        attributes = primitive['attributes']
        components_by_attribute = {'POSITION': 3, 'NORMAL': 3, 'TEXCOORD_0': 2}
        assert 'POSITION' in attributes and set(attributes) <= set(components_by_attribute), 'unsupported attribute'
        layouts = [(key, components_by_attribute[key], {5126}) for key in attributes]
        layouts.append(('indices', 1, {5123, 5125}))
        attribute_counts = set()
        for key, components, types in layouts:
            index = primitive[key] if key == 'indices' else attributes[key]
            assert type(index) is int and 0 <= index < len(gltf['accessors']), 'accessor index'
            accessor = gltf['accessors'][index]
            assert 'sparse' not in accessor and accessor['componentType'] in types
            assert accessor['type'] == ('SCALAR' if key == 'indices' else f'VEC{components}')
            assert type(accessor['count']) is int and accessor['count'] > 0
            if key != 'indices':
                assert not accessor.get('normalized', False), 'float attribute normalization'
                attribute_counts.add(accessor['count'])
            assert type(accessor['bufferView']) is int and 0 <= accessor['bufferView'] < len(gltf['bufferViews']), 'buffer view index'
            view = gltf['bufferViews'][accessor['bufferView']]
            unit = 2 if accessor['componentType'] == 5123 else 4
            size = components * unit
            stride = view.get('byteStride', size)
            offset = accessor.get('byteOffset', 0)
            assert type(offset) is int and offset >= 0 and offset % unit == 0
            assert view.get('byteOffset', 0) % unit == 0, 'accessor alignment'
            assert type(stride) is int and stride >= size and stride % unit == 0
            if key != 'indices' and 'byteStride' in view:
                assert stride <= 252, 'attribute stride'
            assert offset + (accessor['count'] - 1) * stride + size <= view['byteLength'], 'accessor range'
        assert len(attribute_counts) == 1, 'vertex attribute count mismatch'
        indices = gltf['accessors'][primitive['indices']]
        assert indices['count'] % 3 == 0, 'triangle indices'
        view = gltf['bufferViews'][indices['bufferView']]
        offset = view.get('byteOffset', 0) + indices.get('byteOffset', 0)
        code = 'H' if indices['componentType'] == 5123 else 'I'
        stride = view.get('byteStride', struct.calcsize('<' + code))
        vertex_count = gltf['accessors'][primitive['attributes']['POSITION']]['count']
        assert all(struct.unpack_from('<' + code, binary, offset + i * stride)[0] < vertex_count
                   for i in range(indices['count'])), 'invalid vertex index'
    points, triangles = world_geometry(gltf, binary)
    assert points and all(math.isfinite(v) for p in points for v in p), 'non-finite positions'
    assert 0 < triangles <= 2500, 'triangle budget'
    lo, hi = [min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)]
    size = [hi[i] - lo[i] for i in range(3)]
    assert all(0 < v <= cap + 1e-6 for v, cap in zip(size, CAP)), 'bounds budget'
    assert abs(lo[1]) <= .0011 and abs(lo[0] + hi[0]) <= .0011 and abs(lo[2] + hi[2]) <= .0011, 'ground-centered origin'
    assert entry['triangles'] == triangles and entry['material_count'] == len(nodes) == entry['runtime_mesh_nodes'], 'geometry metadata mismatch'
    for key, actual in (('min', lo), ('max', hi), ('size', size)):
        claimed = entry['physical_bounds_m'][key]
        assert len(claimed) == 3 and all(abs(claimed[j] - actual[i]) <= .0011 for i, j in enumerate((0, 2, 1))), 'bounds metadata mismatch'


def validate_totals(glb_bytes, phase_bytes, log_bytes):
    assert 0 <= glb_bytes <= GLB_CAP, 'combined GLB budget'
    assert 0 <= phase_bytes <= PHASE_CAP, 'phase budget'
    assert 0 <= log_bytes <= LOG_CAP, 'log budget'


def owned_path(relative, expected):
    assert relative == expected, 'portable manifest path mismatch'
    path = ROOT / relative
    assert path.resolve() == path and path.is_relative_to(ROOT), 'output path escape/mismatch'
    return path


def owned_file(relative, expected):
    path = owned_path(relative, expected)
    assert path.is_file(), f'missing artifact: {relative}'
    return path


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        assert key not in result, f'duplicate JSON key: {key}'
        result[key] = value
    return result


def read_json(path):
    try:
        return json.loads(path.read_text(), object_pairs_hook=unique_pairs)
    except (ValueError, UnicodeError) as error:
        raise AssertionError('malformed marker JSON') from error


def load_inputs():
    """Repository-owned pins/actual-pixel attestation, not a private task-audit bundle."""
    inputs = read_json(owned_file(INPUTS, INPUTS))
    assert isinstance(inputs, dict) and set(inputs) == {'schema_version', 'helper_sha256', 'reference'}, 'marker input schema'
    assert type(inputs['schema_version']) is int and inputs['schema_version'] == 1, 'marker input version'
    helpers = inputs['helper_sha256']
    assert helpers == HELPER_SHA, 'helper provenance pins'
    assert all(sha(owned_file(rel, rel)) == digest for rel, digest in helpers.items()), 'immutable helper drift'
    reference = inputs['reference']
    assert isinstance(reference, dict) and set(reference) == {'path', 'sha256', 'inspection'}, 'reference provenance schema'
    assert reference['path'] == REFERENCE and reference['sha256'] == REFERENCE_SHA, 'reference provenance pins'
    assert sha(owned_file(reference['path'], REFERENCE)) == REFERENCE_SHA, 'reference drift'
    inspection = reference['inspection']
    assert isinstance(inspection, dict) and set(inspection) == {'inspected_actual_pixels', 'observations'}, 'image inspection schema'
    assert inspection['inspected_actual_pixels'] is True, 'actual image inspection required'
    observations = inspection['observations']
    assert isinstance(observations, list) and observations and all(isinstance(s, str) and s.strip() for s in observations), 'image observations required'
    owned_file(RECIPE, RECIPE)


def validate_lineage(entry):
    # Same per-asset provenance assertions, shared with the builder's pre-write manifest load.
    name = entry['id']
    assert entry['recipe_sha256'] == sha(owned_file(RECIPE, RECIPE))
    assert entry['recipe_dependencies'] == {'tools/build_art.py': HELPER_SHA['tools/build_art.py']}
    assert entry['reference_images'] == [{'path': REFERENCE, 'sha256': REFERENCE_SHA}]
    assert entry['provenance'] == {'method': 'image-derived original Blender geometry',
                                  'authoring_script': RECIPE, 'imports': [],
                                  'license': 'Original NULL CHOIR project art'}
    assert entry['origin'] == 'ground-centered at Blender (0,0,0); GLB Y up'
    assert entry['facing'] == 'front Blender -Y; exported Godot +Z'
    assert entry['collision'] == 'none; marker visuals only' and entry['loop_id'] is None
    assert len(entry['outputs']) == 1
    owned_path(entry['source'], f'source/art/{name}.blend')
    owned_path(entry['outputs'][0]['path'], f'game/assets/art/world/{name}.glb')
    owned_path(entry['preview']['path'], f'builds/marker-art/{name}_preview.png')
    owned_path(entry['geometry_receipt'], f'builds/marker-art/{name}_geometry.json')


def load_manifest():
    path = owned_path(MANIFEST, MANIFEST)
    manifest = read_json(path) if path.exists() else {'schema_version': 1, 'assets': []}
    assert isinstance(manifest, dict) and set(manifest) == {'schema_version', 'assets'}, 'marker manifest schema'
    assert type(manifest['schema_version']) is int and manifest['schema_version'] == 1, 'marker manifest version'
    assets = manifest['assets']
    assert isinstance(assets, list) and all(isinstance(a, dict) and isinstance(a.get('id'), str) for a in assets), 'marker asset entries'
    ids = [a['id'] for a in assets]
    assert len(set(ids)) == len(ids) and set(ids) <= set(IDS), 'marker IDs'
    for entry in assets:
        validate_lineage(entry)
    return manifest


def family_totals():
    files = []
    for relative in FAMILY_FILES:
        path = owned_path(relative, relative)
        if path.exists():
            assert path.is_file(), f'non-file marker path: {relative}'
            files.append(path)
    totals = (sum(p.stat().st_size for p in files if p.suffix == '.glb'),
              sum(p.stat().st_size for p in files),
              sum(p.stat().st_size for p in files if p.suffix == '.log'))
    validate_totals(*totals)
    return totals


def check(asset=None):
    path = owned_path(MANIFEST, MANIFEST)
    assert path.is_file(), 'marker outputs absent: intended asset-contract RED; native build HELD'
    manifest = load_manifest()
    assets = manifest['assets']
    ids = [a['id'] for a in assets]
    assert asset in ids if asset else set(ids) == set(IDS), 'all eight marker outputs required'
    load_inputs()
    total = 0
    for entry in assets:
        name = entry['id']
        source = owned_file(entry['source'], f'source/art/{name}.blend')
        with source.open('rb') as stream:
            assert stream.read(7) == b'BLENDER', 'native blend header'
        assert sha(source) == entry['source_sha256']
        output = entry['outputs'][0]
        glb = owned_file(output['path'], f'game/assets/art/world/{name}.glb')
        assert sha(glb) == output['sha256'] and glb.stat().st_size == output['bytes']
        total += glb.stat().st_size
        assert total <= GLB_CAP, 'combined GLB budget'
        validate_model(*read_model(glb.read_bytes()), entry)
        preview = entry['preview']
        image = owned_file(preview['path'], f'builds/marker-art/{name}_preview.png')
        assert sha(image) == preview['sha256'] and image.stat().st_size == preview['bytes']
        size, pixels = png(image)
        assert list(size) == preview['dimensions'] == [128, 128]
        alpha = pixels[3::4]
        assert set(alpha) == {0, 255} and 128 <= alpha.count(255) < 128 * 128 * .85, 'transparent nonempty preview'
        assert not any(alpha[:128] + alpha[-128:] + alpha[::128] + alpha[127::128]), 'preview clipping'
        receipt_file = owned_file(entry['geometry_receipt'], f'builds/marker-art/{name}_geometry.json')
        receipt = read_json(receipt_file)
        assert receipt['asset_id'] == name and receipt['source_sha256'] == entry['source_sha256']
        assert receipt['recipe_sha256'] == entry['recipe_sha256']
        assert (receipt['render_engine'], receipt['device'], receipt['threads'], receipt['samples']) == ('CYCLES', 'CPU', 4, 16)
        parts = receipt['source_meshes']
        assert len(parts) >= 4 and len({p['name'] for p in parts}) == len(parts), 'named editable source parts'
        assert sum(p['triangles'] for p in parts) == entry['triangles']
        assert receipt['physical_bounds_m'] == entry['physical_bounds_m']
        assert receipt['material_groups'] == entry['material_count']
        assert receipt['reference_sha256'] == REFERENCE_SHA
    family_totals()

def fixture():
    """Synthetic triangle data, never written as production art."""
    positions = [(x, y, z) for x in (-.2, .2) for y in (0, .6) for z in (-.1, .1)]
    binary = b''.join(struct.pack('<3f', *p) for p in positions) + struct.pack('<3H', 0, 1, 2)
    gltf = {'asset': {'version': '2.0'}, 'buffers': [{'byteLength': len(binary)}],
            'bufferViews': [{'buffer': 0, 'byteOffset': 0, 'byteLength': 96},
                            {'buffer': 0, 'byteOffset': 96, 'byteLength': 6}],
            'accessors': [{'bufferView': 0, 'componentType': 5126, 'count': 8, 'type': 'VEC3'},
                          {'bufferView': 1, 'componentType': 5123, 'count': 3, 'type': 'SCALAR'}],
            'materials': [{'name': 'Fixture iron'}],
            'meshes': [{'primitives': [{'attributes': {'POSITION': 0}, 'indices': 1, 'material': 0}]}],
            'nodes': [{'name': 'marker_fixture_iron', 'mesh': 0}],
            'scenes': [{'nodes': [0]}], 'scene': 0}
    entry = {'id': 'marker_ammo', 'triangles': 1, 'material_count': 1, 'runtime_mesh_nodes': 1,
             'physical_bounds_m': {'min': [-.2, -.1, 0], 'max': [.2, .1, .6], 'size': [.4, .2, .6]}}
    return gltf, binary, entry


def container(gltf, binary):
    encoded = json.dumps(gltf).encode()
    encoded += b' ' * (-len(encoded) % 4)
    binary += b'\0' * (-len(binary) % 4)
    body = struct.pack('<I4s', len(encoded), b'JSON') + encoded
    body += struct.pack('<I4s', len(binary), b'BIN\0') + binary
    return struct.pack('<4sII', b'glTF', 2, 12 + len(body)) + body


class ValidatorFixtures(unittest.TestCase):
    def test_valid_model_and_container(self):
        g, b, e = fixture()
        self.assertIsNone(validate_model(g, b, e))
        self.assertEqual(read_model(container(g, b))[0], g)

    def test_malformed_container(self):
        g, b, _ = fixture()
        data = container(g, b)
        for broken in (b'', b'bad!', data[:-1], b'xxxx' + data[4:],
                       data[:16] + b'NOPE' + data[20:], data + b'junk'):
            with self.subTest(bytes=len(broken)), self.assertRaises(AssertionError):
                read_model(broken)

    def test_external_content_and_forbidden_nodes(self):
        g, b, e = fixture()
        edits = [lambda d: d['buffers'][0].update(uri='outside.bin'),
                 lambda d: d.update(images=[{'uri': 'outside.png'}]),
                 lambda d: d.update(cameras=[{}]),
                 lambda d: d.update(extensionsUsed=['KHR_lights_punctual']),
                 lambda d: d.update(animations=[{}]),
                 lambda d: d.update(skins=[{}]),
                 lambda d: d['nodes'][0].update(extras={'script': 'unsafe.gd'}),
                 lambda d: d['nodes'][0].update(camera=0),
                 lambda d: d['nodes'][0].update(name='marker_collider'),
                 lambda d: d['nodes'][0].update(name='marker-col'),
                 lambda d: d['nodes'].append({'name': 'light'}),
                 lambda d: d['nodes'][0].update(translation=[1, 0, 0]),
                 lambda d: d.update(scenes=[{'nodes': []}])]
        for edit in edits:
            d = copy.deepcopy(g)
            edit(d)
            with self.subTest(model=d), self.assertRaises(AssertionError):
                validate_model(d, b, e)

    def test_malformed_geometry(self):
        g, b, e = fixture()
        edits = [lambda d: d['bufferViews'][0].update(byteLength=10000),
                 lambda d: d['bufferViews'][0].update(byteOffset=-1),
                 lambda d: d['accessors'][0].update(count=10000),
                 lambda d: d['accessors'][1].update(count=4),
                 lambda d: d['meshes'][0]['primitives'][0].update(mode=1),
                 lambda d: d['meshes'][0]['primitives'].append(d['meshes'][0]['primitives'][0]),
                 lambda d: d['meshes'][0]['primitives'][0].update(indices=-1),
                 lambda d: d['accessors'][1].update(bufferView=-1),
                 lambda d: d['meshes'][0].update(extras={'script': 'unsafe.gd'}),
                 lambda d: d['meshes'][0]['primitives'][0].update(extensions={'custom': {}})]
        for edit in edits:
            d = copy.deepcopy(g)
            edit(d)
            with self.subTest(model=d), self.assertRaises(AssertionError):
                validate_model(d, b, e)
        for broken in (b[:-1], b[:96] + struct.pack('<3H', 0, 1, 500),
                       struct.pack('<f', float('nan')) + b[4:]):
            with self.subTest(binary=broken), self.assertRaises(AssertionError):
                validate_model(g, broken, e)

    def test_mismatched_metadata(self):
        g, b, e = fixture()
        for key, value in (('triangles', 2), ('material_count', 2), ('runtime_mesh_nodes', 2)):
            d = copy.deepcopy(e)
            d[key] = value
            with self.subTest(key=key), self.assertRaises(AssertionError):
                validate_model(g, b, d)
        d = copy.deepcopy(e)
        d['physical_bounds_m']['size'][0] = .3
        with self.assertRaises(AssertionError):
            validate_model(g, b, d)

    def test_triangle_bounds_and_material_budgets(self):
        g, b, e = fixture()
        d = copy.deepcopy(g)
        d['accessors'][1]['count'] = 2501 * 3
        big = b[:96] + struct.pack('<3H', 0, 1, 2) * 2501
        d['bufferViews'][1]['byteLength'] = len(big) - 96
        d['buffers'][0]['byteLength'] = len(big)
        claimed = copy.deepcopy(e)
        claimed['triangles'] = 2501
        with self.assertRaisesRegex(AssertionError, 'triangle budget'):
            validate_model(d, big, claimed)
        for axis, cap in enumerate(CAP):
            oversized = bytearray(b)
            struct.pack_into('<f', oversized, axis * 4, cap + .1)
            with self.subTest(axis=axis), self.assertRaisesRegex(AssertionError, 'bounds budget'):
                validate_model(g, bytes(oversized), e)
        d = copy.deepcopy(g)
        d['nodes'], d['meshes'], d['materials'] = [], [], []
        for i in range(9):
            d['materials'].append({'name': str(i)})
            primitive = copy.deepcopy(g['meshes'][0]['primitives'][0])
            primitive['material'] = i
            d['meshes'].append({'primitives': [primitive]})
            d['nodes'].append({'name': str(i), 'mesh': i})
        d['scenes'][0]['nodes'] = list(range(9))
        with self.assertRaisesRegex(AssertionError, 'material budget'):
            validate_model(d, b, e)

    def test_manifest_paths_are_portable_and_pinned(self):
        # Path validation is independent of retaining the actual production reference in unit fixtures.
        with tempfile.TemporaryDirectory(prefix='.marker-file-', dir=ROOT) as temporary:
            expected = str((Path(temporary) / 'metadata.txt').relative_to(ROOT))
            (ROOT / expected).write_text('path fixture only')
            self.assertEqual(owned_file(expected, expected), ROOT / expected)
            for relative in (str(ROOT / expected), './' + expected, '../outside.blend'):
                with self.subTest(path=relative), self.assertRaises(AssertionError):
                    owned_file(relative, expected)

    def test_file_budgets(self):
        validate_totals(GLB_CAP, PHASE_CAP, LOG_CAP)
        for totals in ((GLB_CAP + 1, 0, 0), (0, PHASE_CAP + 1, 0), (0, 0, LOG_CAP + 1)):
            with self.subTest(totals=totals), self.assertRaises(AssertionError):
                validate_totals(*totals)


def fixture_with_attributes():
    gltf, binary, entry = fixture()
    binary += b'\0' * (-len(binary) % 4)
    for semantic, layout, values in (('NORMAL', 'VEC3', (0., 1., 0.)),
                                      ('TEXCOORD_0', 'VEC2', (.5, .5))):
        payload = struct.pack('<' + 'f' * len(values), *values) * 8
        gltf['bufferViews'].append({'buffer': 0, 'byteOffset': len(binary), 'byteLength': len(payload)})
        gltf['accessors'].append({'bufferView': len(gltf['bufferViews']) - 1,
                                 'componentType': 5126, 'count': 8, 'type': layout})
        gltf['meshes'][0]['primitives'][0]['attributes'][semantic] = len(gltf['accessors']) - 1
        binary += payload
    gltf['buffers'][0]['byteLength'] = len(binary)
    return gltf, binary, entry


def path_preflight(root):
    """Load exactly the path-only definition; never import the bpy recipe."""
    tree = ast.parse((ROOT / RECIPE).read_text())
    function = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'prepare_paths')
    # This exact function may inspect paths, construct tuples and assert; no I/O writer or native call.
    assert all(not isinstance(n, (ast.Import, ast.ImportFrom)) for n in ast.walk(function))
    calls = [n.func for n in ast.walk(function) if isinstance(n, ast.Call)]
    assert all((isinstance(n, ast.Name) and n.id == 'all') or
               (isinstance(n, ast.Attribute) and n.attr in ('resolve', 'is_relative_to')) for n in calls)
    paths = SimpleNamespace(ROOT=root, ART=root / 'source/art', OUT=root / 'game/assets/art',
                            SCRATCH=root / 'builds/art')
    namespace = {'ROOT': root, 'art': paths}
    exec(compile(ast.Module(body=[function], type_ignores=[]), str(ROOT / RECIPE), 'exec'), namespace)
    return namespace['prepare_paths'], paths


class CorrectionFixtures(unittest.TestCase):
    def test_effective_scratch_and_good_output_paths(self):
        with tempfile.TemporaryDirectory(prefix='.marker-path-', dir=ROOT) as temporary:
            root = Path(temporary) / 'owned'
            root.mkdir()
            preflight, paths = path_preflight(root)
            manifest, candidates = preflight('marker_ammo')
            self.assertEqual(paths.SCRATCH, root / 'builds/marker-art')
            self.assertEqual(manifest, root / 'source/art/marker-manifest.json')
            self.assertEqual(len(candidates), 5)
            self.assertTrue(all(p.resolve() == p and p.is_relative_to(root) for p in candidates))
            self.assertEqual(list(root.iterdir()), [])  # Preflight must not write.

    def test_symlink_output_rejection_before_any_write(self):
        # All temporary directories, including the simulated outside target, stay inside F.
        for relative in ('builds/marker-art', 'builds/marker-art/frames', 'source/art',
                         'game/assets/art/world', 'source/art/marker-manifest.json',
                         'builds/marker-art/marker_ammo_preview.png'):
            for target_location in ('outside', 'owned/wrong-directory'):
                with self.subTest(path=relative, target=target_location), tempfile.TemporaryDirectory(prefix='.marker-path-', dir=ROOT) as temporary:
                    fixture_root = Path(temporary)
                    root = fixture_root / 'owned'
                    root.mkdir()
                    target = fixture_root / target_location
                    target.mkdir()
                    link = root / relative
                    link.parent.mkdir(parents=True, exist_ok=True)
                    link.symlink_to(target, target_is_directory=True)
                    before = set(fixture_root.rglob('*'))
                    preflight, _ = path_preflight(root)
                    with self.assertRaises(AssertionError):
                        preflight('marker_ammo')
                    self.assertEqual(set(fixture_root.rglob('*')), before)
                    self.assertEqual(list(target.iterdir()), [])

    def test_good_normal_and_texcoord_attributes(self):
        g, b, e = fixture_with_attributes()
        self.assertIsNone(validate_model(g, b, e))
        self.assertIsNone(validate_model(*read_model(container(g, b)), e))

    def test_attribute_accessor_references(self):
        g, b, e = fixture_with_attributes()
        for semantic in ('NORMAL', 'TEXCOORD_0'):
            for index in (-1, len(g['accessors']), False):
                d = copy.deepcopy(g)
                d['meshes'][0]['primitives'][0]['attributes'][semantic] = index
                with self.subTest(attribute=semantic, index=index), self.assertRaises(AssertionError):
                    validate_model(d, b, e)

    def test_attribute_layout_count_and_truncated_ranges(self):
        g, b, e = fixture_with_attributes()
        for semantic in ('NORMAL', 'TEXCOORD_0'):
            index = g['meshes'][0]['primitives'][0]['attributes'][semantic]
            edits = [lambda d: d['accessors'][index].update(bufferView=False),
                     lambda d: d['accessors'][index].update(bufferView=-1),
                     lambda d: d['accessors'][index].update(bufferView=len(d['bufferViews'])),
                     lambda d: d['accessors'][index].update(type='SCALAR'),
                     lambda d: d['accessors'][index].update(componentType=5123),
                     lambda d: d['accessors'][index].update(normalized=True),
                     lambda d: d['accessors'][index].update(count=7),
                     lambda d: d['accessors'][index].update(count=9),
                     lambda d: d['accessors'][index].update(byteOffset=-4),
                     lambda d: d['accessors'][index].update(byteOffset=4),
                     lambda d: d['bufferViews'][d['accessors'][index]['bufferView']].update(byteLength=4),
                     lambda d: d['bufferViews'][d['accessors'][index]['bufferView']].update(byteStride=4)]
            for case, edit in enumerate(edits):
                d = copy.deepcopy(g)
                edit(d)
                with self.subTest(attribute=semantic, case=case), self.assertRaises(AssertionError):
                    validate_model(d, b, e)
        d = copy.deepcopy(g)
        d['meshes'][0]['primitives'][0]['attributes']['UNREVIEWED'] = 0
        with self.assertRaises(AssertionError):
            validate_model(d, b, e)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--unit', action='store_true')
    parser.add_argument('--asset', choices=IDS)
    args = parser.parse_args()
    if args.unit:
        unittest.main(argv=[__file__], verbosity=2)
    else:
        check(args.asset)
        print('Marker artifact contract GREEN (actual files only)')
