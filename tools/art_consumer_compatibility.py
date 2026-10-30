"""One exact later consumer generation; retained native art receipts stay historical.

Hash-bound receipts are evidence joins, not authentication of a run or an art grade.
Never normalize a foreign consumer or infer fresh fullmatrix/ABA/gate-open proof.
"""
import hashlib
import json
from pathlib import Path
import re
import stat
import contextvars

# A successful audit may skip expensive parsing only after its complete strict
# byte-read footprint and producer PNG directory membership are replayed.
_QUALIFY96_READS = contextvars.ContextVar('qualification96_reads', default=None)

def _observe96(root, relative, data):
    observed = _QUALIFY96_READS.get()
    if observed is not None:
        if str(Path(root).absolute()) != observed['root']:
            raise ValueError('Qualification dependency escaped its exact root')
        row = (len(data), hashlib.sha256(data).hexdigest())
        prior = observed['files'].setdefault(relative, row)
        if prior != row:
            raise ValueError('Dependency changed during qualification: ' + relative)
    return data

def _observe_png_directory96(root, relative):
    observed = _QUALIFY96_READS.get()
    if observed is not None:
        observed['directories'][relative] = tuple(sorted(
            p.name for p in (Path(root) / relative).glob('*.png')))


def _observe_source_directory97(root):
    observed = _QUALIFY96_READS.get()
    if observed is not None:
        observed.setdefault('source_directories', {})['game/scripts'] = tuple(sorted(
            path.name for path in (Path(root) / 'game/scripts').glob('*.gd')))

RECEIPT = 'source/art/consumer-qualification-v0094/current-consumers.json'
RECEIPT_SHA = 'dad9f63a2c5eb0c73b139186deb9a74990b118f8b38b85cda1f2ac97642060d4'
RECEIPT95 = 'source/art/consumer-qualification-v0095/current-consumers.json'
RECEIPT95_SHA = '09a4f0e50e5e000ab26a1156bba4da7a781af5ac2cfac8f8c31911d70558486e'
SEAMS = {'main': ['unlock_door', '_has_keys'], 'hud': ['_draw'],
         'level': ['_build_gate', 'open_door', 'refresh_gate_presentations', '_build_surface_patch'],
         'enemy': ['visual_hit_sprite', '_try_worker_clutch']}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read_resident(root, relative):
    root = Path(root).absolute()
    path = root / relative
    if relative.startswith('/') or '..' in Path(relative).parts or not relative.startswith(('game/', 'source/')):
        raise ValueError('Exact public source reference required')
    if any(p.is_symlink() for p in (path, *path.parents)):
        raise ValueError('No symlink consumer/provenance')
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or getattr(info, 'st_flags', 0) & 0x40000000:
        raise ValueError('Regular resident consumer/provenance only')
    return _observe96(root, relative, path.read_bytes())


def record(root, row):
    if type(row) is not dict or set(row) != {'path', 'bytes', 'sha256'} or type(row['bytes']) is not int:
        raise ValueError('Typed exact consumer record required')
    data = read_resident(root, row['path'])
    if len(data) != row['bytes'] or sha(data) != row['sha256']:
        raise ValueError('Exact qualified consumer/asset/provenance drift: ' + row['path'])
    return data


def function(text, name):
    match = re.search(r'(?ms)^func ' + re.escape(name) + r'\([^\n]*\n.*?(?=^func |\Z)', text)
    if not match:
        raise ValueError('Required retained consumer seam missing: ' + name)
    return match.group(0)


def pinned_receipt(root, path, expected):
    raw = read_resident(root, path)
    if sha(raw) != expected:
        raise ValueError('Exact current-consumer receipt required; missing/stale/rehashed receipts refused')
    return json.loads(raw)


def qualify(root):
    parent = pinned_receipt(root, RECEIPT, RECEIPT_SHA)
    value = parent
    # The hard pin binds every field, frame inventory, scope limitation and raw
    # private-evidence hash. No paths/argv/HOME or private quality numbers copied.
    if (value['schema'] != 'null-choir-exact-current-art-consumers-v0094-v1'
            or value['status'] != 'ACTUAL_ARRANGED_CURRENT_CONTEXT_OBSERVED'):
        raise ValueError('Wrong current consumer generation/scope')
    if sha(read_resident(root, 'game/scripts/build_info.gd')) != parent['current_sources']['game/scripts/build_info.gd']['sha256']:
        later = pinned_receipt(root, RECEIPT95, RECEIPT95_SHA)
        # Keep exact 94/95 dispatch unchanged. A later build/HUD generation must
        # enter the separately pinned v096 adapter instead of failing a stale95
        # current-source row or relabelling historical observations.
        current_build = sha(read_resident(root, 'game/scripts/build_info.gd'))
        current_hud = sha(read_resident(root, 'game/scripts/hud.gd'))
        build95 = later.get('current_source_overrides', {}).get('game/scripts/build_info.gd', {}).get('sha256')
        hud94 = parent.get('current_sources', {}).get('game/scripts/hud.gd', {}).get('sha256')
        if current_build != build95 or current_hud != hud94:
            observed96 = pinned_receipt(root, RECEIPT96, RECEIPT96_SHA)
            if current_build != observed96['current_sources']['game/scripts/build_info.gd']['sha256']:
                return qualify97(root)
            return qualify96(root)
        if (later['schema'] != 'null-choir-exact-current-art-consumers-v0095-v1'
                or later['status'] != 'ACTUAL_CURRENT95_CORRECTED_WALLS_WITH_HISTORICAL_UNCHANGED_ART'
                or later['parent_qualification']['path'] != RECEIPT
                or later['parent_qualification']['sha256'] != RECEIPT_SHA
                or set(later['current_source_overrides']) != {'game/scripts/build_info.gd', 'game/scripts/wall_architecture.gd'}):
            raise ValueError('Only exact additive95 wall/build generation is supported')
        record(root, later['parent_qualification'])
        record(root, later['runtime_project'])
        bridge = later['export_metadata_bridge']
        after = record(root, bridge['after'])
        removed, anchor = bridge['removed_utf8'].encode(), bridge['following_utf8'].encode()
        if (bridge['path'] != 'game/export_presets.cfg' or bridge['after']['path'] != bridge['path']
                or bridge['operation'] != 'remove_exact_unsupported_application_name_line'
                or removed != b'application/name="Null Choir v0.095"\n'
                or anchor != b'application/short_version="0.095"'
                or after.count(anchor) != 1 or removed in after):
            raise ValueError('Exact export-only preset metadata deletion required')
        before = after.replace(anchor, removed + anchor, 1)
        if len(before) != bridge['before_bytes'] or sha(before) != bridge['before_sha256']:
            raise ValueError('Captured95 export preset does not roundtrip; runtime proof not relabeled')
        # Keep the94 receipt intact. Only its unaffected source/art evidence is
        # inherited; corrected95 walls have their OWN eight actual observations.
        value = {**parent, 'schema': later['schema'], 'status': later['status'],
                 'source_generation': later['source_generation'],
                 'current_sources': {**parent['current_sources'], **later['current_source_overrides']},
                 'native_observation': later['native_observation'],
                 'historical_native_observation': parent['native_observation'], 'scope': later['scope']}
    for group in ('current_sources', 'unchanged_runtime_assets'):
        for relative, row in value[group].items():
            if row['path'] != relative:
                raise ValueError('Current source path association mismatch')
            record(root, row)
    for relative, row in value['historical_sources'].items():
        old = record(root, row).decode('utf-8')
        current = record(root, value['current_sources'][relative]).decode('utf-8')
        for seam in SEAMS[Path(relative).stem]:
            if function(old, seam) != function(current, seam):
                raise ValueError('Critical draw/constructor/gate seam changed: ' + relative + ':' + seam)
    return value


def historical(root, relative, expected_sha):
    """Return explicitly historical Git bytes, NEVER label them current source."""
    current_build = sha(read_resident(root, 'game/scripts/build_info.gd'))
    current_hud = sha(read_resident(root, 'game/scripts/hud.gd'))
    # Preserve the original94 path without requiring a newer receipt. Only load
    # the additive95 parent after the exact94 source generation has changed.
    parent94 = pinned_receipt(root, RECEIPT, RECEIPT_SHA)
    build94 = parent94.get('current_sources', {}).get('game/scripts/build_info.gd', {}).get('sha256')
    hud94 = parent94.get('current_sources', {}).get('game/scripts/hud.gd', {}).get('sha256')
    if current_build == build94 and current_hud == hud94:
        value = qualify(root)
    else:
        parent95 = pinned_receipt(root, RECEIPT95, RECEIPT95_SHA)
        build95 = parent95.get('current_source_overrides', {}).get('game/scripts/build_info.gd', {}).get('sha256')
        if current_build == build95 and current_hud == hud94:
            value = qualify(root)
        else:
            return historical96(root, relative, expected_sha)
    row = value['historical_sources'].get(relative)
    if row is None or row['sha256'] != expected_sha:
        raise ValueError('Only the exact retained historical consumer is supported')
    return record(root, row)


# Additive strict current96 consumer adapter. See candidate adapter docstring.
"""Candidate strict additive v0.096 art-consumer adapter.

This joins a future exact current-source/pixel receipt to immutable v0.094/.095
history. It is a provenance validator, not execution authentication, a receipt,
visual grade, or PASS. The pin intentionally stays closed until actual captures
are reviewed and their final receipt bytes are fixed.
"""
import re
from hashlib import sha256
from pathlib import Path

"""Candidate strict additive v0.096 art-consumer adapter.

This joins a future exact current-source/pixel receipt to immutable v0.094/.095
history. It is a provenance validator, not execution authentication, a receipt,
visual grade, or PASS. The pin intentionally stays closed until actual captures
are reviewed and their final receipt bytes are fixed.
"""
import re
from hashlib import sha256
from pathlib import Path

RECEIPT96 = 'source/art/consumer-qualification-v0096/current-consumers.json'
# Replace only after the complete real-frame receipt is finalized and reviewed.
# Keeping a sentinel here makes the adapter fail closed rather than accept any
# self-reported digest from a caller or an empty placeholder receipt.
RECEIPT96_SHA = 'b05491c85ba9c2e64f4277548b16b2276c8c65037ee5fc0f2b3f0949d7634b38'

RECEIPT95 = 'source/art/consumer-qualification-v0095/current-consumers.json'
RECEIPT95_SHA = '09a4f0e50e5e000ab26a1156bba4da7a781af5ac2cfac8f8c31911d70558486e'
RECEIPT94 = 'source/art/consumer-qualification-v0094/current-consumers.json'
RECEIPT94_SHA = 'dad9f63a2c5eb0c73b139186deb9a74990b118f8b38b85cda1f2ac97642060d4'
HUD96_SHA = '866472f3a8509aca53ddbe1ac17dd114e8fcce3c2071bf70950a63ace931b629'

# The full current consumer dependency contract. Keep sources with the changed
# v096 render/ballistics/local-light/map/UI/transaction paths, not merely the
# old constructor seams. The receipt's byte pin binds any additional rows too.
REQUIRED96_SOURCES = {
    'game/scripts/main.gd', 'game/scripts/hud.gd', 'game/scripts/enemy.gd',
    'game/scripts/level_landmarks.gd', 'game/scripts/navigation_routes.gd',
    'game/scripts/ossuary_surfaces_v3.gd', 'game/scripts/floors_v1.gd',
    'game/scripts/floors_v0.gd', 'game/scripts/narrative.gd',
    'game/scripts/sprite_hit_query.gd', 'game/scripts/critical_actor_practical.gd',
    'game/scripts/level.gd', 'game/scripts/campaign.gd', 'game/scripts/player.gd',
    'game/scripts/ammo_visuals.gd', 'game/scripts/projectile.gd',
    'game/scripts/preferences.gd', 'game/scripts/weapon_variation.gd',
    'game/scripts/earned_supplies.gd', 'game/scripts/earned_supply_runtime.gd',
    'game/scripts/ground_movement.gd', 'game/scripts/build_info.gd',
    'game/scripts/wall_architecture.gd', 'game/scripts/level_schema.gd',
    'game/scripts/level_data.gd', 'game/scripts/seal_guardians.gd',
    'game/scripts/survey.gd', 'game/scripts/worker_hit_regions.gd',
    'game/scripts/healing_machinery.gd', 'game/scripts/healing_machinery_post_import.gd', 'game/scripts/warden_pressure_window.gd',
    'game/scripts/gate_art.gd', 'game/scripts/gate_visual.gd',
    'game/project.godot', 'game/export_presets.cfg',
    'game/data/earned_supplies.json',
    'game/data/healing_machinery_registry.json',
    'game/data/healing_machine_placements.json',
    'game/assets/art/regions/nursery-warden-node-v1.json',
    *(f'game/data/{n:02d}_{chapter}.json' for n, chapter in enumerate(
        ('intake', 'foundry', 'processional', 'reliquary', 'nursery', 'ossuary', 'inversion', 'heart'), 1)),
}
LEVEL_IDS = ('intake', 'foundry', 'processional', 'reliquary', 'nursery', 'ossuary', 'inversion', 'heart')
PURPOSE_MARKERS = {
    'ammo':'marker_ammo', 'health':'marker_health', 'armor':'marker_armor',
    'key':'marker_key', 'weapon':'marker_weapon', 'story':'marker_story',
    'checkpoint':'marker_checkpoint', 'exit':'marker_exit',
}
AMMO_MARKERS = ('marker_ammo', 'marker_ammo', 'marker_ammo_shells',
                'marker_ammo_sawtooth', 'marker_ammo_marrow', 'marker_ammo_choir')
