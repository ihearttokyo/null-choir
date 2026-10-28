#!/usr/bin/env python3
"""Source/binary schema and transform checks, not Godot import or visual acceptance."""
import pathlib,json,struct,math,hashlib
from generate import ROOT,make,COLORS
reports=[]
atlas=ROOT/'raw/texture-atlas.png'
assert atlas.is_file()
png=atlas.read_bytes();assert png[:8]==b'\x89PNG\r\n\x1a\n'
width,height,depth,color_type=struct.unpack_from('>IIBB',png,16)
from PIL import Image
with Image.open(atlas) as image:
 image.verify()
with Image.open(atlas) as image:
 alpha=image.getchannel('A').getextrema() if 'A' in image.getbands() else (255,255)
 texture={'sha256':hashlib.sha256(png).hexdigest(),'bytes':len(png),'dimensions':[width,height],'bitDepth':depth,'pngColorType':color_type,'decodedAlphaExtrema':list(alpha),'baseColorInterpretation':'sRGB texture; COLOR_0 linear multiplicative facet value','gltfAlphaMode':'OPAQUE (default); image alpha ignored','quarterUVContract':'normalized 0.25 tile width with 4% per-tile inset; no integer boundary/resampling assumption'}
assert texture['sha256']=='580ef04e926d59e735bad0c933da87019ac3902df2ecfb04e630db70e0da5795'
for path in sorted((ROOT/'models').glob('*.gltf')):
 d=json.loads(path.read_text());assert d['images']==[{'uri':'../raw/texture-atlas.png'}]
 assert len(d['textures'])==1 and len(d['materials'])==16
 for material in d['materials']:
  assert material.get('alphaMode','OPAQUE')=='OPAQUE' and 'KHR_materials_unlit' in material['extensions']
  assert material['pbrMetallicRoughness']['baseColorTexture']['index']==0 and material['pbrMetallicRoughness'].get('baseColorFactor',[1,1,1,1])[3]==1
 raw=path.with_suffix('.bin').read_bytes();names=[n['name'] for n in d['nodes']];assert len(names)==len(set(names));assert 'UseTarget' in names and 'StockNeedle' in names
 def read(ai):
  a=d['accessors'][ai];v=d['bufferViews'][a['bufferView']];n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']];f={5126:'f',5125:'I'}[a['componentType']];vs=struct.unpack_from('<'+f*a['count']*n,raw,v['byteOffset']);return [vs[j:j+n] for j in range(0,len(vs),n)]
 count=0;world=[];parts={}
 def world_vertices(node):
  pp=d['meshes'][node['mesh']]['primitives'][0];vs=read(pp['attributes']['POSITION']);t=node.get('translation',[0,0,0]);ss=node.get('scale',[1,1,1]);return [[v[j]*ss[j]+t[j] for j in range(3)] for v in vs]
 for node in d['nodes']:
  if 'mesh' not in node:continue
  p=d['meshes'][node['mesh']]['primitives'][0];a=p['attributes'];pos=read(a['POSITION']);ns=read(a['NORMAL']);uv=read(a['TEXCOORD_0']);idx=read(p['indices']);tile=p['material'];t=node.get('translation',[0,0,0]);s=node.get('scale',[1,1,1]);world += [[v[j]*s[j]+t[j] for j in range(3)] for v in pos]
  parts[node['name']]={'node':node,'positions':world_vertices(node),'material':tile}
  assert all(abs(v)>1e-8 for v in s), 'singular authored transform'
  if tile in [12,13]:assert node['name']=='StockVolume', 'fluid material on non-stock structure'
  if node['name'].startswith('SterileBaffle'):assert tile in [0,1,8,11] and node['extras']['role']=='structural_baffle'
  assert len(pos)==len(ns)==len(uv);assert all(math.isfinite(v) for row in pos+ns+uv for v in row)
  assert all(abs(sum(v*v for v in n)-1)<1e-5 for n in ns)
  assert all(0<=i[0]<len(pos) for i in idx);assert len(idx)%3==0
  assert all(tile%4/4 < u < (tile%4+1)/4 and tile//4/4 < v < (tile//4+1)/4 for u,v in uv)
  for j in range(0,len(pos),3):
   aa=[pos[j+1][x]-pos[j][x] for x in range(3)];bb=[pos[j+2][x]-pos[j][x] for x in range(3)];cross=[aa[1]*bb[2]-aa[2]*bb[1],aa[2]*bb[0]-aa[0]*bb[2],aa[0]*bb[1]-aa[1]*bb[0]];assert sum(v*v for v in cross)>1e-14
  count+=len(idx)//3
 stock=next(n for n in d['nodes'] if n['name']=='StockVolume');b=stock['extras']['stockBounds'];stock_checks=[]
 pos=read(d['meshes'][stock['mesh']]['primitives'][0]['attributes']['POSITION']);assert min(v[1] for v in pos)==0 and max(v[1] for v in pos)==1
 empty=b['emptyState'];assert empty['visible'] is False and empty['scalePolicy']=='preserve-full-authored-scale';assert empty['geometricVolumeRemains'] is True and empty['renderedVolume']==0
 assert empty['scaleY']==b['fullHeightMeters'] and empty['scaleY']>0
 for f in [0,.5,1]:
  sy=stock['scale'][1]*(f if f>0 else 1);assert sy>1e-8 and stock['scale'][0]*sy*stock['scale'][2]>1e-8
  ys=[v[1]*sy+stock['translation'][1] for v in pos];assert abs(min(ys)-b['bottomMeters'])<1e-6
  assert abs(max(ys)-(b['bottomMeters']+(f if f>0 else 1)*b['fullHeightMeters']))<1e-6
  stock_checks.append({'fraction':f,'visible':f>0,'scaleY':sy,'transformDeterminant':stock['scale'][0]*sy*stock['scale'][2],'geometricBottom':min(ys),'geometricTop':max(ys),'renderedEmpty':f==0})
 repairs={}
 if path.stem=='capillary-organ':
  center=next(n for n in d['nodes'] if n['name']=='CapillaryVessel1');assert 'mesh' not in center and center['extras']['role']=='open_central_housing'
  stock_radius=max(math.hypot(v[0],v[2]) for v in parts['StockVolume']['positions'])
  support_points=[v for name,part in parts.items() if name.startswith(('CapillaryCenterRing','CapillaryCenterRib')) for v in part['positions']]
  assert support_points
  inner_radius=min(math.hypot(v[0],v[2]) for v in support_points);assert inner_radius-stock_radius>.01
  side_checks=[]
  for fraction in [.5,1.0]:
   stock_top=b['bottomMeters']+b['fullHeightMeters']*fraction
   for side in [0,2]:
    relevant=[(name,part) for name,part in parts.items() if name=='CapillaryVessel'+str(side) or name.startswith('CapillaryFeed'+str(side)+'_') or name=='NeedleCrown'+str(side)]
    for name,part in relevant:
     points=[]
     vs=part['positions']
     for ti in range(0,len(vs),3):
      tri=vs[ti:ti+3]
      if max(v[1] for v in tri)>=b['bottomMeters'] and min(v[1] for v in tri)<=stock_top:points+=tri
     if not points:continue
     inner=min(abs(v[0]) for v in points);gap=inner-stock_radius
     assert gap>=.012, 'closed side assembly overlaps visible stock: '+name
     side_checks.append({'fraction':fraction,'part':name,'innerAbsX':inner,'stockMaxRadius':stock_radius,'minimumGapMeters':gap})
  repairs['sideAssemblyClearances']=side_checks
  repairs['centralOpenHousing']={'stockMaxRadiusMeters':stock_radius,'supportMinRadiusMeters':inner_radius,'radialClearanceMeters':inner_radius-stock_radius,'closedCentralHousingMesh':False}
 if path.stem in ['hanging-pressure-bulb','canted-supported-orbit-core']:
  drain=parts['StockDrainConnection']['positions'];outlet=[v for name,part in parts.items() if name.startswith('Outlet_') for v in part['positions']]
  low=min(v[1] for v in drain);high=max(v[1] for v in drain);outtop=max(v[1] for v in outlet)
  assert low<=outtop and high>=b['bottomMeters']+.01
  endpoints=parts['StockDrainConnection']['node']['extras']['connectionEndpoints'];assert endpoints[0]==[0,.37,0]
  stockbase=list({tuple(v) for v in parts['StockVolume']['positions'] if abs(v[1]-b['bottomMeters'])<1e-6});center=[sum(v[j] for v in stockbase)/len(stockbase) for j in range(3)]
  assert abs(endpoints[1][0]-center[0])<1e-6 and abs(endpoints[1][2]-center[2])<1e-6
  assert endpoints[1][1]>=center[1]+.014
  for ep in endpoints:
   assert all(min(v[j] for v in drain)-1e-6<=ep[j]<=max(v[j] for v in drain)+1e-6 for j in range(3))
  assert min(v[1] for v in parts['StockVolume']['positions'])<high
  repairs['continuousDrain']={'drainYBounds':[low,high],'outletMaxY':outtop,'stockBottom':b['bottomMeters'],'stockOverlapMeters':high-b['bottomMeters'],'centerlineEndpoints':endpoints,'stockBottomCenter':center}
 if path.stem=='clinical-abstract-capsule':
  assert len([n for n in parts if n.startswith('SterileBaffle')])==3
  repairs['fixedBaffles']={'role':'structural_baffle','tileIndices':[p['material'] for n,p in parts.items() if n.startswith('SterileBaffle')],'fluidTilesForbidden':[12,13]}
 glb=path.with_suffix('.glb').read_bytes();assert struct.unpack_from('<III',glb)==(0x46546c67,2,len(glb));jslen,kind=struct.unpack_from('<II',glb,12);assert kind==0x4e4f534a;g=json.loads(glb[20:20+jslen]);assert 'uri' not in g['buffers'][0] and g['images'][0]['uri']=='../raw/texture-atlas.png'
 extent=[max(v[j] for v in world)-min(v[j] for v in world) for j in range(3)];assert .8<extent[0]<1.0 and 1.15<extent[1]<1.4 and .5<extent[2]<.8
 reports.append({'family':path.stem,'nodes':len(names),'triangles':count,'extentXYZMeters':extent,'stockTransformChecks':stock_checks,'reviewBatch01Assertions':repairs,'sourceBinaryChecks':'PASS','externalAtlasExists':(ROOT/'raw/texture-atlas.png').exists()})
report={'evidence':'source-only stdlib geometry binary checks plus installed Pillow PNG verification; no engine import or external validator','textureAudit':texture,'families':reports,'heldUnrun':['Blender import/master save','Godot importer/material behavior','640x360 in-game visibility/readability','full/half/empty actual runtime stock hookup','collision/save integration','native8K masters']}
(ROOT/'metadata/validation.json').write_text(json.dumps(report,indent=2))
files=[p for p in ROOT.rglob('*') if p.is_file() and p.name!='SHA256SUMS.txt' and '__pycache__' not in str(p)]
(ROOT/'SHA256SUMS.txt').write_text('\n'.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(ROOT)) for p in sorted(files))+'\n')
print(json.dumps({'families':len(reports),'checks':'PASS','bytes':sum(p.stat().st_size for p in files),'atlasExists':report['families'][0]['externalAtlasExists']}))
