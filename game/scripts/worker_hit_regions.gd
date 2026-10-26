extends RefCounted
## Explicit authored geometry IDs, NOT occupancy-derived anatomy.
## No shipping manifest is supplied with code preparation. Missing/bad binding
## means region0 and preserves ordinary damage; it never rejects the beauty hit.
const SpriteHitQuery = preload("res://scripts/sprite_hit_query.gd")
const CACHE_KEY := &"_null_choir_worker_regions_v1"
const ATLAS_SIZE := Vector2i(1024, 768)
const CELL_SIZE := Vector2i(128, 128)
const CLUTCH := 1
const VENT_POSE := 5

static func pose_rows(texture: Texture2D) -> int:
	if texture == null: return 0
	if texture.get_size() == Vector2(1024,640): return 5
	if texture.get_size() == Vector2(1024,768): return 6
	return 0 # Unrecognized worker layout has no capsule/guessed-frame fallback.

static func sha256(data: PackedByteArray) -> String:
	var hash_context := HashingContext.new()
	if hash_context.start(HashingContext.HASH_SHA256) != OK: return ""
	if hash_context.update(data) != OK: return ""
	return hash_context.finish().hex_encode()

static func bind(sprite: Sprite3D, manifest_path: String) -> Dictionary:
	if not is_instance_valid(sprite) or sprite.texture == null: return {}
	var texture: Texture2D = sprite.texture
	if texture.has_meta(CACHE_KEY):
		var cached: Dictionary = texture.get_meta(CACHE_KEY)
		if cached.get("manifest_path") == manifest_path and _query_cache_current(cached,texture): return cached
	if not FileAccess.file_exists(manifest_path): return {}
	var manifest_file := FileAccess.open(manifest_path,FileAccess.READ)
	if manifest_file == null or manifest_file.get_length() > 65536: return {}
	var manifest := _manifest_from_json(manifest_file.get_as_text())
	if manifest.is_empty(): return {}
	# IDs are byte-per-texel, not a sampled/imported color texture. The source
	# PNG hash is provenance; imported RGBA hash below is the runtime authority.
	var mask_path = manifest.get("mask_path")
	if not mask_path is String or not mask_path.begins_with("res://assets/art/regions/") or not mask_path.ends_with(".regions"): return {}
	if not FileAccess.file_exists(mask_path): return {}
	var mask_file := FileAccess.open(mask_path,FileAccess.READ)
	if mask_file == null or mask_file.get_length() != ATLAS_SIZE.x*ATLAS_SIZE.y: return {}
	var mask := mask_file.get_buffer(ATLAS_SIZE.x*ATLAS_SIZE.y)
	var binding := bind_data(sprite,manifest,mask)
	if binding.is_empty(): return {}
	binding.manifest_path = manifest_path
	texture.set_meta(CACHE_KEY,binding)
	return binding

static func _json_bounded_integer(value, minimum: int, maximum: int):
	# JSON numbers are FLOAT in this engine, but internal schemas are INT.
	# Exact, finite, bounded integrality only: never bool/string/coercive int().
	if not (value is int or value is float): return null
	if not is_finite(float(value)) or value < minimum or value > maximum: return null
	if float(value) != floor(float(value)): return null
	return int(value) # Safe only AFTER exact bounds+integrality checks above.

static func _normalize_json_manifest(parsed: Dictionary) -> Dictionary:
	# Only the file-decode boundary normalizes representations. bind_data() and
	# all runtime provenance/alpha/frame/cache validators remain unchanged.
	var manifest: Dictionary = parsed.duplicate(true)
	var exact_fields := {"width":1024,"height":768,"hframes":8,"vframes":6,"vent_pose":5,"alpha_min_byte":128}
	for key in exact_fields:
		var integer = _json_bounded_integer(manifest.get(key),exact_fields[key],exact_fields[key])
		if integer == null: return {}
		manifest[key] = integer
	var cell = manifest.get("cell_size")
	if not cell is Array or cell.size() != 2: return {}
	var x = _json_bounded_integer(cell[0],128,128)
	var y = _json_bounded_integer(cell[1],128,128)
	if x == null or y == null: return {}
	manifest.cell_size = [x,y]
	var frames = manifest.get("frames")
	if not frames is Array or frames.size() != 48: return {}
	for frame in range(48):
		if not frames[frame] is Dictionary: return {}
		var row: Dictionary = frames[frame]
		for key in ["frame","pose","direction","labels"]:
			var expected: int = frame if key == "frame" else frame/8 if key == "pose" else frame%8 if key == "direction" else 0
			var maximum: int = 16384 if key == "labels" else expected
			var integer = _json_bounded_integer(row.get(key),expected,maximum)
			if integer == null: return {}
			row[key] = integer
	return manifest

