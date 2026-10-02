"""Source boundary checks and parent-only real atmosphere candidate validation."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import runpy
import shutil
import struct
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'tools/build_world_atmosphere_art.py'


def check():
    assert SOURCE.is_file(), 'Four atmosphere recipes and isolated frozen-root contract are missing (intended RED)'
    recipe = runpy.run_path(str(SOURCE))
    assert recipe['IDS'] == ('nursery_growth_vault', 'ossuary_sorting_vault', 'inversion_cosmic_membrane', 'heart_arterial_vault')
    assert recipe['CAPS'] == (12, 12, 4.2) and recipe['TRIANGLE_CAP'] == 22000 and recipe['MESH_CAP'] == 5
    assert recipe['ASSET_BYTE_CAP'] == 2 * 1024 * 1024 and recipe['GROUP_BYTE_CAP'] == 6 * 1024 * 1024
    assert all(callable(recipe[asset]) for asset in recipe['IDS'])
    assert callable(recipe.get('export_details')), 'Actual embedded-texture evidence reader is missing (intended RED)'
    try:
        recipe['export_details'](b'not a GLB')
    except (AssertionError, ValueError):
        pass
    else:
        raise AssertionError('reject malformed native GLB evidence')
    # A real PNG in a simulated GLB exercises container evidence only, never visual quality.
    png = (ROOT / recipe['ATLAS']).read_bytes()
    payload = {'buffers': [{'byteLength': len(png)}], 'bufferViews': [{'byteLength': len(png)}],
               'images': [{'name': 'fixture atlas', 'mimeType': 'image/png', 'bufferView': 0}]}
    encoded = json.dumps(payload).encode()
    encoded += b' ' * (-len(encoded) % 4)
    binary = png + b'\0' * (-len(png) % 4)
    data = struct.pack('<4sII', b'glTF', 2, 28 + len(encoded) + len(binary))
    data += struct.pack('<I4s', len(encoded), b'JSON') + encoded + struct.pack('<I4s', len(binary), b'BIN\0') + binary
    gltf, raw, textures = recipe['export_details'](data)
    assert raw[:len(png)] == png and gltf == payload
    assert textures == [{'name': 'fixture atlas', 'bytes': len(png), 'dimensions': [192, 64],
                         'sha256': hashlib.sha256(png).hexdigest()}]
    with tempfile.TemporaryDirectory(prefix='atmosphere-frozen-') as temp:
        base = Path(temp).resolve()
        project, receipt = base / 'frozen', base / 'receipts'
        output = receipt / 'native'
        for path in ('tools/build_world_atmosphere_art.py', *recipe['DEPENDENCIES'], recipe['REFERENCE'], 'source/art/manifest.json', 'game/assets/art/textures/surface_atlas.png'):
            target = project / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / path, target)
        asset = recipe['IDS'][0]
        assert recipe['preflight'](asset, output, receipt, project) == (output, receipt, project)
        opts = recipe['arguments'](['--asset', asset, '--project-root', str(project), '--output-root', str(output), '--receipt-root', str(receipt)])
        assert opts.project_root == project
        # Existing source/export/preview/record must never be overwritten.
        for tail in [output / 'source/art' / (asset + '.blend'), output / 'game/assets/art/world' / (asset + '.glb'),
                     output / 'previews' / (asset + '_preview.png'), output / 'previews/frames' / (asset + '_hero.png'),
                     receipt / (asset + '_candidate.json')]:
            tail.parent.mkdir(parents=True, exist_ok=True)
            tail.write_bytes(b'preserved candidate')
            try:
                recipe['preflight'](asset, output, receipt, project)
            except FileExistsError:
                pass
            else:
                raise AssertionError('refuse every existing candidate target before writes')
            assert tail.read_bytes() == b'preserved candidate'
            tail.unlink()
        ref = project / recipe['REFERENCE']
        data = ref.read_bytes()
        ref.write_bytes(b'bad reference')
        try:
            recipe['preflight'](asset, output, receipt, project)
        except ValueError:
            pass
        else:
            raise AssertionError('reject changed/missing selected image before native imports')
        ref.unlink()
        try:
            recipe['preflight'](asset, output, receipt, project)
        except ValueError:
            pass
        else:
            raise AssertionError('reject missing selected image')
        ref.write_bytes(data)
        atlas = project / 'game/assets/art/textures/surface_atlas.png'
        atlas_data = atlas.read_bytes()
        atlas.write_bytes(b'changed shared atlas')
        try:
            recipe['preflight'](asset, output, receipt, project)
        except ValueError:
            pass
        else:
            raise AssertionError('reject atlas/authoritative-manifest drift before candidate writes')
        atlas.write_bytes(atlas_data)
        (output / 'source/art').rmdir()
        (output / 'alternate').mkdir()
        (output / 'source/art').symlink_to(output / 'alternate', target_is_directory=True)
        try:
            recipe['preflight'](asset, output, receipt, project)
        except ValueError:
            pass
        else:
            raise AssertionError('reject internal symlink even without an escape')
        for destination, home in [(project / 'native', project), (ROOT / 'new-candidate', ROOT), (receipt / 'outside', receipt / 'inside')]:
            try:
                recipe['preflight'](asset, destination, home, project)
            except ValueError:
                pass
            else:
                raise AssertionError('protect both canonical and frozen project roots')
    print('PASS four frozen-root recipes, exact caps, reference gate, isolated/no-overwrite/symlink boundaries')



def check_candidates(receipt, project):
    """Validate real parent-built vertices/textures; appearance is not a source assertion."""
    recipe = runpy.run_path(str(project / 'tools/build_world_atmosphere_art.py'))
    geometry = runpy.run_path(str(project / 'tests/test_art.py'))['world_geometry']
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    dependencies = {path: sha(project / path) for path in recipe['DEPENDENCIES']}
    assert sha(project / recipe['REFERENCE']) == recipe['REFERENCE_SHA']
    manifest_data = (project / 'source/art/manifest.json').read_bytes()
    assert dependencies['tools/build_art.py'] == json.loads(manifest_data)['build']['script_sha256']
    digests, total = set(), 0
    for asset in recipe['IDS']:
        record = receipt / (asset + '_candidate.json')
        assert not record.is_symlink()
        candidate = json.loads(record.read_text())
        entry = candidate['asset']
        output_path = Path(candidate['output_root']).absolute()
        assert not any(p.is_symlink() for p in (output_path, *output_path.parents))
        output, _ = recipe['intake'].candidate_roots(output_path, receipt, project)
        recipe['intake'].candidate_roots(output, receipt, ROOT)
        assert candidate['project_root'] == str(project)
        assert sha(Path(candidate['source_root']) / recipe['RECIPE']) == entry['recipe_sha256']
        assert candidate['status'] == 'native_candidate_not_integrated'
        assert candidate['manifest_sha256_read'] == hashlib.sha256(manifest_data).hexdigest()
        assert entry['id'] == asset and entry['level_id'] == asset.split('_', 1)[0] and entry['loop_id'] is None
        assert entry['recipe_sha256'] == sha(project / recipe['RECIPE'])
        assert entry['recipe_dependencies'] == dependencies
        assert entry['reference_images'] == [{'path': recipe['REFERENCE'], 'sha256': recipe['REFERENCE_SHA']}]
        assert entry['machine_purpose'] == recipe['PURPOSES'][asset]
        assert entry['facing'] == 'front Blender -Y; exported Godot +Z' and entry['collision'].startswith('none;')
        assert entry['provenance']['authoring_script'] == recipe['RECIPE'] and not entry['provenance']['imports']
        assert entry['texture_dependencies'] == {recipe['ATLAS']: sha(project / recipe['ATLAS'])}
        # Strict path identity and leaf/ancestor symlink rejection cover every inspected product.
        source = output / 'source/art' / (asset + '.blend')
        exported = output / 'game/assets/art/world' / (asset + '.glb')
        preview = output / 'previews' / (asset + '_preview.png')
        for path in (source, exported, preview, output / recipe['ATLAS']):
            assert not any(p.is_symlink() for p in (path, *path.parents) if p.is_relative_to(output))
            assert path.resolve().is_relative_to(output) and path.is_file()
        assert entry['source'] == str(source.relative_to(output))
        with source.open('rb') as file:
            assert file.read(7) == b'BLENDER'
        assert sha(source) == entry['source_sha256']
        assert entry['source_hierarchy_groups'] == candidate['source_hierarchy_groups'] >= 4
        assert entry['assembly_names'] == candidate['assembly_names']
        assert len(set(entry['assembly_names'])) == len(entry['assembly_names']) == entry['source_hierarchy_groups']
        assert len(candidate['source_meshes']) == entry['source_mesh_count'] > entry['runtime_mesh_nodes']
        assert sum(m['triangles'] for m in candidate['source_meshes']) == entry['triangles'] <= recipe['TRIANGLE_CAP']
        assert sha(output / recipe['ATLAS']) == entry['texture_dependencies'][recipe['ATLAS']]
        assert len(entry['outputs']) == 1
        info = entry['outputs'][0]
        assert info['path'] == str(exported.relative_to(output))
        data = exported.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        assert digest == info['sha256'] and len(data) == info['bytes'] < recipe['ASSET_BYTE_CAP'] and digest not in digests
        digests.add(digest)
        total += len(data)
        assert len(data) <= candidate['four_module_bytes_after_export'] < recipe['GROUP_BYTE_CAP']
        gltf, binary, textures = recipe['export_details'](data)
        assert textures == candidate['embedded_textures']
        assert sum(t['bytes'] for t in textures) == candidate['embedded_texture_bytes']
        consumed = set()
        for mat in gltf['materials']:
            for texture in (mat.get('pbrMetallicRoughness', {}).get('baseColorTexture'), mat.get('emissiveTexture')):
                if texture:
                    consumed.add(gltf['textures'][texture['index']]['source'])
        assert consumed == set(range(len(gltf['images']))), 'All embedded original textures must be consumed'
        assert all(s.get('magFilter') == 9728 and s.get('minFilter') in (9728, 9984) for s in gltf['samplers'])
        assert not gltf.get('cameras') and not gltf.get('animations') and not gltf.get('skins')
        assert 'KHR_lights_punctual' not in gltf.get('extensionsUsed', [])
        assert all('camera' not in n and not n.get('extensions') for n in gltf['nodes'])
        assert len(gltf['meshes']) == entry['runtime_mesh_nodes'] <= recipe['MESH_CAP']
        assert len(gltf['materials']) == entry['material_count'] <= recipe['MESH_CAP']
        points, triangles = geometry(gltf, binary)
        assert points and all(math.isfinite(v) for p in points for v in p)
        assert triangles == entry['triangles'] <= recipe['TRIANGLE_CAP']
        lo, hi = ([min(p[i] for p in points) for i in range(3)], [max(p[i] for p in points) for i in range(3)])
        actual = {'min': [lo[0], -hi[2], lo[1]], 'max': [hi[0], -lo[2], hi[1]]}
        for key, values in actual.items():
            assert all(abs(v - w) <= .002 for v, w in zip(values, entry['physical_bounds_m'][key])), (asset, key)
        size = [actual['max'][i] - actual['min'][i] for i in range(3)]
        assert all(v <= cap + .00001 for v, cap in zip(size, recipe['CAPS'])) and abs(lo[1]) <= .002, (asset, size)
        assert abs(lo[0] + hi[0]) <= .002 and abs(lo[2] + hi[2]) <= .002, 'Actual horizontal origin must be centred'
        if asset in ('nursery_growth_vault', 'inversion_cosmic_membrane'):
            assert any(m.get('alphaMode', 'OPAQUE') == 'BLEND' for m in gltf['materials']), 'Real glass/membrane transparency required'
        assert candidate['preview'] == str(preview) and sha(preview) == candidate['preview_sha256']
        assert preview.read_bytes()[:8] == b'\x89PNG\r\n\x1a\n'
        print(f'PASS real {asset}: {triangles} triangles, {len(data)} bytes, {candidate["embedded_texture_bytes"]} texture bytes')
    assert total < recipe['GROUP_BYTE_CAP'], total
    print(f'PASS actual four-module group: {total} bytes below 6MiB')
    print('NOT VALIDATED: native reopening/editability, reference fidelity, world placement, clear combat lanes, runtime GPU/pacing')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate-root', type=Path)
    parser.add_argument('--project-root', type=Path, default=ROOT)
    opts = parser.parse_args()
    check()
    if opts.candidate_root:
        assert not any(p.is_symlink() for p in (opts.candidate_root.absolute(), *opts.candidate_root.absolute().parents,
                                               opts.project_root.absolute(), *opts.project_root.absolute().parents))
        check_candidates(opts.candidate_root.resolve(), opts.project_root.resolve())
