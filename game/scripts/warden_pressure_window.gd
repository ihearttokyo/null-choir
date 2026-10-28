extends RefCounted
## Conservative source-bound region query. SpriteHitQuery occupancy remains independent.
const SpriteHitQuery = preload("res://scripts/sprite_hit_query.gd")
const Variation = preload("res://scripts/weapon_variation.gd")
const MANIFEST_PATH := "res://assets/art/regions/nursery-warden-node-v1.json"
const ATLAS_PATH := "res://assets/art/sprites/bodies-v1/nursery_warden.png"
const ATLAS_PNG_SHA256 := "516a2abc8ecf4bcbd8fea5074ca1b74982f2422c74b2e638a3f3077c01aa2506"
const ATLAS_RGBA_SHA256 := "70f9746a80f8ec593541171fb3d95e32ca8476947424cb166fd19bdec1fe6694"
const SOURCE_FRAME_RGBA_SHA256 := "bbc9f321ddb35c08b14229db1c875227861841245565d9737b9c9db5785f8330"
const SOURCE_FRAME_PNG_SHA256 := "2295a45ea872d5905de709e7db082cf92f3fdea0afa164b5b1e733a3c4fb3a92"
const SOURCE_BLEND_SHA256 := "2cf72084dbb678722c803fd9eb7df31e6ade2243d3c78356efaaae20348a9d32"
const RUNTIME_FRAME_RGBA_SHA256 := "2fee90a87e3950d085c71dd02ea68d9444af29507abc0407c4b80820603ed161"
const MASK_SHA256 := "8d9f75f77a44e613422a6c238c333c08294e6f2306d3f3956f2b19b7c3559d83"
const CELL := Vector2i(256,256)
const ATLAS := Vector2i(2048,1280)
const FRAME := 24 # attack pose row3, front direction0
const REGION := 1
const MULTIPLIER := 1.5
const CACHE_KEY := &"_null_choir_warden_node_region_v1"

static func sha256(data: PackedByteArray) -> String:
	var hash := HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK or hash.update(data) != OK: return ""
	return hash.finish().hex_encode()

static func _exact_int(value, low: int, high: int) -> int:
	if not (value is int or value is float) or not is_finite(float(value)) or value < low or value > high or float(value) != floor(float(value)): return -1
	return int(value)

static func _exact_pair(value, first: int, second: int) -> bool:
	return value is Array and value.size() == 2 and _exact_int(value[0],first,first) == first and _exact_int(value[1],second,second) == second

