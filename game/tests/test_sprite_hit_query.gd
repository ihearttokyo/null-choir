extends SceneTree
const Query = preload("res://scripts/sprite_hit_query.gd")
class Actor extends CharacterBody3D:
	var id: String = ""
	var hp: int = 100
	var current_map: bool = true
	var sprite: Sprite3D
	func _current_map() -> bool: return current_map
	func visual_hit_sprite() -> Sprite3D: return sprite
class Synthetic extends StaticBody3D:
	func take_damage(_amount: int, _source, _context: Dictionary = {}) -> void: pass
var scene: Node3D
var camera: Camera3D
var front: Actor
var back: Actor
var failures := 0
func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func atlas(pixels: Dictionary) -> ImageTexture:
	var image := Image.create(32,20,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	for frame in pixels:
		for spec in pixels[frame]:
			var pixel: Vector2i = Vector2i(int(frame)%8*4,int(frame)/8*4)+spec[0]
			image.set_pixelv(pixel,Color(1,1,1,float(spec[1])))
	return ImageTexture.create_from_image(image)
func actor(id: String, z: float, texture: Texture2D) -> Actor:
	var body := Actor.new()
	body.id = id
	body.collision_layer = 4
	body.collision_mask = 1
	scene.add_child(body)
	body.position.z = z
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = .35
	shape.height = 1.0
	collider.shape = shape
	collider.position.y = .5
	body.add_child(collider)
	body.sprite = Sprite3D.new()
	body.sprite.texture = texture
	body.sprite.hframes = 8
	body.sprite.vframes = 5
	body.sprite.pixel_size = .5
	body.sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	body.sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	body.sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	body.sprite.alpha_scissor_threshold = .5
	body.add_child(body.sprite)
	return body
func cast_at(x: float, y: float, end_z: float = -12, actors: Array = [])->Dictionary:
	return Query.cast(scene.get_world_3d().direct_space_state,Vector3(x,y,0),Vector3(x,y,end_z),camera,[front,back] if actors.is_empty() else actors)
func opaque(x: int, y: int, alpha: float = 1.0) -> Array: return [Vector2i(x,y),alpha]
func box(position: Vector3, layer: int = 1):
	var body := Synthetic.new()
	body.collision_layer = layer
	scene.add_child(body)
	body.position = position
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4,4,.1)
	collider.shape = shape
	body.add_child(collider)
	return body
