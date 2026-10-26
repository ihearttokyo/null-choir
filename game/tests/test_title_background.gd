extends SceneTree
const Hud = preload("res://scripts/hud.gd")
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var hud = Hud.new()
 if not hud.has_method("menu_backdrop_texture"):
  hud.free()
  push_error("INTENDED RED: title backdrop needs a native authored texture boundary")
  call_deferred("quit", 1)
  return
 var image: Texture2D = hud.menu_backdrop_texture()
 assert(image != null and image.get_width() == 640 and image.get_height() == 360)
 assert(image == hud.menu_backdrop_texture())
 hud.free()
 print("PASS native authored title texture, exact640x360 dimensions and local resource ownership; no rendered/finalart or coldlaunch claim")
 call_deferred("quit", 0)
