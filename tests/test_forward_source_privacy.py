"""SIMULATED fixed-RNA buffers and static save boundaries; not native/art proof."""
import ast
import copy
import hashlib
from pathlib import Path
import runpy
import shutil
import sys
import tempfile
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tests'))
sys.path.insert(0, str(ROOT))


def functions(path, names, namespace):
    tree = ast.parse(path.read_text())
    nodes = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in names]
    exec(compile(ast.Module(body=nodes, type_ignores=[]), str(path), 'exec'), namespace)
    return namespace


class RNA:
    def __init__(self, field, value, size=1282):
        object.__setattr__(self, 'field', field)
        object.__setattr__(self, 'raw', bytearray(size))
        object.__setattr__(self, 'binary', isinstance(value, bytes))
        object.__setattr__(self, 'writes', [])
        object.__setattr__(self, 'bl_rna', NS(properties={field: NS(length_max=size)}))
        setattr(self, field, value)

    def __setattr__(self, name, value):
        if name != self.field:
            return object.__setattr__(self, name, value)
        data = value if isinstance(value, bytes) else value.encode()
        assert len(data) < len(self.raw)
        self.raw[:len(data)+1] = data + b'\0'  # RNA leaves the remaining fixed buffer untouched.
        self.writes.append(value)

    def __getattr__(self, name):
        if name == self.field:
            data = bytes(self.raw).split(b'\0', 1)[0]
            return data if self.binary else data.decode()
        raise AttributeError(name)


