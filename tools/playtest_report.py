"""Bounded read-only summaries of resident Journal records and referenced PNGs.

This verifies local integrity, not pixels, native input, campaign coverage or bills.
Clean Journal telemetry has no sensitivity or visibility-provenance fields.
"""
from contextlib import contextmanager, ExitStack
from datetime import datetime, timedelta
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import struct

from . import playtest_capture as capture
from . import playtest_protocol as p
from .playtest_mailbox import Mailbox
from .playtest_transport import _unique_object

MAX_ROWS = 4096
MAX_ROW_BYTES = 20 * 1024
MAX_INDEX_BYTES = MAX_ROWS * MAX_ROW_BYTES
_BASE = {'kind', 'run_id', 'build_sha256', 'sequence', 'monotonic', 'utc'}
_SAMPLE = _BASE | {'level_id', 'player_id', 'action_sequence', 'frame', 'state'}
_STATE = {'phase', 'health', 'armor', 'ammo', 'weapon', 'pose', 'yaw',
          'objective', 'contacts', 'obstacles'}


class ReportError(ValueError):
    """Invalid, unsafe, changing or out-of-bounds local evidence."""


def _resident(info):
    if getattr(info, 'st_flags', 0) & getattr(stat, 'SF_DATALESS', 0x40000000):
        raise ValueError('Resident evidence required')


def _stamp(info):
    return (info.st_dev, info.st_ino, info.st_mode, info.st_uid, info.st_nlink,
            info.st_size, info.st_mtime_ns, info.st_ctime_ns,
            getattr(info, 'st_flags', 0))


@contextmanager
def _directory(root):
    path = Path(root).absolute()  # Do not resolve away symlinks.
    if '..' in path.parts:
        raise ValueError('Traversal forbidden')
    with ExitStack() as stack:
        fd = os.open(path.anchor, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_NONBLOCK)
        stack.callback(os.close, fd)
        _resident(os.fstat(fd))
        links = []
        for name in path.parts[1:]:
            before = os.stat(name, dir_fd=fd, follow_symlinks=False)
            _resident(before)
            if not stat.S_ISDIR(before.st_mode):
                raise ValueError('Directory required')
            child = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_NONBLOCK,
                            dir_fd=fd)
            stack.callback(os.close, child)
            info = os.fstat(child)
            _resident(info)
            if _stamp(info) != _stamp(before):
                raise ValueError('Directory changed')
            links.append((fd, name, (info.st_dev, info.st_ino)))
            fd = child
        info = os.fstat(fd)
        _resident(info)
        if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
            raise ValueError('Private owned directory required')
        initial = _stamp(info)
        yield fd
        if _stamp(os.fstat(fd)) != initial:
            raise ValueError('Run directory changed')
        for parent, name, identity in links:
            current = os.stat(name, dir_fd=parent, follow_symlinks=False)
            _resident(current)
            if (not stat.S_ISDIR(current.st_mode)
                    or (current.st_dev, current.st_ino) != identity):
                raise ValueError('Directory path changed')


@contextmanager
def _file(directory, name, limit, verified):
    before = os.stat(name, dir_fd=directory, follow_symlinks=False)
    _resident(before)
    Mailbox._private(before)
    if not 0 < before.st_size <= limit:
        raise ValueError('File byte cap')
    fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
    try:
        info = os.fstat(fd)
        _resident(info)
        Mailbox._private(info)
        if _stamp(info) != _stamp(before):
            raise ValueError('File changed before read')
        yield fd, info.st_size
        current = os.stat(name, dir_fd=directory, follow_symlinks=False)
        if _stamp(os.fstat(fd)) != _stamp(info) or _stamp(current) != _stamp(info):
            raise ValueError('File changed during read')
        verified[name] = _stamp(info)
    finally:
        os.close(fd)


def _lines(fd):
    pending = bytearray()
    total = 0
    while True:
        chunk = os.read(fd, 4096)
        if not chunk:
            break
        total += len(chunk)
        if total > MAX_INDEX_BYTES:
            raise ValueError('Index byte cap')
        pending.extend(chunk)
        while (end := pending.find(b'\n')) >= 0:
            if end + 1 > MAX_ROW_BYTES:
                raise ValueError('Row byte cap')
            yield bytes(pending[:end])
            del pending[:end+1]
        if len(pending) >= MAX_ROW_BYTES:
            raise ValueError('Row byte cap')
    if pending:
        raise ValueError('Incomplete index row')


