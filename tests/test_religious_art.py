"""Stdlib candidate isolation; --candidate-root checks real parent-built outputs."""
import argparse
from contextlib import redirect_stderr
import hashlib
import io
import json
from pathlib import Path
import runpy
import struct
import tempfile

ROOT = Path(__file__).resolve().parents[1]
recipe = runpy.run_path(str(ROOT / 'tools/build_religious_art.py'))


def check():
    guard = recipe['candidate_roots']
    receipt = Path('/private/tmp/null-choir-religious-contract')
    assert guard(receipt / 'native', receipt, ROOT) == (receipt / 'native', receipt)
    for output, records in [(ROOT / 'source/art', ROOT),
                            (ROOT.parent, ROOT.parent),
                            (receipt / 'native', receipt / 'other')]:
        try:
            guard(output, records, ROOT)
        except ValueError:
            pass
        else:
            raise AssertionError('candidate destinations must reject production overlap and escaped output (intended RED)')
    with tempfile.TemporaryDirectory(prefix='religious-isolation-') as temp:
        records = Path(temp).resolve()
        native = records / 'native'
        native.mkdir()
        (native / 'source').symlink_to(ROOT / 'source', target_is_directory=True)
        try:
            guard(native, records, ROOT)
        except ValueError:
            pass
        else:
            raise AssertionError('candidate destinations must reject nested symlink escapes (intended RED)')
    for asset in recipe['IDS']:
        opts = recipe['arguments'](['--asset', asset, '--output-root', str(receipt / 'native'), '--receipt-root', str(receipt)])
        assert opts.asset == asset and opts.output_root == receipt / 'native' and opts.receipt_root == receipt
        assert callable(recipe[asset.removeprefix('intake_')])
    for argv in [[], ['--asset', recipe['IDS'][0]],
                 ['--asset', 'all', '--output-root', str(receipt / 'native'), '--receipt-root', str(receipt)]]:
        with redirect_stderr(io.StringIO()):
            try:
                recipe['arguments'](argv)
            except SystemExit as error:
                assert error.code == 2
            else:
                raise AssertionError('exactly one valid asset and both explicit roots are required')
    print('PASS static isolation, seven recipe entry points and explicit single-asset CLI')


def check_candidates(receipt_root):
    """Real GLB vertices use the authoritative existing reader, not a mock."""
    geometry = runpy.run_path(str(ROOT / 'tests/test_art.py'))['world_geometry']
    total, digests = 0, set()
    for asset in recipe['IDS']:
        candidate = json.loads((receipt_root / (asset + '_candidate.json')).read_text())
        entry = candidate['asset']
        output, _ = recipe['candidate_roots'](candidate['output_root'], receipt_root, ROOT)
        assert entry['id'] == asset and entry['tradition_aesthetic'] == recipe['TRADITIONS'][asset]
        assert entry['level_id'] == 'intake' and entry['loop_id'] is None
        assert entry['facing'] == 'front Blender -Y; exported Godot +Z'
        assert entry['provenance']['authoring_script'] == 'tools/build_religious_art.py'
        assert entry['recipe_sha256'] == hashlib.sha256((ROOT / 'tools/build_religious_art.py').read_bytes()).hexdigest()
        assert entry['recipe_dependencies'] == {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest()
                                                for p in ('tools/build_art.py', 'tools/build_foundry_art.py')}
        assert entry['reference_images'] == [{'path': p, 'sha256': h} for p, h in recipe['REFERENCES'].items()]
        for reference in entry['reference_images']:
            assert hashlib.sha256((ROOT / reference['path']).read_bytes()).hexdigest() == reference['sha256']
        source = (output / entry['source']).resolve()
        assert source.is_relative_to(output / 'source/art') and source.suffix == '.blend'
        source_data = source.read_bytes()
        assert source_data[:7] == b'BLENDER' and hashlib.sha256(source_data).hexdigest() == entry['source_sha256']
        assert candidate['source_hierarchy_groups'] == entry['source_hierarchy_groups'] >= 4
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
        length, kind = struct.unpack_from('<I4s', data, 12)
        assert kind == b'JSON'
        gltf = json.loads(data[20:20 + length])
        binary_size, binary_kind = struct.unpack_from('<I4s', data, 20 + length)
        assert binary_kind == b'BIN\0' and 28 + length + binary_size == len(data)
        assert all('uri' not in buf for buf in gltf['buffers'])
        assert gltf.get('images') and all('bufferView' in im and 'uri' not in im for im in gltf['images'])
        assert not gltf.get('cameras') and 'KHR_lights_punctual' not in gltf.get('extensions', {})
        binary = data[28 + length:]
        for image in gltf['images']:
            view = gltf['bufferViews'][image['bufferView']]
            start = view.get('byteOffset', 0)
            assert binary[start:start + 8] == b'\x89PNG\r\n\x1a\n'
            width, height = struct.unpack_from('>II', binary, start + 16)
            assert width <= 192 and height <= 64, 'compact embedded textures required'
        points, triangles = geometry(gltf, binary)
        assert triangles == entry['triangles']
        assert len(gltf['meshes']) == entry['runtime_mesh_nodes'] <= 7
        assert len(gltf['materials']) == entry['material_count'] <= 7
        lo, hi = ([min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)])
        actual = {'min': [lo[0], -hi[2], lo[1]], 'max': [hi[0], -lo[2], hi[1]]}
        for key, values in actual.items():
            assert all(abs(v - w) <= .002 for v, w in zip(values, entry['physical_bounds_m'][key])), (asset, key)
        size = [actual['max'][i] - actual['min'][i] for i in range(3)]
        assert all(v <= cap + .003 for v, cap in zip(size, recipe['CAPS'])), (asset, size)
        assert abs(lo[1]) <= .002, (asset, 'true ground origin')
        assert any(any(v > 0 for v in m.get('emissiveFactor', [])) for m in gltf['materials'])
        preview = Path(candidate['preview']).resolve()
        assert preview.is_relative_to(output / 'previews') and preview.is_file()
    assert total < 8 * 1024 * 1024 and len(digests) == 7
    print(f'PASS real seven-candidate GLB/source provenance, vertices, bounds, material merging, textures and {total} bytes')
    print('NOT VALIDATED: visual distinction, reference fidelity, source editability inspection or in-game staging/traversal')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate-root', type=Path)
    opts = parser.parse_args()
    check()
    if opts.candidate_root:
        check_candidates(opts.candidate_root.resolve())
