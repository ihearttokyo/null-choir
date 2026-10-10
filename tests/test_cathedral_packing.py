import copy
import importlib.util
import json
from pathlib import Path
import struct
from types import SimpleNamespace
import unittest
import zlib

ROOT=Path(__file__).resolve().parents[1]
def module(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/'tools'/(name+'.py'))
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result);return result
kit=module('build_cathedral_kit');packing=module('share_cathedral_atlas')

def png(pixel=b'\x20\x40\x80\xff'):
    def chunk(k,d):return struct.pack('>I',len(d))+k+d+struct.pack('>I',zlib.crc32(k+d)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',1,1,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(b'\0'+pixel))+chunk(b'IEND',b'')

def encode(doc,binary):
    j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*(-len(j)%4)
    binary+=b'\0'*(-len(binary)%4)
    return struct.pack('<4sII',b'glTF',2,28+len(j)+len(binary))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(binary),b'BIN\0')+binary

def decode(data):
    n=struct.unpack_from('<I',data,12)[0]
    return json.loads(data[20:20+n]),data[28+n:]

def fixture():
    atlas=png();pos=struct.pack('<9f',0,0,0,1,0,0,0,1,0);indices=struct.pack('<3H',0,1,2)
    binary=pos+atlas;binary+=b'\0'*(-len(binary)%4);index_offset=len(binary);binary+=indices
    d={'asset':{'version':'2.0'},'buffers':[{'byteLength':len(binary)}],
       'bufferViews':[{'buffer':0,'byteLength':len(pos),'target':34962},{'buffer':0,'byteOffset':len(pos),'byteLength':len(atlas)},{'buffer':0,'byteOffset':index_offset,'byteLength':len(indices),'target':34963}],
       'accessors':[{'bufferView':0,'componentType':5126,'count':3,'type':'VEC3','min':[0,0,0],'max':[1,1,0]}, {'bufferView':2,'componentType':5123,'count':3,'type':'SCALAR'}],
       'images':[{'name':'Kit atlas','mimeType':'image/png','bufferView':1}], 'samplers':[{'magFilter':9728}], 'textures':[{'source':0,'sampler':0}],
       'materials':[{'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'roughnessFactor':.68}}],
       'meshes':[{'primitives':[{'attributes':{'POSITION':0},'indices':1,'material':0}]}],
       'nodes':[{'mesh':0,'translation':[1,2,3]}],'scenes':[{'nodes':[0]}],'scene':0}
    return d,binary,atlas

def accessor_bytes(d,b,a):
    view=d['bufferViews'][a['bufferView']];off=view.get('byteOffset',0)
    return b[off:off+view['byteLength']]

class Packing(unittest.TestCase):
    def test_shared_image_and_non_image_identity(self):
        d,b,atlas=fixture();out=packing.externalize_atlas(encode(d,b),atlas);new,nb=decode(out)
        self.assertEqual(new['images'],[{'name':'Kit atlas','mimeType':'image/png','uri':packing.ATLAS_URI}])
        for old_a,new_a in zip(d['accessors'],new['accessors']):
            self.assertEqual(accessor_bytes(d,b,old_a),accessor_bytes(new,nb,new_a))
            self.assertEqual({k:v for k,v in old_a.items() if k!='bufferView'},{k:v for k,v in new_a.items() if k!='bufferView'})
        for key in ('meshes','nodes','materials','textures','samplers','scenes','scene'):
            self.assertEqual(d[key],new[key])
        # Same complete PNG bytes imply identical decodedRGBA; fixture also decodes the authored pixel.
        n=struct.unpack_from('>I',atlas,33)[0]
        self.assertEqual(zlib.decompress(atlas[41:41+n]),b'\0\x20\x40\x80\xff')
        self.assertLess(len(out),len(encode(d,b)))
    def test_reject_container_range_and_image_mismatch(self):
        d,b,a=fixture();valid=encode(d,b)
        for broken in (valid[:-1],b'bad'+valid[3:]):self.assertRaises(ValueError,packing.externalize_atlas,broken,a)
        for change in ('view_range','overlap','accessor_range','image_accessor','hidden_reference'):
            doc=copy.deepcopy(d)
            if change=='view_range':doc['bufferViews'][0]['byteLength']=len(b)+1
            if change=='overlap':doc['bufferViews'][1]['byteOffset']=0
            if change=='accessor_range':doc['accessors'][0]['count']=999
            if change=='image_accessor':doc['accessors'][0]['bufferView']=1
            if change=='hidden_reference':doc['nodes'][0]['extras']={'bufferView':1}
            self.assertRaises(ValueError,packing.externalize_atlas,encode(doc,b),a)
        self.assertRaises(ValueError,packing.externalize_atlas,valid,png(b'\x10\x20\x30\xff'))
    def test_uv_name_and_render_selection_are_uniform_before_join(self):
        class Layers(list):
            def __init__(self,names):
                super().__init__([SimpleNamespace(name=n,active_render=i==1,data=[SimpleNamespace(uv=(0,0)) for _ in range(3)]) for i,n in enumerate(names)])
                self.active_index=0
            @property
            def active(self):return self[self.active_index] if self else None
            def new(self,name):
                layer=SimpleNamespace(name=name,active_render=False,data=[SimpleNamespace(uv=(0,0)) for _ in range(3)]);self.append(layer);return layer
        class Object(dict):pass
        for names in (['UVMap','Unused lightmap'],['Authored 512px kit atlas'],[]):
            obj=Object(atlas_kind='brass');layers=Layers(names)
            coords=((0,0,0),(1,0,0),(0,1,0));obj.data=SimpleNamespace(uv_layers=layers,
                vertices=[SimpleNamespace(co=p) for p in coords],loops=[SimpleNamespace(vertex_index=i) for i in range(3)],
                polygons=[SimpleNamespace(normal=SimpleNamespace(z=1,y=0),loop_indices=[0,1,2])])
            kit.uv_map(obj)
            self.assertEqual(len(layers),1)
            self.assertEqual(layers[0].name,'Authored 512px kit atlas')
            self.assertIs(layers.active,layers[0]);self.assertTrue(layers[0].active_render)
            self.assertTrue(all(.75<u<1 and .5<v<1 for u,v in [l.uv for l in layers[0].data]))
            self.assertEqual(tuple(v.co for v in obj.data.vertices),coords)

if __name__=='__main__':unittest.main()