def _state(value, row):
    """Validate the writer's clean schema without fabricating raw provenance."""
    if type(value) is not dict or set(value) != _STATE:
        raise ValueError('Exact clean state required')
    phase = value['phase']
    if phase not in ('alive', 'title', 'loading', 'menu', 'dead', 'stopped'):
        raise ValueError('Invalid phase')
    if phase == 'alive' and (row['level_id'] == 0 or row['player_id'] == 0):
        raise ValueError('Alive identities required')
    for name in ('health', 'armor'):
        p.number(value[name], 0, 200, True)
    p.number(value['weapon'], 0, 5, True)
    if type(value['ammo']) is not list or len(value['ammo']) != 6:
        raise ValueError('Six ammunition counts required')
    for item in value['ammo']:
        p.number(item, 0, 9999, True)
    if type(value['pose']) is not list or len(value['pose']) != 3:
        raise ValueError('Three pose coordinates required')
    for item in value['pose']:
        p.number(item, -100000, 100000)
    p.number(value['yaw'], -180, 180)
    if type(value['objective']) is not str or value['objective'] not in p.OBJECTIVES:
        raise ValueError('Invalid objective')
    for name in ('contacts', 'obstacles'):
        entries = value[name]
        if type(entries) is not list or len(entries) > 32:
            raise ValueError('Bounded clean observations required')
        for item in entries:
            if type(item) is not dict or set(item) != {'kind', 'distance', 'bearing'}:
                raise ValueError('Exact clean contact required')
            if item['kind'] not in ('enemy', 'door', 'wall', 'pickup', 'exit', 'unknown'):
                raise ValueError('Invalid contact kind')
            p.number(item['distance'], 0, 200)
            p.number(item['bearing'], -180, 180)


def _row(data, sequence, run_id, build_sha256, last_time, started, last_frame, last_action):
    row = json.loads(data.decode('utf-8'), object_pairs_hook=_unique_object)
    p.bounded_document(row)
    if type(row) is not dict or type(row.get('kind')) is not str:
        raise ValueError('Journal row required')
    kind = row['kind']
    if kind == 'run' and sequence == 0:
        fields = _BASE | {'version'}
    elif sequence and kind in ('state', 'action', 'release', 'stop'):
        fields = _SAMPLE | ({'action'} if 'action' in row else set())
    elif sequence and kind == 'frame':
        fields = _SAMPLE | {'capture', 'sha256', 'size_bytes'}
    elif sequence and kind == 'command_attempt':
        fields = _SAMPLE | {'action', 'model', 'usage', 'issued_frame',
                            'expires_monotonic', 'duration_seconds'}
    else:
        raise ValueError('Invalid row kind/order')
    if set(row) != fields:
        raise ValueError('Exact journal schema required')
    if row['run_id'] != run_id or row['build_sha256'] != build_sha256:
        raise ValueError('Journal identity mismatch')
    p.number(row['sequence'], sequence, sequence, True)
    now = p.number(row['monotonic'], last_time, 1e12)
    if started is not None and now - started >= p.MAX_SECONDS:
        raise ValueError('Journal time cap')
    if type(row['utc']) is not str or len(row['utc']) > 64:
        raise ValueError('UTC stamp required')
    stamp = datetime.fromisoformat(row['utc'])
    if stamp.utcoffset() != timedelta(0):
        raise ValueError('UTC stamp required')
    if kind == 'run':
        p.number(row['version'], 1, 1, True)
        return row
    p.identity(row)
    p.number(row['frame'], last_frame, 2**53-1, True)
    p.number(row['action_sequence'], last_action, 2**53-1, True)
    _state(row['state'], row)
    if 'action' in row and (type(row['action']) is not str or row['action'] not in p.ACTIONS):
        raise ValueError('Allowlisted action required')
    if kind == 'command_attempt':
        if row['model'] != p.MODEL or row['state']['phase'] != 'alive' or row['state']['health'] <= 0:
            raise ValueError('Invalid command attempt')
        usage = row['usage']
        if type(usage) is not dict or set(usage) != {'input_tokens', 'output_tokens'}:
            raise ValueError('Exact token usage required')
        if sum(p.number(value, 0, p.CONTEXT_TOKENS, True) for value in usage.values()) > p.CONTEXT_TOKENS:
            raise ValueError('Context ceiling exceeded')
        p.number(row['issued_frame'], 0, row['frame'], True)
        expires = p.number(row['expires_monotonic'], now, started + p.MAX_SECONDS)
        duration = p.number(row['duration_seconds'], 0.000001, p.LEASE_SECONDS)
        if expires - now > p.LEASE_SECONDS + 1e-9 or duration > expires - now + 1e-9:
            raise ValueError('Command lease exceeded')
    return row


def _capture(directory, row, verified):
    name = row['capture']
    p.Journal._capture_path(name)
    if name in verified:
        raise ValueError('Duplicate capture')
    size = p.number(row['size_bytes'], 1, capture.MAX_CAPTURE_BYTES, True)
    if type(row['sha256']) is not str or not re.fullmatch(r'[0-9a-f]{64}', row['sha256']):
        raise ValueError('Capture digest required')
    with _file(directory, name, capture.MAX_CAPTURE_BYTES, verified) as (fd, actual):
        if size != actual:
            raise ValueError('Capture size mismatch')
        data = bytearray()
        while len(data) <= size:
            chunk = os.read(fd, min(65536, size + 1 - len(data)))
            if not chunk:
                break
            data.extend(chunk)
        if len(data) != size:
            raise ValueError('Capture byte mismatch')
        data = bytes(data)
        if hashlib.sha256(data).hexdigest() != row['sha256']:
            raise ValueError('Capture digest mismatch')
        if len(data) < 24:
            raise ValueError('PNG header required')
        width, height = struct.unpack_from('>II', data, 16)
        capture.validate_png(data, width, height)
    return {key: row[key] for key in ('capture', 'sha256', 'size_bytes', 'frame',
                                     'level_id', 'player_id', 'action_sequence')}