FIXED_WORLD_ART = {'ribbed_wall', 'conduit', 'marker_ivorykey', *PURPOSE_MARKERS.values(), *AMMO_MARKERS}
WEAPON_TEXTURES = ('impact_tool', 'rivet_pistol', 'scattergun', 'sawtooth_repeater', 'marrow_launcher', 'choir_disruptor')
CURRENT_2D_ART_PATHS = {
    *(f'game/assets/art/weapons/{name}.png' + suffix for name in WEAPON_TEXTURES for suffix in ('', '.import')),
    *(f'game/assets/art/effects/{name}.png' + suffix for name in ('ammo_vfx', 'shot_travel') for suffix in ('', '.import')),
    *(f'game/assets/art/hud/{name}.png' + suffix for name in ('hud_kit', 'marker_glyphs') for suffix in ('', '.import')),
    'game/assets/art/hud/hud_kit.json', 'game/assets/art/hud/marker_glyphs.json',
    *(f'game/assets/art/textures/{name}.png' + suffix for name in ('wall', 'floor', 'grate', 'surface_atlas', 'cathedral_kit_atlas') for suffix in ('', '.import')),
    *(f'game/assets/art/thresholds-v3/{chapter}_threshold.glb' + suffix for chapter in LEVEL_IDS for suffix in ('', '.import')),
    *(f'game/assets/art/healing_machinery/models/{family}.glb' + suffix for family in (
        'canted-supported-orbit-core', 'capillary-organ', 'clinical-abstract-capsule',
        'hanging-pressure-bulb', 'ivory-archive-vessel', 'organic-valve-cage',
        'refractory-ceramic-crucible', 'ribbed-marrow-tank') for suffix in ('', '.import')),
    'game/assets/art/healing_machinery/raw/texture-atlas.png',
    'game/assets/art/healing_machinery/raw/texture-atlas.png.import',
    *(f'game/assets/art/sprites/bodies-v1/{name}.png' + suffix for name in (
        'brute', 'caster', 'choir_avatar', 'crawler', 'guardian', 'nursery_warden',
        'summoner', 'worker') for suffix in ('', '.import')),
}


def validate_finite_marker_registry(root, current, base):
    """Bind Level constants and the earned-supply JSON to their runtime gate."""
    import json
    level_text = base.record(root, current['game/scripts/level.gd']).decode('utf-8')
    purpose = re.search(r'(?ms)^const PURPOSE_ART = \{(.*?)^\}', level_text)
    ammo = re.search(r'(?m)^const AMMO_ART = \[(.*?)\]', level_text)
    _require(purpose is not None and ammo is not None, 'Finite Level marker registry constants required')
    purpose_rows = re.findall(r'"([^"]+)"\s*:\s*"([^"]+)"', purpose.group(1))
    ammo_rows = re.findall(r'"([^"]+)"', ammo.group(1))
    _require(dict(purpose_rows) == PURPOSE_MARKERS and tuple(ammo_rows) == AMMO_MARKERS
             and 'if spec.kind == "key" and spec.key == "ivory": art = "marker_ivorykey"' in level_text,
             'Unknown/changed Level finite marker-to-model registry')

    registry_path = 'game/data/earned_supplies.json'
    script = base.record(root, current['game/scripts/earned_supplies.gd']).decode('utf-8')
    data = base.record(root, current[registry_path])
    path_match = re.search(r'(?m)^const REGISTRY_PATH = "res://data/earned_supplies\.json"$', script)
    sha_match = re.search(r'(?m)^const REGISTRY_SHA = "([0-9a-f]{64})"$', script)
    _require(path_match is not None and sha_match is not None
             and sha_match.group(1) == sha256(data).hexdigest(),
             'Finite earned-marker registry path/content digest mismatch')
    registry = json.loads(data.decode('utf-8'))
    _require(registry.get('schema') == 'null-choir-earned-supplies-registry-v1'
             and registry.get('revision') == 1 and registry.get('legacy_pickup_count') == 145
             and set(registry.get('chapters', {})) == set(LEVEL_IDS),
             'Exact eight-chapter finite earned-marker registry required')


def validate_healing_and_warden_dependencies(root, current, art_resources, base):
    """Bind current finite-machine inputs and Warden region assets, not runtime import success."""
    import json
    machinery = base.record(root, current['game/scripts/healing_machinery.gd']).decode('utf-8')
    post_import = base.record(root, current['game/scripts/healing_machinery_post_import.gd']).decode('utf-8')
    _require('extends EditorScenePostImport' in post_import and 'func _post_import(scene: Node)' in post_import
             and 'material.vertex_color_use_as_albedo=true' in post_import
             and 'get_source_file() not in SOURCE_PATHS' in post_import,
             'Mandatory authored healing-machine import-time COLOR_0 route required')
    supply_script = base.record(root, current['game/scripts/earned_supplies.gd']).decode('utf-8')
    main = base.record(root, current['game/scripts/main.gd']).decode('utf-8')
    enemy = base.record(root, current['game/scripts/enemy.gd']).decode('utf-8')
    level = base.record(root, current['game/scripts/level.gd']).decode('utf-8')
    earned_runtime = base.record(root, current['game/scripts/earned_supply_runtime.gd']).decode('utf-8')
    warden = base.record(root, current['game/scripts/warden_pressure_window.gd']).decode('utf-8')
    _require('const REGISTRY_PATH = "res://data/healing_machinery_registry.json"' in machinery
             and 'const PLACEMENTS_PATH = "res://data/healing_machine_placements.json"' in machinery
             and 'const REGISTRY_SHA = "' in machinery and 'const PLACEMENTS_SHA = "' in machinery
             and 'func _read_contracts()' in machinery and 'func validate_book(' in machinery
             and 'func validate_station(' in machinery and 'func use_target(' in machinery
             and 'func _render_sha(' in machinery and 'func _shape_sha(' in machinery,
             'Current strict healing registry/placement/load-validation API required')
    _require('level.healing_machinery.root_point(station.id)' in main
             and 'level.healing_machinery.validate_station(id,true)' in main
             and 'level.healing_machinery.validate_book(state.earned_supply,true)' in main
             and 'checks["earned_typed_state"]' in main
             and 'game.level.healing_machinery.station_world_point(station.id)' in earned_runtime
             and 'Supply.heal(game.state._resources(),game.level.layout,game.state.difficulty,station.id)' in earned_runtime
             and 'game.level.healing_machinery.use_target(station.id)' in earned_runtime,
             'Main ownership/finite-stock and runtime use/transfer seams required')
    _require('const EarnedRuntime = preload("res://scripts/earned_supply_runtime.gd")' in main
             and 'if not healing_machinery.build(self,game.state.earned_supply):' in level
             and 'healing_machinery' in level and 'earned_supply' in level
             and 'func valid(' in supply_script and 'healing_remaining' in supply_script
             and 'checks["earned_marker_ownership"]' in main
             and 'checks["earned_fixed_machine_geometry"]' in main
             and '"stock":remaining' in main and '"capacity":int(station.capacity)' in main,
             'Level-owned fixed geometry and finite earned-supply authority required')
    _require('nursery_warden' in warden and 'nursery-warden-node-v1.json' in warden
             and 'const WardenPressureWindow = preload("res://scripts/warden_pressure_window.gd")' in enemy
             and 'WardenPressureWindow.bind(sprite)' in enemy
             and 'WardenPressureWindow.eligible(' in enemy
             and 'WardenPressureWindow.bonus_damage(amount)' in enemy,
             'Current Nursery Warden mask-helper dependency required')

    registry_path = 'game/data/healing_machinery_registry.json'
    placements_path = 'game/data/healing_machine_placements.json'
    registry_bytes = base.record(root, current[registry_path])
    placements_bytes = base.record(root, current[placements_path])
    registry = json.loads(registry_bytes.decode('utf-8'))
    placements = json.loads(placements_bytes.decode('utf-8'))
    families = ('hanging-pressure-bulb', 'refractory-ceramic-crucible', 'capillary-organ',
                'ivory-archive-vessel', 'clinical-abstract-capsule', 'ribbed-marrow-tank',
                'canted-supported-orbit-core', 'organic-valve-cage')
    chapters = ('intake', 'foundry', 'processional', 'reliquary', 'nursery', 'ossuary', 'inversion', 'heart')
    _require(registry.get('schema') == 'null-choir-healing-machinery-v1'
             and set(registry.get('families', {})) == set(families)
             and registry.get('atlasPath') == 'res://assets/art/healing_machinery/raw/texture-atlas.png',
             'Exact eight-family healing machinery registry required')
    atlas_path = 'game/assets/art/healing_machinery/raw/texture-atlas.png'
    atlas = base.record(root, art_resources[atlas_path])
    _require(registry.get('atlasSHA256') == sha256(atlas).hexdigest(),
             'Healing registry atlas byte pin mismatch')
    _require(len(placements) == 32, 'Exact 32 finite healing-machine placements required')
    expected_counts = {chapter: 4 for chapter in chapters}
    found_counts = {chapter: 0 for chapter in chapters}
    for chapter_index, chapter in enumerate(chapters):
        for station_type in ('reservoir_entry', 'reservoir_blood', 'reservoir_ivory', 'reservoir_final'):
            ident = chapter + '_' + station_type
            row = placements.get(ident)
            _require(type(row) is dict and set(row) == {'id', 'chapter', 'family', 'cell', 'yaw_degrees'}
                     and row.get('id') == ident and row.get('chapter') == chapter
                     and row.get('family') == families[chapter_index]
                     and type(row.get('cell')) is list and len(row['cell']) == 2
                     and all(type(v) in (int, float) and abs(v) <= 100000 for v in row['cell'])
                     and type(row.get('yaw_degrees')) in (int, float) and abs(row['yaw_degrees']) <= 360,
                     'Malformed/misowned finite machine placement: ' + ident)
            found_counts[chapter] += 1
    _require(found_counts == expected_counts, 'Exact four-per-chapter placement book required')
    registry_pin = re.search(r'(?m)^const REGISTRY_SHA = \"([0-9a-f]{64})\"$', machinery)
    placements_pin = re.search(r'(?m)^const PLACEMENTS_SHA = \"([0-9a-f]{64})\"$', machinery)
    _require(registry_pin is not None and registry_pin.group(1) == sha256(registry_bytes).hexdigest()
             and placements_pin is not None and placements_pin.group(1) == sha256(placements_bytes).hexdigest(),
             'Production healing registry/placement byte pins do not match resident JSON')
    _require('const CHAPTERS = ' in machinery and 'const FAMILIES = ' in machinery
             and 'placements.size()!=32' in machinery and 'row.family!=FAMILIES[CHAPTERS.find(chapter)]' in machinery,
             'Production must retain exact selected-chapter placement contract')
    for family in families:
        model_path = f'game/assets/art/healing_machinery/models/{family}.glb'
        sidecar = base.record(root, art_resources[model_path + '.import']).decode('utf-8')
        _require('import_script/path="res://scripts/healing_machinery_post_import.gd"' in sidecar,
                 'Every authored healing model must bind the mandatory post-import script')
        row = registry['families'][family]
        _require(row.get('path') == 'res://assets/art/healing_machinery/models/' + family + '.glb'
                 and row.get('sourceGLBSHA256') == art_resources[model_path]['sha256'],
                 'Registry-to-resident GLB byte identity mismatch: ' + family)
    region_path = 'game/assets/art/regions/nursery-warden-node-v1.json'
    region = json.loads(base.record(root, current[region_path]).decode('utf-8'))
    _require(region.get('schema') == 'null-choir-nursery-pressure-region-v1'
             and region.get('status') == 'SOURCE_ONLY_CANDIDATE_NOT_RUNTIME_ACCEPTED'
             and region.get('actor_kind') == 'nursery_warden'
             and region.get('runtime_atlas_path') == 'res://assets/art/sprites/bodies-v1/nursery_warden.png'
             and region.get('runtime_frame', {}).get('atlas_frame') == 24
             and region.get('mask', {}).get('pixel_count', 0) > 0,
             'Exact source-only Warden pressure-region and authored runtime cell required')
    sprite_path = 'game/assets/art/sprites/bodies-v1/nursery_warden.png'
    sprite = base.record(root, art_resources[sprite_path])
    _require(region.get('runtime_atlas_png_sha256') == sha256(sprite).hexdigest(),
             'Warden region atlas byte identity mismatch')
    try:
        from io import BytesIO
        from PIL import Image
        with Image.open(BytesIO(sprite)) as decoded:
            _require(decoded.format == 'PNG' and decoded.size == (2048, 1280),
                     'Exact Warden atlas PNG dimensions required')
            atlas_rgba = decoded.convert('RGBA').tobytes()
    except Exception as exc:
        raise ValueError('Warden atlas must decode as PNG') from exc
    _require(region.get('runtime_atlas_rgba_sha256') == sha256(atlas_rgba).hexdigest(),
             'Warden decoded atlas pixel pin mismatch')
    # Config files are resident source candidates, not proof of Godot canonical
    # imports, native UIDs, .ctex outputs, or PackedScene fidelity.
    return {'status': 'UNPINNED_SOURCE_CONFIG_ONLY', 'canonical_native_imports': None}


def expected_art_resource_paths(root, current, base):
    """Exact GLB/import closure asserted by Main._export_art_checks for all maps."""
    names = set(FIXED_WORLD_ART)
    for i, chapter in enumerate(LEVEL_IDS, 1):
        relative = f'game/data/{i:02d}_{chapter}.json'
        raw = base.record(root, current[relative])
        import json
        data = json.loads(raw.decode('utf-8'))
        for row in data.get('heroes', ()):
            names.add(row['id'])
        for row in data.get('scenery', ()):
            names.add(row['art'])
        for row in data.get('pickups', ()) + data.get('interactions', ()):
            kind = row['kind']
            if kind == 'key' and row.get('key') == 'ivory':
                names.add('marker_ivorykey')
            elif kind == 'ammo':
                names.add(AMMO_MARKERS[int(row['weapon'])])
            else:
                names.add(PURPOSE_MARKERS[kind])
    paths = {f'game/assets/art/world/{name}{suffix}'
             for name in names for suffix in ('.glb', '.glb.import')}
    return paths | CURRENT_2D_ART_PATHS


EXPECTED96_CHANGED_SEAMS = {
    'game/scripts/hud.gd:_process',
    'game/scripts/hud.gd:draw_state',
    'game/scripts/hud.gd:_draw',
}
EXPECTED96_JOBS = (
    *(f'chapter-{n}-{mode}' for n in range(8) for mode in ('routes', 'transactions')),
    *(f'weapon-{n}-roles' for n in range(6)),
)


def _require(condition, message):
    if not condition:
        raise ValueError(message)


# Exact source contract only. Root must freeze the final controller/native controls
# after native66 recovery; leaving these two pins unset deliberately closes this
# additional gate, independently of RECEIPT96_SHA and the final UNPINNED refusal.
CAPTURE96_CONTROLLER_PIN = None
CAPTURE96_CONTROL_PINS = None
CAPTURE96_SOURCE_MANIFEST_SHA = '1d0d32deac3e044eb2141dad0e0620866c4a6488044226362acdd68b3a9eb7af'


