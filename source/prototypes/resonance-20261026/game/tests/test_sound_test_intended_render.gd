extends SceneTree
## Isolated synthetic UI SubViewport only. No gameplay/desktop capture or audible claim.
const Music = preload("res://audio/music.gd")
const SoundTest = preload("res://ui/resonance/sound_test.gd")
var failures = 0
var output: String
var viewport: SubViewport
var music
var screen
var records: Array = []
var recordings: Array[WeakRef] = []
func _initialize() -> void:
 AudioServer.set_bus_mute(0,true)
 call_deferred("run")
func check(ok: bool, message: String) -> bool:
 if not ok:
  failures += 1
  push_error(message)
 return ok
func sha(bytes: PackedByteArray) -> String:
 var hash = HashingContext.new()
 hash.start(HashingContext.HASH_SHA256)
 hash.update(bytes)
 return hash.finish().hex_encode()
func draw() -> void:
 await process_frame
 await RenderingServer.frame_post_draw
 await process_frame
 await RenderingServer.frame_post_draw
func art_image() -> Image:
 var image: Image = viewport.get_texture().get_image()
 image.convert(Image.FORMAT_RGBA8)
 var rect: Rect2i = Rect2i(screen._art.get_global_rect()).intersection(Rect2i(0,0,viewport.size.x,viewport.size.y))
 check(rect.size.x>0 and rect.size.y>0,"Actual art region exists inside isolated viewport")
 return image.get_region(rect)
func metrics(image: Image) -> Dictionary:
 var bright = 0
 var minimum = 1.0
 var maximum = 0.0
 var palette: Dictionary = {}
 for y in range(0,image.get_height(),2):
  for x in range(0,image.get_width(),2):
   var pixel = image.get_pixel(x,y)
   var value: float = maxf(pixel.r,maxf(pixel.g,pixel.b))
   minimum = minf(minimum,value)
   maximum = maxf(maximum,value)
   if value>.025: bright += 1
   palette[Vector3i(int(pixel.r*15),int(pixel.g*15),int(pixel.b*15))] = true
 var samples: int = ceili(image.get_width()/2.0)*ceili(image.get_height()/2.0)
 return {"nonblack_fraction":float(bright)/maxi(1,samples),"dynamic_range":maximum-minimum,"palette_bins":palette.size(),"pixel_sha256":sha(image.get_data()),"width":image.get_width(),"height":image.get_height()}
