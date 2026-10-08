"""Source contracts; native Blender regeneration is checked separately."""
import ast
import hashlib
import importlib.util
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('ammo_recipe', ROOT/'tools/build_ammo_vfx.py')
recipe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recipe)

class AmmoHelper(unittest.TestCase):
    def test_current_helper_pin_and_ammo_callers(self):
        helper = ROOT/'tools/build_art.py'
        self.assertEqual(hashlib.sha256(helper.read_bytes()).hexdigest(), recipe.HELPER_SHA)
        # Conduit-only paths do not drive the ammo renderer.
        calls = {n.attr for n in ast.walk(ast.parse((ROOT/'tools/build_ammo_vfx.py').read_text()))
                 if isinstance(n, ast.Attribute) and isinstance(n.value, ast.Name) and n.value.id == 'art'}
        self.assertFalse(calls.intersection({'kit','world_export','main'}))
        for name in ('setup','mesh','tube','box','egg','ring','camera','pixels_render','png','material'):
            self.assertIn('def '+name+'(', helper.read_text())

    def test_foreground_refusal_has_no_output_or_scene_effects(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder).resolve()/'uncreated'
            bpy = SimpleNamespace(app=SimpleNamespace(background=False), ops=Mock())
            with patch.object(recipe,'pinned'), patch.dict(sys.modules,{'bpy':bpy}), patch.object(sys,'argv',['blender','--','--output-root',str(output)]):
                with self.assertRaisesRegex(RuntimeError, 'background'):
                    recipe.main()
            self.assertFalse(output.exists())
            bpy.ops.wm.read_factory_settings.assert_not_called()

if __name__ == '__main__': unittest.main()
