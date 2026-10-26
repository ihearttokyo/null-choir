extends SceneTree
## Actual final Enemy normal-import visible context; explicit one idle/role, not gameplay.
const LevelSource = preload("res://scripts/level.gd")
const EnemySource = preload("res://scripts/enemy.gd")
const Campaign = preload("res://scripts/campaign.gd")
class Host extends Node:
	var state = Campaign.new()
	var level
	var playing := false
var failures := 0
var report := {"scope":"Actual unchanged authored role map/spawn + final Enemy normal Texture2D; one manually selected idle0. No ImageTexture/scene-light/art/scale override, input/AI/gameplay/FPS claim", "checks":[],"views":[],"camera_trials":[]}
func check(ok: bool,detail: String) -> void:
	report.checks.append({"passed":ok,"message":detail})
	if not ok: failures += 1; push_error(detail)
func _initialize() -> void: call_deferred("run")
func disable_tree(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_INHERIT
	node.set_process(false); node.set_physics_process(false); node.set_process_input(false); node.set_process_unhandled_input(false); node.set_process_unhandled_key_input(false)
	for child in node.get_children(): disable_tree(child)

func v3(value: Vector3) -> Array:
	return [value.x,value.y,value.z]

func natural_direction(actor: Node3D,camera: Camera3D) -> int:
	var bearing: Vector3 = actor.global_basis.inverse()*(camera.global_position-actor.global_position)
	return posmod(int(round(atan2(bearing.x,-bearing.z)/TAU*8)),8)

func unobstructed(space: PhysicsDirectSpaceState3D,start: Vector3,end: Vector3) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(start,end,1)).is_empty()

func registered_colliders(node: Node,space: RID) -> int:
	var count := 0
	if node is StaticBody3D and ((node as StaticBody3D).collision_layer & 1) != 0:
		if PhysicsServer3D.body_get_space((node as StaticBody3D).get_rid()) == space: count += 1
	for child in node.get_children(): count += registered_colliders(child,space)
	return count

func check_collision_negative_control(level,actor) -> void:
	var world: World3D = level.get_world_3d()
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var count := registered_colliders(level,world.space)
	check(count > 0 and level.floor_bodies.size() > 0,"Actual Level static colliders remain registered in this native World3D")
	var closest := INF
	var edge := Vector2.ZERO
	var normal := Vector2.ZERO
	var source_tile := Vector2i.ZERO
	for tile in level.layout.tiles:
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if level.layout.is_walkable(tile+direction): continue
			var point := Vector2(tile)+Vector2(.5,.5)+Vector2(direction)*.5
			var distance := (point*float(level.layout.data.cell_size)-Vector2(actor.position.x,actor.position.z)).length_squared()
			if distance < closest: closest = distance; edge = point; normal = Vector2(direction); source_tile = tile
	check(closest < INF,"An actual authored boundary wall exists for occluded-approach negative control")
	if closest == INF: return
	var center := Vector3(edge.x*float(level.layout.data.cell_size),level.layout.height_at(edge)+1.55,edge.y*float(level.layout.data.cell_size))
	var offset := Vector3(normal.x,0,normal.y)*.75
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(center-offset,center+offset,1))
	check(not hit.is_empty() and hit.collider is StaticBody3D,"Representative cross-boundary native ray really hits unchanged Level wall")
	check(not unobstructed(space,center-offset,center+offset),"Same visibility predicate rejects actual wall-occluded approach; empty-space false pass impossible")
	report.collision_negative_control = {"registered_static_world_colliders":count,"actual_floor_bodies":level.floor_bodies.size(),"boundary_tile":[source_tile.x,source_tile.y],"nonwalkable_direction":[normal.x,normal.y],"ray_start":v3(center-offset),"ray_end":v3(center+offset),"blocked":not hit.is_empty(),"scope":"negative control only, not a captured camera or moved actor"}

func world_pixel(sprite: Sprite3D,camera: Camera3D,cell: int,pixel: Vector2) -> Vector3:
	return sprite.global_position+camera.global_basis.x*((pixel.x-cell/2.0)*sprite.pixel_size)+camera.global_basis.y*((cell/2.0-pixel.y)*sprite.pixel_size)

func occupied_samples(image: Image) -> Array[Vector2]:
	# Bounded nine-bin witnesses from actual source alpha, not invented anatomy.
	var samples: Array[Vector2] = []
	var size := image.get_size()
	for by in range(3):
		for bx in range(3):
			var best := Vector2.ZERO
			var distance := INF
			var target := Vector2((bx+.5)*size.x/3.0,(by+.5)*size.y/3.0)
			for y in range(by*size.y/3,(by+1)*size.y/3):
				for x in range(bx*size.x/3,(bx+1)*size.x/3):
					if image.get_pixel(x,y).a < .5: continue
					var point := Vector2(x+.5,y+.5)
					var next := point.distance_squared_to(target)
					if next < distance: distance = next; best = point
			if distance < INF: samples.append(best)
	return samples

