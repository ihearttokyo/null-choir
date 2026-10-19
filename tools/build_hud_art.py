"""Original sculpted HUD kit. Blender -b -t 2 --python this_file -- --output-root FRESH_ROOT."""
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import stat
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT/'source/art/references/hud-reference-v1.png'
REFERENCE_SHA = '16045d1e30d36fe544f4939d871a4f67b34b409eb7e39b8ec63213d6d7ee7f8e'
HELPER_SHA = '07c35732461226ee786f7f3f50b0617c5acf90368b8cd8668b6c996e13b45c5a'
PALETTE = {'basalt':'#17191d', 'shadow':'#08090c', 'ivory':'#d8c7a4',
           'brass':'#a8793e', 'wear':'#e1bd7d', 'oxblood':'#762b30',
           'flesh':'#aa544c', 'amber':'#eab15d', 'core':'#ffe2a6'}
NAMES = ('heart','shield','impact_tool','rivet_pistol','scattergun','sawtooth_repeater',
         'marrow_launcher','choir_disruptor','seal_blood','seal_ivory','seal_empty',
         'story_empty','story_filled','ammo','frame_corner','frame_tile',
         'slot_base','slot_selected','lock','dry','low_health','divider')


def pinned(path, expected):
    info = path.lstat()
    if path.resolve() != path or not stat.S_ISREG(info.st_mode) or getattr(info,'st_flags',0)&stat.SF_DATALESS:
        raise ValueError('Input must be a real resident file: '+str(path))
    if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        raise ValueError('Input drift: '+str(path))


def plate(art, name, outline, material, depth=.10, z=0):
    count = len(outline)
    vertices = [(x,y,z) for x,y in outline]+[(x,y,z+depth) for x,y in outline]
    faces = [tuple(reversed(range(count))),tuple(range(count,count*2))]
    faces += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    return art.mesh(name,vertices,faces,material)


def heart(art):
    obj = art.egg('Left ventricle',(-.10,-.075,.06),(.235,.31,.155),'oxblood',24,16)
    obj.rotation_euler.z = -.28
    obj = art.egg('Right ventricle',(.105,-.045,.08),(.17,.26,.16),'flesh',24,16)
    obj.rotation_euler.z = .23
    art.egg('Atrial appendage',(-.18,.17,.08),(.14,.11,.12),'oxblood',20,12)
    art.egg('Right atrial lobe',(.18,.13,.065),(.13,.12,.11),'oxblood',20,12)
    art.tube('Raised aortic arch',[(-.08,.16,.11),(-.13,.32,.10),(-.06,.395,.085),
             (.035,.37,.10),(.105,.245,.13)],[.078,.065,.064,.061,.05],'oxblood',16)
    art.tube('Pulmonary branch',[(.065,.19,.18),(.18,.31,.16),(.30,.30,.12)],
             [.068,.055,.037],'flesh',12)
    art.egg('Pulmonary dark bore',(.30,.30,.147),(.028,.022,.015),'shadow',12,8)
    for i in range(2):
        x = -.24+i*.105
        art.tube('Venous inflow '+str(i),[(x,.14,.035),(x-.025,.31,.025),(x+.01,.355,.02)],
                 [.044,.04,.03],'oxblood',12)
        art.egg('Venous bore '+str(i),(x+.01,.355,.052),(.021,.017,.01),'shadow',12,8)
    art.tube('Ventricular separation',[(-.015,.15,.225),(.035,.03,.233),(.02,-.15,.208),
             (-.045,-.32,.11)],[.020,.017,.013,.004],'oxblood',8)
    art.tube('Coronary trunk',[(-.21,.12,.17),(-.085,.16,.205),(.02,.06,.24),
             (.17,-.04,.213),(.17,-.15,.18)],[.019,.025,.02,.015,.005],'flesh',10)
    for i in range(3):
        y = .04-i*.09
        art.tube('Coronary lateral '+str(i),[(.015,y,.232),(-.11,y-.02,.205),(-.22,y-.06,.15)],
                 [.013,.01,.002],'flesh',8)