def _capture_record96(root, row, base):
    """Private candidate evidence only; never broaden the public source reader."""
    relative = row.get('path', '') if type(row) is dict else ''
    if not relative.startswith(('work/earned-arsenal-prep/consumer96-producer-v1/',
                                'work/earned-arsenal-prep/authored-rivet70-source-scout/',
                                'work/preview07-local-control/reviews/cohort-ledger-review/',
                                'work/preview07-local-control/v0.096-native/',
                                'work/preview07-local-release/')):
        return base.record(root, row)
    import stat
    _require(set(row) == {'path', 'bytes', 'sha256'} and type(row['bytes']) is int
             and row['bytes'] >= 0 and not Path(relative).is_absolute()
             and '..' not in Path(relative).parts,
             'Exact bounded private capture record required')
    path = Path(root).absolute() / relative
    _require(not any(p.is_symlink() for p in (path, *path.parents))
             and stat.S_ISREG(path.lstat().st_mode)
             and not getattr(path.lstat(), 'st_flags', 0) & 0x40000000,
             'Resident unaliased private capture provenance required')
    data = path.read_bytes()
    _require(len(data) == row['bytes'] and sha256(data).hexdigest() == row['sha256'],
             'Private capture provenance drift: ' + relative)
    return data


def validate_fresh_import_join96(root, binding, source_manifest_sha, base):
    """Join the bridge's actual post-import proof, native guard and retained bytes.

    This checks retained evidence relationships, not execution authentication or
    imported material fidelity. The permanent UNPINNED qualification gate remains.
    """
    import json
    _require(type(binding) is dict and set(binding) == {'proof', 'guard', 'generated_cache', 'sidecars', 'new_UIDs'},
             'Exact fresh native import evidence binding required')
    proof_raw = _capture_record96(root, binding['proof'], base)
    proof = json.loads(proof_raw)
    expected_fields = {'native_guard_sha256', 'current_source_manifest_sha256',
        'current_source_and_art_bytes_joined', 'actual_nine_imports', 'new_UIDs',
        'actual_imported_cache', 'sidecars', 'qualification'}
    _require(type(proof) is dict and set(proof) == expected_fields
             and proof.get('current_source_manifest_sha256') == source_manifest_sha
             and proof.get('current_source_and_art_bytes_joined') is True
             and proof.get('actual_nine_imports') is True and proof.get('qualification') is False,
             'Current source-manifest and actual nine-import proof must join')
    guard_raw = _capture_record96(root, binding['guard'], base)
    guard = json.loads(guard_raw)
    _require(sha256(guard_raw).hexdigest() == proof['native_guard_sha256']
             and guard.get('strict_resource_guard') is True
             and guard.get('fresh_owned_closure') is True,
             'Fresh native import guard/owned closure must join exact proof bytes')
    cache = binding.get('generated_cache'); sidecars = binding.get('sidecars')
    _require(type(cache) is dict and set(cache) == set(proof['actual_imported_cache'])
             and type(sidecars) is dict and set(sidecars) == set(proof['sidecars'])
             and len(sidecars) == 9,
             'All actual generated import/cache and nine sidecar records required')
    uid_records = binding.get('new_UIDs')
    _require(type(uid_records) is dict and set(uid_records) == set(proof['new_UIDs']),
             'Every actual generated source UID record must be retained')
    for name, row in uid_records.items():
        data = _capture_record96(root, row, base); actual = proof['new_UIDs'][name]
        _require(not Path(name).is_absolute() and '..' not in Path(name).parts
                 and name.endswith('.gd.uid') and len(data) <= 64
                 and re.fullmatch(rb'uid://[a-z0-9]+\n?', data)
                 and row['bytes'] == actual['bytes'] and row['sha256'] == actual['sha256'],
                 'Exact actual generated source UID content/stat join required')
    observed_refs = set(); model_count = 0; texture_count = 0; import_uids = set()
    expected_sidecars = {f'assets/art/healing_machinery/models/{name}.glb.import' for name in (
        'canted-supported-orbit-core', 'capillary-organ', 'clinical-abstract-capsule',
        'hanging-pressure-bulb', 'ivory-archive-vessel', 'organic-valve-cage',
        'refractory-ceramic-crucible', 'ribbed-marrow-tank')}
    expected_sidecars.add('assets/art/healing_machinery/raw/texture-atlas.png.import')
    _require(set(sidecars) == expected_sidecars, 'Exact eight authored models plus atlas import set required')
    for name, row in sidecars.items():
        data = _capture_record96(root, row, base)
        native = proof['sidecars'][name]
        _require(row['bytes'] == native['bytes'] and row['sha256'] == native['sha256'],
                 'Native sidecar stat/hash must join retained actual bytes')
        text = data.decode('utf-8'); asset = name.removesuffix('.import')
        is_model = asset.endswith('.glb')
        _require(re.search(r'(?m)^importer="' + ('scene' if is_model else 'texture') + r'"$', text)
                 and re.search(r'(?m)^type="' + ('PackedScene' if is_model else 'CompressedTexture2D') + r'"$', text),
                 'Actual native importer/type must match authored model or atlas source kind')
        _require('source_file="res://' + asset + '"' in text
                 and re.search(r'(?m)^uid="uid://[a-z0-9]+"$', text),
                 'Actual native sidecar source and generated UID required')
        uid = re.search(r'(?m)^uid="(uid://[a-z0-9]+)"$', text).group(1)
        _require(uid not in import_uids, 'Distinct actual native imported source UIDs required'); import_uids.add(uid)
        refs = set(re.findall(r'"res://(\.godot/imported/[^"\n]+)"', text))
        _require(bool(refs), 'Actual compiled scene/texture remap required')
        for rel in refs:
            q = Path(rel)
            _require(q.parent == Path('.godot/imported') and q.name.startswith(Path(asset).name + '-')
                     and q.suffix == ('.scn' if asset.endswith('.glb') else '.ctex'),
                     'Actual native remap may not retarget another source/type')
            key = rel[7:]; _require(key in cache, 'Compiled remap missing retained imported bytes')
            observed_refs.add(key)
            if q.suffix == '.scn': model_count += 1
            else: texture_count += 1
    _require(model_count == 8 and texture_count == 1, 'Eight compiled scenes and one native atlas required')
    for name, row in cache.items():
        data = _capture_record96(root, row, base); actual = proof['actual_imported_cache'][name]
        _require(row['bytes'] == actual['bytes'] and row['sha256'] == actual['sha256'],
                 'Actual generated cache stat/hash must join retained bytes')
        allowed = name in observed_refs or any(name == str(Path(ref).with_suffix('.md5')) for ref in observed_refs)
        for ref in observed_refs:
            if not ref.endswith('.scn'): continue
            full = 'res://.godot/' + ref
            folding = 'editor/' + Path(ref).name + '-folding-' + __import__('hashlib').md5(full.encode()).hexdigest() + '.cfg'
            if name == folding:
                _require(data == b'[folding]\n\nsections_unfolded=PackedStringArray()\n', 'Exact actual scene-folding payload required')
                allowed = True
        _require(allowed, 'Foreign generated native cache leaf refused')
    return sha256(proof_raw).hexdigest()


def _load_capture_producer96(root, row):
    # Called only after the exact fixed source record has been verified.
    import importlib.util
    path = Path(root) / row['path']
    spec = importlib.util.spec_from_file_location('_exact_v096_context_producer', path)
    producer = importlib.util.module_from_spec(spec); spec.loader.exec_module(producer)
    return producer


# Root must review/fill all five exact real-artifact bindings and RECEIPT96_SHA.
# Hash commitments are not authentication. Never populate these from a caller.
PUBLIC96_BINDINGS = {'portable_module': {'path': 'source/art/consumer-qualification-v0096/portable96.py', 'bytes': 17597, 'sha256': '790d6483ab50bf1d3f328a6d6248e0ba4a91bb8cadf829398d31ac4f1476eb89'}, 'portable_index': {'path': 'source/art/consumer-qualification-v0096/portable-index.json', 'bytes': 78305, 'sha256': 'f76c666a6b5c4760bab57fc55ebb87c778a09d33cc24356eebeadc44078a36fe'}, 'trusted_producer_sha256': '571839218a1bd6e6e223ec54f6403bcd51cb25692cceb056a0373a7ecb72d61a', 'metadata_sha256s': {'producer': '571839218a1bd6e6e223ec54f6403bcd51cb25692cceb056a0373a7ecb72d61a', 'fixture': '294b46e02bf196dbad8d6517fadc041a35042ecc0c12c135c5263209dc5fb13e', 'case_schema': 'c92c312298fee77e7f662a5072b2163cc0a44cb6ac00d381d72b1401b353a539', 'source_manifest': '1d0d32deac3e044eb2141dad0e0620866c4a6488044226362acdd68b3a9eb7af', 'station_view_map': 'ec1f9260b933928cf587b7b4f1440f34b72a5b8cd8ca2d9af04c78ee608aea72', 'original22_contract': '136325f20b9c0b8081e596728252acf8acdc2fb8d5198aa10c1dbafdec771617', 'source_scout': 'bc9db94dc5519af61bba231a652028f8998c6d484e9a26cd317b0618a0c8dd5d', 'source_scout_report': 'bd8a15f3a446b6b5f144ce140763ab8d77cbc12c2ebd7bdaa6fcd6f43b3d3f20', 'source_scout_near_mid': 'cf891524d4bd316888d78e2e0c737e8ce104d2b87b407d56e4579b48dc2feb58', 'source_scout_review': '1a76218f2fe085a8018c26e0f43374ecf64790d52e7fb9106d6d8ad7b047e723'}, 'native_status_sha256': 'b10e25e696d5dffa707175f7fd557cf089da1f0c455931981d95b5c4375db358'}

def portable_native_status96(root, index, current, base):
    """Deterministic NON-qualifying status builder; caller must validate portable joins.
    Native resource rows derive from the real byte projections, never source config.
    Canonical C/cache promotion and GPU/material-fidelity claims remain explicitly false.
    """
    import json
    projections = index['native_import_projections']
    _require(type(projections) is dict and projections, 'Actual native import generations required')
    generations = {}
    for raw_sha, row in projections.items():
        projection = json.loads(base.record(root, row))
        _require(projection.get('raw_import_proof_sha256') == raw_sha
                 and projection.get('current_source_manifest_sha256') == CAPTURE96_SOURCE_MANIFEST_SHA
                 and projection.get('actual_nine_imports') is True,
                 'Actual nine-import projection/current47 source join required')
        generations[raw_sha] = {
            'projection': row, 'raw_guard_sha256': projection['raw_import_guard_sha256'],
            'generated_cache': projection['files']['generated_cache'],
            'sidecars': projection['files']['sidecars'], 'new_UIDs': projection['files']['new_UIDs']}
    return {
        'status': 'ACTUAL_RETAINED_NATIVE_IMPORT_BYTES_JOINED',
        'current_source_manifest_sha256': CAPTURE96_SOURCE_MANIFEST_SHA,
        'observed_native_import_generations': generations,
        'material_source_gate': {
            'scope': 'STRICT_SOURCE_GATES_AND_IMPORTED_BYTES_NOT_MATERIAL_FIDELITY',
            'healing_helper_sha256': current['game/scripts/healing_machinery.gd']['sha256'],
            'post_import_sha256': current['game/scripts/healing_machinery_post_import.gd']['sha256'],
            'registry_sha256': current['game/data/healing_machinery_registry.json']['sha256'],
            'placements_sha256': current['game/data/healing_machine_placements.json']['sha256'],
            'warden_helper_sha256': current['game/scripts/warden_pressure_window.gd']['sha256']},
        'canonical_cache_adopted': False, 'qualification': False, 'execution_authenticated': False}

