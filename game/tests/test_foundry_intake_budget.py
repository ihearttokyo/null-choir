"""Source/ledger checks of the actual earned handoff predicate; not native gameplay."""
import ast
import json
from pathlib import Path
import re
import unittest

GAME = Path(__file__).resolve().parents[1]


def predicate():
    source = (GAME/'tests/test_foundry_earned_walk.gd').read_text()
    line = next(line for line in source.splitlines()
                if '"Exact independently verified Intake exit precedes all Foundry observer changes"' in line)
    expression = line.split('if not expect(', 1)[1].split(' and saved_exit_matches(', 1)[0]
    tree = ast.parse(expression, mode='eval')
    # GDScript dictionary-dot fields become Python dictionary keys, without changing logic.
    class Fields(ast.NodeTransformer):
        def visit_Attribute(self, node):
            return ast.Subscript(self.visit(node.value), ast.Constant(node.attr), ast.Load())
    return expression, ast.fix_missing_locations(Fields().visit(tree))


def evaluate(tree, carried, shots):
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Compare, ast.Eq, ast.Dict,
               ast.Constant, ast.List, ast.Load, ast.Name, ast.Subscript, ast.BinOp, ast.Add, ast.Sub)
    assert all(isinstance(node, allowed) for node in ast.walk(tree))
    return eval(compile(tree, '<actual Foundry handoff predicate>', 'eval'),
                {'__builtins__': {}}, {'carried': carried, 'game': {'shots': shots}})


class IntakeFoundryBudget(unittest.TestCase):
    def test_actual_exact_handoff(self):
        expression, tree = predicate()
        carried = {'health': 70, 'armor': 0, 'ammo': [0, 81, 0, 0, 0, 0],
                   'owned_weapons': [0, 1], 'weapon': 1, 'keys': []}
        for label, shots, ammo, accepted in [
            ('current exact witness', 89, 81, True),
            ('old80', 89, 80, False), ('extra82', 89, 82, False),
            ('wrong count', 88, 81, False), ('free+1 after90 shots', 90, 81, False),
            ('balanced historical count', 90, 80, False),
        ]:
            with self.subTest(label=label):
                candidate = {**carried, 'ammo': [0, ammo, 0, 0, 0, 0]}
                self.assertEqual(evaluate(tree, candidate, shots), accepted)
        self.assertIn('game.shots == 89', expression)
        # Exercise the actual independent arithmetic node, separately from fixed81/89.
        ledgers = [node for node in ast.walk(tree) if isinstance(node, ast.Compare)
                   and any(isinstance(child, ast.BinOp) for child in ast.walk(node))]
        self.assertEqual(len(ledgers), 1)
        ledger = ast.fix_missing_locations(ast.Expression(ledgers[0]))
        self.assertTrue(evaluate(ledger, carried, 89))
        self.assertFalse(evaluate(ledger, carried, 90), 'a free round must violate conservation')
        self.assertFalse(evaluate(ledger, {**carried, 'ammo': [0, 82, 0, 0, 0, 0]}, 89))

    def test_real_supply_and_pistol_only_counting_source(self):
        data = json.loads((GAME/'data/01_intake.json').read_text())
        supplies = {spec['id']: spec for spec in data['pickups']}
        campaign = (GAME/'scripts/campaign.gd').read_text()
        initial = json.loads(re.search(r'var ammo: Array = (\[[^\n]+\])', campaign)[1])[1]
        self.assertEqual(initial, 90)
        for id, amount in [('entry_ammo', 35), ('upper_ammo', 45)]:
            self.assertEqual((supplies[id]['kind'], supplies[id]['weapon'], supplies[id]['amount']),
                             ('ammo', 1, amount))
        self.assertEqual(initial+supplies['entry_ammo']['amount'], 125)
        self.assertEqual(125+supplies['upper_ammo']['amount']-89, 81)
        combat = (GAME/'tests/test_intake_combat.gd').read_text()
        west = (GAME/'tests/test_intake_west_seal.gd').read_text()
        complete = (GAME/'tests/test_intake_complete_walk.gd').read_text()
        self.assertIn('if weapon != 1 or not held', combat)
        self.assertIn('count,ammo-earned,weapon,held)', west)
        self.assertIn('shots += 1', west)
        self.assertIn('game.shot_ok and game.shot_clock_ok', complete)
        self.assertIn('game.state.ammo == [0,170-game.shots,0,0,0,0]', complete)


if __name__ == '__main__':
    unittest.main()
