"""Blender metadata regression; render callbacks are simulated, never art evidence."""
import json
from pathlib import Path
import runpy
import sys
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

# Only version metadata is used; geometry callbacks below are deliberately simulated.
with patch.dict(sys.modules, {'bpy': SimpleNamespace(app=SimpleNamespace(version_string='metadata fixture')),
                             'mathutils': SimpleNamespace(Vector=None)}):
    main = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'tools/build_art.py'))['main']
g = main.__globals__
foreign = [{'id': name, 'recipe_sha256': 'retained', 'retained': {'source': name, 'values': [1, 2]}}
           for name in ('vertebral_furnace', 'caster', 'intake_throat_frame', 'ammo_vfx')]
failures = []
with tempfile.TemporaryDirectory(prefix='art-manifest-metadata-') as folder:
    root = Path(folder)
    g['ART'], g['OUT'], g['SCRATCH'] = root / 'source', root / 'out', root / 'scratch'
    (g['OUT'] / 'textures').mkdir(parents=True)
    (g['OUT'] / 'textures/surface_atlas.png').write_bytes(b'simulated atlas presence')
    g['ART'].mkdir()
    g['build_enemy'] = lambda name: {'id': name, 'outputs': [{'sha256': 'simulated'}]}
    g['build_textures'] = lambda: [{'id': name} for name in ('floor', 'grate', 'wall')]
    path = g['ART'] / 'manifest.json'
    for asset in ('worker', 'floor'):
        path.write_text(json.dumps({'assets': [{'id': 'arch'}, *foreign, {'id': 'crawler'}]}))
        sys.argv = ['blender', '--', '--asset', asset]
        try:
            main()
            assets = json.loads(path.read_text())['assets']
            assert [a for a in assets if a['id'] in {f['id'] for f in foreign}] == foreign
            known = [a['id'] for a in assets if a['id'] in g['IDS']]
            assert known == sorted(known, key=g['IDS'].index)
            assert assets[-len(foreign):] == foreign
            assert asset in known
        except (ValueError, AssertionError) as error:
            failures.append((asset, str(error)))
assert not failures, failures
print('PASS real recipe metadata: geometry and texture rebuilds retain later assets in stable order')
