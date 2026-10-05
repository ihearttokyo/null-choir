"""Engine-free serializer tests; native importer/render parity is separate."""
import copy
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'tools/prune_untextured_uv.py'
spec = importlib.util.spec_from_file_location('prune_untextured_uv', SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def pack(document, binary):
    encoded = json.dumps(document, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    binary += b'\0' * (-len(binary) % 4)
    return (struct.pack('<4sII', b'glTF', 2, 28 + len(encoded) + len(binary)) +
            struct.pack('<I4s', len(encoded), b'JSON') + encoded +
            struct.pack('<I4s', len(binary), b'BIN\0') + binary)


def unpack(data):
    magic, version, length = struct.unpack_from('<4sII', data)
    assert (magic, version, length) == (b'glTF', 2, len(data))
    count, kind = struct.unpack_from('<I4s', data, 12)
    assert kind == b'JSON' and count % 4 == 0
    document = json.loads(data[20:20 + count])
    offset = 20 + count
    count, kind = struct.unpack_from('<I4s', data, offset)
    assert kind == b'BIN\0' and count % 4 == 0 and offset + 8 + count == len(data)
    return document, data[offset + 8:]


def fixture():
    streams = [struct.pack('<9f', 0, 0, 0, 1, 0, 0, 0, 1, 0),
               struct.pack('<9f', *([0, 0, 1] * 3)),
               struct.pack('<6f', 0, 0, 1, 0, 0, 1),
               struct.pack('<6f', .1, .2, .3, .4, .5, .6),
               struct.pack('<3H', 0, 1, 2)]
    binary = b''
    views, accessors = [], []
    for i, stream in enumerate(streams):
        binary += b'\0' * (-len(binary) % 4)
        views.append({'buffer': 0, 'byteOffset': len(binary), 'byteLength': len(stream),
                      'target': 34963 if i == 4 else 34962})
        accessors.append({'bufferView': i, 'componentType': 5123 if i == 4 else 5126,
                          'count': 3, 'type': 'SCALAR' if i == 4 else 'VEC3' if i < 2 else 'VEC2'})
        binary += stream
    accessors[0].update(min=[0, 0, 0], max=[1, 1, 0])
    return {'asset': {'version': '2.0'}, 'scene': 0, 'scenes': [{'nodes': [0]}],
            'nodes': [{'mesh': 0, 'name': 'original', 'translation': [1, 2, 3]}],
            'materials': [{'name': 'iron', 'pbrMetallicRoughness': {'metallicFactor': .6}}],
            'meshes': [{'name': 'original', 'primitives': [{'attributes': {'POSITION': 0,
                        'NORMAL': 1, 'TEXCOORD_0': 2, 'TEXCOORD_1': 3}, 'indices': 4, 'material': 0}]}],
            'accessors': accessors, 'bufferViews': views, 'buffers': [{'byteLength': len(binary)}]}, binary


class PruningTests(unittest.TestCase):
    def test_retained_streams_and_properties_are_exact(self):
        document, binary = fixture()
        original = copy.deepcopy(document)
        data = pack(document, binary)
        result = module.prune_glb(data)
        self.assertLess(len(result), len(data))
        out, payload = unpack(result)
        self.assertEqual(document, original)
        self.assertEqual(out['meshes'][0]['primitives'][0]['attributes'], {'POSITION': 0, 'NORMAL': 1})
        self.assertEqual(out['meshes'][0]['primitives'][0]['indices'], 2)
        self.assertEqual(len(out['accessors']), 3)
        for old_index, new_index in [(0, 0), (1, 1), (4, 2)]:
            old, new = document['bufferViews'][old_index], out['bufferViews'][new_index]
            self.assertEqual(binary[old['byteOffset']:old['byteOffset'] + old['byteLength']],
                             payload[new['byteOffset']:new['byteOffset'] + new['byteLength']])
            self.assertEqual(new['byteOffset'] % 4, 0)
            self.assertEqual({k: v for k, v in new.items() if k != 'byteOffset'},
                             {k: v for k, v in old.items() if k != 'byteOffset'})
            self.assertEqual({k: v for k, v in out['accessors'][new_index].items() if k != 'bufferView'},
                             {k: v for k, v in document['accessors'][old_index].items() if k != 'bufferView'})
        for key in ['asset', 'scene', 'scenes', 'nodes', 'materials']:
            self.assertEqual(out[key], document[key])
        self.assertEqual(result, module.prune_glb(data))
        self.assertEqual(result, module.prune_glb(result))

    def test_rejects_unsupported_references_and_layouts(self):
        cases = [
            ('texture', lambda d: d['materials'][0]['pbrMetallicRoughness'].update(baseColorTexture={'index': 0})),
            ('images', lambda d: d.update(images=[{'bufferView': 2, 'mimeType': 'image/png'}])),
            ('extension', lambda d: d['materials'][0].update(extensions={'KHR_materials_unlit': {}})),
            ('unknown root', lambda d: d.update(animations=[])),
            ('morph', lambda d: d['meshes'][0]['primitives'][0].update(targets=[{'POSITION': 2}])),
            ('shared view', lambda d: d['accessors'][2].update(bufferView=0)),
            ('shared accessor', lambda d: d['meshes'][0]['primitives'][0]['attributes'].update(NORMAL=2)),
            ('sparse', lambda d: d['accessors'][2].update(sparse={'count': 1})),
            ('stride', lambda d: d['bufferViews'][2].update(byteStride=8)),
            ('overlap', lambda d: d['bufferViews'][2].update(byteOffset=0)),
            ('external', lambda d: d['buffers'][0].update(uri='external.bin')),
            ('missing index', lambda d: d['meshes'][0]['primitives'][0].update(indices=50)),
            ('missing node', lambda d: d['scenes'][0].update(nodes=[50])),
            ('count mismatch', lambda d: d['accessors'][2].update(count=4)),
        ]
        for name, edit in cases:
            with self.subTest(name=name):
                document, binary = fixture()
                edit(document)
                with self.assertRaises(ValueError):
                    module.prune_glb(pack(document, binary))

    def test_rejects_invalid_chunks_and_oversized_input(self):
        document, binary = fixture()
        good = pack(document, binary)
        for data in [good[:-1], b'bad', good + b'\0' * 4,
                     good.replace(b'BIN\0', b'XXXX', 1), b'\0' * (8 * 1024 * 1024 + 1)]:
            with self.subTest(length=len(data)), self.assertRaises(ValueError):
                module.prune_glb(data)

    def test_cli_preserves_inputs_and_rejects_existing_or_project_targets(self):
        document, binary = fixture()
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()  # macOS /var is a system symlink; test deliberate links below.
            project = root / 'project'
            project.mkdir()
            (project / '.git').mkdir()
            source = project / 'input.glb'
            data = pack(document, binary)
            source.write_bytes(data)
            target = root / 'fresh.glb'
            command = [sys.executable, '-B', str(SCRIPT), '--input', str(source), '--output', str(target)]
            result = subprocess.run(command, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertLess(target.stat().st_size, len(data))
            saved = target.read_bytes()
            self.assertNotEqual(subprocess.run(command, capture_output=True, timeout=10).returncode, 0)
            self.assertEqual(target.read_bytes(), saved)
            for forbidden in [source, project / 'new.glb']:
                with self.subTest(target=forbidden):
                    blocked = subprocess.run(command[:-1] + [str(forbidden)], capture_output=True, timeout=10)
                    self.assertNotEqual(blocked.returncode, 0)
            link = root / 'link.glb'
            link.symlink_to(root / 'absent.glb')
            self.assertNotEqual(subprocess.run(command[:-1] + [str(link)], capture_output=True, timeout=10).returncode, 0)
            self.assertFalse((root / 'absent.glb').exists())
            directory_link = root / 'directory-link'
            directory_link.symlink_to(root, target_is_directory=True)
            self.assertNotEqual(subprocess.run(command[:-1] + [str(directory_link / 'linked.glb')], capture_output=True, timeout=10).returncode, 0)
            self.assertFalse((root / 'linked.glb').exists())
            alias = root / 'project-alias'
            alias.symlink_to(project, target_is_directory=True)
            aliased_input = command[:]
            aliased_input[4] = str(alias / 'input.glb')
            self.assertNotEqual(subprocess.run(aliased_input[:-1] + [str(project / 'alias-target.glb')],
                                              capture_output=True, timeout=10).returncode, 0)
            self.assertFalse((project / 'alias-target.glb').exists())
            (root / 'detour').mkdir()
            dotdot = root / 'detour' / '..' / 'project' / 'dotdot-target.glb'
            self.assertNotEqual(subprocess.run(command[:-1] + [str(dotdot)],
                                              capture_output=True, timeout=10).returncode, 0)
            self.assertFalse((project / 'dotdot-target.glb').exists())
            self.assertEqual(source.read_bytes(), data)
            self.assertFalse((project / 'new.glb').exists())


if __name__ == '__main__':
    unittest.main()
