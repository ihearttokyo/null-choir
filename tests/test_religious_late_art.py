"""Late dispatch's per-level budget, hero identity and isolated output checks."""
import argparse
import hashlib
import json
import struct
from pathlib import Path
import runpy
import tempfile

ROOT = Path(__file__).resolve().parents[1]
validate_recipe = runpy.run_path(str(ROOT / 'tools/art_recipe.py'))['validate_recipe']
recipe = runpy.run_path(str(ROOT / 'tools/build_religious_late_art.py'))


def check():
    ids = recipe['LEVEL_IDS']
    assert len(ids) == 5 and all(len(assets) == 7 for assets in ids.values())
    assert len(set(recipe['IDS'])) == 35 and len(set(recipe['HEROES'])) == 10
    assert recipe['HEROES'] == tuple(a for assets in ids.values() for a in assets[:2])
    with tempfile.TemporaryDirectory(prefix='late-group-budget-') as temp:
        output = Path(temp)
        world = output / 'game/assets/art/world'
        world.mkdir(parents=True)
        for asset in recipe['IDS']:
            with (world / (asset + '.glb')).open('wb') as file:
                file.truncate(1024 * 1024)
        # Five valid 7MiB groups must not be rejected as one 35MiB group.
        for assets in ids.values():
            assert recipe['group_budget'](assets[0], output) == 7 * 1024 * 1024
        with (world / (ids['heart'][0] + '.glb')).open('wb') as file:
            file.truncate(2 * 1024 * 1024)
        try:
            recipe['group_budget'](ids['heart'][0], output)
        except AssertionError:
            pass
        else:
            raise AssertionError('Exactly 8MiB is rejected for each level (intended RED)')
        assert recipe['group_budget'](ids['nursery'][0], output) == 7 * 1024 * 1024
    with tempfile.TemporaryDirectory(prefix='late-internal-link-') as temp:
        receipt = Path(temp).resolve()
        output = receipt / 'native'
        (output / 'source').mkdir(parents=True)
        (output / 'alternate-art').mkdir()
        (output / 'source/art').symlink_to(output / 'alternate-art', target_is_directory=True)
        try:
            recipe['preflight'](recipe['IDS'][0], output, receipt, ROOT)
        except ValueError:
            pass
        else:
            raise AssertionError('Refuse candidate symlinks even when they stay inside output (intended RED)')
    for asset in recipe['IDS']:
        opts = recipe['arguments'](['--asset', asset, '--output-root', '/private/tmp/native', '--receipt-root', '/private/tmp'])
        assert opts.asset == asset and callable(recipe[asset])
    assert len(set(recipe['PURPOSES'].values())) == 35
    print('PASS 35 products, ten unique hero candidates, independent strict level budgets and symlink rejection')


