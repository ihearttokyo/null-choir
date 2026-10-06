"""Offline wire and receiver contract, not a native bridge or input injector.

No listener, HTTP, engine launch or CLI activation. A future Godot bridge must
enforce the same lease inside its ALWAYS-processing owned node. Python fixtures
cannot certify paused native processing or real input release.
"""
from datetime import datetime, timezone
import json
import math
import re

from . import playtest_protocol as p
from .playtest_transport import _unique_object

MAX_WIRE_BYTES = 16384
HEADER = {'version', 'kind', 'run_id', 'build_sha256', 'level_id', 'player_id',
          'action_sequence', 'frame', 'monotonic', 'utc', 'clock_domain'}
OBSERVABLE = {'phase', 'health', 'armor', 'ammo', 'weapon', 'pose', 'yaw',
              'sensitivity', 'objective', 'contacts', 'obstacles'}


def _encode(packet):
    data = json.dumps(packet, separators=(',', ':'), allow_nan=False).encode('utf-8')
    if len(data) > MAX_WIRE_BYTES:
        raise ValueError('wire byte cap')
    return data


def _decode(data, kind):
    if type(data) is not bytes or not 0 < len(data) <= MAX_WIRE_BYTES:
        raise ValueError('bounded wire bytes required')
    try:
        packet = json.loads(data.decode('utf-8'), object_pairs_hook=_unique_object)
        p.bounded_document(packet)
        fields = OBSERVABLE if kind == 'observation' else {'action', 'duration_seconds'}
        if type(packet) is not dict or set(packet) != HEADER | fields:
            raise ValueError('exact wire schema required')
        if type(packet['version']) is not int or packet['version'] != 1 or packet['kind'] != kind:
            raise ValueError('wire version/kind')
        if packet['clock_domain'] != ('bridge' if kind == 'observation' else 'controller'):
            raise ValueError('clock domain')
        stamp = datetime.fromisoformat(packet['utc'])
        if stamp.tzinfo is None or stamp.utcoffset().total_seconds() != 0:
            raise ValueError('UTC timestamp required')
        p.number(packet['monotonic'], 0, 1e12)  # Metadata only; never compare epochs.
        for name in ('level_id', 'player_id'):
            value = packet[name]
            if type(value) is not str or not re.fullmatch(r'0|[1-9][0-9]{0,18}', value):
                raise ValueError('canonical decimal scene identity required')
            packet[name] = p.number(int(value), 0, 2**63-1, True)
        p.identity(packet)
        p.number(packet['frame'], 0, 2**53-1, True)
        return packet
    except (ValueError, TypeError, OverflowError, RecursionError):
        raise ValueError('Invalid private playtest wire.') from None


def _header(state, kind, now):
    key = p.identity(state)
    return {'version': 1, 'kind': kind, 'run_id': key[0], 'build_sha256': key[1],
            'level_id': str(key[2]), 'player_id': str(key[3]), 'action_sequence': key[4],
            'frame': p.number(state['frame'], 0, 2**53-1, True),
            'monotonic': p.number(now, 0, 1e12), 'utc': datetime.now(timezone.utc).isoformat(),
            'clock_domain': 'bridge' if kind == 'observation' else 'controller'}


def encode_observation(state, now):
    clean = p.telemetry(state)
    clean['sensitivity'] = state['sensitivity']
    for name in ('contacts', 'obstacles'):
        clean[name] = [{**item, 'visible': True} for item in clean[name]]
    return _encode({**clean, **_header(state, 'observation', now)})


def decode_observation(data):
    packet = _decode(data, 'observation')
    state = {key: packet[key] for key in OBSERVABLE | {'run_id', 'build_sha256',
             'level_id', 'player_id', 'action_sequence', 'frame'}}
    p.telemetry(state)
    return state


def encode_command(ticket, plan, state, now):
    clean = p.telemetry(state)
    if clean['phase'] != 'alive' or clean['health'] <= 0:
        raise ValueError('alive command source required')
    if type(plan) is not dict or plan.get('action') not in p.ACTIONS or p.identity(state) != ticket.identity:
        raise ValueError('bound action plan required')
    duration = p.number(plan.get('duration_seconds'), 0.000001, p.LEASE_SECONDS)
    p.number(now, 0, 1e12)
    if now >= ticket.expires_at:
        raise ValueError('expired controller ticket')
    return _encode({**_header(state, 'command', now), 'action': plan['action'],
                    'duration_seconds': min(duration, ticket.expires_at - now)})