def validate_capture_context_join96(root, receipt, base):
    """Public evidence bridge; no private controller/provider/process/home paths required.
    The unchanged final producer verifies every exact per-case schema/emission/import.
    This does not authenticate execution, accept pixels, or open any gate by itself.
    """
    import importlib.util
    import json
    pins = PUBLIC96_BINDINGS
    _require(type(pins) is dict and set(pins) == {
        'portable_module', 'portable_index', 'trusted_producer_sha256', 'native_status_sha256', 'metadata_sha256s'},
        'Final public portable/native bindings remain UNPINNED')
    _require(re.fullmatch('[0-9a-f]{64}', pins['trusted_producer_sha256'] or '')
             and re.fullmatch('[0-9a-f]{64}', pins['native_status_sha256'] or ''),
             'Externally reviewed final producer/native status pins required')
    join = receipt.get('capture_context_join')
    _require(type(join) is dict and set(join) == {'schema', 'portable_index'}
             and join['schema'] == 'null-choir-v096-public-portable-context-import-join-v1'
             and join['portable_index'] == pins['portable_index'],
             'Exact final public portable index binding required')
    for row in (pins['portable_module'], pins['portable_index']):
        _require(row['path'].startswith('source/art/consumer-qualification-v0096/'),
                 'Public bridge artifact outside exact source namespace')
        base.record(root, row)
    index = json.loads(base.record(root, pins['portable_index']))
    deps = index.get('dependencies')
    metadata_pins = pins['metadata_sha256s']
    _require(type(metadata_pins) is dict and set(metadata_pins) == set(CAPTURE96_SOURCE_DEPENDENCIES)
             and all(re.fullmatch('[0-9a-f]{64}', value or '') for value in metadata_pins.values()),
             'Final ten public metadata SHA pins remain externally reviewed, never caller-adopted')
    _require(type(deps) is dict and set(deps) == set(metadata_pins)
             and all(deps[k]['sha256'] == metadata_pins[k] for k in deps)
             and deps['producer']['sha256'] == pins['trusted_producer_sha256']
             and deps['source_manifest']['sha256'] == CAPTURE96_SOURCE_MANIFEST_SHA,
             'Exact final ten metadata byte pins/current47-source manifest required')
    manifest = json.loads(base.record(root, deps['source_manifest']))
    _require(receipt['current_sources'] == manifest['source_dependencies']
             and set(receipt['current_sources']) == REQUIRED96_SOURCES
             and receipt['current_art_resources'] == manifest['art_resource_dependencies'],
             'Portable bridge must preserve all exact47 source and262 current-art records')
    spec = importlib.util.spec_from_file_location('_reviewed_public_portable96', Path(root) / pins['portable_module']['path'])
    portable = importlib.util.module_from_spec(spec); spec.loader.exec_module(portable)
    # Observe the private imported reader, not a process-global filesystem hook.
    # Its original strict public-namespace/symlink/residency/hash checks still run.
    portable_record = portable.record
    def observed_record(evidence_root, row):
        return _observe96(evidence_root, row['path'], portable_record(evidence_root, row))
    portable.record = observed_record
    if (getattr(base, '_main_derivation96', None) is not None
            or getattr(base, '_historical96_snapshots', None) is not None):
        original_load_producer = portable.load_producer
        def captured_load_producer(*args, **kwargs):
            producer = original_load_producer(*args, **kwargs)
            if getattr(base, '_historical96_snapshots', None) is not None:
                return _project_historical96_for97(producer, root, base)
            return _project_captured_main96(producer, root, base)
        portable.load_producer = captured_load_producer
    for job in index['jobs']:
        _observe_png_directory96(root, 'source/art/consumer-qualification-v0096/cases/' + job['id'])
    result = portable.validate_bundle(root, root, index, validate_fresh_import_join96,
        trusted_producer_sha256=pins['trusted_producer_sha256'])
    _require(result == {'status': 'PORTABLE_CONTEXT_RELATIONSHIPS_VALIDATED_NOT_QUALIFICATION',
                       'cases': 22, 'qualification': False, 'execution_authenticated': False},
             'All22 strict portable producer/native relationships required')
    by_id = {job['id']: job for job in receipt['native_observation']['jobs']}
    _require(len(by_id) == 22 and set(by_id) == set(EXPECTED96_JOBS),
             'All22 original current96 observation jobs required')
    for emitted in index['jobs']:
        job = by_id[emitted['id']]
        raw = portable.context_bytes(root, emitted['context'])
        context = json.loads(raw)
        frames = [{**row, 'rgba_sha256': frame['RGBA_sha256'], 'width': 640, 'height': 360}
                  for row, frame in zip(emitted['frames'], context['frames'])]
        _require(job['frames'] == frames and job['trace'] == emitted['context']['artifact']
                 and job['trace_join'] == emitted['trace_join'],
                 'Receipt PNG/RGBA/order/gzip/rawTRACEJOIN must exactly match validated portable cases')
    status = portable_native_status96(root, index, receipt['current_sources'], base)
    status_raw = json.dumps(status, sort_keys=True, separators=(',', ':')).encode()
    _require(sha256(status_raw).hexdigest() == pins['native_status_sha256']
             and receipt.get('native_import_status') == status,
             'Final actual compiled/import/material-source status must be independently pinned and exact')
    return {'status': 'PUBLIC_CONTEXT_IMPORT_JOIN_VALIDATED_NOT_EXECUTION_AUTHENTICATION',
            'cases': 22, 'native_import_status': status, 'qualification': False,
            'execution_authenticated': False}


CAPTURE96_SOURCE_DEPENDENCIES = {'producer': {'path': 'work/earned-arsenal-prep/consumer96-producer-v1/later22_producer.py', 'bytes': 70308, 'sha256': '571839218a1bd6e6e223ec54f6403bcd51cb25692cceb056a0373a7ecb72d61a'}, 'fixture': {'path': 'work/earned-arsenal-prep/consumer96-producer-v1/qualify_v0096_gameplay_context.gd', 'bytes': 86098, 'sha256': 'c7b4fae75e27a35eab50b671241f820e926e615917282d25f53fd713cecd32d3'}, 'case_schema': {'path': 'work/earned-arsenal-prep/consumer96-producer-v1/CASE-SCHEMA.json', 'bytes': 35259, 'sha256': 'c92c312298fee77e7f662a5072b2163cc0a44cb6ac00d381d72b1401b353a539'}, 'source_manifest': {'path': 'work/earned-arsenal-prep/consumer96-producer-v1/CURRENT-SOURCE-PINS.json', 'bytes': 72406, 'sha256': '1d0d32deac3e044eb2141dad0e0620866c4a6488044226362acdd68b3a9eb7af'}, 'station_view_map': {'path': 'work/earned-arsenal-prep/consumer96-producer-v1/STATION-VIEW-MAP.json', 'bytes': 11226, 'sha256': 'ec1f9260b933928cf587b7b4f1440f34b72a5b8cd8ca2d9af04c78ee608aea72'}, 'original22_contract': {'path': 'work/earned-arsenal-prep/consumer96-producer-v1/CAPTURE-CASES22-REFERENCE.json', 'bytes': 14365, 'sha256': '136325f20b9c0b8081e596728252acf8acdc2fb8d5198aa10c1dbafdec771617'}, 'source_scout': {'path': 'work/earned-arsenal-prep/authored-rivet70-source-scout/PROPOSED-ENCOUNTER.json', 'bytes': 8966, 'sha256': 'bc9db94dc5519af61bba231a652028f8998c6d484e9a26cd317b0618a0c8dd5d'}, 'source_scout_report': {'path': 'work/earned-arsenal-prep/authored-rivet70-source-scout/REPORT.md', 'bytes': 8274, 'sha256': 'bd8a15f3a446b6b5f144ce140763ab8d77cbc12c2ebd7bdaa6fcd6f43b3d3f20'}, 'source_scout_near_mid': {'path': 'work/earned-arsenal-prep/authored-rivet70-source-scout/near-mid-same-spine.json', 'bytes': 9104, 'sha256': 'cf891524d4bd316888d78e2e0c737e8ce104d2b87b407d56e4579b48dc2feb58'}, 'source_scout_review': {'path': 'work/preview07-local-control/reviews/cohort-ledger-review/authored-rivet70-source-review.md', 'bytes': 5428, 'sha256': '1a76218f2fe085a8018c26e0f43374ecf64790d52e7fb9106d6d8ad7b047e723'}}


# Explicit test-only source derivation; raw capture receipts/manifests stay immutable.
MAIN96_VERIFIER_DERIVATION = {'schema': 'null-choir-v096-verifier-only-main-derivation-v1', 'observed_main': {'path': 'game/scripts/main.gd', 'bytes': 95728, 'sha256': 'e34dffae3eb0b73c3a3a72d11a81d4bbb402266603007a2e281bc1b3ef081f9b'}, 'observed_snapshot': {'path': 'source/art/consumer-qualification-v0096/provenance/main-v96-capture.gd', 'bytes': 95728, 'sha256': 'e34dffae3eb0b73c3a3a72d11a81d4bbb402266603007a2e281bc1b3ef081f9b'}, 'derived_main': {'path': 'game/scripts/main.gd', 'bytes': 100753, 'sha256': '89a4fe9dbda378bae34573176c684faffdcf7b572e5793a849e5a720f91cf380'}, 'changed_functions': {'_export_art_checks': {'old_sha256': '30140f5a374d0d8ef27e28a39204a2993e08e8f7a7eedad4c1e3cb73ef031900', 'new_sha256': 'caa3fe75990b244ca621a9f3e3dc21fe59157ba38252c0c9724d694c7a36c181'}, '_verify_export': {'old_sha256': 'e481aec2c782ec3a8a4f6befddeda63b043313f53587a66e667472f86b26be37', 'new_sha256': 'c79ff47fa6dc4a68b8b42f3fe650dd4e0fdc1ce04dc78ae32296218acc5aafde'}}, 'added_functions': {'_export_wall_architecture_checks': 'ce627e9c6501b93a7ca445803ecf9f426258af83180fdd64980809e92e38e3dc'}}


def _verifier_function_span96(raw, name):
    pattern = rb'(?ms)^func ' + re.escape(name.encode()) + rb'\([^\n]*\n.*?(?=^func |\Z)'
    matches = list(re.finditer(pattern, raw))
    _require(len(matches) == 1, 'Exactly one approved verifier function required: ' + name)
    match = matches[0]
    # Refuse a new top-level declaration hidden between function declarations.
    _require(all(not line.strip() or line.startswith((b'\t', b'#'))
                 for line in match.group().splitlines()[1:]),
             'Unapproved top-level payload in verifier function span')
    return match


def verifier_main_derivation96(root, observed_row, base):
    """Exact finite source equivalence, never a new frame/native observation."""
    pin = MAIN96_VERIFIER_DERIVATION
    _require(observed_row == pin['observed_main'], 'Observed Main derivation record drift')
    resident = base.read_resident(root, observed_row['path'])
    if len(resident) == observed_row['bytes'] and sha(resident) == observed_row['sha256']:
        return None
    target = pin['derived_main']
    _require(len(resident) == target['bytes'] and sha(resident) == target['sha256'],
             'Exact approved verifier-only resident Main drift')
    old = base.record(root, pin['observed_snapshot'])
    _require(len(old) == observed_row['bytes'] and sha(old) == observed_row['sha256'],
             'Captured full Main snapshot drift')
    replacements = []
    for name, hashes in pin['changed_functions'].items():
        before = _verifier_function_span96(old, name)
        after = _verifier_function_span96(resident, name)
        _require(sha(before.group()) == hashes['old_sha256']
                 and sha(after.group()) == hashes['new_sha256'],
                 'Explicit old/new verifier function pin drift')
        replacements.append((after.start(), after.end(), before.group()))
    for name, digest in pin['added_functions'].items():
        _require(not re.search(rb'(?m)^func ' + re.escape(name.encode()) + rb'\(', old),
                 'Added verifier function already present in captured Main')
        after = _verifier_function_span96(resident, name)
        _require(sha(after.group()) == digest, 'Explicit added verifier function pin drift')
        replacements.append((after.start(), after.end(), b''))
    inverse = resident
    for begin, end, replacement in sorted(replacements, reverse=True):
        inverse = inverse[:begin] + replacement + inverse[end:]
    _require(inverse == old, 'Bytes outside approved verifier functions changed')
    return {**pin, 'status': 'VERIFIER_ONLY_SOURCE_DERIVATION_NOT_NEW_OBSERVATION',
            'outside_verifier_bytes_exact': True, 'new_frames_claimed': False,
            'new_native_import_claimed': False, 'new_gameplay_observation_claimed': False}


def _verifier_snapshot_path96(root, derivation):
    return Path(root) / derivation['observed_snapshot']['path']


def _observed_main_reader96(root, derivation, base):
    """Historical read view ONLY after exact derived resident source proof."""
    view = type('_ObservedMainReader96', (), {})()
    for name in ('read_resident', 'record', 'pinned_receipt', 'sha', 'function'):
        setattr(view, name, getattr(base, name))
    def captured_record(evidence_root, row):
        if row == derivation['observed_main']:
            _require(verifier_main_derivation96(evidence_root, row, base) == derivation,
                     'Verifier derivation changed during historical source read')
            return base.record(evidence_root, derivation['observed_snapshot'])
        return base.record(evidence_root, row)
    view.record = captured_record
    view._main_derivation96 = derivation
    view._actual_reader96 = base
    return view


def _project_captured_main96(producer, root, base):
    """One private producer source path projection, never patch its validators."""
    derivation = getattr(base, '_main_derivation96', None)
    if derivation is None:
        return producer
    regular = producer._regular
    def projected(project, relative):
        current_path = regular(project, relative) # Preserve original resident/symlink gates.
        if relative != derivation['observed_main']['path']:
            return current_path
        _require(Path(project).resolve() == Path(root).resolve(), 'Main projection root drift')
        _require(verifier_main_derivation96(root, derivation['observed_main'],
                                          base._actual_reader96) == derivation,
                 'Main projection lacks exact current verifier derivation')
        return _verifier_snapshot_path96(root, derivation)
    producer._regular = projected
    return producer


