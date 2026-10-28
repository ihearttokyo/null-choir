#!/usr/bin/env python3
"""Deterministic editable polygon assets. CPU only; stdlib only; meters; Y up; front -Z."""
import json, math, struct, hashlib, pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
TILES=['dark_iron','ivory','brass','crimson_glass','blue_glass','green_glass','amber_glass','dark_cavity','oxidized_steel','parchment','control_markings','bone','red_fluid','pale_fluid','gasket','hazard_stripe']
COLORS=['#424d53','#ded4b4','#ad853e','#752d38','#587f9a','#628c7c','#bc8640','#182329','#738b8c','#b7a783','#c6b99b','#d4c5a4','#a53342','#c0d4b4','#303c40','#b5a35d']
def vadd(a,b):return tuple(x+y for x,y in zip(a,b))
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def mul(a,s):return tuple(x*s for x in a)
def cross(a,b):return(a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def norm(a):return mul(a,1/math.sqrt(sum(x*x for x in a)))
class Kit:
 def __init__(self,name):self.name=name;self.parts=[]
 def part(self,name,verts,faces,tile,role='structure',translation=None,scale=None):
  p={'name':name,'vertices':verts,'faces':faces,'tile':tile,'role':role}
  if translation:p['translation']=translation
  if scale:p['scale']=scale
  self.parts.append(p)
 def box(self,name,c,s,t,role='structure'):
  x,y,z=c;a,b,d=[i/2 for i in s];v=[(x+i*a,y+j*b,z+k*d) for i,j,k in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
  self.part(name,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],t,role)
 def lathe(self,name,profile,t,c=(0,0,0),n=12,role='vessel',stock=False):
  v=[(r*math.cos(i*math.tau/n)+c[0],y+c[1],r*math.sin(i*math.tau/n)+c[2]) for y,r in profile for i in range(n)]
  f=[]
  for j in range(len(profile)-1):
   for i in range(n):a=j*n+i;b=j*n+(i+1)%n;f.append((a,a+n,b+n,b))
  f.extend([tuple(range(n)),tuple((len(profile)-1)*n+i for i in reversed(range(n)))])
  self.part(name,v,f,t,role)
 def beam(self,name,a,b,r,t,n=8,role='plumbing'):
  axis=norm(sub(b,a));u=norm(cross(axis,(0,0,1) if abs(axis[2])<.9 else (1,0,0)));w=cross(axis,u)
  v=[vadd(p,vadd(mul(u,r*math.cos(i*math.tau/n)),mul(w,r*math.sin(i*math.tau/n)))) for p in [a,b] for i in range(n)]
  f=[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]+[tuple(reversed(range(n))),tuple(i+n for i in range(n))]
  self.part(name,v,f,t,role)
 def ring(self,name,c,rx,ry,t,plane='xy',tube=.025,n=20):
  pts=[]
  for i in range(n):
   a=math.tau*i/n;p=(rx*math.cos(a),ry*math.sin(a),0) if plane=='xy' else (rx*math.cos(a),0,ry*math.sin(a));pts.append(vadd(c,p))
  for i in range(n):self.beam(name+f'_{i:02}',pts[i],pts[(i+1)%n],tube,t,6,'brace')
 def pipe(self,name,pts,r=.025,t=2):
  for i in range(len(pts)-1):
   if pts[i]!=pts[i+1]:self.beam(name+f'_{i}',pts[i],pts[i+1],r,t)
 def stock(self,t=12,r=.18,bottom=.39,height=.57):
  self.lathe('StockVolume',[(0,r*.82),(.08,r),( .9,r),(1,r*.82)],t,role='stock')
  self.parts[-1]['translation']=[0,bottom,0];self.parts[-1]['scale']=[1,height,1];self.parts[-1]['stockBounds']={'bottomMeters':bottom,'fullHeightMeters':height,'localBottom':0,'localTop':1,'emptyState':{'visible':False,'scalePolicy':'preserve-full-authored-scale','scaleY':height,'renderedVolume':0,'geometricVolumeRemains':True},'partialFraction':.5,'axis':'Y'}
 def control(self,y=.38,x=.28):
  # A three-quarter-facing handwheel and dial connected to the bottom vessel outlet.
  self.pipe('Outlet',[(0,.37,0),(0,y,0),(x,y,0),(x,y,-.19)],.035)
  self.beam('ValveHousing',(x,y,-.12),(x,y,-.27),.075,2,10,'valve')
  self.ring('ValveWheel',(x,y,-.295),.105,.105,1,tube=.018,n=12)
  for i in range(4):
   a=i*math.pi/2;self.beam(f'ValveSpoke_{i}',(x,y,-.295),(x+.09*math.cos(a),y+.09*math.sin(a),-.295),.012,2)
  self.beam('DialFace',(x,y,-.3),(x,y,-.31),.044,10,12,'control')
  self.box('StockNeedle',(0,.022,0),(.008,.048,.009),0,'stock_indicator')
  self.parts[-1]['translation']=[x,y,-.317]
  self.parts.append({'name':'UseTarget','role':'interaction','translation':[x,y,-.33],'controlRadiusMeters':.12})
 def foundation(self):
  self.box('FloorPlinth',(0,.045,.025),(.83,.09,.57),8,'base')
  for x in [-.32,.32]:
   for z in [-.19,.22]:
    self.beam('FloorFlange_'+str(x)+'_'+str(z),(x,.09,z),(x,.12,z),.07,2,10,'base')
    self.beam('AnchorBolt_'+str(x)+'_'+str(z),(x,.12,z),(x,.14,z),.022,0,6,'fastener')
  self.pipe('FloorConduit',[(0,.2,.12),(-.25,.2,.12),(-.25,.12,.12),(-.38,.12,.12)],.035,8)
 def rails(self,style=0):
  for x in [-.32,.32]:
   self.box('RearColumn_'+str(x),(x,.68,.18),(.085,1.08,.11),1)
   self.box('ColumnInset_'+str(x),(x,.68,.115),(.035,.82,.018),0)
   for y in [.22,1.14]:self.box('ColumnBracket_'+str(x)+'_'+str(y),(x,y,.13),(.14,.08,.19),2)
  self.box('Header',(0,1.21,.15),(.76,.10,.16),8,'cap')
  self.box('HeaderIvoryInlay',(0,1.215,.055),(.5,.055,.025),1)

def make(i):
 names=['hanging-pressure-bulb','refractory-ceramic-crucible','capillary-organ','ivory-archive-vessel','clinical-abstract-capsule','ribbed-marrow-tank','canted-supported-orbit-core','organic-valve-cage']
 k=Kit(names[i]);k.foundation();k.rails();k.control(x=.27 if i!=6 else .22)
 if i==0:
  k.lathe('PressureBulbShell',[(.37,.09),(.44,.19),(.63,.245),(.83,.21),(.99,.10),(1.08,.065)],3)
  k.parts.pop();k.stock(12,.22,.43,.58)
  k.parts[-1]['vertices']=[(x*(.58+.42*math.sin(y*math.pi)),y,z*(.58+.42*math.sin(y*math.pi))) for x,y,z in k.parts[-1]['vertices']]
  for a in [0,math.pi/2,math.pi,math.pi*1.5]:
   x,z=math.cos(a),math.sin(a);k.pipe('BulbSuspension'+str(a),[(x*.07,1.15,z*.07),(x*.26,.83,z*.26),(x*.21,.5,z*.21),(x*.09,.38,z*.09)],.025,1)
  for y,r in [(.44,.19),(.69,.25),(1.03,.095)]:k.ring('PressureBand'+str(y),(0,y,0),r,r,2,'xz',.025)
 elif i==1:
  k.lathe('RefractoryCrucible',[(.34,.10),(.43,.22),(.52,.25),(1.04,.25),(1.1,.21)],1)
  # Four open cut-away body staves, reveal broad amber stock; not opaque shell overlay.
  k.parts.pop();k.stock(6,.20,.43,.58)
  for a in [0,math.pi/2,math.pi,math.pi*1.5]:
   x,z=math.cos(a),math.sin(a);k.box('CeramicStave'+str(a),(x*.235,.76,z*.235),(.075,.57,.075),1)
  for y in [.43,1.03]:k.lathe('CrucibleCollar'+str(y),[(y,.25),(y+.09,.26)],1,role='cap')
  k.lathe('CrucibleFoot',[(.32,.08),(.43,.22)],1);k.lathe('CrucibleCrown',[(1.12,.13),(1.16,.07)],2)
 elif i==2:
  for j,x in enumerate([-.22,0,.22]):
   if j==1:
    k.parts.append({'name':'CapillaryVessel1','role':'open_central_housing'})
    for yy in [.43,1.04]:k.ring('CapillaryCenterRing'+str(yy),(0,yy,0),.16,.16,2,'xz',.018,16)
    for xx in [-.15,.15]:k.beam('CapillaryCenterRib'+str(xx),(xx,.43,0),(xx,1.06,0),.018,1,8,'open_housing_support')
   else:k.lathe('CapillaryVessel'+str(j),[(.47,.065),(.55,.085),(1.07,.085),(1.14,.045)],4,c=(x,0,0),n=10)
   k.pipe('CapillaryFeed'+str(j),[(x,.49,0),(x,.29,0),(0,.29,0)],.025,2)
   k.lathe('NeedleCrown'+str(j),[(1.12,.07),(1.24,.015)],2,c=(x,0,0),n=8)
  k.stock(13,.12,.42,.59)
  for y in [.48,1.04]:k.box('Manifold'+str(y),(0,y,-.01),(.61,.065,.16),2)
 elif i==3:
  k.stock(13,.18,.42,.62)
  k.lathe('ArchiveFoot',[(.31,.08),(.42,.21),(.47,.21)],1)
  for s in [-1,1]:
   k.pipe('ArchiveArch'+str(s),[(s*.23,.42,0),(s*.24,.96,0),(s*.13,1.18,0),(0,1.25,0)],.045,1)
   k.box('ArchivePlaque'+str(s),(s*.23,.72,-.07),(.09,.24,.06),9)
  k.lathe('ArchiveCrown',[(1.05,.19),(1.13,.13),(1.2,.05)],2)
 elif i==4:
  k.stock(5,.205,.41,.64)
  for y in [.37,1.01]:k.lathe('CapsuleCeramicCap'+str(y),[(y,.16),(y+.055,.24),(y+.13,.20)],1)
  for x in [-.235,.235]:k.box('CapsuleSpine'+str(x),(x,.75,.03),(.075,.60,.14),1)
  # Nonfigurative stacked sterile baffles; explicitly no human/infant form.
  for j in range(3):k.lathe('SterileBaffle'+str(j),[(.5+j*.16,.14),(.55+j*.16,.17)],11,n=8,role='structural_baffle')
 elif i==5:
  k.stock(3,.17,.39,.67)
  for j in range(7):
   y=.45+j*.09;k.ring('MarrowRib'+str(j),(0,y,0),.235,.19,11,'xz',.027,16)
  k.lathe('MarrowCap',[(1.06,.17),(1.13,.11),(1.17,.05)],1)
  k.lathe('MarrowDrain',[(.32,.07),(.4,.17)],2)
 elif i==6:
  # Canted body mesh baked 22deg about Z; independent stock stays vertical by contract.
  k.lathe('OrbitCore',[(.38,.08),(.46,.18),(.72,.245),(.98,.18),(1.07,.08)],4)
  p=k.parts[-1];angle=.38;p['vertices']=[(x*math.cos(angle)-(y-.72)*math.sin(angle),(y-.72)*math.cos(angle)+x*math.sin(angle)+.72,z) for x,y,z in p['vertices']]
  k.ring('SupportedOrbit',(0,.72,0),.35,.46,2,'xy',.04,24)
  for part in k.parts:
   if part['name'].startswith('SupportedOrbit'):
    part['vertices']=[(x*math.cos(-.28)-(y-.72)*math.sin(-.28),(y-.72)*math.cos(-.28)+x*math.sin(-.28)+.72,z) for x,y,z in part['vertices']]
  for x,y in [(-.27,.39),(.27,1.05)]:k.beam('OrbitBearing'+str(y),(x,y,-.07),(x,y,.16),.07,1,10)
  k.parts=[p for p in k.parts if p['name']!='OrbitCore'];k.stock(4,.21,.44,.56)
  k.parts[-1]['vertices']=[(x*(.55+.45*math.sin(y*math.pi))+.18*(y-.5),y,z*(.55+.45*math.sin(y*math.pi))) for x,y,z in k.parts[-1]['vertices']]
 elif i==7:
  k.stock(12,.19,.41,.61)
  for j in range(6):
   a=j*math.tau/6;x,z=math.cos(a),math.sin(a);k.pipe('OrganicCageRib'+str(j),[(x*.08,.35,z*.08),(x*.25,.53,z*.22),(x*.255,.83,z*.22),(x*.15,1.07,z*.15),(x*.06,1.14,z*.06)],.033,11)
  k.lathe('OrganicCollar',[(.36,.13),(.43,.18)],2)
  k.pipe('ReturnValve',[(.08,1.12,0),(.23,1.17,0),(.28,1.10,0),(.28,.89,0)],.04,8)
  k.ring('CageBelt',(0,.72,0),.27,.24,2,'xz',.025)
 # All rigs have actual drain, independent vessel cap and rear feed.
 if i in [0,6]:
  bottom=next(p['stockBounds']['bottomMeters'] for p in k.parts if p['name']=='StockVolume')
  stock=next(p for p in k.parts if p['name']=='StockVolume');base=[v for v in stock['vertices'] if v[1]==0];cx=sum(v[0] for v in base)/len(base)
  k.beam('StockDrainConnection',(0,.37,0),(cx,bottom+.015,0),.055,2,10,'drain_connection')
  k.parts[-1]['connectionEndpoints']=[[0,.37,0],[cx,bottom+.015,0]]
 k.pipe('RearFeed',[(0,.25,.15),(0,1.13,.15),(0,1.13,0)],.028,8)
 k.lathe('TopCoupling',[(1.11,.06),(1.18,.06)],2,role='cap')
 return k

def export(k):
 binary=bytearray();views=[];acc=[];meshes=[];nodes=[];meta=[]
 def accessor(data,fmt,typ,ctype):
  while len(binary)%4:binary.append(0)
  off=len(binary);flat=[n for row in data for n in row] if isinstance(data[0],(list,tuple)) else data
  binary.extend(struct.pack('<'+fmt*len(flat),*flat));vi=len(views);views.append({'buffer':0,'byteOffset':off,'byteLength':len(binary)-off})
  a={'bufferView':vi,'componentType':ctype,'count':len(data),'type':typ}
  if typ=='VEC3':a.update(min=[min(p[j] for p in data) for j in range(3)],max=[max(p[j] for p in data) for j in range(3)])
  acc.append(a);return len(acc)-1
 for p in k.parts:
  node={'name':p['name'],'extras':{'role':p['role']}}
  for attr in ['translation','scale']:
   if attr in p:node[attr]=p[attr]
  if 'stockBounds' in p:node['extras']['stockBounds']=p['stockBounds']
  if 'connectionEndpoints' in p:node['extras']['connectionEndpoints']=p['connectionEndpoints']
  if 'vertices' in p:
   pos=[];ns=[];uv=[];colors=[];idx=[];tile=p['tile'];u0=(tile%4)/4;v0=(tile//4)/4
   for face in p['faces']:
    for j in range(1,len(face)-1):
     tri=[p['vertices'][v] for v in [face[0],face[j],face[j+1]]];n=norm(cross(sub(tri[1],tri[0]),sub(tri[2],tri[0])))
     # Authored local facet values only: does not add any scene light or emission.
     shade=.63+.30*max(0,sum(a*b for a,b in zip(n,norm((-.4,.8,-.55)))))
     face_uv=[(.04,.04),(.96,.04),(.96,.96),(.04,.96)] if len(face)==4 else [(.5+.46*math.cos(q*math.tau/len(face)),.5+.46*math.sin(q*math.tau/len(face))) for q in range(len(face))]
     for v,tc in zip(tri,[face_uv[q] for q in [0,j,j+1]]):
      idx.append(len(pos));pos.append(v);ns.append(n);uv.append((u0+tc[0]/4,v0+tc[1]/4));colors.append((shade,shade,shade,1))
   attrs={'POSITION':accessor(pos,'f','VEC3',5126),'NORMAL':accessor(ns,'f','VEC3',5126),'TEXCOORD_0':accessor(uv,'f','VEC2',5126),'COLOR_0':accessor(colors,'f','VEC4',5126)}
   indices=accessor(idx,'I','SCALAR',5125);node['mesh']=len(meshes);meshes.append({'name':p['name'],'primitives':[{'attributes':attrs,'indices':indices,'material':tile}]})
   meta.append({'name':p['name'],'role':p['role'],'tileIndex':tile,'triangles':len(idx)//3,'boundsLocal':{'min':[min(v[j] for v in pos) for j in range(3)],'max':[max(v[j] for v in pos) for j in range(3)]},'translation':p.get('translation',[0,0,0]),'scale':p.get('scale',[1,1,1])})
  nodes.append(node)
 materials=[{'name':t,'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':1},'extensions':{'KHR_materials_unlit':{}},'extras':{'atlasTile':i,'paintLed':True,'facetColorAuthored':True}} for i,t in enumerate(TILES)]
 doc={'asset':{'version':'2.0','generator':'NULL CHOIR healing-kit deterministic CPU source v1'},'extensionsUsed':['KHR_materials_unlit'],'scene':0,'scenes':[{'nodes':list(range(len(nodes)))}],'nodes':nodes,'meshes':meshes,'materials':materials,'textures':[{'source':0,'sampler':0}],'samplers':[{'magFilter':9729,'minFilter':9729,'wrapS':33071,'wrapT':33071}],'images':[{'uri':'../raw/texture-atlas.png'}],'buffers':[{'byteLength':len(binary),'uri':k.name+'.bin'}],'bufferViews':views,'accessors':acc}
 (ROOT/'models'/f'{k.name}.bin').write_bytes(binary);(ROOT/'models'/f'{k.name}.gltf').write_text(json.dumps(doc,separators=(',',':')))
 del doc['buffers'][0]['uri'];js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4);binary+=b'\0'*((-len(binary))%4)
 glb=struct.pack('<III',0x46546c67,2,12+8+len(js)+8+len(binary))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(binary),0x004e4942)+binary
 (ROOT/'models'/f'{k.name}.glb').write_bytes(glb)
 (ROOT/'metadata'/f'{k.name}.json').write_text(json.dumps({'family':k.name,'units':'meters','front':'-Z','parts':meta,'useTarget':next(p['translation'] for p in k.parts if p['name']=='UseTarget'),'stock':next(p['stockBounds'] for p in k.parts if p['name']=='StockVolume')},indent=2))
 return k
if __name__=='__main__':
 for i in range(8):export(make(i))
 (ROOT/'metadata/atlas-tiles.json').write_text(json.dumps({'grid':[4,4],'indexOrigin':'top-left','uri':'../raw/texture-atlas.png','tiles':[{'index':i,'name':s} for i,s in enumerate(TILES)],'sampling':'4 percent inset within tile; no mipmap requested','facetShading':'vertex COLOR_0 authored directional value, unlit material; no physical illumination claim'},indent=2))
 print('Exported eight source/runtime geometry families; no native app invoked.')