def shield(art):
    outline = [(-.29,.335),(-.055,.315),(0,.39),(.055,.315),(.29,.335),(.26,-.11),(0,-.395),(-.26,-.11)]
    plate(art,'Thick pointed brass perimeter',outline,'brass',.07)
    inside = [(x*.82,y*.85) for x,y in outline]
    plate(art,'Solid ivory armored plate',inside,'ivory',.045,.075)
    art.mesh('Raised faceted central ridge',[(x,y,.12) for x,y in inside]+[(0,-.005,.19)],
             [(i,(i+1)%len(inside),len(inside)) for i in range(len(inside))],'ivory')
    art.tube('Worn raised edge',[(x,y,.092) for x,y in outline+[outline[0]]],.018,'wear',8)
    art.tube('Central reinforcement',[(0,.30,.175),(0,-.29,.175)],.026,'brass',8)
    for side in (-1,1):
        for y in (.16,-.015,-.16):
            art.tube('Armor branching buttress',[(0,y,.185),(side*.17,y+.075,.155)],.018,'brass',8)
    plate(art,'Ivory central lozenge',[(-.065,0),(0,.12),(.065,0),(0,-.12)],'wear',.025,.19)


def impact_tool(art):
    art.tube('Impact haft',[(-.025,-.36,0),(-.025,.16,0)],.038,'ivory',12)
    for y in (-.31,-.25,-.19):
        art.box('Grip collar',(-.025,y,.012),(.11,.034,.08),'brass',.008)
    art.box('Heavy striking block',(-.15,.17,.03),(.25,.22,.13),'basalt',.035)
    art.box('Pale striking face',(-.25,.17,.035),(.065,.23,.15),'ivory',.012)
    art.tube('Split extraction claw',[(0,.18,.01),(.15,.23,.01),(.25,.17,.01),(.20,.055,.01)],
             [.08,.07,.045,.012],'brass',10)
    art.box('Impact head bearing',(-.055,.17,.105),(.11,.09,.04),'wear',.016)


def rivet_pistol(art):
    plate(art,'Angled ivory grip',[(-.27,.12),(-.15,.05),(-.16,-.27),(-.31,-.31),(-.35,-.19)],'ivory',.12)
    art.box('Compact rivet receiver',(-.06,.135,.045),(.38,.16,.15),'basalt',.025)
    art.tube('Rivet barrel',[(.05,.16,.10),(.36,.16,.10)],.052,'brass',12)
    art.box('Raised pale slide',(.025,.22,.085),(.36,.044,.13),'ivory',.01)
    art.ring('Circular rivet chamber',(-.14,.13,.145),.072,.022,'brass',segments=16)
    art.egg('Chamber inset',(-.14,.13,.152),(.049,.049,.018),'shadow',12,8)
    art.ring('Open trigger guard',(-.06,-.04,.03),.085,.018,'brass',segments=16)
    art.tube('Trigger',[(-.04,.014,.075),(-.06,-.05,.075)],.018,'ivory',6)
    for y in (-.16,-.22):
        art.tube('Wide grip cuts',[(-.30,y,.13),(-.19,y+.02,.13)],.014,'basalt',6)
    art.box('Muzzle collar',(.325,.16,.10),(.054,.145,.145),'wear',.008)


def scattergun(art):
    plate(art,'Broad shoulder stock',[(-.40,-.18),(-.36,.105),(-.20,.115),(-.075,.045),(-.19,-.13)],'ivory',.115)
    art.box('Stock heel',(-.365,-.065,.058),(.08,.25,.135),'basalt',.015)
    for y in (.12,.215):
        art.tube('Long twin scatter barrel',[(-.16,y,.04),(.415,y,.04)],.043,'ivory',12)
        art.box('Dark muzzle band',(.37,y,.04),(.055,.10,.10),'brass',.008)
    art.box('Scatter breach',(-.135,.105,.04),(.145,.23,.16),'brass',.023)
    art.box('Thick foregrip',(.075,.045,.045),(.29,.125,.145),'basalt',.025)
    for x in (-.015,.055,.125):
        art.box('Foregrip raised grooves',(x,.035,.127),(.025,.10,.028),'brass',.006)
    art.ring('Scatter trigger',(-.15,-.05,.055),.061,.015,'brass',segments=16)


def sawtooth_repeater(art):
    art.box('Boxed chain receiver',(-.05,.045,.025),(.42,.20,.16),'basalt',.025)
    art.tube('Repeater barrel',[(.08,.14,.025),(.405,.14,.025)],.055,'ivory',12)
    art.box('Box ammunition feed',(.035,-.13,.04),(.20,.19,.14),'brass',.025)
    plate(art,'Repeater rear handgrip',[(-.35,.09),(-.19,.075),(-.21,-.24),(-.35,-.20)],'ivory',.14)
    for i in range(5):
        x = -.17+i*.092
        plate(art,'Raised saw blade tooth '+str(i),[(x,.15),(x+.035,.27),(x+.065,.15)],'ivory',.09,.025)
    art.box('Chain spine',(.015,.17,.07),(.47,.045,.1),'brass',.008)
    for x in (-.14,-.015,.12):
        art.box('Receiver vent',(x,.045,.125),(.045,.083,.025),'wear',.004)


