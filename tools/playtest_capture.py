"""Private frame-file consumer; no renderer, native activation or image rewriting.

Metadata's post_draw bit is an assertion from a trusted future native producer,
not proof of rendering. Drain before newer state rows: late frames fail closed.
"""
import hashlib
import json
import re
import struct
import zlib

from . import playtest_bridge as wire
from . import playtest_protocol as p
from . import playtest_mailbox as ipc
from .playtest_recorder import PNG_SIGNATURE
from .playtest_transport import _unique_object

MAX_CAPTURE_BYTES = 8 * 1024 * 1024
MAX_CAPTURE_METADATA = 32768
MAX_WIDTH, MAX_HEIGHT = 1280, 720
CAPTURE_RESERVED_BYTES = 2*MAX_CAPTURE_BYTES + 2*MAX_CAPTURE_METADATA + 2*ipc.MAX_METADATA_BYTES
CAPTURE_KEYS = ipc.MANIFEST_KEYS | {'capture_id', 'post_draw', 'width', 'height',
                                  'payload_bytes', 'payload_sha256', 'observation'}
ACK_KEYS = ipc.MANIFEST_KEYS | {'capture_id', 'payload_sha256', 'next_byte_bound'}


def validate_png(data, width, height):
    """Bounded static 8-bit PNG profile. Does not certify pixels or native origin."""
    p.number(width, 1, MAX_WIDTH, True)
    p.number(height, 1, MAX_HEIGHT, True)
    if type(data) is not bytes or not 8 < len(data) <= MAX_CAPTURE_BYTES or not data.startswith(PNG_SIGNATURE):
        raise ValueError('Bounded PNG required')
    offset, chunks = 8, 0
    raw = bytearray()
    decoder = zlib.decompressobj()
    stride = expected = None
    idat = ended_idat = ended = False
    ancillary = {b'sRGB': 1, b'gAMA': 4, b'cHRM': 32, b'pHYs': 9}
    try:
        while offset < len(data):
            chunks += 1
            if chunks > 1024 or len(data)-offset < 12:
                raise ValueError('PNG chunk cap/truncation')
            size = struct.unpack_from('>I', data, offset)[0]
            kind = data[offset+4:offset+8]
            end = offset+12+size
            if end > len(data):
                raise ValueError('PNG truncation')
            body = memoryview(data)[offset+8:end-4]
            if zlib.crc32(body, zlib.crc32(kind))&0xffffffff != struct.unpack_from('>I', data, end-4)[0]:
                raise ValueError('PNG CRC')
            if chunks == 1:
                if kind != b'IHDR' or size != 13:
                    raise ValueError('PNG header')
                w, h, bits, color, compression, filtering, interlace = struct.unpack('>IIBBBBB', body)
                channels = {0:1, 2:3, 4:2, 6:4}.get(color)
                if (w != width or h != height or bits != 8 or channels is None
                        or (compression, filtering, interlace) != (0,0,0)):
                    raise ValueError('PNG geometry/profile')
                stride = 1+width*channels
                expected = height*stride
            elif kind == b'IDAT':
                if ended_idat:
                    raise ValueError('Nonconsecutive PNG image data')
                idat = True
                output = decoder.decompress(body, expected-len(raw)+1)
                if len(raw)+len(output) > expected or decoder.unconsumed_tail or decoder.unused_data:
                    raise ValueError('PNG expansion cap/extra stream')
                raw.extend(output)
            elif kind == b'IEND':
                if size or not idat or end != len(data):
                    raise ValueError('PNG end')
                ended = True
            else:
                # No animation, compressed text/profile or unknown decode allocation.
                if kind not in ancillary or size != ancillary[kind]:
                    raise ValueError('Unsupported PNG chunk')
                ended_idat = idat
            offset = end
        if not ended or not decoder.eof or len(raw) != expected or any(raw[i] > 4 for i in range(0,len(raw),stride)):
            raise ValueError('PNG stream/scanlines')
    except (struct.error, zlib.error, TypeError):
        raise ValueError('Invalid bounded PNG.') from None


class CaptureInbox:
    def __init__(self, recorder, mailbox):
        if 'capture_ack.json' in mailbox.owned or 'capture_ack.json.tmp' in mailbox.owned:
            raise ValueError('Capture reader already owns this run.')
        self.recorder, self.mailbox = recorder, mailbox
        self.last_id = 0
        self.last_state = None
        self.stopped = False
        try:
            if recorder.journal is not mailbox.journal or recorder.journal.max_bytes > p.MAX_BYTES-ipc.IPC_RESERVED_BYTES-CAPTURE_RESERVED_BYTES:
                raise ValueError('Owned capture disk reservation required')
            p.number(recorder.byte_bound,1,MAX_CAPTURE_BYTES,True)
            mailbox._root()
            recorder.journal.check_capture(recorder.byte_bound, recorder.journal.started_at)
            self._ack(0,hashlib.sha256(b'').hexdigest(),recorder.byte_bound)
        except Exception:
            self._fail()

    def _fail(self):
        self.stopped = True
        self.recorder.close()
        raise ValueError('Capture stopped; preserve evidence and release inputs.') from None

    def _ack(self, capture_id, digest, next_bound):
        packet = {**self.mailbox.manifest, 'capture_id':capture_id,
                  'payload_sha256':digest, 'next_byte_bound':next_bound}
        self.mailbox._publish('capture_ack.json', self.mailbox._encoded(packet))

    def poll(self, now):
        if self.stopped:
            raise ValueError('Capture stopped; no retry.')
        try:
            self.mailbox._clock(now)
            try:
                data = self.mailbox._read('capture.json',MAX_CAPTURE_METADATA)
            except FileNotFoundError:
                return None
            packet = json.loads(data.decode('utf-8'),object_pairs_hook=_unique_object)
            p.bounded_document(packet)
            if type(packet) is not dict or set(packet) != CAPTURE_KEYS:
                raise ValueError('Exact capture schema required')
            if any(packet[k] != v or type(packet[k]) is not type(v) for k,v in self.mailbox.manifest.items()):
                raise ValueError('Capture manifest mismatch')
            if type(packet['payload_sha256']) is not str or not re.fullmatch('[0-9a-f]{64}',packet['payload_sha256']):
                raise ValueError('Capture digest required')
            capture_id = p.number(packet['capture_id'],1,p.MAX_CAPTURES,True)
            if capture_id <= self.last_id:
                return None
            if capture_id != self.last_id+1 or packet['post_draw'] is not True:
                raise ValueError('Capture ID/completion')
            width = p.number(packet['width'],1,MAX_WIDTH,True)
            height = p.number(packet['height'],1,MAX_HEIGHT,True)
            size = p.number(packet['payload_bytes'],1,self.recorder.byte_bound,True)
            state = wire.decode_observation(wire._encode(packet['observation']))

            def produce(bound):
                payload = self.mailbox._read('capture.bin',bound)
                if len(payload) != size or hashlib.sha256(payload).hexdigest() != packet['payload_sha256']:
                    raise ValueError('Capture body mismatch')
                validate_png(payload,width,height)
                return payload

            path = self.recorder.frame_drawn(state,now,produce,completed=True)
            if path is not None:
                self.last_state = state
            self.last_id = capture_id
            next_bound = self.recorder.byte_bound
            try:
                self.recorder.journal.check_capture(next_bound,now)
            except ValueError:
                next_bound = 0
            self._ack(capture_id,packet['payload_sha256'],next_bound)
            if not next_bound:
                self.stopped = True
                self.recorder.close()
            return path
        except Exception:
            self._fail()
        except BaseException:
            self.stopped = True
            self.recorder.close()
            raise
