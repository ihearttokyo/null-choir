"""Source-only alternate: detailed v2 mesh rigidly aligned to its actual muzzle axis."""
import math
SIZE=(320,200)
ANCHOR=(140.,62.)
CROSSHAIR=(140.,37.)
LENS_MM=42.
SENSOR_MM=36.
FOCAL=SIZE[0]*LENS_MM/SENSOR_MM
DISTANCE=3.88
MUZZLE_PIX=(140.,62.,22.)
FIRST_BARREL_NEAR_PIX=(164.,76.,11.)
SOURCE_REL='source/art/rivet_pistol_v2.blend'
SOURCE_SHA='b29ac487f2339a7668a7207f84159ad8da4a5aca27803f5349d12ae50a57e3aa'
RECIPE_REL='tools/build_rivet_pistol_v2.py'
RECIPE_SHA='a1bd6849a6475275c723c927ef5c1de5013505c7c0086f04470e8cd0be10a710'
HELPER_SHA='07c35732461226ee786f7f3f50b0617c5acf90368b8cd8668b6c996e13b45c5a'
POSES=('idle','fire','recover')


def add(a,b):return tuple(x+y for x,y in zip(a,b))
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def scale(a,t):return tuple(x*t for x in a)
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return(a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def unit(a):return scale(a,1/math.sqrt(dot(a,a)))
def world(p):return(p[0]/80,p[2]/80,(200-p[1])/80)
M=world(MUZZLE_PIX)
A=unit(sub(M,world(FIRST_BARREL_NEAR_PIX)))
U=unit(sub((0,0,1),scale(A,A[2])))
R=unit(cross(A,U))
# Rows R,A,U form a proper rigid rotation (det+1); no scale/shear/warp.
ROWS=(R,A,U)
SLOPE=(ANCHOR[1]-CROSSHAIR[1])/FOCAL
EYE=(0,-DISTANCE,DISTANCE*SLOPE)
FORWARD=unit(scale(EYE,-1))
RIGHT=unit(cross(FORWARD,(0,0,1)))
UP=cross(RIGHT,FORWARD)


def rigid(p):return tuple(dot(sub(p,M),b)for b in ROWS)
def rigid_pixel(p):return rigid(world(p))
def project_direction(q):
 depth=dot(q,FORWARD)
 if depth<=0:raise ValueError('Behind camera')
 return(ANCHOR[0]+FOCAL*dot(q,RIGHT)/depth,ANCHOR[1]-FOCAL*dot(q,UP)/depth)
def project(p):return project_direction(sub(p,EYE))
def project_pixel(p):return project(rigid_pixel(p))


def receipt():
 return {'scope':'Analytic alternate from genuine detailed source recipe; no native open/render yet',
  'source_rel':SOURCE_REL,'source_sha256':SOURCE_SHA,'recipe_sha256':RECIPE_SHA,
  'actual_first_barrel_world_axis':A,'rigid_rotation_rows':ROWS,'original_world_muzzle':M,
  'proper_rigid_determinant':dot(R,cross(A,U)),
  'canonical_camera':{'eye':EYE,'aim':[0,0,0],'lens_mm':LENS_MM,'sensor_width_mm':SENSOR_MM,'shift_x':.5-140/320,'shift_y':(62-100)/320},
  'idle_muzzle_local_px':project((0,0,0)),
  'idle_forward_vanishing_local_px':project_direction((0,1,0)),
  'source_landmarks_local_px':{n:project_pixel(p)for n,p in {'rear_cap':(250,129,-4),'palm':(244,159,-8),'thumb':(228,147,-17),'wrist_medallion':(256,171,-25),'forearm_center':(270,192,3)}.items()},
  'limit':'Camera/rigid math only. Source/native material, topology match, occlusion, grip and raster acceptance not established.'}
