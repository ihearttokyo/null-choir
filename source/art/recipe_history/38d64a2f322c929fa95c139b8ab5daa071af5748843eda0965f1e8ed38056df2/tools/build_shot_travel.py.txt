"""Original editable travel shots; run with background Blender and explicit repo/output roots."""
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import sys

sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from shot_atlas import validate

PINS={
 'tools/build_art.py':'285c99ece27a834e912e90f9c5d07ca4b2f8392a1045a1c089c7aa4fb5b8f581',
 'tools/build_ammo_vfx.py':'4988b1eab654935fd66dc8aeb143dcc33c01da4e633a8ec39df0112458edbd2d',
 'source/art/references/shot-transport-construction-20261018.png':'c48eefc9b364b169c2b7c7fa65ba0a55804a362ab42430c432aaf73d7221b15f'}
FAMILIES=('rivet_square_amber','flechette_single_bone','needle_serrated_red','choir_hollow_pressure')


def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def plate(art,name,outline,z,depth,material):
    if sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(outline,outline[1:]+outline[:1])) < 0:
        outline=list(reversed(outline))
    n=len(outline)
    verts=[(x,y,h) for h in (z-depth/2,z+depth/2) for x,y in outline]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return art.mesh(name,verts,faces,material)


def wake(art,phase,x,y=0,material='amber',length=.17):
    reach=length*(.84,1,.91,.96)[phase]
    art.tube('Tapered travel wake',[(x,y,.0),(x-reach*.45,y,.0),(x-reach,y,.0)],
             [.035,.023,.001],material,6)
    art.tube('Hot travel seam',[(x+.015,y,.025),(x-reach*.67,y,.025)],[.014,.001],'hot',5)


def rivet(art,phase):
    art.box('Short forged shank',(-.065,0,0),(.28,.15,.12),'iron',.015)
    art.box('Copper neck collar',(-.18,0,.005),(.055,.22,.15),'copper',.01)
    art.box('Square head copper rim',(.18,0,.035),(.235,.35,.15),'copper',.015)
    art.box('Square head inset iron',(.19,0,.12),(.196,.302,.045),'steel',.008)
    for y in (-.06,.06):
        art.box('Amber head vent',(.19,y,.147),(.115,.024,.014),'amber')
    for x in (.116,.264):
        for y in (-.118,.118):
            art.egg('Copper head rivet',(x,y,.154),(.018,.018,.013),'edge',8,4)
    art.box('Leading square edge',(.295,0,.07),(.019,.30,.10),'edge',.004)
    wake(art,phase,-.21,length=.18)
    for side in (-1,1):
        art.tube('Short split amber wake',[(-.205,side*.055,0),(-.31,side*(.06+.008*phase),0)],
                 [.013,.001],'amber',5)


def flechette(art,phase):
    art.tube('Single iron pellet spine',[(-.22,0,0),(.20,0,0),(.385,0,0)],[.048,.034,.001],'iron',6)
    art.box('Single copper binding',(-.17,0,.025),(.045,.125,.08),'copper',.006)
    upper=[(-.09,.022),(-.115,.067),(.025,.056),(-.006,.089),(.154,.048),(.385,0),(.11,.017)]
    plate(art,'Upper jagged bone plate',upper,.043,.033,'bone')
    lower=[(-.08,-.017),(-.11,-.06),(.07,-.047),(.025,-.078),(.23,-.028),(.385,0),(.12,-.012)]
    plate(art,'Lower jagged bone plate',list(reversed(lower)),.042,.032,'bone')
    art.tube('Pellet incandescent groove',[(-.13,0,.056),(.21,0,.046)],[.014,.002],'amber',5)
    wake(art,phase,-.215,length=.17)


