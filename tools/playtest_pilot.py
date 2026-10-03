"""Serial external pilot coordinator, not a CLI, renderer or native launcher.

Activation remains behind the existing disabled transport gate. Native IO and
foreground safety have separate unresolved gates. Never reopen/replay a run.
"""
import time

from . import playtest_bridge as wire
from . import playtest_protocol as p
from . import playtest_supervisor as supervisor
from .playtest_mailbox import Mailbox
from .playtest_recorder import FrameRecorder
from .playtest_capture import CaptureInbox


class PilotError(Exception):
    """Sanitized terminal outcome; preserve possible completed remote effects."""


class Pilot:
    """Single-writer run, like Journal; reject callback reentrancy, not a thread API."""
    def __init__(self, controller, journal, *, clock=time.monotonic, sleep=time.sleep,
                 capture_byte_bound=None):
        if (controller.started_at != journal.started_at or controller.attempts
                or controller.pending is not None or controller.active_ticket is not None or controller.stopped):
            raise PilotError('A fresh, same-clock owned run is required.')
        self.controller, self.journal = controller, journal
        self.clock, self.sleep = clock, sleep  # Trusted local functions, never provider output.
        self.mailbox = Mailbox(journal)
        self.last_state = None
        self.stopped = False
        self._running = False
        self.capture = None if capture_byte_bound is None else CaptureInbox(
            FrameRecorder(journal, byte_bound=capture_byte_bound), self.mailbox)

    def _drain_capture(self):
        if self.capture is not None and not self.capture.stopped:
            self.capture.poll(self.clock())
        if self.last_state is not None:
            self.last_state = self._newest_state(self.last_state)

    def _newest_state(self, state):
        captured = self.capture.last_state if self.capture is not None else None
        if captured is None or captured['frame'] < state['frame']:
            return state
        if captured['frame'] == state['frame']:
            if captured != state:
                raise ValueError('Same-frame capture/RPC disagreement')
            return state
        if (p.identity(captured)[:4] != p.identity(state)[:4]
                or captured['action_sequence'] < state['action_sequence']):
            raise ValueError('Capture/RPC identity or sequence drift')
        return captured

    def _request(self, kind, payload=b'', *, deadline=None):
        self._drain_capture()
        now = self.clock()
        if deadline is not None and now >= deadline:
            raise ValueError('Pilot request deadline')
        self.mailbox.send(kind, payload, now)
        limit = self.mailbox.pending[2]
        if deadline is not None:
            limit = min(limit, deadline)
        while True:
            now = self.clock()
            if now >= limit:
                raise ValueError('Pilot response deadline')
            result = self.mailbox.receive(now)
            self._drain_capture()  # Commit older draw metadata before a newer state.
            now = self.clock()  # Files/PNG validation may consume the lease.
            if now >= limit:
                raise ValueError('Pilot response deadline')
            if result is not None:
                if result['ok'] is not True:
                    raise ValueError('Native peer rejected request')
                issued = wire.decode_observation(result['payload'])
                state = self._newest_state(issued)
                if not self.journal.closed:
                    self.journal.record('state', state, now)
                elif kind != 'snapshot':
                    raise ValueError('Capture budget ended before acknowledgment')
                self.last_state = state
                # Observe's frame belongs to the native command envelope even
                # if a newer post-draw snapshot is available for lifecycle checks.
                return issued if kind == 'observe' else state
            if self.journal.closed:
                raise ValueError('Capture ended without native response')
            self.sleep(min(0.01, limit-now))

    def _acknowledge(self, ticket):
        # The native observation can age before Controller.begin. Its sequence
        # may advance early; never feed that ACK to Controller.tick prematurely.
        deadline = min(ticket.expires_at + p.LEASE_SECONDS,
                       self.journal.started_at + p.MAX_SECONDS)
        while True:
            self._drain_capture()
            if self.journal.closed and self.capture is not None:
                # The last successful frame can exhaust the capture grant before
                # the controller's conservative local lease ends. No more RPCs.
                self.last_state = self.capture.last_state
            state, now = self.last_state, self.clock()
            if now >= deadline:
                raise ValueError('Missing native acknowledgment')
            key = p.identity(state)
            clean = p.telemetry(state)
            if (key[:4] != ticket.identity[:4] or clean['phase'] != 'alive' or clean['health'] <= 0
                    or key[4] not in (ticket.identity[4], ticket.identity[4]+1)):
                raise ValueError('Stale acknowledgment')
            if now >= ticket.expires_at:
                release = self.controller.tick(state, now)
                if self.controller.stopped:
                    raise ValueError('Controller stopped')
                if release['release'] and not self.journal.closed:
                    self.journal.record('release', state, now)
                if key[4] == ticket.identity[4]+1:
                    return key[4]
            self.sleep(min(0.02, deadline-now))
            if not self.journal.closed:
                self._request('snapshot', deadline=deadline)

    def _frame_barrier(self, ticket, sequence, issued_frame):
        if self.capture is None:
            return
        deadline = min(self.clock()+1.0, self.journal.started_at+p.MAX_SECONDS)
        while True:
            self._drain_capture()
            now = self.clock()
            if now >= deadline:
                raise ValueError('Missing completed frame')
            state = self.capture.last_state
            if state is not None:
                key, clean = p.identity(state), p.telemetry(state)
                if (key[:4] != ticket.identity[:4] or clean['phase'] != 'alive'
                        or clean['health'] <= 0 or key[4] > sequence):
                    raise ValueError('Stale completed frame')
                if key[4] == sequence and state['frame'] > issued_frame:
                    if self.capture.stopped:
                        self.stop()  # Retain the successful final action/frame.
                    return
            if self.capture.stopped:
                raise ValueError('Missing completed frame')
            self.sleep(min(0.01,deadline-now))

    def run_one(self, *, credential):
        if self.stopped or self._running:
            raise PilotError('Pilot stopped or one decision in flight; no retry.')
        self._running = True
        try:
            # Check before IPC or reservation, then supervisor rechecks before HTTP.
            supervisor.transport._validate_activation(self.controller, credential)
            self.controller._clock(self.clock())
            if (self.controller.stopped or self.controller.pending is not None
                    or self.controller.active_ticket is not None or self.controller.attempts >= p.MAX_ATTEMPTS):
                raise ValueError('Pilot stopped, occupied or attempt cap')
            issued = self._request('observe')
            if issued['phase'] != 'alive' or issued['health'] <= 0:
                raise ValueError('Alive observation required')
            result = supervisor.decide(self.controller, issued, credential=credential,
                                       observe=lambda: self._request('snapshot', deadline=self.controller.pending.expires_at),
                                       clock=self.clock)
            ticket = self.controller.active_ticket
            now = self.clock()
            # A fresh snapshot verifies the scene, but must not replace the native
            # issued observation frame in the command's exact identity envelope.
            command = wire.encode_command(ticket, result['plan'], issued, now)
            row = self.journal._row('command_attempt', self.last_state, now)
            row.update(action=result['plan']['action'], model=result['model'], usage=result['usage'],
                       issued_frame=issued['frame'], expires_monotonic=ticket.expires_at,
                       duration_seconds=min(result['plan']['duration_seconds'], ticket.expires_at-now))
            self.journal._append(row)  # An attempted commit, not rendered input proof.
            self._request('command', command, deadline=ticket.expires_at)
            sequence = self._acknowledge(ticket)
            self._frame_barrier(ticket,sequence,issued['frame'])
            return {'action': result['plan']['action'], 'model': result['model'],
                    'usage': result['usage'], 'acknowledged_sequence': sequence}
        except Exception:
            self.stop()
            raise PilotError('Pilot stopped; preserve evidence and reservations, no retry.') from None
        except BaseException:
            self.stop()
            raise
        finally:
            self._running = False

    def stop(self):
        if self.stopped:
            return
        self.stopped = True
        self.controller.stop()
        try:
            # Best effort only, without waiting/retrying an ambiguous command.
            # The native bridge must independently expire and release its lease.
            if self.mailbox.sequence and not self.mailbox.stopped:
                self.mailbox.send('stop', b'', self.clock())
            if self.last_state is not None and not self.journal.closed:
                self.journal.record('stop', self.last_state, self.clock())
        except Exception:
            pass  # Retain partial files; no secret/path/error or blind retry.
        finally:
            self.journal.close()
