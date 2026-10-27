#!/usr/bin/env python3
"""Check display metadata or explicitly reserve an integer development ordinal.

Default operation is read-only. --reserve updates only the allocation ledger;
then --sync updates owned display metadata, and --check verifies the join.
No export, Git mutation, release publication or final source-hash claim occurs.
"""
import argparse
import copy
import json
import os
from pathlib import Path
import re
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LEDGER = Path('docs/build-iterations.json')
SEED_COMMIT = '3a3c3538cf030dd8c80ba8ea5b355cb2fd4aa36b'
SEED_SET = 'ca18c62864ebee9c7d28fc9b8f6ec898be486f815179aa00faa11d9c61e1d7e0'
KEY = re.compile(r'[a-z][a-z0-9]*(?:-[a-z0-9]+)*\Z')


def validate(data):
    if not isinstance(data, dict) or set(data) != {'schema', 'seed', 'policy', 'allocations'}:
        raise ValueError('Unknown ledger shape')
    seed = data['seed']
    if (data['schema'] != 'null-choir-build-iterations-v1' or not isinstance(seed, dict)
            or seed.get('source_commit') != SEED_COMMIT
            or seed.get('projection_identity_set_sha256') != SEED_SET
            or any(type(seed.get(k)) is not int or seed[k] != v for k, v in {
                'ordinal': 93, 'reachable_commits': 289, 'empty_states': 1,
                'distinct_production_states': 93, 'first_parent_states': 59,
                'additional_branch_states': 34, 'missing_trees': 0}.items())
            or not all(isinstance(seed.get(k), str) and seed[k] for k in ('projection', 'scope'))
            or not isinstance(data['policy'], str) or not data['policy']):
        raise ValueError('Immutable audited seed or policy missing')
    if not isinstance(data['allocations'], list) or not data['allocations']:
        raise ValueError('Retain every issued ordinal, including initial94')
    seen = set()
    for ordinal, row in enumerate(data['allocations'], 94):
        if (not isinstance(row, dict) or set(row) != {'ordinal', 'candidate', 'status'}
                or type(row['ordinal']) is not int or row['ordinal'] != ordinal
                or not isinstance(row['candidate'], str) or not KEY.fullmatch(row['candidate'])
                or row['candidate'] in seen or row['status'] not in ('reserved', 'failed')):
            raise ValueError('Invalid, duplicate or reused allocation')
        seen.add(row['candidate'])
    if data['allocations'][0]['candidate'] != 'seal-wardens-and-dimensional-walls':
        raise ValueError('Initial94 candidate identity changed')
    return data['allocations'][-1]['ordinal']


def identity(ordinal):
    if type(ordinal) is not int or ordinal < 94:
        raise ValueError('Expected issued integer ordinal >=94')
    version = f'0.{ordinal:03d}'
    name = f'Null Choir v{version}'
    return {'ordinal': ordinal, 'version': version, 'display_name': name,
            'app_name': name + '.app', 'archive_name': f'Null-Choir-v{version}.zip',
            'cfbundle_version': str(ordinal)}


def reserve(data, candidate, expected):
    last = validate(data)
    if type(expected) is not int or expected != last:
        raise ValueError('Stale expected ordinal; reread before allocating')
    if not isinstance(candidate, str) or not KEY.fullmatch(candidate):
        raise ValueError('Expected a stable lowercase candidate key')
    prior = next((r for r in data['allocations'] if r['candidate'] == candidate), None)
    if prior:
        if prior != data['allocations'][-1] or prior['status'] != 'reserved':
            raise ValueError('Retired/earlier candidate cannot reuse an issued ordinal')
        return copy.deepcopy(data)  # Source-identical packaging retry, not a new iteration.
    result = copy.deepcopy(data)
    result['allocations'].append({'ordinal': last + 1, 'candidate': candidate, 'status': 'reserved'})
    validate(result)
    return result


def replace_field(text, name, value):
    pattern = r'(?m)^' + re.escape(name) + r'=.*$'
    result, count = re.subn(pattern, lambda _: name + '=' + json.dumps(value), text)
    if count != 1:
        raise ValueError(f'Expected exactly one existing field: {name}')
    return result


def metadata(root, data):
    info = identity(validate(data))
    gd = root / 'game/scripts/build_info.gd'
    project = root / 'game/project.godot'
    preset = root / 'game/export_presets.cfg'
    project_text, preset_text = project.read_text(), preset.read_text()
    if ('config/name="NULL CHOIR"' not in project_text
            or 'application/bundle_identifier="com.ihearttokyo.nullchoir"' not in preset_text
            or 'config/use_custom_user_dir' in project_text or 'config/custom_user_dir_name' in project_text):
        raise ValueError('Internal project/user-data identity or bundle ID changed')
    gd_text = gd.read_text()
    for key, value in {'BUILD_ITERATION': info['ordinal'], 'VERSION': info['version'],
                       'DISPLAY_NAME': info['display_name'], 'ARCHIVE_NAME': info['archive_name']}.items():
        gd_text, count = re.subn(r'(?m)^const ' + key + r' = .*$',
                                lambda _, k=key, v=value: 'const ' + k + ' = ' + json.dumps(v), gd_text)
        if count != 1:
            raise ValueError(f'Expected exactly one BuildInfo constant: {key}')
    project_text = replace_field(project_text, 'config/version', info['version'])
    for key, value in {'application/name': info['display_name'], 'application/short_version': info['version'],
                       'application/version': info['cfbundle_version'],
                       'export_path': '../builds/macos/' + info['archive_name']}.items():
        preset_text = replace_field(preset_text, key, value)
    return {gd: gd_text, project: project_text, preset: preset_text}


def atomic_write(path, text):
    # Same-directory replacement, never truncate an existing ledger on interruption.
    fd, tmp = tempfile.mkstemp(prefix=path.name + '.', suffix='.tmp', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as out:
            out.write(text)
            out.flush()
            os.fsync(out.fileno())
        os.chmod(tmp, path.stat().st_mode & 0o777)
        os.replace(tmp, path)
    finally:
        Path(tmp).unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument('--check', action='store_true')
    action.add_argument('--reserve', metavar='CANDIDATE')
    action.add_argument('--sync', action='store_true')
    parser.add_argument('--expect-last', type=int)
    args = parser.parse_args()
    # Exclusive lock prevents concurrent writers from reserving the same number.
    # Failed sync leaves its already-issued number reserved; rerun --sync, never rewind.
    lock = ROOT / (str(LEDGER) + '.lock')
    fd = None
    try:
        if args.reserve is not None or args.sync:
            if args.expect_last is None:
                parser.error('Writes require --expect-last')
            fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        data = json.loads((ROOT / LEDGER).read_text())
        last = validate(data)
        if args.reserve is not None:
            updated = reserve(data, args.reserve, args.expect_last)
            atomic_write(ROOT / LEDGER, json.dumps(updated, indent=2) + '\n')
            data = updated
        else:
            if args.sync and args.expect_last != last:
                raise ValueError('Stale expected ordinal')
            for path, expected in metadata(ROOT, data).items():
                if args.sync:
                    if path.read_text() != expected:
                        atomic_write(path, expected)
                elif path.read_text() != expected:
                    raise ValueError(f'Display metadata out of sync: {path.relative_to(ROOT)}')
        print(json.dumps(identity(validate(data)), sort_keys=True))
    finally:
        if fd is not None:
            os.close(fd)
            lock.unlink()


if __name__ == '__main__':
    main()
