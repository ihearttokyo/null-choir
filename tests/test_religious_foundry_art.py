"""Foundry isolation/topology; --candidate-root validates real parent-built output."""
import argparse
from collections import Counter
from contextlib import redirect_stderr
import hashlib
import io
import json
from pathlib import Path
import runpy
import struct
import tempfile

ROOT = Path(__file__).resolve().parents[1]
validate_recipe = runpy.run_path(str(ROOT / 'tools/art_recipe.py'))['validate_recipe']
recipe = runpy.run_path(str(ROOT / 'tools/build_religious_foundry_art.py'))


def check():
    asset = recipe['IDS'][0]
    tails = ['native/source/art/' + asset + '.blend', 'native/game/assets/art/world/' + asset + '.glb',
             'native/previews/' + asset + '_preview.png', 'native/previews/frames/' + asset + '_hero.png',
             asset + '_candidate.json']
    for tail in tails:
        with tempfile.TemporaryDirectory(prefix='foundry-isolation-') as temp:
            receipt = Path(temp).resolve()
            native = receipt / 'native'
            assert recipe['preflight'](asset, native, receipt, ROOT) == (native, receipt)
            existing = receipt / tail
            existing.parent.mkdir(parents=True, exist_ok=True)
            existing.write_bytes(b'accepted existing output must survive')
            try:
                recipe['preflight'](asset, native, receipt, ROOT)
            except FileExistsError:
                pass
            else:
                raise AssertionError('Foundry preflight must refuse existing output before native import/writes (intended RED)')
            assert existing.read_bytes() == b'accepted existing output must survive'
    with tempfile.TemporaryDirectory(prefix='foundry-symlink-') as temp:
        receipt = Path(temp).resolve()
        native = receipt / 'native'
        native.mkdir()
        (native / 'source').symlink_to(ROOT / 'source', target_is_directory=True)
        try:
            recipe['preflight'](asset, native, receipt, ROOT)
        except ValueError:
            pass
        else:
            raise AssertionError('nested symlinks cannot redirect Foundry output into production')
    with tempfile.TemporaryDirectory(prefix='foundry-dangling-') as temp:
        receipt = Path(temp).resolve()
        (receipt / (asset + '_candidate.json')).symlink_to(receipt / 'missing-record')
        try:
            recipe['preflight'](asset, receipt / 'native', receipt, ROOT)
        except FileExistsError:
            pass
        else:
            raise AssertionError('dangling record symlinks must not be overwritten')
    for output, receipt in [(ROOT / 'source/art', ROOT), (Path('/private/tmp/native'), Path('/private/tmp/other'))]:
        try:
            recipe['preflight'](asset, output, receipt, ROOT)
        except ValueError:
            pass
        else:
            raise AssertionError('reject production overlap or output outside explicit receipt root')
    for argv in [[], ['--asset', asset], ['--asset', 'all', '--output-root', '/private/tmp/native', '--receipt-root', '/private/tmp']]:
        with redirect_stderr(io.StringIO()):
            try:
                recipe['arguments'](argv)
            except SystemExit as error:
                assert error.code == 2
            else:
                raise AssertionError('one valid asset and both roots are mandatory')
    for asset in recipe['IDS']:
        opts = recipe['arguments'](['--asset', asset, '--output-root', '/private/tmp/native', '--receipt-root', '/private/tmp'])
        assert opts.asset == asset and callable(recipe[asset.removeprefix('foundry_')])
    for verts, faces in [recipe['pressure_cell'](.9), recipe['slag_petal'](.3), recipe['curtain_leaf'](0, 5.5, 3),
                         recipe['control_blade'](2.83)]:
        assert all(0 <= vertex < len(verts) for face in faces for vertex in face)
        directed = Counter((face[i], face[(i + 1) % len(face)]) for face in faces for i in range(len(face)))
        assert all(directed[a, b] == directed[b, a] == 1 for a, b in directed), 'closed solids need two oppositely wound faces per edge (intended RED)'
        triangles = [(verts[face[0]], verts[face[i]], verts[face[i + 1]]) for face in faces for i in range(1, len(face) - 1)]
        volume = sum(a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0])
                     + a[2] * (b[0] * c[1] - b[1] * c[0]) for a, b, c in triangles) / 6
        assert volume > 0, 'closed pure recipe faces must point outward (intended RED)'
    verts, _ = recipe['pressure_cell'](.9)
    assert len(verts) == 20 and max(p[1] for p in verts) - min(p[1] for p in verts) >= .4
    print('PASS Foundry explicit single-asset CLI, output preservation/isolation and pure cell/petal/curtain/blade topology/outward winding')


