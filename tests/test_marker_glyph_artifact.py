"""Glyph bytes/inventory only: default adopted, --candidate-root PATH, or --unit."""
import argparse
import ast
import copy
import hashlib
import json
from pathlib import Path
import runpy
import struct
import tempfile
import unittest
import zlib

from test_art import png, validate_recipe

ROOT = Path(__file__).resolve().parents[1]
RECIPE = 'tools/build_marker_glyphs.py'
SOURCE = 'source/art/marker_glyphs.blend'
ATLAS = 'game/assets/art/hud/marker_glyphs.png'
METADATA = 'game/assets/art/hud/marker_glyphs.json'
METHOD = 'original editable Blender glyph geometry, native CPU orthographic render'
producer = runpy.run_path(str(ROOT / RECIPE))  # Current trusted source only; archives remain data.
NAMES = producer['NAMES']
COUNTS = {name: sum(4*len(polygon)-4 for _, polygon in producer['geometry'](name)) for name in NAMES}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def exact_file(root, relative):
    root = Path(root)
    assert root.is_absolute() and root.resolve() == root, 'canonical artifact root required'
    path = root / relative
    assert path.resolve() == path and path.is_relative_to(root), 'aliased or escaped artifact'
    assert not any(p.is_symlink() for p in (path, *path.parents)), 'symlinked artifact'
    assert path.is_file(), 'missing artifact: '+relative
    return path


def validate_entry(entry, artifact_root=ROOT, provenance_root=ROOT):
    assert entry['id'] == 'marker_glyphs' and entry['source'] == SOURCE, 'glyph identity/source path'
    assert entry['provenance'] == {'method': METHOD, 'authoring_script': RECIPE,
                                    'imports': [], 'license': 'Original NULL CHOIR project art'}, 'glyph provenance'
    validate_recipe(provenance_root, entry, RECIPE, producer['HELPER_SHA'])
    assert entry['recipe_dependencies'] == producer['HELPER_SHA'], 'glyph helper pins'
    references = [{'path': producer['REFERENCE'], 'sha256': producer['REFERENCE_SHA']}]
    assert entry['reference_images'] == references, 'glyph reference inventory'
    for reference in references:
        assert sha(exact_file(provenance_root, reference['path'])) == reference['sha256'], 'glyph reference hash'
    source = exact_file(artifact_root, SOURCE)
    data = source.read_bytes()
    assert data[:7] == b'BLENDER', 'glyph source header'
    assert sha(source) == entry['source_sha256'], 'glyph source hash'
    outputs = entry['outputs']
    assert len(outputs) == 2 and {o['path'] for o in outputs} == {ATLAS, METADATA}, 'closed glyph outputs'
    for output in outputs:
        expected_keys = {'path', 'sha256', 'bytes'} | ({'dimensions'} if output['path'] == ATLAS else set())
        assert set(output) == expected_keys, 'glyph output fields'
        path = exact_file(artifact_root, output['path'])
        assert type(output['bytes']) is int and path.stat().st_size == output['bytes'], 'glyph output byte parity'
        assert sha(path) == output['sha256'], 'glyph output hash'
    atlas = exact_file(artifact_root, ATLAS)
    assert atlas.read_bytes()[-12:] == b'\x00\x00\x00\x00IEND\xaeB`\x82', 'glyph PNG closure'
    size, pixels = png(atlas)
    assert size == (256, 256), 'glyph atlas dimensions'
    atlas_entry = next(o for o in outputs if o['path'] == ATLAS)
    assert atlas_entry['dimensions'] == list(size), 'glyph dimension parity'
    runtime_bytes = sum(o['bytes'] for o in outputs)
    producer['check_sizes'](runtime_bytes, len(data))
    assert entry['cell_size'] == [64,64] and entry['columns'] == 4, 'glyph atlas layout'
    assert entry['filter'] == 'nearest' and entry['clear_border'] == 4, 'glyph sampling/gutters'
    assert entry['pose_collections'] == list(NAMES), 'glyph collection order'
    assert type(entry['triangles']) is int and entry['triangles'] == sum(COUNTS.values()) < 10000, 'glyph triangle parity'
    build = entry['build']
    assert set(build) == {'blender_version','render_engine','device','threads','samples'}, 'glyph build fields'
    assert (build['render_engine'],build['device'],build['threads'],build['samples']) == ('CYCLES','CPU',4,8), 'glyph recorded build'
    assert isinstance(build['blender_version'], str) and build['blender_version'], 'glyph Blender version'
    meta = json.loads(exact_file(artifact_root, METADATA).read_bytes())
    expected = producer['metadata'](pixels, COUNTS, entry['recipe_sha256'])
    expected['blender_version'] = build['blender_version']
    assert meta == expected, 'glyph exact pixel/metadata/contract parity'
    masks = []
    for index in range(len(NAMES)):
        x,y = index%4*64, index//4*64
        masks.append(b''.join(pixels[((y+cy)*256+x)*4+3:((y+cy)*256+x+64)*4:4] for cy in range(64)))
    assert len(set(masks[10:])) == 6, 'six unique weapon silhouettes'
    assert masks[8] != masks[9], 'distinct blood/ivory silhouettes'
    assert len(set(masks)) == 16, 'unique glyph silhouettes'
    return {'runtime_bytes':runtime_bytes, 'source_bytes':len(data), 'triangles':entry['triangles'], 'glyphs':len(NAMES)}