def needle(art,phase):
    plate(art,'Lean iron needle',[(-.235,-.044),(.14,-.025),(.415,0),(.14,.025),(-.235,.044)],.015,.055,'iron')
    art.box('Rear needle binding',(-.215,0,.025),(.04,.12,.09),'copper',.005)
    for side in (-1,1):
        for i,(x,reach) in enumerate(((-.11,.118),(.02,.092),(.145,.066))):
            outline=[(x-.066,side*.018),(x-.10,side*reach),(x+.075,side*.024)]
            if side < 0:
                outline.reverse()
            plate(art,'Serration %s %s'%(side,i),outline,.051,.022,'edge' if i==0 else 'copper')
            art.tube('Serration red heat %s %s'%(side,i),[(x-.083,side*reach*.86,.067),(x+.035,side*.023,.067)],
                     [.009,.002],'red',5)
    art.tube('Red-hot axial needle',[(-.19,0,.065),(.16,0,.065),(.415,0,.025)],
             [.017,.014,.001],'red',6)
    art.tube('Amber axial edge',[(-.13,.009,.083),(.17,.006,.075),(.385,0,.031)],
             [.006,.005,.001],'hot',5)
    wake(art,phase,-.24,material='red',length=.15)


def choir(art,phase):
    growth=(.88,.95,1,.94)[phase]
    for radius,mat,kept in ((.255,'cyan',(0,1,3,4,5,7,8,9,11,12,13,15)),
                            (.32,'violet',(0,2,3,5,6,8,10,11,13,14))):
        for i in kept:
            a=math.tau*(i+.12*phase)/16
            b=a+math.tau*.72/16
            pts=[(radius*growth*math.cos(t),radius*growth*math.sin(t),.01) for t in (a,(a+b)/2,b)]
            art.tube('%s broken pressure arc %02d'%(mat,i),pts,[.019,.027 if mat=='cyan' else .019,.009],mat,5)
    for i in range(4):
        a=math.tau*i/4+.035*phase
        art.tube('Cardinal pressure shard %s'%i,
                 [(.19*growth*math.cos(a),.19*growth*math.sin(a),.028),
                  (.335*growth*math.cos(a),.335*growth*math.sin(a),.028),
                  (.397*growth*math.cos(a),.397*growth*math.sin(a),.028)],
                 [.008,.017,.001],'cyan' if i%2 else 'violet',5)
    for i in range(4):
        a=math.tau*(i+.32)/4+.05*phase
        art.box('Detached violet fracture %s'%i,(.36*growth*math.cos(a),.36*growth*math.sin(a),.01),
                (.017,.028,.018),'violet')