static func _manifest_from_json(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	return _normalize_json_manifest(parsed) if parsed is Dictionary else {}

static func bind_data(sprite: Sprite3D, manifest: Dictionary, mask: PackedByteArray) -> Dictionary:
	# Also the synthetic-fixture seam. Production calls bind(), not a fabricated
	# manifest. This validator checks all48frames before enabling any region.
	if not is_instance_valid(sprite) or sprite.texture == null or sprite.texture is AtlasTexture: return {}
	if sprite.region_enabled or sprite.hframes != 8 or sprite.vframes != 6: return {}
	var texture: Texture2D = sprite.texture
	if texture.resource_path != manifest.get("beauty_path",""): return {}
	if manifest.get("schema") != "null-choir-worker-regions-v1" or manifest.get("kind") != "worker": return {}
	if manifest.get("width") != ATLAS_SIZE.x or manifest.get("height") != ATLAS_SIZE.y or manifest.get("hframes") != 8 or manifest.get("vframes") != 6 or manifest.get("vent_pose") != VENT_POSE: return {}
	if manifest.get("cell_size") != [128,128] or manifest.get("alpha_min_byte") != 128: return {}
	if manifest.get("regions") != {"0":"ordinary","1":"pressure_clutch"}: return {}
	if not _hash_string(manifest.get("beauty_source_sha256")) or not _hash_string(manifest.get("source_blend_sha256")): return {}
	var geometry_names = manifest.get("authored_objects")
	if not geometry_names is Array or geometry_names.is_empty(): return {}
	for object_name in geometry_names:
		if not object_name is String or object_name.is_empty(): return {}
	var cache := SpriteHitQuery._texture_cache(texture)
	if cache.is_empty() or cache.width != ATLAS_SIZE.x or cache.height != ATLAS_SIZE.y: return {}
	var beauty: PackedByteArray = cache.data
	if sha256(beauty) != manifest.get("beauty_rgba_sha256"): return {}
	if mask.size() != ATLAS_SIZE.x*ATLAS_SIZE.y or sha256(mask) != manifest.get("mask_sha256"): return {}
	var frames = manifest.get("frames")
	if not frames is Array or frames.size() != 48: return {}
	var total_labels := 0
	for frame in range(48):
		var row = frames[frame]
		if not row is Dictionary or row.get("frame") != frame or row.get("direction") != frame%8 or row.get("pose") != frame/8: return {}
		var labels := 0
		var opaque := 0
		var frame_mask := PackedByteArray()
		var frame_beauty := PackedByteArray()
		for y in range(CELL_SIZE.y):
			var start: int = ((frame/8*CELL_SIZE.y+y)*ATLAS_SIZE.x+frame%8*CELL_SIZE.x)
			frame_mask.append_array(mask.slice(start,start+CELL_SIZE.x))
			frame_beauty.append_array(beauty.slice(start*4,(start+CELL_SIZE.x)*4))
			for x in range(CELL_SIZE.x):
				var index := start+x
				var accepted: bool = beauty[index*4+3] >= 128
				if accepted: opaque += 1
				if mask[index] not in [0,CLUTCH]: return {}
				if mask[index] == CLUTCH:
					if not accepted or frame >= 32: return {}
					labels += 1
		# Strict subset, independently in each labeled frame. Zero-label views
		# are legitimate when the actual clutch is occluded (never mirror it).
		if labels > 0 and labels >= opaque: return {}
		if row.get("labels") != labels or row.get("mask_sha256") != sha256(frame_mask) or row.get("beauty_rgba_sha256") != sha256(frame_beauty): return {}
		total_labels += labels
	if total_labels <= 0: return {}
	var binding := {"vent_pose":VENT_POSE,"valid":true,"texture":weakref(texture),"mask":mask,"beauty":beauty,"query_cache":cache}
	# Invalidation marks already-held actor bindings invalid too. No strong
	# texture capture/global table; image updates cannot keep old anatomy alive.
	texture.changed.connect(func(): binding.valid = false, Object.CONNECT_ONE_SHOT)
	return binding

static func region(binding: Dictionary, sprite: Sprite3D, contact: Dictionary, actor_id: int) -> int:
	if not binding.get("valid",false) or not is_instance_valid(sprite) or sprite.texture == null: return 0
	if not _query_cache_current(binding,sprite.texture): return 0
	if binding.texture.get_ref() != sprite.texture or sprite.region_enabled or sprite.hframes != 8 or sprite.vframes != 6: return 0
	if contact.get("coverage") != "visible_sprite" or contact.get("collider_id") != actor_id: return 0
	if not contact.get("sprite_frame") is int or contact.sprite_frame != sprite.frame or sprite.frame < 0 or sprite.frame >= 32: return 0
	if not contact.get("sprite_pixel") is Vector2i or not contact.get("frame_pixel") is Vector2i: return 0
	var local: Vector2i = contact.frame_pixel
	if local.x < 0 or local.y < 0 or local.x >= CELL_SIZE.x or local.y >= CELL_SIZE.y: return 0
	var pixel := Vector2i(sprite.frame%8,sprite.frame/8)*CELL_SIZE+local
	if pixel != contact.sprite_pixel: return 0
	var index: int = pixel.y*ATLAS_SIZE.x+pixel.x
	# Accepted contact is authoritative, but independently recheck the exact
	# bound alpha against the current scissor/transparency too.
	var alpha: float = 1.0-sprite.transparency
	var node: Node = sprite
	while node is SpriteBase3D:
		alpha *= (node as SpriteBase3D).modulate.a
		node = node.get_parent()
	var cutoff: float = sprite.alpha_scissor_threshold if sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD else 0.0
	if not is_finite(alpha) or alpha <= 0 or not is_finite(cutoff) or cutoff < 0 or cutoff > 1: return 0
	if float(binding.beauty[index*4+3])/255.0*alpha < cutoff: return 0
	return binding.mask[index]

static func _query_cache_current(binding: Dictionary, texture: Texture2D) -> bool:
	# Query.invalidate_texture() is also mandatory for updates that do not emit
	# changed. Its cache dictionary is the exact generation token; equal bytes
	# in a replacement dictionary do not make old anatomical provenance current.
	# Metadata/reference checks only: no per-hit decode, copy, hash or rebuild.
	if not binding.get("valid",false) or binding.texture.get_ref() != texture: return false
	if not texture.has_meta(SpriteHitQuery.CACHE_KEY) or not is_same(texture.get_meta(SpriteHitQuery.CACHE_KEY),binding.get("query_cache")):
		binding.valid = false
		return false
	return true

static func _hash_string(value) -> bool:
	if not value is String or value.length() != 64: return false
	for character in value:
		if not character in "0123456789abcdef": return false
	return true
