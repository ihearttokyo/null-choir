"""Direct, stdlib-only authored art contract: python3 tests/test_art.py."""
import hashlib
import json
import runpy
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
recipe_guard = runpy.run_path(str(ROOT / 'tools/art_recipe.py'))
resolve_recipe, validate_recipe = recipe_guard['resolve_recipe'], recipe_guard['validate_recipe']
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
RELIGIOUS_INTAKE = dict(zip(
    ('intake_throat_frame', 'intake_wheel_reservoir', 'intake_bound_gate',
     'intake_pressure_screen', 'intake_ascending_engine', 'intake_seven_lamps', 'intake_solar_seal'),
    ('Christian', 'Buddhist', 'Shinto', 'Islamic', 'Hindu', 'Jewish', 'ancient Egyptian')))
EXPECTED.update(RELIGIOUS_INTAKE)
SCENERY.update(dict.fromkeys(RELIGIOUS_INTAKE, (8, 6, 9)))
RELIGIOUS_FOUNDRY = dict(zip(
    ('foundry_cross_spine', 'foundry_slag_wheel', 'foundry_bound_furnace',
     'foundry_pressure_canopy', 'foundry_tower_cluster', 'foundry_lamp_manifold', 'foundry_solar_crucible'),
    ('Christian', 'Buddhist', 'Shinto', 'Islamic', 'Hindu', 'Jewish', 'ancient Egyptian')))
EXPECTED.update(RELIGIOUS_FOUNDRY)
SCENERY.update(dict.fromkeys(RELIGIOUS_FOUNDRY, (8, 6, 9)))
RELIGIOUS_PROCESSIONAL = dict(zip(
    ('processional_pipe_choir', 'processional_gong_carousel', 'processional_bound_drums',
     'processional_acoustic_canopy', 'processional_reed_chariot', 'processional_seven_reeds', 'processional_winged_sarcophagus'),
    ('Christian', 'Buddhist', 'Shinto', 'Islamic', 'Hindu', 'Jewish', 'ancient Egyptian')))
EXPECTED.update(RELIGIOUS_PROCESSIONAL)
SCENERY.update(dict.fromkeys(RELIGIOUS_PROCESSIONAL, (8, 6, 9)))
RELIGIOUS_RELIQUARY = dict(zip(
    ('reliquary_face_halo', 'reliquary_memory_wheel', 'reliquary_bound_gate', 'reliquary_cell_vault',
     'reliquary_tower_cluster', 'reliquary_seven_vessels', 'reliquary_winged_seal'),
    ('Christian', 'Buddhist', 'Shinto', 'Islamic', 'Hindu', 'Jewish', 'ancient Egyptian')))
EXPECTED.update(RELIGIOUS_RELIQUARY)
SCENERY.update(dict.fromkeys(RELIGIOUS_RELIQUARY, (8, 6, 9)))
RELIGIOUS_SETS = {'intake': RELIGIOUS_INTAKE, 'foundry': RELIGIOUS_FOUNDRY,
                  'processional': RELIGIOUS_PROCESSIONAL, 'reliquary': RELIGIOUS_RELIQUARY}
for level, suffixes in {
    'nursery': ('gestation_engine', 'seed_orrery', 'bound_gate', 'cell_canopy', 'tower_cluster', 'seven_vessels', 'winged_cradle'),
    'ossuary': ('rib_bridge', 'bone_mandala', 'bound_gate', 'cell_archive', 'tower_cluster', 'seven_reservoirs', 'winged_sarcophagus'),
    'inversion': ('surgical_cradle', 'tilted_gyroscope', 'bound_gate', 'cell_prism', 'tower_cluster', 'seven_vessels', 'winged_cradle'),
    'heart': ('mouth_restraint', 'pulse_mandala', 'bound_gate', 'cell_crown', 'tower_cluster', 'seven_reservoirs', 'winged_seal'),
}.items():
    RELIGIOUS_SETS[level] = dict(zip((level+'_'+s for s in suffixes), RELIGIOUS_INTAKE.values()))
    EXPECTED.update(RELIGIOUS_SETS[level])
    SCENERY.update(dict.fromkeys(RELIGIOUS_SETS[level], (8, 6, 9)))