func choose_camera(level,actor,camera: Camera3D,settings: Dictionary,samples: Array[Vector2],cell: int) -> bool:
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	for index in settings.bearing_preference_indices:
		var angle: float = actor.rotation.y+float(index)*TAU/8.0
		var xz := Vector2(actor.position.x,actor.position.z)+Vector2(-sin(angle),-cos(angle))*float(settings.horizontal_distance_m)
		var point: Array = [xz.x/level.layout.data.cell_size,xz.y/level.layout.data.cell_size]
		var trial := {"preferred_bearing":index,"camera_cell":point,"accepted":false}
		report.camera_trials.append(trial)
		if not level.layout.is_walkable(Vector2i(floori(point[0]),floori(point[1]))):
			trial.reason = "nonwalkable center"; continue
		var floor_position: Vector3 = level.layout.world_position(point)
		if not floor_position.is_finite(): trial.reason = "no finite actual floor"; continue
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(floor_position+Vector3.UP*.1,floor_position-Vector3.UP*.1,1))
		if floor_hit.is_empty() or not floor_hit.collider in level.floor_bodies or floor_hit.position.distance_to(floor_position) > .003:
			trial.reason = "no native current-Level floor witness"; continue
		var shape := CapsuleShape3D.new()
		shape.radius = .32; shape.height = 1.65
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY,floor_position+Vector3.UP*(.04+.85))
		query.collision_mask = 1
		if not space.intersect_shape(query,1).is_empty(): trial.reason = "actual player capsule obstructed"; continue
		camera.position = floor_position+Vector3.UP*(.04+1.55)
		camera.look_at(Vector3(actor.position.x,camera.position.y,actor.position.z))
		var visible := 0
		for pixel in samples:
			var target := world_pixel(actor.sprite,camera,cell,pixel)
			if not camera.is_position_in_frustum(target): continue
			if unobstructed(space,camera.global_position,target): visible += 1
		if visible == 0: trial.reason = "no occupied texel has native unobstructed in-frustum ray"; continue
		trial.accepted = true
		trial.native_unobstructed_occupied_samples = visible
		trial.native_floor = v3(floor_hit.position)
		trial.camera_eye = v3(camera.position)
		trial.horizontal_distance_m = xz.distance_to(Vector2(actor.position.x,actor.position.z))
		trial.eye_to_actor_origin_distance_m = camera.position.distance_to(actor.position)
		trial.actual_bearing = natural_direction(actor,camera)
		report.camera = trial
		return true
	return false

func changed_pixels(background: Image,pixels: Image,limit: int = 0) -> int:
	var before: PackedByteArray = background.get_data()
	var after: PackedByteArray = pixels.get_data()
	var count := 0
	for offset in range(0,before.size(),4):
		if before[offset] != after[offset] or before[offset+1] != after[offset+1] or before[offset+2] != after[offset+2]: count += 1
		if limit > 0 and count >= limit: return count
	return count



func finish(output: String,view: SubViewport) -> void:
	report.failures = failures
	var file = FileAccess.open(output.path_join("visible-context-report.json"),FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report,"  ")); file.close()
	view.free()
	print("VISIBLE_NORMAL_COHORT_CONTEXT failures=",failures)
	quit(0 if failures == 0 else 1)

func stable_opaque_witnesses(background_a: Image,actor_view: Image,background_b: Image,actor,camera: Camera3D,cell: int,samples: Array[Vector2]) -> int:
	var count := 0
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	for sample in samples:
		var target := world_pixel(actor.sprite,camera,cell,sample)
		if not camera.is_position_in_frustum(target) or not unobstructed(space,camera.global_position,target): continue
		var center := Vector2i(camera.unproject_position(target).floor())
		var stable := true
		var changed := false
		for dy in range(-1,2):
			for dx in range(-1,2):
				var point := center+Vector2i(dx,dy)
				if point.x < 0 or point.x >= 640 or point.y < 0 or point.y >= 360: continue
				var a := background_a.get_pixelv(point); var b := background_b.get_pixelv(point); var v := actor_view.get_pixelv(point)
				if a != b: stable = false
				if a != v: changed = true
		if stable and changed: count += 1
	return count

