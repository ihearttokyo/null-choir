extends SceneTree
## PR35 scaling contract: synthetic headless virtual root only; NO gameplay/image readback.
## Headless/Dummy proves content geometry, NOT Metal/GPU cost, beauty or FPS.
var failures := 0
class QuietMain:
 extends "res://scripts/main.gd"
 func _capture_game_mouse() -> void: pass
func _initialize() -> void:
 AudioServer.set_bus_mute(0,true)
 call_deferred("run")
func check(ok: bool,label: String) -> bool:
 if not ok:
  failures += 1
  push_error(label)
 return ok
func settle() -> void:
 await process_frame
 await process_frame
func run() -> void:
 if not check(DisplayServer.get_name()=="headless" and AudioServer.get_driver_name()=="Dummy","Scaling logic fixture requires headless/Dummy; never operate native GUI"):
  quit(1); return
 check(ProjectSettings.get_setting("display/window/size/viewport_width")==640 and ProjectSettings.get_setting("display/window/size/viewport_height")==360,"Original640x360 logical HUD coordinates")
 check(ProjectSettings.get_setting("display/window/stretch/mode")=="canvas_items" and ProjectSettings.get_setting("display/window/stretch/scale_mode")=="integer","Actual project enables canvas-items integer scaling")
 check(ProjectSettings.get_setting("rendering/renderer/rendering_method")=="mobile" and ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")==0,"Mobile selection and nearest art filtering preserved (not actual GPU verification)")
 check(root.content_scale_size==Vector2i(640,360) and root.content_scale_mode==Window.CONTENT_SCALE_MODE_CANVAS_ITEMS,"Live headless project root applies logical canvas-items configuration")
 # A real Main instance's test override cannot capture OR release the existing mode.
 # Never add it/start_level: this fixture does not create a gameplay scene/audio owner.
 var mouse_before: int = Input.mouse_mode
 var quiet = QuietMain.new()
 quiet._capture_game_mouse()
 check(Input.mouse_mode==mouse_before,"QuietMain override leaves input mode completely unchanged")
 quiet.free()
 # Headless root has NO OS GUI window. Use its actual stretch implementation directly.
 # Assert actual canvas transforms; Dummy texture metadata is not GPU allocation.
 var original_size: Vector2i = root.size
 var cases = [
  [Vector2i(640,360),Vector2i(640,360),1],
  [Vector2i(1280,720),Vector2i(1280,720),2],
  [Vector2i(1366,768),Vector2i(1280,720),2],
  [Vector2i(1000,700),Vector2i(640,360),1],
  [Vector2i(1920,1200),Vector2i(1920,1080),3]
 ]
 for row in cases:
  var window: Window = root
  window.size = row[0]
  await settle()
  var transform: Transform2D = window.get_final_transform()
  var logical: Rect2 = window.get_visible_rect()
  var extent: Vector2i = Vector2i(transform.basis_xform(logical.size))
  var expected_offset: Vector2 = Vector2(row[0]-row[1])*.5
  check(logical==Rect2(Vector2.ZERO,Vector2(640,360)),"Actual logical visible rect stays640x360")
  check(transform.get_scale()==Vector2.ONE*row[2],"Actual integer canvas transform at "+str(row[0]))
  check(extent==row[1] and transform.origin==expected_offset,"Actual transformed content extent and centered letterbox at "+str(row[0]))
  check(window.content_scale_size==Vector2i(640,360),"Fractional window never changes logical HUD coordinates")
  # Dummy ViewportTexture metadata is not a GPU allocation/readback oracle: on this
  # backend it includes integer stretch a second time. Retain observation, not a repin.
  print("SYNTHETIC_CANVAS_SCALE ",JSON.stringify({"virtual_window":str(window.size),"actual_transformed_content_extent":str(extent),"actual_letterbox_offset":str(transform.origin),"logical_hud":str(logical.size),"actual_integer_scale":str(transform.get_scale()),"dummy_texture_metadata_not_gpu_extent":str(window.get_texture().get_size()),"gpu_readback":false}))
 root.size = original_size
 await settle()
 check(Input.mouse_mode==mouse_before,"Entire fixture leaves original mouse mode untouched")
 if failures==0: print("PASS headless/Dummy canvas-items640logicalHUD/integer-content boundaries; NO GPU/FPS/gameplay/desktop/input-capture claim")
 quit(0 if failures==0 else 1)