def _qualify96_uncached(root, base=None):
    """Validate a later exact receipt; never reinterpret old95 frames as96.

    `base` is tools.art_consumer_compatibility's already-reviewed strict reader
    (`read_resident`, `record`, `pinned_receipt`, `sha`). Parent receipts are
    pinned, immutable history. v096 source rows are independently hash checked
    against current resident files; unaffected old asset rows are inherited only
    after rechecking their bytes. Future schema changes are deliberately refused.
    """
    if base is None:
        # Also support strict-reader imports loaded via importlib specs that do
        # not register the module in sys.modules (as the legacy tests do).
        base = type('_ConsumerReader', (), {})()
        for name in ('read_resident', 'record', 'pinned_receipt', 'sha', 'function'):
            setattr(base, name, globals()[name])
    _require(bool(re.fullmatch(r'[0-9a-f]{64}', RECEIPT96_SHA)),
             'v096 receipt is not pinned to finalized actual-frame evidence')
    parent94 = base.pinned_receipt(root, RECEIPT94, RECEIPT94_SHA)
    parent95 = base.pinned_receipt(root, RECEIPT95, RECEIPT95_SHA)
    _require(parent94.get('schema') == 'null-choir-exact-current-art-consumers-v0094-v1'
             and parent94.get('status') == 'ACTUAL_ARRANGED_CURRENT_CONTEXT_OBSERVED',
             'Exact historical94 parent required')
    for row in parent94.get('historical_sources', {}).values():
        base.record(root, row)
    _require(parent95.get('schema') == 'null-choir-exact-current-art-consumers-v0095-v1'
             and parent95.get('status') == 'ACTUAL_CURRENT95_CORRECTED_WALLS_WITH_HISTORICAL_UNCHANGED_ART'
             and parent95.get('parent_qualification') == {
                 'path': RECEIPT94, 'bytes': len(base.read_resident(root, RECEIPT94)),
                 'sha256': RECEIPT94_SHA},
             'Exact immutable95->94 historical chain required')
    v = base.pinned_receipt(root, RECEIPT96, RECEIPT96_SHA)
    _require(type(v) is dict and set(v) == {
        'schema', 'status', 'parent_qualification', 'current_sources',
        'unchanged_runtime_assets', 'current_art_resources', 'native_import_status',
        'native_observation', 'capture_context_join', 'scope'}
        and v.get('schema') == 'null-choir-exact-current-art-consumers-v0096-v1'
             and v.get('status') == 'ACTUAL_CURRENT96_MOVING_CONTEXTS_OBSERVED',
             'Exact actual-current96 receipt schema/status required')
    _require(v.get('parent_qualification') == {
        'path': RECEIPT95, 'bytes': len(base.read_resident(root, RECEIPT95)),
        'sha256': RECEIPT95_SHA}, 'Exact immutable95 parent required')

    current = v.get('current_sources')
    _require(type(current) is dict and REQUIRED96_SOURCES.issubset(current),
             'Incomplete v096 code/render/ballistics/local-light/map/UI dependency set')
    main_derivation = verifier_main_derivation96(root, current['game/scripts/main.gd'], base)
    if main_derivation is not None:
        base = _observed_main_reader96(root, main_derivation, base)
    for relative, row in current.items():
        _require(relative == row.get('path'), 'Current source path association mismatch')
        base.record(root, row)
    _require(current['game/scripts/hud.gd']['sha256'] == HUD96_SHA,
             'Exact current96 pickup-hint/HUD consumer source required')

    # Compare retained critical seams, never borrowing 94/95 draw contexts for
    # changed v096 behavior. Only these known HUD routines may differ, and the
    # new actual moving-context case set must explicitly cover the changed seams.
    changed = set()
    historical_sources = parent94.get('historical_sources')
    _require(type(historical_sources) is dict, 'Immutable historical source snapshot set required')
    for relative, hist in historical_sources.items():
        if relative not in current:
            continue
        old_text = base.record(root, hist).decode('utf-8')
        now_text = base.record(root, current[relative]).decode('utf-8')
        seams = list(SEAMS.get(Path(relative).stem, ()))
        if relative == 'game/scripts/hud.gd':
            seams.extend(['_process', 'draw_state'])
        for seam in seams:
            if base.function(old_text, seam) != base.function(now_text, seam):
                changed.add(relative + ':' + seam)
    _require(changed == EXPECTED96_CHANGED_SEAMS,
             'Unexpected changed critical seam or missing declared v096 actual-evidence seam')

    # Main._export_art_checks consumes the finite Level marker registry, all
    # current hero/scenery map rows, and imported world-model resources. Source
    # JSON alone does not bind the actual GLB bytes or their Godot import config.
    validate_finite_marker_registry(root, current, base)
    art_resources = v.get('current_art_resources')
    expected_art_paths = expected_art_resource_paths(root, current, base)
    _require(type(art_resources) is dict and set(art_resources) == expected_art_paths,
             'Exact finite Main._export_art_checks GLB/import dependency inventory required')
    for relative, row in art_resources.items():
        _require(relative == row.get('path'), 'Current world-art path association mismatch')
        base.record(root, row)
    # Preserve ALL strict material/helper/registry/Warden source checks.
    # Their source-config result is never relabelled as actual native output.
    source_config_status = validate_healing_and_warden_dependencies(root, current, art_resources, base)
    _require(source_config_status == {'status': 'UNPINNED_SOURCE_CONFIG_ONLY', 'canonical_native_imports': None},
             'Strict source material/finite-machine/Warden gate must remain unchanged')

    # Reuse only prior asset-byte proof that remains exactly unaffected. No old
    # frame or wall observation is upgraded into a v096 observation.
    old_assets = parent94.get('unchanged_runtime_assets')
    assets = v.get('unchanged_runtime_assets')
    _require(type(old_assets) is dict and type(assets) is dict
             and set(assets) == set(old_assets), 'Exact inherited asset inventory required')
    for relative, row in old_assets.items():
        _require(assets[relative] == row, 'Historical asset proof may not be rewritten')
        base.record(root, row)

    observation = v.get('native_observation')
    _require(type(observation) is dict and set(observation) == {
        'mode', 'resolution', 'job_count', 'jobs', 'changed_seam_evidence_jobs'}
             and observation.get('mode') == 'actual_moving_contexts'
             and observation.get('resolution') == [640, 360]
             and observation.get('job_count') == len(EXPECTED96_JOBS),
             'Actual 640x360 moving-context observation required')
    jobs = observation.get('jobs')
    _require(type(jobs) is list and len(jobs) == len(EXPECTED96_JOBS),
             'All 22 actual capture jobs required; source counts are not evidence')
    by_id = {}
    for job in jobs:
        _require(type(job) is dict and set(job) == {'id', 'status', 'resolution', 'frames', 'trace', 'trace_join'}
                 and type(job.get('id')) is str and job['id'] not in by_id,
                 'Unique exact capture job IDs required')
        by_id[job['id']] = job
    _require(set(by_id) == set(EXPECTED96_JOBS), 'Missing/foreign/future capture case refused')
    _require(observation.get('changed_seam_evidence_jobs') == list(EXPECTED96_JOBS),
             'Changed HUD seams must be scoped to every actual moving-context capture')
    for job_id in EXPECTED96_JOBS:
        job = by_id[job_id]
        _require(job.get('status') == 'OBSERVED' and job.get('resolution') == [640, 360],
                 'Every capture job needs observed native-resolution output')
        frames = job.get('frames')
        _require(type(frames) is list and frames, 'Empty capture job is not evidence: ' + job_id)
        for frame in frames:
            _require(type(frame) is dict and set(frame) == {
                'path', 'bytes', 'sha256', 'rgba_sha256', 'width', 'height'},
                'Exact lossless frame record required')
            _require(frame['path'].startswith('source/art/consumer-qualification-v0096/')
                     and frame['width'] == 640 and frame['height'] == 360
                     and type(frame['bytes']) is int and frame['bytes'] > 0
                     and re.fullmatch(r'[0-9a-f]{64}', frame['sha256'] or '')
                     and re.fullmatch(r'[0-9a-f]{64}', frame['rgba_sha256'] or ''),
                     'Current96 frame path/bytes/pixel hashes required')
            png = base.record(root, {k: frame[k] for k in ('path', 'bytes', 'sha256')})
            try:
                from io import BytesIO
                from PIL import Image
                with Image.open(BytesIO(png)) as decoded:
                    _require(decoded.format == 'PNG' and decoded.size == (640, 360)
                             and getattr(decoded, 'n_frames', 1) == 1,
                             'Frame must decode as a 640x360 PNG')
                    rgba = decoded.convert('RGBA').tobytes()
            except Exception as exc:
                raise ValueError('Frame must be a decodable resident PNG') from exc
            _require(sha256(rgba).hexdigest() == frame['rgba_sha256'],
                     'Decoded RGBA pixel hash mismatch')
            for prior in (parent94.get('native_observation', {}), parent95.get('native_observation', {})):
                for chapter in prior.get('chapters', ()):
                    for old_frame in chapter.get('frames', ()):
                        old_hashes = {old_frame.get('png_sha256'), old_frame.get('rgba_sha256')}
                        _require(frame['sha256'] not in old_hashes and frame['rgba_sha256'] not in old_hashes,
                                 'Historical94/95 image-byte or pixel reuse is not v096 evidence')
        trace = job.get('trace')
        _require(type(trace) is dict and set(trace) == {'path', 'bytes', 'sha256'},
                 'Per-job actual state/action trace required')
        _require(trace['path'].startswith('source/art/consumer-qualification-v0096/')
                 and type(trace['bytes']) is int and trace['bytes'] > 0,
                 'Current96 trace reference required')
        base.record(root, trace)

    public_join = validate_capture_context_join96(root, v, base)

    scope = v.get('scope')
    _require(type(scope) is dict and set(scope) == {
        'evidence_is_execution_authentication', 'new_art_grade_or_final_visual_acceptance',
        'earned_combat_or_performance_or_package_qualification',
        'new_three_pose_pistol_ABA_qualification', 'new_body_fullmatrix_or_555_qualification',
        'new_gate_opening_or_fullview_qualification', 'full_authored_loop_traversal',
        'human_input_or_listening', 'sustained_performance',
        'changed_consumer_seams_with_actual_evidence'}
             and scope.get('changed_consumer_seams_with_actual_evidence') == sorted(EXPECTED96_CHANGED_SEAMS)
             and scope.get('evidence_is_execution_authentication') is False
             and scope.get('new_art_grade_or_final_visual_acceptance') is False
             and scope.get('earned_combat_or_performance_or_package_qualification') is False
             and scope.get('new_three_pose_pistol_ABA_qualification') is False
             and scope.get('new_body_fullmatrix_or_555_qualification') is False
             and scope.get('new_gate_opening_or_fullview_qualification') is False,
             'v096 scope must retain explicit non-claims')
    _require(scope.get('full_authored_loop_traversal') is False
             and scope.get('human_input_or_listening') is False
             and scope.get('sustained_performance') is False,
             'v096 may not infer whole-campaign/human/performance acceptance')
    # No final return is possible from source config alone or a receipt SHA flip.
    # All public bindings, exact actual compiled generations, raw producer joins,
    # historical/source/art/changed-seam/RGBA/non-claim gates above must pass.
    _require(public_join.get('status') == 'PUBLIC_CONTEXT_IMPORT_JOIN_VALIDATED_NOT_EXECUTION_AUTHENTICATION'
             and public_join.get('cases') == 22
             and public_join.get('native_import_status') == v['native_import_status'],
             'Complete pinned actual public source/native/context join required')
    # Preserve historical() callers without promoting their bytes or images.
    if main_derivation is not None:
        v = {**v, 'status': 'ACTUAL96_GAMEPLAY_WITH_VERIFIER_ONLY_SOURCE_DERIVATION',
             'observed_current_sources': current,
             'current_sources': {**current, 'game/scripts/main.gd': main_derivation['derived_main']},
             'verifier_source_derivation': main_derivation}
    return {**v, 'historical_sources': historical_sources,
            'historical_native_observation': parent95['native_observation'],
            'v0094_historical_native_observation': parent94['native_observation']}


def historical96(root, relative, expected_sha, base=None):
    """Preserve immutable historical lookup while current96 qualification is closed."""
    if relative == 'game/scripts/player.gd':
        _require(expected_sha == PLAYER_V5_HISTORICAL['sha256'], 'Only exact historical v5 Player is supported')
        return qualified_player_consumption96(root, read_resident(root, relative))
    if base is None:
        base = type('_ConsumerReader', (), {})()
        for name in ('read_resident', 'record', 'pinned_receipt'):
            setattr(base, name, globals()[name])
    parent94 = base.pinned_receipt(root, RECEIPT94, RECEIPT94_SHA)
    parent95 = base.pinned_receipt(root, RECEIPT95, RECEIPT95_SHA)
    _require(parent94.get('schema') == 'null-choir-exact-current-art-consumers-v0094-v1'
             and parent94.get('status') == 'ACTUAL_ARRANGED_CURRENT_CONTEXT_OBSERVED'
             and parent95.get('schema') == 'null-choir-exact-current-art-consumers-v0095-v1'
             and parent95.get('status') == 'ACTUAL_CURRENT95_CORRECTED_WALLS_WITH_HISTORICAL_UNCHANGED_ART'
             and parent95.get('parent_qualification') == {
                 'path': RECEIPT94, 'bytes': len(base.read_resident(root, RECEIPT94)),
                 'sha256': RECEIPT94_SHA},
             'Exact immutable94/95 historical chain required')
    row = parent94.get('historical_sources', {}).get(relative)
    _require(type(row) is dict and row.get('sha256') == expected_sha,
             'Only exact retained historical consumer is supported')
    return base.record(root, row)


# Explicitly historical Player, never a normalization of current96 gameplay.
PLAYER_V5_HISTORICAL = {'path':'source/art/consumer-qualification-v0096/provenance/player-v5-historical.gd','bytes':15851,'sha256':'0a1c0959513a068d13a0ac0f3b5a6ad3dca2064155028a568155e11b8f83a5a7'}
PLAYER_PRE_V5 = {'path':'source/art/rivet-forward-v5/provenance/player-before-v5.gd','bytes':15851,'sha256':'d3ff20a302f8ead0f6808683e6ccdd9a2b3f10f711b019fe9808a788faef7bff'}

def qualified96_generation96(value):
    """Result-shape gate only; consumers MUST call full qualify96 first."""
    if type(value) is not dict or value.get('schema') != 'null-choir-exact-current-art-consumers-v0096-v1':
        return False
    if value.get('status') == 'ACTUAL_CURRENT96_MOVING_CONTEXTS_OBSERVED':
        return 'verifier_source_derivation' not in value and 'observed_current_sources' not in value
    if value.get('status') != 'ACTUAL96_GAMEPLAY_WITH_VERIFIER_ONLY_SOURCE_DERIVATION':
        return False
    expected = {**MAIN96_VERIFIER_DERIVATION,
                'status': 'VERIFIER_ONLY_SOURCE_DERIVATION_NOT_NEW_OBSERVATION',
                'outside_verifier_bytes_exact': True, 'new_frames_claimed': False,
                'new_native_import_claimed': False, 'new_gameplay_observation_claimed': False}
    observed = value.get('observed_current_sources')
    current = value.get('current_sources')
    main = 'game/scripts/main.gd'
    return (value.get('verifier_source_derivation') == expected
            and type(observed) is dict and set(observed) == REQUIRED96_SOURCES
            and observed.get(main) == MAIN96_VERIFIER_DERIVATION['observed_main']
            and current == {**observed, main: MAIN96_VERIFIER_DERIVATION['derived_main']})


def qualified_player_consumption96(root, supplied):
    """Return old v5 art-consumer bytes ONLY after complete actual96 qualification.

    No broad source alias: supplied=current resident=final receipt source row.
    qualify96 owns every actual producer/native/source join and remains closed
    until Root finalizes them. Historical bytes establish no gameplay equivalence.
    """
    value = qualify(root)
    _require(qualified96_generation96(value) or qualified97_generation97(value),
             'Fully qualified actual96/97 Player consumption required')
    row = value.get('current_sources', {}).get('game/scripts/player.gd')
    _require(type(row) is dict and row.get('path') == 'game/scripts/player.gd',
             'Final96 receipt must bind the current Player source')
    resident = record(root, row)
    _require(type(supplied) is bytes and supplied == resident,
             'Supplied Player differs from exact resident/final96 receipt source')
    retained = record(root, PLAYER_V5_HISTORICAL)
    before = record(root, PLAYER_PRE_V5)
    old_uri = b'"asset":"native-v4/rivet_pistol"'
    new_uri = b'"asset":"native-v5/rivet_pistol"'
    _require(before.count(old_uri) == 1 and new_uri not in before
             and retained == before.replace(old_uri, new_uri, 1)
             and retained.replace(new_uri, old_uri, 1) == before,
             'Historical v5 snapshot must preserve exact original one-byte proof')
    return retained