def check_candidates(receipt):
    geometry = runpy.run_path(str(ROOT / 'tests/test_art.py'))['world_geometry']
    total, digests = 0, set()
    dependencies = ('tools/build_art.py', 'tools/build_foundry_art.py', 'tools/build_religious_art.py')
    for asset in recipe['IDS']:
        candidate = json.loads((receipt / (asset + '_candidate.json')).read_text())
        entry = candidate['asset']
        output, _ = recipe['intake'].candidate_roots(candidate['output_root'], receipt, ROOT)
        assert entry['id'] == asset and entry['level_id'] == 'foundry' and entry['loop_id'] is None
        assert entry['tradition_aesthetic'] == recipe['TRADITIONS'][asset] and entry['machine_purpose'] == recipe['PURPOSES'][asset]
        assert entry['facing'] == 'front Blender -Y; exported Godot +Z'
        assert entry['provenance']['authoring_script'] == 'tools/build_religious_foundry_art.py'
        validate_recipe(ROOT, entry, 'tools/build_religious_foundry_art.py', dependencies)
        assert entry['reference_images'] == [{'path': p, 'sha256': h} for p, h in recipe['REFERENCES'].items()]
        for path, digest in recipe['REFERENCES'].items():
            assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest
        source = (output / entry['source']).resolve()
        assert source.is_relative_to(output / 'source/art') and source.suffix == '.blend'
        source_data = source.read_bytes()
        assert source_data[:7] == b'BLENDER' and hashlib.sha256(source_data).hexdigest() == entry['source_sha256']
        assert entry['source_hierarchy_groups'] == candidate['source_hierarchy_groups'] >= 4
        assert len(entry['assembly_names']) == len(set(entry['assembly_names'])) == entry['source_hierarchy_groups']
        assert len(candidate['source_meshes']) == entry['source_mesh_count']
        assert sum(m['triangles'] for m in candidate['source_meshes']) == entry['triangles'] <= 30000
        assert len(entry['outputs']) == 1
        exported = entry['outputs'][0]
        path = (output / exported['path']).resolve()
        assert path.is_relative_to(output / 'game/assets/art/world') and path.suffix == '.glb'
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        assert digest == exported['sha256'] and len(data) == exported['bytes']
        total += len(data)
        digests.add(digest)
        assert struct.unpack_from('<4sII', data) == (b'glTF', 2, len(data))
        n, kind = struct.unpack_from('<I4s', data, 12)
        assert kind == b'JSON'
        gltf = json.loads(data[20:20 + n])
        binary_size, binary_kind = struct.unpack_from('<I4s', data, 20 + n)
        assert binary_kind == b'BIN\0' and 28 + n + binary_size == len(data)
        binary = data[28 + n:]
        assert all('uri' not in b for b in gltf['buffers'])
        assert gltf.get('images') and all('bufferView' in im and 'uri' not in im for im in gltf['images'])
        assert not gltf.get('cameras') and 'KHR_lights_punctual' not in gltf.get('extensions', {})
        for im in gltf['images']:
            view = gltf['bufferViews'][im['bufferView']]
            offset = view.get('byteOffset', 0)
            assert binary[offset:offset + 8] == b'\x89PNG\r\n\x1a\n'
            w, h = struct.unpack_from('>II', binary, offset + 16)
            assert w <= 192 and h <= 64
        points, triangles = geometry(gltf, binary)
        assert triangles == entry['triangles'] <= 30000
        assert len(gltf['meshes']) == entry['runtime_mesh_nodes'] <= 7
        assert len(gltf['materials']) == entry['material_count'] <= 7
        lo, hi = ([min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)])
        actual = {'min': [lo[0], -hi[2], lo[1]], 'max': [hi[0], -lo[2], hi[1]]}
        for key, values in actual.items():
            assert all(abs(v - w) <= .002 for v, w in zip(values, entry['physical_bounds_m'][key])), (asset, key)
        size = [actual['max'][i] - actual['min'][i] for i in range(3)]
        assert all(v <= cap + .003 for v, cap in zip(size, recipe['CAPS'])) and abs(lo[1]) <= .002, (asset, size)
        assert any(any(v > 0 for v in m.get('emissiveFactor', [])) for m in gltf['materials'])
        preview = Path(candidate['preview']).resolve()
        assert preview.is_relative_to(output / 'previews') and preview.is_file()
    assert total < 8 * 1024 * 1024 and len(digests) == 7
    print(f'PASS real Foundry GLB/source provenance, vertices, bounds, merged materials, textures and {total} bytes')
    print('NOT VALIDATED: render/reference fidelity, actual blend collection inspection or map staging/traversal')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate-root', type=Path)
    opts = parser.parse_args()
    check()
    if opts.candidate_root:
        check_candidates(opts.candidate_root.resolve())
