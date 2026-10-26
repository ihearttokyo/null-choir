extends SceneTree
const Tell=preload("res://scripts/enemy_telegraph.gd")
class Host extends Node3D:
	var playing := true
	var player: Node3D
class Viewer extends Node3D:
	var camera: Camera3D
class Actor extends CharacterBody3D:
	var game: Node
	var kind := "brute"
	var _committed_aim := Vector3(0,1,-20)
	var stage := "windup"
	var variant := 0
	var progress := 0.2
	func combat_visual_state() -> Dictionary:
		return {"phase":stage,"progress":progress,"variant":variant}
func _initialize() -> void: call_deferred("run")
func box(parent: Node3D,position_: Vector3,size: Vector3) -> StaticBody3D:
	var body=StaticBody3D.new();body.collision_layer=1;parent.add_child(body);body.position=position_
	var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision)
	return body
func run() -> void:
	var host=Host.new();root.add_child(host)
	var viewer=Viewer.new();host.add_child(viewer);host.player=viewer
	viewer.camera=Camera3D.new();viewer.add_child(viewer.camera);viewer.camera.position=Vector3(3,3,5);viewer.camera.look_at(Vector3(0,1,-5));viewer.camera.current=true
	var floor=box(host,Vector3(0,-0.1,-8),Vector3(12,0.2,32))
	var actor=Actor.new();host.add_child(actor);actor.game=host;actor.position.y=0.03;actor.set_physics_process(false)
	var collision=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=0.62;capsule.height=3.3;collision.shape=capsule;collision.position.y=1.65;actor.add_child(collision)
	var tell=Tell.new();actor.add_child(tell);tell.set_physics_process(false)
	await physics_frame;await physics_frame
	tell._physics_process(0.04)
	if not check(tell.lane.visible and tell.lane_points.size()==48 and is_equal_approx(tell.lane_nominal_distance,13.5) and is_equal_approx(tell.lane_clipped_distance,13.5),"Actual capsule floor clearance must allow nominal13.5m brute corridor"): return
	if not check(is_equal_approx(absf(tell.lane_points[0].x),0.62) and actor._committed_aim==Vector3(0,1,-20),"Lane edge marks capsule width, not damage radius; aim untouched"): return
	var points=tell.lane_points.duplicate();viewer.position.x=1;tell._physics_process(0.04)
	if not check(tell.lane_points==points,"Moving viewer cannot retarget cached committed lane"): return
	actor.position+=Vector3(0.0004,-0.0005,0.0003);tell._physics_process(0.04)
	if not check(tell.lane.visible and tell.lane_points==points,"Sub-mm physics jitter must preserve static cached lane"): return
	actor.position=Vector3(0.1,0.03,0);tell._physics_process(0.04)
	if not check(not tell.lane.visible,"Pose changes invalidate cached corridor, no repeated expensive query loop"): return
	actor.position.x=0;actor.stage="stagger";tell._physics_process(0.04);actor.stage="windup"
	var wall=box(host,Vector3(0,2,-5),Vector3(8,4,0.2))
	await physics_frame;await physics_frame;tell._physics_process(0.04)
	if not check(tell.lane.visible and tell.lane_clipped_distance>4.0 and tell.lane_clipped_distance<4.4,"WORLD capsule sweep must stop BEFORE wall by actual bodyradius"): return
	wall.queue_free();floor.queue_free();actor.stage="idle";tell._physics_process(0.04)
	box(host,Vector3(0,-0.1,-1.5),Vector3(12,0.2,3))
	await physics_frame;await physics_frame;actor.stage="windup";tell._physics_process(0.04)
	if not check(tell.lane_clipped_distance<3.0 and not tell.lane_points.is_empty(),"Unsupported cliff must end dotted ground lane, never draw over void"): return
	actor.stage="idle";tell._physics_process(0.04);actor.kind="nursery_warden";capsule.radius=1.0;capsule.height=5.4;collision.position.y=2.7;actor.variant=1;actor.stage="windup";tell._physics_process(0.04)
	if not check(not tell.lane.visible,"Warden projectile variant must never claim a charge lane"): return
	actor.variant=0;tell._physics_process(0.04)
	if not check(is_equal_approx(tell.lane_nominal_distance,9.1) and is_equal_approx(tell.lane_radius,1.0),"Warden charge nominal range is actual13x.7, not brute range"): return
	host.queue_free();await process_frame;await process_frame
	print("PASS synthetic charge corridor: real capsule floor/WORLD sweep, supported finite dots, actual nominal durations/speeds, locked aim/cache/pose invalidation, Warden variant gate; no damage-zone or visual acceptance claim")
	quit(0)
func check(ok: bool,message: String) -> bool:
	if not ok:push_error(message);quit(1)
	return ok