def environment(bpy,output):
    paths={}
    for kind in ('CONFIG','DATAFILES','SCRIPTS','EXTENSIONS'):
        key='BLENDER_USER_'+kind
        expected=Path(os.environ[key])
        actual=Path(bpy.utils.user_resource(kind,create=False))
        assert expected==actual and actual.is_dir() and actual.resolve()==actual
        assert actual.is_relative_to(output.parent)
        paths[key]=str(actual)
    base=Path(os.environ['BLENDER_USER_RESOURCES'])
    assert Path(bpy.utils.resource_path('USER')).resolve()==base
    assert base.is_relative_to(output.parent)
    tmp=Path(bpy.app.tempdir).resolve()
    assert tmp.is_relative_to(Path(os.environ['TMPDIR']))
    paths.update(BLENDER_USER_RESOURCES=str(base),temporary_path=str(tmp))
    return paths


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo-root',required=True,type=Path)
    parser.add_argument('--output-root',required=True,type=Path)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    repo=args.repo_root.absolute()
    output=args.output_root.absolute()
    assert not output.exists() and all(not p.is_symlink() for p in (output,*output.parents)), 'Fresh real output root required'
    # Check bytes before importing either source helper.
    for relative,pin in PINS.items():
        path=repo/relative
        assert path.resolve()==path and path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest()==pin, 'Source drift: '+relative
    retained=load('retained_vfx',repo/'tools/build_ammo_vfx.py')
    for relative,pin in PINS.items():
        retained.pinned(repo/relative,pin)
    import bpy
    from mathutils import Matrix,Vector
    assert bpy.app.background, 'Background Blender only'
    art=load('retained_art',repo/'tools/build_art.py')
    output.mkdir(parents=True)
    art.ART,art.OUT,art.SCRATCH=output/'source/art',output/'runtime',output/'preview'
    scene=art.setup()
    scene.cycles.seed=7331
    scene.cycles.use_animated_seed=False
    scene.view_settings.exposure=-1.3
    user_paths=environment(bpy,output)
    for name,color,metal,emit in (
        ('iron','#222c31',.65,0),('steel','#526067',.6,0),('copper','#9e5732',.7,0),
        ('edge','#d09a66',.55,0),('bone','#e2cfaa',.05,0),
        ('amber','#ff9c20',.05,.9),('red','#f94512',0,.9),('hot','#ffda82',0,1),
        ('cyan','#66d8ff',0,.9),('violet','#a25eff',0,.85)):
        art.M[name]=art.material(name,color,metal=metal,emission=emit)
    poses=[]
    for row,(family,build) in enumerate(zip(FAMILIES,(rivet,flechette,needle,choir))):
        for column in range(4):
            before=set(scene.objects)
            build(art,column)
            bpy.context.view_layer.update()
            objects=set(scene.objects)-before
            collection=art.pose_collection(family+'_travel_%02d'%column)
            center=Vector((-1.5+column,1.5-row,0))
            angle=0 if row==3 else math.radians((0,-3,0,3)[column])
            transform=Matrix.Translation(center) @ Matrix.Rotation(angle,4,'X')
            for obj in objects:
                obj.matrix_world=transform @ obj.matrix_world
                obj.hide_render=False
                obj.hide_viewport=False
                obj.hide_set(False)
                obj['shot_family']=family
                obj['travel_frame']=column
            art.move_to(collection,objects)
            poses.append({'name':collection.name,'row':row,'column':column,'objects':len(objects),
                          'bounds':art.bounds(objects)})
    meshes=[o for o in scene.objects if o.type=='MESH']
    triangles=0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles+=len(obj.data.loop_triangles)
    assert len(poses)==16 and 0 < triangles <= 40000
    assert all(not o.hide_render and not o.hide_get() for o in meshes)
    art.camera(scene,(0,0,8),(0,0,0),4,256,256)
    scene['selected_reference_sha256']=PINS['source/art/references/shot-transport-construction-20261018.png']
    scene['pose_order']=json.dumps([p['name'] for p in poses])
    scene['forward_axis']='+X; camera +Z; rows top to bottom rivet, flechette, needle, choir'
    blend=art.target(art.ART/'shot_travel.blend')
    atlas=art.target(art.OUT/'shot_travel.png')
    for screen in bpy.data.screens:
        for area in screen.areas:
            for space in area.spaces:
                if space.type=='FILE_BROWSER' and space.params is not None:
                    space.params.directory=b'//'
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=False)
    pixels=art.pixels_render(scene,'shot-travel-native',256,256)
    frames=validate(pixels)
    art.png(atlas,256,256,pixels)
    assert blend.read_bytes()[:7]==b'BLENDER' and blend.stat().st_size<8*1024*1024
    assert atlas.stat().st_size<=512*1024
    scene_receipt={
        'status':'NATIVE_RENDER_VALIDATED_UNADOPTED','source_pins':PINS,
        'builder_sha256':art.sha(Path(__file__)),'validator_sha256':art.sha(HERE/'shot_atlas.py'),
        'blender_version':bpy.app.version_string,'renderer':scene.render.engine,'device':scene.cycles.device,
        'threads':scene.render.threads,'samples':scene.cycles.samples,'seed':scene.cycles.seed,
        'user_paths':user_paths,'pose_count':len(poses),'poses':poses,'mesh_objects':len(meshes),'triangles':triangles,
        'atlas_size':[256,256],'cell_size':[64,64],'gutter_px':4,'forward':'+X','frames':frames,
        'alpha_sha256':hashlib.sha256(pixels[3::4]).hexdigest(),
        'artifacts':{str(p.relative_to(output)):{'sha256':art.sha(p),'bytes':p.stat().st_size} for p in
                     (blend,atlas,art.SCRATCH/'frames/shot-travel-native.png')},
        'not_claimed':['runtime integration','GPU performance','packed application','human visual approval','bitwise RGB determinism']}
    (output/'ARTIFACT.json').write_text(json.dumps(scene_receipt,indent=2)+'\n')
    print('PASS native shot source, 16 visible poses, alpha/gutters/void, triangle and file budgets')


if __name__=='__main__':
    main()