func run() -> void:
	check(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1,"Unmodified production clock")
	scene = Node3D.new()
	root.add_child(scene)
	camera = Camera3D.new()
	scene.add_child(camera)
	front = actor("front",-4,atlas({0:[opaque(3,1)],1:[opaque(0,2)],8:[opaque(2,0)]}))
	back = actor("back",-7,atlas({0:[opaque(1,1),opaque(3,1)]}))
	await physics_frame
	await physics_frame
	var space = scene.get_world_3d().direct_space_state
	var native = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-.25,.25,0),Vector3(-.25,.25,-12),4))
	check(native.get("collider") == front,"SETUP transparent front texel is inside actual native front capsule")
	var hit := cast_at(-.25,.25)
	check(hit.get("collider") == back and hit.get("coverage") == "visible_sprite","Transparent front passes to actual opaque back plane")
	hit = cast_at(.75,.25)
	check(hit.get("collider") == front and hit.get("sprite_pixel") == Vector2i(3,1) and hit.position == Vector3(.75,.25,-4),"Opaque extremity outside .35m capsule remains hittable")
	check(cast_at(.75,.25,-3.99).is_empty() and cast_at(.75,.25,-4).get("collider") == front,"Finite endpoint excludes/admits exact visible plane")
	var skip: Array[RID] = [front.get_rid()]
	check(Query.cast(space,Vector3(.75,.25,0),Vector3(.75,.25,-12),camera,[front,back],skip).get("collider") == back,"Piercing exclusion keeps finite ray and next opaque actor")
	var wall = box(Vector3(0,0,-3))
	await physics_frame
	await physics_frame
	check(cast_at(.75,.25).get("collider") == wall,"Native wall before sprite wins")
	check(Query.cast(space,Vector3(.75,.25,0),Vector3(.75,.25,-12),null,[front,back]).get("collider") == wall,"Missing camera preserves physical wall, never visual capsule fallback")
	wall.position.z = -5
	await physics_frame
	await physics_frame
	check(cast_at(-.25,.25).get("collider") == wall,"Transparent foreground cannot reveal opaque actor behind a wall")
	check(cast_at(.75,.25).get("collider") == front,"Nearest opaque sprite before wall wins")
	front.current_map = false
	check(cast_at(.75,.25).get("collider") == wall,"Retired visual actor cannot damage through native wall to an opaque back actor")
	front.current_map = true
	wall.free()
	await physics_frame
	var synthetic = box(Vector3(0,0,-2),4)
	await physics_frame
	await physics_frame
	check(cast_at(.75,.25).get("collider") == synthetic,"Nonvisual synthetic damage object remains native occluder")
	synthetic.collision_layer = 2
	await physics_frame
	await physics_frame
	check(Query.cast(space,Vector3(.75,.25,0),Vector3(.75,.25,-12),null,[front,back],[],7).get("collider") == synthetic,"Physical player-layer body retained for camera-null projectiles")
	synthetic.free()
	await physics_frame
	front.sprite.frame = 1
	check(cast_at(.75,.25,-6,[front]).is_empty(),"Previous facing's opaque texel is not retained")
	hit = cast_at(-.75,-.25,-6,[front])
	check(hit.get("sprite_frame") == 1 and hit.get("sprite_pixel") == Vector2i(4,2),"Actual directional atlas column selected")
	front.sprite.frame = 8
	hit = cast_at(.25,.75,-6,[front])
	check(hit.get("sprite_frame") == 8 and hit.get("sprite_pixel") == Vector2i(2,4),"Actual animation row selected")
	front.sprite.frame = 0
	front.sprite.flip_h = true
	check(cast_at(-.75,.25,-6,[front]).get("collider") == front and cast_at(.75,.25,-6,[front]).is_empty(),"Horizontal flip uses texture UV, not collider transform")
	front.sprite.flip_v = true
	check(cast_at(-.75,-.25,-6,[front]).get("collider") == front,"Vertical flip uses texture UV")
	front.sprite.flip_h = false
	front.sprite.flip_v = false
	front.sprite.offset = Vector2(2,1)
	front.sprite.scale = Vector3(2,3,1)
	check(cast_at(3.5,2.25,-6,[front]).get("collider") == front,"Pixel size, offset and nonuniform global scale match actual quad")
	front.sprite.centered = false
	check(cast_at(5.5,5.25,-6,[front]).get("collider") == front,"Noncentered sprite origin follows native vertex recipe")
	front.sprite.centered = true
	front.sprite.offset = Vector2.ZERO
	front.sprite.scale = Vector3.ONE
	camera.rotation.z = PI/2
	check(cast_at(-.25,.75,-6,[front]).get("collider") == front,"Camera roll rotates full billboard right/up axes")
	camera.rotation = Vector3(PI/4,0,0)
	# Explicit native camera basis: up=(0,sqrt(.5),sqrt(.5)), normal=(0,-sqrt(.5),sqrt(.5)).
	var target := Vector3(.75,.25*sqrt(.5),-4+.25*sqrt(.5))
	var normal := Vector3(0,-sqrt(.5),sqrt(.5))
	hit = Query.cast(space,target+normal*2,target-normal*2,camera,[front])
	check(hit.get("collider") == front and hit.position.distance_to(target)<.00001,"Camera pitch places visible plane in actual tilted camera basis")
	camera.rotation = Vector3.ZERO
	front.rotation = Vector3(.2,.7,.1)
	# Full billboard replaces actor rotation but keeps lengths of global columns.
	check(cast_at(.75,.25,-6,[front]).get("collider") == front,"Actor rotation does not rotate full billboard away from camera")
	front.rotation = Vector3.ZERO
	front.sprite.texture = atlas({0:[opaque(3,1,.4)]})
	check(cast_at(.75,.25,-6,[front]).is_empty(),"Alpha below actual scissor threshold rejected")
	front.sprite.alpha_scissor_threshold = .3
	check(cast_at(.75,.25,-6,[front]).get("collider") == front,"Changed scissor threshold uses actual source alpha")
	front.sprite.modulate.a = .5
	check(cast_at(.75,.25,-6,[front]).is_empty(),"Modulate alpha participates in visible alpha cutoff")
	front.sprite.modulate.a = 1
	front.sprite.alpha_scissor_threshold = .5
	front.sprite.texture = atlas({0:[opaque(3,1)]})
	var held_texture: Texture2D = front.sprite.texture
	front.sprite.texture = null
	check(cast_at(.75,.25,-6,[front]).is_empty(),"Invalid actual sprite texture never falls back to native capsule")
	front.sprite.texture = held_texture
	held_texture = null
	front.sprite.visible = false
	check(cast_at(.75,.25,-6,[front]).is_empty(),"Hidden visual body has no capsule fallback")
	front.sprite.visible = true
	front.hp = 0
	check(cast_at(.75,.25,-6,[front]).is_empty(),"Dead actor cannot be hit despite still-present native capsule")
	front.hp = 100
	front.current_map = false
	check(cast_at(.75,.25,-6,[front]).is_empty(),"Retired/wrong-map visual actor cannot be damaged")
	front.current_map = true
	var points: Array[Vector3] = Query.candidate_points(front,camera,Vector3.ZERO)
	check(points.size()==1 and points[0]==Vector3(.75,.25,-4),"Aim candidate is actual opaque texel outside capsule, not a fictional body center")
	for point in points: check(Query.cast(space,point+Vector3(0,0,2),point-Vector3(0,0,2),camera,[front]).get("collider")==front,"Every advertised candidate samples actual occupied current frame")
	var duplicate = actor("a_authored_first",-4,front.sprite.texture)
	front.id = "z_authored_last"
	check(cast_at(.75,.25,-6,[front,duplicate]).get("collider")==duplicate,"Exact-overlap ordering uses authored ID, not creation order")
	duplicate.queue_free()
	check(cast_at(.75,.25,-6,[duplicate]).is_empty(),"Queued visual actor is never returned")
	await process_frame
	await physics_frame
	check(Query.cast(space,Vector3.ZERO,Vector3.ZERO,camera,[front]).is_empty(),"Zero-length finite query rejected")
	check(Query.cast(space,Vector3(NAN,0,0),Vector3.ZERO,camera,[front]).is_empty(),"Nonfinite input rejected")
	check(Query.candidate_points(front,null,Vector3.ZERO).is_empty(),"Invalid camera produces no invented aim candidates")
	await cache_checks()
	var texture: Texture2D = front.sprite.texture
	Query.invalidate_texture(texture)
	var started: int = Time.get_ticks_usec()
	cast_at(.75,.25,-6,[front])
	var cold_us: int = Time.get_ticks_usec()-started
	var cache = texture.get_meta(Query.CACHE_KEY)
	started = Time.get_ticks_usec()
	for i in range(256): cast_at(.75,.25,-6,[front])
	var warm_total_us: int = Time.get_ticks_usec()-started
	check(is_same(cache,texture.get_meta(Query.CACHE_KEY)),"Warm casts reuse cache, not a per-ray image copy")
	print("SPRITE_HIT_QUERY_TIMING ",JSON.stringify({"cold_us":cold_us,"warm_casts":256,"warm_total_us":warm_total_us,"warm_mean_us":warm_total_us/256.0,"synthetic4x4frame":true,"fps_claim":false}))
	scene.free()
	await process_frame
	print("PASS native visible-sprite geometry/query occupancy tests; NOT anatomy/weakpoints, integrated weapon damage, actual-render or FPS acceptance" if failures==0 else "FAIL visible-sprite geometry: "+str(failures))
	quit(0 if failures==0 else 1)
