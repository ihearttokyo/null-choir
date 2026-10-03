"""Offline Jev protocol preparation. No HTTP, game launch or input injection.

The controller emits plans, not Godot events. A future bridge must independently
enforce the 0.2s lease while paused and release inputs if its heartbeat disappears.
Budget reservations are estimates, never billing evidence or activation authority.
Journal.capture stores supplied bytes; it does not render or certify PNG frames.
"""
import hashlib
import json
import math
import os
from pathlib import Path
import re
from decimal import Decimal, InvalidOperation
from datetime import datetime, timezone
from typing import NamedTuple

MODEL = 'jev-1.13.0'
ACTIONS = ('move_forward', 'move_back', 'move_left', 'move_right',
           'turn_left', 'turn_right', 'fire', 'interact', 'wait')
OBJECTIVES = ('Find the visible exit', 'Explore visible surroundings',
              'Fight visible enemies', 'Interact with a visible door')
HELD_INPUTS = ('move_forward', 'move_back', 'move_left', 'move_right', 'fire', 'interact')
MAX_SECONDS, MAX_ATTEMPTS, MAX_CAPTURES, MAX_BYTES = 120, 240, 300, 250 * 1024 * 1024
CONTEXT_TOKENS = 64000
INPUT_PRICE = Decimal('0.042') / 1000000
ATTEMPT_RESERVATION = CONTEXT_TOKENS * INPUT_PRICE
LEASE_SECONDS = 0.2


def number(value, low, high, integer=False):
    if type(value) not in (int, float) or not low <= value <= high or (type(value) is float and not math.isfinite(value)):
        raise ValueError('invalid bounded number')
    if integer and type(value) is not int:
        raise ValueError('integer required')
    return value


def bounded_document(value):
    """Validate the whole raw boundary, including discarded nested fields."""
    count = 0

    def visit(item, depth):
        nonlocal count
        count += 1
        if depth > 6 or count > 512:
            raise ValueError('state structure too large')
        if item is None or type(item) is bool:
            return
        if type(item) in (int, float):
            number(item, -(2**63-1), 2**63-1)
        elif type(item) is str:
            if len(item.encode('utf-8')) > 2048:
                raise ValueError('state string too large')
        elif type(item) is list:
            if len(item) > 64:
                raise ValueError('state list too large')
            for child in item:
                visit(child, depth + 1)
        elif type(item) is dict:
            if len(item) > 64:
                raise ValueError('state dictionary too large')
            for key, child in item.items():
                if type(key) is not str or len(key) > 64:
                    raise ValueError('invalid state key')
                visit(child, depth + 1)
        else:
            raise ValueError('non-JSON state')

    visit(value, 0)
    if len(json.dumps(value, allow_nan=False).encode('utf-8')) > 16384:
        raise ValueError('state byte limit')


def identity(state):
    if type(state) is not dict:
        raise ValueError('observation must be a dictionary')
    run = state.get('run_id')
    build = state.get('build_sha256')
    if type(run) is not str or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', run):
        raise ValueError('invalid run identity')
    if type(build) is not str or not re.fullmatch(r'[0-9a-f]{64}', build):
        raise ValueError('invalid build identity')
    return (run, build, number(state.get('level_id'), 0, 2**63-1, True),
            number(state.get('player_id'), 0, 2**63-1, True),
            number(state.get('action_sequence'), 0, 2**53-1, True))