LATE_WEAPONS = {'sawtooth_repeater', 'marrow_launcher', 'choir_disruptor'}
LATE_ROLES = {'brute', 'guardian', 'summoner'}
LATE_BOSSES = {'nursery_warden', 'choir_avatar'}
LATE_COMBAT = LATE_WEAPONS | LATE_ROLES | LATE_BOSSES
EXPECTED.update(LATE_COMBAT)
ATMOSPHERE = {'nursery_growth_vault', 'ossuary_sorting_vault', 'inversion_cosmic_membrane', 'heart_arterial_vault'}
EXPECTED.update(ATMOSPHERE)
EXPECTED.add('ammo_vfx')
CATHEDRAL = {'cathedral_vault_6m','cathedral_vault_9m','cathedral_cluster_pier',
             'cathedral_lancet_bay','cathedral_corner_rib','cathedral_skeletal_dado',
             'cathedral_brass_lamp','cathedral_inlay_tile','cathedral_kit_atlas'}
EXPECTED.update(CATHEDRAL)
EXPECTED.add('hud_kit')
SCENERY.update(dict.fromkeys(ATMOSPHERE, (12, 12, 4.2)))


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


def check_skin_bell_dimensions(declared, measured):
    assert len(declared) == len(measured) == 3
    assert all(type(v) in (int, float) and 0 < v <= cap + .003
               for v, cap in zip(measured, (6.48, 6.48, 8.2)))
    assert all(type(v) in (int, float) and abs(v - w) <= .002
               for v, w in zip(declared, measured))


def check_skin_bell_v2(a):
    assert a['id'] == 'skin_bell', 'v2 bell contract is identity-specific'
    validate_recipe(ROOT, a, 'tools/build_skin_bell_v2.py', ['tools/art_recipe.py'])
    assert a['provenance']['method'] == 'original image-derived editable geometry and authored opaque pixel atlas'
    assert a['source'] == 'source/art/skin_bell_v2.blend'
    source = ROOT / a['source']
    data = source.read_bytes()
    assert hashlib.sha256(data).hexdigest() == a['source_sha256']
    assert data[:7] == b'BLENDER'
    assert a['loop_id'] == 'intake_loop_bell'
    assert a['origin'] == 'ground-centered at Blender (0,0,0); GLB Y up'
    size = a['physical_bounds_m']['size']
    check_skin_bell_dimensions(size, size)
    references = [
        {'path': 'source/art/references/skin-bell-v2.png',
         'sha256': '93a7a08843e1cf8414c93513892f5ac621c4469095fd0a86f468adb0987d43be'},
        {'path': 'source/art/references/skin-bell-material-v3.png',
         'sha256': 'eed15e41ba0bf85de489dbe4e25364324e8ead8e33a333182edeca89077b6ac7'}]
    assert a['provenance']['references'] == references
    assert a['provenance']['reference_sha256'] == references[0]['sha256']
    assert a['provenance']['material_reference_sha256'] == references[1]['sha256']
    assert a['provenance']['reference_is_not_runtime_texture'] is True
    for reference in references:
        assert hashlib.sha256((ROOT / reference['path']).read_bytes()).hexdigest() == reference['sha256']
    assert len(a['outputs']) == 1 and a['outputs'][0]['path'] == 'game/assets/art/world/skin_bell.glb'
    output = a['outputs'][0]
    data = (ROOT / output['path']).read_bytes()
    assert len(data) == output['bytes'] and hashlib.sha256(data).hexdigest() == output['sha256']



