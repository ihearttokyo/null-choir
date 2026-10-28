"""Frozen portable SOURCE render convention, not an engine/import proof.

POSITION/UV and decoded NORMAL use signed half-away-from-zero at1e-4.
Source normals first pass the declared float32 octahedral UNORM16 codec;
source colors pass RGBA8 truncation. Oriented render triangles canonicalize
cyclic rotation and triangle order, never reflection. Godot4.5 source informed
this convention; target4.7.2 import/codec parity is still unrun.
"""
import math,struct,hashlib
f32=lambda x:struct.unpack('<f',struct.pack('<f',x))[0]
def quant(v):return math.floor(v*10000+.5) if v>=0 else math.ceil(v*10000-.5)
def normal_codes(n):
 # Explicit float32 octahedral encoding + UNORM16 truncation, even with mesh compression disabled.
 den=f32(f32(abs(n[0])+abs(n[1]))+abs(n[2]));x,y,z=[f32(v/den) for v in n]
 if z<0:x,y=f32((1-abs(y))*(1 if x>=0 else -1)),f32((1-abs(x))*(1 if y>=0 else -1))
 return tuple(math.floor(max(0,min(65535,f32(f32(f32(v*.5)+.5)*65535)))) for v in [x,y])
def color_codes(c):return tuple(math.floor(max(0,min(255,v*255))) for v in c)
def render_hash(pos,norm,uv,color,ids,source=True):
 records=[]
 for p,n,u,c in zip(pos,norm,uv,color):
  nc=normal_decode(normal_codes(n)) if source else n
  cc=color_codes(c) if source else c
  records.append(','.join(str(v) for v in [*(quant(v) for v in p),*(quant(v) for v in nc),*(quant(v) for v in u),*cc]))
 rows=[]
 for i in range(0,len(ids),3):
  ix=ids[i:i+3];ix=[ix[0],ix[2],ix[1]] if source else ix # declared glTF CCW→Godot CW
  t=[records[j] for j in ix];rows.append(min('|'.join(t[r:]+t[:r]) for r in range(3)))
 return hashlib.sha256('\n'.join(sorted(rows)).encode()).hexdigest()
def normal_decode(codes):
 # SOURCE simulation of the declared codec, not an observed target-engine result.
 x,y=[f32(f32(f32(code/65535)*2)-1) for code in codes]
 z=f32(f32(1-abs(x))-abs(y));t=max(0,min(1,-z));x=f32(x+(-t if x>=0 else t));y=f32(y+(-t if y>=0 else t))
 length=f32(math.sqrt(f32(f32(f32(x*x)+f32(y*y))+f32(z*z))))
 return tuple(f32(v/length) for v in [x,y,z])