def candidate_entry(root):
    """Ephemeral manifest-shaped entry from native receipt; never write/adopt it."""
    receipt = json.loads(exact_file(root, 'NATIVE-GLYPH-RECEIPT.json').read_bytes())
    assert set(receipt['artifacts']) == {SOURCE,ATLAS,METADATA}, 'candidate artifact inventory'
    assert receipt['native_source_saved_before_runtime'] is True, 'recorded source ordering'
    entry = {'id':'marker_glyphs', 'source':SOURCE, 'source_sha256':receipt['artifacts'][SOURCE],
             'outputs':[{'path':p, 'sha256':receipt['artifacts'][p],
                         'bytes':exact_file(root,p).stat().st_size,
                         **({'dimensions':[256,256]} if p == ATLAS else {})} for p in (ATLAS,METADATA)],
             'provenance':{'method':METHOD,'authoring_script':RECIPE,'imports':[],
                           'license':'Original NULL CHOIR project art'},
             'recipe_sha256':receipt['recipe_sha256'], 'recipe_dependencies':receipt['recipe_dependencies'],
             'reference_images':[{'path':producer['REFERENCE'],'sha256':receipt['reference_sha256']}],
             'cell_size':[64,64], 'columns':4, 'filter':'nearest', 'clear_border':4,
             'pose_collections':list(NAMES), 'triangles':receipt['source_triangles'],
             'build':{k:receipt[k] for k in ('blender_version','render_engine','device','threads','samples')}}
    assert receipt['source_bytes'] == exact_file(root,SOURCE).stat().st_size, 'candidate source byte parity'
    assert receipt['runtime_bytes'] == sum(o['bytes'] for o in entry['outputs']), 'candidate runtime byte parity'
    return entry


def check(root=ROOT, candidate=False):
    root = Path(root)
    if candidate:
        entry = candidate_entry(root)
    else:
        assets = json.loads(exact_file(root,'source/art/manifest.json').read_bytes())['assets']
        entries = [a for a in assets if a['id'] == 'marker_glyphs']
        assert len(entries) == 1, 'one adopted marker_glyphs entry required (intended RED before parent adoption)'
        entry = entries[0]
    result = validate_entry(entry, root, ROOT if candidate else root)
    print('PASS glyph artifact bytes/pins/metadata, 16 unique masks; not native geometry or game recognition')
    return result


