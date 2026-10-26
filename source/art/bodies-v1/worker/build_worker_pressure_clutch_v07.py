"""Editable Worker art pilot. PREPARED ONLY: native execution needs parent serial grant.

No runtime mechanics, atlas labels, imported art or image-plane stand-ins. All pixels
come from original volumetric meshes. Default saves five articulated pose collections
and renders NOTHING. `--mode proof` renders exactly idle/front/128px. The worker-only 48-cell six-row
matrix is separately guarded, never a prerequisite for the cheap first proof.
"""
import argparse
import hashlib
import json
import math
import pathlib
import struct
import sys
import zlib

BASE_POSES = ('idle', 'walk_a', 'walk_b', 'attack', 'dead')
POSES = BASE_POSES + ('clutch_vent',)
CELL = 128
ORTHO = 3.65
FOOT_Y = 119
ANCHOR = (64, 120)
REFERENCE_SHA = '5ca36c68dd5e662b90316484591629037d9380e4f2cca223277e23f1cc29b52f'
OWNED = pathlib.Path(__file__).resolve().parent
PALETTE = {
    'ivory': ('Aged ivory ceramic planes', (0.72, 0.58, 0.39, 1)),
    'ivory_edge': ('Worn warm ivory edges', (0.88, 0.76, 0.55, 1)),
    'iron': ('Petrol forged iron', (0.13, 0.21, 0.22, 1)),
    'steel': ('Worn cool joint steel', (0.30, 0.39, 0.39, 1)),
    'brass': ('Restrained aged brass structure', (0.53, 0.34, 0.13, 1)),
    'recess': ('Soot cloth and empty hood recess', (0.045, 0.042, 0.038, 1)),
    'burgundy': ('Dark red load-bearing bellows', (0.27, 0.10, 0.085, 1)),
    'amber': ('Amber compression clutch glass', (0.88, 0.42, 0.055, 1)),
    'upper_ivory': ('Broad time-worn upper ceramic planes', (0.91, 0.82, 0.65, 1)),
    'upper_steel': ('Broad forged working-arm steel planes', (0.52, 0.61, 0.58, 1)),
    'exhaust': ('Opaque stepped pressure exhaust', (0.68, 0.66, 0.55, 1)),
    'amber_edge': ('Warm clutch pressure highlight', (1.0, 0.67, 0.17, 1)),
}
# Coordinates: original geometry fronts -Y. Physical tool arm is ALWAYS -X;
# cameras orbit the SAME asymmetric model, rather than mirroring any image.
POSE_DATA = {
 'idle': dict(pelvis=(0, .04, 1.35), chest=(0, 0, 2.05), lean=0,
   legs=[(-.30,.02,1.30,-.38,.01,.75,-.39,0,.18),(.30,.02,1.30,.38,.04,.75,.39,.02,.18)],
   tool=[(-.58,0,2.43),(-.95,-.48,2.22),(-1.14,-.98,1.91)],
   free=[(.58,0,2.43),(.73,.04,1.94),(.73,-.16,1.43)]),
 'walk_a': dict(pelvis=(.045,0,1.31), chest=(.02,-.04,2.01), lean=.055,
   legs=[(-.27,0,1.27,-.38,-.31,.72,-.42,-.45,.18),(.33,0,1.27,.39,.32,.77,.43,.43,.18)],
   tool=[(-.56,-.04,2.39),(-.94,-.48,2.08),(-1.13,-.92,1.73)],
   free=[(.60,-.04,2.39),(.78,.13,1.90),(.79,.18,1.36)]),
 'walk_b': dict(pelvis=(-.045,0,1.31), chest=(-.02,-.04,2.01), lean=.055,
   legs=[(-.33,0,1.27,-.39,.32,.77,-.43,.43,.18),(.27,0,1.27,.38,-.31,.72,.42,-.45,.18)],
   tool=[(-.60,-.04,2.39),(-.98,-.44,2.07),(-1.17,-.88,1.72)],
   free=[(.56,-.04,2.39),(.70,-.19,1.95),(.67,-.35,1.46)]),
 'attack': dict(pelvis=(.13,.10,1.18), chest=(.04,-.24,1.91), lean=.15,
   legs=[(-.16,.10,1.18,-.55,-.21,.64,-.65,-.37,.18),(.42,.10,1.18,.59,.24,.68,.66,.40,.18)],
   tool=[(-.53,-.24,2.32),(-.98,.02,2.29),(-1.23,-.58,2.35)],
   free=[(.61,-.24,2.32),(.84,-.11,1.91),(.48,-.57,1.69)]),
 # A genuinely bent/fallen articulated body, NOT a Z-scaled standing silhouette.
 'clutch_vent': dict(pelvis=(.10,.13,1.16), chest=(.02,-.22,1.72), lean=.25,
   legs=[(-.18,.13,1.16,-.53,-.19,.63,-.63,-.32,.18),(.38,.13,1.16,.56,.26,.65,.66,.39,.18)],
   tool=[(-.62,-.24,2.10),(-.94,-.60,1.76),(-1.0,-.96,1.21)],
   free=[(.60,-.22,2.13),(.78,-.43,1.86),(.08,-.78,1.77)]),
 'dead': dict(pelvis=(0,0,1.20), chest=(.06,0,1.91), lean=.08,
   legs=[(-.28,0,1.20,-.60,-.07,.67,-.70,-.14,.18),(.28,0,1.20,.59,.38,.72,.44,.60,.18)],
   tool=[(-.52,0,2.32),(-.95,.15,1.80),(-1.22,.04,1.42)],
   free=[(.64,0,2.32),(.96,-.22,1.98),(1.18,-.30,1.62)]),
}


