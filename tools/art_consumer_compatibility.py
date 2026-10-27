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


def qualify(root):
    raw = read_resident(root, RECEIPT)
    if sha(raw) != RECEIPT_SHA:
        raise ValueError('Exact current-consumer receipt required; missing/stale/rehashed receipts refused')
    value = json.loads(raw)
    # The hard pin binds every field, frame inventory, scope limitation and raw
    # private-evidence hash. No paths/argv/HOME or private quality numbers copied.
    if (value['schema'] != 'null-choir-exact-current-art-consumers-v0094-v1'
            or value['status'] != 'ACTUAL_ARRANGED_CURRENT_CONTEXT_OBSERVED'):
        raise ValueError('Wrong current consumer generation/scope')
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