func run() -> void:
 output = OS.get_environment("NULL_CHOIR_SOUND_RENDER_OUTPUT")
 if not check(not output.is_empty() and DirAccess.dir_exists_absolute(output),"Caller supplies existing task-local fresh output directory"): await finish(); return
 if not check(RenderingServer.get_current_rendering_method()=="mobile" and RenderingServer.get_current_rendering_driver_name()=="metal","Actual native Mobile/Metal required; no dummy renderer acceptance"): await finish(); return
 viewport = SubViewport.new()
 viewport.size = Vector2i(640,360)
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 music = Music.new()
 root.add_child(music)
 screen = SoundTest.new()
 screen.bind_music(music)
 viewport.add_child(screen)
 await draw()
 check(screen.size==Vector2(640,360),"Actual intended-use640x360 independent viewport, no window resize")
 check(screen._tracks.size()==9 and music.level_tracks.size()==8,"Eight actual campaign recordings plus explicit title")
 var hashes: Dictionary = {}
 # Technical lossless QA mosaic: exact native full-UI pixels, no art edits/upscale.
 var contact_sheet = Image.create(1920,2880,false,Image.FORMAT_RGBA8)
 contact_sheet.fill(Color.TRANSPARENT)
 for index in range(9):
  if not check(screen.play_track(index),"Actual owned recording starts: "+str(index)): continue
  recordings.append(weakref(music.player.stream))
  check(screen._art_material.get_shader_parameter("track_id")== (2 if index==8 else index),"Eight chapter IDs remain0..7; ninth title selection reuses actual Processional composition2")
  music.player.seek(2.0) # Real transport seek, not a fabricated shader phase.
  await draw()
  screen.toggle_playback()
  check(music.player.stream_paused,"Render owns real paused transport")
  var held_phase: float = screen._phase
  var held_energy: float = screen._art_energy
  screen._update_art(10.0)
  check(screen._phase==held_phase and screen._art_energy==held_energy,"Paused phase/energy frozen, no wallclock phase")
  check(screen._art_energy==0.0,"Master-muted render never invents analyzed Music amplitude")
  var each: Array = []
  for style in range(3):
   screen.set_visual_style(style)
   await draw()
   check(is_equal_approx(screen._art_material.get_shader_parameter("aspect"),screen._art.size.x/maxf(1.0,screen._art.size.y)),"Actual art rectangle aspect uniform")
   var image: Image = art_image()
   var row = metrics(image)
   check(row.nonblack_fraction>.03 and row.dynamic_range>.1 and row.palette_bins>8,"Nonblack materially varied shader output; not an aesthetic score")
   each.append(row.pixel_sha256)
   var full: Image = viewport.get_texture().get_image()
   if index<8:
    full.convert(Image.FORMAT_RGBA8)
    check(full.get_size()==Vector2i(640,360),"Contact-sheet cells retain exact native640x360 pixels")
    contact_sheet.blit_rect(full,Rect2i(0,0,640,360),Vector2i(style*640,index*360))
   var filename = "track-%02d-style-%d.png" % [index,style]
   check(full.save_png(output+"/"+filename)==OK,"Save only isolated intended-use UI pixels")
   row.merge({"track":index,"style":style,"recording":music.player.stream.resource_path,"phase":screen._phase,"energy":screen._art_energy,"image":filename})
   records.append(row)
   var stable: String = row.pixel_sha256
   await draw()
   check(sha(art_image().get_data())==stable,"Paused actual shader pixels stay bit-identical across native frames")
  check(each[0]!=each[1] and each[1]!=each[2] and each[0]!=each[2],"Three actual style compositions differ at same transport")
  hashes[index] = each
 check(hashes.size()==9,"Allnine UI selections actually rendered")
 check(contact_sheet.save_png(output+"/contact-sheet.png")==OK,"Save exact24case1920x2880 QA mosaic, eightchapterrows/three stylecolumns")
 for style in range(3):
  var distinct: Dictionary = {}
  for index in range(8):
   if hashes.has(index): distinct[hashes[index][style]] = true
  check(distinct.size()==8,"Eight campaign compositions distinct in style"+str(style))
 screen.set_reduced_motion(true)
 await draw()
 var still = sha(art_image().get_data())
 screen._update_art(10.0)
 await draw()
 check(screen._phase==0 and screen._art_energy==0 and sha(art_image().get_data())==still,"Reduced-motion native pixels stable")
 # Local viewport resize only: preserve the user's native app/window state.
 viewport.size = Vector2i(480,640)
 await draw()
 check(screen.size==Vector2(480,640),"Portrait layout follows only isolated viewport")
 check(is_equal_approx(screen._art_material.get_shader_parameter("aspect"),screen._art.size.x/maxf(1,screen._art.size.y)),"Portrait shader aspect follows actual art rectangle")
 viewport.size = Vector2i(640,360)
 await draw()
 screen.focus_selected_track()
 await draw()
 check(viewport.gui_get_focus_owner()==screen._track_buttons[8],"Programmatic keyboard focus reaches selected ninth item")
 check(screen._track_scroll.get_global_rect().encloses(screen._track_buttons[8].get_global_rect()),"Selected ninth row actually scrolled wholly into track viewport")
 check(viewport.get_texture().get_image().save_png(output+"/selected-ninth-focus.png")==OK,"Save only isolated selected-row intended-use evidence")
 var file = FileAccess.open(output+"/render-results.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"failures":failures,"renders":records,"scope":"Actual Mobile/Metal isolated SoundTest640x360 UI. Muted real transport, no audible/audio-response/nonzero analyzer claim. Pixel variation is not9score or FPS/material depth perception proof; actual visual review required."},"  "))
 file.close()
 await finish()
func finish() -> void:
 if is_instance_valid(screen): screen.close(); screen.free()
 screen = null
 if is_instance_valid(music): music.stop(); music.free()
 music = null
 if is_instance_valid(viewport): viewport.free()
 viewport = null
 await process_frame
 var deadline = Time.get_ticks_usec()+2000000
 while Time.get_ticks_usec()<deadline:
  var released = true
  for recording in recordings: released = released and recording.get_ref()==null
  if released: break
  OS.delay_msec(2)
  await process_frame
 for recording in recordings: check(recording.get_ref()==null,"Every owned native MP3 released")
 call_deferred("terminal")
func terminal() -> void:
 await process_frame
 await process_frame
 if failures==0: print("PASS isolated intended-use SoundTest27native UI renders +paused/reduced stability/aspect; NOT listening/fullcampaign/FPS/beauty acceptance")
 quit(0 if failures==0 else 1)