static func _manifest(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary or parsed.get("schema") != "null-choir-nursery-pressure-region-v1": return {}
	if parsed.get("actor_kind") != "nursery_warden" or parsed.get("region_id") != 1 or parsed.get("region_label") != "recessed_organism_pressure_node": return {}
	if parsed.get("runtime_atlas_path") != ATLAS_PATH or parsed.get("runtime_atlas_png_sha256") != ATLAS_PNG_SHA256 or parsed.get("runtime_atlas_rgba_sha256") != ATLAS_RGBA_SHA256: return {}
	if parsed.get("source_frame_path") != "source/art/bodies-v1/nursery_warden/frames/raw-attack-00.png" or parsed.get("source_frame_png_sha256") != SOURCE_FRAME_PNG_SHA256 or parsed.get("source_frame_rgba_sha256") != SOURCE_FRAME_RGBA_SHA256: return {}
	if parsed.get("source_blend_path") != "source/art/bodies-v1/nursery_warden/nursery_warden.blend" or parsed.get("source_blend_sha256") != SOURCE_BLEND_SHA256 or parsed.get("source_geometry_name") != "Recessed organism pressure node": return {}
	var frame = parsed.get("runtime_frame")
	if not frame is Dictionary or frame.get("pose_row") != 3 or frame.get("direction") != 0 or frame.get("atlas_frame") != FRAME or frame.get("rgba_sha256") != RUNTIME_FRAME_RGBA_SHA256: return {}
	if not _exact_pair(frame.get("atlas_cell_origin_xy"),0,768) or not _exact_pair(frame.get("size"),256,256): return {}
	var mask = parsed.get("mask")
	if not mask is Dictionary or mask.get("alpha_min_byte") != 128 or mask.get("mask_sha256") != MASK_SHA256 or mask.get("pixel_count") != 234: return {}
	return parsed

static func bind(sprite: Sprite3D) -> Dictionary:
	if not is_instance_valid(sprite) or sprite.texture == null or sprite.region_enabled or sprite.hframes != 8 or sprite.vframes != 5: return {}
	if sprite.texture is AtlasTexture or sprite.texture.resource_path != ATLAS_PATH or sprite.texture.get_size() != Vector2(ATLAS): return {}
	var texture: Texture2D = sprite.texture
	if texture.has_meta(CACHE_KEY):
		var prior: Dictionary = texture.get_meta(CACHE_KEY)
		if _query_cache_current(prior,texture): return prior
	if not FileAccess.file_exists(MANIFEST_PATH): return {}
	var file := FileAccess.open(MANIFEST_PATH,FileAccess.READ)
	if file == null or file.get_length() > 16384: return {}
	var manifest := _manifest(file.get_as_text())
	if manifest.is_empty(): return {}
	var cache := SpriteHitQuery._texture_cache(texture)
	if cache.is_empty() or cache.width != ATLAS.x or cache.height != ATLAS.y or sha256(cache.data) != ATLAS_RGBA_SHA256: return {}
	var frame_bytes := PackedByteArray()
	for y in range(CELL.y):
		var start: int = ((768+y)*ATLAS.x)*4
		frame_bytes.append_array(cache.data.slice(start,start+CELL.x*4))
	if sha256(frame_bytes) != RUNTIME_FRAME_RGBA_SHA256: return {}
	var mask_data: Variant = _validated_mask(manifest.get("mask",{}))
	if not mask_data is PackedByteArray: return {}
	var binding := {"valid":true,"texture":weakref(texture),"query_cache":cache,"rgba":cache.data,"mask":mask_data}
	texture.changed.connect(func(): binding.valid = false, Object.CONNECT_ONE_SHOT)
	texture.set_meta(CACHE_KEY,binding)
	return binding

static func _validated_mask(spec) -> Variant:
	if not spec is Dictionary or spec.get("coordinate_space") != "cell-local-x-y" or spec.get("alpha_min_byte") != 128: return null
	var runs = spec.get("runs_y_x0_x1")
	if not runs is Array or runs.size() != 53: return null
	var mask := PackedByteArray(); mask.resize(CELL.x*CELL.y)
	var total := 0
	var prev_y := -1; var prev_end := -1
	for run in runs:
		if not run is Array or run.size() != 3: return null
		var y := _exact_int(run[0],0,CELL.y-1); var x0 := _exact_int(run[1],0,CELL.x-1); var x1 := _exact_int(run[2],1,CELL.x)
		if y < 0 or x0 < 0 or x1 <= x0: return null
		if y < prev_y or (y == prev_y and x0 <= prev_end): return null
		for x in range(x0,x1):
			var index := y*CELL.x+x
			if mask[index] != 0: return null
			mask[index] = REGION; total += 1
		prev_y = y; prev_end = x1-1
	if total != 234 or sha256(mask) != MASK_SHA256: return null
	return mask

static func _query_cache_current(binding: Dictionary, texture: Texture2D) -> bool:
	if not binding.get("valid",false) or not binding.has("texture") or binding.texture.get_ref() != texture: return false
	if not texture.has_meta(SpriteHitQuery.CACHE_KEY) or not is_same(texture.get_meta(SpriteHitQuery.CACHE_KEY),binding.get("query_cache")):
		binding.valid = false
		return false
	return true

static func region(binding: Dictionary, sprite: Sprite3D, contact: Dictionary, actor_id: int) -> int:
	if not is_instance_valid(sprite) or sprite.texture == null or not _query_cache_current(binding,sprite.texture): return 0
	if sprite.texture.resource_path != ATLAS_PATH or sprite.region_enabled or sprite.hframes != 8 or sprite.vframes != 5 or sprite.frame != FRAME or contact.get("sprite_frame") != FRAME: return 0
	if contact.get("coverage") != "visible_sprite" or contact.get("collider_id") != actor_id: return 0
	if not contact.get("sprite_pixel") is Vector2i or not contact.get("frame_pixel") is Vector2i: return 0
	var local: Vector2i = contact.frame_pixel
	if local.x < 0 or local.y < 0 or local.x >= CELL.x or local.y >= CELL.y or contact.sprite_pixel != Vector2i(local.x,768+local.y): return 0
	var index: int = local.y*CELL.x+local.x
	if binding.mask[index] != REGION: return 0
	var rgba: PackedByteArray = binding.rgba
	var atlas_index: int = ((768+local.y)*ATLAS.x+local.x)*4
	if rgba[atlas_index+3] < 128: return 0
	var alpha := 1.0-sprite.transparency; var node: Node = sprite
	while node is SpriteBase3D:
		alpha *= (node as SpriteBase3D).modulate.a; node = node.get_parent()
	var cutoff: float = sprite.alpha_scissor_threshold if sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD else 0.0
	if not is_finite(alpha) or alpha <= 0 or not is_finite(cutoff) or cutoff < 0 or cutoff > 1: return 0
	if float(rgba[atlas_index+3])/255.0*alpha < cutoff: return 0
	return REGION

static func eligible(binding: Dictionary, sprite: Sprite3D, contact: Dictionary, actor_id: int, source: Node3D, player: Node3D, game: Node, level: Node, kind: String, telegraph_time: float, committed_variant: int, context: Dictionary, physics_tick: int) -> bool:
	if kind != "nursery_warden" or telegraph_time <= 0 or committed_variant != 0: return false
	if not is_instance_valid(game) or not game.playing or game.level != level or game.player != player: return false
	if not is_instance_valid(level) or not is_instance_valid(player) or source != player or source.get_parent() != level: return false
	var attack_kind = context.get("attack_kind"); var weapon: int = _exact_int(context.get("weapon"),0,5)
	if weapon < 0: return false
	if attack_kind == "melee":
		if weapon != 0: return false
	elif attack_kind == "hitscan":
		if weapon not in [1,2,3]: return false
	elif attack_kind == "piercing":
		if weapon != 5: return false
	else: return false
	var shot_tick: int = _exact_int(context.get("shot_tick"),0,2147483647)
	var shot_sequence: int = _exact_int(context.get("shot_sequence"),0,Variation.PERIOD-1)
	if shot_tick < 0 or shot_tick != physics_tick or shot_sequence < 0: return false
	if not source.has_method("last_shot_sequence") or source.last_shot_sequence(weapon) != shot_sequence: return false
	var state: Variant = game.get("state")
	if state == null or not state.get("shot_sequence") is Array or state.shot_sequence.size() != 6: return false
	if state.shot_sequence[weapon] != (shot_sequence+1)%Variation.PERIOD: return false
	return region(binding,sprite,contact,actor_id) == REGION

static func bonus_damage(base_amount: int) -> int:
	if base_amount <= 0: return base_amount
	return int(round(float(base_amount)*MULTIPLIER))
