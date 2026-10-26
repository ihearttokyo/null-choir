extends SceneTree
## Native CPU-only extraction/export, no creative image generation or game edits.
var failures := 0
func require(ok: bool,why: String) -> bool:
 if not ok: failures+=1; push_error(why)
 return ok
func digest(bytes: PackedByteArray) -> String:
 var ctx = HashingContext.new(); ctx.start(HashingContext.HASH_SHA256);ctx.update(bytes);return ctx.finish().hex_encode()
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var metadata_path = ""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--registration="): metadata_path = arg.trim_prefix("--registration=")
 if not require(DisplayServer.get_name()=="headless" and AudioServer.get_driver_name()=="Dummy" and metadata_path.is_absolute_path(),"Explicit CPU headless/Dummy external registration required"): quit(1);return
 var parsed = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
 if not require(parsed is Dictionary,"Readable exact registration metadata"): quit(1);return
 var m: Dictionary = parsed
 var root_path = metadata_path.get_base_dir()
 var source_path = root_path.path_join(m.source_file)
 var source_sha: String = FileAccess.get_sha256(source_path)
 if not require(source_sha==m.source_sha256,"Full original generated production source SHA required"):quit(1);return
 var src = Image.new()
 if not require(src.load_png_from_buffer(FileAccess.get_file_as_bytes(source_path))==OK and src.get_size()==Vector2i(2172,724),"Decode original unmodified2172x724 RGBA source"):quit(1);return
 src.convert(Image.FORMAT_RGBA8)
 var pixels = src.get_data()
 var atlas = Image.create(960,200,false,Image.FORMAT_RGBA8)
 atlas.fill(Color.TRANSPARENT)
 var proof: Array = []
 var all_hashes: Array = []
 for pose_index in range(3):
  var pose: Dictionary = m.poses[pose_index]
  var muzzle = Vector2(pose.muzzle_source_local[0],pose.muzzle_source_local[1])
  var crop = Rect2i(pose.extraction_local[0],pose.extraction_local[1],pose.extraction_local[2],pose.extraction_local[3])
  var count := 0
  var lo = Vector2i(320,200); var hi = Vector2i(-1,-1)
  for y in range(200):
   for x in range(320):
    var local = Vector2i(roundi(muzzle.x+(x-int(m.native_muzzle[0]))/float(m.uniform_scale)),roundi(muzzle.y+(y-int(m.native_muzzle[1]))/float(m.uniform_scale)))
    if not crop.has_point(local) or local.x<0 or local.x>=724 or local.y<0 or local.y>=724:continue
    var global_x: int = int(pose.source_cell)*724+local.x
    var offset: int = (local.y*2172+global_x)*4
    if pixels[offset+3]<int(m.alpha_cutoff_byte):continue
    atlas.set_pixel(pose_index*320+x,y,Color8(pixels[offset],pixels[offset+1],pixels[offset+2],255))
    count+=1;lo.x=mini(lo.x,x);lo.y=mini(lo.y,y);hi.x=maxi(hi.x,x);hi.y=maxi(hi.y,y)
  var cell = atlas.get_region(Rect2i(pose_index*320,0,320,200))
  var cell_sha = digest(cell.get_data())
  require(not cell_sha in all_hashes,"Three actual poses cannot be duplicates")
  require(count>=80 and hi.y==199,"Opaque registered weapon/arm reaches intended bottomcrop")
  require(cell.get_pixel(140,62).a==1.0,"Measured source muzzle maps to same opaque native pixel")
  all_hashes.append(cell_sha)
  proof.append({"pose":pose.id,"source_muzzle":pose.muzzle_source_local,"native_muzzle":m.native_muzzle,"source_crop":pose.extraction_local,"scale":m.uniform_scale,"opaque_pixels":count,"opaque_bounds_inclusive":[lo.x,lo.y,hi.x,hi.y],"cell_rgba8_sha256":cell_sha})
 var output_path: String = root_path.path_join(m.native_output)
 if not require(not FileAccess.file_exists(output_path),"Versioned output must be absent; preserve existing versions"):quit(1);return
 if failures>0:quit(1);return
 DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
 require(atlas.save_png(output_path)==OK,"Native Godot PNG export succeeds")
 var out_bytes = atlas.get_data()
 for index in range(3,out_bytes.size(),4):
  if not require(out_bytes[index]==0 or out_bytes[index]==255,"Native atlas binary alpha only"):break
 require(FileAccess.get_sha256(source_path)==source_sha,"Raw source preserved byteexact")
 var result = {"scope":"NONSHIPPING nativeCPU registered extraction; not newpainting/Blender/3D/gameplay/visualacceptance","original_source_sha256":source_sha,"registration_sha256":FileAccess.get_sha256(metadata_path),"compiler_sha256":FileAccess.get_sha256(get_script().resource_path),"output_png_sha256":FileAccess.get_sha256(output_path),"output_rgba8_sha256":digest(out_bytes),"dimensions":[960,200],"cell":[320,200],"alpha":[0,255],"poses":proof,"failures":failures,"creative_pixel_edits":false,"nearest_only":true,"full_original_preserved":true}
 var f = FileAccess.open(output_path.get_base_dir().path_join("compile-proof.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
 if failures==0:print("PASS NONSHIPPING Godot CPU registered threepose960x200 binary-alpha extraction")
 quit(0 if failures==0 else 1)