TOOL_UPPER_LENGTH = math.dist((-0.58,0,2.43),(-0.94,-0.02,1.96))
TOOL_CORE_LENGTH = math.dist((-0.94,-0.02,1.96),(-0.88,-0.22,1.42))

def normalized_tool(chain):
    # Fixed physical segment lengths, including fallen and depressurized poses.
    # Preserve each authored shoulder and proximal/distal force-line direction.
    shoulder,old_elbow,old_wrist=chain
    def advance(a,b,length):
        delta=tuple(b[i]-a[i] for i in range(3));norm=math.sqrt(sum(x*x for x in delta))
        assert norm>.1
        return tuple(a[i]+delta[i]*length/norm for i in range(3))
    elbow=advance(shoulder,old_elbow,TOOL_UPPER_LENGTH)
    distal_target=tuple(elbow[i]+old_wrist[i]-old_elbow[i] for i in range(3))
    wrist=advance(elbow,distal_target,TOOL_CORE_LENGTH)
    return (shoulder,elbow,wrist)


def sha(path):
    with pathlib.Path(path).open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def parse_cells(value):
    cells=[]
    for item in value.split(','):
        parts=item.split(':')
        if len(parts)!=2 or parts[0] not in POSES or parts[1] not in tuple(str(n) for n in range(8)):
            raise argparse.ArgumentTypeError('Expected exact pose:direction, direction0–7')
        cell=(parts[0],int(parts[1]))
        if cell in cells:raise argparse.ArgumentTypeError('Duplicate selected cell')
        cells.append(cell)
    if not 1<=len(cells)<=4:raise argparse.ArgumentTypeError('Selected proof accepts1–4 unique cells only')
    return cells


