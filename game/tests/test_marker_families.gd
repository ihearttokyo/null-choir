extends SceneTree

const PurposeContract = preload("res://tests/test_marker_purposes.gd")
const Player = preload("res://scripts/player.gd")
const GLYPH_PATH = "res://assets/art/hud/marker_glyphs.png"
const WEAPON_GLYPHS = ["impact_tool","rivet_pistol","scattergun","sawtooth_repeater","marrow_launcher","choir_disruptor"]
const FAMILY_ART = ["marker_ammo","marker_ammo_shells","marker_ammo_sawtooth","marker_ammo_marrow","marker_ammo_choir","marker_key","marker_ivorykey"]

class MarkerOwner extends Node:
	var state = preload("res://scripts/campaign.gd").new()
	var level

var owner
var texture_ref: WeakRef
var metadata: Dictionary

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var passed: bool = await check_families()
	cleanup()
	if passed: print("PASS eight-map marker families, normalized 0..5 IDs, visual-only weapon atlas identity, sharing/removal/cache teardown; no distance/visual-quality claim")
	quit(0 if passed else 1)

func check_families() -> bool:
	metadata = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/hud/marker_glyphs.json"))
	if not expect(metadata.contracts.weapons == WEAPON_GLYPHS and metadata.dimensions == [256.0,256.0] and metadata.cell_size == [64.0,64.0] and metadata.columns == 4,"Native atlas metadata fixes canonical full-square frame order"): return false
	for weapon in range(6):
		if not expect(String(Player.WEAPONS[weapon].asset).get_file() == WEAPON_GLYPHS[weapon],"Canonical WEAPONS identity: "+str(weapon)): return false
	owner = MarkerOwner.new()
	root.add_child(owner)
	var seen = {}
	var purposes = {}
	for index in range(8):
		owner.state.new_campaign(1)
		owner.state.level_index = index
		owner.level = load("res://scripts/level.gd").new()
		owner.add_child(owner.level)
		if not expect(owner.level.layout.load_level(index),"Authored family map loads"): return false
		var source: Dictionary = owner.level.layout.data.duplicate(true)
		owner.state.removed = [source.pickups[0].id]
		var state_before: Dictionary = owner.state.to_dict().duplicate(true)
		if not expect(owner.level.build(owner,index),"Authored family map builds"): return false
		var level = owner.level
		var colliders = PurposeContract.collision_nodes(level)
		var scenes = {}
		var nodes = []
		for spec in source.pickups+source.interactions:
			purposes[spec.kind] = true
			seen[PurposeContract.expected_art(spec)] = true
			if spec.id in owner.state.removed:
				if not expect(not level.markers.has(spec.id),"Exact removed ID suppressed: "+spec.id): return false
			else:
				if not check_marker(level,spec,scenes,nodes): return false
		if not expect(level.markers.size() == source.pickups.size()+source.interactions.size()-owner.state.removed.size(),"One marker per exact live authored ID"): return false
		# Schema allows integer-valued JSON floats and weapon index zero for both kinds.
		for kind in ["ammo","weapon"]:
			for weapon in range(6):
				for numeric in [weapon,float(weapon)]:
					var spec = {"id":"boundary_"+kind+"_"+str(weapon)+"_"+str(typeof(numeric)),"kind":kind,"weapon":numeric,"amount":1,"cell":source.pickups[0].cell.duplicate()}
					var before: Dictionary = spec.duplicate(true)
					level.markers[spec.id] = level._place_marker(spec)
					if not check_marker(level,spec,scenes,nodes): return false
					if not expect(spec == before,"Visual factory never normalizes/mutates its caller's ID/type/amount/cell"): return false
		for seal in ["blood","ivory","other_schema_valid_seal"]:
			var spec = {"id":"boundary_seal_"+seal,"kind":"key","key":seal,"cell":source.interactions[0].cell.duplicate()}
			level.markers[spec.id] = level._place_marker(spec)
			if not check_marker(level,spec,scenes,nodes): return false
		var ids: Array = level.markers.keys()
		for id in ids:
			level.remove_marker(id)
			if not expect(not level.markers.has(id),"Per-ID removal erases only its presentation record: "+id): return false
		await process_frame
		await process_frame
		for node_ref in nodes:
			if not expect(node_ref.get_ref() == null,"Marker and attached emblem freed together"): return false
		if not expect(level.markers.is_empty() and PurposeContract.collision_nodes(level) == colliders and level.layout.data == source and owner.state.to_dict() == state_before,"All visual family placements/removals preserve geometry, source and full campaign state"): return false
		level.free()
		owner.level = null
		await process_frame
		await process_frame
		for path in scenes:
			if not expect(scenes[path].get_ref() == null and not ResourceLoader.has_cached(path),"Level-owned exact-art scene/cache released: "+path): return false
		if texture_ref != null and not expect(texture_ref.get_ref() == null and not ResourceLoader.has_cached(GLYPH_PATH),"Shared atlas released with Level and emblems"): return false
		texture_ref = null
	if not expect(purposes.size() == 8,"All eight authored purpose types exercised"): return false
	for art in FAMILY_ART:
		if not expect(seen.has(art),"Authored subtype coverage: "+art): return false
	return true

