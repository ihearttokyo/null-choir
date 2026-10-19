"""Actual native asset bytes and Intake layout; pixels need separate GPU inspection."""
import hashlib
import json
import math
from pathlib import Path
import struct
import test_art

ROOT = Path(__file__).resolve().parents[1]
IDS = ('cathedral_vault_6m', 'cathedral_vault_9m', 'cathedral_cluster_pier',
       'cathedral_lancet_bay', 'cathedral_corner_rib', 'cathedral_skeletal_dado',
       'cathedral_brass_lamp', 'cathedral_inlay_tile')


def check():
    assets = {a['id']:a for a in json.loads((ROOT/'source/art/manifest.json').read_bytes())['assets']}
    assert set(IDS) <= assets.keys(), 'INTENDED RED: native image-derived cathedral kit required'
    total = (ROOT/'game/assets/art/textures/cathedral_kit_atlas.png').stat().st_size
    for name in IDS:
        asset = assets[name]
        test_art.validate_forward_recipe(ROOT, asset)
        assert hashlib.sha256((ROOT/asset['source']).read_bytes()).hexdigest() == asset['source_sha256']
        assert (ROOT/asset['source']).read_bytes().startswith(b'BLENDER'), 'Blender source header'
        assert asset['reference_images'] == [{'path':'source/art/references/cathedral-kit-reference-v1.png',
            'sha256':'67f9ecf5ee5dd1d7b54f05acc211a53beafa1eae5ca86b6acb2f014ae9fd9fb3'}]
        ref = asset['reference_images'][0]
        assert hashlib.sha256((ROOT/ref['path']).read_bytes()).hexdigest() == ref['sha256']
        output, = asset['outputs']
        raw = (ROOT/output['path']).read_bytes(); total += len(raw)
        assert len(raw) == output['bytes'] and hashlib.sha256(raw).hexdigest() == output['sha256']
        magic, version, length, n, kind = struct.unpack_from('<4sIII4s',raw)
        assert magic == b'glTF' and version == 2 and length == len(raw) and kind == b'JSON'
        doc = json.loads(raw[20:20+n]); size, kind = struct.unpack_from('<I4s',raw,20+n)
        assert kind == b'BIN\0' and 28+n+size == len(raw)
        binary = raw[28+n:]
        assert doc['images'] == [{'mimeType':'image/png','name':'cathedral_kit_atlas',
                                  'uri':'../textures/cathedral_kit_atlas.png'}]
        assert not doc.get('animations') and not doc.get('skins') and not doc.get('cameras')
        points, triangles = test_art.world_geometry(doc,binary)
        assert triangles == asset['triangles'] and 500 < triangles < 15000
        assert len(doc['meshes']) == asset['runtime_mesh_nodes'] <= 3
        bounds = asset['physical_bounds_m']
        # Blender XYZ exports as Godot X,Z,-Y. Check actual vertices, not claimed bounds.
        for axis, source_axis in [(0,0),(1,2),(2,1)]:
            lo, hi = min(p[axis] for p in points), max(p[axis] for p in points)
            expected_lo, expected_hi = bounds['min'][source_axis], bounds['max'][source_axis]
            if axis == 2: expected_lo, expected_hi = -expected_hi, -expected_lo
            assert abs(lo-expected_lo) < .002 and abs(hi-expected_hi) < .002, (name,axis,lo,hi)
        for mesh in doc['meshes']:
            for primitive in mesh['primitives']:
                assert set(primitive['attributes']) == {'POSITION','NORMAL','TEXCOORD_0'}
                a = doc['accessors'][primitive['attributes']['TEXCOORD_0']]
                view = doc['bufferViews'][a['bufferView']]
                assert a['componentType'] == 5126 and a['type'] == 'VEC2'
                start = view.get('byteOffset',0)+a.get('byteOffset',0)
                for i in range(a['count']):
                    uv = struct.unpack_from('<2f',binary,start+i*view.get('byteStride',8))
                    assert all(math.isfinite(v) and 0 <= v <= 1 for v in uv)
        for material in doc['materials']:
            assert material['pbrMetallicRoughness']['baseColorTexture'].get('texCoord',0) == 0
    assert total <= 5_000_000
    data = json.loads((ROOT/'game/data/01_intake.json').read_bytes())
    assert {'rect':[13,10,15,30],'height':26} in data['ceilings'] and {'rect':[11,10,17,30],'height':14} in data['ceilings'], 'INTENDED RED: tall nave replaces flattened roof'
    bays = [s for s in data['scenery'] if s['art']=='cathedral_vault_9m' and s['cell'][0]==14.5]
    assert [s['cell'][1] for s in bays] == [28,26,24.5,20,16,12]
    assert all(s['scale']==[2.8,2.8,1] and not s.get('solid') for s in bays)
    arches = [s for s in data['scenery'] if s['art'] in IDS[:2]]
    assert len(arches)==18 and all(len(s['supports'])==2 for s in arches)
    assert sum(s['art']=='cathedral_lancet_bay' for s in data['scenery']) == 8
    assert sum(s['art']=='cathedral_skeletal_dado' for s in data['scenery']) == 8
    assert len([s for s in data['scenery'] if 'tradition' in s]) == 7
    assert len(data['heroes']) == len(data['loops']) == 2
    assert sum(bool(s.get('shadow')) for s in data['lights']) == 4
    print('PASS actual 8 GLB vertices/UV/byte/source/reference parity <=5MB; tall Intake bays/windows/dados preserve loops and four shadows')


if __name__ == '__main__': check()