def telemetry(state):
    bounded_document(state)
    key = identity(state)
    number(state.get('frame'), 0, 2**53-1, True)
    phase = state.get('phase')
    if phase not in ('alive', 'title', 'loading', 'menu', 'dead', 'stopped'):
        raise ValueError('invalid gameplay phase')
    if phase == 'alive' and (key[2] == 0 or key[3] == 0):
        raise ValueError('alive scene identities required')
    clean = {'phase': phase}
    for name in ('health', 'armor'):
        clean[name] = number(state.get(name), 0, 200, True)
    ammo = state.get('ammo')
    if type(ammo) is not list or len(ammo) != 6:
        raise ValueError('six ammunition counts required')
    clean['ammo'] = [number(item, 0, 9999, True) for item in ammo]
    clean['weapon'] = number(state.get('weapon'), 0, 5, True)
    pose = state.get('pose')
    if type(pose) is not list or len(pose) != 3:
        raise ValueError('three pose coordinates required')
    clean['pose'] = [number(item, -100000, 100000) for item in pose]
    clean['yaw'] = number(state.get('yaw'), -180, 180)
    number(state.get('sensitivity'), 0.1, 4)
    objective = state.get('objective')
    # The bridge maps authored goals to this fixed vocabulary, never arbitrary prose.
    if type(objective) is not str or objective not in OBJECTIVES:
        raise ValueError('invalid observable objective')
    clean['objective'] = objective
    for name in ('contacts', 'obstacles'):
        entries = state.get(name, [])
        if type(entries) is not list or len(entries) > 32:
            raise ValueError('bounded visible observations required')
        clean[name] = []
        for entry in entries:
            if type(entry) is not dict or type(entry.get('visible')) is not bool:
                raise ValueError('visibility provenance required')
            if not entry['visible']:
                continue
            if entry.get('kind') not in ('enemy', 'door', 'wall', 'pickup', 'exit', 'unknown'):
                raise ValueError('invalid visible kind')
            clean[name].append({'kind': entry['kind'],
                                'distance': number(entry.get('distance'), 0, 200),
                                'bearing': number(entry.get('bearing'), -180, 180)})
    return clean


def build_request(state):
    """Pinned TypeSafe Choice shape; synthetic tests do not certify hosted behavior."""
    clean = telemetry(state)
    if clean['phase'] != 'alive' or clean['health'] <= 0:
        raise ValueError('alive gameplay required')
    return {'model': MODEL, 'state': json.dumps(clean, separators=(',', ':'), allow_nan=False),
            'questions': {'action': {'type': 'choice',
                          'instructions': 'Select one bounded local action using only visible player observations.',
                          'criteria': {name: name.replace('_', ' ') for name in ACTIONS}}}}


def reply_choice(reply):
    """Validate https://docs.typesafe.ai/api Choice answers for this request."""
    bounded_document(reply)
    if type(reply) is not dict or reply.get('model') != MODEL:
        raise ValueError('invalid reply model')
    answers = reply.get('answers')
    if type(answers) is not dict or set(answers) != {'action'} or type(answers['action']) is not dict:
        raise ValueError('one choice answer required')
    answer = answers['action']
    choice = answer.get('choice')
    if answer.get('type') != 'choice' or choice not in ACTIONS:
        raise ValueError('invalid action answer')
    number(answer.get('confidence'), 0, 1)
    probabilities = answer.get('probabilities')
    if type(probabilities) is not dict or set(probabilities) != set(ACTIONS):
        raise ValueError('invalid action probabilities')
    values = [number(item, 0, 1) for item in probabilities.values()]
    if not math.isclose(sum(values), 1, abs_tol=0.001):
        raise ValueError('probabilities must sum to one')
    usage = reply.get('usage')
    if type(usage) is not dict:
        raise ValueError('token usage required')
    tokens = sum(number(usage.get(key), 0, CONTEXT_TOKENS, True) for key in ('input_tokens', 'output_tokens'))
    if tokens > CONTEXT_TOKENS:
        raise ValueError('context ceiling exceeded')
    return choice


class Ticket(NamedTuple):
    identity: tuple
    expires_at: float
    attempt: int


