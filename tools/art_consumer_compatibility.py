"""One exact later consumer generation; retained native art receipts stay historical.

Hash-bound receipts are evidence joins, not authentication of a run or an art grade.
Never normalize a foreign consumer or infer fresh fullmatrix/ABA/gate-open proof.
"""
import hashlib
import json
from pathlib import Path
import re
import stat

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
    return path.read_bytes()


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
    value = qualify(root)
    row = value['historical_sources'].get(relative)
    if row is None or row['sha256'] != expected_sha:
        raise ValueError('Only the exact retained historical consumer is supported')
    return record(root, row)
