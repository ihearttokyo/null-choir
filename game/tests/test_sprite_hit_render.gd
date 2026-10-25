extends SceneTree
## Only a tiny synthetic Sprite3D/SubViewport: not gameplay/desktop capture/art.
const Query = preload("res://scripts/sprite_hit_query.gd")
class Actor extends CharacterBody3D:
	var id := "render_toy"
	var hp := 100
	var sprite: Sprite3D
	func _current_map() -> bool: return true
	func visual_hit_sprite() -> Sprite3D: return sprite
var checks: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	assert(DisplayServer.get_name() != "headless")
	assert(RenderingServer.get_current_rendering_driver_name() == "metal")
	assert(RenderingServer.get_current_rendering_method() == "mobile")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(128,128)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6
	camera.near = .1
	camera.far = 30
	scene.add_child(camera)
	camera.make_current()
	var actor := Actor.new()
	actor.collision_layer = 4
	scene.add_child(actor)
	actor.position = Vector3(0,0,-4)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .25
	capsule.height = 1
	collider.shape = capsule
	actor.add_child(collider)
	var image := Image.create(64,40,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	for frame in [0,1,8]:
		for y in range(8):
			for x in range(8):
				var alpha: float = 0
				if frame == 0: alpha = 1.0 if (x in [1,2] and y in [1,2]) or (x>=4 and x<=6 and y>=3 and y<=5) else .4 if x==3 and y==6 else 0.0
				elif frame == 1: alpha = 1.0 if x>=2 and x<=4 and y>=1 and y<=3 else 0.0
				else: alpha = 1.0 if x>=4 and x<=6 and y>=4 and y<=6 else 0.0
				image.set_pixel(int(frame)%8*8+x,int(frame)/8*8+y,Color(1,1,1,alpha))
	actor.sprite = Sprite3D.new()
	actor.sprite.texture = ImageTexture.create_from_image(image)
	actor.sprite.hframes = 8
	actor.sprite.vframes = 5
	actor.sprite.pixel_size = .4
	actor.sprite.shaded = false
	actor.sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	actor.sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	actor.sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	actor.sprite.alpha_scissor_threshold = .5
	actor.add_child(actor.sprite)
	await physics_frame
	await physics_frame
	for name in ["base","pitched_rolled_camera","offset_scaled","flipped","different_facing","different_animation","modulate_hidden","runtime_texture_update"]:
		camera.position = Vector3.ZERO
		camera.rotation = Vector3.ZERO
		actor.rotation = Vector3(.12,.4,.15)
		actor.scale = Vector3.ONE
		actor.sprite.scale = Vector3.ONE
		actor.sprite.offset = Vector2.ZERO
		actor.sprite.flip_h = false
		actor.sprite.flip_v = false
		actor.sprite.frame = 0
		actor.sprite.modulate.a = 1
		var update_before: float = -1
		if name == "pitched_rolled_camera":
			camera.position = Vector3(1.2,.9,0)
			camera.look_at(actor.global_position,Vector3.UP)
			camera.rotate_object_local(Vector3.FORWARD,.3)
		elif name == "offset_scaled":
			actor.scale = Vector3(.8,1.2,1)
			actor.sprite.scale = Vector3(1.3,.7,1)
			actor.sprite.offset = Vector2(1.5,-1)
		elif name == "flipped":
			actor.sprite.flip_h = true
			actor.sprite.flip_v = true
		elif name == "different_facing": actor.sprite.frame = 1
		elif name == "different_animation": actor.sprite.frame = 8
		elif name == "modulate_hidden": actor.sprite.modulate.a = .4
		elif name == "runtime_texture_update":
			update_before = actor.sprite.texture.get_image().get_pixel(1,1).a
			var empty_image := Image.create(64,40,false,Image.FORMAT_RGBA8)
			empty_image.fill(Color(0,0,0,0))
			(actor.sprite.texture as ImageTexture).update(empty_image)
		for i in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		if name == "runtime_texture_update":
			var actual_source: Image = actor.sprite.texture.get_image()
			assert(update_before == 1.0 and actual_source.get_pixel(1,1).a == 0.0,"Real renderer must commit the submitted transparent source bytes")
			Query.invalidate_texture(actor.sprite.texture)
			print("SPRITE_REAL_TEXTURE_UPDATE ",JSON.stringify({"before_readback_alpha":update_before,"after_readback_alpha":actual_source.get_pixel(1,1).a,"submitted_alpha":0.0,"cache_invalidated_after_committed_readback":true}))
		var rendered: Image = viewport.get_texture().get_image()
		var mismatch := 0
		var compared := 0
		var rendered_occupied := 0
		for y in range(2,126,4):
			for x in range(2,126,4):
				var visible: bool = rendered.get_pixel(x,y).a >= .5
				var interior := true
				for dy in [-1,0,1]:
					for dx in [-1,0,1]:
						if (rendered.get_pixel(x+dx,y+dy).a>=.5) != visible: interior = false
				if not interior: continue # Actual raster edge convention is not a texel-center guarantee.
				var pixel := Vector2(x+.5,y+.5)
				var origin := camera.project_ray_origin(pixel)
				var end := origin+camera.project_ray_normal(pixel)*30
				var hit := Query.cast(actor.get_world_3d().direct_space_state,origin,end,camera,[actor])
				var occupied: bool = hit.get("collider") == actor
				compared += 1
				if visible: rendered_occupied += 1
				if occupied != visible: mismatch += 1
		checks.append({"case":name,"compared_interior_pixels":compared,"rendered_occupied_samples":rendered_occupied,"mismatches":mismatch})
		assert(compared>500 and (rendered_occupied>0 if name not in ["modulate_hidden","runtime_texture_update"] else rendered_occupied==0),"Native toy render must actually contain the intended visible/hidden sprite")
		assert(mismatch==0,"Native rendered alpha must agree with CPU occupancy on every tested interior pixel")
	viewport.queue_free()
	await process_frame
	await process_frame
	print("SPRITE_HIT_RENDER_CORRELATION ",JSON.stringify({"engine":Engine.get_version_info().string,"viewport_size":[128,128],"cases":checks,"synthetic_only":true,"saved_images":0,"gameplay_capture":false,"fps_claim":false}))
	print("PASS native Metal toy Sprite3D rendered-alpha/interior-ray correlation; no actual game/desktop/art capture or anatomy claim")
	quit(0)
