extends RefCounted
## Visible occupancy only; never anatomy, a weakpoint, or a damage multiplier.
## Source geometry follows Godot SpriteBase3D::draw_texture_rect / Sprite3D::_draw
## and BaseMaterial3D's BILLBOARD_ENABLED + BILLBOARD_KEEP_SCALE shader:
## https://github.com/godotengine/godot/blob/ed1daf0bf/scene/3d/sprite_3d.cpp
## https://github.com/godotengine/godot/blob/ed1daf0bf/scene/resources/material.cpp
## Standard Enemy sprites: axis Z, full billboard, nearest sampling, integer atlas
## cells, transparent/discard (or ordinary alpha), no custom materials/fixed-size.
## Unsupported visual geometry fails closed, NEVER falls back to its capsule.
const SOURCE_ENGINE_REVISION := "ed1daf0bf" # Installed Godot4.7.2; geometry verified by native fixtures.
const MAX_ACTORS := 256
const MAX_TEXTURE_PIXELS := 4194304
const MAX_FRAME_PIXELS := 262144
const MAX_FRAME_CACHE := 64
const CACHE_KEY := &"_null_choir_visible_hit_cache_v1"
const EPS := 0.000001

static func cast(space: PhysicsDirectSpaceState3D, origin: Vector3, end: Vector3, camera: Camera3D, actors: Array, exclude: Array[RID] = [], mask: int = 5) -> Dictionary:
	if space == null or not origin.is_finite() or not end.is_finite() or origin.distance_squared_to(end) <= EPS*EPS or actors.size() > MAX_ACTORS:
		return {}
	if _camera_current(camera) and camera.get_world_3d().direct_space_state != space: return {}
	var ignored: Array[RID] = exclude.duplicate()
	# Movement capsules do not define sprite occupancy. Exclude even a dead,
	# hidden, invalid or retired visual actor, so it cannot become a fallback hit.
	for actor in actors:
		if is_instance_valid(actor) and actor is CollisionObject3D and actor.has_method("visual_hit_sprite"):
			if not actor.get_rid() in ignored: ignored.append(actor.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, end, mask)
	query.hit_from_inside = true
	query.exclude = ignored
	var native: Dictionary = {}
	for attempt in range(MAX_ACTORS + 1):
		native = space.intersect_ray(query)
		if native.is_empty(): break
		var body = native.get("collider")
		if not is_instance_valid(body) or not body.has_method("visual_hit_sprite"): break
		# A stale/unlisted real visual body must not leak a capsule damage hit.
		if attempt == MAX_ACTORS: return {}
		ignored.append(body.get_rid())
		query.exclude = ignored
	var best: Dictionary = native
	var best_distance: float = origin.distance_squared_to(native.position) if not native.is_empty() else INF
	var best_id: int = 0
	var best_authored: String = ""
	for actor in actors:
		if not is_instance_valid(actor) or not actor is CollisionObject3D or actor.get_rid() in exclude or (actor.collision_layer & mask) == 0: continue
		var geometry := _geometry(actor, camera)
		if geometry.is_empty(): continue
		var hit := _intersect(geometry, origin, end)
		if hit.is_empty(): continue
		var distance := origin.distance_squared_to(hit.position)
		# A wall/nonvisual collider wins exact/near ties; do not shoot through it.
		if not native.is_empty() and distance >= origin.distance_squared_to(native.position) - EPS: continue
		var id: int = actor.get_instance_id()
		var authored: String = str(actor.get("id"))
		if authored.is_empty(): authored = "~" + str(id)
		if distance > best_distance + EPS: continue
		if absf(distance-best_distance) <= EPS and best_id != 0 and (authored > best_authored or (authored == best_authored and id >= best_id)): continue
		hit.merge({"collider":actor, "collider_id":id, "rid":actor.get_rid(), "shape":-1, "face_index":-1, "coverage":"visible_sprite"})
		best = hit
		best_distance = distance
		best_id = id
		best_authored = authored
	return best