func check_marker(level, spec: Dictionary, scenes: Dictionary, nodes: Array) -> bool:
	if not PurposeContract.check_marker(level,spec,expect): return false
	var art = PurposeContract.expected_art(spec)
	var marker = level.markers[spec.id]
	var path: String = marker.scene_file_path
	if not expect(level._model_scenes.has(art) and level._model_scenes[art] is PackedScene and level._model_scenes[art].resource_path == path and ResourceLoader.has_cached(path) and load(path) == level._model_scenes[art],"Used exact-art native scene owned/cached once: "+spec.id): return false
	scenes[path] = weakref(level._model_scenes[art])
	nodes.append(weakref(marker))
	var emblems = marker.find_children("*","Sprite3D",true,false)
	if spec.kind != "weapon":
		return expect(emblems.is_empty(),"Only weapon cradles add an identity emblem: "+spec.id)
	if not expect(emblems.size() == 1,"One visual-only world weapon emblem: "+spec.id): return false
	var emblem = emblems[0]
	if not expect(emblem.get_parent() == marker and emblem.texture is Texture2D and emblem.texture.resource_path == GLYPH_PATH and emblem.texture.get_size() == Vector2(256,256),"Weapon emblem uses the same native full-square atlas: "+spec.id): return false
	if texture_ref == null: texture_ref = weakref(emblem.texture)
	if not expect(texture_ref.get_ref() == emblem.texture,"Every weapon emblem reuses one Texture2D"): return false
	var frame = 10+int(spec.weapon)
	var region: Array = metadata.sprites[WEAPON_GLYPHS[int(spec.weapon)]].region
	if not expect(emblem.hframes == 4 and emblem.vframes == 4 and emblem.frame == frame and Rect2(region[0],region[1],region[2],region[3]) == Rect2((frame%4)*64,floori(frame/4.0)*64,64,64) and not emblem.region_enabled and emblem.centered and emblem.offset == Vector2.ZERO and emblem.scale == Vector3.ONE,"Exact canonical weapon frame, whole square and unstretched aspect: "+spec.id): return false
	if not expect(emblem.visible and emblem.position == Vector3(0,1.04,0) and is_equal_approx(emblem.pixel_size,0.008) and emblem.billboard == BaseMaterial3D.BILLBOARD_ENABLED and emblem.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and not emblem.shaded and emblem.double_sided and not emblem.fixed_size and not emblem.no_depth_test and emblem.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Nearest camera-facing visual-only emblem respects world depth, with no shadow or screen-size promise: "+spec.id): return false
	nodes.append(weakref(emblem))
	return true

func cleanup() -> void:
	if is_instance_valid(owner):
		if is_instance_valid(owner.level): owner.level.free()
		owner.level = null
		owner.free()
	owner = null

func expect(condition: bool, detail: String) -> bool:
	if not condition: push_error(detail)
	return condition
