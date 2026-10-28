extends SceneTree
## Actual Enemy AI/collision on arranged flat WORLD; no campaign/render claim.
const Enemy = preload("res://scripts/enemy.gd")
class Layout extends RefCounted:
	var data: Dictionary = {}
	func world_position(_cell) -> Vector3: return Vector3.ZERO
	func capsule_floor_support(_p,_r) -> float: return 0.0
	func capsule_floor_support_at_y(_p,_r,_y,_t) -> float: return 0.0
class Room extends Node3D:
	var layout = Layout.new()
	var floor_bodies: Array = []
class Viewer extends CharacterBody3D:
	var camera: Camera3D
class Host extends Node3D:
	var state = {"difficulty":1,"health":100,"removed":[]}
	var playing: bool = true
	var level
	var player
	var hits: int = 0
	func hurt_player(_damage: int) -> void: hits += 1
func _initialize() -> void: call_deferred("run")
var failures: int = 0
func check(ok: bool,label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func box(room,center,size):
	var b = StaticBody3D.new()
	room.add_child(b)
	b.position = center
	b.collision_layer = 1
	var c = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	c.shape = shape
	b.add_child(c)
	return b
func run() -> void:
	for mode in ["contact","dodge","wall"]:
		var host = Host.new()
		root.add_child(host)
		host.level = Room.new()
		host.add_child(host.level)
		host.level.floor_bodies.append(box(host.level,Vector3(0,-.1,-4),Vector3(30,.2,40)))
		host.player = Viewer.new()
		host.level.add_child(host.player)
		host.player.position = Vector3(0,.03,-6)
		host.player.collision_layer = 2
		var c = CollisionShape3D.new()
		var capsule = CapsuleShape3D.new()
		capsule.radius = .35
		capsule.height = 1.8
		c.shape = capsule
		c.position.y = .9
		host.player.add_child(c)
		host.player.camera = Camera3D.new()
		host.player.add_child(host.player.camera)
		host.player.camera.position.y = 1.55
		host.player.camera.current = true
		var actor = Enemy.new()
		host.level.add_child(actor)
		actor.configure(host,{"id":"crawler_lunge_"+mode,"kind":"crawler","cell":[0,0],"yaw":0})
		actor.set_physics_process(false)
		await physics_frame
		await physics_frame
		await process_frame
		actor.set_physics_process(true)
		actor.alerted = true
		actor.target = host.player
		actor.path_time = 1000 # Open flat arena; no navigation fixture required.
		actor.waypoint = host.player.position
		var began = false
		var locked = Vector3.ZERO
		var rush_start = Vector3.ZERO
		var displacement = 0.0
		var pose_checks = 0
		for tick in range(90):
			await physics_frame
			await process_frame
			if tick < 3: print("SETUP ",mode," tick=",tick," pos=",actor.position," player=",host.player.position," rush=",actor._rush_time," windup=",actor.telegraph_time)
			if mode == "wall" and actor.telegraph_time > 0 and not began:
				box(host.level,Vector3(0,1,-2.5),Vector3(8,2,.2))
				began = true
			if actor._rush_time > 0:
				if locked == Vector3.ZERO:
					locked = actor._rush_direction
					rush_start = actor.position
					if mode == "dodge": host.player.position.x = 6
				check(actor._rush_direction.is_equal_approx(locked),"Lunge aim remains locked after target dodge")
				check(int(actor.sprite.frame/8) == 3,"Entire actual crawler lunge retains attack pose")
				pose_checks += 1
				displacement = maxf(displacement,rush_start.distance_to(actor.position))
			elif locked != Vector3.ZERO:
				break
		check(pose_checks > 0,"Real AI must initiate a crawler lunge")
		check(host.hits <= 1,"A charge cannot apply repeated melee damage")
		if mode == "contact": check(host.hits == 1 and actor.position.z < -3,"Real lunge closes meaningful range and contacts once")
		if mode == "dodge": check(host.hits == 0 and displacement > 4,"Lateral dodge escapes a full fast non-homing lunge")
		if mode == "wall": check(host.hits == 0 and actor.position.z > -2.5,"Native wall stops the committed lunge")
		print("CRAWLER ",mode," poses=",pose_checks," travel=",displacement," hits=",host.hits)
		host.queue_free()
		await process_frame
	print("CRAWLER_LUNGE failures=",failures," arranged real AI/physics, not campaign or visual acceptance")
	quit(0 if failures == 0 else 1)
