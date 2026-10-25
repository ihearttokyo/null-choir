extends SceneTree
## Focused constructor/real native overlap regression, not an earned encounter.
const Level = preload("res://scripts/level.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Campaign = preload("res://scripts/campaign.gd")
class Host extends Node:
	var level
	var state = Campaign.new()
	var playing = false # No AI/combat; these are independent constructor cases.
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var host = Host.new()
	root.add_child(host)
	host.state.new_campaign(1)
	host.state.level_index = 7
	host.level = Level.new()
	host.add_child(host.level)
	if not host.level.build(host,7):
		push_error(host.level.layout.load_error)
		quit(2)
		return
	await physics_frame
	await physics_frame
	for id in ["heart_enemy_00","heart_enemy_08","heart_enemy_05"]:
		var spec: Dictionary = host.level.layout.data.enemies.filter(func(entry): return entry.id == id)[0]
		var actor = Enemy.new()
		host.level.add_child(actor)
		actor.configure(host,spec)
		var collider: CollisionShape3D = actor.get_child(0)
		var center = Vector2(actor.position.x,actor.position.z)
		var support: float = host.level.layout.capsule_floor_support(center,Enemy.capsule_radius(actor.kind))
		var floor_point: Vector3 = host.level.layout.world_position(spec.cell)
		var hover: float = 1.0 if actor.kind == "caster" else 0.0
		expect(absf(actor.position.y-support-0.03-hover)<0.00001,id+": fresh signed capsule clearance and unchanged hover")
		expect(actor.position.x == floor_point.x and actor.position.z == floor_point.z,id+": authored XZ unchanged")
		expect(is_equal_approx(collider.shape.radius,Enemy.capsule_radius(actor.kind)) and is_equal_approx(collider.shape.height,Enemy.capsule_height(actor.kind)) and collider.position.y == collider.shape.height/2,id+": original capsule dimensions/offset")
		if id == "heart_enemy_00":
			expect(spec.cell == [10.5,18.5] and actor.kind == "brute" and absf(floor_point.y+0.75)<0.00001,"Exact reproduced Heart brute ramp case")
			expect(floor_point.y+0.03 < support-0.001,"Old center-floor spawn demonstrably violates unchanged native allowance")
		else:
			expect(absf(support-floor_point.y)<0.00001,id+": independently authored flat control retains old height")
		if actor.kind == "caster":
			expect(actor.motion_mode == CharacterBody3D.MOTION_MODE_FLOATING and actor.floor_snap_length == 0,"Caster keeps floating motion and one-metre hover")
		else:
			expect(actor.motion_mode == CharacterBody3D.MOTION_MODE_GROUNDED and actor.floor_snap_length == 0.5,"Grounded role keeps snap/motion mode")
		await physics_frame
		await physics_frame
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = collider.shape
		query.transform = collider.global_transform
		query.collision_mask = 1|4
		query.exclude = [actor.get_rid()]
		expect(host.level.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),id+": actual native fresh capsule is clear of floor/walls/scenery")
		print("FRESH_CAPSULE_SUPPORT ",JSON.stringify({"id":id,"kind":actor.kind,"floor_y":floor_point.y,"support_y":support,"position_y":actor.position.y,"hover":hover,"signed_gap":actor.position.y-support,"arranged_constructor":true}))
		# An intentionally penetrated stored pose must still overwrite configure
		# exactly. Validation belongs to Main/Campaign, never this restore method.
		var snapshot: Dictionary = actor.snapshot()
		var stored = Vector3(actor.position.x,floor_point.y+0.03,actor.position.z)
		snapshot.position = [stored.x,stored.y,stored.z]
		actor.restore_snapshot(snapshot)
		expect(actor.snapshot() == snapshot,id+": restored snapshot remains byte-codec exact, no spawn repair leaks into saved pose")
		actor.free()
		await physics_frame
	host.level.free()
	host.level = null
	host.free()
	await physics_frame
	print("FRESH_CAPSULE_SUPPORT_RESULT failures=",failures,"; real native constructor overlaps/flat/hover/exact restore, no combat/render/earned acceptance")
	quit(0 if failures == 0 else 1)