func cache_checks() -> void:
	var texture = atlas({0:[opaque(3,1)]})
	var temporary = actor("cache_lifetime",-4,texture)
	for i in range(4):
		Query.candidate_points(temporary,camera,Vector3.ZERO)
		check(texture.changed.get_connections().size()==2,"Exactly native Sprite listener + one cache listener, not accumulating callbacks")
		Query.invalidate_texture(texture)
		check(texture.changed.get_connections().size()==1,"Manual invalidate disconnects its cache listener")
	Query.candidate_points(temporary,camera,Vector3.ZERO)
	texture.emit_changed()
	check(not texture.has_meta(Query.CACHE_KEY),"Texture changed invalidates source coverage cache")
	Query.candidate_points(temporary,camera,Vector3.ZERO)
	for i in range(80):
		temporary.sprite.alpha_scissor_threshold = float(i)/100.0
		Query.candidate_points(temporary,camera,Vector3.ZERO)
	check(texture.get_meta(Query.CACHE_KEY).frames.size() <= Query.MAX_FRAME_CACHE,"Frame/threshold cache cannot grow beyond its fixed bound")
	# Actual ImageTexture.update/readback alpha mutation is exercised by the
	# real Metal SubViewport fixture, not the headless dummy render server.
	var source_ref: WeakRef = weakref(texture)
	temporary.free()
	texture = null
	check(source_ref.get_ref()==null,"Texture-owned cache/listener cannot keep an unused texture alive")
	await process_frame