def marrow_launcher(art):
    art.egg('Pressurized marrow organ',(.025,.045,.045),(.285,.175,.13),'oxblood',24,16)
    plate(art,'Two-pronged rear brace',[(-.39,.16),(-.23,.16),(-.25,.055),(-.29,-.085),(-.24,-.22),(-.39,-.20),(-.34,0)],'ivory',.105)
    for x in (-.19,-.045,.10):
        art.tube('Heavy external marrow rib',[(x,-.15,.025),(x-.03,-.08,.16),
                 (x-.035,.07,.19),(x,.23,.06)],[.025,.033,.031,.018],'ivory',10)
    art.box('Muzzle backing',(.30,.05,.01),(.10,.36,.21),'brass',.025)
    art.box('Open dark marrow bore',(.355,.05,.12),(.055,.23,.028),'shadow',.007)
    for y in (-.13,.235):
        art.egg('Thick bifurcated muzzle lip',(.32,y,.10),(.086,.044,.11),'ivory',16,8)
    art.egg('Warm pressure window',(-.14,.045,.183),(.035,.06,.027),'amber',12,8)
    art.tube('Organic trigger root',[(-.20,-.08,.025),(-.16,-.27,.025)],.04,'ivory',10)


def choir_disruptor(art):
    art.tube('Resonator staff',[(0,-.40,.025),(0,.34,.025)],.029,'ivory',12)
    art.ring('Large choir resonator',(0,.12,.035),.205,.034,'brass',segments=32)
    for i in range(6):
        angle = i*math.tau/6
        x,y = math.cos(angle),math.sin(angle)
        art.tube('Broad resonator vane '+str(i),[(x*.16,.12+y*.16,.03),
                 (x*.275,.12+y*.275,.03)],[.037,.005],'ivory',8)
    plate(art,'Raised resonator core',[(-.055,.12),(0,.285),(.055,.12),(0,-.045)],'ivory',.045,.07)
    art.egg('Warm isolated focus',(0,.12,.15),(.03,.053,.023),'amber',12,8)
    for y in (-.32,-.22):
        art.box('Staff collar',(0,y,.035),(.10,.035,.10),'brass',.008)


def seal(art, kind):
    art.egg('Black recessed seal disk',(0,0,0),(.31,.31,.045),'basalt',32,12)
    art.ring('Heavy brass seal rim',(0,0,.025),.335,.034,'brass',segments=40)
    art.ring('Pale inner raised rim',(0,0,.055),.286,.013,'wear',segments=32)
    for i in range(6):
        angle = i*math.tau/6
        art.box('Brass retainer',(math.cos(angle)*.328,math.sin(angle)*.328,.063),(.055,.055,.035),'wear',.01)
    if kind == 'blood':
        plate(art,'Four-bladed containment seal',[(0,.26),(.045,.07),(.145,0),(.045,-.07),
                  (0,-.26),(-.045,-.07),(-.145,0),(-.045,.07)],'brass',.08,.075)
        plate(art,'Warm inset seal',[(-.052,0),(0,.155),(.052,0),(0,-.155)],'amber',.025,.16)
    elif kind == 'ivory':
        art.egg('Ivory witness cranium',(0,.055,.09),(.15,.165,.08),'ivory',24,12)
        for side in (-1,1):
            art.egg('Deep carved eye',(side*.067,.07,.16),(.043,.055,.023),'shadow',12,8)
            art.egg('Raised cheekbone',(side*.102,-.034,.13),(.045,.07,.04),'wear',12,8)
        plate(art,'Triangular nasal cavity',[(-.025,-.026),(0,.013),(.025,-.026)],'shadow',.01,.174)
        art.box('Broad mandibular seal',(0,-.135,.075),(.19,.064,.13),'ivory',.02)
        for x in (-.04,.04):
            art.box('Jaw division',(x,-.13,.15),(.012,.05,.01),'shadow')


