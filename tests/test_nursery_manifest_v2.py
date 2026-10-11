"""Boundary checks for the installed Nursery v2 manifest contract."""
from copy import deepcopy
import json
from pathlib import Path
import runpy
import hashlib
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
CHECK = runpy.run_path(str(ROOT / 'tests/test_art.py'))['check_nursery_v2']
ENTRY = next(a for a in json.loads((ROOT / 'source/art/manifest.json').read_text())['assets']
             if a['id'] == 'nursery_gestation_engine')
BLOB = (ROOT / ENTRY['outputs'][0]['path']).read_bytes()


class NurseryManifest(unittest.TestCase):
    def test_current_installed_art_contract(self):
        CHECK(ENTRY, BLOB)

    def test_integer_counts_are_not_coerced(self):
        for key in ['source_mesh_count', 'source_hierarchy_groups', 'triangles', 'runtime_mesh_nodes', 'material_count']:
            bad = deepcopy(ENTRY); bad[key] = float(bad[key])
            with self.subTest(key=key), self.assertRaises(AssertionError): CHECK(bad, BLOB)

    def test_embedded_flag_is_not_numeric(self):
        bad = deepcopy(ENTRY); bad['atlas']['embedded'] = 1
        with self.assertRaises(AssertionError): CHECK(bad, BLOB)

    def test_identity_and_reference_drift_rejected(self):
        for field in ['id', 'source']:
            bad = deepcopy(ENTRY); bad[field] = 'unrelated'
            with self.subTest(field=field), self.assertRaises(AssertionError): CHECK(bad, BLOB)
        bad = deepcopy(ENTRY); bad['provenance']['references'][0]['sha256'] = '0'*64
        with self.assertRaises(AssertionError): CHECK(bad, BLOB)

    def test_runtime_and_atlas_drift_rejected(self):
        bad = deepcopy(ENTRY); bad['outputs'][0]['sha256'] = '0'*64
        with self.assertRaises(AssertionError): CHECK(bad, BLOB)
        bad = deepcopy(ENTRY); bad['atlas']['sha256'] = '0'*64
        with self.assertRaises(AssertionError): CHECK(bad, BLOB)
        bad = deepcopy(ENTRY); bad['texture_dependencies'] = {'duplicate.png':'0'*64}
        with self.assertRaises(AssertionError): CHECK(bad, BLOB)


    def test_declared_dimensions_bound_to_source(self):
        for key, value in [('size', [99,99,99]), ('min', []), ('max', [1,1,1])]:
            bad = deepcopy(ENTRY); bad['physical_bounds_m'][key] = value
            with self.subTest(key=key), self.assertRaises(AssertionError): CHECK(bad, BLOB)

    def test_archived_wrong_helper_generation_rejected(self):
        bad = deepcopy(ENTRY)
        bad['recipe_dependencies']['tools/build_art.py'] = '25c9dca4239b0de3929baaa53a4efee7ee7fbedfe0d0085bf6f1d30b158c2d95'
        with self.assertRaises(AssertionError): CHECK(bad, BLOB)

    def test_rescaled_runtime_with_matching_record_rejected(self):
        recipe = runpy.run_path(str(ROOT / 'tools/build_nursery_gestation_v2.py'))
        doc, binary = recipe['unpack_glb'](BLOB); binary = bytearray(binary)
        indices = {p['attributes']['POSITION'] for mesh in doc['meshes'] for p in mesh['primitives']}
        for index in indices:
            accessor = doc['accessors'][index]; view = doc['bufferViews'][accessor['bufferView']]
            start = view.get('byteOffset',0) + accessor.get('byteOffset',0); stride = view.get('byteStride',12)
            for i in range(accessor['count']):
                offset = start+i*stride
                struct.pack_into('<f',binary,offset,struct.unpack_from('<f',binary,offset)[0]*1.02)
            accessor['min'][0] *= 1.02; accessor['max'][0] *= 1.02
        mutant = recipe['pack_glb'](doc,bytes(binary))
        report = recipe['inspect_glb'](mutant)
        self.assertGreater(report['bounds'][1][0]-report['bounds'][0][0],3.9)
        bad = deepcopy(ENTRY); bad['outputs'][0].update(bytes=len(mutant),sha256=hashlib.sha256(mutant).hexdigest())
        with self.assertRaisesRegex(ValueError, 'Export/source actual bounds parity'): CHECK(bad, mutant)
        for key in ['min','max','size']: bad['physical_bounds_m'][key][0] *= 1.02
        with self.assertRaises((AssertionError,ValueError)): CHECK(bad, mutant)


if __name__ == '__main__': unittest.main()
