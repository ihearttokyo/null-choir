"""Catalog and decoded-byte contracts; no engine or gameplay acceptance."""
import copy
import hashlib
import json
from pathlib import Path
import runpy
import struct
import sys
import tempfile
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
ID = 'ossuary_living_buttress'
BASELINE = 'b72a28cd995917905db1f94ebaf543ed17dd7787498dacde5d0511d36019f278'
GEOMETRY = '36ce1d987af3f80e16d77e8235157e3256958f25ea1b97390ede12f2fe65ea08'


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def check_catalog():
    manifest = json.loads((ROOT / 'source/art/manifest.json').read_text())
    entries = [a for a in manifest['assets'] if a['id'] == ID]
    assert len(entries) == 1, 'decorative buttress catalog entry absent'
    baseline = copy.deepcopy(manifest)
    baseline['assets'] = [a for a in baseline['assets'] if a['id'] != ID]
    assert len(baseline['assets']) == 118 and digest(baseline) == BASELINE, 'old catalog/build/palette changed'
    from tools.build_ossuary_buttress import design, preflight, assert_clean_source
    from tools.ossuary_buttress_contract import validate_entry
    entry = entries[0]
    assert 'level_id' not in entry and 'tradition_aesthetic' not in entry
    preflight(ROOT)
    assert digest(design()) == GEOMETRY, 'reviewed geometry changed during layout port'
    validate_entry(ROOT, entry)
    for field in ('source', 'outputs', 'provenance'):
        altered = copy.deepcopy(entry)
        if field == 'source':
            altered[field] = '/Users/private/source.blend'
        elif field == 'outputs':
            altered[field][0]['path'] = '../outside.glb'
        else:
            altered[field]['references'][0]['path'] = '/private/reference.png'
        try:
            validate_entry(ROOT, altered)
        except (AssertionError, ValueError):
            pass
        else:
            raise AssertionError('unsafe catalog path accepted: ' + field)
    for marker in (b'/Users/', b'/private/', b'.codex/tasks/'):
        try:
            assert_clean_source(b'BLENDER' + marker)
        except AssertionError:
            pass
        else:
            raise AssertionError('private marker accepted')


def check_hierarchy():
    geometry = runpy.run_path(str(ROOT / 'tests/test_art.py'))['world_geometry']
    doc = {'scene': 0, 'scenes': [{'nodes': [0]}],
           'nodes': [{'translation': [2, 3, 4], 'children': [1]},
                     {'translation': [-1, 2, 0], 'mesh': 0}],
           'meshes': [{'primitives': [{'attributes': {'POSITION': 0}, 'indices': 1, 'material': 0}]}],
           'accessors': [{'componentType': 5126, 'type': 'VEC3', 'bufferView': 0, 'count': 3}, {'count': 3}],
           'bufferViews': [{'byteLength': 36}]}
    binary = struct.pack('<9f', 0, 0, 0, 1, 0, 0, 0, 1, 0)
    points, triangles = geometry(doc, binary)
    assert points == [(1, 5, 4), (2, 5, 4), (1, 6, 4)] and triangles == 1, 'parent translation ignored'
    for change in ({'matrix': [1] * 16}, {'rotation': [1, 0, 0, 0]}, {'translation': [float('nan'), 0, 0]}):
        bad = copy.deepcopy(doc)
        bad['nodes'][0].update(change)
        try:
            geometry(bad, binary)
        except AssertionError:
            pass
        else:
            raise AssertionError('unsupported parent transform accepted')


def check_output_alias():
    from tools.build_ossuary_buttress import candidate_output
    alias = ROOT.with_name(ROOT.name.swapcase())
    if alias.is_dir() and alias.samefile(ROOT):
        target = alias / '__readonly_buttress_output_alias__'
        assert not target.exists()
        try:
            candidate_output(target, ROOT)
        except ValueError as exc:
            assert str(exc) == 'Output/input alias'
        else:
            raise AssertionError('case alias bypassed source isolation')
        assert not target.exists()
    else:
        print('NOT RUN: live case alias on a case-sensitive filesystem')
    with tempfile.TemporaryDirectory(prefix='null-choir-buttress-outside-', dir=Path(tempfile.gettempdir()).resolve()) as directory:
        target = Path(directory) / 'fresh'
        assert candidate_output(target, ROOT) == target
        assert not target.exists()