def check_nursery_v2(a, blob):
    assert a['id'] == 'nursery_gestation_engine'
    assert all(type(a[key]) is int for key in ['source_mesh_count', 'source_hierarchy_groups', 'triangles', 'runtime_mesh_nodes', 'material_count'])
    script = 'tools/build_nursery_gestation_v2.py'
    validate_recipe(ROOT, a, script, ['tools/build_art.py', 'tools/art_recipe.py'])
    recipe = runpy.run_path(str(resolve_recipe(ROOT, script, a['recipe_sha256'])))
    assert a['recipe_dependencies'] == {key: recipe['PINS'][key] for key in ['tools/build_art.py', 'tools/art_recipe.py']}
    for logical, digest in recipe['PINS'].items():
        assert hashlib.sha256((ROOT / logical).read_bytes()).hexdigest() == digest
    assert a['source'] == 'source/art/nursery_gestation_engine_v2.blend'
    assert a['provenance']['image_derived'] is True
    original = {'path': 'source/art/nursery_gestation_engine.blend',
                'sha256': recipe['PINS']['source/art/nursery_gestation_engine.blend']}
    assert a['provenance']['original_source'] == original
    refs = [
        {'path': 'source/art/references/nursery-transparent-v2.png', 'sha256': recipe['REFERENCE_SHA']},
        {'path': 'source/art/references/nursery-membrane-wrap-v1.png', 'sha256': 'bd32fcb9a7019745663536466fa16d5daa6b74b55a62829175962f219f8bdfe0'},
        {'path': 'source/art/references/nursery-material-atlas-v2.png', 'sha256': recipe['MATERIAL_SHA']}]
    assert a['provenance']['references'] == refs
    assert a['provenance']['geometry_reference_sha256'] == refs[1]['sha256']
    assert a['provenance']['material_reference_sha256'] == refs[2]['sha256']
    for ref in refs:
        assert hashlib.sha256((ROOT / ref['path']).read_bytes()).hexdigest() == ref['sha256']
    geometry = recipe['geometry_report'](recipe['build_parts']())
    assert a['source_mesh_count'] == geometry['editable_meshes'] == 227
    assert a['source_hierarchy_groups'] == 4
    assert a['assembly_names'] == ['Editable architecture', 'Editable vessel', 'Editable anatomy', 'Editable controls']
    assert len(a['outputs']) == 1 and a['outputs'][0]['path'] == 'game/assets/art/world/nursery_gestation_engine.glb'
    output = a['outputs'][0]
    assert len(blob) == output['bytes'] < 1813732 and hashlib.sha256(blob).hexdigest() == output['sha256']
    low, high = geometry['bounds']
    for key, expected in [('min', low), ('max', high), ('size', [high[i]-low[i] for i in range(3)])]:
        declared = a['physical_bounds_m'][key]
        assert type(declared) is list and len(declared) == 3
        assert all(type(v) in (int, float) and abs(v-w) <= .002 for v, w in zip(declared, expected))
    y_up = [[low[0], low[2], -high[1]], [high[0], high[2], -low[1]]]
    report = recipe['inspect_glb'](blob, y_up)
    assert report['triangles'] == a['triangles'] == geometry['triangles'] <= 20000
    assert report['groups'] == a['runtime_mesh_nodes'] == a['material_count'] == 5
    assert a['texture_dependencies'] == {}, 'runtime atlas is embedded, not duplicated'
    doc, binary = recipe['unpack_glb'](blob)
    view = doc['bufferViews'][doc['images'][0]['bufferView']]
    offset = view.get('byteOffset', 0)
    atlas = binary[offset:offset + view['byteLength']]
    assert a['atlas']['embedded'] is True
    assert a['atlas'] == {'embedded': True, 'size': [512, 512],
                          'sha256': hashlib.sha256(atlas).hexdigest(), 'sampling': 'nearest/no-mip'}