# Additive v097: exact current source and explicitly historical96 source views.
# The actual current97 receipt remains closed until real reviewed captures exist.
PREFIX97 = 'source/art/consumer-qualification-v0097/'
SOURCE97 = PREFIX97 + 'source-contract.json'
SOURCE97_SHA = 'a26e8a034d13875f32ba91d094c691350b7990d84d640133c24b6a7d8bf546c3'
RECEIPT97 = PREFIX97 + 'current-consumers.json'
RECEIPT97_SHA = 'aea22f5443352ef82a5b2ad7d5728e44579caed30127560c52447fda5307db87'
PUBLIC97_SUPPLEMENT_BINDINGS = {'producer': {'path': 'source/art/consumer-qualification-v0097/supplement/provenance/producer.gd', 'bytes': 4991, 'sha256': 'ef184f0a1f95af204931ae33a9e0ecbbac4b8679dd7f5568e9e09348b4b14e49'}, 'base_producer': {'path': 'source/art/consumer-qualification-v0097/supplement/provenance/base-producer.gd', 'bytes': 22198, 'sha256': '89fd8e1ba8ea3cbcdd5d37edfdcc81f52a325f27ddeaf4b7785e8c15a888230c'}, 'trace': {'path': 'source/art/consumer-qualification-v0097/supplement/provenance/result.json', 'bytes': 362586, 'sha256': 'e9e9a1b4f58f5df1f45e1e899b3e1779a2f1e9ccda5b5e3d2a49c88797d64506'}, 'script_sources': {'path': 'source/art/consumer-qualification-v0097/supplement/provenance/source.json', 'bytes': 4020, 'sha256': '4a85695cd25a0e602d1736a64d765f7cb4622bd5c01c258b4034372f6d098ef1'}, 'tracked_game': {'path': 'source/art/consumer-qualification-v0097/supplement/provenance/tracked-game.json', 'bytes': 78944, 'sha256': '18e0dd82fc02a9f1ad425e5f439a1679d0f48fd12c016718884200e5e915a753'}, 'supervision': {'path': 'source/art/consumer-qualification-v0097/supplement/provenance/supervision.json', 'bytes': 110, 'sha256': 'fe82c0f24594f34ec6d37c7fddd380a8db91f8f5ee1735bee1c08814eb0e5424'}}
PUBLIC97_BINDINGS = {'producer': {'path': 'source/art/consumer-qualification-v0097/provenance/producer.gd', 'bytes': 22198, 'sha256': '89fd8e1ba8ea3cbcdd5d37edfdcc81f52a325f27ddeaf4b7785e8c15a888230c'}, 'trace': {'path': 'source/art/consumer-qualification-v0097/provenance/result.json', 'bytes': 533827, 'sha256': '111eabd51fdac3ce7224809ff272ecf94cbe85ca8cb96c7a9cdc8c00312f7c15'}, 'script_sources': {'path': 'source/art/consumer-qualification-v0097/provenance/source.json', 'bytes': 4020, 'sha256': '4a85695cd25a0e602d1736a64d765f7cb4622bd5c01c258b4034372f6d098ef1'}, 'tracked_game': {'path': 'source/art/consumer-qualification-v0097/provenance/tracked-game.json', 'bytes': 78944, 'sha256': '18e0dd82fc02a9f1ad425e5f439a1679d0f48fd12c016718884200e5e915a753'}, 'native_identity': {'path': 'source/art/consumer-qualification-v0097/provenance/native-identity.json', 'bytes': 326, 'sha256': '34bb56058d3af44e4eb79d938950c0457de08e1e922c0d8835cf1fcc1d2524b7'}, 'supervision': {'path': 'source/art/consumer-qualification-v0097/provenance/supervision.json', 'bytes': 110, 'sha256': 'fe82c0f24594f34ec6d37c7fddd380a8db91f8f5ee1735bee1c08814eb0e5424'}}
REQUIRED97_SOURCES = REQUIRED96_SOURCES | {
    'game/scripts/enemy_motion.gd', 'game/scripts/enemy_telegraph.gd'}
HISTORICAL96_PATHS97 = {
    'game/export_presets.cfg', 'game/project.godot', 'game/scripts/build_info.gd',
    'game/scripts/critical_actor_practical.gd', 'game/scripts/enemy.gd',
    'game/scripts/main.gd', 'game/scripts/player.gd',
    *(f'game/assets/art/healing_machinery/models/{name}.glb.import' for name in (
        'canted-supported-orbit-core', 'capillary-organ', 'clinical-abstract-capsule',
        'hanging-pressure-bulb', 'ivory-archive-vessel', 'organic-valve-cage',
        'refractory-ceramic-crucible', 'ribbed-marrow-tank')),
    'game/assets/art/healing_machinery/raw/texture-atlas.png.import'}


def validate_source97(root):
    """Static exact-byte binding only; never a rendered-evidence or PASS claim."""
    contract = pinned_receipt(root, SOURCE97, SOURCE97_SHA)
    prior = pinned_receipt(root, RECEIPT96, RECEIPT96_SHA)
    _require(type(contract) is dict and set(contract) == {
        'schema', 'status', 'parent_qualification', 'current_sources',
        'current_art_resources', 'unchanged_runtime_assets', 'current_weapon_art_resources',
        'historical96_snapshots', 'scope'}
        and contract['schema'] == 'null-choir-v097-source-bound-historical-reuse-v1'
        and contract['status'] == 'SOURCE_BOUND_PENDING_CURRENT97_CAPTURE'
        and contract['parent_qualification'] == {
            'path': RECEIPT96, 'bytes': len(read_resident(root, RECEIPT96)), 'sha256': RECEIPT96_SHA}
        and contract['scope'] == {'historical96_is_current97': False,
                                  'new_native_observation': False, 'qualification': False},
        'Exact distinct97 static contract and immutable96 parent required')
    sources, art = contract['current_sources'], contract['current_art_resources']
    _require(type(sources) is dict and set(sources) == REQUIRED97_SOURCES
             and type(art) is dict and set(art) == set(prior['current_art_resources']),
             'Exact49 current97 source and262 art dependency inventory required')
    _require(contract['unchanged_runtime_assets'] == prior['unchanged_runtime_assets'],
             'Exact inherited weapon/body asset inventory required')
    for relative, row in {**sources, **art, **contract['unchanged_runtime_assets']}.items():
        _require(row.get('path') == relative, 'Current97 path association mismatch')
        record(root, row)
    player = record(root, sources['game/scripts/player.gd'])
    weapon_assets = re.findall(rb'"asset":"([^"]+)"', player)
    _require(weapon_assets == [b'painted-v3/impact_tool', b'native-v5/rivet_pistol',
        b'painted-v3/scattergun', b'painted-v3/sawtooth_repeater',
        b'painted-v3/marrow_launcher', b'painted-v3/choir_disruptor'],
        'Current97 Player must retain exact six actual weapon art bindings')
    weapon_art = contract['current_weapon_art_resources']
    expected_weapon_art = {'game/assets/art/weapons/' + asset.decode() + '.png' + suffix
                           for asset in weapon_assets for suffix in ('', '.import')}
    _require(type(weapon_art) is dict and set(weapon_art) == expected_weapon_art,
             'Every currently consumed weapon PNG/import must be byte bound')
    for relative, row in weapon_art.items():
        _require(row.get('path') == relative, 'Current97 weapon art path association mismatch')
        record(root, row)
    snapshots = contract['historical96_snapshots']
    observed = {**prior['current_sources'], **prior['current_art_resources']}
    _require(type(snapshots) is dict and set(snapshots) == HISTORICAL96_PATHS97,
             'Only exact seven96 code/config and nine96 sidecar snapshots allowed')
    for relative, binding in snapshots.items():
        _require(type(binding) is dict and set(binding) == {'observed96', 'snapshot'}
                 and binding['observed96'] == observed[relative]
                 and binding['snapshot']['path'] == PREFIX97 + 'provenance/historical96/' + relative.removeprefix('game/')
                 and {k: binding['snapshot'][k] for k in ('bytes', 'sha256')}
                     == {k: observed[relative][k] for k in ('bytes', 'sha256')},
                 'Historical96 snapshot must equal original96 receipt, not rewritten97 source')
        record(root, binding['snapshot'])
    # All unaffected source/art dependencies retain their exact original96 rows.
    for relative, row in observed.items():
        if relative not in snapshots:
            _require((sources if relative in sources else art)[relative] == row,
                     'Unexpected source/art difference outside enumerated97 changes')
    return contract


def _historical96_reader97(root, contract):
    """Finite historical-only view; cannot qualify current97 by source alias."""
    view = type('_Historical96Reader97', (), {})()
    snapshots = contract['historical96_snapshots']
    exact_root = str(Path(root).absolute())
    def historical_read(evidence_root, relative):
        _require(str(Path(evidence_root).absolute()) == exact_root, 'Historical96 projection root drift')
        binding = snapshots.get(relative)
        if binding is not None:
            return record(evidence_root, binding['snapshot'])
        return read_resident(evidence_root, relative)
    def historical_record(evidence_root, row):
        binding = snapshots.get(row.get('path'))
        if binding is not None:
            _require(row == binding['observed96'], 'Historical96 projected record drift')
        raw = historical_read(evidence_root, row['path'])
        _require(set(row) == {'path', 'bytes', 'sha256'} and type(row['bytes']) is int
                 and len(raw) == row['bytes'] and sha(raw) == row['sha256'],
                 'Exact historical96 dependency drift: ' + row['path'])
        return raw
    view.read_resident = historical_read
    view.record = historical_record
    view.pinned_receipt = pinned_receipt
    view.sha = sha
    view.function = function
    view._historical96_snapshots = snapshots
    return view


def _project_historical96_for97(producer, root, base):
    """Project only sixteen historical96 producer paths; validators unchanged."""
    regular = producer._regular
    def projected(project, relative):
        resident = regular(project, relative) # Keep original no-follow gates.
        binding = base._historical96_snapshots.get(relative)
        if binding is None:
            return resident
        _require(Path(project).resolve() == Path(root).resolve(), 'Historical96 producer root drift')
        record(root, binding['snapshot'])
        return Path(root) / binding['snapshot']['path']
    producer._regular = projected
    # The unchanged producer has exactly one direct project/path read outside
    # _regular: its literal96 display-name check. Feed that SAME validator a
    # finite one-path view; do not replace its regex/result with a96 constant.
    original_version = producer.source_build_version
    class BuildSourceView:
        def __init__(self, project):
            self.project = project
        def __truediv__(self, relative):
            _require(relative == 'game/scripts/build_info.gd',
                     'Only historical96 build identity direct read is projected')
            return projected(self.project, relative)
    def historical_version(project=Path(root)):
        return original_version(BuildSourceView(project))
    producer.source_build_version = historical_version
    return producer


def validate_historical96_reuse97(root, contract=None):
    """Revalidate all22 old contexts under original96 sources, NOT current97."""
    checked = validate_source97(root)
    _require(contract is None or contract == checked, 'Historical96 contract drift')
    value = qualify96(root, _historical96_reader97(root, checked))
    _require(value['status'] == 'ACTUAL_CURRENT96_MOVING_CONTEXTS_OBSERVED',
             'Historical96 view must preserve original observation identity')
    return {'status': 'HISTORICAL96_REVALIDATED_NOT_CURRENT97',
            'receipt': checked['parent_qualification'], 'qualification': value,
            'current97_observation_claimed': False}


def _qualify97_uncached(root):
    """Distinct actual97 generation; no source normalization or historical pixels."""
    contract = validate_source97(root)
    _require(type(RECEIPT97_SHA) is str and re.fullmatch('[0-9a-f]{64}', RECEIPT97_SHA),
             'v097 actual current-source frame/trace/native receipt remains unpinned')
    value = pinned_receipt(root, RECEIPT97, RECEIPT97_SHA)
    _require(type(value) is dict and set(value) == {
        'schema', 'status', 'source_contract', 'parent_qualification',
        'current_sources', 'current_art_resources', 'current_weapon_art_resources',
        'unchanged_runtime_assets', 'native_observation', 'historical96_reuse', 'scope'}
        and value['schema'] == 'null-choir-exact-current-art-consumers-v0097-v1'
        and value['status'] == 'ACTUAL_CURRENT97_ORDINARY_THREAT_CONTEXTS_OBSERVED'
        and value['source_contract'] == {
            'path': SOURCE97, 'bytes': len(read_resident(root, SOURCE97)), 'sha256': SOURCE97_SHA}
        and value['parent_qualification'] == contract['parent_qualification'],
        'Exact distinct actual97 receipt schema/source/historical parent required')
    for group in ('current_sources', 'current_art_resources', 'current_weapon_art_resources',
                  'unchanged_runtime_assets'):
        _require(value[group] == contract[group], 'Current97 receipt/source inventory drift')
    join = validate_capture_context_join97(root, value, contract)
    validate_supplement_join97(root, value, contract)
    historical_result = validate_historical96_reuse97(root, contract)
    expected_reuse = {'status': historical_result['status'],
                     'receipt': historical_result['receipt'],
                     'current97_observation_claimed': False}
    _require(value['historical96_reuse'] == expected_reuse,
             'Old96 qualification must remain explicit historical reuse')
    _require(value['scope'] == SCOPE97, 'Current97 scope must preserve exact non-claims')
    _require(join['status'] == 'PUBLIC97_FRAME_TRACE_SOURCE_NATIVE_JOIN_VALIDATED',
             'Actual97 public graphical evidence required')
    return {**value, 'historical_sources': historical_result['qualification']['historical_sources'],
            'historical_native_observation': historical_result['qualification']['native_observation']}


def qualify97(root):
    """Successful97 audit reuse requires rereading every mutable dependency.

    This is the same strict content-footprint replay as96, including all506
    captured game files, source snapshots, producer/trace/native artifacts,
    every current97 and historical96 PNG and exact PNG directory memberships.
    No stat shortcut, cached failure, caller reader or patched validator bypass.
    """
    import copy
    if any(globals().get(name) is not value for name, value in _MEMO96_FUNCTIONS.items()):
        return _qualify97_uncached(root)
    key = ('97', *_memo96_key(root))
    store = _memo96_store()
    prior = store.get(key)
    if prior is not None:
        if _memo96_replay(root, prior['observed']):
            return copy.deepcopy(prior['value'])
        del store[key]
    observed = {'root': str(Path(root).absolute()), 'files': {}, 'directories': {}}
    token = _QUALIFY96_READS.set(observed)
    try:
        value = _qualify97_uncached(root)
    finally:
        _QUALIFY96_READS.reset(token)
    _require(_memo96_replay(root, observed), 'Dependency changed during97 audit; result not reusable')
    if len(store) >= 8:
        store.pop(next(iter(store)))
    store[key] = {'observed': observed, 'value': copy.deepcopy(value)}
    return value