class ForwardPrivacy(unittest.TestCase):
    def sanitizer(self):
        return functions(ROOT/'tools/build_art.py', {'_portable_path', 'sanitize_source_paths'}, {})

    def test_fixed_buffer_string_and_bytes(self):
        for value in ('//', b'//'):
            old = '/Users/private-owner/.codex/tasks/private-session/output'
            owner = RNA('path', old.encode() if isinstance(value, bytes) else old)
            # A short assignment really reproduces the private trailing-byte defect.
            setattr(owner, 'path', value)
            self.assertIn(b'private-session', owner.raw)
            self.sanitizer()['_portable_path'](owner, 'path', value)
            self.assertNotIn(b'private-session', owner.raw)
            self.assertEqual(owner.path, value)
            self.assertEqual(owner.writes[-2], value[:1] * 1281)

    def test_real_common_save_wipes_string_and_byte_buffers(self):
        render = RNA('filepath', '/Users/private-owner/render', 1024)
        browser = RNA('directory', b'/Users/private-owner/browser')
        saved = []
        bpy = NS(data=NS(images=[], scenes=[NS(render=render)],
                        screens=[NS(areas=[NS(spaces=[NS(type='FILE_BROWSER', params=browser)])])]),
                 ops=NS(wm=NS(save_as_mainfile=lambda **kw: saved.append((bytes(render.raw), bytes(browser.raw))))))
        namespace = {'bpy': bpy, 'ART': Path('/unused/source/art'), 'target': lambda path: path}
        functions(ROOT/'tools/build_art.py', {'_portable_path', 'sanitize_source_paths', 'save'}, namespace)
        self.assertEqual(namespace['save']('fixture'), Path('/unused/source/art/fixture.blend'))
        self.assertEqual(len(saved), 1)
        self.assertTrue(all(b'private-owner' not in data for data in saved[0]))

    def test_all_packed_render_and_browser_fields_preserve_external_data(self):
        images = []
        for name in ('atlas.png', 'reference.png'):
            image = RNA('filepath_raw', '/Users/private-owner/' + name, 1024)
            image.filepath = '/Users/private-owner/' + name
            image.packed_file = True
            image.packed_files = [RNA('filepath', '/Users/private-owner/' + name, 1024) for _ in range(2)]
            image.pixels = b'unchanged packed pixels'
            images.append(image)
        external = RNA('filepath_raw', '/external/required.png', 1024)
        external.packed_file = False
        scenes = [NS(render=RNA('filepath', '/Users/private-owner/render', 1024)) for _ in range(2)]
        browsers = [RNA('directory', b'/Users/private-owner/browser') for _ in range(2)]
        screens = [NS(areas=[NS(spaces=[NS(type='FILE_BROWSER', params=p), NS(type='VIEW_3D')])]) for p in browsers]
        bpy = NS(data=NS(images=images+[external], scenes=scenes, screens=screens),
                 path=NS(basename=lambda p: p.rsplit('/', 1)[-1]))
        fn = self.sanitizer()['sanitize_source_paths']
        fn(bpy)
        fields = [f for i in images for f in [i, *i.packed_files]] + [s.render for s in scenes] + browsers
        before = [bytes(f.raw) for f in fields]
        fn(bpy)
        self.assertEqual(before, [bytes(f.raw) for f in fields])
        self.assertTrue(all(b'private-owner' not in f.raw for f in fields))
        self.assertEqual([i.filepath_raw for i in images], ['//atlas.png', '//reference.png'])
        self.assertEqual(external.filepath_raw, '/external/required.png')
        self.assertTrue(all(i.pixels == b'unchanged packed pixels' for i in images))

    def test_established_sanitizer_semantics_exact(self):
        def bodies(path):
            return [ast.dump(n, include_attributes=False) for n in ast.parse(path.read_text()).body
                    if isinstance(n, ast.FunctionDef) and n.name in ('_portable_path', 'sanitize_source_paths')]
        self.assertEqual(bodies(ROOT/'tools/build_art.py'), bodies(ROOT/'tools/build_nursery_gestation_v2.py'))

    def test_each_unsafe_save_is_immediately_sanitized(self):
        files = ('art', 'ammo_vfx', 'cathedral_kit', 'hud_art', 'marker_glyphs', 'shot_travel', 'skin_bell_v2')
        for name in files:
            tree = ast.parse((ROOT/f'tools/build_{name}.py').read_text())
            found = 0
            for node in ast.walk(tree):
                for field in ('body', 'orelse', 'finalbody'):
                    statements = getattr(node, field, [])
                    if not isinstance(statements, list): continue
                    for i, statement in enumerate(statements):
                        if isinstance(statement, ast.Expr) and isinstance(statement.value, ast.Call) and ast.unparse(statement.value.func).endswith('.save_as_mainfile'):
                            found += 1
                            self.assertGreater(i, 0, name)
                            self.assertIn('sanitize_source_paths(bpy)', ast.unparse(statements[i-1]), name)
            self.assertEqual(found, 1, name)

    def test_atmosphere_logical_provenance(self):
        tree = ast.parse((ROOT/'tools/build_world_atmosphere_art.py').read_text())
        assignment = next(n for n in ast.walk(tree) if isinstance(n, ast.Assign)
                          and "scene['source_root'], scene['project_root']" in ast.unparse(n))
        self.assertEqual(ast.literal_eval(assignment.value), ('authoring repository root', 'dependency snapshot root'))

    def test_current_execution_pins_and_build_record(self):
        import json
        helper = hashlib.sha256((ROOT/'tools/build_art.py').read_bytes()).hexdigest()
        for name, constant in (('ammo_vfx', 'HELPER_SHA'), ('hud_art', 'HELPER_SHA'),
                               ('marker_glyphs', 'HELPER_SHA'), ('marker_identities', 'HELPER_SHA'),
                               ('rivet_pistol_v2', 'HELPER_SHA'), ('nursery_gestation_v2', 'PINS'),
                               ('ossuary_buttress', 'DEPENDENCIES'), ('shot_travel', 'PINS'),
                               ('skin_bell_v2', 'BASELINE_PINS')):
            tree = ast.parse((ROOT/f'tools/build_{name}.py').read_text())
            node = next(n for n in tree.body if isinstance(n, ast.Assign)
                        and any(isinstance(t, ast.Name) and t.id == constant for t in n.targets))
            pins = ast.literal_eval(node.value)
            if isinstance(pins, str): self.assertEqual(pins, helper, name)
            else:
                self.assertEqual(pins['tools/build_art.py'], helper, name)
                for logical, digest in pins.items():
                    if logical.startswith('tools/'):
                        self.assertEqual(hashlib.sha256((ROOT/logical).read_bytes()).hexdigest(), digest, name)
        manifest = json.loads((ROOT/'source/art/manifest.json').read_text())
        self.assertEqual(manifest['build']['script_sha256'], helper)

    def test_retained_glyph_metadata_uses_recorded_helpers(self):
        import json
        import test_marker_glyph_artifact as validator
        fixture = validator.ArtifactFixtures('test_metadata_and_mapping_parity')
        self.addCleanup(fixture.doCleanups)
        fixture.setUp()
        digest, dependencies = next(iter(validator.RETAINED_GENERATIONS.items()))
        fixture.entry.update(recipe_sha256=digest, recipe_dependencies=dependencies)
        meta = validator.producer['metadata'](fixture.pixels, validator.COUNTS, digest)
        meta.update(blender_version='fixture', recipe_dependencies=dependencies)
        (fixture.root/validator.METADATA).write_text(json.dumps(meta))
        fixture.refresh()
        self.assertEqual(fixture.validate()['glyphs'], 16)
        fixture.entry['recipe_dependencies'] = dict(dependencies, **{'tools/build_art.py': '0'*64})
        with self.assertRaises((AssertionError, ValueError)): fixture.validate()

    def test_unknown_archived_nursery_and_buttress_never_execute(self):
        import json
        import test_art
        from unittest.mock import patch
        from tools.ossuary_buttress_contract import validate_entry
        manifest = json.loads((ROOT/'source/art/manifest.json').read_text())
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            shutil.copytree(ROOT/'tools', root/'tools')
            shutil.copytree(ROOT/'source/art/recipe_history', root/'source/art/recipe_history')
            for name in ('nursery_gestation_engine', 'ossuary_living_buttress'):
                entry = copy.deepcopy(next(a for a in manifest['assets'] if a['id'] == name))
                data = b'raise RuntimeError("Manifest-selected archive executed")\n'
                digest = hashlib.sha256(data).hexdigest()
                logical = entry['provenance']['authoring_script']
                path = root/'source/art/recipe_history'/digest/(logical+'.txt')
                path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(data)
                entry['recipe_sha256'] = digest
                with self.assertRaisesRegex(AssertionError, 'trusted .* generation'):
                    if name == 'nursery_gestation_engine':
                        with patch.object(test_art, 'ROOT', root): test_art.check_nursery_v2(entry, b'')
                    else: validate_entry(root, entry)

    def test_current_builder_rejects_helper_drift_even_with_exact_archive(self):
        recipe = runpy.run_path(str(ROOT/'tools/build_marker_identities.py'))
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            for logical in (*recipe['HELPER_SHA'], recipe['REFERENCE']):
                path = root/logical; path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT/logical, path)
            check = recipe['check_inputs']; check.__globals__['SOURCE_ROOT'] = root
            check()
            logical = 'tools/build_art.py'; current = root/logical
            archive = root/'source/art/recipe_history'/recipe['HELPER_SHA'][logical]/(logical+'.txt')
            archive.parent.mkdir(parents=True); shutil.copyfile(current, archive)
            current.write_bytes(current.read_bytes()+b'\n# drift\n')
            with self.assertRaisesRegex(ValueError, 'drifted input'): check()

    def test_atmosphere_retains_original_helper_generation(self):
        import json
        import test_world_atmosphere_art as validator
        recipe = runpy.run_path(str(ROOT/'tools/build_world_atmosphere_art.py'))
        entry = next(a for a in json.loads((ROOT/'source/art/manifest.json').read_text())['assets']
                     if a['id'] == 'nursery_growth_vault')
        validator.validate_generation(ROOT, entry, recipe)
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            shutil.copytree(ROOT/'tools', root/'tools')
            shutil.copytree(ROOT/'source/art/recipe_history', root/'source/art/recipe_history')
            logical = recipe['RECIPE']
            archived = root/'source/art/recipe_history'/entry['recipe_sha256']/(logical+'.txt')
            shutil.copyfile(archived, root/logical)
            validator.validate_generation(root, entry, recipe)
        changed = copy.deepcopy(entry); changed['recipe_dependencies']['tools/build_art.py'] = '0'*64
        with self.assertRaises((AssertionError, ValueError)):
            validator.validate_generation(ROOT, changed, recipe)

    def test_cathedral_rejects_rehashed_invalid_native_header(self):
        import json
        import test_cathedral_art as validator
        from unittest.mock import patch
        read = Path.read_bytes
        manifest_path = ROOT/'source/art/manifest.json'
        manifest = json.loads(read(manifest_path))
        source = next(a['source'] for a in manifest['assets'] if a['id'] == validator.IDS[0])
        broken = b'BROKEN!'+read(ROOT/source)[7:]
        for asset in manifest['assets']:
            if asset['source'] == source:
                asset['source_sha256'] = hashlib.sha256(broken).hexdigest()
        def mutated_bytes(path):
            if path == ROOT/source: return broken
            if path == manifest_path: return json.dumps(manifest).encode()
            return read(path)
        with patch.object(validator, 'ROOT', ROOT), patch.object(Path, 'read_bytes', mutated_bytes):
            with self.assertRaisesRegex(AssertionError, 'Blender source header'):
                validator.check()

    def test_catalog_metadata_projection_remains_exact(self):
        import json
        import test_ossuary_buttress as validator
        from unittest.mock import patch
        validator.check_catalog()
        read = Path.read_text
        path = ROOT/'source/art/manifest.json'
        original = json.loads(read(path))
        for field in ('source_sha256', 'outputs'):
            manifest = copy.deepcopy(original)
            ivory = next(a for a in manifest['assets'] if a['id'] == 'marker_ivorykey')
            if field == 'source_sha256': ivory[field] = '0'*64
            else: ivory[field][0]['sha256'] = '0'*64
            def mutated_text(candidate, *args, **kwargs):
                return json.dumps(manifest) if candidate == path else read(candidate, *args, **kwargs)
            with patch.object(Path, 'read_text', mutated_text):
                with self.assertRaises(AssertionError): validator.check_catalog()

    def test_direct_retained_generation_guards(self):
        import test_art
        import json
        manifest = json.loads((ROOT/'source/art/manifest.json').read_text())
        for name in ('ammo_vfx', 'hud_kit', 'cathedral_vault_6m', 'shot_travel'):
            entry = next(a for a in manifest['assets'] if a['id'] == name)
            test_art.validate_forward_recipe(ROOT, entry)
            changed = copy.deepcopy(entry)
            changed['recipe_dependencies']['tools/build_art.py'] = '0'*64
            with self.assertRaises((AssertionError, ValueError)):
                test_art.validate_forward_recipe(ROOT, changed)
            changed = copy.deepcopy(entry); changed['recipe_sha256'] = '0'*64
            with self.assertRaises((AssertionError, ValueError)):
                test_art.validate_forward_recipe(ROOT, changed)

    def test_retained_marker_survives_forward_generation_but_not_tamper(self):
        import test_marker_identity_artifact as validator
        import json
        entry = json.loads((ROOT/validator.FAMILY).read_text())['assets'][0]
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            for logical, digest in {validator.RECIPE: entry['recipe_sha256'], **entry['recipe_dependencies']}.items():
                source = ROOT/logical
                old = ROOT/'source/art/recipe_history'/digest/(logical+'.txt')
                data = old.read_bytes() if old.exists() else source.read_bytes()
                archive = root/'source/art/recipe_history'/digest/(logical+'.txt')
                archive.parent.mkdir(parents=True, exist_ok=True); archive.write_bytes(data)
                current = root/logical; current.parent.mkdir(parents=True, exist_ok=True)
                current.write_bytes(source.read_bytes()+b'\n# simulated forward generation\n')
            ref = root/validator.producer['REFERENCE']; ref.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT/validator.producer['REFERENCE'], ref)
            validator.validate_entry(entry, ROOT, root)
            changed = copy.deepcopy(entry); changed['recipe_dependencies']['tools/build_art.py'] = '0'*64
            with self.assertRaises((AssertionError, ValueError)):
                validator.validate_entry(changed, ROOT, root)
            archive.write_bytes(b'altered archive')
            with self.assertRaises((AssertionError, ValueError)):
                validator.validate_entry(entry, ROOT, root)


if __name__ == '__main__': unittest.main()