class ArtifactFixtures(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.pixels = bytearray(256*256*4)
        for index in range(16):
            for cx in range(index+1):
                x,y = index%4*64+8+cx,index//4*64+32
                self.pixels[(y*256+x)*4:(y*256+x)*4+4] = bytes(producer['IVORY_RGBA'])
        meta = producer['metadata'](self.pixels,COUNTS,sha(ROOT/RECIPE))
        meta['blender_version'] = 'fixture'
        for relative in (SOURCE,ATLAS,METADATA):
            (self.root/relative).parent.mkdir(parents=True,exist_ok=True)
        (self.root/SOURCE).write_bytes(b'BLENDER-v-fixture')
        (self.root/METADATA).write_text(json.dumps(meta))
        tree = ast.parse((ROOT/'tools/build_art.py').read_text())
        node = next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name == 'png')
        namespace = {'struct':struct,'zlib':zlib,'target':lambda p:p}
        exec(compile(ast.Module(body=[node],type_ignores=[]),'<retained PNG writer>','exec'),namespace)
        self.write_png = namespace['png']
        self.write_png(self.root/ATLAS,256,256,self.pixels)
        self.entry = {'id':'marker_glyphs','source':SOURCE,'source_sha256':sha(self.root/SOURCE),
                      'outputs':[], 'provenance':{'method':METHOD,'authoring_script':RECIPE,'imports':[],
                                                'license':'Original NULL CHOIR project art'},
                      'recipe_sha256':sha(ROOT/RECIPE),'recipe_dependencies':producer['HELPER_SHA'],
                      'reference_images':[{'path':producer['REFERENCE'],'sha256':producer['REFERENCE_SHA']}],
                      'cell_size':[64,64],'columns':4,'filter':'nearest','clear_border':4,
                      'pose_collections':list(NAMES),'triangles':sum(COUNTS.values()),
                      'build':{'blender_version':'fixture','render_engine':'CYCLES','device':'CPU','threads':4,'samples':8}}
        self.refresh()

    def refresh(self):
        self.entry['outputs'] = [{'path':p,'sha256':sha(self.root/p),'bytes':(self.root/p).stat().st_size,
                                 **({'dimensions':[256,256]} if p == ATLAS else {})} for p in (ATLAS,METADATA)]

    def validate(self):
        return validate_entry(self.entry,self.root,ROOT)

    def test_valid_fixture_and_inventory_discovery(self):
        self.assertEqual(self.validate()['glyphs'],16)
        import test_art
        self.assertIn('marker_glyphs',test_art.EXPECTED)
        self.assertEqual(len(test_art.EXPECTED),117)
        original = {a['id'] for a in json.loads((ROOT/'source/art/manifest.json').read_bytes())['assets']
                    if a['id'] != 'marker_glyphs' and a['id'] not in test_art.MARKER_IDENTITIES}
        self.assertEqual(len(original),111)
        self.assertEqual(test_art.EXPECTED-{'marker_glyphs'}-test_art.MARKER_IDENTITIES,original)

    def test_missing_and_corrupt_artifacts(self):
        for relative in (SOURCE,ATLAS,METADATA):
            with self.subTest(path=relative):
                path = self.root/relative
                original = path.read_bytes()
                path.unlink()
                with self.assertRaises(AssertionError): self.validate()
                path.write_bytes(original+b'corrupt')
                with self.assertRaises(AssertionError): self.validate()
                path.write_bytes(original)

    def test_alias_and_output_path_escapes(self):
        original = copy.deepcopy(self.entry)
        for bad in ('../escape.blend','source/art/../art/marker_glyphs.blend','source/art/other.blend'):
            self.entry['source'] = bad
            with self.assertRaises(AssertionError): self.validate()
        self.entry = copy.deepcopy(original)
        for bad in ('../escape.png',ATLAS+'/../other.png',METADATA):
            self.entry['outputs'][0]['path'] = bad
            with self.assertRaises(AssertionError): self.validate()
        self.entry = copy.deepcopy(original)
        source = self.root/SOURCE
        data = source.read_bytes()
        source.unlink()
        target = self.root/'other.blend';target.write_bytes(data)
        source.symlink_to(target)
        with self.assertRaises(AssertionError): self.validate()

    def test_closed_outputs_and_byte_claims(self):
        for outputs in (self.entry['outputs'][:1],self.entry['outputs']*2):
            entry = copy.deepcopy(self.entry);entry['outputs'] = outputs
            with self.assertRaises(AssertionError): validate_entry(entry,self.root,ROOT)
        self.entry['outputs'][0]['bytes'] += 1
        with self.assertRaises(AssertionError): self.validate()

    def test_bad_header_and_png_crc_even_after_rehash(self):
        (self.root/SOURCE).write_bytes(b'NOTBLEND')
        self.entry['source_sha256'] = sha(self.root/SOURCE)
        with self.assertRaisesRegex(AssertionError,'header'): self.validate()
        (self.root/SOURCE).write_bytes(b'BLENDER-v-fixture')
        self.entry['source_sha256'] = sha(self.root/SOURCE)
        data = bytearray((self.root/ATLAS).read_bytes());data[29] ^= 1
        (self.root/ATLAS).write_bytes(data);self.refresh()
        with self.assertRaises(AssertionError): self.validate()

    def test_png_trailing_corruption_even_after_rehash(self):
        path = self.root/ATLAS
        original = path.read_bytes()
        for suffix in (b'trailing corruption', b'unparsed corruption'+original[-12:]):
            path.write_bytes(original+suffix);self.refresh()
            with self.subTest(suffix=suffix), self.assertRaisesRegex(AssertionError,'closure'):
                self.validate()

    def test_root_and_runtime_aliases(self):
        with self.assertRaisesRegex(AssertionError,'canonical'):
            validate_entry(self.entry,self.root/'..'/self.root.name,ROOT)
        alias = self.root/'alias';alias.symlink_to(self.root,target_is_directory=True)
        with self.assertRaises(AssertionError): validate_entry(self.entry,alias,ROOT)
        for relative in (ATLAS,METADATA):
            path = self.root/relative
            data = path.read_bytes()
            target = self.root/('alias-target'+path.suffix);target.write_bytes(data)
            path.unlink();path.symlink_to(target)
            with self.assertRaisesRegex(AssertionError,'aliased'): self.validate()
            path.unlink();path.write_bytes(data)

    def test_dimensions_palette_alpha_gutters_and_empty(self):
        for offset,color in ((0,producer['IVORY_RGBA']),((32*256+8)*4,(1,2,3,255)),
                              ((32*256+8)*4,producer['IVORY_RGBA'][:3]+(128,)),((32*256+8)*4,(0,0,0,0))):
            pixels = bytearray(self.pixels);pixels[offset:offset+4] = bytes(color)
            self.write_png(self.root/ATLAS,256,256,pixels);self.refresh()
            with self.assertRaises((AssertionError,ValueError)): self.validate()
        self.write_png(self.root/ATLAS,128,128,bytearray(128*128*4));self.refresh()
        with self.assertRaisesRegex(AssertionError,'dimensions'): self.validate()

    def test_metadata_and_mapping_parity(self):
        original = json.loads((self.root/METADATA).read_text())
        for key,value in [('columns',8),('contracts',{}),('sprites',{}),('recipe_sha256','0'*64),
                          ('recipe_dependencies',{}),('reference_sha256','0'*64),('binary_alpha',False)]:
            meta = copy.deepcopy(original);meta[key] = value
            (self.root/METADATA).write_text(json.dumps(meta));self.refresh()
            with self.assertRaisesRegex(AssertionError,'metadata'): self.validate()

    def test_duplicate_weapon_and_seal_masks(self):
        for index,other in ((11,10),(9,8)):
            pixels = bytearray(self.pixels)
            x,y = index%4*64,index//4*64;ox,oy = other%4*64,other//4*64
            for cy in range(64):
                pixels[((y+cy)*256+x)*4:((y+cy)*256+x+64)*4] = self.pixels[((oy+cy)*256+ox)*4:((oy+cy)*256+ox+64)*4]
            meta = producer['metadata'](pixels,COUNTS,self.entry['recipe_sha256']);meta['blender_version'] = 'fixture'
            (self.root/METADATA).write_text(json.dumps(meta))
            self.write_png(self.root/ATLAS,256,256,pixels);self.refresh()
            with self.assertRaisesRegex(AssertionError,'silhouettes'): self.validate()

    def test_provenance_pins_and_budget_boundaries(self):
        for key,value in [('recipe_sha256','0'*64),('recipe_dependencies',{}),('reference_images',[]),
                          ('triangles',10000),('columns',8),('pose_collections',list(reversed(NAMES)))]:
            entry = copy.deepcopy(self.entry);entry[key] = value
            with self.assertRaises((AssertionError,ValueError)): validate_entry(entry,self.root,ROOT)
        producer['check_sizes'](128*1024-1,8*1024*1024-1)
        for runtime,source in ((128*1024,1),(1,8*1024*1024)):
            with self.assertRaises(ValueError): producer['check_sizes'](runtime,source)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--unit',action='store_true')
    modes.add_argument('--candidate-root',type=Path)
    args = parser.parse_args()
    if args.unit:
        unittest.main(argv=[__file__],verbosity=2)
    else:
        check(args.candidate_root or ROOT,candidate=args.candidate_root is not None)


if __name__ == '__main__':
    main()
