"""Direct, stdlib-only authored art contract: python3 tests/test_art.py."""
import hashlib
import json
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {'crawler', 'worker', 'impact_tool', 'rivet_pistol', 'skin_bell',
            'siphon_heart', 'ribbed_wall', 'conduit', 'arch', 'floor', 'grate', 'wall',
            'vault_span', 'lumen_sconce', 'witness_relief', 'suspended_cadaver',
            'containment_capsule', 'drain_altar', 'vertebral_furnace', 'marrow_crucible',
            'walking_bone_organ', 'ossified_palanquin', 'caster', 'scattergun'}
SCENERY = {'vault_span': (8, 1.2, 6), 'lumen_sconce': (1, .6, 2),
           'witness_relief': (3.5, .8, 4.8), 'suspended_cadaver': (2, 2, 3),
           'containment_capsule': (2.2, 1.8, 5), 'drain_altar': (3, 2.2, 1.7),
           'skin_bell': (7, 7, 9), 'siphon_heart': (6, 6, 5),
           'vertebral_furnace': (8, 6, 9), 'marrow_crucible': (8, 6, 5),
           'walking_bone_organ': (8, 6, 9), 'ossified_palanquin': (8, 6, 6)}
FOUNDRY = {'vertebral_furnace', 'marrow_crucible'}
PROCESSIONAL = {'walking_bone_organ', 'ossified_palanquin'}
PROCESSIONAL_ASSETS = PROCESSIONAL | {'caster', 'scattergun'}


def world_geometry(gltf, binary):
    """Read the real exported vertices, not just the manifest's claimed bounds."""
    points, triangles, materials = [], 0, []
    for node in gltf['nodes']:
        if 'mesh' not in node:
            continue
        assert not node.get('children') and 'matrix' not in node
        assert node.get('rotation', [0, 0, 0, 1]) == [0, 0, 0, 1]
        scale, offset = node.get('scale', [1] * 3), node.get('translation', [0] * 3)
        primitives = gltf['meshes'][node['mesh']]['primitives']
        assert len(primitives) == 1, 'runtime mesh must be merged by material'
        for primitive in primitives:
            a = gltf['accessors'][primitive['attributes']['POSITION']]
            view = gltf['bufferViews'][a['bufferView']]
            assert a['componentType'] == 5126 and a['type'] == 'VEC3'
            start = view.get('byteOffset', 0) + a.get('byteOffset', 0)
            for i in range(a['count']):
                p = struct.unpack_from('<3f', binary, start + i * view.get('byteStride', 12))
                points.append(tuple(p[j] * scale[j] + offset[j] for j in range(3)))
            triangles += gltf['accessors'][primitive['indices']]['count'] // 3
            materials.append(primitive['material'])
    assert len(materials) == len(set(materials)), 'one runtime mesh per material'
    return points, triangles


def png(path):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    pos, compressed, size = 8, bytearray(), None
    while pos < len(data):
        length = struct.unpack_from('>I', data, pos)[0]
        kind, payload = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + length]
        crc = struct.unpack_from('>I', data, pos + 8 + length)[0]
        assert zlib.crc32(kind + payload) & 0xffffffff == crc, path
        if kind == b'IHDR':
            w, h, depth, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', payload)
            assert (depth, color, compression, filtering, interlace) == (8, 6, 0, 0, 0), path
            size = (w, h)
        elif kind == b'IDAT':
            compressed.extend(payload)
        pos += 12 + length
        if kind == b'IEND':
            break
    assert size, path
    w, h = size
    raw, stride = zlib.decompress(compressed), w * 4
    assert len(raw) == h * (stride + 1), path
    # The source-owned PNG writer emits unfiltered RGBA rows.
    assert all(raw[y * (stride + 1)] == 0 for y in range(h)), path
    rows = [raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)] for y in range(h)]
    return size, b''.join(rows)


