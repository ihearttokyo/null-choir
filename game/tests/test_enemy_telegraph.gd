extends SceneTree
const Tell = preload("res://scripts/enemy_telegraph.gd")
class Host extends Node3D:
	var playing := true
	var player: Node3D
class Viewer extends Node3D:
	var camera: Camera3D
class Actor extends CharacterBody3D:
	var game: Node
	var kind := "worker"
	var _committed_aim := Vector3(0,1.4,-10)
	var stage := "windup"
	var progress := 0.0
	func combat_visual_state() -> Dictionary:
		return {} if stage == "retired" else {"phase":stage,"progress":progress}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host=Host.new();root.add_child(host)
	var viewer=Viewer.new();host.add_child(viewer);host.player=viewer
	viewer.camera=Camera3D.new();viewer.add_child(viewer.camera)
	viewer.camera.position=Vector3(0,2,4);viewer.camera.look_at(Vector3(0,1.4,-2));viewer.camera.current=true
	var actor=Actor.new();host.add_child(actor);actor.game=host
	actor.set_physics_process(false)
	var tell=Tell.new();actor.add_child(tell);tell.set_physics_process(false)
	var wall=StaticBody3D.new();wall.collision_layer=1;host.add_child(wall)
	var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(4,4,0.2);wall.add_child(shape);wall.position.z=-5
	await physics_frame
	await physics_frame
	var before=actor._committed_aim
	tell._physics_process(1.0/30.0)
	if not check(tell.beam.visible and is_equal_approx(tell.beam.mesh.height,4.9),"Lockline must terminate at actual WORLD wall front, not pass through"): return
	var locked=tell.beam.global_transform
	viewer.position.x=2.0
	tell._physics_process(1.0/30.0)
	if not check(tell.beam.global_transform.is_equal_approx(locked) and actor._committed_aim==before,"Moving target must not retarget committed line or write attack aim"): return
	actor.progress=0.9;tell._physics_process(1.0/30.0)
	if not check(is_equal_approx(tell.beam.mesh.top_radius,0.0144),"Line width uses genuine windup completion without flashing"): return
	for stage in ["release","recovery","stagger","idle"]:
		actor.stage=stage;tell._physics_process(1.0/30.0)
		if not check(not tell.beam.visible,"Cancelled/released/inactive tell must disappear"): return
	actor.stage="windup";host.playing=false;tell._physics_process(1.0/30.0)
	if not check(not tell.beam.visible,"Paused host must not draw active tell"): return
	host.playing=true;viewer.camera.rotation.y=PI;tell._physics_process(1.0/30.0)
	if not check(not tell.beam.visible,"Offscreen attacker must not draw/query tell"): return
	actor.stage="dead";tell._physics_process(1.0/30.0)
	if not check(tell.is_queued_for_deletion(),"Dead actor must retire owned visual helper"): return
	host.queue_free();await process_frame;await process_frame
	print("PASS synthetic worker committed-lockline: actual WORLD occlusion, immutable aim, timing read-only, cancellation/pause/offscreen/death cleanup; no gameplay/render acceptance")
	quit(0)
func check(ok: bool,message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