static func candidate_points(actor, camera: Camera3D, origin: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not origin.is_finite(): return result
	var geometry := _geometry(actor, camera)
	if geometry.is_empty(): return result
	for pixel in _frame_pixels(geometry):
		result.append(_world_pixel(geometry, pixel))
	# A bounded set of actual occupied pixel centers; this is not a promise to
	# discover every partially exposed texel or a generic head/torso classification.
	result.sort_custom(func(a: Vector3, b: Vector3): return a.distance_squared_to(origin) < b.distance_squared_to(origin))
	return result

static func _camera_current(camera: Camera3D) -> bool:
	return is_instance_valid(camera) and not camera.is_queued_for_deletion() and camera.is_inside_tree() and camera.get_world_3d() != null

static func _geometry(actor, camera: Camera3D) -> Dictionary:
	if not _camera_current(camera) or not is_instance_valid(actor) or not actor is CollisionObject3D or actor.is_queued_for_deletion() or not actor.is_inside_tree(): return {}
	if not actor.has_method("visual_hit_sprite") or not actor.has_method("_current_map") or not actor.call("_current_map"): return {}
	var hp = actor.get("hp")
	if not (hp is int or hp is float) or not is_finite(float(hp)) or hp <= 0: return {}
	var sprite := actor.call("visual_hit_sprite") as Sprite3D
	if not is_instance_valid(sprite) or sprite.is_queued_for_deletion() or not sprite.is_inside_tree() or not actor.is_ancestor_of(sprite) or not sprite.is_visible_in_tree(): return {}
	if sprite.get_world_3d() != camera.get_world_3d() or (sprite.layers & camera.cull_mask) == 0: return {}
	if sprite.axis != Vector3.AXIS_Z or sprite.billboard != BaseMaterial3D.BILLBOARD_ENABLED or sprite.fixed_size or sprite.no_depth_test or not sprite.transparent: return {}
	if sprite.material_override != null or sprite.material_overlay != null or sprite.texture_filter != BaseMaterial3D.TEXTURE_FILTER_NEAREST: return {}
	if sprite.alpha_cut not in [SpriteBase3D.ALPHA_CUT_DISCARD, SpriteBase3D.ALPHA_CUT_DISABLED]: return {}
	# Distance fades and stochastic/AA coverage need a separate render contract.
	if sprite.visibility_range_begin != 0 or sprite.visibility_range_end != 0 or sprite.alpha_antialiasing_mode != BaseMaterial3D.ALPHA_ANTIALIASING_OFF: return {}
	var texture: Texture2D = sprite.texture
	if texture == null or texture is AtlasTexture: return {}
	var cache := _texture_cache(texture)
	if cache.is_empty(): return {}
	var region := Rect2i(0, 0, cache.width, cache.height)
	if sprite.region_enabled:
		var requested: Rect2 = sprite.region_rect
		region = Rect2i(requested)
		if Rect2(region) != requested or not Rect2i(0, 0, cache.width, cache.height).encloses(region): return {}
	if sprite.hframes < 1 or sprite.vframes < 1 or region.size.x % sprite.hframes != 0 or region.size.y % sprite.vframes != 0: return {}
	var frame_size := Vector2i(region.size.x / sprite.hframes, region.size.y / sprite.vframes)
	if frame_size.x <= 0 or frame_size.y <= 0 or frame_size.x*frame_size.y > MAX_FRAME_PIXELS: return {}
	var frame: int = sprite.frame
	if frame < 0 or frame >= sprite.hframes*sprite.vframes: return {}
	var source := Rect2i(region.position + Vector2i(frame % sprite.hframes, frame / sprite.hframes)*frame_size, frame_size)
	var pixel_size: float = sprite.pixel_size
	var sx: float = sprite.global_basis.x.length()*pixel_size
	var sy: float = sprite.global_basis.y.length()*pixel_size
	if not is_finite(sx) or not is_finite(sy) or sx <= EPS or sy <= EPS or not sprite.offset.is_finite() or not sprite.global_position.is_finite(): return {}
	var basis: Basis = camera.get_camera_transform().basis.orthonormalized()
	if not basis.is_finite(): return {}
	var alpha: float = 1.0 - sprite.transparency
	var node: Node = sprite
	while node is SpriteBase3D:
		alpha *= (node as SpriteBase3D).modulate.a
		node = node.get_parent()
	if not is_finite(alpha) or alpha <= 0: return {}
	var threshold: float = sprite.alpha_scissor_threshold if sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD else 0.0
	if not is_finite(threshold) or threshold < 0 or threshold > 1: return {}
	var cutoff: float = threshold/alpha
	if cutoff > 1: return {}
	var offset: Vector2 = sprite.offset - Vector2(frame_size)*0.5 if sprite.centered else sprite.offset
	return {"center":sprite.global_position, "right":basis.x, "up":basis.y, "normal":basis.z, "sx":sx, "sy":sy, "offset":offset, "source":source, "frame":frame, "flip_h":sprite.flip_h, "flip_v":sprite.flip_v, "cutoff":cutoff, "cache":cache, "double_sided":sprite.double_sided}

static func _intersect(g: Dictionary, origin: Vector3, end: Vector3) -> Dictionary:
	var ray := end-origin
	var denominator: float = g.normal.dot(ray)
	if absf(denominator) <= EPS or (not g.double_sided and denominator >= 0): return {}
	var t: float = g.normal.dot(g.center-origin)/denominator
	if t < 0 or t > 1: return {}
	var position: Vector3 = origin + ray*t
	var local: Vector3 = position-g.center
	var source: Rect2i = g.source
	var uv := Vector2((local.dot(g.right)/g.sx-g.offset.x)/source.size.x, 1.0-(local.dot(g.up)/g.sy-g.offset.y)/source.size.y)
	if uv.x < 0 or uv.x >= 1 or uv.y < 0 or uv.y >= 1: return {}
	if g.flip_h: uv.x = 1.0-uv.x
	if g.flip_v: uv.y = 1.0-uv.y
	var frame_pixel := Vector2i(mini(source.size.x-1, floori(uv.x*source.size.x)), mini(source.size.y-1, floori(uv.y*source.size.y)))
	var pixel := source.position+frame_pixel
	if not _opaque(g.cache, pixel, g.cutoff): return {}
	return {"position":position, "normal":g.normal if denominator < 0 else -g.normal, "sprite_frame":g.frame, "sprite_pixel":pixel, "frame_pixel":frame_pixel}

static func _opaque(cache: Dictionary, pixel: Vector2i, cutoff: float) -> bool:
	var data: PackedByteArray = cache.data
	var alpha: int = data[(pixel.y*int(cache.width)+pixel.x)*4+3]
	return alpha > 0 and float(alpha)/255.0 >= cutoff

static func _world_pixel(g: Dictionary, pixel: Vector2i) -> Vector3:
	var source: Rect2i = g.source
	var uv := (Vector2(pixel-source.position)+Vector2(0.5,0.5))/Vector2(source.size)
	if g.flip_h: uv.x = 1.0-uv.x
	if g.flip_v: uv.y = 1.0-uv.y
	return g.center + g.right*((g.offset.x+uv.x*source.size.x)*g.sx) + g.up*((g.offset.y+(1.0-uv.y)*source.size.y)*g.sy)

static func _frame_pixels(g: Dictionary) -> Array:
	var cache: Dictionary = g.cache
	var frames: Dictionary = cache.frames
	var key: String = var_to_bytes([g.source, g.cutoff]).hex_encode()
	if frames.has(key): return frames[key]
	var source: Rect2i = g.source
	var bins: Array = []
	var distances: Array[float] = []
	for i in range(9):
		bins.append(null)
		distances.append(INF)
	for y in range(source.size.y):
		for x in range(source.size.x):
			var pixel := source.position+Vector2i(x,y)
			if not _opaque(cache, pixel, g.cutoff): continue
			var bx: int = mini(2,x*3/source.size.x)
			var by: int = mini(2,y*3/source.size.y)
			var bin_index: int = by*3+bx
			var target := Vector2((bx+0.5)*source.size.x/3.0, (by+0.5)*source.size.y/3.0)
			var distance := (Vector2(x+0.5,y+0.5)-target).length_squared()
			if distance < distances[bin_index]:
				distances[bin_index] = distance
				bins[bin_index] = pixel
	var result: Array = []
	for pixel in bins:
		if pixel != null: result.append(pixel)
	if frames.size() >= MAX_FRAME_CACHE: frames.erase(frames.keys()[0])
	frames[key] = result
	return result

static func invalidate_texture(texture: Texture2D) -> void:
	# ImageTexture.update() callers that do not emit changed must call this
	# AFTER the renderer commits the new data (dummy headless updates may not).
	if is_instance_valid(texture) and texture.has_meta(CACHE_KEY):
		var cache: Dictionary = texture.get_meta(CACHE_KEY)
		var listener: Callable = cache.get("listener", Callable())
		if listener.is_valid() and texture.changed.is_connected(listener): texture.changed.disconnect(listener)
		texture.remove_meta(CACHE_KEY)

static func _texture_cache(texture: Texture2D) -> Dictionary:
	if texture.has_meta(CACHE_KEY): return texture.get_meta(CACHE_KEY)
	var width: int = texture.get_width()
	var height: int = texture.get_height()
	if width <= 0 or height <= 0 or width*height > MAX_TEXTURE_PIXELS: return {}
	var image: Image = texture.get_image()
	if image == null or image.is_empty(): return {}
	if image.is_compressed() and image.decompress() != OK: return {}
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() != width or image.get_height() != height: return {}
	var data: PackedByteArray = image.get_data()
	if data.size() < width*height*4: return {}
	var cache := {"width":width,"height":height,"data":data,"frames":{}}
	texture.set_meta(CACHE_KEY, cache)
	# Cache belongs to its texture, never to a growing static strong-ref table.
	# The signal closure captures ONLY a WeakRef, preventing a resource cycle.
	var owner: WeakRef = weakref(texture)
	var listener: Callable = func():
		var changed = owner.get_ref()
		if changed != null: invalidate_texture(changed)
	cache.listener = listener
	texture.changed.connect(listener)
	return cache
