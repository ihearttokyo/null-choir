"""Pure shipped-Main guard proof; no Godot, import, render, or gameplay claim."""
import ast,json,re,stat,unittest
from pathlib import Path
from types import SimpleNamespace
ROOT=Path(__file__).resolve().parents[1]
def resident_text(path):
    info=path.lstat()
    if not stat.S_ISREG(info.st_mode) or getattr(info,'st_flags',0)&0x40000000:
        raise RuntimeError("Resident regular source required; no hydration")
    return path.read_text()
class MainBodySelftestContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.main=resident_text(ROOT/'game/scripts/main.gd')
        ledger=json.loads(resident_text(ROOT/'source/art/bodies-v1/ledger.json'))
        assert ledger['status']=='QUALIFIED'
        cls.actors={row['kind']:row for row in ledger['actors']}
        match=re.search(r'_sprite_export_check\(checks,"original_worker_atlas",(.+)\)',cls.main)
        assert match
        cls.guard=match[1]
        tree=ast.parse(cls.guard,mode='eval')
        allowed=(ast.Expression,ast.BoolOp,ast.And,ast.Compare,ast.Eq,ast.Name,ast.Load,ast.Attribute,ast.Constant)
        assert all(isinstance(node,allowed) for node in ast.walk(tree))
        cls.expression=compile(tree,'actual Main Worker URI guard','eval')
    def accepts_uri(self,uri,valid=True):
        sprite=SimpleNamespace(texture=SimpleNamespace(resource_path=uri))
        return eval(self.expression,{'__builtins__':{}},{'sprite':sprite,'valid':valid})
    def test_literal_independent_pin_matches_approved_contract(self):
        worker=self.actors['worker']
        self.assertEqual(worker['runtime_uri'],'res://assets/art/sprites/bodies-v1/worker.png')
        self.assertEqual(worker['runtime_uri'],'res://'+worker['output']['path'].removeprefix('game/'))
        self.assertEqual(self.guard,'valid and sprite.texture.resource_path=="'+worker['runtime_uri']+'"')
    def test_qualified_production_URI_accepted_by_actual_source_expression(self):
        self.assertTrue(self.accepts_uri(self.actors['worker']['runtime_uri']))
    def test_wrong_legacy_fallback_rejected_by_actual_source_expression(self):
        self.assertFalse(self.accepts_uri('res://assets/art/sprites/worker.png'))
        self.assertFalse(self.accepts_uri('res://assets/art/sprites/bodies-v1/crawler.png'))
        self.assertFalse(self.accepts_uri(self.actors['worker']['runtime_uri'],False))
    def test_fixed_dimensions_match_all_eight_approved_roles(self):
        self.assertIn('var cell = 256 if actor.kind in ["nursery_warden","choir_avatar"] else 128',self.main)
        match=re.search(r'var expected_rows = (.+)',self.main)
        self.assertIsNotNone(match)
        expr=compile(ast.parse(match[1],mode='eval'),'actual Main expected rows','eval')
        self.assertIn('actor.sprite.texture.get_width() == cell*8 and actor.sprite.texture.get_height() == cell*expected_rows',self.main)
        for kind,row in self.actors.items():
            cell=256 if kind in ['nursery_warden','choir_avatar'] else 128
            rows=eval(expr,{'__builtins__':{}},{'actor':SimpleNamespace(kind=kind)})
            contract=row['runtime_contract']
            self.assertEqual([cell*8,cell*rows],contract['dimensions'])
            self.assertEqual(rows,contract['rows'])
    def test_legacy_five_row_worker_cannot_meet_fixed_current_dimensions(self):
        expected=re.search(r'var expected_rows = (.+)',self.main)[1]
        rows=eval(compile(ast.parse(expected,mode='eval'),'Main rows','eval'),{'__builtins__':{}},{'actor':SimpleNamespace(kind='worker')})
        self.assertEqual(rows,6)
        self.assertNotEqual(128*5,128*rows)
    def test_no_other_legacy_role_URI_assumption_in_Main(self):
        paths=re.findall(r'"(res://assets/art/sprites/[^"]+)"',self.main)
        self.assertEqual(paths,['res://assets/art/sprites/bodies-v1/worker.png'])
if __name__=='__main__':unittest.main(verbosity=2)
