extends SceneTree
## Arranged candidate-only UI preview. Actual Main toggle/layout + HUD draw consumer.
## No Level/Player/earned progress/audio player or canonical art asset mutation.
const Main=preload("res://scripts/main.gd")
const Names=preload("res://scripts/descent_map.gd")
class SilentTransport extends Node:
 func play_interlude()->void:pass
 func stop()->void:pass
class PreviewMain extends Main:
 func _ready()->void:
  process_mode=Node.PROCESS_MODE_ALWAYS
  set_process(false);set_physics_process(false);set_process_unhandled_input(false)
  settings=preferences.values
  music=SilentTransport.new();add_child(music)
  canvas=CanvasLayer.new();canvas.process_mode=Node.PROCESS_MODE_ALWAYS;add_child(canvas)
  hud=Hud.new();hud.game=self;canvas.add_child(hud)
  menu=VBoxContainer.new();menu.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  menu_scroll=ScrollContainer.new();menu_scroll.theme=_menu_theme()
  menu_scroll.position=Vector2(150,45);menu_scroll.size=Vector2(340,275)
  menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;menu_scroll.follow_focus=true
  menu.add_theme_constant_override("separation",9);menu_scroll.add_child(menu);canvas.add_child(menu_scroll)
var failures=0
var viewport:SubViewport
var game
var output=""
var records:Array=[]
func _initialize()->void:
 AudioServer.set_bus_mute(0,true)
 call_deferred("run")
func check(ok:bool,message:String)->bool:
 if not ok:failures+=1;push_error(message)
 return ok