def story(art, filled):
    art.egg('Recessed record socket',(0,0,0),(.21,.21,.04),'shadow',24,12)
    art.ring('Record socket lip',(0,0,.03),.24,.035,'brass',segments=24)
    for angle in (0,math.pi/2,math.pi,math.pi*1.5):
        art.egg('Socket rivet',(math.cos(angle)*.238,math.sin(angle)*.238,.06),(.026,.026,.017),'wear',8,6)
    if filled:
        art.egg('Convex recovered core',(0,0,.06),(.17,.17,.075),'amber',24,12)
        plate(art,'Raised core diamond',[(-.066,0),(0,.102),(.066,0),(0,-.102)],'core',.02,.14)


def ammo(art):
    for x in (-.18,0,.18):
        art.box('Ivory cartridge',(x,-.03,0),(.10,.40,.085),'ivory',.014)
        plate(art,'Pointed cartridge cap',[(x-.05,.17),(x,.31),(x+.05,.17)],'ivory',.09)
        art.box('Brass cartridge base',(x,-.23,.01),(.13,.055,.11),'brass',.008)
        art.box('Broad cartridge band',(x,-.12,.055),(.10,.025,.012),'brass')


def frame_corner(art):
    plate(art,'Basalt corner shoulder',[(-.39,-.38),(-.39,.39),(.38,.39),(.30,.18),(-.17,.17),(-.18,-.30)],'basalt',.045)
    art.tube('Heavy outer corner trim',[(-.36,-.37,.07),(-.36,.36,.07),(.37,.36,.07)],.027,'brass',8)
    art.tube('Raised inner ogive',[(-.30,-.19,.09),(-.22,.05,.09),(-.03,.24,.09),(.22,.30,.09)],.022,'wear',8)
    plate(art,'Broad lance leaf',[(-.30,.28),(-.08,.17),(-.20,.10)],'brass',.045,.08)
    plate(art,'Corner leaf hook',[(-.30,.28),(-.21,.04),(-.12,.13)],'wear',.035,.10)
    art.egg('Corner nail',(-.30,.30,.11),(.046,.046,.029),'wear',12,6)


def frame_tile(art):
    art.box('Broad basalt slab',(0,0,0),(.88,.48,.07),'basalt',.023)
    for y in (-.24,.24):
        art.box('Raised long brass rail',(0,y,.04),(.88,.036,.045),'brass',.008)
        art.box('Broad pale rail wear',(-.14,y+.012,.068),(.35,.012,.012),'wear')
    for x,y in ((-.32,-.07),(.25,.085)):
        plate(art,'Sparse large chipped basalt edge',[(x-.07,y),(x+.06,y+.025),(x+.02,y-.015)],'shadow',.002,.037)


def slot(art, selected):
    art.box('Dark arsenal recess',(0,0,-.02),(.87,.56,.04),'basalt',.018)
    thickness = .028 if selected else .014
    for x in (-.432,.432):
        art.box('Arsenal side', (x,0,.01),(thickness,.56,.07),'wear' if selected else 'brass',.005)
    for y in (-.28,.28):
        art.box('Arsenal rail',(0,y,.01),(.88,thickness,.07),'wear' if selected else 'brass',.005)
    if selected:
        for side in (-1,1):
            plate(art,'Selection corner tooth',[(side*.40,.28),(side*.30,.28),(side*.34,.195)],'amber',.035,.06)
        art.box('Selection lower tab',(0,-.28,.05),(.15,.055,.05),'amber',.009)


def lock(art):
    art.ring('Thick lock shackle',(0,.105,0),.14,.041,'ivory',segments=24)
    art.box('Lock body',(0,-.065,.02),(.35,.255,.13),'brass',.035)
    art.egg('Dark key hole',(0,-.03,.105),(.035,.035,.012),'shadow',12,8)
    art.box('Key hole stem',(0,-.085,.10),(.032,.055,.014),'shadow')


def dry(art):
    art.tube('Heavy ammunition strike-through',[(-.37,-.25,.0),(.37,.25,.0)],.034,'ivory',8)
    for side in (-1,1):
        art.tube('Dry end serif',[(side*.33,side*.15,0),(side*.39,side*.285,0)],.031,'oxblood',8)


def low_health(art):
    for side in (-1,1):
        for i in range(2):
            x = side*(.23+i*.08)
            plate(art,'Sculpted wound warning fang',[(x,-.29+i*.025),(x-side*.05,.0),(x,.27-i*.055)],'flesh',.07)


