import importlib.util
from pathlib import Path
import tempfile
import unittest

P = Path(__file__).resolve().parents[1] / 'tools/build_cathedral_kit.py'
spec = importlib.util.spec_from_file_location('kit', P)
kit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(kit)

class KitContract(unittest.TestCase):
    def test_authored_vault_proportions_and_clearance(self):
        for ceiling in (6, 9):
            pts = kit.pointed(1.65, ceiling - 2.5, ceiling - .35, 32)
            self.assertAlmostEqual(pts[0][0], -1.65)
            self.assertAlmostEqual(pts[-1][0], 1.65)
            self.assertAlmostEqual(max(z for x,z in pts), ceiling - .35)
            self.assertTrue(all(z >= 3.5 for x,z in pts))
            self.assertEqual(len(pts), 65)
        self.assertRaises(ValueError, kit.vault_parameters, 7)
    def test_output_refuses_production_overlap(self):
        project=Path('/project')
        for root in (project,project/'new',project.parent,Path('/candidate/../project')):
            self.assertRaises(ValueError,kit.isolated_output,root,project)
        self.assertEqual(kit.isolated_output(Path('/candidate'),project),Path('/candidate'))
    def test_refuse_existing_and_aliased_outputs(self):
        with tempfile.TemporaryDirectory(dir=str(P.parents[2])) as tmp:
            root = Path(tmp)
            p = kit.fresh(root, Path('source/art/test.blend'))
            p.write_text('preserve')
            self.assertRaises(FileExistsError, kit.fresh, root, Path('source/art/test.blend'))
            self.assertEqual(p.read_text(), 'preserve')
            (root / 'alias').symlink_to(root / 'source', target_is_directory=True)
            self.assertRaises(ValueError, kit.fresh, root, Path('alias/escape'))
            self.assertRaises(ValueError, kit.fresh, root, Path('../escape'))


# Simulated callback coverage only; it does not establish Blender geometry or pixels.
class BuilderCallbacks(unittest.TestCase):
    def test_all_authored_modules_have_nontrivial_finite_geometry_calls(self):
        import math
        from types import SimpleNamespace
        class Object(dict):
            def __init__(self): self.location=SimpleNamespace(x=0)
        class Geometry:
            def __init__(self): self.triangles=0; self.parts=0
            def add(self, triangles):
                self.triangles+=triangles; self.parts+=1
                return Object()
            def box(self,name,p,size,kind,bevel):
                self.validate([p]); self.validate([size]); return self.add(44 if bevel else 12)
            def egg(self,name,p,scale,kind,segments,rings):
                self.validate([p]); self.validate([scale]); return self.add(2*segments*(rings-1))
            def tube(self,name,pts,radius,kind,sides):
                self.validate(pts)
                if isinstance(radius,list):
                    assert len(radius)==len(pts)
                return self.add(2*(len(pts)-1)*sides+2*(sides-2))
            def ring(self,name,p,r,t,kind,plane,segments):
                self.validate([p]); return self.add(2*segments*8+12)
            def mesh(self,name,verts,faces,kind):
                self.validate(verts); return self.add(sum(len(f)-2 for f in faces))
            def validate(self,points):
                assert all(len(p)==3 and all(math.isfinite(v) for v in p) for p in points)
        total=0
        for builder in (lambda:kit.vault(6),lambda:kit.vault(9),kit.pier,kit.lancet,kit.corner,kit.dado,kit.lamp,kit.tile):
            geometry=Geometry(); kit.art=geometry; builder()
            self.assertGreater(geometry.parts,20)
            self.assertGreater(geometry.triangles,500)
            print('SIMULATED_TRIANGLES',builder.__name__,geometry.triangles,'parts',geometry.parts)
            total+=geometry.triangles
        self.assertGreater(total,30000)
        self.assertLess(total,60000)

if __name__ == '__main__': unittest.main()