func draw()->void:
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
func run()->void:
 if not check(OS.get_environment("NULL_CHOIR_HIDDEN_NATIVE_WRAPPER")=="1" and DisplayServer.get_name()!="headless","Established open hidden/background native wrapper required"):await finish();return
 if not check(RenderingServer.get_current_rendering_method()=="mobile" and RenderingServer.get_current_rendering_driver_name()=="metal","Actual Mobile/Metal configured"):await finish();return
 var device=RenderingServer.get_rendering_device()
 if not check(device!=null and not device.get_device_name().strip_edges().is_empty(),"Real native GPU/device required, not configured names only"):await finish();return
 if not check(AudioServer.get_driver_name()=="Dummy" and AudioServer.is_bus_mute(0),"Dummy/Master mute; no audio player/listening"):await finish();return
 var args=OS.get_cmdline_user_args()
 if not check(args.size()==2,"Supply absolute preview-inputs JSON and fresh output directory"):await finish();return
 output=args[1]
 if not check(output.is_absolute_path() and DirAccess.dir_exists_absolute(output),"Existing task-local output directory"):await finish();return
 var config=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 if not check(config is Dictionary and config.candidates.size()==3,"Exact three candidate records"):await finish();return
 var consumer:bool=config.get("consumer",false)
 viewport=SubViewport.new();viewport.size=Vector2i(640,360);viewport.process_mode=Node.PROCESS_MODE_ALWAYS
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 game=PreviewMain.new();viewport.add_child(game);game.state.new_campaign(1)
 paused=true
 for row in config.candidates:
  var chapter:int=int(row.index)
  if not check(chapter in [0,3,4] and row.path.is_absolute_path(),"Only arranged Intake/Reliquary/Nursery candidate paths"):continue
  if not check(FileAccess.get_sha256(row.path)==row.sha256,"Original candidate exact bytes bound before decode"):continue
  var image:Image
  var texture:Texture2D
  if not consumer:
   image=Image.load_from_file(row.path)
   if not check(image!=null and not image.is_empty(),"Read actual original PNG from absolute OS file"):continue
   texture=ImageTexture.create_from_image(image)
  else:
   check(row.runtime_path==preload("res://scripts/descent_chart.gd").art_path(chapter),"Canonical ART_FILES points to exact qualified original")
   if not check(FileAccess.get_sha256(row.runtime_path)==row.sha256,"Canonical runtime PNG exact original bytes"):continue
   if not check(ResourceLoader.exists(row.runtime_path),"Normal imported runtime resource exists; editor import required"):continue
  var depth=chapter+1
  game.state.level_index=depth
  game._show_menu(Names.LEVEL_NAMES[chapter].to_upper()+" RESTORED",[["Descend to "+Names.LEVEL_NAMES[depth],game.start_level],["Return to title",game.show_title]])
  game._show_descent_intermission()
  var descend=game.menu.get_child(1)
  var connections=descend.get_signal_connection_list("pressed")
  var toggle:Button
  for child in game.menu.get_children():
   if child is Button and child.text=="Chapter illustration":toggle=child
  if not check(toggle!=null,"Actual cleared-only production illustration button exists"):continue
  check(game.intermission_route.textures.size()==depth,"Only earned-prefix runtime route textures admitted in arranged state")
  toggle.pressed.emit()
  check(game.menu.get_meta("chapter_intro",-1)==chapter and not game.intermission_route.visible,"Actual cleared candidate viewer transition")
  # Test-only cache injection: HUD's ACTUAL consumer draws this Texture2D with unchanged tint,
  # scaling/footer. No asset source overwritten, no copied/reimplemented HUD drawing.
  if not consumer:
   game.hud._menu_chapter=chapter;game.hud._chapter_background=texture;game.hud.queue_redraw()
   check(game.hud.menu_backdrop_texture()==texture,"Actual HUD receives exact candidate texture")
  else:
   # NO cache assignment or Texture injection: actual normal HUD ResourceLoader path.
   texture=game.hud.menu_backdrop_texture()
   if not check(texture is Texture2D and texture.resource_path==row.runtime_path,"Actual consumer loads canonical imported ART_FILES resource"):continue
   check(texture.get_size()==Vector2(1672,941),"Imported resource preserves qualified original dimensions")
  check(game.menu_scroll.position==Vector2(8,245) and game.menu_scroll.size==Vector2(624,82),"Current bottom rail, never rejected centred overlay")
  check(descend.has_focus() and descend.get_signal_connection_list("pressed")==connections,"Same production Descend callback/focus")
  await draw()
  var filename=output.path_join(("consumer-cleared-chapter-%02d.png"if consumer else "candidate-cleared-chapter-%02d.png")%depth)
  if check(not FileAccess.file_exists(filename),"Never overwrite previous intended-use evidence"):
   var pixels=viewport.get_texture().get_image()
   check(pixels.get_size()==Vector2i(640,360) and pixels.save_png(filename)==OK,"Actual640x360 isolated HUD native pixels")
  toggle.pressed.emit();await draw()
  check(game.intermission_route.visible and game.menu.get_meta("chapter_intro",-1)==-1,"Actual accessible cancel returns to connected chart")
  check(game.menu_scroll.position==Vector2(430,45) and game.menu_scroll.size==Vector2(198,275),"Chart panel visibility/bounds restored")
  records.append({"chapter_index":chapter,"source":row.path,"source_sha256":row.sha256,"source_size":str(texture.get_size()),"png":filename,"png_sha256":FileAccess.get_sha256(filename),"actual_HUD_consumer":true,"actual_toggle_cancel":true,"arranged_completion_state":true,"candidate_integrated":consumer,"test_texture_injection":not consumer,"runtime_path":row.get("runtime_path","")})
  image=null;texture=null
 check(records.size()==3,"Three native candidate cards and restored cancel states")
 var manifest=output.path_join("card-preview-manifest.json")
 if check(not FileAccess.file_exists(manifest),"Fresh evidence manifest only"):
  var file=FileAccess.open(manifest,FileAccess.WRITE)
  if check(file!=null,"Open manifest"):
   file.store_string(JSON.stringify({"scope":"Synthetic arranged candidate-only intended-use HUD; not gameplay/earned/art9+ acceptance","gpu_adapter":device.get_device_name(),"records":records,"failures":failures,"audio":"silent stub, no player/listening","asset_mutation":false,"consumer_mode":consumer},"  ")+"\n");file.close()
 await finish()
func finish()->void:
 paused=false
 if is_instance_valid(viewport):viewport.free()
 await process_frame;await process_frame
 print("CANDIDATE_CHAPTER_CARDS failures=",failures," synthetic=true integrated=false earned_campaign=false")
 if failures==0:print("PASS actual HUD candidate card preview mechanics only")
 quit(0 if failures==0 else 1)