def check_proof_inventory():
    from tools.build_ossuary_buttress import ID, proof, sha
    source = 'source/art/ossuary_living_buttress_v1.blend'
    names = [source, 'game/assets/art/world/ossuary_living_buttress.glb', 'source/art/ossuary_atlas.png']
    with tempfile.TemporaryDirectory(prefix='null-choir-buttress-proof-', dir=Path(tempfile.gettempdir()).resolve()) as directory:
        output = Path(directory)
        for name in names:
            path = output / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'BLENDER fixture' if name == source else b'fixture')
        items = [dict(path=name, sha256=sha(output / name)) for name in names]
        opened = []
        def unexpected_open(**kwargs):
            opened.append(kwargs)
            raise RuntimeError('invalid candidate reached Blender')
        bpy = SimpleNamespace(ops=SimpleNamespace(wm=SimpleNamespace(open_mainfile=unexpected_open)))
        for inventory in [[], items[1:], [items[2]] * 3]:
            record = dict(id=ID, recipe_sha256=sha(ROOT / 'tools/build_ossuary_buttress.py'), artifacts=inventory)
            (output / 'candidate.receipt.json').write_text(json.dumps(record))
            try:
                proof(bpy, output, ROOT)
            except (AssertionError, ValueError):
                pass
            except RuntimeError as exc:
                raise AssertionError('incomplete proof inventory reached Blender') from exc
            else:
                raise AssertionError('incomplete proof inventory accepted')
            assert not opened
        (output / 'candidate.receipt.json').write_text(json.dumps(dict(record, artifacts=items)))
        original = output / source
        held = output / 'held-source.blend'
        original.rename(held)
        for alias_kind in ('symlink', 'hardlink'):
            if alias_kind == 'symlink':
                original.symlink_to(held)
            else:
                original.hardlink_to(held)
            try:
                proof(bpy, output, ROOT)
            except ValueError:
                pass
            else:
                raise AssertionError('aliased proof source accepted: ' + alias_kind)
            assert not opened
            original.unlink()


def check_validator_generation():
    h = runpy.run_path(str(ROOT / 'tools/build_ossuary_buttress.py'))
    with tempfile.TemporaryDirectory(prefix='null-choir-buttress-generation-', dir=Path(tempfile.gettempdir()).resolve()) as directory:
        root = Path(directory)
        g = h['preflight'].__globals__
        g['ROOT'] = root
        for logical, pin in h['DEPENDENCIES'].items():
            current = root / logical
            current.parent.mkdir(parents=True, exist_ok=True)
            data = (ROOT / logical).read_bytes()
            current.write_bytes(data)
            if logical == 'tools/ossuary_buttress_contract.py':
                archive = root / 'source/art/recipe_history' / pin / (logical + '.txt')
                archive.parent.mkdir(parents=True)
                archive.write_bytes(data)
                current.write_bytes(data + b'\n# different current generation\n')
        texture = root / 'texture.png'
        texture.write_bytes(b'fixture')
        g.update(REFERENCES={}, ATLAS_REFERENCE='texture.png', ATLAS_SHA=h['sha'](texture))
        try:
            h['preflight'](root)
        except ValueError:
            pass
        else:
            raise AssertionError('archive hid drift in the executing validator generation')


def check():
    check_output_alias()
    check_proof_inventory()
    check_validator_generation()
    check_catalog()
    check_hierarchy()
    from ossuary_buttress_controls import check_controls
    check_controls()
    print('PASS: decorative buttress catalog, unchanged baseline, decoded GLB and preserved negative controls')


if __name__ == '__main__':
    check()