def qualified97_generation97(value):
    """Result-shape gate only; consumers MUST call full qualify97 first."""
    return (type(value) is dict
            and value.get('schema') == 'null-choir-exact-current-art-consumers-v0097-v1'
            and value.get('status') == 'ACTUAL_CURRENT97_ORDINARY_THREAT_CONTEXTS_OBSERVED'
            and value.get('scope') == SCOPE97
            and value.get('source_contract', {}).get('sha256') == SOURCE97_SHA
            and value.get('historical96_reuse') == {
                'status': 'HISTORICAL96_REVALIDATED_NOT_CURRENT97',
                'receipt': value.get('parent_qualification'),
                'current97_observation_claimed': False}
            and 'verifier_source_derivation' not in value
            and 'observed_current_sources' not in value)


SCOPE97 = {
    'arranged_current97_ordinary_threat_visibility': True,
    'actual_short_AI_motion_not_earned_combat': True,
    'aggregate_offscreen_CPU_timing_samples_not_FPS': True,
    'supplemental_offcenter_crawler_caster_views': True,
    'warmed_alternating_forced_draw_sync_readback_latency_not_exclusive_GPU_or_FPS': True,
    'GPU_timing_available': False,
    'evidence_is_execution_authentication': False,
    'historical96_frames_or_sources_are_current97': False,
    'new_three_pose_pistol_ABA_qualification': False,
    'new_body_fullmatrix_or_555_qualification': False,
    'new_gate_opening_or_fullview_qualification': False,
    'new_art_grade_or_final_visual_acceptance': False,
    'earned_combat_or_performance_or_package_qualification': False,
    'full_authored_loop_traversal': False,
    'human_input_or_listening': False,
    'sustained_performance': False,
    'native8K_or_editable_master_qualification': False,
    'new_native_import_cache_qualification': False}


def _public97_bytes(root, row):
    _require(type(row) is dict and type(row.get('path')) is str
             and row['path'].startswith(PREFIX97), 'Exact public97 artifact namespace required')
    raw = record(root, row)
    # Reuse the exact existing portable privacy scanner, not a redactor.
    import importlib.util
    binding = PUBLIC96_BINDINGS['portable_module']
    record(root, binding)
    spec = importlib.util.spec_from_file_location('_public97_privacy', Path(root) / binding['path'])
    portable = importlib.util.module_from_spec(spec); spec.loader.exec_module(portable)
    portable.privacy(raw)
    return raw


def _public97_json(root, row):
    return json.loads(_public97_bytes(root, row))


def _ordinary_roster97(root, contract):
    supplies = json.loads(record(root, contract['current_sources']['game/data/earned_supplies.json']))
    roster = {}
    for chapter, name in enumerate(LEVEL_IDS):
        layout = json.loads(record(root, contract['current_sources'][f'game/data/{chapter+1:02d}_{name}.json']))
        carriers = {grant.get('carrier') for grant in supplies['chapters'][name]['grants']}
        for role in ('worker', 'crawler', 'caster', 'brute'):
            eligible = [actor for actor in layout['enemies'] if actor['kind'] == role
                        and not actor.get('seal_guardian') and not actor.get('door_warden')
                        and not actor.get('encounter') and actor['id'] not in carriers]
            if eligible:
                roster[(chapter, role)] = eligible[0]['id']
    _require({chapter for chapter, role in roster} == set(range(8)),
             'All eight source-derived ordinary threat chapters required')
    return roster


def validate_capture_context_join97(root, receipt, contract):
    """Portable actual97 byte/pixel/state joins; not execution authentication."""
    import math
    pins = PUBLIC97_BINDINGS
    _require(type(pins) is dict and set(pins) == {
        'producer', 'trace', 'script_sources', 'tracked_game', 'native_identity', 'supervision'},
        'Final actual97 public artifact bindings remain UNPINNED')
    observation = receipt['native_observation']
    _require(type(observation) is dict and set(observation) == {
        'mode', 'resolution', 'artifacts', 'frames', 'chapter_roles', 'GPU_timing_available', 'supplement'}
        and observation['mode'] == 'actual_arranged_current97_ordinary_threat_contexts'
        and observation['resolution'] == [640, 360] and observation['artifacts'] == pins
        and observation['GPU_timing_available'] is False,
        'Distinct actual97 observation/artifact and timing limits required')
    for row in pins.values():
        _require(row['path'].startswith(PREFIX97), 'Current97 artifact outside exact public namespace')
        record(root, row)
    producer = _public97_bytes(root, pins['producer'])
    _require(producer == read_resident(root, 'game/tests/qualify_v0097_visibility.gd'),
             'Captured97 producer differs from exact current fixture')
    trace = _public97_json(root, pins['trace'])
    tracked = _public97_json(root, pins['tracked_game'])
    scripts = _public97_json(root, pins['script_sources'])
    native = _public97_json(root, pins['native_identity'])
    supervision = _public97_json(root, pins['supervision'])
    _require(type(tracked) is dict and tracked and all(
        type(path) is str and path.startswith('game/') and not path.startswith('game/tests/')
        and type(row) is dict and set(row) == {'bytes', 'sha256'} for path, row in tracked.items()),
        'Exact captured exportable tracked-game byte inventory required')
    for relative, row in tracked.items():
        record(root, {'path': relative, **row})
    for group in ('current_sources', 'current_art_resources', 'current_weapon_art_resources', 'unchanged_runtime_assets'):
        for relative, row in contract[group].items():
            _require(tracked.get(relative) == {k: row[k] for k in ('bytes', 'sha256')},
                     'Actual captured source/art manifest must join current97 contract')
    expected_scripts = {path: row['sha256'] for path, row in tracked.items()
                        if path.startswith('game/scripts/') and path.endswith('.gd')}
    _observe_source_directory97(root)
    _require(scripts == expected_scripts
             and {str(p.relative_to(root)) for p in (Path(root) / 'game/scripts').glob('*.gd')}
                 == set(scripts), 'Missing/foreign source script outside actual97 capture refused')
    _require(type(native) is dict and set(native) == {
        'schema', 'engine', 'version', 'executable_bytes', 'executable_sha256',
        'rendering_method', 'rendering_driver', 'execution_authenticated'}
        and native['schema'] == 'null-choir-v097-native-engine-identity-v1'
        and native['engine'] == 'Godot' and native['version'] == '4.7.2'
        and type(native['executable_bytes']) is int and native['executable_bytes'] > 0
        and re.fullmatch('[0-9a-f]{64}', native['executable_sha256'])
        and native['rendering_method'] == 'mobile' and native['rendering_driver'] == 'metal'
        and native['execution_authenticated'] is False,
        'Exact retained native97 binary identity and honest non-authentication required')
    _require(supervision == {'launcher_exit': 0, 'fault': None, 'native_report_exists': True,
                            'execution_authenticated': False},
             'Actual completed no-fault97 supervision summary required')
    _require(type(trace) is dict and set(trace) == {
        'arranged', 'arrangements', 'completed_chapters', 'earned_combat', 'events', 'failed',
        'frames', 'hardware_input', 'hidden_manual_draw', 'motion', 'performance_claim',
        'rendering_driver', 'rendering_method', 'required_chapters', 'resolution', 'schema', 'status'}
        and trace.get('schema') == 'null-choir-v097-ordinary-threat-native-context-v1'
        and trace.get('status') == 'CAPTURED_PENDING_INDEPENDENT_REVIEW'
        and trace.get('failed') is False and trace.get('resolution') == [640, 360]
        and trace.get('required_chapters') == list(range(8))
        and trace.get('completed_chapters') == list(range(8))
        and trace.get('arranged') is True and trace.get('earned_combat') is False
        and trace.get('hardware_input') is False and trace.get('performance_claim') is False
        and trace.get('hidden_manual_draw') is True
        and trace.get('rendering_method') == native['rendering_method']
        and trace.get('rendering_driver') == native['rendering_driver'],
        'Actual full eight-chapter completed97 trace and native identity required')
    roster = _ordinary_roster97(root, contract)
    expected_roles = [{'chapter': chapter, 'role': role, 'actor': actor}
                      for (chapter, role), actor in roster.items()]
    _require(observation['chapter_roles'] == expected_roles,
             'Actual97 role coverage must derive from ordinary active source actors')
    expected_files = {}
    suffixes = ('mid-off-control', 'mid-current', 'mid-hidden-control', 'mid-reduced',
                'near-current', 'motion-00', 'motion-11', 'motion-23', 'motion-35')
    for (chapter, role), actor in roster.items():
        for suffix in suffixes + (('occluded-present', 'occluded-hidden') if role == 'worker' else ()):
            expected_files[f'chapter-{chapter}-{role}-{suffix}.png'] = (chapter, role, actor, suffix)
    frames = observation['frames']; emitted = trace.get('frames')
    _require(type(frames) is list and type(emitted) is list and len(frames) == len(expected_files)
             and len(emitted) == len(expected_files), 'Every actual97 near/mid/moving/control/occluded frame required')
    by_file = {frame.get('file'): frame for frame in emitted}
    _require(len(by_file) == len(emitted) and set(by_file) == set(expected_files),
             'Missing/foreign/duplicate actual97 frame refused')
    _require([Path(frame['path']).name for frame in frames] == [frame['file'] for frame in emitted],
             'Receipt frame order must match exact emitted97 trace order')
    directory = PREFIX97 + 'frames'
    _observe_png_directory96(root, directory)
    _require({p.name for p in (Path(root) / directory).glob('*.png')} == set(expected_files),
             'Unexpected PNG membership outside exact actual97 frame inventory')
    old96 = pinned_receipt(root, RECEIPT96, RECEIPT96_SHA)
    historical_pixels = {frame[key] for job in old96['native_observation']['jobs']
                         for frame in job['frames'] for key in ('sha256', 'rgba_sha256')}
    for frame in frames:
        _require(type(frame) is dict and set(frame) == {
            'path', 'bytes', 'sha256', 'rgba_sha256', 'width', 'height'}
            and frame['path'] == directory + '/' + Path(frame['path']).name
            and frame['width'] == 640 and frame['height'] == 360,
            'Exact current97 public lossless frame record required')
        filename = Path(frame['path']).name
        state = by_file[filename]; chapter, role, actor, suffix = expected_files[filename]
        _require(set(state) == {'actor', 'actor_position', 'camera', 'chapter', 'file', 'light_energy',
            'physics_tick', 'player_foot', 'reduced_effects', 'role', 'sha256', 'sprite_corners', 'sprite_visible'}
                 and state.get('sha256') == frame['sha256'] and state.get('chapter') == chapter
                 and state.get('role') == role and state.get('actor') == actor
                 and state.get('sprite_visible') is (suffix not in ('mid-hidden-control', 'occluded-hidden'))
                 and state.get('reduced_effects') is (suffix == 'mid-reduced')
                 and type(state.get('light_energy')) in (float, int)
                 and abs(state['light_energy'] - (0 if suffix == 'mid-off-control' else .65)) < .000001
                 and type(state.get('physics_tick')) is int,
                 'Exact97 PNG/state/actor/light/hidden/reduced relationships required')
        _require(frame['sha256'] not in historical_pixels and frame['rgba_sha256'] not in historical_pixels,
                 'Historical96 PNG/pixel reuse is not current97 graphical evidence')
        png = _public97_bytes(root, {k: frame[k] for k in ('path', 'bytes', 'sha256')})
        from io import BytesIO
        from PIL import Image
        with Image.open(BytesIO(png)) as decoded:
            _require(decoded.format == 'PNG' and decoded.size == (640, 360)
                     and getattr(decoded, 'n_frames', 1) == 1,
                     'Actual97 frame must decode as640x360 lossless PNG')
            _require(sha(decoded.convert('RGBA').tobytes()) == frame['rgba_sha256'],
                     'Actual97 decoded RGBA drift')
    motion = trace.get('motion'); events = trace.get('events')
    _require(type(motion) is list and len(motion) == len(roster) * 36 and type(events) is list,
             'All actual short AI motion rows and aggregate timing events required')
    for (chapter, role), actor in roster.items():
        rows = [row for row in motion if row.get('chapter') == chapter and row.get('role') == role]
        _require(len(rows) == 36 and [row.get('tick') for row in rows] == list(range(36))
                 and all(row.get('actor') == actor for row in rows), 'Exact per-role36tick actual97 motion join required')
        approaches = [row for row in events if row.get('kind') == 'actual_AI_short_approach_not_earned_combat'
                      and row.get('chapter') == chapter and row.get('role') == role]
        _require(len(approaches) == 1 and approaches[0].get('actor') == actor
                 and approaches[0].get('end') == by_file[f'chapter-{chapter}-{role}-motion-35.png']['actor_position']
                 and approaches[0].get('start') == by_file[f'chapter-{chapter}-{role}-mid-current.png']['actor_position']
                 and approaches[0].get('start') != approaches[0].get('end'),
                 'Actual97 short AI approach must move and join its final source actor state')
        physics_ticks = []
        for tick in (0, 11, 23, 35):
            state = by_file[f'chapter-{chapter}-{role}-motion-{tick:02d}.png']
            physics_ticks.append(state['physics_tick'])
        # snap() awaits real warm draws while production AI remains active.
        # Its pixels/state therefore follow, not coincide with, the sample row
        # naming that phase. Do not invent a same-physics-tick relationship.
        _require(all(a < b for a, b in zip(physics_ticks, physics_ticks[1:])),
                 'Actual97 moving capture phases need increasing real physics ticks')
    timing = [row for row in events if row.get('kind') == 'aggregate_light_cost_offscreen_not_FPS']
    _require(len(events) == len(roster) + 24 and len(timing) == 24,
             'Only actual per-role motion and eight-chapter aggregate timing events required')
    for chapter in range(8):
        rows = [row for row in timing if row.get('chapter') == chapter]
        layout = json.loads(record(root, contract['current_sources'][f'game/data/{chapter+1:02d}_{LEVEL_IDS[chapter]}.json']))
        supplies = json.loads(record(root, contract['current_sources']['game/data/earned_supplies.json']))
        carriers = {grant.get('carrier') for grant in supplies['chapters'][LEVEL_IDS[chapter]]['grants']}
        ordinary_count = sum(not actor.get('seal_guardian') and not actor.get('door_warden')
                             and actor['id'] not in carriers for actor in layout['enemies'])
        _require([row.get('variant') for row in rows] == ['all_current', 'ordinary_off', 'all_current_repeat']
                 and all(type(row.get('ordinary_lights')) is int and row['ordinary_lights'] == ordinary_count
                         and type(row.get('samples')) is list and len(row['samples']) == 20 for row in rows),
                 'Exact all/off/repeat20sample aggregate CPU light timing required per chapter')
        for row in rows:
            for sample in row['samples']:
                _require(type(sample) is dict and set(sample) == {'cpu_render_ms', 'gpu_render_ms'}
                         and type(sample['cpu_render_ms']) in (int, float)
                         and math.isfinite(sample['cpu_render_ms']) and sample['cpu_render_ms'] > 0
                         and sample['gpu_render_ms'] == 0,
                         'Actual positive CPU timings with explicitly unavailable GPU timing required')
    return {'status': 'PUBLIC97_FRAME_TRACE_SOURCE_NATIVE_JOIN_VALIDATED',
            'chapters': 8, 'roles': len(roster), 'frames': len(frames),
            'execution_authenticated': False}


