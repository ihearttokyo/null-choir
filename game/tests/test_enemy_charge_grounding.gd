extends SceneTree
## Actual Enemy.configure + normal gravity/move_and_slide, synthetic flat WORLD.
const Enemy=preload("res://scripts/enemy.gd")
class State extends RefCounted:
	var difficulty := 1
	var health := 100
	var removed: Array=[]
class Layout extends RefCounted:
	var data: Dictionary = {}
	func world_position(_cell) -> Vector3:return Vector3.ZERO
	func capsule_floor_support(_point,_radius) -> float:return 0.0
	func capsule_floor_support_at_y(_point,_radius,_height,_tolerance) -> float:return 0.0
class Room extends Node3D:
	var layout=Layout.new()
class Viewer extends Node3D:
	var camera: Camera3D
class Host extends Node3D:
	var state=State.new()
	var playing := true
	var level: Node3D
	var player: Node3D
func _initialize() -> void:call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var host=Host.new();root.add_child(host);host.level=Room.new();host.add_child(host.level)
	var floor=StaticBody3D.new();floor.collision_layer=1;host.level.add_child(floor);floor.position=Vector3(0,-0.1,-8)
	var collision=CollisionShape3D.new();var floor_shape=BoxShape3D.new();floor_shape.size=Vector3(16,0.2,40);collision.shape=floor_shape;floor.add_child(collision)
	var player=Viewer.new();host.level.add_child(player);host.player=player;player.position=Vector3(0,0,-20)
	player.camera=Camera3D.new();player.add_child(player.camera);player.camera.position=Vector3(3,3,25);player.camera.look_at(Vector3(0,1.4,0));player.camera.make_current()
	await physics_frame;await physics_frame
	for role in ["brute","nursery_warden"]:
		var actor=Enemy.new();host.level.add_child(actor)
		actor.configure(host,{"id":"grounded_charge_"+role,"kind":role,"cell":[0,0],"yaw":0})
		# No pose lift, collider/margin/radius edits, manual physics calls or clock changes.
		actor.target=player;actor._begin_attack(player.global_position+Vector3.UP)
		var start_y: float=actor.global_position.y
		var tell=actor.get_node("CommittedShotTell")
		var visible_frames := 0
		for tick in range(12):
			await physics_frame
			await process_frame
			if tell.lane.visible:visible_frames+=1
			if not check(actor.telegraph_time>0 and actor._rush_time==0,"Grounding case must remain genuine committed windup"):return
		print("MEASURE actual_",role," start_y=",start_y," settled_y=",actor.global_position.y," on_floor=",actor.is_on_floor()," visible_frames=",visible_frames," nominal=",tell.lane_nominal_distance," clipped=",tell.lane_clipped_distance," radius=",tell.lane_radius)
		if not check(actor.is_on_floor() and actor.global_position.y<start_y and visible_frames>=10,"Real gravity/slide settling must retain readable supported lane"):return
		var expected: float=13.5 if role=="brute" else 10.4
		if not check(is_equal_approx(tell.lane_clipped_distance,expected) and tell.lane_points.size()==48,"Unmodified real capsule floor skin must not silently clip nominal flat-ground corridor to zero"):return
		actor.queue_free();await process_frame;await physics_frame
	host.queue_free();await process_frame;await process_frame
	print("PASS actual Enemy charge grounding: configured brute/Warden, native gravity+move_and_slide, supported corridor through settling; no rendered/gameplay acceptance")
	quit(0)
func check(ok: bool,message: String) -> bool:
	if not ok:push_error(message);quit(1)
	return ok
