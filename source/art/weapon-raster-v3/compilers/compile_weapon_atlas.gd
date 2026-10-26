extends SceneTree
## NONSHIPPING nativeCPU extraction. Requires actual source measurements; no defaults.
const IDS = ["impact_tool","scattergun","sawtooth_repeater","marrow_launcher","choir_disruptor"]
const POSES = ["idle","fire","recover"]
var failures := 0
func require(ok: bool,why: String) -> bool:
 if not ok:failures+=1;push_error(why)
 return ok
func digest(bytes: PackedByteArray) -> String:
 var context=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var path=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--registration="):path=arg.trim_prefix("--registration=")
 if not require(DisplayServer.get_name()=="headless" and AudioServer.get_driver_name()=="Dummy" and path.is_absolute_path(),"Explicit CPU/Dummy registration path required"):quit(1);return
 var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not require(parsed is Dictionary,"Actual manually measured metadata required"):quit(1);return
 var m:Dictionary=parsed
 for field in ["weapon_id","source_file","source_sha256","source_dimensions","source_cell_rects","uniform_scale","native_anchor_px","registration_basis","alpha_cutoff_byte","poses","native_output"]:
  if not require(m.has(field),"No guessed registration defaults: "+field):quit(1);return
 if not require(m.weapon_id in IDS and m.poses.size()==3 and m.source_sha256.length()==64 and float(m.uniform_scale)>0 and float(m.uniform_scale)<=1,"One of five actual sources/three poses/explicitscale/SHA required"):quit(1);return
 var base=path.get_base_dir()
 if not require(not str(m.source_file).is_absolute_path() and not ".." in str(m.source_file).split("/") and not str(m.native_output).is_absolute_path() and not ".." in str(m.native_output).split("/"),"All source/output paths remain inside this versioned prototype"):quit(1);return
 var source=base.path_join(m.source_file)
 if not require(FileAccess.get_sha256(source)==m.source_sha256,"Original new production source SHA required"):quit(1);return
 var src=Image.new()
 if not require(src.load_png_from_buffer(FileAccess.get_file_as_bytes(source))==OK,"Native Godot source PNG decode"):quit(1);return
 if not require(src.get_size()==Vector2i(m.source_dimensions[0],m.source_dimensions[1]) and m.source_cell_rects.size()==3,"Measured actual source dimensions/three explicit cell rectangles"):quit(1);return
 var source_rects:Array=[]
 for row in m.source_cell_rects:
  var rect=Rect2i(row[0],row[1],row[2],row[3])
  if not require(Rect2i(Vector2i.ZERO,src.get_size()).encloses(rect) and rect.has_area(),"Explicit actual cell rectangle inside original source"):quit(1);return
  for other in source_rects:
   if not require(not rect.intersects(other),"Source cell rectangles cannot overlap"):quit(1);return
  source_rects.append(rect)
 var target=Vector2(m.native_anchor_px[0],m.native_anchor_px[1])
 if not require(not str(m.registration_basis).is_empty() and (m.weapon_id=="impact_tool" or target==Vector2(140,62)),"Tool registration explicitly explained; ranged muzzle matches actual existing flash center"):quit(1);return
 if not require(int(m.alpha_cutoff_byte)==128,"Coherent explicit128alpha extraction boundary"):quit(1);return
 src.convert(Image.FORMAT_RGBA8)
 var pixels=src.get_data()
 var atlas=Image.create(960,200,false,Image.FORMAT_RGBA8);atlas.fill(Color.TRANSPARENT)
 var hashes:Array=[];var rows:Array=[]
 for index in range(3):
  var pose:Dictionary=m.poses[index]
  if not require(pose.id==POSES[index] and pose.source_cell==index and pose.has("source_anchor_local") and pose.has("extraction_local"),"Each actual pose has manual landmark and extraction rectangle"):quit(1);return
  var anchor=Vector2(pose.source_anchor_local[0],pose.source_anchor_local[1])
  var source_rect:Rect2i=source_rects[index]
  var cell_size=source_rect.size
  var crop=Rect2i(pose.extraction_local[0],pose.extraction_local[1],pose.extraction_local[2],pose.extraction_local[3])
  if not require(Rect2i(Vector2i.ZERO,cell_size).encloses(crop) and crop.has_area(),"Manual crop inside its actual source cell"):quit(1);return
  var count=0;var lo=Vector2i(320,200);var hi=Vector2i(-1,-1)
  for y in range(200):
   for x in range(320):
    var sample=Vector2i(roundi(anchor.x+(x-target.x)/float(m.uniform_scale)),roundi(anchor.y+(y-target.y)/float(m.uniform_scale)))
    if not crop.has_point(sample):continue
    var offset=(((sample.y+source_rect.position.y)*src.get_width())+source_rect.position.x+sample.x)*4
    if pixels[offset+3]<128:continue
    atlas.set_pixel(index*320+x,y,Color8(pixels[offset],pixels[offset+1],pixels[offset+2],255))
    count+=1;lo.x=mini(lo.x,x);lo.y=mini(lo.y,y);hi.x=maxi(hi.x,x);hi.y=maxi(hi.y,y)
  var pose_image=atlas.get_region(Rect2i(index*320,0,320,200));var hash=digest(pose_image.get_data())
  require(not hash in hashes and count>=80 and hi.y==199,"Actual distinct nonemptypose with deliberate arm bottomcrop")
  hashes.append(hash);rows.append({"pose":pose.id,"source_cell_rect":m.source_cell_rects[index],"source_anchor_local":pose.source_anchor_local,"native_anchor":m.native_anchor_px,"source_crop":pose.extraction_local,"uniform_scale":m.uniform_scale,"opaque_pixels":count,"opaque_bounds_inclusive":[lo.x,lo.y,hi.x,hi.y],"rgba8_sha256":hash})
 if failures>0:quit(1);return
 var output=base.path_join(m.native_output)
 if not require(not FileAccess.file_exists(output),"Fresh versioned output only, never overwrite previous art"):quit(1);return
 DirAccess.make_dir_recursive_absolute(output.get_base_dir())
 require(atlas.save_png(output)==OK,"Native registered PNG export")
 var data=atlas.get_data()
 for index in range(3,data.size(),4):
  if not require(data[index]==0 or data[index]==255,"Binaryalpha native atlas"):break
 require(FileAccess.get_sha256(source)==m.source_sha256,"Full original source unchanged")
 var result={"weapon_id":m.weapon_id,"source_sha256":m.source_sha256,"registration_sha256":FileAccess.get_sha256(path),"compiler_sha256":FileAccess.get_sha256(get_script().resource_path),"output_png_sha256":FileAccess.get_sha256(output),"output_rgba8_sha256":digest(data),"dimensions":[960,200],"cell":[320,200],"alpha":[0,255],"poses":rows,"failures":failures,"scope":"NONSHIPPING nativeCPU measured source extraction, no repaint/newBlender/creativepixel edits/quality/gameplay acceptance"}
 var f=FileAccess.open(output.get_base_dir().path_join("compile-proof.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
 if failures==0:print("PASS NONSHIPPING nativeCPU registered ",m.weapon_id," 960x200/3distinctposes/binaryalpha")
 quit(0 if failures==0 else 1)
