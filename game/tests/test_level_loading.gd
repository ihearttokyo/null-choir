extends SceneTree

const Layout = preload("res://scripts/level_data.gd")
const Level = preload("res://scripts/level.gd")

class MissingArtLayout extends "res://scripts/level_data.gd":
	func _art_exists(_id: String) -> bool: return false

func _initialize() -> void:
	# Parent may run this against an isolated malformed/missing source, never authored JSON.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--expect-load-error="):
			var layout = Layout.new()
			layout.data = {"previous":"accepted"}
			layout.tiles = {Vector2i(7,9):true}
			if not rejected(layout,0,argument.trim_prefix("--expect-load-error=")): return
			print("PASS actual isolated invalid source: error and atomic previous data/tiles")
			quit(0)
			return
	var layout = Layout.new()
	for index in range(Layout.FILES.size()):
		var path: String = "res://data/"+Layout.FILES[index]+".json"
		var source: String = FileAccess.get_file_as_string(path)
		var parsed: Dictionary = JSON.parse_string(source)
		if not expect(layout.load_level(index),path+": "+layout.load_error): return
		if not expect(layout.load_error.is_empty() and layout.data == parsed,"Accepted source remains unchanged: "+path): return
		if not expect(FileAccess.get_file_as_string(path) == source,"Loader never writes authored JSON: "+path): return
		var expected_tiles: Dictionary = {}
		for rect in parsed.rects:
			for x in range(rect[0],rect[2]+1):
				for z in range(rect[1],rect[3]+1): expected_tiles[Vector2i(x,z)] = true
		if not expect(layout.tiles == expected_tiles,"Exact authored floor expansion: "+path): return
		if not rejected(layout,-1,"index") or not rejected(layout,8,"index"): return
	var unavailable = MissingArtLayout.new()
	unavailable.data = layout.data
	unavailable.tiles = layout.tiles
	if not rejected(unavailable,0,"heroes[0].id"): return
	var level = Level.new()
	level.layout = unavailable
	var previous_owner = Node.new()
	level.game = previous_owner
	if not expect(not level.build(null,0),"Build propagates loader failure"): return
	if not expect(level.game == previous_owner and level.get_child_count() == 0 and level._model_scenes.is_empty() and level.doors.is_empty() and level.markers.is_empty() and level.machine_lights.is_empty(),"Rejected build publishes no owner, geometry, models or gameplay"): return
	level.free()
	previous_owner.free()
	print("PASS production loader: eight exact sources/tiles, nonmutation, invalid indices, art boundary and empty failed build")
	quit(0)

func rejected(layout, index: int, field: String) -> bool:
	var previous_data: Dictionary = layout.data
	var previous_tiles: Dictionary = layout.tiles
	var data_before: Dictionary = previous_data.duplicate(true)
	var tiles_before: Dictionary = previous_tiles.duplicate(true)
	if not expect(not layout.load_level(index),"Reject invalid source/index before publication"): return false
	if not expect(field in layout.load_error,"Actionable error names "+field+": "+layout.load_error): return false
	return expect(is_same(layout.data,previous_data) and is_same(layout.tiles,previous_tiles) and layout.data == data_before and layout.tiles == tiles_before,"Failure preserves previous data/tiles and their aliases atomically")

func expect(ok: bool, detail: String) -> bool:
	if not ok:
		push_error("Level loading: "+detail)
		quit(1)
	return ok