def check_candidates(receipt, levels):
    """Read actual Blender/GLB output only; appearance and source editability stay native gates."""
    geometry = runpy.run_path(str(ROOT / 'tests/test_art.py'))['world_geometry']
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    dependencies = ('tools/build_art.py', 'tools/build_foundry_art.py', 'tools/build_processional_art.py',
                                               'tools/build_religious_art.py', 'tools/build_religious_foundry_art.py')
    digests = set()
    for level in levels:
        total = 0
        ref = f'source/art/references/religion-{level}-01.png'
        assert sha(ROOT / ref) == recipe['REFERENCES'][level]
        for asset in recipe['LEVEL_IDS'][level]:
            candidate = json.loads((receipt / (asset + '_candidate.json')).read_text())
            entry = candidate['asset']
            output, _ = recipe['intake'].candidate_roots(candidate['output_root'], receipt, ROOT)
            assert entry['id'] == asset and entry['level_id'] == level and entry['loop_id'] is None
            assert entry['loop_hero_candidate'] == (asset in recipe['HEROES'])
            assert entry['tradition_aesthetic'] == recipe['TRADITIONS'][asset] and entry['machine_purpose'] == recipe['PURPOSES'][asset]
            validate_recipe(ROOT, entry, 'tools/build_religious_late_art.py', dependencies)
            assert entry['reference_images'] == [{'path': ref, 'sha256': recipe['REFERENCES'][level]}]
            assert entry['facing'] == 'front Blender -Y; exported Godot +Z' and entry['collision'].startswith('none;')
            assert entry['provenance']['authoring_script'] == 'tools/build_religious_late_art.py'
            assert entry['texture_dependencies']
            for path, digest in entry['texture_dependencies'].items():
                assert sha(ROOT / path) == digest and sha(output / path) == digest
            source = (output / entry['source']).resolve()
            assert source.is_relative_to(output / 'source/art') and source.suffix == '.blend'
            assert source.read_bytes()[:7] == b'BLENDER' and sha(source) == entry['source_sha256']
            assert entry['source_hierarchy_groups'] == candidate['source_hierarchy_groups'] >= 4
            assert len(set(entry['assembly_names'])) == len(entry['assembly_names']) == entry['source_hierarchy_groups']
            assert len(candidate['source_meshes']) == entry['source_mesh_count']
            assert sum(m['triangles'] for m in candidate['source_meshes']) == entry['triangles'] <= 30000
            assert len(entry['outputs']) == 1
            exported = entry['outputs'][0]
            path = (output / exported['path']).resolve()
            assert path.is_relative_to(output / 'game/assets/art/world') and path.suffix == '.glb'
            data = path.read_bytes()
            digest = hashlib.sha256(data).hexdigest()
            assert digest == exported['sha256'] and len(data) == exported['bytes'] and digest not in digests
            total += len(data)
            digests.add(digest)
            assert struct.unpack_from('<4sII', data) == (b'glTF', 2, len(data))
            n, kind = struct.unpack_from('<I4s', data, 12)
            assert kind == b'JSON'
            gltf = json.loads(data[20:20 + n])
            size, kind = struct.unpack_from('<I4s', data, 20 + n)
            assert kind == b'BIN\0' and 28 + n + size == len(data)
            binary = data[28 + n:]
            assert all('uri' not in buffer for buffer in gltf['buffers'])
            assert gltf.get('images') and all('bufferView' in im and 'uri' not in im for im in gltf['images'])
            assert any(m.get('pbrMetallicRoughness', {}).get('baseColorTexture') for m in gltf['materials'])
            assert not gltf.get('cameras') and 'KHR_lights_punctual' not in gltf.get('extensions', {})
            for im in gltf['images']:
                view = gltf['bufferViews'][im['bufferView']]
                offset = view.get('byteOffset', 0)
                assert binary[offset:offset + 8] == b'\x89PNG\r\n\x1a\n'
                w, h = struct.unpack_from('>II', binary, offset + 16)
                assert w <= 192 and h <= 64
            points, triangles = geometry(gltf, binary)
            assert triangles == entry['triangles'] <= 30000
            assert len(gltf['meshes']) == entry['runtime_mesh_nodes'] <= 7 and len(gltf['materials']) == entry['material_count'] <= 7
            lo, hi = ([min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)])
            actual = {'min': [lo[0], -hi[2], lo[1]], 'max': [hi[0], -lo[2], hi[1]]}
            for key, values in actual.items():
                assert all(abs(v - w) <= .002 for v, w in zip(values, entry['physical_bounds_m'][key])), (asset, key)
            extent = [actual['max'][i] - actual['min'][i] for i in range(3)]
            assert all(v <= cap + .003 for v, cap in zip(extent, recipe['CAPS'])) and abs(lo[1]) <= .002, (asset, extent)
            assert any(any(v > 0 for v in m.get('emissiveFactor', [])) for m in gltf['materials'])
            preview = Path(candidate['preview']).resolve()
            assert preview.is_relative_to(output / 'previews') and preview.is_file()
        assert total < 8 * 1024 * 1024, (level, total)
        print(f'PASS real {level} seven-piece source/GLB provenance, geometry, textures and {total} bytes')
    print('NOT VALIDATED: source reopening/editability, reference/render fidelity, game staging, hero loops or traversal')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate-root', type=Path)
    parser.add_argument('--level', choices=recipe['LEVEL_IDS'])
    opts = parser.parse_args()
    check()
    if opts.candidate_root:
        check_candidates(opts.candidate_root.resolve(), [opts.level] if opts.level else recipe['LEVEL_IDS'])
