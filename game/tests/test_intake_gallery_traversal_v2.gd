extends SceneTree
const StaticSelectedLevel = preload("res://tests/fixtures/static_selected_level.gd")
## Arranged, scripted-input geometry witness. Not earned combat, physical input,
## campaign completion, rendering or performance acceptance. Level keeps every
## production art/scenery/floor/wall/door collider; no Enemy instances are spawned.
const Level = preload("res://scripts/level.gd")
const Player = preload("res://scripts/player.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Preferences = preload("res://scripts/preferences.gd")
const MOVEMENT = ["move_left","move_right","move_forward","move_back"]
const CASES = [
	{"id":"bell_bridge","cells":[[8,16],[12.5,16]]},
	{"id":"south_ramp","cells":[[11.5,24],[12.5,19],[12.5,16]]},
	{"id":"north_ramp","cells":[[12,8],[12.5,12],[12.5,16]]},
	{"id":"lower_direct","cells":[[14.5,24],[14.5,12]]},
	{"id":"landing_cover","cells":[[12.5,19],[12.5,15]]},
	{"id":"altar_approach","cells":[[6.5,17.5],[6.5,16],[8,16]]}
]
class Host extends Node:
	var state = Campaign.new()
	var level
	var player
	var playing = false
	var settings = {"head_bob":false,"camera_shake":false,"sensitivity":1.0,"invert_y":false}
	func hurt_player(damage: int) -> void: state.health -= damage
var failures: int = 0
var host
var total_ticks: int = 0

func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> bool:
	if not ok:
		failures += 1
		push_error(message)
	return ok
func release_actions() -> void:
	for action in MOVEMENT:
		if InputMap.has_action(action): Input.action_release(action)
func finish() -> void:
	release_actions()
	if is_instance_valid(host):
		host.playing = false
		host.player = null
		host.level = null
		host.free()
	await physics_frame
	await process_frame
	print("INTAKE_GALLERY_TRAVERSAL_RESULT ",JSON.stringify({"failures":failures,"ticks":total_ticks,"arranged":true,"scripted_input":true,"earned_campaign":false,"physical_input":false,"gpu":false}))
	quit(0 if failures == 0 else 1)

func run() -> void:
	# Match Main startup exactly; project.godot does not declare these actions.
	# Use fresh production defaults, never load/save the user's preferences.
	Preferences.new().apply_bindings()
	for action in Preferences.ACTIONS:
		if not expect(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(),"Production binding initialized: "+action):
			await finish()
			return
	if not expect(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60,"Unmodified production physics clock required"):
		await finish()
		return
	# Reject dirty external controls rather than silently letting them affect proof.
	for action in InputMap.get_actions():
		if Input.is_action_pressed(action):
			expect(false,"Fixture requires initially released input: "+action)
			await finish()
			return
	host = Host.new()
	root.add_child(host)
	host.state = StaticSelectedLevel.fresh_selected(0,1)
	host.level = Level.new()
	host.add_child(host.level)
	if not expect(host.level.build(host,0) and host.level.layout.floor_revision() == 2,"Actual production Intake revision2 builds"):
		await finish()
		return
	await physics_frame
	await physics_frame
	for spec in CASES:
		for reverse in [false,true]:
			var cells: Array = spec.cells.duplicate(true)
			if reverse: cells.reverse()
			if not await traverse(str(spec.id)+(":reverse" if reverse else ":forward"),cells):
				await finish()
				return
	await finish()


func progress_snapshot(id: String, player, target: Vector3, ticks: int) -> void:
	var floor_point: Vector3 = host.level.layout.world_position([player.position.x/4.0,player.position.z/4.0])
	# Emit essential motion evidence first; optional shape details cannot hide it.
	print("INTAKE_GALLERY_POSE ",JSON.stringify({"case":id,"segment_ticks":ticks,"position":str(player.position),"target":str(target),"velocity":str(player.velocity),"yaw":player.rotation.y,"input_vector":str(Input.get_vector("move_left","move_right","move_forward","move_back")),"forward_strength":Input.get_action_strength("move_forward"),"grounded":player.is_on_floor(),"floor":str(floor_point),"floor_support":host.level.layout.capsule_floor_support(Vector2(player.position.x,player.position.z),0.32)}))
	var contacts: Array = []
	for i in range(player.get_slide_collision_count()):
		var hit: KinematicCollision3D = player.get_slide_collision(i)
		var collider = hit.get_collider()
		var details: Dictionary = {"normal":str(hit.get_normal()),"position":str(hit.get_position()),"depth":hit.get_depth(),"collider":str(collider),"shape_index":hit.get_collider_shape_index()}
		if collider is Node:
			details.path = str(collider.get_path())
			details.metadata = collider.get_meta_list()
		if collider is CollisionObject3D:
			var owner_id: int = collider.shape_find_owner(hit.get_collider_shape_index())
			var shape_owner = collider.shape_owner_get_owner(owner_id)
			if shape_owner is CollisionShape3D:
				details.shape = str(shape_owner.shape)
				details.shape_transform = str(shape_owner.global_transform)
				if shape_owner.shape is BoxShape3D:
					var size: Vector3 = shape_owner.shape.size
					details.box_size = str(size)
					details.world_aabb = str(shape_owner.global_transform*AABB(-size*0.5,size))
				elif shape_owner.shape is ConcavePolygonShape3D:
					var bounds = AABB()
					var vertices: PackedVector3Array = shape_owner.shape.get_faces()
					if not vertices.is_empty():
						bounds = AABB(shape_owner.to_global(vertices[0]),Vector3.ZERO)
						for vertex in vertices: bounds = bounds.expand(shape_owner.to_global(vertex))
					details.world_aabb = str(bounds)
		contacts.append(details)
	print("INTAKE_GALLERY_PROGRESS ",JSON.stringify({"case":id,"segment_ticks":ticks,"position":str(player.position),"target":str(target),"velocity":str(player.velocity),"yaw":player.rotation.y,"input_vector":str(Input.get_vector("move_left","move_right","move_forward","move_back")),"forward_strength":Input.get_action_strength("move_forward"),"grounded":player.is_on_floor(),"floor":str(floor_point),"floor_support":host.level.layout.capsule_floor_support(Vector2(player.position.x,player.position.z),0.32),"contacts":contacts}))

func traverse(id: String, cells: Array) -> bool:
	release_actions()
	# Independent case setup is the ONLY player placement. Subsequent movement
	# comes exclusively from Input and Player's normal automatic physics callback.
	var player = Player.new()
	host.player = player
	host.level.add_child(player)
	player.configure(host)
	player.position = host.level.layout.world_position(cells[0])+Vector3.UP*0.08
	host.playing = true
	var capsule: CapsuleShape3D = player.get_child(0).shape
	if not expect(is_equal_approx(capsule.radius,0.32) and is_equal_approx(capsule.height,1.65) and is_equal_approx(player.floor_snap_length,0.5),"Unmodified production capsule/snap"):
		return false
	for tick in range(30):
		await physics_frame
		total_ticks += 1
	if not expect(player.is_on_floor(),id+": arranged start settles on real floor"):
		return false
	var initial_health: int = host.state.health
	var ticks: int = 0
	var grounded: int = 0
	var max_height: float = player.position.y
	var start_height: float = player.position.y
	var max_floor_gap: float = 0.0
	for index in range(1,cells.size()):
		var target: Vector3 = host.level.layout.world_position(cells[index])
		var segment_ticks: int = 0
		while Vector2(player.position.x-target.x,player.position.z-target.z).length() > 0.18:
			if segment_ticks >= 720 or total_ticks >= 12000:
				progress_snapshot(id,player,target,segment_ticks)
				expect(false,id+": finite real-capsule route budget")
				return false
			var offset: Vector3 = target-player.position
			var distance = Vector2(offset.x,offset.z).length()
			var desired = atan2(-offset.x,-offset.z)
			player.look(Vector2(wrapf(player.rotation.y-desired,-PI,PI),0))
			# get_vector uses the production InputMap deadzone. Keep the
			# slow approach strength above it instead of stalling at its edge.
			var approach_strength = minf(1.0,InputMap.action_get_deadzone("move_forward")+0.15)
			Input.action_press("move_forward",minf(1.0,maxf(approach_strength,distance*0.7)))
			await physics_frame
			segment_ticks += 1
			ticks += 1
			total_ticks += 1
			if id == "bell_bridge:forward" and segment_ticks % 120 == 0: progress_snapshot(id,player,target,segment_ticks)
			if player.is_on_floor(): grounded += 1
			if not expect(player.position.is_finite() and host.state.health == initial_health,id+": finite live player, no fall/death"):
				return false
			var floor_point: Vector3 = host.level.layout.world_position([player.position.x/4.0,player.position.z/4.0])
			var gap: float = player.position.y-floor_point.y
			max_floor_gap = maxf(max_floor_gap,absf(gap))
			max_height = maxf(max_height,player.position.y)
			if not expect(gap >= -0.10 and gap <= 0.75,id+": capsule stays supported by real ramp/landing, not a fall shortcut"):
				return false
		release_actions()
	# Let ordinary braking settle; do not force velocity or snap/position.
	for tick in range(20):
		await physics_frame
		total_ticks += 1
	var final: Vector3 = host.level.layout.world_position(cells.back())
	var final_gap = Vector2(player.position.x-final.x,player.position.z-final.z).length()
	var ok = expect(final_gap < 0.4 and player.is_on_floor(),id+": original final goal reached and grounded")
	ok = expect(ticks > 0 and grounded >= ticks*0.90,id+": sustained native floor contact") and ok
	print("INTAKE_GALLERY_CAPSULE_CASE ",JSON.stringify({"case":id,"ticks":ticks,"grounded":grounded,"start_y":start_height,"peak_y":max_height,"end_y":player.position.y,"max_floor_gap":max_floor_gap,"goal_gap":final_gap,"capsule_radius":capsule.radius,"arranged_start":true,"position_writes_during_motion":0,"passed":ok}))
	host.playing = false
	host.player = null
	player.free()
	await physics_frame
	return ok
