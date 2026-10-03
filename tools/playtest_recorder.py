"""Local post-draw scheduling over the existing private journal; disabled on import.

A trusted native adapter must call this after RenderingServer.frame_post_draw.
Acknowledgment and PNG framing do not certify rendering: native execution is held.
The caller must apply input release on recorder failure; no desktop input is used.
"""
from .playtest_protocol import MAX_BYTES, number

PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


class FrameRecorder:
    """Two FPS plus phase/scene/action/objective/weapon/death events, hard preflight.

    produce_png(byte_bound) is trusted local encoding code, never model output.
    It must bound its allocation and return bytes from the acknowledged frame.
    This wrapper bounds persisted bytes; it cannot bound an arbitrary callback.
    """
    def __init__(self, journal, *, byte_bound):
        self.byte_bound = number(byte_bound, 1, MAX_BYTES, True)
        self.journal = journal
        self.last_frame = -1
        self.last_action_sequence = -1
        self.next_capture_at = journal.started_at
        self.last_signature = None
        self.stopped = False

    def close(self):
        self.stopped = True
        self.journal.close()

    def frame_drawn(self, state, now, produce_png, *, completed=False):
        if self.stopped:
            raise ValueError('Frame recording stopped.')
        if completed is not True:
            return None  # Never encode based on physics tick or a truthy substitute.
        try:
            # Reuse the journal's identity, privacy, monotonic and pilot checks.
            row = self.journal._row('frame', state, now)
            frame = row['frame']
            if frame < self.last_frame or row['action_sequence'] < self.last_action_sequence:
                raise ValueError('frame/action regression')
            self.last_action_sequence = row['action_sequence']
            if frame == self.last_frame:
                return None
            self.last_frame = frame
            clean = row['state']
            signature = (row['level_id'], row['player_id'], clean['phase'],
                         clean['objective'], clean['weapon'], clean['health'] <= 0,
                         row['action_sequence'])
            if now < self.next_capture_at and signature == self.last_signature:
                return None
            # Freeze metadata before encoding; a callback cannot relabel its frame.
            snapshot = {**clean, 'run_id': self.journal.run_id,
                        'build_sha256': self.journal.build_sha256,
                        'level_id': row['level_id'], 'player_id': row['player_id'],
                        'action_sequence': row['action_sequence'], 'frame': frame,
                        'sensitivity': state['sensitivity']}
            for name in ('contacts', 'obstacles'):
                snapshot[name] = [{**item, 'visible': True} for item in clean[name]]
            path = f'frame-{self.journal.captures:04d}.png'
            self.journal.check_capture(self.byte_bound, now, state=snapshot, relative_path=path)
            data = produce_png(self.byte_bound)
            if type(data) is not bytes or not len(PNG_SIGNATURE) < len(data) <= self.byte_bound or not data.startswith(PNG_SIGNATURE):
                raise ValueError('bounded PNG bytes required')
            self.journal.capture(path, data, snapshot, now)
            if now >= self.next_capture_at:
                self.next_capture_at = now + 0.5
            self.last_signature = signature
            return path
        except Exception:
            self.close()
            raise ValueError('Frame recording stopped; release inputs and preserve evidence.') from None
        except BaseException:
            self.close()
            raise