class Controller:
    """Single serial pilot; fatal failures stop it without retrying or refunding reservations."""
    paid_activation_allowed = False  # This offline module cannot authorize paid activation.

    def __init__(self, started_at, *, setup_fee_usd=None, pricing_verified=False, account_active=False):
        self.started_at = self.last_time = number(started_at, 0, 1e12)
        try:
            fee = Decimal(str(setup_fee_usd)) if setup_fee_usd is not None else None
        except InvalidOperation:
            raise ValueError('invalid setup fee') from None
        if fee is not None and (not fee.is_finite() or not 0 <= fee <= 5):
            raise ValueError('invalid setup fee')
        self.budget_verified = fee is not None and pricing_verified is True and account_active is True
        self.reserved_usd = fee if fee is not None else Decimal(0)
        self.attempts = 0
        self.last_sequence = -1
        self.pending = None
        self.active_ticket = None
        self.held = ()
        self.stopped = False
        self.release_plan = {'release': [], 'reason': None}

    def _clock(self, now):
        number(now, self.last_time, 1e12)
        self.last_time = now
        if now - self.started_at >= MAX_SECONDS:
            raise ValueError('pilot time cap')

    def _release(self, reason, stop=False):
        self.release_plan = {'release': list(HELD_INPUTS), 'reason': reason}
        self.pending = self.active_ticket = None
        self.held = ()
        self.stopped = self.stopped or stop
        return self.release_plan

    def stop(self):
        return self._release('stop', True)

    def fail(self):
        return self._release('failure', True)

    def begin(self, state, now):
        if self.pending is not None or self.active_ticket is not None:
            self.tick(state, now)  # Observe cancellation even on a rejected second attempt.
            if self.pending is not None or self.active_ticket is not None or self.stopped:
                raise ValueError('one decision/action in flight or stopped')
        try:
            self._clock(now)
            if self.stopped or self.attempts >= MAX_ATTEMPTS:
                raise ValueError('pilot stopped or attempt cap')
            payload = build_request(state)
            key = identity(state)
            if key[-1] <= self.last_sequence:
                raise ValueError('action sequence must advance')
            if self.reserved_usd + ATTEMPT_RESERVATION > 5:
                raise ValueError('hard budget cap')
        except ValueError:
            self.fail()
            raise
        self.attempts += 1  # Failed remote attempts remain counted; never auto-retry.
        self.reserved_usd = (self.reserved_usd + ATTEMPT_RESERVATION).normalize()
        self.last_sequence = key[-1]
        self.pending = Ticket(key, min(now + LEASE_SECONDS, self.started_at + MAX_SECONDS), self.attempts)
        return self.pending, payload

    def accept(self, ticket, reply, state, now):
        try:
            self._clock(now)
            current = telemetry(state)
            if self.stopped or ticket != self.pending or self.pending is None:
                raise ValueError('stale or duplicate ticket')
            if identity(state) != ticket.identity or current['phase'] != 'alive' or current['health'] <= 0 or now >= ticket.expires_at:
                raise ValueError('stale identity, phase or action lease')
            choice = reply_choice(reply)
        except ValueError:
            self.fail()
            raise
        self.pending = None
        self.active_ticket = ticket
        self.held = (choice,) if choice in HELD_INPUTS else ()
        yaw = 15 if choice == 'turn_left' else -15 if choice == 'turn_right' else 0
        # Player.look subtracts screen_relative * sensitivity * 0.002.
        return {'action': choice, 'press': list(self.held), 'duration_seconds': min(LEASE_SECONDS, ticket.expires_at-now),
                'yaw_degrees': yaw, 'screen_relative_x': -math.radians(yaw)/(state['sensitivity']*0.002),
                'release': list(HELD_INPUTS)}

    def tick(self, state, now):
        try:
            self._clock(now)
            current = telemetry(state)
        except ValueError:
            return self.fail()
        ticket = self.pending or self.active_ticket
        key = identity(state)
        completed_ack = (self.active_ticket is not None and now >= ticket.expires_at
                         and key[:4] == ticket.identity[:4] and key[4] == ticket.identity[4] + 1)
        if current['phase'] != 'alive' or current['health'] <= 0 or (ticket and key != ticket.identity and not completed_ack):
            return self._release('stale', True)
        if ticket and now >= ticket.expires_at:
            return self._release('timeout' if self.pending else 'lease', self.pending is not None)
        return {'release': [], 'reason': None}