def report_run(root, *, run_id, build_sha256):
    """Return sample-only aggregates; no writes, provider access or corpus loading.

    Index and referenced captures must remain stable throughout verification.
    Unreferenced IPC bodies are not read, counted or certified by this report.
    """
    try:
        p.identity({'run_id': run_id, 'build_sha256': build_sha256,
                    'level_id': 0, 'player_id': 0, 'action_sequence': 0})
        result = {'run_id': run_id, 'build_sha256': build_sha256,
                  'evidence': 'local journal and PNG integrity only',
                  'captures': [], 'capture_count': 0, 'command_attempts': {},
                  'usage_tokens': {'input_tokens': 0, 'output_tokens': 0},
                  'unique_pose_bins': 0, 'pose_bin_world_units': 1,
                  'sampled_pose_displacement_world_units': 0,
                  'sampled_absolute_yaw_change_degrees': 0,
                  'observed_ammo_decreases': [0]*6, 'observed_health_decreases': 0,
                  'journal_has_stop': False, 'missing_post_action_frames': [], 'diagnostics': []}
        verified, bins, pending = {}, set(), []
        previous = started = None
        last_time, last_frame, last_action, last_command = 0, -1, -1, -1
        count = attempts = 0
        with _directory(root) as directory:
            with _file(directory, 'index.jsonl', min(MAX_INDEX_BYTES, p.MAX_BYTES), verified) as (fd, index_size):
                total = index_size
                for data in _lines(fd):
                    if result['journal_has_stop']:
                        raise ValueError('Journal stop must be terminal')
                    if count >= MAX_ROWS:
                        raise ValueError('Row count cap')
                    row = _row(data, count, run_id, build_sha256, last_time, started, last_frame, last_action)
                    count += 1
                    last_time = row['monotonic']
                    if row['kind'] == 'run':
                        started = last_time
                        continue
                    state = row['state']
                    scene = (row['level_id'], row['player_id'])
                    bins.add((*scene, *(math.floor(coordinate) for coordinate in state['pose'])))
                    if previous is not None and previous[:2] == scene:
                        old = previous[2]
                        result['sampled_pose_displacement_world_units'] += math.dist(old['pose'], state['pose'])
                        result['sampled_absolute_yaw_change_degrees'] += abs((state['yaw']-old['yaw']+180)%360-180)
                        for i, ammo in enumerate(state['ammo']):
                            result['observed_ammo_decreases'][i] += max(0, old['ammo'][i]-ammo)
                        result['observed_health_decreases'] += max(0, old['health']-state['health'])
                    previous = (*scene, state)
                    last_frame, last_action = row['frame'], row['action_sequence']
                    if row['kind'] == 'command_attempt':
                        attempts += 1
                        if attempts > p.MAX_ATTEMPTS or last_action <= last_command:
                            raise ValueError('Command attempt count/sequence')
                        last_command = last_action
                        action = row['action']
                        result['command_attempts'][action] = result['command_attempts'].get(action, 0)+1
                        for key in result['usage_tokens']:
                            result['usage_tokens'][key] += row['usage'][key]
                        pending.append({'level_id': scene[0], 'player_id': scene[1],
                                        'issued_sequence': last_action, 'expected_sequence': last_action+1,
                                        'action': action, 'issued_frame': row['issued_frame']})
                    elif row['kind'] == 'frame':
                        size = p.number(row['size_bytes'], 1, capture.MAX_CAPTURE_BYTES, True)
                        if len(result['captures']) >= p.MAX_CAPTURES or total + size > p.MAX_BYTES:
                            raise ValueError('Capture count/total byte cap')
                        result['captures'].append(_capture(directory, row, verified))
                        total += size
                        pending = [item for item in pending if not (
                            (item['level_id'], item['player_id']) == scene
                            and item['expected_sequence'] == last_action
                            and state['phase'] == 'alive' and state['health'] > 0
                            and row['frame'] > item['issued_frame'])]
                    elif row['kind'] == 'stop':
                        result['journal_has_stop'] = True
                if not count:
                    raise ValueError('Empty journal')
            for name, initial in verified.items():
                if _stamp(os.stat(name, dir_fd=directory, follow_symlinks=False)) != initial:
                    raise ValueError('Verified evidence changed')
        result['capture_count'] = len(result['captures'])
        result['unique_pose_bins'] = len(bins)
        result['row_count'] = count
        result['verified_bytes'] = total
        result['missing_post_action_frames'] = [
            {key: value for key, value in item.items() if key != 'issued_frame'} for item in pending]
        if not result['journal_has_stop']:
            result['diagnostics'].append('no_local_stop_record')
        if pending:
            result['diagnostics'].append('missing_post_action_frames')
        return result
    except (OSError, ValueError, TypeError, KeyError, OverflowError, RecursionError):
        raise ReportError('Local report rejected: unsafe, invalid, changing or bounded-out evidence.') from None
