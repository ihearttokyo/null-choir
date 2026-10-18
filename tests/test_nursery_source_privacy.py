"""Public editable source must retain portable paths and the actual rollback baseline."""
import ast
from pathlib import Path
import runpy
import unittest

ROOT = Path(__file__).resolve().parents[1]
RECIPE = ROOT/'tools/build_nursery_gestation_v2.py'


class SourceMetadata(unittest.TestCase):
    def test_rollback_matches_retained_canonical_baseline(self):
        recipe=runpy.run_path(str(RECIPE))
        self.assertEqual(recipe.get('ROLLBACK_COMMIT'),'84d27115f178a25c38dab0c6c98bafdd7ed918b8')
        self.assertEqual(recipe['ROLLBACK_PINS'],{
            'game/assets/art/world/nursery_gestation_engine.glb':'5d7921f949b3898d4293ec9c019f08dcd9df21a22bcb7e8977cc4c9c1a42502f',
            'source/art/manifest.json':'e33eef0912d9b4b3aeb41996dbe475b8b2537468c62d3970328a4c5c225b1556'})

    def test_saved_source_has_no_worker_path_or_task_identifier(self):
        blob=(ROOT/'source/art/nursery_gestation_engine_v2.blend').read_bytes()
        for marker in [b'/Users/',b'.codex/tasks/',b'/var/folders/']:
            self.assertFalse(marker in blob,'Private build metadata remains in saved source')

    def test_producer_sanitizes_before_saving_source(self):
        tree=ast.parse(RECIPE.read_text())
        main=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='main')
        calls=[n for n in ast.walk(main) if isinstance(n,ast.Call)]
        sanitizers=[n.lineno for n in calls if isinstance(n.func,ast.Name) and n.func.id=='sanitize_source_paths']
        saves=[n.lineno for n in calls if isinstance(n.func,ast.Attribute) and n.func.attr=='save_as_mainfile']
        self.assertTrue(sanitizers and saves and max(sanitizers)<min(saves),'Source paths must be sanitized before save')


if __name__=='__main__':unittest.main()
