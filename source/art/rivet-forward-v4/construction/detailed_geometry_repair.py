"""One bounded, original-geometry repair hypothesis; pure geometry, no engine imports."""
import math
import camera_model_detailed as c
REVISION='closed-breech-supported-dorsal-sight01'
RETIRED_PART='Rear cap black inset'
MODIFIED_PART='Low bone sight'
SIGHT_TOP_Z=.220
ADDITIONS=('Closed octagonal breech backplate','Shallow breech locking bar','Breech planar lock seam','Breech fastener upper','Breech fastener lower','Continuous slender dorsal sight rib','Forward dorsal sight rib support')


def part(name,verts,faces,material_source):return{'name':name,'vertices':verts,'faces':faces,'material_source':material_source}

def extrusion(name,outline,y_near,y_far,material_source):
 n=len(outline);v=[(x,y,z)for y in[y_near,y_far]for x,z in outline]
 f=[tuple(range(n)),tuple(reversed(range(n,2*n)))]+[(i,(i+1)%n,(i+1)%n+n,i+n)for i in range(n)]
 return part(name,v,f,material_source)

def octagon(name,center,width,height,depth,material_source):
 x,y,z=center;rx,rz=width/2,height/2;ch=min(rx,rz)*.28
 outline=[(x-rx+ch,z-rz),(x+rx-ch,z-rz),(x+rx,z-rz+ch),(x+rx,z+rz-ch),(x+rx-ch,z+rz),(x-rx+ch,z+rz),(x-rx,z+rz-ch),(x-rx,z-rz+ch)]
 return extrusion(name,outline,y-depth/2,y+depth/2,material_source)

def box(name,center,width,height,depth,material_source):
 x,y,z=center;return extrusion(name,[(x-width/2,z-height/2),(x+width/2,z-height/2),(x+width/2,z+height/2),(x-width/2,z+height/2)],y-depth/2,y+depth/2,material_source)

def tube(name,points,radius,material_source,sides=10):
 v=[];f=[]
 for j,p in enumerate(points):
  axis=c.unit(c.sub(points[min(j+1,len(points)-1)],points[max(j-1,0)]));u=c.cross(axis,(0,0,1))
  if c.dot(u,u)<1e-6:u=c.cross(axis,(1,0,0))
  u=c.unit(u);w=c.cross(axis,u)
  for i in range(sides):v.append(c.add(p,c.add(c.scale(u,radius*math.cos(math.tau*i/sides)),c.scale(w,radius*math.sin(math.tau*i/sides)))))
  if j:
   for i in range(sides):a=(j-1)*sides+i;b=(j-1)*sides+(i+1)%sides;f.append((a,b,b+sides,a+sides))
 f.extend([tuple(reversed(range(sides))),tuple(range(len(v)-sides,len(v)))])
 return part(name,v,f,material_source)

def inverse_rigid(p):return c.add(c.M,c.add(c.scale(c.R,p[0]),c.add(c.scale(c.A,p[1]),c.scale(c.U,p[2]))))

def repair_parts():
 x,y,z=c.rigid_pixel((250,129,-4));face=y-.055
 rows=[octagon(ADDITIONS[0],(x,y-.0275,z),.260,.250,.055,'Short rear brass cap'),
       box(ADDITIONS[1],(x,face-.004,z),.150,.022,.008,'Muzzle black steel barrel'),
       box(ADDITIONS[2],(x,face-.0085,z),.075,.004,.002,'Carved cheek groove 0'),
       octagon(ADDITIONS[3],(x-.087,face-.003,z+.073),.026,.026,.006,'Receiver bolt 0'),
       octagon(ADDITIONS[4],(x+.087,face-.003,z-.073),.026,.026,.006,'Receiver bolt 0')]
 points=[(x,face+.020,z+.120),(.240,-1.55,.100),(.200,-1.44,.200),(.020,-1.00,.200),(0,-.780,.200),(0,-.146,.200)]
 rows.append(tube(ADDITIONS[5],points,.0125,'Worn band edge 0'))
 rows.append(tube(ADDITIONS[6],[(-.015,-.379,.135),(0,-.379,.200)],.0125,'Muzzle receiver band 2'))
 return rows

def raise_sight(points):
 canonical=[c.rigid(p)for p in points];lo=min(p[2]for p in canonical);hi=max(p[2]for p in canonical)
 if not .06<lo<.08 or not .15<hi<.17:raise ValueError('Actual original sight bounds drift')
 return[inverse_rigid((x,y,lo+(z-lo)*(SIGHT_TOP_Z-lo)/(hi-lo)))for x,y,z in canonical]
