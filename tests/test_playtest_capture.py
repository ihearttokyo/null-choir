"""Real private frame files; synthetic PNG/peer, never renderer evidence."""
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import zlib

from tools import playtest_capture as capture
from tools import playtest_bridge as wire
from tools import playtest_protocol as p
from tools import playtest_mailbox as ipc
from tools.playtest_recorder import FrameRecorder
from tests.test_playtest_protocol import observation
from tests.test_playtest_recorder import PNG
from tests.test_playtest_mailbox import dataless_metadata


def chunk(kind, body):
    return struct.pack('>I', len(body))+kind+body+struct.pack('>I', zlib.crc32(kind+body)&0xffffffff)


# Correct only the CRC of the existing mechanical one-pixel fixture. No new art.
VALID_PNG = PNG[:33]+chunk(b'IDAT', PNG[41:52])+PNG[56:]


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='null-choir-capture-')
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()/'run'
        self.journal = p.Journal(self.root, 'run-01', 'a'*64, 0,
             max_bytes=p.MAX_BYTES-ipc.IPC_RESERVED_BYTES-capture.CAPTURE_RESERVED_BYTES)
        self.addCleanup(self.journal.close)
        self.mailbox = ipc.Mailbox(self.journal)
        self.recorder = FrameRecorder(self.journal, byte_bound=1024)
        self.inbox = capture.CaptureInbox(self.recorder, self.mailbox)

    def peer(self, data=VALID_PNG, **changes):
        packet = {**self.mailbox.manifest, 'capture_id': self.inbox.last_id+1,
                  'post_draw': True, 'width': 1, 'height': 1,
                  'payload_bytes': len(data), 'payload_sha256': hashlib.sha256(data).hexdigest(),
                  'observation': json.loads(wire.encode_observation(observation(frame=8+self.inbox.last_id), 9000))}
        packet.update(changes)
        for name, body in (('capture.bin', data), ('capture.json', json.dumps(packet).encode())):
            path=self.root/name;path.write_bytes(body);path.chmod(0o600)
        return packet

    def test_private_initial_grant_and_valid_frame_hash_index_ack(self):
        grant=json.loads((self.root/'capture_ack.json').read_text())
        self.assertEqual(grant['capture_id'], 0)
        self.assertEqual(grant['next_byte_bound'], 1024)
        self.assertIsNone(self.inbox.poll(0))
        packet=self.peer()
        self.assertEqual(self.inbox.poll(0.01), 'frame-0000.png')
        self.assertEqual((self.root/'frame-0000.png').read_bytes(), VALID_PNG)
        ack=json.loads((self.root/'capture_ack.json').read_text())
        self.assertEqual(ack['capture_id'], 1)
        self.assertEqual(ack['payload_sha256'], packet['payload_sha256'])
        rows=[json.loads(x) for x in (self.root/'index.jsonl').read_text().splitlines()]
        self.assertEqual(rows[-1]['sha256'], ack['payload_sha256'])
        self.assertIsNone(self.inbox.poll(0.02))
        for path in self.root.iterdir(): self.assertEqual(path.stat().st_mode&0o777, 0o600)

    def test_bad_crc_and_decompression_bomb_are_rejected(self):
        with self.assertRaises(ValueError): capture.validate_png(PNG, 1, 1)
        header=chunk(b'IHDR', struct.pack('>IIBBBBB',1,1,8,6,0,0,0))
        bomb=PNG[:8]+header+chunk(b'IDAT',zlib.compress(b'\x00'*100000))+chunk(b'IEND',b'')
        with self.assertRaises(ValueError): capture.validate_png(bomb,1,1)
        capture.validate_png(VALID_PNG,1,1)
        for bad in (VALID_PNG+b'private trailing data', VALID_PNG[:-1],
                    VALID_PNG[:33]+chunk(b'IDAT',zlib.compress(b'\x05\x00\x00'))+chunk(b'IEND',b'')):
            with self.assertRaises(ValueError): capture.validate_png(bad,1,1)

    def test_corrupt_hash_stops_before_any_persisted_frame(self):
        self.peer(payload_sha256='b'*64)
        with self.assertRaises(ValueError): self.inbox.poll(0.01)
        self.assertTrue(self.inbox.stopped)
        self.assertEqual(self.journal.captures, 0)

    def test_future_id_stops_before_reading_png(self):
        self.peer(capture_id=2)
        with patch.object(self.mailbox,'_read',wraps=self.mailbox._read) as read, self.assertRaises(ValueError):
            self.inbox.poll(0.01)
        self.assertFalse(any(call.args[0]=='capture.bin' for call in read.call_args_list))

    def test_byte_cap_preflight_precedes_png_read(self):
        self.peer()
        self.journal.max_bytes=self.journal.bytes+1023
        with patch.object(self.mailbox,'_read',wraps=self.mailbox._read) as read, self.assertRaises(ValueError):
            self.inbox.poll(0.01)
        self.assertFalse(any(call.args[0]=='capture.bin' for call in read.call_args_list))
        self.assertEqual(self.journal.captures,0)

    def test_nonprivate_png_file_is_terminal(self):
        self.peer()
        (self.root/'capture.bin').chmod(0o644)
        with self.assertRaises(ValueError): self.inbox.poll(0.01)
        self.assertEqual(self.journal.captures,0)

    def test_missing_disk_reservation_creates_no_ack(self):
        journal=p.Journal(self.root.parent/'unreserved','run-01','a'*64,0,
                          max_bytes=p.MAX_BYTES-ipc.IPC_RESERVED_BYTES)
        self.addCleanup(journal.close)
        mailbox=ipc.Mailbox(journal)
        with self.assertRaises(ValueError): capture.CaptureInbox(FrameRecorder(journal,byte_bound=1024),mailbox)
        self.assertFalse((journal.root/'capture_ack.json').exists())

    def test_duplicate_reader_preserves_existing_owner_and_grant(self):
        before=(self.root/'capture_ack.json').read_bytes()
        with self.assertRaises(ValueError): capture.CaptureInbox(self.recorder,self.mailbox)
        self.assertFalse(self.journal.closed)
        self.assertFalse(self.inbox.stopped)
        self.assertEqual((self.root/'capture_ack.json').read_bytes(),before)
        self.peer()
        self.assertEqual(self.inbox.poll(0.01),'frame-0000.png')

    def test_terminal_ack_publication_failure_retains_possible_completed_frame(self):
        self.peer()
        before=(self.root/'capture_ack.json').read_bytes()
        with patch.object(ipc.os,'replace',side_effect=OSError('private error')),self.assertRaises(ValueError):
            self.inbox.poll(0.01)
        self.assertTrue(self.inbox.stopped)
        self.assertTrue(self.journal.closed)
        self.assertEqual((self.root/'frame-0000.png').read_bytes(),VALID_PNG)
        self.assertEqual((self.root/'capture_ack.json').read_bytes(),before)
        with self.assertRaises(ValueError): self.inbox.poll(0.02)

    def test_unknown_ack_symlink_preserves_target(self):
        journal=p.Journal(self.root.parent/'foreign-ack','run-01','a'*64,0,
              max_bytes=p.MAX_BYTES-ipc.IPC_RESERVED_BYTES-capture.CAPTURE_RESERVED_BYTES)
        self.addCleanup(journal.close)
        mailbox=ipc.Mailbox(journal)
        target=journal.root.parent/'keep';target.write_bytes(b'preserve')
        (journal.root/'capture_ack.json').symlink_to(target)
        with self.assertRaises(ValueError): capture.CaptureInbox(FrameRecorder(journal,byte_bound=1024),mailbox)
        self.assertEqual(target.read_bytes(),b'preserve')

    def test_metadata_identity_geometry_completion_unknown_and_stale_foreign_stop(self):
        changes=({'nonce':'0'*32},{'version':True},{'width':True},{'height':0},
                 {'width':2},{'post_draw':1},{'credential':'synthetic-private'},
                 {'capture_id':0},{'payload_bytes':1025},{'payload_sha256':'synthetic-private'},
                 {'observation':json.loads(wire.encode_observation(observation(build_sha256='b'*64),9000))})
        for index,change in enumerate(changes):
            journal=p.Journal(self.root.parent/f'bad-{index}','run-01','a'*64,0,
                   max_bytes=p.MAX_BYTES-ipc.IPC_RESERVED_BYTES-capture.CAPTURE_RESERVED_BYTES)
            self.addCleanup(journal.close)
            self.root,self.journal=journal.root,journal
            self.mailbox=ipc.Mailbox(journal)
            self.recorder=FrameRecorder(journal,byte_bound=1024)
            self.inbox=capture.CaptureInbox(self.recorder,self.mailbox)
            self.peer(**change)
            with self.subTest(change=change),self.assertRaises(ValueError): self.inbox.poll(0.01)
            self.assertEqual(journal.captures,0)

    def test_final_capture_ack_revokes_further_render_budget(self):
        self.journal.max_captures=1
        self.peer()
        self.assertEqual(self.inbox.poll(0.01),'frame-0000.png')
        self.assertEqual(json.loads((self.root/'capture_ack.json').read_text())['next_byte_bound'],0)
        self.assertTrue(self.inbox.stopped)
        self.assertTrue(self.journal.closed)

    def test_dataless_capture_metadata_and_body_rejected_before_open(self):
        for index, name in enumerate(('capture.json', 'capture.bin')):
            journal = p.Journal(self.root.parent/f'resident-pre-{index}', 'run-01', 'a'*64, 0,
                     max_bytes=p.MAX_BYTES-ipc.IPC_RESERVED_BYTES-capture.CAPTURE_RESERVED_BYTES)
            self.addCleanup(journal.close)
            self.root, self.journal = journal.root, journal
            self.mailbox = ipc.Mailbox(journal)
            self.recorder = FrameRecorder(journal, byte_bound=1024)
            self.inbox = capture.CaptureInbox(self.recorder, self.mailbox)
            self.peer()
            before = journal.bytes
            real_stat = ipc.os.stat
            def flagged(path, *args, **kwargs):
                info = real_stat(path, *args, **kwargs)
                return dataless_metadata(info) if path == name else info
            with self.subTest(name=name), patch.object(ipc.os, 'stat', side_effect=flagged), \
                 patch.object(ipc.os, 'open', wraps=ipc.os.open) as opened:
                with self.assertRaises(ValueError): self.inbox.poll(0.01)
                self.assertFalse(any(call.args[0] == name for call in opened.call_args_list))
            self.assertTrue(self.inbox.stopped)
            self.assertTrue(journal.closed)
            self.assertEqual(journal.captures, 0)
            self.assertEqual(journal.bytes, before)
            self.assertFalse((self.root/'frame-0000.png').exists())

    def test_capture_becomes_dataless_after_open_before_content_read(self):
        for index, name in enumerate(('capture.json', 'capture.bin')):
            journal = p.Journal(self.root.parent/f'resident-post-{index}', 'run-01', 'a'*64, 0,
                     max_bytes=p.MAX_BYTES-ipc.IPC_RESERVED_BYTES-capture.CAPTURE_RESERVED_BYTES)
            self.addCleanup(journal.close)
            self.root, self.journal = journal.root, journal
            self.mailbox = ipc.Mailbox(journal)
            self.recorder = FrameRecorder(journal, byte_bound=1024)
            self.inbox = capture.CaptureInbox(self.recorder, self.mailbox)
            self.peer()
            inode = (self.root/name).stat().st_ino
            real_fstat, real_open, real_read = ipc.os.fstat, ipc.os.open, ipc.os.read
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
            with self.subTest(name=name), patch.object(ipc.os, 'open', side_effect=opened), \
                 patch.object(ipc.os, 'fstat', side_effect=flagged), \
                 patch.object(ipc.os, 'read', side_effect=read):
                with self.assertRaises(ValueError): self.inbox.poll(0.01)
                self.assertEqual(len(flagged_fds), 1)
                self.assertEqual(flagged_reads, [])
            self.assertTrue(self.inbox.stopped)
            self.assertTrue(journal.closed)
            self.assertEqual(journal.captures, 0)
            self.assertFalse((self.root/'frame-0000.png').exists())


if __name__=='__main__': unittest.main()