def check():
    path = ROOT / 'source/art/manifest.json'
    assert path.is_file(), 'required art manifest absent (intended RED)'
    manifest = json.loads(path.read_text())
    assert manifest['schema_version'] == 1
    assets = manifest['assets']
    assert {a['id'] for a in assets} == EXPECTED, 'four Processional assets required: walking_bone_organ, ossified_palanquin, caster, scattergun (intended RED)'
    assert len(assets) == len(EXPECTED)
    assert len(manifest['palette']) >= 4
    owned_outputs = set()
    scenery_bytes = foundry_bytes = processional_bytes = 0
    for a in assets:
        assert a['provenance']['method'] == 'original Blender geometry and authored pixel textures'
        source = ROOT / a['source']
        assert source.is_relative_to(ROOT / 'source/art') and source.suffix == '.blend'
        assert source.is_file() and source.read_bytes()[:7] == b'BLENDER', a['id']
        assert hashlib.sha256(source.read_bytes()).hexdigest() == a['source_sha256'], a['id']
        if a['id'] in PROCESSIONAL_ASSETS:
            recipe = 'tools/build_processional_art.py'
            assert a['recipe_sha256'] == hashlib.sha256((ROOT / recipe).read_bytes()).hexdigest()
            assert a['provenance']['authoring_script'] == recipe
            assert a['recipe_dependencies'] == {helper: hashlib.sha256((ROOT / helper).read_bytes()).hexdigest()
                                                 for helper in ('tools/build_art.py', 'tools/build_foundry_art.py')}
        for output in a['outputs']:
            file = ROOT / output['path']
            assert file.is_relative_to(ROOT / 'game/assets/art')
            assert file.is_file(), file
            assert file not in owned_outputs, file
            owned_outputs.add(file)
            assert hashlib.sha256(file.read_bytes()).hexdigest() == output['sha256'], file
            if file.suffix == '.png':
                size, pixels = png(file)
                assert list(size) == output['dimensions'], file
                if a['id'] in ('crawler', 'worker', 'impact_tool', 'rivet_pistol', 'caster', 'scattergun'):
                    assert 0 in pixels[3::4] and 255 in pixels[3::4], file
                    assert set(pixels[3::4]) == {0, 255}, 'sprite edges must be pixel-crisp'
                    cw, ch = a['cell_size']
                    enemy = a['id'] in ('crawler', 'worker', 'caster')
                    rows = len(a['frames']) if enemy else 1
                    assert size == (a['columns'] * cw, rows * ch)
                    assert a['filter'] == 'nearest'
                    assert a['origin_px'] == ([cw // 2, ch - 8] if enemy else [160, 200])
                    cells = []
                    for frame in range(rows):
                        for column in range(a['columns']):
                            cell = b''.join(pixels[((frame * ch + y) * size[0] + column * cw) * 4:((frame * ch + y) * size[0] + (column + 1) * cw) * 4] for y in range(ch))
                            assert sum(v != 0 for v in cell[3::4]) >= 80, (a['id'], column, frame)
                            if enemy:
                                bottom = max(y for y in range(ch) if any(cell[(y * cw + x) * 4 + 3] for x in range(cw)))
                                assert bottom == 119, 'every enemy pose must meet its documented baseline'
                            cells.append(cell)
                    if enemy:
                        for column in range(a['columns']):
                            assert len(set(cells[column::a['columns']])) == rows, 'enemy poses cannot be duplicate cells'
                        if a['id'] == 'caster':
                            assert len(set(cells)) == 40, 'all caster directions and poses must be distinct'
                            for cell in cells[-8:]:
                                top = min(y for y in range(ch) if any(cell[(y * cw + x) * 4 + 3] for x in range(cw)))
                                assert top >= 64, 'dead caster must visibly collapse'
                    else:
                        if a['id'] == 'scattergun':
                            assert not any(pixels[3:24 * size[0] * 4:4]), 'scattergun must stay below central aim'
                        assert len(set(cells)) == len(a['frames']), 'weapon poses cannot be duplicate cells'
            elif file.suffix == '.glb':
                assert 'gltf/embedded_image_handling=3' in file.with_suffix('.glb.import').read_text(), 'Godot must keep authored images embedded'
                data = file.read_bytes()
                magic, version, length = struct.unpack_from('<4sII', data)
                assert (magic, version, length) == (b'glTF', 2, len(data)), file
                n, kind = struct.unpack_from('<I4s', data, 12)
                assert kind == b'JSON'
                gltf = json.loads(data[20:20 + n])
                assert gltf['asset']['version'] == '2.0' and gltf.get('meshes') and gltf.get('nodes'), file
                assert gltf.get('materials') and gltf.get('buffers'), file
                assert all('uri' not in buf for buf in gltf['buffers']), 'GLB must be self-contained'
                for mesh in gltf['meshes']:
                    for primitive in mesh['primitives']:
                        assert 'POSITION' in primitive['attributes']
                assert a['triangles'] < 50000 and a['physical_bounds_m']['size'][2] > 0, a['id']
                if a['id'] in SCENERY:
                    if a['id'] in FOUNDRY:
                        foundry_bytes += len(data)
                        recipe = 'tools/build_foundry_art.py'
                        assert a['recipe_sha256'] == hashlib.sha256((ROOT / recipe).read_bytes()).hexdigest()
                        assert a['provenance']['authoring_script'] == recipe
                        assert a['recipe_dependencies'] == {'tools/build_art.py': manifest['build']['script_sha256']}
                        assert a['triangles'] <= 30000 and a['source_mesh_count'] >= 100
                        assert a['loop_id'] == ('foundry_loop_furnace' if a['id'] == 'vertebral_furnace' else 'foundry_loop_crucible')
                        assert gltf.get('images') and all('bufferView' in im and 'uri' not in im for im in gltf['images'])
                    elif a['id'] in PROCESSIONAL:
                        processional_bytes += len(data)
                        assert a['triangles'] <= 30000 and a['source_mesh_count'] >= 100
                        assert a['source_hierarchy_groups'] >= 4, 'editable hero assemblies required'
                        assert a['loop_id'] == ('processional_loop_organ' if a['id'] == 'walking_bone_organ' else 'processional_loop_palanquin')
                        assert a['facing'] == 'front Blender -Y; exported Godot +Z'
                        assert gltf.get('images') and all('bufferView' in im and 'uri' not in im for im in gltf['images'])
                    else:
                        scenery_bytes += len(data)
                        assert a['provenance']['authoring_script'] == 'tools/build_art.py'
                        assert a['recipe_sha256'] == manifest['build']['script_sha256']
                    binary_size, binary_kind = struct.unpack_from('<I4s', data, 20 + n)
                    assert binary_kind == b'BIN\x00'
                    points, triangles = world_geometry(gltf, data[28 + n:28 + n + binary_size])
                    assert triangles == a['triangles'] and triangles < 50000, a['id']
                    assert len(gltf['meshes']) == a['runtime_mesh_nodes'] <= 7
                    assert len(gltf['materials']) == a['material_count']
                    lo = [min(p[i] for p in points) for i in range(3)]
                    hi = [max(p[i] for p in points) for i in range(3)]
                    # Convert Y-up GLB bounds back to Blender XYZ for manifest parity.
                    actual_lo, actual_hi = [lo[0], -hi[2], lo[1]], [hi[0], -lo[2], hi[1]]
                    for key, values in [('min', actual_lo), ('max', actual_hi)]:
                        assert all(abs(v - w) <= .002 for v, w in zip(values, a['physical_bounds_m'][key])), (a['id'], key)
                    size = [actual_hi[i] - actual_lo[i] for i in range(3)]
                    assert all(v <= cap + .003 for v, cap in zip(size, SCENERY[a['id']])), (a['id'], size)
                    assert -.002 <= lo[1] <= .002, 'scenery must have a true ground origin'
                    assert any(any(v > 0 for v in m.get('emissiveFactor', [])) for m in gltf['materials']), a['id']
                    if a['id'] == 'vertebral_furnace':
                        assert size[2] >= 7.5 and size[2] > size[0], 'furnace needs a vertical spinal silhouette'
                    if a['id'] == 'marrow_crucible':
                        assert size[0] >= 6 and size[0] > size[2] * 1.4, 'crucible needs a broad pelvic silhouette'
                    if a['id'] == 'walking_bone_organ':
                        assert size[2] >= 7.2 and size[2] > size[0], 'organ needs tall staggered pipe silhouette'
                        assert a['features']['hollow_pipes'] >= 12 and a['features']['walking_legs'] == 6
                        assert a['features']['pedals'] >= 12 and a['features']['bellows_folds'] >= 12
                    if a['id'] == 'ossified_palanquin':
                        assert size[0] >= 6.6 and size[0] > size[2] * 1.25, 'palanquin needs broad conveyance silhouette'
                        assert a['features']['canopy_ribs'] >= 8 and a['features']['carrying_limbs'] == 6
                        assert a['features']['casket_leaves'] == 2 and a['features']['restraint_bands'] >= 6
                    if a['id'] == 'vault_span':
                        assert size[0] >= 7.95 and size[2] >= 5.95
                        assert all(abs(p[0]) >= 3.7 - .002 or p[1] >= 3.6 for p in points), 'vault hangs into capsule route'
                        assert all(abs(p[0]) >= 3.5 or p[1] >= 4 for p in points), 'vault must preserve the open 7m interior'
        if a['id'] in ('crawler', 'worker', 'caster'):
            assert a['columns'] == 8 and a['cell_size'] == [128, 128]
            assert a['frames'] == ['idle', 'walk_a', 'walk_b', 'attack', 'dead']
            assert a['yaw_degrees'] == list(range(0, 360, 45))
        if a['id'] in ('caster', 'scattergun'):
            assert a['pose_collections'] == a['frames']
            assert set(a['pose_mesh_counts']) == set(a['frames'])
            assert all(n >= (70 if a['id'] == 'caster' else 80) for n in a['pose_mesh_counts'].values())
            if a['id'] == 'caster':
                assert a['runtime_quad_height_m'] == 3.65
        if a['id'] in ('impact_tool', 'rivet_pistol', 'scattergun'):
            assert a['columns'] == 3 and a['cell_size'] == [320, 200]
            assert a['frames'] == ['idle', 'fire', 'recover']
    actual = {p for p in (ROOT / 'game/assets/art').rglob('*') if p.suffix in ('.png', '.glb')}
    assert actual == owned_outputs, 'manifest/output parity'
    assert foundry_bytes < 4 * 1024 * 1024, 'two Foundry GLBs exceed their runtime budget'
    assert processional_bytes < 4 * 1024 * 1024, 'two Processional GLBs exceed their runtime budget'
    assert scenery_bytes < 8 * 1024 * 1024, 'eight scenery GLBs exceed their runtime budget'
    assert hashlib.sha256((ROOT / 'tools/build_art.py').read_bytes()).hexdigest() == manifest['build']['script_sha256']
    print(f'PASS: {len(assets)} assets; {len(owned_outputs)} exports; PNG alpha/pose/dimensions, GLB structure, blend provenance and SHA-256 parity')


if __name__ == '__main__':
    check()