def selected_frames(args):
    if args.mode=='proof':return [('idle',0)]
    if args.mode=='selected':return args.cells
    if args.mode=='atlas':return [(p,c) for p in POSES for c in range(8)]
    return []


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=pathlib.Path)
    parser.add_argument('--mode', choices=('source', 'proof', 'selected', 'atlas'), default='source')
    parser.add_argument('--cells', type=parse_cells, help='Selected proof only: pose:direction comma list, max4 unique actual cells')
    parser.add_argument('--approved-directional-matrix', action='store_true')
    parser.add_argument('--export-idle-glb', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    args.output = args.output.resolve()
    assert args.output.is_relative_to(OWNED) and args.output != OWNED, 'R-only new output subfolder required'
    assert not args.output.exists(), 'Never overwrite a source/proof; choose a fresh pilot output'
    if args.mode == 'selected':
        assert args.cells and len(args.cells)<=4, 'Selected proof requires1–4 explicit unique cells'
    else:
        assert args.cells is None, '--cells is only valid with --mode selected'
    if args.mode == 'atlas':
        assert args.approved_directional_matrix, 'Full directional matrix is held until separate explicit parent approval'
    assert sha(OWNED/'worker-pressure-clutch-reference01.png') == REFERENCE_SHA
    return args


class Builder:
    def __init__(self, bpy, Vector, Matrix):
        self.bpy, self.V, self.Matrix = bpy, Vector, Matrix
        self.materials = {}
        self.pose_collections = {}
        self.anatomy_collections = {}
        self.material_collections = {}
        self.group = self.pose = None
        self.objects = []

    def setup(self):
        bpy = self.bpy
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.preferences.filepaths.save_version = 0
        scene = bpy.context.scene
        # Cheap studio raster ONLY. No Cycles, compute device, baking, compositing,
        # external textures, denoising, bloom, motion blur or GPU-compute setup.
        scene.render.engine = 'BLENDER_WORKBENCH'
        scene.render.threads_mode = 'FIXED'
        scene.render.threads = 2
        scene.render.film_transparent = True
        scene.render.resolution_x = scene.render.resolution_y = CELL
        scene.render.resolution_percentage = 100
        scene.render.image_settings.file_format = 'PNG'
        scene.render.image_settings.color_mode = 'RGBA'
        scene.display.render_aa = 'OFF'
        shading = scene.display.shading
        shading.light = 'STUDIO'
        shading.studio_light = 'paint.sl'
        shading.color_type = 'MATERIAL'
        shading.show_shadows = True
        shading.show_cavity = True
        shading.cavity_type = 'BOTH'
        shading.curvature_ridge_factor = 1.0
        shading.curvature_valley_factor = .65
        shading.cavity_ridge_factor = 1.0
        shading.cavity_valley_factor = .65
        shading.show_specular_highlight = True
        scene.view_settings.view_transform = 'Standard'
        scene.view_settings.look = 'None'
        scene.world = bpy.data.worlds.new('Source world (transparent raster)')
        scene.world.color = (.15,.15,.15)
        for key, (name, color) in PALETTE.items():
            mat = bpy.data.materials.new(name)
            mat.diffuse_color = color
            mat.use_nodes = True
            node = mat.node_tree.nodes.get('Principled BSDF')
            node.inputs['Base Color'].default_value = color
            node.inputs['Roughness'].default_value = .76
            node.inputs['Metallic'].default_value = .35 if key in ('iron','steel','brass') else 0
            # Workbench does not use an emission cheat. Amber is a material plane.
            self.materials[key] = mat
        scene['pilot_reference_sha256'] = REFERENCE_SHA
        scene['mechanics_changed'] = False
        scene['damage_region_labels_authored'] = False
        scene['pixel_contract'] = '128cell; ortho3.65; anchor64,120; occupied bottom119'
        scene['construction'] = 'Original solid geometry; no image cards, no mirrored asymmetric cells'
        self.scene = scene
        return scene

    def collection(self, name, parent):
        coll = self.bpy.data.collections.new(name)
        parent.children.link(coll)
        return coll

    def begin_pose(self, name):
        self.pose = name
        coll = self.collection('Pose_'+name, self.scene.collection)
        coll['row'] = POSES.index(name)
        coll['articulation'] = 'Named pivot empties; rotate proximal joint to carry child chain'
        self.pose_collections[name] = coll
        self.anatomy_collections = {}
        self.material_collections = {}
        self.anatomy_root = self.collection(name+'/Anatomical assemblies', coll)
        self.material_root = self.collection(name+'/Material groups', coll)
        return self.pivot('GroundRoot', (0,0,0), None)

    def register(self, obj, group, material=None):
        bpy = self.bpy
        obj.name = self.pose+'/'+obj.name
        if group not in self.anatomy_collections:
            self.anatomy_collections[group] = self.collection(self.pose+'/'+group, self.anatomy_root)
        for coll in list(obj.users_collection):
            coll.objects.unlink(obj)
        self.anatomy_collections[group].objects.link(obj)
        obj['anatomical_assembly'] = group
        if material:
            obj.data.materials.append(self.materials[material])
            obj['material_group'] = material
            if material not in self.material_collections:
                self.material_collections[material] = self.collection(self.pose+'/Material_'+material,self.material_root)
            self.material_collections[material].objects.link(obj)
        self.objects.append(obj)
        return obj

    def pivot(self, name, position, parent=None):
        obj = self.bpy.data.objects.new(name, None)
        self.scene.collection.objects.link(obj)
        obj.empty_display_type = 'SPHERE'
        obj.empty_display_size = .065
        obj.location = position
        self.register(obj, 'Articulation pivots')
        obj['editable_joint'] = True
        if parent:
            # Preserve authored world position when parenting the kinematic chain.
            obj.parent = parent
            obj.matrix_parent_inverse = parent.matrix_world.inverted()
        self.bpy.context.view_layer.update()
        return obj

    def parent_world(self, obj, parent):
        if parent:
            self.bpy.context.view_layer.update()
            obj.parent = parent
            obj.matrix_parent_inverse = parent.matrix_world.inverted()
        return obj

    def finish(self, obj, name, group, material, parent=None):
        obj.name = name
        self.register(obj, group, material)
        self.parent_world(obj,parent)
        return obj

    def ellipsoid(self,name,pos,scale,mat,group,parent=None):
        self.bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,location=pos)
        obj=self.bpy.context.object;obj.scale=scale
        return self.finish(obj,name,group,mat,parent)

    def box(self,name,pos,size,mat,group,parent=None,bevel=.025):
        bpy=self.bpy
        bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
        obj=bpy.context.object;obj.scale=size
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        if bevel:
            m=obj.modifiers.new('Editable broad edge chamfer','BEVEL');m.width=bevel;m.segments=1
            # Keep modifier editable in the saved source.
        return self.finish(obj,name,group,mat,parent)

    def mesh(self,name,vertices,faces,mat,group,parent=None):
        data=self.bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
        obj=self.bpy.data.objects.new(name,data);self.scene.collection.objects.link(obj)
        return self.finish(obj,name,group,mat,parent)

    def tube(self,name,points,radii,mat,group,parent=None,sides=8):
        p=[self.V(v) for v in points]
        r=[radii]*len(p) if isinstance(radii,(int,float)) else radii
        verts=[];faces=[]
        for i,v in enumerate(p):
            tangent=(p[min(i+1,len(p)-1)]-p[max(i-1,0)]).normalized()
            axis=self.V((0,0,1)) if abs(tangent.z)<.9 else self.V((1,0,0))
            u=tangent.cross(axis).normalized();w=tangent.cross(u).normalized()
            for j in range(sides):
                a=j*math.tau/sides;verts.append(v+r[i]*(u*math.cos(a)+w*math.sin(a)))
            if i:
                for j in range(sides):
                    a=(i-1)*sides+j;b=(i-1)*sides+(j+1)%sides
                    faces.append((a,b,b+sides,a+sides))
        faces.extend([tuple(reversed(range(sides))),tuple(range((len(p)-1)*sides,len(p)*sides))])
        return self.mesh(name,verts,faces,mat,group,parent)

    def plate(self,name,outline,y,depth,mat,group,parent=None,transform=None):
        area=sum(outline[i][0]*outline[(i+1)%len(outline)][1]-outline[(i+1)%len(outline)][0]*outline[i][1] for i in range(len(outline)))
        if area<0:outline=list(reversed(outline))
        vertices=[(x,y+d,z) for d in (0,depth) for x,z in outline]
        if transform:
            vertices=[transform@self.V(v) for v in vertices]
        n=len(outline)
        faces=[tuple(range(n)),tuple(reversed(range(n,n*2)))]
        faces.extend((i,i+n,(i+1)%n+n,(i+1)%n) for i in range(n))
        return self.mesh(name,vertices,faces,mat,group,parent)

    def clutch_housing(self,T,chest):
        # Thick cast pressure receiver with an open deep bevel and recessed dome.
        # The whole circumference is an actual closed 3D annular cross-section.
        profile=[(.39,-.30),(.415,-.44),(.36,-.66),(.265,-.66),(.245,-.51),(.285,-.32)]
        verts=[T((math.sin(i*math.tau/16)*rad,y,.02+math.cos(i*math.tau/16)*rad)) for rad,y in profile for i in range(16)]
        faces=[(ring*16+i,ring*16+(i+1)%16,((ring+1)%len(profile))*16+(i+1)%16,((ring+1)%len(profile))*16+i) for ring in range(len(profile)) for i in range(16)]
        faces=[tuple(reversed(face)) for face in faces] # Outward normals on the receiver cavity/cast walls.
        obj=self.mesh('Deep open cast clutch receiver',verts,faces,'iron','Amber compression clutch',chest)
        for key in ('upper_steel','upper_ivory','recess'):obj.data.materials.append(self.materials[key])
        for face in obj.data.polygons:
            section=face.index//16
            face.material_index={0:0,1:1,2:2,3:3,4:0,5:0}[section]
        self.ellipsoid('Recessed convex amber pressure chamber',T((0,-.52,.02)),(.245,.105,.265),'amber','Amber compression clutch',chest)
        # One broad iron valve bridge and a bright chamfer, not dense ornament.
        self.tube('Clutch offset pressure bridge',[T((.095,-.655,-.27)),T((.095,-.655,.30))],.043,'iron','Amber compression clutch',chest,6)
        self.tube('Clutch chamber curved light plane',[T((-.15,-.60,-.08)),T((-.16,-.605,.12))],.042,'amber_edge','Amber compression clutch',chest,6)
        self.tube('Attached shoulder feed neck',[T((-.30,-.30,.27)),T((-.42,-.34,.43)),T((-.49,-.15,.47))],.085,'brass','Amber compression clutch',chest,8)
        self.tube('Upper pressure release outlet',[T((.30,-.32,.23)),T((.44,-.38,.30))],.095,'upper_steel','Amber compression clutch',chest,8)
        if self.pose=='clutch_vent':
            # Actual opened valve and three large stepped solid plume lobes;
            # a second state silhouette, not an attack frame or red hurt tint.
            self.tube('Opened pressure release stem',[T((.44,-.38,.30)),T((.56,-.40,.39))],.065,'recess','Vented pressure state',chest,8)
            for i,(position,scale) in enumerate([((.60,-.40,.42),(.16,.12,.14)),((.82,-.41,.56),(.21,.13,.18)),((1.06,-.40,.68),(.18,.13,.15))]):
                self.ellipsoid('Stepped visible pressure exhaust_%02d'%i,T(position),scale,'exhaust','Vented pressure state',chest)

    def collar(self,name,a,b,radius,thickness,mat,group,parent=None):
        center=(self.V(a)+self.V(b))*.5;axis=(self.V(b)-self.V(a)).normalized()
        return self.tube(name,[center-axis*thickness*.5,center+axis*thickness*.5],radius,mat,group,parent,12)

    def ring(self,name,center,normal,radius,thickness,mat,group,parent=None):
        axis=self.V(normal).normalized();u=axis.cross(self.V((0,0,1))).normalized()
        if u.length<.1:u=self.V((1,0,0))
        v=axis.cross(u).normalized();center=self.V(center)
        points=[center+radius*(u*math.cos(i*math.tau/16)+v*math.sin(i*math.tau/16)) for i in range(17)]
        return self.tube(name,points,thickness,mat,group,parent,6)

    def limb(self,name,a,b,radius,mat,group,parent):
        a=self.V(a);b=self.V(b)
        self.tube(name,[a,a.lerp(b,.22),a.lerp(b,.77),b],
                  [radius*.8,radius,radius*.84,radius*.62],mat,group,parent)

    def body(self, name):
        d=POSE_DATA[name];root=self.begin_pose(name)
        pelvis=self.pivot('Pelvis',d['pelvis'],root)
        chest=self.pivot('Chest',d['chest'],pelvis)
        # Body construction uses one shared upright local template, posed in 3D.
        rotation=self.Matrix.Rotation(d['lean'],4,'X')
        transform=self.Matrix.Translation(self.V(d['chest']))@rotation
        T=lambda p:transform@self.V(p)
        self.ellipsoid('Pelvis iron cradle',self.V(d['pelvis'])+self.V((0,.06,0)),(.43,.37,.27),'iron','Pelvis',pelvis)
        self.box('Broad sacral block',self.V(d['pelvis'])+self.V((0,.14,0)),(.56,.24,.30),'ivory','Pelvis',pelvis)
        self.ellipsoid('Solid bellows torso',T((0,.12,-.05)),(.43,.44,.49),'burgundy','Torso',chest)
        # Three structural collars replace the old seven bright rib-stripe ladder.
        for i,z in enumerate((-.32,-.17,-.02)):
            self.ring('Structural torso girdle_%02d'%i,T((0,.06,z)),rotation.to_3x3()@self.V((0,0,1)),.30,.045,'iron','Torso',chest)
        for side in (-1,1):
            outline=[(side*.08,-.16),(side*.46,-.22),(side*.63,.20),(side*.43,.49),(side*.13,.39)]
            self.plate('Ivory chest mantle_%s'%side,outline,-.21,.48,'upper_ivory','Torso',chest,transform)
            # Sculpted load-bearing shoulder cap, broad planes and purposeful chips.
            shoulder_outline=([(side*.32,.18),(side*.84,.13),(side*.92,.30),(side*.72,.57),(side*.41,.55)] if side<0 else [(side*.34,.19),(side*.69,.13),(side*.79,.30),(side*.67,.49),(side*.41,.50)])
            self.plate('Ceramic shoulder canopy_%s'%side,shoulder_outline,-.19,.60,'upper_ivory','Shoulders',chest,transform)
        self.ellipsoid('Rear pressure reservoir',T((-.10,.48,.02)),(.34,.25,.43),'iron','Back pressure equipment',chest)
        self.box('Rear amber pressure tank',T((-.14,.68,.03)),(.35,.20,.51),'brass','Back pressure equipment',chest)
        self.tube('Back pressure spine',[T((.18,.68,-.36)),T((.18,.69,.36))],.085,'steel','Back pressure equipment',chest)
        self.clutch_housing(T,chest)
        head=self.pivot('Neck / faceless hood',T((0,0,.57)),chest)
        self.hood(T,transform,head)
        # Solid split devotional apron, deliberately large shapes, not fine filigree.
        apron_transform=self.Matrix.Translation(self.V(d['pelvis']))
        for side in (-1,1):
            self.plate('Split ivory apron_%s'%side,
                       [(side*.04,.10),(side*.27,.14),(side*.43,-.30),(side*.18,-.67),(side*.07,-.51)],
                       -.32,.09,'ivory','Pelvis',pelvis,apron_transform)
        self.legs(d,pelvis)
        self.arms(d,chest)
        if name=='dead':
            # Fall the complete articulated chain, with separately bent/sprawled
            # joints, then seat actual geometry on ground. Never squash Z.
            root.rotation_euler.x=math.pi/2
            root.location.y=1.52
            self.bpy.context.view_layer.update()
            meshes=[o for o in self.pose_collections[name].all_objects if o.type=='MESH']
            minimum=min((o.matrix_world@self.V(v)).z for o in meshes for v in o.bound_box)
            root.location.z-=minimum
            self.bpy.context.view_layer.update()
        root['pose_name']=name
        root['pose_semantics']='Existing row only; no animation timing or combat behavior changed'
        return root

    def hood(self,T,transform,chest):
        # Focused side-height fix: shorten ONLY the upper0.39m hood cap by0.08m.
        # Preserve all lower-body geometry, camera/ortho, foot registration and rim thickness.
        base_T=T
        def cap_z(z):return z-.08*max(0,z-.90)/.39
        T=lambda p:base_T((p[0],p[1],cap_z(p[2])))
        def hood_plate(name,outline,*args):
            return self.plate(name,[(x,cap_z(z)) for x,z in outline],*args)
        # Thick open Gothic hood: no face/eyes/flat-card stand-in. Black rear cavity
        # plus separate outer piers and pointed crown retain side/rear volume.
        hood_plate('Deep faceless hood cavity',[(-.23,.50),(-.24,.92),(0,1.14),(.24,.92),(.23,.50)],
                   -.13,.29,'recess','Head and faceless hood',chest,transform)
        left=[(-.36,.46),(-.36,.95),(-.23,1.17),(0,1.29),(0,1.14),(-.16,1.00),(-.20,.89),(-.20,.48)]
        right=[(-x,z) for x,z in reversed(left)]
        hood_plate('Ivory hood left pier',left,-.34,.43,'upper_ivory','Head and faceless hood',chest,transform)
        hood_plate('Ivory hood right pier',right,-.34,.43,'upper_ivory','Head and faceless hood',chest,transform)
        self.tube('Hood crown brass ridge',[T((0,-.32,1.28)),T((0,.07,1.25)),T((0,.15,.74))],.035,'brass','Head and faceless hood',chest)
        self.tube('Thick left mantle hose',[T((-.26,.09,.89)),T((-.46,.25,.75)),T((-.47,.30,.40))],.072,'iron','Back pressure equipment',chest)
        self.tube('Thick right mantle hose',[T((.26,.09,.89)),T((.46,.25,.75)),T((.47,.30,.40))],.072,'iron','Back pressure equipment',chest)

    def legs(self,d,pelvis):
        for side,values in zip((-1,1),d['legs']):
            hip=self.V(values[:3]);knee=self.V(values[3:6]);ankle=self.V(values[6:])
            upper=self.pivot('Hip_'+str(side),hip,pelvis)
            lower=self.pivot('Knee_'+str(side),knee,upper)
            foot=self.pivot('Ankle_'+str(side),ankle,lower)
            self.limb('Load-bearing thigh_'+str(side),hip,knee,.18,'burgundy','Legs',upper)
            self.limb('Thigh ceramic rail_'+str(side),hip+self.V((side*.08,-.12,0)),knee+self.V((side*.06,-.11,0)),.105,'ivory','Legs',upper)
            self.ellipsoid('Large knee bearing_'+str(side),knee,(.18,.16,.16),'iron','Legs',lower)
            self.ellipsoid('Knee bearing cap_'+str(side),knee+self.V((0,-.12,0)),(.105,.07,.105),'steel','Legs',lower)
            self.limb('Solid shin housing_'+str(side),knee,ankle,.145,'iron','Legs',lower)
            self.limb('Broad ivory shin plane_'+str(side),knee+self.V((0,-.13,-.13)),ankle+self.V((0,-.13,.10)),.13,'ivory_edge','Legs',lower)
            self.box('Grounded broad boot_'+str(side),ankle+self.V((0,-.12,-.07)),(.39,.62,.22),'iron','Feet',foot,.045)
            self.box('Ivory toe cap_'+str(side),ankle+self.V((0,-.31,-.025)),(.36,.25,.20),'ivory','Feet',foot,.045)

    def arms(self,d,chest):
        shoulder,elbow,wrist=[self.V(v) for v in normalized_tool(d['tool'])]
        s=self.pivot('Tool shoulder (-X)',shoulder,chest)
        e=self.pivot('Tool elbow',elbow,s)
        w=self.pivot('Tool wrist / barrel axis',wrist,e)
        self.limb('Thick riveter upper arm',shoulder,elbow,.23,'burgundy','Rivet working arm',s)
        self.ellipsoid('Tool shoulder iron ball',shoulder,(.28,.26,.27),'iron','Rivet working arm',s)
        self.limb('Outer arm reinforcement',shoulder+self.V((-.12,.05,.01)),elbow+self.V((-.10,.05,0)),.145,'upper_ivory','Rivet working arm',s)
        self.ellipsoid('Large riveter elbow joint',elbow,(.245,.22,.22),'upper_steel','Rivet working arm',e)
        axis=(wrist-elbow).normalized();muzzle=wrist+axis*.32
        self.tube('Heavy cylindrical rivet barrel',[elbow+axis*.06,wrist,muzzle], [.235,.205,.105],'upper_steel','Rivet working arm',e,12)
        for i,t in enumerate((.15,.76)):
            p=elbow.lerp(wrist,t)
            self.collar('Rivet pressure collar_%02d'%i,p-axis*.035,p+axis*.035,.25,.09,'brass' if i==1 else 'iron','Rivet working arm',e)
        self.collar('Muzzle iron rim',muzzle-axis*.04,muzzle,.13,.07,'upper_steel','Rivet working arm',w)
        self.tube('Rivet dark bore',[muzzle,muzzle+axis*.012],.070,'recess','Rivet working arm',w,12)
        self.tube('Short solid rivet tip',[muzzle+axis*.012,muzzle+axis*.11], [.035,.013],'brass','Rivet working arm',w,6)
        # An authored curved hose follows the posed arm, not a texture scribble.
        self.tube('Working arm pressure hose',[shoulder+self.V((0,.18,0)),elbow+self.V((-.18,.24,0)),wrist+self.V((-.12,.12,.07))],.065,'burgundy','Rivet working arm',e)
        shoulder,elbow,wrist=[self.V(v) for v in d['free']]
        s=self.pivot('Free shoulder',shoulder,chest)
        e=self.pivot('Free elbow',elbow,s)
        w=self.pivot('Free wrist',wrist,e)
        self.limb('Support upper arm',shoulder,elbow,.135,'burgundy','Free maintenance arm',s)
        self.limb('Support forearm',elbow,wrist,.105,'iron','Free maintenance arm',e)
        self.ellipsoid('Free elbow bearing',elbow,(.14,.14,.14),'steel','Free maintenance arm',e)
        self.box('Broad articulated palm',wrist,(.18,.17,.22),'iron','Free maintenance arm',w)
        for i in (-1,0,1):
            self.tube('Maintenance claw_%s'%i,[wrist+self.V((i*.065,-.02,-.08)),wrist+self.V((i*.08,-.10,-.26)),wrist+self.V((i*.075,-.17,-.22))],[.035,.032,.018],'brass','Free maintenance arm',w,6)

    def camera(self):
        data=self.bpy.data.cameras.new('Registered 128px orthographic camera')
        obj=self.bpy.data.objects.new('Registered 128px orthographic camera',data)
        self.scene.collection.objects.link(obj)
        data.type='ORTHO';data.ortho_scale=ORTHO;data.lens=50
        self.scene.camera=obj;self.cam=obj
        self.set_direction(0)

    def set_direction(self,index):
        a=math.radians(index*45)
        self.cam.location=(10*math.sin(a),-10*math.cos(a),3.65)
        self.cam.rotation_euler=(self.V((0,0,1.60))-self.cam.location).to_track_quat('-Z','Y').to_euler()

    def select_pose(self,pose):
        for name,coll in self.pose_collections.items():
            coll.hide_render=name!=pose
            coll.hide_viewport=name!=pose
        self.bpy.context.view_layer.update()

    def projected_geometry_extrema(self,pose):
        # Source-native measurement (not an alpha estimate): evaluated actual
        # vertices incl. bevels, same visible pose/real camera, before raster.
        self.bpy.context.view_layer.update()
        graph=self.bpy.context.evaluated_depsgraph_get()
        camera_inverse=self.cam.matrix_world.inverted()
        extrema={};count=0;lowest_world=None
        for original in self.pose_collections[pose].all_objects:
            if original.type!='MESH':continue
            obj=original.evaluated_get(graph);mesh=obj.to_mesh()
            try:
                for vertex in mesh.vertices:
                    world=obj.matrix_world@vertex.co;camera=camera_inverse@world;count+=1
                    row={'object':original.name,'world':[float(x) for x in world],'camera':[float(x) for x in camera],'raw_continuous_pixel':[64+camera.x*128/ORTHO,64-camera.y*128/ORTHO]}
                    if lowest_world is None or world.z<lowest_world['world'][2]:lowest_world={'object':original.name,'world':[float(x) for x in world]}
                    for key,axis,high in [('top',1,True),('bottom',1,False),('left',0,False),('right',0,True)]:
                        if key not in extrema or (camera[axis]>extrema[key]['camera'][axis] if high else camera[axis]<extrema[key]['camera'][axis]):extrema[key]=row
            finally:obj.to_mesh_clear()
        return {'evaluated_vertex_count':count,'lowest_world_vertex':lowest_world,'extrema':extrema,'scope':'Actual evaluated3D source bounds before alpha/raster; same camera, no registration adjustment'}

    def pixels(self,path):
        self.scene.render.filepath=str(path)
        self.bpy.ops.render.render(write_still=True)
        image=self.bpy.data.images.load(str(path),check_existing=False)
        rgba=list(image.pixels[:]);self.bpy.data.images.remove(image)
        raw=bytearray(CELL*CELL*4)
        for y in range(CELL):
            for x in range(CELL):
                i=((CELL-1-y)*CELL+x)*4;o=(y*CELL+x)*4
                if rgba[i+3]>=.5:
                    # Same hard coverage / 5-bit channel quantization as current recipe.
                    raw[o:o+4]=bytes([min(255,round(rgba[i+k]*31)*8) for k in range(3)]+[255])
        occupied=[(x,y) for y in range(CELL) for x in range(CELL) if raw[(y*CELL+x)*4+3]]
        assert occupied,'Empty proof'
        raw_bbox=[min(x for x,y in occupied),min(y for x,y in occupied),max(x for x,y in occupied),max(y for x,y in occupied)]
        assert raw_bbox[0]>0 and raw_bbox[1]>0 and raw_bbox[2]<127 and raw_bbox[3]<127, 'Raw geometry touches cell border: '+repr(raw_bbox)
        bottom=max(y for x,y in occupied);shift=FOOT_Y-bottom
        aligned=bytearray(len(raw));clipped=0
        for y in range(CELL):
            dest=y+shift
            if 0<=dest<CELL:aligned[dest*CELL*4:(dest+1)*CELL*4]=raw[y*CELL*4:(y+1)*CELL*4]
            else:clipped+=sum(raw[(y*CELL+x)*4+3]>0 for x in range(CELL))
        # No silent top/side cropping to force an overlarge design into the cell.
        assert clipped==0 and min(x for x,y in occupied)>0 and max(x for x,y in occupied)<127,'Geometry clips fixed128 cell'
        final_occupied=[(x,y) for y in range(CELL) for x in range(CELL) if aligned[(y*CELL+x)*4+3]]
        final_bbox=[min(x for x,y in final_occupied),min(y for x,y in final_occupied),max(x for x,y in final_occupied),max(y for x,y in final_occupied)]
        assert final_bbox[0]>0 and final_bbox[1]>0 and final_bbox[2]<127 and final_bbox[3]<127, 'Registered geometry touches border: '+repr(final_bbox)
        assert final_bbox[3]==FOOT_Y, 'Registered occupied foot not119: '+repr(final_bbox)
        assert all(aligned[i] in (0,255) for i in range(3,len(aligned),4)), 'Nonbinary alpha'
        return aligned,{'raw_occupied_bbox':raw_bbox,'registered_occupied_bbox':final_bbox,'raw_all_borders_clear':True,'registered_all_borders_clear':True,'vertical_registration_shift':shift,'occupied_bottom':119,'origin_px':list(ANCHOR),'clipped_pixels':clipped}