class InputLease:
    """Independent receiver-local clock/sequence; emits plans, never native events."""
    def __init__(self, run_id, build_sha256, started_at):
        p.identity({'run_id': run_id, 'build_sha256': build_sha256,
                    'level_id': 0, 'player_id': 0, 'action_sequence': 0})
        self.run_build = (run_id, build_sha256)
        self.started_at = self.last_time = p.number(started_at, 0, 1e12)
        self.next_sequence = 0
        self.observed = None
        self.observed_frame = -1
        self.last_frame = -1
        self.deadline = None
        self.active = False
        self.stopped = False
        self.release_plan = {'release': [], 'reason': None, 'action_sequence': 0}

    def _clock(self, now):
        p.number(now, self.last_time, 1e12)
        self.last_time = now
        if self.stopped or now - self.started_at >= p.MAX_SECONDS:
            raise ValueError('receiver stopped or pilot cap')

    def _release(self, reason, stop=True):
        if self.active and not stop:
            self.next_sequence += 1
        self.observed = self.deadline = None
        self.active = False
        self.stopped = self.stopped or stop
        self.release_plan = {'release': list(p.HELD_INPUTS), 'reason': reason,
                             'action_sequence': self.next_sequence}
        return self.release_plan

    def stop(self):
        return self._release('stop')

    def _current(self, state):
        clean = p.telemetry(state)
        key = p.identity(state)
        if clean['phase'] != 'alive' or clean['health'] <= 0 or key[:2] != self.run_build:
            raise ValueError('receiver lifecycle changed')
        if self.observed and (key != self.observed or state['frame'] < self.observed_frame):
            raise ValueError('stale receiver scene/sequence/frame')
        if state['frame'] < self.last_frame:
            raise ValueError('receiver frame regression')
        self.last_frame = state['frame']
        return key

    def observe(self, state, now):
        try:
            self._clock(now)
            key = self._current(state)
            if self.observed or key[4] != self.next_sequence or self.next_sequence >= p.MAX_ATTEMPTS:
                raise ValueError('one observation/action in flight or cap')
            self.observed, self.observed_frame = key, state['frame']
            self.deadline = min(now + p.LEASE_SECONDS, self.started_at + p.MAX_SECONDS)
            return encode_observation(state, now)
        except Exception:
            self._release('failure')
            raise ValueError('Receiver observation stopped; release inputs.') from None
        except BaseException:
            self._release('failure')
            raise

    def apply(self, data, state, now):
        try:
            self._clock(now)
            self._current(state)
            command = _decode(data, 'command')
            if self.observed is None or self.active or p.identity(command) != self.observed or command['frame'] != self.observed_frame or now >= self.deadline:
                raise ValueError('stale, duplicate or late command')
            action = command['action']
            if action not in p.ACTIONS:
                raise ValueError('unknown bounded action')
            duration = p.number(command['duration_seconds'], 0.000001, p.LEASE_SECONDS)
            self.deadline = min(self.deadline, now + duration)
            self.active = True
            yaw = 15 if action == 'turn_left' else -15 if action == 'turn_right' else 0
            return {'action': action, 'press': [action] if action in p.HELD_INPUTS else [],
                    'duration_seconds': self.deadline - now, 'yaw_degrees': yaw,
                    'screen_relative_x': -math.radians(yaw)/(state['sensitivity'] * 0.002),
                    'release': list(p.HELD_INPUTS)}
        except Exception:
            self._release('failure')
            raise ValueError('Receiver command stopped; release inputs.') from None
        except BaseException:
            self._release('failure')
            raise

    def tick(self, state, now):
        try:
            self._clock(now)
            self._current(state)
            if self.observed and now >= self.deadline:
                return self._release('lease' if self.active else 'heartbeat', not self.active)
            return {'release': [], 'reason': None, 'action_sequence': self.next_sequence}
        except Exception:
            return self._release('failure')
        except BaseException:
            self._release('failure')
            raise
