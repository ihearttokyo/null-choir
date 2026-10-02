"""Processional isolated candidate boundary; parent owns native visual evidence."""
import argparse
from contextlib import redirect_stderr
import hashlib
import io
import json
from pathlib import Path
import struct
import runpy
import tempfile

ROOT = Path(__file__).resolve().parents[1]
recipe = runpy.run_path(str(ROOT / 'tools/build_religious_processional_art.py'))


def check():
    asset = recipe['IDS'][0]
    for tail in ['native/source/art/' + asset + '.blend', 'native/game/assets/art/world/' + asset + '.glb',
                 'native/previews/' + asset + '_preview.png', 'native/previews/frames/' + asset + '_hero.png',
                 asset + '_candidate.json']:
        with tempfile.TemporaryDirectory(prefix='processional-preserve-') as temp:
            receipt = Path(temp).resolve()
            native = receipt / 'native'
            source = receipt / tail
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_bytes(b'accepted candidate source')
            try:
                recipe['preflight'](asset, native, receipt, ROOT)
            except FileExistsError:
                pass
            else:
                raise AssertionError('Processional must refuse existing candidate before any native import or write (intended RED)')
            assert source.read_bytes() == b'accepted candidate source'
    with tempfile.TemporaryDirectory(prefix='processional-atlas-') as temp:
        receipt = Path(temp).resolve()
        native = receipt / 'native'
        atlas = native / 'game/assets/art/textures/surface_atlas.png'
        atlas.parent.mkdir(parents=True)
        atlas.symlink_to(receipt / 'missing-atlas')
        try:
            recipe['preflight'](asset, native, receipt, ROOT)
        except ValueError:
            pass
        else:
            raise AssertionError('Processional atlas leaf symlink must be refused before native writes (intended RED)')
    with tempfile.TemporaryDirectory(prefix='processional-nested-') as temp:
        receipt = Path(temp).resolve()
        native = receipt / 'native'
        native.mkdir()
        (native / 'source').symlink_to(ROOT / 'source', target_is_directory=True)
        try:
            recipe['preflight'](asset, native, receipt, ROOT)
        except ValueError:
            pass
        else:
            raise AssertionError('nested candidate symlinks cannot redirect writes into production')
    for output, receipt in [(ROOT / 'source/art', ROOT), (Path('/private/tmp/native'), Path('/private/tmp/other'))]:
        try:
            recipe['preflight'](asset, output, receipt, ROOT)
        except ValueError:
            pass
        else:
            raise AssertionError('production overlap and output outside explicit receipt root must be refused')
    for argv in [[], ['--asset', asset], ['--asset', 'all', '--output-root', '/private/tmp/native', '--receipt-root', '/private/tmp']]:
        with redirect_stderr(io.StringIO()):
            try:
                recipe['arguments'](argv)
            except SystemExit as error:
                assert error.code == 2
            else:
                raise AssertionError('require one valid asset and both explicit roots')
    for asset in recipe['IDS']:
        opts = recipe['arguments'](['--asset', asset, '--output-root', '/private/tmp/native', '--receipt-root', '/private/tmp'])
        assert opts.asset == asset and callable(recipe[asset.removeprefix('processional_')])
    print('PASS Processional single-asset CLI, output preservation, isolated roots and pre-native atlas symlink refusal')


def check_candidates(receipt):
    geometry = runpy.run_path(str(ROOT / 'tests/test_art.py'))['world_geometry']
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    dependencies = {p: sha(ROOT / p) for p in ('tools/build_art.py', 'tools/build_foundry_art.py', 'tools/build_processional_art.py',
                                               'tools/build_religious_art.py', 'tools/build_religious_foundry_art.py')}
    total, digests = 0, set()
    for asset in recipe['IDS']:
        candidate = json.loads((receipt / (asset + '_candidate.json')).read_text())
        entry = candidate['asset']
        output, _ = recipe['intake'].candidate_roots(candidate['output_root'], receipt, ROOT)
        assert entry['id'] == asset and entry['level_id'] == 'processional' and entry['loop_id'] is None
        assert entry['tradition_aesthetic'] == recipe['TRADITIONS'][asset] and entry['machine_purpose'] == recipe['PURPOSES'][asset]
        assert entry['facing'] == 'front Blender -Y; exported Godot +Z' and entry['collision'].startswith('none;')
        assert entry['recipe_sha256'] == sha(ROOT / 'tools/build_religious_processional_art.py')
        assert entry['provenance']['authoring_script'] == 'tools/build_religious_processional_art.py'
        assert entry['recipe_dependencies'] == dependencies
        assert entry['reference_images'] == [{'path': p, 'sha256': h} for p, h in recipe['REFERENCES'].items()]
        for p, h in recipe['REFERENCES'].items():
            assert sha(ROOT / p) == h
        for p, h in entry['texture_dependencies'].items():
            assert sha(ROOT / p) == h and sha(output / p) == h
        source = (output / entry['source']).resolve()
        assert source.is_relative_to(output / 'source/art') and source.suffix == '.blend'
        assert source.read_bytes()[:7] == b'BLENDER' and sha(source) == entry['source_sha256']
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
        size, kind = struct.unpack_from('<I4s', data, 20 + n)
        assert kind == b'BIN\0' and 28 + n + size == len(data)
        binary = data[28 + n:]
        assert all('uri' not in b for b in gltf['buffers'])
        assert gltf.get('images') and all('bufferView' in im and 'uri' not in im for im in gltf['images'])
        assert not gltf.get('cameras') and 'KHR_lights_punctual' not in gltf.get('extensions', {})
        for im in gltf['images']:
            view = gltf['bufferViews'][im['bufferView']]
            off = view.get('byteOffset', 0)
            assert binary[off:off + 8] == b'\x89PNG\r\n\x1a\n'
            w, h = struct.unpack_from('>II', binary, off + 16)
            assert w <= 192 and h <= 64
        points, triangles = geometry(gltf, binary)
        assert triangles == entry['triangles'] <= 30000
        assert len(gltf['meshes']) == entry['runtime_mesh_nodes'] <= 7 and len(gltf['materials']) == entry['material_count'] <= 7
        lo, hi = ([min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)])
        actual = {'min': [lo[0], -hi[2], lo[1]], 'max': [hi[0], -lo[2], hi[1]]}
        for k, values in actual.items():
            assert all(abs(v - w) <= .002 for v, w in zip(values, entry['physical_bounds_m'][k])), (asset, k)
        extent = [actual['max'][i] - actual['min'][i] for i in range(3)]
        assert all(v <= cap + .003 for v, cap in zip(extent, recipe['CAPS'])) and abs(lo[1]) <= .002, (asset, extent)
        assert any(any(v > 0 for v in m.get('emissiveFactor', [])) for m in gltf['materials'])
        preview = Path(candidate['preview']).resolve()
        assert preview.is_relative_to(output / 'previews') and preview.is_file()
    assert total < 8 * 1024 * 1024 and len(digests) == 7
    print(f'PASS real Processional source/GLB provenance, geometry, budgets, materials, textures and {total} bytes')
    print('NOT VALIDATED: real source editability inspection, reference/render fidelity or game staging/traversal')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate-root', type=Path)
    opts = parser.parse_args()
    check()
    if opts.candidate_root:
        check_candidates(opts.candidate_root.resolve())
