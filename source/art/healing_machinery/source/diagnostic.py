"""Small source-geometry painter diagnostic. NO texture/engine/lighting acceptance."""
from generate import *
from PIL import Image,ImageDraw
im=Image.new('RGB',(1280,800),'#1e252c');draw=ImageDraw.Draw(im)
for i in range(8):
 k=make(i);col=i%4;row=i//4;triangles=[]
 def project(v):x,y,z=v;return(col*320+150+(x*.86+z*.51)*230,row*400+350-y*230+(x*.17-z*.29)*230)
 for p in k.parts:
  if 'vertices' not in p:continue
  t=p.get('translation',[0,0,0]);s=p.get('scale',[1,1,1]);verts=[tuple(v[j]*s[j]+t[j] for j in range(3)) for v in p['vertices']]
  for face in p['faces']:
   for j in range(1,len(face)-1):
    vs=[verts[q] for q in [face[0],face[j],face[j+1]]];n=norm(cross(sub(vs[1],vs[0]),sub(vs[2],vs[0])));sh=.63+.30*max(0,sum(a*b for a,b in zip(n,norm((-.4,.8,-.55)))));c=COLORS[p['tile']];rgb=tuple(int(int(c[q:q+2],16)*sh) for q in [1,3,5]);depth=sum(v[0]*.51-v[2]*.86+v[1]*.27 for v in vs)/3
    triangles.append((depth,[project(v) for v in vs],rgb))
 for depth,points,rgb in sorted(triangles):draw.polygon(points,fill=rgb)
 draw.text((col*320+12,row*400+10),f'{i+1} '+k.name,fill='#e4d9be')
 draw.text((col*320+12,row*400+28),'SOURCE ONLY / flat tile swatches',fill='#b4bec4')
draw.text((12,780),'No atlas, Godot renderer, scene lighting or gameplay acceptance represented.',fill='#e4d9be')
im.save(ROOT/'diagnostics/source-geometry-only.png')
print('Saved source-only diagnostic')
