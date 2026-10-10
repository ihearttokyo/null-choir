extends SceneTree
const Main = preload("res://scripts/main.gd")
var game
var root_path = "user://metal_cache_fixture_"+str(Time.get_ticks_usec())
const FAMILIES = ["SceneForwardClusteredShaderRD", "SceneForwardMobileShaderRD", "CanvasShaderRD"]

func _initialize(): call_deferred("run")

func run():
	game = Main.new()
	if not expect(not game._has_metal_shader_cache(root_path), "Missing caches cannot pass"): return
	for family in FAMILIES:
		assert(DirAccess.make_dir_recursive_absolute(root_path+"/"+family+"/variant") == OK)
	if not expect(not game._has_metal_shader_cache(root_path), "Empty caches cannot pass"): return
	write_cache(FAMILIES[0], "actual.metal.cache")
	if not expect(not game._has_metal_shader_cache(root_path), "INTENDED RED: Forward+-only caches cannot certify Mobile/Metal"): return
	write_cache(FAMILIES[1], "only.vulkan.cache")
	write_cache(FAMILIES[2], "actual.metal.cache")
	if not expect(not game._has_metal_shader_cache(root_path), "UI plus Vulkan-only scene caches cannot pass"): return
	write_cache(FAMILIES[1], "actual.metal.cache")
	if not expect(game._has_metal_shader_cache(root_path), "Nested Mobile/Metal and UI caches must pass"): return
	assert(DirAccess.remove_absolute(root_path+"/"+FAMILIES[2]+"/variant/actual.metal.cache") == OK)
	if not expect(not game._has_metal_shader_cache(root_path), "Mobile without UI caches cannot pass"): return
	print("PASS cache guard rejects wrong renderer, empty/non-Metal and missing UI; nested Mobile/Metal plus UI accepted. Filename fixtures, not compiled shader evidence.")
	finish(0)

func write_cache(family: String, name: String):
	var file = FileAccess.open(root_path+"/"+family+"/variant/"+name, FileAccess.WRITE)
	assert(file != null)
	file.store_string("filename fixture, not compiled shader evidence")
	file.close()

func expect(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		finish(1)
	return ok

func finish(status: int):
	for family in FAMILIES:
		var folder = root_path+"/"+family+"/variant"
		for name in ["actual.metal.cache", "only.vulkan.cache"]:
			if FileAccess.file_exists(folder+"/"+name): DirAccess.remove_absolute(folder+"/"+name)
		DirAccess.remove_absolute(folder)
		DirAccess.remove_absolute(root_path+"/"+family)
	if DirAccess.dir_exists_absolute(root_path): DirAccess.remove_absolute(root_path)
	game.free()
	quit(status)
