"""Portable export contracts; bpy and export callbacks are SIMULATED, not art proof."""
import hashlib
import json
from pathlib import Path
import runpy
import struct
import sys
import tempfile
from types import SimpleNamespace as NS
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]


def glb(document):
    raw = json.dumps(document).encode()
    raw += b' ' * (-len(raw) % 4)
    binary = b'KEEP-BIN'
    return (struct.pack('<4sII', b'glTF', 2, 28 + len(raw) + len(binary)) +
            struct.pack('<I4s', len(raw), b'JSON') + raw +
            struct.pack('<I4s', len(binary), b'BIN\0') + binary)


class ConduitContracts(unittest.TestCase):
    def exporter(self):
        return runpy.run_path(str(ROOT / 'tools/build_conduit_art.py'))

    def test_background_refusal_precedes_open_and_writes(self):
        native = NS(app=NS(background=False), ops=Mock())
        helper = {'target': Mock()}
        with patch.dict(sys.modules, bpy=native):
            with self.assertRaisesRegex(RuntimeError, 'background'):
                self.exporter()['export_conduit'](helper)
        native.ops.wm.open_mainfile.assert_not_called()
        native.ops.export_scene.gltf.assert_not_called()
        helper['target'].assert_not_called()

    def test_sampler_preserves_bin_and_is_idempotent(self):
        fix = self.exporter()['without_atlas_mips']
        before = glb({'materials': [{'emissiveTexture': {'index': 0}}],
                      'textures': [{'sampler': 0}, {'sampler': 0}],
                      'samplers': [{'minFilter': 9987, 'magFilter': 9729}]})
        after = fix(before)
        self.assertEqual(after[-16:], before[-16:])
        n = struct.unpack_from('<I', after, 12)[0]
        doc = json.loads(after[20:20+n])
        self.assertEqual(doc['samplers'][doc['textures'][0]['sampler']]['minFilter'], 9729)
        self.assertEqual(doc['textures'][1]['sampler'], 0)
        self.assertEqual(fix(after), after)
        with self.assertRaises(ValueError):
            fix(b'not a glb')

    def test_dispatch_and_conduit_only_manifest(self):
        native = NS(app=NS(version_string='SIMULATED'))
        with patch.dict(sys.modules, bpy=native, mathutils=NS(Vector=None)):
            main = runpy.run_path(str(ROOT / 'tools/build_art.py'))['main']
        g = main.__globals__
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            g.update(ART=root/'source', OUT=root/'runtime', SCRATCH=root/'scratch')
            g['ART'].mkdir()
            path = g['ART']/'manifest.json'
            foreign = {'id': 'foreign', 'arbitrary': [1, 2]}
            path.write_text(json.dumps({'assets': [foreign]}))
            g['setup'] = Mock(side_effect=AssertionError('old kit must not run'))
            g['build_textures'] = Mock(side_effect=AssertionError('unrelated textures'))
            exported = {'id': 'conduit', 'outputs': [{'sha256': 'SIMULATED'}]}
            callback = Mock(return_value=exported)
            with patch.dict(sys.modules, build_conduit_art=NS(export_conduit=callback)):
                with patch.object(sys, 'argv', ['blender', '--', '--asset', 'conduit']):
                    main()
            callback.assert_called_once()
            self.assertEqual(json.loads(path.read_text())['assets'], [exported, foreign])
            self.assertFalse(json.loads(path.read_text())['build']['native_pixel_render'])
            self.assertFalse((g['OUT']/'textures').exists())

    def test_export_unchanged_source_relative_record_and_contracts(self):
        export = self.exporter()['export_conduit']
        g = export.__globals__
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root/'source/art/conduit.blend'
            source.parent.mkdir(parents=True)
            source.write_bytes(b'editable SIMULATED source')
            refs = root/'source/art/references'
            refs.mkdir()
            for name in g['REFERENCE_PINS']:
                (refs/name).write_bytes(name.encode())
            g['REFERENCE_PINS'] = {name: hashlib.sha256(name.encode()).hexdigest()
                                   for name in g['REFERENCE_PINS']}
            images = [NS(name=str(i), size=(256, 256), packed_file=True) for i in range(3)]
            mats = [NS(name=str(n), node_tree=NS(nodes=[NS(type='TEX_IMAGE', image=i) for i in images]))
                    for n in range(2)]
            obj = NS(type='MESH', data=NS(materials=mats,
                     polygons=[NS(vertices=(0, 1, 2), material_index=0),
                               NS(vertices=(0, 1, 2), material_index=1)], uv_layers=[True]),
                     modifiers=[], select_set=Mock())
            native = NS(app=NS(background=True), context=NS(scene=NS(objects=[obj]),
                        view_layer=NS(objects=NS(active=None), update=Mock())), ops=Mock())
            document = {'materials': [{'emissiveTexture': {'index': 0}}, {}],
                        'textures': [{'sampler': 0}], 'samplers': [{'minFilter': 9987}]}
            def successful_export(**kw):
                Path(kw['filepath']).write_bytes(glb(document))
                return {'FINISHED'}
            native.ops.object.join.return_value = {'FINISHED'}
            native.ops.export_scene.gltf.side_effect = successful_export
            def target(path):
                path.parent.mkdir(parents=True, exist_ok=True)
                return path
            sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
            helper = {'ROOT': root, 'ART': source.parent, 'OUT': root/'game/assets/art',
                      'target': target, 'sha': sha,
                      'bounds': lambda _: {'min': [-.49, -2.006, 0], 'max': [.49, 2.022, .585]},
                      'record': lambda name, src, paths, **kw: {'id': name,
                          'source': str(src.relative_to(root)), 'source_sha256': sha(src), **kw}}
            with patch.dict(sys.modules, bpy=native):
                result = export(helper)
            self.assertEqual(source.read_bytes(), b'editable SIMULATED source')
            native.ops.wm.open_mainfile.assert_called_once_with(filepath=str(source), load_ui=False, use_scripts=False)
            native.ops.wm.save_as_mainfile.assert_not_called()
            self.assertEqual(result['source'], 'source/art/conduit.blend')
            self.assertEqual(result['material_count'], 2)
            self.assertEqual(result['runtime_mesh_nodes'], 1)
            self.assertEqual(result['provenance']['authoring_script'], 'tools/build_conduit_art.py')
            self.assertEqual(result['recipe_sha256'], sha(ROOT/'tools/build_conduit_art.py'))
            self.assertTrue(all(not r['path'].startswith('/') for r in result['provenance']['references']))
            output = helper['OUT']/'world/conduit.glb'
            preserved = output.read_bytes()
            recorder = Mock(wraps=helper['record'])
            helper['record'] = recorder
            for operation in ('join', 'export'):
                with self.subTest(cancelled=operation):
                    native.ops.object.join.return_value = {'CANCELLED'} if operation=='join' else {'FINISHED'}
                    native.ops.export_scene.gltf.side_effect = None if operation=='export' else successful_export
                    native.ops.export_scene.gltf.return_value = {'CANCELLED'}
                    recorder.reset_mock()
                    with patch.dict(sys.modules, bpy=native):
                        with self.assertRaisesRegex(RuntimeError, 'cancelled'):
                            export(helper)
                    self.assertEqual(output.read_bytes(), preserved)
                    self.assertEqual(source.read_bytes(), b'editable SIMULATED source')
                    recorder.assert_not_called()
            obj.data.polygons *= 1600
            native.ops.export_scene.gltf.reset_mock()
            with patch.dict(sys.modules, bpy=native):
                with self.assertRaisesRegex(RuntimeError, 'triangle'):
                    export(helper)
            native.ops.export_scene.gltf.assert_not_called()

    def test_documented_commands_fail_on_python_error(self):
        for name in ('build_art.py','build_conduit_art.py'):
            doc = (ROOT/'tools'/name).read_text().split('\"\"\"')[1]
            self.assertIn('--python-exit-code 1', doc, name)

    def test_no_workstation_or_experimental_dependency(self):
        text = (ROOT/'tools/build_conduit_art.py').read_text()
        self.assertNotIn('/Users/', text)
        self.assertNotIn('conduit_fidelity_recipe', text)
        self.assertNotIn('save_as_mainfile', text)


if __name__ == '__main__':
    unittest.main()