def check():
    path = ROOT / 'source/art/manifest.json'
    assert path.is_file(), 'required art manifest absent (intended RED)'
    manifest = json.loads(path.read_text())
    assert manifest['schema_version'] == 1
    assets = manifest['assets']
    assert {a['id'] for a in assets} == EXPECTED, 'original assets, all56 religious pieces, eight native late combat identities and four atmosphere modules required (intended RED)'
    assert len(assets) == len(EXPECTED)
    assert len(manifest['palette']) >= 4
    owned_outputs = set()
    scenery_bytes = foundry_bytes = processional_bytes = atmosphere_bytes = 0
    religious_bytes = dict.fromkeys(RELIGIOUS_SETS, 0)
    for a in assets:
        nursery_v2 = a['id'] == 'nursery_gestation_engine' and a['provenance']['authoring_script'] == 'tools/build_nursery_gestation_v2.py'
        skin_bell_v2 = a['id'] == 'skin_bell' and a['provenance']['authoring_script'] == 'tools/build_skin_bell_v2.py'
        if skin_bell_v2:
            check_skin_bell_v2(a)
        else:
            assert a['provenance']['method'] == ('original primitive Blender geometry and editable procedural material nodes' if a['id']=='rivet_pistol' and a['provenance']['authoring_script']=='tools/build_rivet_pistol_v2.py' else 'Original modeled geometry and deterministic authored texture atlas' if a['id'] in CATHEDRAL else 'original sculpted Blender geometry, native CPU orthographic render' if a['id']=='hud_kit' else 'original editable Blender geometry and packed authored PBR textures' if a['id']=='conduit' else 'original Blender geometry and authored pixel textures')
        resolve_recipe(ROOT, a['provenance']['authoring_script'], a['recipe_sha256'])
        for helper, digest in a.get('recipe_dependencies', {}).items():
            resolve_recipe(ROOT, helper, digest)
        if a['id']=='rivet_pistol' and a['provenance']['authoring_script']=='tools/build_rivet_pistol_v2.py':
            validate_recipe(ROOT, a, 'tools/build_rivet_pistol_v2.py', ['tools/build_art.py'])
            assert a['source']=='source/art/rivet_pistol_v2.blend' and a['frames']==['idle','fire','recover']
            assert a['provenance']['references']==[{'path':'source/art/references/rivet-pistol-reference-v2.png', 'sha256':'246d6f6b39d252115465feac28832664285686567f1612db9df9301cfeff8e15'}]
            for reference in a['provenance']['references']:
                assert hashlib.sha256((ROOT/reference['path']).read_bytes()).hexdigest()==reference['sha256']
        if a['id'] == 'conduit':
            validate_recipe(ROOT, a, 'tools/build_conduit_art.py', ['tools/build_art.py'])
            references = runpy.run_path(str(ROOT / 'tools/build_conduit_art.py'))['REFERENCE_PINS']
            assert a['provenance']['references'] == [{'path': 'source/art/references/' + name, 'sha256': pin}
                                                    for name, pin in references.items()]
            for reference in a['provenance']['references']:
                assert hashlib.sha256((ROOT / reference['path']).read_bytes()).hexdigest() == reference['sha256']
        source = ROOT / a['source']
        assert source.is_relative_to(ROOT / 'source/art') and source.suffix == '.blend'
        assert source.is_file() and (skin_bell_v2 or source.read_bytes()[:7] == b'BLENDER'), a['id']
        assert hashlib.sha256(source.read_bytes()).hexdigest() == a['source_sha256'], a['id']
        if a['id'] in LATE_COMBAT:
            recipe = 'tools/build_late_combat_art.py'
            assert a['provenance']['authoring_script'] == recipe
            assert set(a['recipe_dependencies']) == set(('tools/build_art.py', 'tools/build_foundry_art.py', 'tools/build_processional_art.py', 'tools/build_religious_art.py'))
            assert len(a['reference_images']) == 1
            reference = a['reference_images'][0]
            assert (ROOT / reference['path']).resolve().is_relative_to((ROOT / 'source/art/references').resolve())
            assert hashlib.sha256((ROOT / reference['path']).read_bytes()).hexdigest() == reference['sha256']
            assert a['pose_collections'] == a['frames'] and set(a['pose_mesh_counts']) == set(a['frames'])
            assert all(count >= 50 for count in a['pose_mesh_counts'].values())
            cap = 18000 if a['id'] in LATE_WEAPONS else 24000 if a['id'] in LATE_BOSSES else 16000
            assert set(a['pose_triangles']) == set(a['frames']) and all(0 < count <= cap for count in a['pose_triangles'].values())
        if a['id'] in PROCESSIONAL_ASSETS:
            recipe = 'tools/build_processional_art.py'
            assert a['provenance']['authoring_script'] == recipe
            assert set(a['recipe_dependencies']) == set(('tools/build_art.py', 'tools/build_foundry_art.py'))
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
                if a['id'] in ('crawler', 'worker', 'impact_tool', 'rivet_pistol', 'caster', 'scattergun') or a['id'] in LATE_COMBAT:
                    assert 0 in pixels[3::4] and 255 in pixels[3::4], file
                    assert set(pixels[3::4]) == {0, 255}, 'sprite edges must be pixel-crisp'
                    cw, ch = a['cell_size']
                    enemy = a['id'] in ('crawler', 'worker', 'caster') or a['id'] in LATE_ROLES | LATE_BOSSES
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
                                assert bottom == (247 if a['id'] in LATE_BOSSES else 119), 'every enemy pose must meet its documented baseline'
                            cells.append(cell)
                    if enemy:
                        for column in range(a['columns']):
                            assert len(set(cells[column::a['columns']])) == rows, 'enemy poses cannot be duplicate cells'
                        if a['id'] == 'caster' or a['id'] in LATE_ROLES | LATE_BOSSES:
                            assert len(set(cells)) == 40, 'all caster directions and poses must be distinct'
                            for cell in cells[-8:]:
                                top = min(y for y in range(ch) if any(cell[(y * cw + x) * 4 + 3] for x in range(cw)))
                                assert top >= ch // 2, 'dead character must visibly collapse'
                    else:
                        if a['id'] == 'scattergun' or a['id'] in LATE_WEAPONS:
                            assert not any(pixels[3:24 * size[0] * 4:4]), 'scattergun must stay below central aim'
                        assert len(set(cells)) == len(a['frames']), 'weapon poses cannot be duplicate cells'
                    if a['id'] in LATE_COMBAT:
                        byte_cap = 256*1024 if a['id'] in LATE_WEAPONS else 2*1024*1024 if a['id'] in LATE_BOSSES else 512*1024
                        assert file.stat().st_size == output['bytes'] <= byte_cap
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
                    if any(a['id'] in pieces for pieces in RELIGIOUS_SETS.values()):
                        level = a['level_id']
                        assert level in RELIGIOUS_SETS and a['id'] in RELIGIOUS_SETS[level]
                        traditions = RELIGIOUS_SETS[level]
                        religious_bytes[level] += len(data)
                        recipe = {'intake': 'tools/build_religious_art.py', 'foundry': 'tools/build_religious_foundry_art.py',
                                  'processional': 'tools/build_religious_processional_art.py',
                                  **dict.fromkeys(('reliquary', 'nursery', 'ossuary', 'inversion', 'heart'), 'tools/build_religious_late_art.py')}[level]
                        if nursery_v2:
                            check_nursery_v2(a, data)
                            recipe = 'tools/build_nursery_gestation_v2.py'
                        assert a['provenance']['authoring_script'] == recipe
                        helpers = ['tools/build_art.py', 'tools/build_foundry_art.py']
                        if level != 'intake':
                            helpers.append('tools/build_religious_art.py')
                        if level not in ('intake', 'foundry'):
                            helpers.extend(['tools/build_processional_art.py', 'tools/build_religious_foundry_art.py'])
                        if nursery_v2: helpers = ['tools/build_art.py', 'tools/art_recipe.py']
                        assert set(a['recipe_dependencies']) == set(helpers)
                        assert a['tradition_aesthetic'] == traditions[a['id']] and a['level_id'] == level
                        assert a['loop_id'] == {'reliquary_face_halo': 'reliquary_loop_halo',
                                                'reliquary_memory_wheel': 'reliquary_loop_wheel',
                                                'nursery_gestation_engine': 'nursery_loop_gestation', 'nursery_seed_orrery': 'nursery_loop_seeds',
                                                'ossuary_rib_bridge': 'ossuary_loop_transport', 'ossuary_bone_mandala': 'ossuary_loop_mandala',
                                                'inversion_surgical_cradle': 'inversion_loop_clamps', 'inversion_tilted_gyroscope': 'inversion_loop_gyroscope',
                                                'heart_mouth_restraint': 'heart_loop_restraint', 'heart_pulse_mandala': 'heart_loop_pulse'}.get(a['id'])
                        assert a['triangles'] <= 30000 and a['source_hierarchy_groups'] >= 4
                        assert len(set(a['assembly_names'])) == a['source_hierarchy_groups']
                        assert a['facing'] == 'front Blender -Y; exported Godot +Z'
                        assert a['reference_images']
                        for reference in a['reference_images']:
                            path = ROOT / reference['path']
                            assert path.resolve().is_relative_to((ROOT / 'source/art/references').resolve())
                            assert hashlib.sha256(path.read_bytes()).hexdigest() == reference['sha256']
                        assert gltf.get('images') and all('bufferView' in im and 'uri' not in im for im in gltf['images'])
                    elif a['id'] in ATMOSPHERE:
                        atmosphere_bytes += len(data)
                        recipe = 'tools/build_world_atmosphere_art.py'
                        assert a['provenance']['authoring_script'] == recipe
                        assert set(a['recipe_dependencies']) == set(('tools/build_art.py', 'tools/build_foundry_art.py', 'tools/build_religious_art.py'))
                        assert a['level_id'] == a['id'].split('_', 1)[0] and a['loop_id'] is None
                        assert a['triangles'] <= 22000 and a['runtime_mesh_nodes'] <= 5 and a['material_count'] <= 5
                        assert a['source_hierarchy_groups'] >= 4 and len(set(a['assembly_names'])) == a['source_hierarchy_groups']
                        assert len(data) == output['bytes'] < 2 * 1024 * 1024
                        assert a['facing'] == 'front Blender -Y; exported Godot +Z' and a['collision'].startswith('none;')
                        expected_reference = ('source/art/references/inversion-cavity-02.png',
                                              '8f3363b3643660733b13e4b76ee9029ccdfa088a97191a106c68248ce7da125e') if a['id'] == 'inversion_cosmic_membrane' else (
                                              'source/art/references/world-polish-late-01.png',
                                              'f779257d54a32b0d702193b79beceee63df0d96b54f2988a5899e457670dc9a7')
                        assert a['reference_images'] == [{'path': expected_reference[0], 'sha256': expected_reference[1]}]
                        for reference in a['reference_images']:
                            assert hashlib.sha256((ROOT / reference['path']).read_bytes()).hexdigest() == reference['sha256']
                        assert gltf.get('images') and all('bufferView' in im and 'uri' not in im for im in gltf['images'])
                        assert not gltf.get('cameras') and not gltf.get('animations') and not gltf.get('skins')
                        assert 'KHR_lights_punctual' not in gltf.get('extensionsUsed', [])
                        assert all(s.get('magFilter') == 9728 and s.get('minFilter') in (9728, 9984) for s in gltf['samplers'])
                    elif a['id'] in FOUNDRY:
                        foundry_bytes += len(data)
                        recipe = 'tools/build_foundry_art.py'
                        assert a['provenance']['authoring_script'] == recipe
                        assert set(a['recipe_dependencies']) == {'tools/build_art.py'}
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
                        assert a['provenance']['authoring_script'] == ('tools/build_skin_bell_v2.py' if skin_bell_v2 else 'tools/build_art.py')
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
                    if skin_bell_v2: check_skin_bell_dimensions(a['physical_bounds_m']['size'], size)
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
        if a['id'] in ('crawler', 'worker', 'caster') or a['id'] in LATE_ROLES | LATE_BOSSES:
            cell = 256 if a['id'] in LATE_BOSSES else 128
            assert a['columns'] == 8 and a['cell_size'] == [cell, cell]
            assert a['frames'] == ['idle', 'walk_a', 'walk_b', 'attack', 'dead']
            assert a['yaw_degrees'] == list(range(0, 360, 45))
        if a['id'] in ('caster', 'scattergun'):
            assert a['pose_collections'] == a['frames']
            assert set(a['pose_mesh_counts']) == set(a['frames'])
            assert all(n >= (70 if a['id'] == 'caster' else 80) for n in a['pose_mesh_counts'].values())
            if a['id'] == 'caster':
                assert a['runtime_quad_height_m'] == 3.65
        if a['id'] in ('impact_tool', 'rivet_pistol', 'scattergun') or a['id'] in LATE_WEAPONS:
            assert a['columns'] == 3 and a['cell_size'] == [320, 200]
            assert a['frames'] == ['idle', 'fire', 'recover']
    actual = {p for p in (ROOT / 'game/assets/art').rglob('*') if p.suffix in ('.png', '.glb')}
    actual.add(ROOT / 'game/assets/art/hud/hud_kit.json')
    assert actual == owned_outputs, 'manifest/output parity'
    assert foundry_bytes < 4 * 1024 * 1024, 'two Foundry GLBs exceed their runtime budget'
    assert processional_bytes < 4 * 1024 * 1024, 'two Processional GLBs exceed their runtime budget'
    assert all(total < 8 * 1024 * 1024 for total in religious_bytes.values()), 'seven religious-aesthetic GLBs in a level exceed their runtime budget'
    assert atmosphere_bytes < 6 * 1024 * 1024, 'four atmosphere GLBs exceed their independent runtime budget'
    assert scenery_bytes < 8 * 1024 * 1024, 'eight scenery GLBs exceed their runtime budget'
    assert hashlib.sha256((ROOT / 'tools/build_art.py').read_bytes()).hexdigest() == manifest['build']['script_sha256']
    print(f'PASS: {len(assets)} assets; {len(owned_outputs)} exports; PNG alpha/pose/dimensions, GLB structure, blend provenance and SHA-256 parity')


if __name__ == '__main__':
    check()
