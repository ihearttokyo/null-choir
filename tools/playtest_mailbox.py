"""Private serial file IPC; no listener, native activation, provider or CLI.

Borrow the exclusive Journal directory. A timed-out or ambiguous publication
stops this instance; never reopen it or retry a possibly executed action.
"""
import hashlib
import json
import os
import stat
import uuid

from . import playtest_bridge as wire
from . import playtest_protocol as p
from .playtest_transport import _unique_object

MAX_PAYLOAD_BYTES = wire.MAX_WIRE_BYTES
MAX_METADATA_BYTES = 2048
IPC_RESERVED_BYTES = 8 * MAX_PAYLOAD_BYTES
MAX_REQUESTS = 1024
KINDS = {'observe', 'snapshot', 'command', 'stop'}
MANIFEST_KEYS = {'version', 'run_id', 'build_sha256', 'nonce'}
REQUEST_KEYS = MANIFEST_KEYS | {'request_id', 'kind', 'payload_bytes', 'payload_sha256'}
SLOTS = ('manifest.json', 'request.json', 'request.bin', 'response.json', 'response.bin',
         'request.json.tmp', 'request.bin.tmp', 'response.json.tmp', 'response.bin.tmp')


class Mailbox:
    def __init__(self, journal):
        self.journal = journal
        self.sequence = 0
        self.pending = None
        self.stopped = False
        self.last_time = journal.started_at
        self.owned = {}
        try:
            self._root()
            if journal.max_bytes > p.MAX_BYTES - IPC_RESERVED_BYTES:
                raise ValueError('IPC disk reservation required')
            for name in SLOTS:
                try:
                    os.stat(name, dir_fd=journal.dir_fd, follow_symlinks=False)
                except FileNotFoundError:
                    continue
                raise ValueError('Refuse existing IPC files')
            self.manifest = {'version': 1, 'run_id': journal.run_id,
                             'build_sha256': journal.build_sha256, 'nonce': uuid.uuid4().hex}
            self._write_new('manifest.json', self._encoded(self.manifest))
        except (OSError, ValueError):
            self._fail()

    def _fail(self):
        self.stopped = True
        self.pending = None
        raise ValueError('Mailbox stopped; no retry.') from None

    def _root(self):
        if self.journal.closed:
            raise ValueError('Closed journal')
        info = os.fstat(self.journal.dir_fd)
        path = self.journal.root.lstat()
        if (not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid()
                or stat.S_IMODE(info.st_mode) != 0o700
                or (path.st_dev, path.st_ino) != (info.st_dev, info.st_ino)):
            raise ValueError('Private owned root required')

    def _clock(self, now):
        self._root()
        p.number(now, self.last_time, 1e12)
        self.last_time = now
        if now - self.journal.started_at >= p.MAX_SECONDS:
            raise ValueError('Mailbox pilot cap')

    @staticmethod
    def _private(info):
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid()
                or info.st_nlink != 1 or stat.S_IMODE(info.st_mode) != 0o600
                or getattr(info, 'st_flags', 0) & getattr(stat, 'SF_DATALESS', 0x40000000)):
            raise ValueError('Private resident regular file required')

    def _read(self, name, limit):
        # Preflight residency; NONBLOCK guards FIFOs, not cloud hydration.
        before = os.stat(name, dir_fd=self.journal.dir_fd, follow_symlinks=False)
        self._private(before)
        if before.st_size > limit:
            raise ValueError('Bounded IPC file required')
        fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                     dir_fd=self.journal.dir_fd)
        try:
            info = os.fstat(fd)
            self._private(info)
            if info.st_size > limit:
                raise ValueError('Bounded IPC file required')
            data = bytearray()
            while len(data) <= limit:
                chunk = os.read(fd, min(4096, limit + 1 - len(data)))
                if not chunk:
                    break
                data.extend(chunk)
            if len(data) > limit:
                raise ValueError('IPC byte cap')
            return bytes(data)
        finally:
            os.close(fd)

    def _write_new(self, name, data):
        fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                     0o600, dir_fd=self.journal.dir_fd)
        try:
            self._private(os.fstat(fd))
            view = memoryview(data)
            while view:
                count = os.write(fd, view)
                if count <= 0:
                    raise OSError('Incomplete IPC publication')
                view = view[count:]
            os.fsync(fd)
            info = os.fstat(fd)
            self.owned[name] = (info.st_dev, info.st_ino)
        finally:
            os.close(fd)

    def _publish(self, name, data):
        try:
            info = os.stat(name, dir_fd=self.journal.dir_fd, follow_symlinks=False)
        except FileNotFoundError:
            if name in self.owned:
                raise ValueError('Owned IPC file disappeared')
        else:
            self._private(info)
            if self.owned.get(name) != (info.st_dev, info.st_ino):
                raise ValueError('Refuse unknown replacement')
        temporary = name + '.tmp'
        self._write_new(temporary, data)
        os.replace(temporary, name, src_dir_fd=self.journal.dir_fd,
                   dst_dir_fd=self.journal.dir_fd)
        self.owned[name] = self.owned.pop(temporary)

    @staticmethod
    def _encoded(packet):
        data = json.dumps(packet, separators=(',', ':'), allow_nan=False).encode('utf-8')
        if len(data) > MAX_METADATA_BYTES:
            raise ValueError('IPC metadata cap')
        return data

    def send(self, kind, payload, now):
        if self.stopped:
            raise ValueError('Mailbox stopped; no retry.')
        if type(kind) is not str or kind not in KINDS or type(payload) is not bytes or len(payload) > MAX_PAYLOAD_BYTES:
            raise ValueError('Bounded allowlisted IPC request required')
        if kind == 'command':
            packet = wire._decode(payload, 'command')
            if packet['action'] not in p.ACTIONS or (packet['run_id'], packet['build_sha256']) != (self.journal.run_id, self.journal.build_sha256):
                raise ValueError('Bound command required')
            p.number(packet['duration_seconds'], 0.000001, p.LEASE_SECONDS)
        elif payload:
            raise ValueError('Only commands carry request bodies')
        if self.pending is not None and kind != 'stop':
            raise ValueError('One IPC request in flight')
        if kind != 'stop' and self.sequence >= MAX_REQUESTS - 1:
            raise ValueError('IPC request cap; one explicit stop slot remains')
        try:
            self._clock(now)
            if self.sequence >= MAX_REQUESTS:
                raise ValueError('IPC request cap')
            request = {**self.manifest, 'request_id': self.sequence + 1, 'kind': kind,
                       'payload_bytes': len(payload), 'payload_sha256': hashlib.sha256(payload).hexdigest()}
            self._publish('request.bin', payload)
            self._publish('request.json', self._encoded(request))  # Commit marker last.
            self.sequence += 1
            self.pending = (self.sequence, kind, min(now + p.LEASE_SECONDS, self.journal.started_at + p.MAX_SECONDS))
            self.stopped = kind == 'stop'
            return self.sequence
        except (OSError, ValueError):
            self._fail()
        except (KeyboardInterrupt, SystemExit):
            self.stopped, self.pending = True, None
            raise

    def receive(self, now):
        if self.pending is None:
            return None
        try:
            self._clock(now)
            request_id, kind, deadline = self.pending
            if now >= deadline:
                raise ValueError('IPC response deadline')
            try:
                data = self._read('response.json', MAX_METADATA_BYTES)
            except FileNotFoundError:
                return None
            packet = json.loads(data.decode('utf-8'), object_pairs_hook=_unique_object)
            p.bounded_document(packet)
            if type(packet) is not dict or set(packet) != REQUEST_KEYS | {'ok'}:
                raise ValueError('Exact IPC response required')
            p.number(packet['request_id'], 0, MAX_REQUESTS, True)
            if (any(packet[key] != value or type(packet[key]) is not type(value)
                    for key, value in self.manifest.items()) or type(packet['ok']) is not bool):
                raise ValueError('IPC identity mismatch')
            if packet['request_id'] < request_id:
                return None  # Never inspect/replay an older body.
            if packet['request_id'] != request_id or packet['kind'] != kind:
                raise ValueError('IPC counter/kind mismatch')
            size = p.number(packet['payload_bytes'], 0, MAX_PAYLOAD_BYTES, True)
            payload = self._read('response.bin', MAX_PAYLOAD_BYTES)
            if len(payload) != size or hashlib.sha256(payload).hexdigest() != packet['payload_sha256']:
                raise ValueError('IPC body/commit mismatch')
            self.pending = None
            return {'kind': kind, 'ok': packet['ok'], 'payload': payload}
        except (OSError, ValueError, TypeError, UnicodeError, RecursionError):
            self._fail()
        except (KeyboardInterrupt, SystemExit):
            self.stopped, self.pending = True, None
            raise