def png(path,width,height,pixels):
    def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    raw=b''.join(b'\0'+bytes(pixels[y*width*4:(y+1)*width*4]) for y in range(height))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))


def main():
    args=parse_args()
    import bpy
    from mathutils import Vector, Matrix
    args.output.mkdir(parents=True)
    b=Builder(bpy,Vector,Matrix);b.setup()
    for pose in POSES:b.body(pose)
    b.camera();b.select_pose('idle')
    manifest={'status':'GENERATED_SOURCE_NOT_QUALITY_APPROVED','recipe_sha256':sha(__file__),'reference_sha256':REFERENCE_SHA,'poses':list(POSES),'columns':8,'cell_size':[128,128],'origin_px':list(ANCHOR),'occupied_bottom':119,'pixel_size_runtime_unchanged':3.65/128,'camera_ortho_scale':ORTHO,'yaw_degrees':list(range(0,360,45)),'asymmetric_tool_side':'-X in every pose/direction; never image mirrored','direction_contract':'column0 camera-Y(front), column2 camera+X(right), column4 camera+Y(rear)','renderer':'BLENDER_WORKBENCH studio material raster; no Cycles, compute bake, bloom or added mechanics','materials':list(PALETTE),'geometry_objects':sum(o.type=='MESH' for o in b.objects),'editable_joint_pivots':sum(o.type=='EMPTY' for o in b.objects),'frames':[],'mechanics_changed':False,'damage_region_labels_authored':False}
    blend=args.output/'worker-pressure-clutch.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),check_existing=False)
    manifest['editable_source']={'file':blend.name,'bytes':blend.stat().st_size,'sha256':sha(blend)}
    if args.export_idle_glb:
        bpy.ops.object.select_all(action='DESELECT')
        for obj in b.pose_collections['idle'].all_objects:
            if obj.type in ('MESH','EMPTY'):obj.select_set(True)
        glb=args.output/'worker-idle-geometry.glb'
        bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
        manifest['optional_idle_glb']={'file':glb.name,'bytes':glb.stat().st_size,'sha256':sha(glb),'scope':'Editable-pilot geometry interchange, not a runtime enemy replacement'}
    frames=selected_frames(args)
    manifest['parent_recipe_sha256']='b597021591be84e2b56ac773c9c2c98944ccc6816ed6baf6f33ae5ee22e738de'
    manifest['geometry_camera_materials_unchanged_from_v02']=False
    manifest['changes_from_v02']=['Actual deep open beveled clutch casing with recessed convex chamber','Broader hood rim and asymmetric thick ceramic shoulder volumes','Separated attached working-arm planes and body-arm negative space','Constant rigid tool upper/core length in all6 poses','v04 focused upper hood cap shortened0.08m to correct real side span120px before fixedfoot registration','v05 side-depth repair: physically forward-staggered working elbow/barrel; substantial rearward chest/shoulder/pelvis and attached pressure reservoir depth, front plane coordinates retained','Genuine sixth clutch_vent collapsed bracing pose and pressure exhaust; worker-only future opt-in','v07 ONLY attack elbow braced rearward while fixedlength tool remains forward, fixing diagonal rivet-tip clipping; fallen pose recentered0.10m and low ankle/knee curled0.06/0.03m while actual body stays ground-seated','v06 ONLY walkA/B tool carry force-lines lowered and drawn back with exact rigid lengths to correct demonstrated rivet-tip diagonal clipping; idle/attack/vent untouched']
    manifest['rows']=len(POSES)
    manifest['base_five_rows_preserved']=list(BASE_POSES)
    manifest['worker_only_optional_phase_row']={'clutch_vent':5}
    manifest['tool_rigid_lengths']={'upper':TOOL_UPPER_LENGTH,'barrel_core':TOOL_CORE_LENGTH}
    manifest['requested_cells']=[{'pose':p,'row':POSES.index(p),'direction':c} for p,c in frames]
    manifest['native_render_count']=0
    manifest_path=args.output/'manifest.json'
    def checkpoint():manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
    checkpoint()
    if args.mode=='atlas':
        # One cheap source-native survey of ALL6 poses/all8 bearings before
        # first raster. Actual raster clipping guards remain authoritative.
        manifest['all48_source_preflight']=[]
        for survey_pose in POSES:
            for survey_direction in range(8):
                b.select_pose(survey_pose);b.set_direction(survey_direction)
                manifest['all48_source_preflight'].append({'pose':survey_pose,'direction':survey_direction,'geometry':b.projected_geometry_extrema(survey_pose)})
        checkpoint()
    cells=[]
    for pose,direction in frames:
        b.select_pose(pose);b.set_direction(direction)
        raw=args.output/('raw-%s-%02d.png'%(pose,direction))
        manifest['attempting_cell']={'pose':pose,'direction':direction,'row':POSES.index(pose),'source_geometry_extrema':b.projected_geometry_extrema(pose)}
        checkpoint()
        try:
            pixels,registration=b.pixels(raw)
        except BaseException as exc:
            manifest['status']='FRAME_FAILED_NO_CROP_OR_RESCALE'
            manifest['failure']={'type':type(exc).__name__,'message':str(exc)}
            checkpoint()
            raise
        out=args.output/('worker-%s-%02d.png'%(pose,direction));png(out,128,128,pixels)
        manifest['frames'].append({'file':out.name,'sha256':sha(out),'row':POSES.index(pose),'direction':direction,'registration':registration,'source_geometry_extrema':manifest['attempting_cell']['source_geometry_extrema']})
        cells.append(pixels)
        manifest['native_render_count']=len(cells)
        manifest.pop('attempting_cell',None)
        checkpoint()
    if args.mode=='atlas':
        assert len(cells)==len(POSES)*8
        atlas=bytearray(1024*(128*len(POSES))*4)
        for i,cell in enumerate(cells):
            row,column=divmod(i,8)
            for y in range(128):
                dest=((row*128+y)*1024+column*128)*4
                atlas[dest:dest+512]=cell[y*512:(y+1)*512]
        path=args.output/'worker.png';png(path,1024,128*len(POSES),atlas)
        manifest['atlas']={'file':path.name,'sha256':sha(path),'bytes':path.stat().st_size}
    manifest['native_render_count']=len(frames)
    manifest['not_evidence_for']=['quality acceptance','gameplay','timing','damage regions','Godot consumer','FPS','human play']
    checkpoint()
    print('WORKER_PILOT_DONE '+json.dumps({'mode':args.mode,'render_count':len(frames),'output':str(args.output),'source':str(blend)}),flush=True)


if __name__=='__main__':main()