class Journal:
    """Exclusive private run directory; no reopen/replay and no raw-response interface.

    Single writer. Call check_capture with a conservative byte bound BEFORE a
    future frame producer runs; capture rechecks actual bytes before writing.
    """
    def __init__(self, root, run_id, build_sha256, started_at, *, max_captures=MAX_CAPTURES, max_bytes=MAX_BYTES):
        identity({'run_id': run_id, 'build_sha256': build_sha256, 'level_id': 1, 'player_id': 1, 'action_sequence': 0})
        self.started_at = self.last_time = number(started_at, 0, 1e12)
        self.max_captures = number(max_captures, 1, MAX_CAPTURES, True)
        self.max_bytes = number(max_bytes, 1024, MAX_BYTES, True)
        self.root = Path(root).absolute()
        if '..' in self.root.parts:
            raise ValueError('run path traversal')
        for path in (self.root, *self.root.parents):
            if path.is_symlink():
                raise ValueError('symlink run path')
        try:
            self.root.mkdir(mode=0o700)
        except FileExistsError:
            raise ValueError('refuse reopening any run') from None
        self.dir_fd = os.open(self.root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            self.index_fd = os.open('index.jsonl', os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_APPEND | os.O_NOFOLLOW, 0o600, dir_fd=self.dir_fd)
        except OSError:
            os.close(self.dir_fd)
            raise
        self.run_id, self.build_sha256 = run_id, build_sha256
        self.sequence = self.bytes = self.captures = 0
        self.last_frame = self.last_action_sequence = -1
        self.closed = False
        self._append({'kind': 'run', 'monotonic': started_at, 'version': 1})

    def close(self):
        if not self.closed:
            self.closed = True
            try:
                os.close(self.index_fd)
            finally:
                os.close(self.dir_fd)

    def _clock(self, now):
        if self.closed:
            raise ValueError('closed journal')
        number(now, self.last_time, 1e12)
        self.last_time = now
        if now - self.started_at >= MAX_SECONDS:
            raise ValueError('capture/index pilot time cap')

    def _row(self, kind, state, now):
        self._clock(now)
        clean = telemetry(state)
        key = identity(state)
        if key[:2] != (self.run_id, self.build_sha256) or state['frame'] < self.last_frame or key[4] < self.last_action_sequence:
            raise ValueError('journal identity/frame/action regression')
        return {'kind': kind, 'monotonic': now, 'level_id': key[2], 'player_id': key[3],
                'action_sequence': key[4], 'frame': state['frame'], 'state': clean}

    def _encoded(self, row):
        return (json.dumps({**row, 'run_id': self.run_id, 'build_sha256': self.build_sha256,
                           'sequence': self.sequence, 'utc': datetime.now(timezone.utc).isoformat(timespec='microseconds')},
                          separators=(',', ':'), allow_nan=False)+'\n').encode('utf-8')

    def _append(self, row):
        data = self._encoded(row)
        if self.bytes + len(data) > self.max_bytes:
            raise ValueError('journal byte cap')
        self.bytes += len(data)
        try:
            view = memoryview(data)
            while view:
                written = os.write(self.index_fd, view)
                if written <= 0:
                    raise OSError('incomplete index append')
                view = view[written:]
            os.fsync(self.index_fd)
        except OSError:
            self.close()
            raise
        self.sequence += 1
        if 'frame' in row:
            self.last_frame = row['frame']
            self.last_action_sequence = row['action_sequence']

    def record(self, kind, state, now, *, action=None):
        if kind not in ('state', 'action', 'release', 'stop') or (action is not None and action not in ACTIONS):
            raise ValueError('invalid journal event/action')
        row = self._row(kind, state, now)
        if action is not None:
            row['action'] = action
        self._append(row)

    def check_capture(self, byte_bound, now, *, state=None, relative_path='frame.png'):
        self._clock(now)
        number(byte_bound, 1, MAX_BYTES, True)
        metadata_bound = 17000  # Unknown observation: reserve the full boundary.
        if state is not None:
            self._capture_path(relative_path)
            row = self._row('frame', state, now)
            row.update(capture=relative_path, sha256='0'*64, size_bytes=byte_bound)
            metadata_bound = len(self._encoded(row))
        if self.captures >= self.max_captures or self.bytes + byte_bound + metadata_bound > self.max_bytes:
            raise ValueError('capture count/byte cap')

    @staticmethod
    def _capture_path(relative_path):
        if type(relative_path) is not str or len(relative_path) > 128 or not re.fullmatch(r'[A-Za-z0-9_-]+\.png', relative_path):
            raise ValueError('safe relative capture filename required')

    def capture(self, relative_path, data, state, now):
        self._capture_path(relative_path)
        if type(data) is not bytes or not data:
            raise ValueError('capture bytes required')
        row = self._row('frame', state, now)
        self.check_capture(len(data), now, state=state, relative_path=relative_path)
        row.update(capture=relative_path, sha256=hashlib.sha256(data).hexdigest(), size_bytes=len(data))
        try:
            fd = os.open(relative_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=self.dir_fd)
        except OSError:
            raise ValueError('capture exists or unsafe path') from None
        self.captures += 1
        self.bytes += len(data)
        try:
            with os.fdopen(fd, 'wb') as output:
                output.write(data)
                output.flush()
                os.fsync(output.fileno())
            self._append(row)
        except OSError:
            self.close()  # Fail closed; reserved bytes include any partial owned file.
            raise
