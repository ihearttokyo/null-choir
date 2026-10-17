"""Small deterministic alpha-contract fixtures; no renderer mocks."""
import unittest
import os
from pathlib import Path
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from shot_atlas import validate
import build_shot_travel as recipe
import hashlib,json
from test_art import png


def fixture():
    pixels = bytearray(256*256*4)
    for row in range(4):
        for col in range(4):
            for y in range(14,50):
                for x in range(14,50):
                    if row == 3 and 22 <= x < 42 and 22 <= y < 42:
                        continue
                    p = ((row*64+y)*256+col*64+x)*4
                    pixels[p:p+4] = b'\x80\xc0\xf0\xff'
    return pixels


class AlphaContract(unittest.TestCase):
    def test_valid_layout(self):
        self.assertEqual(len(validate(fixture())),16)

    def test_coverage_boundary_79_rejected_80_accepted(self):
        for count in (79,80):
            p=fixture()
            for y in range(64):
                for x in range(64):p[(y*256+x)*4+3]=0
            for i in range(count):p[((14+i//20)*256+14+i%20)*4+3]=255
            if count==79:
                with self.assertRaises(AssertionError):validate(p)
            else:self.assertEqual(len(validate(p)),16)

    def test_rejects_clipping_empty_soft_alpha_and_filled_void(self):
        for issue in ('clipped','empty','soft','void'):
            with self.subTest(issue=issue):
                p=fixture()
                if issue == 'clipped':
                    p[(32*256+3)*4+3]=255
                elif issue == 'empty':
                    for y in range(64):
                        p[y*256*4:y*256*4+256]=bytes(256)
                elif issue == 'soft':
                    p[(32*256+32)*4+3]=128
                else:
                    p[((3*64+32)*256+32)*4+3]=255
                with self.assertRaises(AssertionError):
                    validate(p)


class ActualArt(unittest.TestCase):
    def test_source_reference_recipe_and_pixels(self):
        manifest=json.loads((ROOT/'source/art/manifest.json').read_text())
        entries=[e for e in manifest['assets'] if e['id']=='shot_travel']
        self.assertEqual(len(entries),1)
        e=entries[0]
        for path,pin in [(e['source'],e['source_sha256']),(e['provenance']['authoring_script'],e['recipe_sha256']),*e['recipe_dependencies'].items(),*[(v['path'],v['sha256']) for v in e['reference_images']]]:
            self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest(),pin)
        self.assertEqual((ROOT/e['source']).read_bytes()[:7],b'BLENDER')
        self.assertFalse(b'/Users/' in (ROOT/e['source']).read_bytes(),"Editable shot source must omit factory home-directory metadata")
        self.assertLess((ROOT/e['source']).stat().st_size,8*1024*1024)
        self.assertEqual(e['families'],list(recipe.FAMILIES))
        self.assertEqual(e['pose_collections'],[family+'_travel_%02d'%i for family in recipe.FAMILIES for i in range(4)])
        self.assertEqual(len(e['outputs']),1)
        output=e['outputs'][0];path=ROOT/output['path'];size,pixels=png(path)
        self.assertEqual(size,(256,256))
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),output['sha256'])
        self.assertEqual(path.stat().st_size,output['bytes'])
        self.assertLessEqual(path.stat().st_size,512*1024)
        self.assertEqual([f['alpha_pixels'] for f in validate(pixels)],e['frame_alpha_pixels'])

    def test_all_actual_plate_outlines_are_outward(self):
        class Art:
            def __init__(self):self.plates=[]
            def mesh(self,name,vertices,faces,material):self.plates.append((vertices,faces))
            def tube(self,*args,**kwargs):pass
            def box(self,*args,**kwargs):pass
        art=Art()
        for phase in range(4):recipe.flechette(art,phase);recipe.needle(art,phase)
        self.assertEqual(len(art.plates),36)
        for vertices,faces in art.plates:
            volume=0
            for face in faces:
                a=vertices[face[0]]
                for i in range(1,len(face)-1):
                    b=vertices[face[i]];c=vertices[face[i+1]]
                    volume+=(a[0]*(b[1]*c[2]-b[2]*c[1])+a[1]*(b[2]*c[0]-b[0]*c[2])+a[2]*(b[0]*c[1]-b[1]*c[0]))/6
            self.assertGreater(volume,0)

class BuilderBoundaries(unittest.TestCase):
    def test_existing_output_and_missing_pins_rejected_before_blender(self):
        here=Path(__file__).resolve().parent
        env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'}
        for output,reason in ((here,'Fresh real output root required'),(here/'never-rendered-negative-fixture','Source drift')):
            result=subprocess.run([sys.executable,str(ROOT/'tools/build_shot_travel.py'),'--',
                                   '--repo-root',str(here),'--output-root',str(output)],
                                  env=env,capture_output=True,text=True,timeout=10)
            self.assertNotEqual(result.returncode,0)
            self.assertIn(reason,result.stderr)
        self.assertFalse((here/'never-rendered-negative-fixture').exists())


if __name__ == '__main__':
    unittest.main()
