"""Real resident filesystem; simulated native peer, never Godot or network."""
import hashlib
import json
import os
import stat
from types import SimpleNamespace
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools import playtest_mailbox as m
from tools.playtest_protocol import Journal, MAX_BYTES
from tools import playtest_bridge as wire
from tools import playtest_protocol as protocol
from tests.test_playtest_protocol import observation, reply


def dataless_metadata(info):
    """Synthetic flag over resident fixture metadata; never a cloud file."""
    fields = {name: getattr(info, name) for name in
              ('st_mode', 'st_uid', 'st_nlink', 'st_size', 'st_dev', 'st_ino')}
    return SimpleNamespace(**fields, st_flags=getattr(info, 'st_flags', 0) | stat.SF_DATALESS)


class MailboxTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='null-choir-mailbox-')
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve() / 'run'
        self.journal = Journal(self.root, 'run-01', 'a' * 64, 0,
                               max_bytes=MAX_BYTES-m.IPC_RESERVED_BYTES)
        self.addCleanup(self.journal.close)
        self.box = m.Mailbox(self.journal)

    def peer(self, payload=b'fixture response', **changes):
        request = json.loads((self.root / 'request.json').read_text())
        response = {**request, 'ok': True, 'payload_bytes': len(payload),
                    'payload_sha256': hashlib.sha256(payload).hexdigest()}
        response.update(changes)
        (self.root / 'response.bin').write_bytes(payload)
        (self.root / 'response.bin').chmod(0o600)
        (self.root / 'response.json').write_text(json.dumps(response))
        (self.root / 'response.json').chmod(0o600)

    def test_private_serial_atomic_request_and_bound_response(self):
        self.box.send('observe', b'', 0)
        request = json.loads((self.root / 'request.json').read_text())
        self.assertEqual(request['request_id'], 1)
        self.assertEqual(request['kind'], 'observe')
        self.assertIsNone(self.box.receive(0.01))
        self.peer()
        result = self.box.receive(0.05)
        self.assertEqual(result, {'kind': 'observe', 'ok': True, 'payload': b'fixture response'})
        self.assertIsNone(self.box.pending)
        self.assertEqual(self.box.send('snapshot', b'', 0.06), 2)
        for path in self.root.iterdir():
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.root.stat().st_mode & 0o777, 0o700)
        self.assertNotIn('private', (self.root / 'manifest.json').read_text())

    def test_single_pending_and_explicit_stop_without_action_retry(self):
        self.box.send('observe', b'', 0)
        with self.assertRaises(ValueError):
            self.box.send('snapshot', b'', 0.01)
        self.assertEqual(self.box.sequence, 1)
        self.assertEqual(self.box.send('stop', b'', 0.02), 2)
        self.peer(request_id=1, kind='observe')
        self.assertIsNone(self.box.receive(0.03))
        self.peer()
        self.assertEqual(self.box.receive(0.04)['kind'], 'stop')
        with self.assertRaises(ValueError):
            self.box.send('observe', b'', 0.05)

    def test_stale_reply_ignored_and_future_or_mismatched_reply_stops(self):
        self.box.send('observe', b'', 0)
        self.peer(request_id=0)
        self.assertIsNone(self.box.receive(0.01))
        self.peer(request_id=2)
        with self.assertRaises(ValueError):
            self.box.receive(0.02)
        self.assertTrue(self.box.stopped)
        self.assertEqual(self.box.sequence, 1)

    def test_body_hash_size_and_metadata_unknown_fields_fail_closed(self):
        for index, changes in enumerate(({'payload_sha256': 'b'*64}, {'payload_bytes': 99999},
                                         {'nonce': '0'*32}, {'build_sha256': 'b'*64},
                                         {'ok': 1}, {'credential': 'private'})):
            with self.subTest(changes=changes):
                journal = Journal(self.root.parent / f'bad-{index}', 'run-01', 'a'*64, 0,
                                  max_bytes=MAX_BYTES-m.IPC_RESERVED_BYTES)
                self.addCleanup(journal.close)
                self.root = journal.root
                self.box = m.Mailbox(journal)
                self.box.send('observe', b'', 0)
                self.peer(**changes)
                with self.assertRaises(ValueError):
                    self.box.receive(0.1)
                self.assertTrue(self.box.stopped)

    def test_timeout_clock_and_pilot_cap_preserve_no_retry(self):
        self.box.send('observe', b'', 0)
        with self.assertRaises(ValueError):
            self.box.receive(0.2)
        self.assertTrue(self.box.stopped)
        self.assertEqual(self.box.sequence, 1)
        with self.assertRaises(ValueError):
            self.box.send('observe', b'', 0.21)

    def test_fatal_reply_cannot_be_accepted_after_repair(self):
        self.box.send('observe', b'', 0)
        self.peer(nonce='0'*32)
        with self.assertRaises(ValueError):
            self.box.receive(0.01)
        self.peer()
        self.assertIsNone(self.box.receive(0.02))
        self.assertIsNone(self.box.pending)

    def test_stale_foreign_identity_stops_instead_of_being_ignored(self):
        self.box.send('observe', b'', 0)
        self.peer(request_id=0, nonce='0'*32)
        with self.assertRaises(ValueError):
            self.box.receive(0.01)
        self.assertTrue(self.box.stopped)

    def test_interrupted_publication_is_terminal_and_closes_file(self):
        with patch.object(m.os, 'fsync', side_effect=KeyboardInterrupt):
            with self.assertRaises(KeyboardInterrupt):
                self.box.send('observe', b'', 0)
        self.assertTrue(self.box.stopped)
        self.assertIsNone(self.box.pending)
        self.assertFalse((self.root / 'request.json').exists())

    def test_permissions_symlink_and_disk_reservation(self):
        self.box.send('observe', b'', 0)
        self.peer()
        (self.root / 'response.bin').chmod(0o644)
        with self.assertRaises(ValueError):
            self.box.receive(0.05)
        journal = Journal(self.root.parent / 'unreserved', 'run-01', 'a'*64, 0)
        self.addCleanup(journal.close)
        with self.assertRaises(ValueError):
            m.Mailbox(journal)
        self.assertEqual(list(journal.root.iterdir()), [journal.root / 'index.jsonl'])
        journal = Journal(self.root.parent / 'symlink', 'run-01', 'a'*64, 0,
                          max_bytes=MAX_BYTES-m.IPC_RESERVED_BYTES)
        self.addCleanup(journal.close)
        target = journal.root.parent / 'keep'
        target.write_bytes(b'preserve unrelated bytes')
        (journal.root / 'manifest.json').symlink_to(target)
        with self.assertRaises(ValueError):
            m.Mailbox(journal)
        self.assertEqual(target.read_bytes(), b'preserve unrelated bytes')

    def test_failed_publication_stops_and_preserves_previous_committed_request(self):
        self.box.send('observe', b'', 0)
        before = (self.root / 'request.json').read_bytes()
        self.peer()
        self.box.receive(0.05)
        with patch.object(m.os, 'replace', side_effect=OSError('sensitive path')):
            with self.assertRaisesRegex(ValueError, '^Mailbox stopped'):
                self.box.send('snapshot', b'', 0.1)
        self.assertTrue(self.box.stopped)
        self.assertEqual((self.root / 'request.json').read_bytes(), before)
        with self.assertRaises(ValueError):
            self.box.send('snapshot', b'', 0.11)

    def test_invalid_payload_never_reaches_owned_request_file(self):
        for kind, data in (('exec(code)', b''), ('observe', b'private source'),
                           ('command', b'{}'), ('command', b'x'*(m.MAX_PAYLOAD_BYTES+1))):
            with self.assertRaises(ValueError):
                self.box.send(kind, data, 0)
        self.assertFalse((self.root / 'request.json').exists())
        self.assertEqual(self.box.sequence, 0)

    def test_wire_controller_round_trip_with_simulated_native_peer(self):
        self.box.send('observe', b'', 0)
        state = observation()
        self.peer(payload=wire.encode_observation(state, 9000))
        state = wire.decode_observation(self.box.receive(0.02)['payload'])
        controller = protocol.Controller(0)
        ticket, _ = controller.begin(state, 0.02)
        plan = controller.accept(ticket, reply('move_forward'), state, 0.04)
        command = wire.encode_command(ticket, plan, state, 0.04)
        self.box.send('command', command, 0.04)
        receiver = wire.InputLease('run-01', 'a'*64, 9000)
        receiver.observe(state, 9000)
        result = receiver.apply((self.root / 'request.bin').read_bytes(), state, 9000.04)
        self.assertEqual(result['press'], ['move_forward'])
        self.peer(payload=wire.encode_observation(state, 9000.04))
        self.assertTrue(self.box.receive(0.06)['ok'])
        self.box.send('stop', b'', 0.07)
        receiver.stop()
        self.peer(payload=wire.encode_observation({**state, 'phase': 'stopped'}, 9000.07))
        self.assertEqual(wire.decode_observation(self.box.receive(0.08)['payload'])['phase'], 'stopped')
        self.assertTrue(receiver.stopped)

    def test_clock_regression_and_pilot_cap_are_terminal(self):
        self.box.send('observe', b'', 0.1)
        with self.assertRaises(ValueError):
            self.box.receive(0.09)
        self.assertTrue(self.box.stopped)
        journal = Journal(self.root.parent / 'pilot-cap', 'run-01', 'a'*64, 0,
                          max_bytes=MAX_BYTES-m.IPC_RESERVED_BYTES)
        self.addCleanup(journal.close)
        box = m.Mailbox(journal)
        with self.assertRaises(ValueError):
            box.send('observe', b'', protocol.MAX_SECONDS)
        self.assertTrue(box.stopped)
        self.assertEqual(box.sequence, 0)

    def test_fifo_symlink_hardlink_and_oversized_response_are_rejected(self):
        for index, kind in enumerate(('fifo', 'symlink', 'hardlink', 'oversize', 'duplicate')):
            journal = Journal(self.root.parent / f'file-{index}', 'run-01', 'a'*64, 0,
                              max_bytes=MAX_BYTES-m.IPC_RESERVED_BYTES)
            self.addCleanup(journal.close)
            box = m.Mailbox(journal)
            box.send('observe', b'', 0)
            path = journal.root / 'response.json'
            if kind == 'fifo':
                os.mkfifo(path, 0o600)
            elif kind in ('symlink', 'hardlink'):
                target = journal.root.parent / f'keep-{index}'
                target.write_bytes(b'preserve')
                target.chmod(0o600)
                path.symlink_to(target) if kind == 'symlink' else os.link(target, path)
            else:
                path.write_bytes(b'x'*(m.MAX_METADATA_BYTES+1) if kind == 'oversize'
                                 else b'{"version":1,"version":1}')
                path.chmod(0o600)
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                box.receive(0.01)
            self.assertTrue(box.stopped)
            if kind in ('symlink', 'hardlink'):
                self.assertEqual(target.read_bytes(), b'preserve')

    def test_request_replacement_and_closed_journal_are_terminal(self):
        self.box.send('observe', b'', 0)
        self.peer()
        self.box.receive(0.01)
        replacement = self.root / 'replacement'
        replacement.write_bytes(b'preserve foreign replacement')
        replacement.chmod(0o600)
        replacement.replace(self.root / 'request.json')
        with self.assertRaises(ValueError):
            self.box.send('snapshot', b'', 0.02)
        self.assertEqual((self.root / 'request.json').read_bytes(), b'preserve foreign replacement')
        self.assertTrue(self.box.stopped)
        journal = Journal(self.root.parent / 'closed', 'run-01', 'a'*64, 0,
                          max_bytes=MAX_BYTES-m.IPC_RESERVED_BYTES)
        box = m.Mailbox(journal)
        journal.close()
        with self.assertRaises(ValueError):
            box.send('observe', b'', 0)
        self.assertTrue(box.stopped)

    def test_request_cap_keeps_one_explicit_stop_slot(self):
        self.box.sequence = m.MAX_REQUESTS-1  # Synthetic boundary, real publication.
        with self.assertRaises(ValueError):
            self.box.send('snapshot', b'', 0)
        self.assertFalse(self.box.stopped)
        self.assertEqual(self.box.send('stop', b'', 0.01), m.MAX_REQUESTS)
        self.peer()
        self.assertEqual(self.box.receive(0.02)['kind'], 'stop')

    def test_dataless_response_files_rejected_before_open_preserve_reservation(self):
        for index, name in enumerate(('response.json', 'response.bin')):
            journal = Journal(self.root.parent / f'resident-pre-{index}', 'run-01', 'a'*64, 0,
                              max_bytes=MAX_BYTES-m.IPC_RESERVED_BYTES)
            self.addCleanup(journal.close)
            self.root, self.box = journal.root, m.Mailbox(journal)
            controller = protocol.Controller(0)
            controller.begin(observation(), 0)
            reserved = controller.reserved_usd
            self.box.send('observe', b'', 0)
            self.peer()
            before = journal.bytes
            real_stat = m.os.stat
            def flagged(path, *args, **kwargs):
                info = real_stat(path, *args, **kwargs)
                return dataless_metadata(info) if path == name else info
            with self.subTest(name=name), patch.object(m.os, 'stat', side_effect=flagged), \
                 patch.object(m.os, 'open', wraps=m.os.open) as opened:
                with self.assertRaises(ValueError): self.box.receive(0.01)
                self.assertFalse(any(call.args[0] == name for call in opened.call_args_list))
            self.assertTrue(self.box.stopped)
            self.assertIsNone(self.box.pending)
            self.assertEqual(self.box.sequence, 1)
            self.assertEqual(journal.bytes, before)
            self.assertEqual(controller.reserved_usd, reserved)

    def test_response_becomes_dataless_after_open_before_content_read(self):
        for index, name in enumerate(('response.json', 'response.bin')):
            journal = Journal(self.root.parent / f'resident-post-{index}', 'run-01', 'a'*64, 0,
                              max_bytes=MAX_BYTES-m.IPC_RESERVED_BYTES)
            self.addCleanup(journal.close)
            self.root, self.box = journal.root, m.Mailbox(journal)
            self.box.send('observe', b'', 0)
            self.peer()
            inode = (self.root/name).stat().st_ino
            real_fstat, real_open, real_read = m.os.fstat, m.os.open, m.os.read
            flagged_fds, flagged_reads = [], []
            def opened(path, *args, **kwargs):
                fd = real_open(path, *args, **kwargs)
                if path == name: flagged_fds.append(fd)
                return fd
            def flagged(fd):
                info = real_fstat(fd)
                return dataless_metadata(info) if info.st_ino == inode else info
            def read(fd, size):
                # Descriptor numbers may be reused after the metadata file closes.
                if fd in flagged_fds: flagged_reads.append(fd)
                return real_read(fd, size)
            with self.subTest(name=name), patch.object(m.os, 'open', side_effect=opened), \
                 patch.object(m.os, 'fstat', side_effect=flagged), \
                 patch.object(m.os, 'read', side_effect=read):
                with self.assertRaises(ValueError): self.box.receive(0.01)
                self.assertEqual(len(flagged_fds), 1)
                self.assertEqual(flagged_reads, [])
            self.assertTrue(self.box.stopped)
            self.assertIsNone(self.box.pending)


if __name__ == '__main__':
    unittest.main()