func run() -> void:
	var output := OS.get_environment("COHORT_VISIBLE_OUTPUT")
	var role := OS.get_environment("COHORT_VISIBLE_ROLE")
	if output.is_empty() or not DirAccess.dir_exists_absolute(output): push_error("Fresh explicit noncloud output required"); quit(1); return
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/visible-registry.json"))
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/cohort-expected.json"))
	check(registry.has(role) and expected.actors.has(role),"Exact known role descriptor")
	var contract: Dictionary = registry[role]; var e: Dictionary = expected.actors[role]; var cell: int = int(e.cell)
	var view := SubViewport.new(); view.size = Vector2i(640,360); view.own_world_3d = true; view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var host := Host.new(); disable_tree(host); view.add_child(host); host.state.new_campaign(1)
	var level = LevelSource.new(); disable_tree(level); host.level = level; host.add_child(level)
	check(level.build(host,int(contract.map_index)),"Actual role's unchanged authored map builds")
	disable_tree(host)
	var spec: Dictionary = {}
	for item in level.layout.data.enemies:
		if item.id == contract.expected_spawn.id: spec = item.duplicate(true); break
	check(spec == contract.expected_spawn,"Exact role's authored spawn/yaw, no actor reposition")
	if failures > 0: finish(output,view); return
	var actor = EnemySource.new(); disable_tree(actor); actor.configure(host,spec); level.add_child(actor); disable_tree(host)
	var sprite: Sprite3D = actor.sprite; var original_pose: Transform3D = actor.transform; var original_sprite: Transform3D = sprite.transform
	check(sprite.texture is CompressedTexture2D and sprite.texture.resource_path == e.uri,"Final Enemy constructor consumes actual normal CompressedTexture2D resource")
	check(sprite.hframes == 8 and sprite.vframes == int(e.rows) and sprite.texture.get_size() == Vector2(int(e.dimensions[0]),int(e.dimensions[1])),"Exact actual eightdirection runtime layout")
	check(is_equal_approx(sprite.pixel_size,float(e.pixel_size)) and is_equal_approx(sprite.position.y,float(e.sprite_offset_y)),"Original runtime pixel size/foot anchor untouched")
	check(sprite.shaded and sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED and sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD,"Original shaded nearest billboard/discard flags")
	var image := sprite.texture.get_image()
	if image.is_compressed(): check(image.decompress() == OK,"Lossless normal texture readback")
	image.convert(Image.FORMAT_RGBA8)
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(image.get_data())
	check(context.finish().hex_encode() == e.rgba_sha256,"Same actual accepted normal-import RGBA")
	var idle := image.get_region(Rect2i(0,0,cell,cell)); var samples: Array[Vector2] = occupied_samples(idle)
	sprite.frame = 0
	var camera := Camera3D.new(); camera.fov = 85; camera.near = .08; view.add_child(camera)
	await physics_frame; await physics_frame
	check_collision_negative_control(level,actor)
	check(choose_camera(level,actor,camera,contract.camera,samples,cell),"Actual walkable floor/player-clear/native-opaqueLOS camera found")
	check(is_equal_approx(Vector2(camera.position.x-actor.position.x,camera.position.z-actor.position.z).length(),float(contract.camera.horizontal_distance_m)),"Exact previously validated approach distance, no zoom rescue")
	if failures > 0: finish(output,view); return
	sprite.hide(); await process_frame; await RenderingServer.frame_post_draw
	var hidden_a := view.get_texture().get_image(); hidden_a.convert(Image.FORMAT_RGBA8)
	sprite.show(); await process_frame; await RenderingServer.frame_post_draw
	var visible := view.get_texture().get_image(); visible.convert(Image.FORMAT_RGBA8)
	sprite.hide(); await process_frame; await RenderingServer.frame_post_draw
	var hidden_b := view.get_texture().get_image(); hidden_b.convert(Image.FORMAT_RGBA8)
	var total := changed_pixels(hidden_a,visible)
	var witness := stable_opaque_witnesses(hidden_a,visible,hidden_b,actor,camera,cell,samples)
	check(total >= 64 and witness >= 1,"Actual visible depth-tested actor pixels +stable ABA opaque source witness (wall-only/savePNG falsepass rejected)")
	check(actor.transform == original_pose and sprite.transform == original_sprite,"No production actor/art/scale/light/camera-source changes")
	check(not host.playing and not actor.is_processing() and not actor.is_physics_processing(),"Static callbacks/AI/input stay disabled")
	check(visible.save_png(output.path_join("context-00.png")) == OK and hidden_a.save_png(output.path_join("background-a.png")) == OK and hidden_b.save_png(output.path_join("background-b.png")) == OK,"Actual render/background evidence retained")
	report.role = role; report.map = contract.map_file; report.actor_spec = spec; report.actor_position = v3(actor.position); report.runtime_uri = e.uri; report.normal_RGBA = e.rgba_sha256
	report.views.append({"file":"context-00.png","tested_frame":0,"manual_idle_direction":0,"actual_bearing":natural_direction(actor,camera),"visible_changed_pixels":total,"stable_opaque_source_witnesses":witness,"source_alpha_samples":samples.size(),"no_ImageTexture_override":true,"backgrounds":["background-a.png","background-b.png"],"resolution":[640,360]})
	finish(output,view)