def validate_supplement_join97(root, receipt, contract):
    """Independent offcenter emitter and warmed total draw/readback observations."""
    pins = PUBLIC97_SUPPLEMENT_BINDINGS
    _require(type(pins) is dict and set(pins) == {
        'producer', 'base_producer', 'trace', 'script_sources', 'tracked_game', 'supervision'},
        'Actual97 offcenter supplement bindings remain UNPINNED')
    observation = receipt['native_observation']['supplement']
    _require(type(observation) is dict and set(observation) == {'artifacts', 'frames', 'chapter_roles'}
             and observation['artifacts'] == pins, 'Exact actual97 supplemental observation binding required')
    for row in pins.values():
        _public97_bytes(root, row)
    _require(record(root, pins['producer']) == read_resident(root, 'game/tests/qualify_v0097_visibility_supplement.gd')
             and record(root, pins['base_producer']) == record(root, PUBLIC97_BINDINGS['producer']),
             'Exact supplemental producer and unchanged captured base fixture required')
    for key in ('script_sources', 'tracked_game'):
        _require(record(root, pins[key]) == record(root, PUBLIC97_BINDINGS[key]),
                 'Supplement must capture the same exact current97 source/art generation')
    _require(_public97_json(root, pins['supervision']) == {
        'launcher_exit': 0, 'fault': None, 'native_report_exists': True, 'execution_authenticated': False},
        'Completed no-fault supplemental native supervision required')
    trace = _public97_json(root, pins['trace'])
    base_trace = _public97_json(root, PUBLIC97_BINDINGS['trace'])
    _require(type(trace) is dict and set(trace) == set(base_trace)
        and trace['schema'] == 'null-choir-v097-offcenter-supplement-v1'
        and trace['required_chapters'] == list(range(8)) and trace['completed_chapters'] == list(range(8))
        and trace['status'] == 'CAPTURED_PENDING_INDEPENDENT_REVIEW' and trace['failed'] is False
        and trace['arranged'] is True and trace['earned_combat'] is False and trace['hardware_input'] is False
        and trace['performance_claim'] is False and trace['hidden_manual_draw'] is True
        and trace['resolution'] == [640, 360] and trace['rendering_method'] == 'mobile'
        and trace['rendering_driver'] == 'metal', 'Actual completed eight-chapter offcenter native trace required')
    roster = {key: actor for key, actor in _ordinary_roster97(root, contract).items()
              if key[1] in ('crawler', 'caster')}
    _require(observation['chapter_roles'] == [{'chapter': chapter, 'role': role, 'actor': actor}
             for (chapter, role), actor in roster.items()], 'Source-derived offcenter role roster required')
    suffixes = ('mid-off-control', 'mid-current', 'mid-hidden-control', 'mid-reduced',
                'motion-00', 'motion-11', 'motion-23', 'motion-35')
    expected = {f'chapter-{chapter}-{role}-offcenter-{suffix}.png': (chapter, role, actor, suffix)
                for (chapter, role), actor in roster.items() for suffix in suffixes}
    emitted, frames = trace['frames'], observation['frames']
    _require(type(emitted) is list and type(frames) is list
             and len(emitted) == len(expected) and len(frames) == len(expected),
             'Every actual97 offcenter control/reduced/motion frame required')
    by_file = {frame.get('file'): frame for frame in emitted}
    _require(set(by_file) == set(expected) and len(by_file) == len(emitted)
             and [Path(frame['path']).name for frame in frames] == [frame['file'] for frame in emitted],
             'Exact unique ordered supplemental frame emission required')
    directory = PREFIX97 + 'supplement/frames'
    _observe_png_directory96(root, directory)
    _require({p.name for p in (Path(root) / directory).glob('*.png')} == set(expected),
             'Foreign/missing supplemental PNG directory member refused')
    old96 = pinned_receipt(root, RECEIPT96, RECEIPT96_SHA)
    historical_pixels = {frame[key] for job in old96['native_observation']['jobs']
                         for frame in job['frames'] for key in ('sha256', 'rgba_sha256')}
    historical_pixels.update(frame[key] for frame in receipt['native_observation']['frames']
                             for key in ('sha256', 'rgba_sha256'))
    for frame in frames:
        _require(type(frame) is dict and set(frame) == {
            'path', 'bytes', 'sha256', 'rgba_sha256', 'width', 'height'}
            and frame['path'] == directory + '/' + Path(frame['path']).name
            and frame['width'] == 640 and frame['height'] == 360,
            'Exact lossless public supplemental97 frame record required')
        state = by_file[Path(frame['path']).name]
        chapter, role, actor, suffix = expected[Path(frame['path']).name]
        _require(set(state) == set(base_trace['frames'][0])
                 and state['sha256'] == frame['sha256'] and state['chapter'] == chapter
                 and state['role'] == role and state['actor'] == actor
                 and state['sprite_visible'] is (suffix != 'mid-hidden-control')
                 and state['reduced_effects'] is (suffix == 'mid-reduced')
                 and type(state['light_energy']) in (int, float)
                 and abs(state['light_energy'] - (0 if suffix == 'mid-off-control' else .65)) < .000001
                 and type(state['physics_tick']) is int,
                 'Exact supplemental pixel/light/hidden/reduced/actor trace join required')
        _require(frame['sha256'] not in historical_pixels and frame['rgba_sha256'] not in historical_pixels,
                 'Old96/base97 pixels are not new supplemental graphical evidence')
        png = _public97_bytes(root, {k: frame[k] for k in ('path', 'bytes', 'sha256')})
        from io import BytesIO
        from PIL import Image
        with Image.open(BytesIO(png)) as decoded:
            _require(decoded.format == 'PNG' and decoded.size == (640, 360)
                     and getattr(decoded, 'n_frames', 1) == 1
                     and sha(decoded.convert('RGBA').tobytes()) == frame['rgba_sha256'],
                     'Supplemental97 PNG/decoded pixel drift')
    _require(len(trace['motion']) == len(roster) * 36 and len(trace['events']) == len(roster) + 8,
             'All supplemental motion and eight warmed draw/readback events required')
    for (chapter, role), actor in roster.items():
        prefix = f'chapter-{chapter}-{role}-offcenter-'
        rows = [row for row in trace['motion'] if row.get('chapter') == chapter and row.get('role') == role]
        _require(len(rows) == 36 and [row.get('tick') for row in rows] == list(range(36))
                 and all(row.get('actor') == actor for row in rows), 'Exact supplemental36tick source actor trace required')
        event = [row for row in trace['events'] if row.get('kind') == 'actual_AI_short_approach_not_earned_combat'
                 and row.get('chapter') == chapter and row.get('role') == role]
        _require(len(event) == 1 and event[0]['actor'] == actor
                 and event[0]['start'] == by_file[prefix+'mid-current.png']['actor_position']
                 and event[0]['end'] == by_file[prefix+'motion-35.png']['actor_position']
                 and event[0]['start'] != event[0]['end'], 'Actual supplemental AI movement/frame endpoint join required')
        ticks = [by_file[prefix+f'motion-{tick:02d}.png']['physics_tick'] for tick in (0, 11, 23, 35)]
        _require(all(a < b for a, b in zip(ticks, ticks[1:])), 'Supplemental moving frames must progress through physics')
        drains = [row for row in trace['arrangements'] if row.get('kind') == 'natural_UI_transient_drain_before_pair'
                  and row.get('chapter') == chapter and row.get('role') == role]
        _require(len(drains) == 1 and drains[0]['damage_flash'] == 0 and drains[0]['hit_flash'] == 0
                 and drains[0]['weapon_hidden'] is False and drains[0]['fov'] == 85
                 and type(drains[0]['camera_eye']) is list and len(drains[0]['camera_eye']) == 3
                 and all(abs(a-b) < .000001 for a,b in zip(drains[0]['camera_eye'], [0, 1.55, 0])),
                 'Actual naturally drained UI pair must retain production eye/FOV/pistol')
    timing = [row for row in trace['events'] if row.get('kind') == 'warmed_alternating_draw_readback_not_GPU_or_FPS']
    _require(len(timing) == 8 and {row['chapter'] for row in timing} == set(range(8)),
             'All eight warmed standing-view draw/readback series required')
    counts = {row['chapter']: row['ordinary_lights'] for row in base_trace['events']
              if row['kind'] == 'aggregate_light_cost_offscreen_not_FPS'}
    for event in timing:
        _require(event['ordinary_lights'] == counts[event['chapter']]
                 and type(event['batches']) is list and len(event['batches']) == 8,
                 'Same source ordinary-light population and eight alternating batches required')
        for index, batch in enumerate(event['batches']):
            _require(batch['batch'] == index and abs(batch['energy'] - (.65 if index % 2 == 0 else 0)) < .000001
                     and type(batch['samples']) is list and len(batch['samples']) == 8,
                     'Exact warmed alternating on/off eight-sample batches required')
            for sample in batch['samples']:
                _require(type(sample) is dict and set(sample) == {'draw_and_readback_usec', 'width', 'height'}
                         and type(sample['draw_and_readback_usec']) is int and sample['draw_and_readback_usec'] > 0
                         and sample['width'] == 640 and sample['height'] == 360,
                         'Actual forced draw/synchronization/readback latency, not GPU/FPS, required')
    return {'status': 'PUBLIC97_SUPPLEMENT_TRACE_FRAME_TIMING_JOIN_VALIDATED',
            'chapters': 8, 'roles': len(roster), 'frames': len(frames), 'execution_authenticated': False}


# Shared only inside this Python process: legacy ledgers load this helper through
# runpy repeatedly. Store hashes and a deep-copied public result, never raw input
# bytes. Root + helper source bytes + all public pin/config values isolate entries.
def _memo96_store():
    import sys
    import types
    name = '_null_choir_exact_qualification96_memo_v1'
    shared = sys.modules.setdefault(name, types.ModuleType(name))
    if not hasattr(shared, 'entries'):
        shared.entries = {}
    return shared.entries


def _memo96_key(root):
    config = {name: value for name, value in globals().items()
              if name.isupper() and not name.startswith('_')}
    config_raw = json.dumps(config, sort_keys=True, default=lambda value: sorted(value),
                            separators=(',', ':')).encode()
    return (str(Path(root).absolute()), _MEMO96_CODE_SHA,
            sha(Path(__file__).read_bytes()), sha(config_raw))


def _memo96_replay(root, observed):
    # No stat/mtime shortcut. Each hit rechecks strict no-follow/residency gates,
    # every complete file's byte count and SHA, plus producer directory membership.
    if str(Path(root).absolute()) != observed['root']:
        return False
    for relative, expected in observed['files'].items():
        raw = read_resident(root, relative)
        if (len(raw), hashlib.sha256(raw).hexdigest()) != expected:
            return False
    for relative, expected in observed['directories'].items():
        if tuple(sorted(p.name for p in (Path(root) / relative).glob('*.png'))) != expected:
            return False
    for relative, expected in observed.get('source_directories', {}).items():
        if tuple(sorted(p.name for p in (Path(root) / relative).glob('*.gd'))) != expected:
            return False
    return True


def qualify96(root, base=None):
    """Exact qualification, with full-content guarded successful audit reuse.

    Custom readers or patched validation functions always take the uncached path.
    The footprint covers base strict reads plus portable artifact reads. The
    unchanged producer's direct reads are exactly the already-recorded source
    manifest rows, ten metadata files/per-case schemas, and PNGs; its only glob
    is the explicitly replayed per-case PNG membership. No failure is cached.
    """
    import copy
    if base is not None or any(globals().get(name) is not value
                               for name, value in _MEMO96_FUNCTIONS.items()):
        return _qualify96_uncached(root, base)
    key = _memo96_key(root)
    store = _memo96_store()
    prior = store.get(key)
    if prior is not None:
        if _memo96_replay(root, prior['observed']):
            return copy.deepcopy(prior['value'])
        del store[key]
    observed = {'root': str(Path(root).absolute()), 'files': {}, 'directories': {}}
    token = _QUALIFY96_READS.set(observed)
    try:
        value = _qualify96_uncached(root)
    finally:
        _QUALIFY96_READS.reset(token)
    if not _memo96_replay(root, observed):
        raise ValueError('Dependency changed during qualification; audit not reusable')
    if len(store) >= 8:
        store.pop(next(iter(store)))
    store[key] = {'observed': observed, 'value': copy.deepcopy(value)}
    return value


# Do not let mocked/custom validation poison or bypass canonical audits. This
# comparison is local to each runpy namespace; the content keys above share only
# completed canonical results across otherwise equivalent helper imports.
_MEMO96_CODE_SHA = sha(Path(__file__).read_bytes())
_MEMO96_FUNCTIONS = {name: value for name, value in list(globals().items())
                     if getattr(value, '__globals__', None) is globals()}
