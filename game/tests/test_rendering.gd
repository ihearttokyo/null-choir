extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 if DisplayServer.get_name()=="headless": push_error("Native rendering contract requires actual GPU");quit(1);return
 if RenderingServer.get_current_rendering_method()!="mobile" or RenderingServer.get_current_rendering_driver_name()!="metal":
  push_error("Apple Silicon renderer must actually select Mobile/native Metal (intended RED)")
  quit(1)
  return
 await process_frame
 await RenderingServer.frame_post_draw
 if root.get_texture().get_size()!=Vector2(640,360): push_error("Native render target must remain640x360");quit(1);return
 print("PASS native Apple Silicon Mobile/Metal renderer, original640x360 target")
 quit()