def divider(art):
    art.box('Dark frame joint',(0,0,0),(.13,.78,.035),'shadow',.012)
    art.tube('Brass joint spine',[(0,-.34,.05),(0,.34,.05)],.019,'brass',8)
    for y in (-.32,.32):
        plate(art,'Raised frame joint spear',[(-.058,y),(0,y+.045),(.058,y),(0,y-.045)],'wear',.045,.05)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-root',type=Path,required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    output = args.output_root.absolute()
    if any(p.is_symlink() for p in (output,*output.parents)) or output.exists():
        raise ValueError('Use a fresh exact nonsymlink output root')
    pinned(REFERENCE,REFERENCE_SHA)
    pinned(ROOT/'tools/build_art.py',HELPER_SHA)
    import bpy
    from mathutils import Vector
    if not bpy.app.background: raise ValueError('Background Blender only')
    user_paths = {}
    for kind in ('CONFIG','DATAFILES','SCRIPTS','EXTENSIONS'):
        path = Path(os.environ['BLENDER_USER_'+kind])
        if Path(bpy.utils.user_resource(kind,create=False)) != path or path.resolve() != path or not path.is_dir():
            raise ValueError('Unowned Blender user path: '+kind)
        user_paths[kind] = str(path)
    if Path(bpy.utils.resource_path('USER')).resolve() != Path(os.environ['BLENDER_USER_RESOURCES']):
        raise ValueError('Unowned Blender resource root')
    if not Path(bpy.app.tempdir).resolve().is_relative_to(Path(os.environ['TMPDIR'])):
        raise ValueError('Unowned Blender temporary path')
    output.mkdir(parents=True)
    spec = importlib.util.spec_from_file_location('art',ROOT/'tools/build_art.py')
    art = importlib.util.module_from_spec(spec); spec.loader.exec_module(art)
    art.ART,art.OUT,art.SCRATCH = output/'source/art',output/'game/assets/art',output/'previews'
    scene = art.setup()
    scene.render.threads = 2
    scene.cycles.samples = 24
    scene.cycles.use_adaptive_sampling = False
    scene.render.filter_size = .1
    art.M.clear()
    for name,color in PALETTE.items():
        art.M[name] = art.material(name,color,metal=.50 if name in ('brass','wear') else 0,
                    rough=.48 if name in ('brass','wear') else .38 if name in ('oxblood','flesh') else .7,
                    emission=.4 if name == 'core' else .1 if name == 'amber' else 0)
    builders = (heart,shield,impact_tool,rivet_pistol,scattergun,sawtooth_repeater,marrow_launcher,choir_disruptor,
                lambda a:seal(a,'blood'),lambda a:seal(a,'ivory'),lambda a:seal(a,'empty'),
                lambda a:story(a,False),lambda a:story(a,True),ammo,frame_corner,frame_tile,
                lambda a:slot(a,False),lambda a:slot(a,True),lock,dry,low_health,divider)
    counts = {}
    for index,(name,builder) in enumerate(zip(NAMES,builders)):
        before = set(scene.objects)
        builder(art)
        collection = bpy.data.collections.new(name); scene.collection.children.link(collection)
        center = Vector((index%8-3.5,1-index//8,0))
        count = 0
        for obj in set(scene.objects)-before:
            obj.scale *= .94
            obj.location = obj.location*.94+center
            for old in list(obj.users_collection): old.objects.unlink(obj)
            collection.objects.link(obj)
            obj.data.calc_loop_triangles(); count += len(obj.data.loop_triangles)
        counts[name] = count
        bpy.context.view_layer.update()
        for obj in collection.objects:
            for corner in obj.bound_box:
                point = obj.matrix_world @ Vector(corner)-center
                assert abs(point.x) <= .4375 and abs(point.y) <= .4375, (name,obj.name,'source exceeds gutter bounds')
    assert sum(counts.values()) < 75000
    camera = art.camera(scene,(0,0,10),(0,0,0),8.0,512,192)
    for obj in list(scene.objects):
        if obj.type == 'LIGHT': bpy.data.objects.remove(obj,do_unlink=True)
    # A distant broad key keeps the same highlight direction and exposure across the atlas.
    light = bpy.data.lights.new('Uniform upper-left orthographic key','AREA')
    light.energy,light.shape,light.size,light.color = 21000,'DISK',24,(1,.89,.74)
    obj = bpy.data.objects.new(light.name,light); scene.collection.objects.link(obj)
    obj.location = (-18,26,45); obj.rotation_euler = (Vector((0,0,0))-obj.location).to_track_quat('-Z','Y').to_euler()
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.30,.34,.40,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .35
    scene['selected_reference_sha256'] = REFERENCE_SHA
    scene['sprite_collection_order'] = json.dumps(NAMES)
    scene['HUD_artist_note'] = 'Original editable geometry, no captured/reference textures or live text. Single orthographic key; source pixel atlas 64px cells.'
    blend = art.target(art.ART/'hud_kit.blend')
    atlas = art.target(art.OUT/'hud/hud_kit.png')
    scene.render.filepath = str(art.target(art.SCRATCH/'frames/hud-native-atlas.png'))
    art.sanitize_source_paths(bpy)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=False)
    pixels = art.pixels_render(scene,'hud-native-atlas',512,192)
    art.png(atlas,512,192,pixels)
    sprites = {}
    for index,name in enumerate(NAMES):
        x,y = index%8*64,index//8*64
        occupied = [(cx,cy) for cy in range(64) for cx in range(64) if pixels[((y+cy)*512+x+cx)*4+3]]
        assert occupied and all(4 <= cx < 60 and 4 <= cy < 60 for cx,cy in occupied), (name,'gutter bleed')
        bounds = [min(cx for cx,cy in occupied),min(cy for cx,cy in occupied),
                  max(cx for cx,cy in occupied)-min(cx for cx,cy in occupied)+1,
                  max(cy for cx,cy in occupied)-min(cy for cx,cy in occupied)+1]
        sprites[name] = {'region':[x,y,64,64],'content_rect':bounds,'alpha_pixels':len(occupied),
                         'triangles':counts[name]}
    metadata = {'atlas':'res://assets/art/hud/hud_kit.png','dimensions':[512,192],'cell_size':[64,64],
                'columns':8,'filter':'nearest','clear_border':4,'sprites':sprites,'native_render':True,
                'render_engine':'CYCLES','render_device':'CPU','render_threads':2,'samples':24,
                'scene_collection_names':list(NAMES),'lights':1,'blender_version':bpy.app.version_string,
                'reference_sha256':REFERENCE_SHA,'palette':PALETTE,
                'state_shapes':{'selected':'double rim, inward corner teeth and lower tab','locked':'thick lock body and open shackle',
                                'dry':'heavy diagonal strike-through with capped ends','low_health':'paired wound-warning fangs',
                                'story_empty':'dark recessed center','story_filled':'convex pale raised diamond'}}
    meta = art.target(art.OUT/'hud/hud_kit.json')
    meta.write_text(json.dumps(metadata,indent=2)+'\n')
    runtime_bytes = sum(p.stat().st_size for p in atlas.parent.iterdir() if p.is_file())
    assert runtime_bytes <= 1024*1024 and blend.stat().st_size < 16*1024*1024
    receipt = {'native_render':True,'source_triangles':sum(counts.values()),'runtime_bytes':runtime_bytes,
               'source_bytes':blend.stat().st_size,'user_paths':user_paths,'temporary_path':bpy.app.tempdir,
               'scene_objects':len(scene.objects),'render_threads':2,'reference_sha256':REFERENCE_SHA,
               'helper_sha256':HELPER_SHA,'artifact_hashes':{str(p.relative_to(output)):art.sha(p) for p in (blend,atlas,meta)}}
    (output/'NATIVE-ART-RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n')
    entry = {'id':'hud_kit','source':'source/art/hud_kit.blend','source_sha256':art.sha(blend),
             'outputs':[{'path':str(p.relative_to(output)),'sha256':art.sha(p),'bytes':p.stat().st_size,
                         **({'dimensions':[512,192]} if p == atlas else {})} for p in (atlas,meta)],
             'provenance':{'method':'original sculpted Blender geometry, native CPU orthographic render',
                           'authoring_script':'tools/build_hud_art.py','imports':[],'license':'Original NULL CHOIR project art'},
             'recipe_sha256':art.sha(Path(__file__)), 'recipe_dependencies':{'tools/build_art.py':HELPER_SHA},
             'reference_images':[{'path':'source/art/references/hud-reference-v1.png','sha256':REFERENCE_SHA}],
             'cell_size':[64,64],'columns':8,'filter':'nearest','clear_border':4,
             'pose_collections':list(NAMES),'triangles':sum(counts.values()),
             'build':{'blender_version':bpy.app.version_string,'render_engine':'CYCLES','device':'CPU','threads':2,'samples':24}}
    (art.ART/'hud_manifest_entry.json').write_text(json.dumps(entry,indent=2)+'\n')
    print('PASS original HUD source, single-key CPU native atlas, 22 sprites, hard alpha and 4px clear gutters')


if __name__ == '__main__':
    main()
