extends SceneTree

# SYNTHETIC: isolate enabled standalone projectile observers; native Enemy physics
# releases a real projectile into an arranged, nonlethal enemy victim.
class OrganProbe:
	extends "res://tests/test_processional_earned_organ.gd".OrganMain
	var contact_count: int = 0
	var birth_clean: bool = false
	func _ready() -> void: set_process(false)
	func _physics_process(_delta: float) -> void: pass
	func impact(_point: Vector3) -> void: pass
	func enemy_event(actor, event: String) -> void:
		if event == "attack": o_attacks[actor.id] = Engine.get_physics_frames()
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		super._debug_projectile_event(projectile,event,data)
		if event == "configured_birth": birth_clean = o_ok and o_births.size() == 1
		if event == "queued_enemy_contact": contact_count += 1

class PalanquinProbe:
	extends "res://tests/test_processional_earned_palanquin.gd".PalanquinMain
	var contact_count: int = 0
	var birth_clean: bool = false
	func _ready() -> void: set_process(false)
	func _physics_process(_delta: float) -> void: pass
	func impact(_point: Vector3) -> void: pass
	func enemy_event(actor, event: String) -> void:
		if event == "attack": l_attacks[actor.id] = Engine.get_physics_frames()
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		super._debug_projectile_event(projectile,event,data)
		if event == "configured_birth": birth_clean = l_ok and l_births.size() == 1
		if event == "queued_enemy_contact": contact_count += 1

var failures: int = 0
var prior_mute: bool
func _initialize() -> void:
	prior_mute = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")
func expect(condition: bool, detail: String) -> void:
	if condition: return
	failures += 1
	push_error(detail)
func native_contact(palanquin: bool) -> void:
	var game = PalanquinProbe.new() if palanquin else OrganProbe.new()
	root.add_child(game)
	game.state.new_campaign(1)
	game.state.level_index = 2
	game.level = game.Level.new()
	game.add_child(game.level)
	expect(game.level.layout.load_level(2),"SETUP original Processional metadata")
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.position = Vector3(15,0.04,0)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.playing = true
	var floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(80,0.2,80)
	shape.position.y = -0.1
	floor_body.add_child(shape)
	game.level.add_child(floor_body)
	var caster = game.Enemy.new()
	game.level.add_child(caster)
	caster.configure(game,{"id":"processional_enemy_17" if palanquin else "processional_enemy_07","kind":"caster","cell":[0.5,0.5],"yaw":0})
	caster.position = Vector3(0,0.03,-6)
	caster.active = true
	caster.alerted = true
	caster.set_physics_process(false)
	var victim = game.Enemy.new()
	game.level.add_child(victim)
	victim.configure(game,{"id":"processional_enemy_03","kind":"worker","cell":[0.5,0.5],"yaw":0})
	victim.position = Vector3(0,0.03,0)
	victim.set_physics_process(false)
	var prior_hp: int = victim.hp
	game.enemies = [caster,victim]
	game.p_originals = {caster.id:{"instance":caster.get_instance_id()},victim.id:{"instance":victim.get_instance_id()}}
	game.organ_enabled = not palanquin
	if palanquin: game.palanquin_enabled = true
	await physics_frame
	await physics_frame
	await process_frame
	caster.target = victim
	caster._committed_target = victim
	caster._committed_aim = victim.global_position+Vector3.UP*0.55
	caster.telegraph_time = 1.0/120.0
	caster.attack_time = 20.0
	caster.set_physics_process(true)
	for frame in range(100):
		await physics_frame
		await process_frame
		if game.contact_count > 0: break
	caster.set_physics_process(false)
	var ok: bool = game.l_ok if palanquin else game.o_ok
	var births: Dictionary = game.l_births if palanquin else game.o_births
	var contacts: Dictionary = game.l_contacts if palanquin else game.o_contacts
	var used: Dictionary = game.l_used if palanquin else game.o_used
	var pending: Dictionary = game.l_pending if palanquin else game.o_pending
	expect(game.birth_clean and births.size() == 1 and game.contact_count == 1 and victim.hp == prior_hp-14 and victim.hp > 0,"SETUP admitted actual caster birth and one native nonlethal enemy contact")
	expect(ok and contacts.is_empty() and used.is_empty() and pending.is_empty(),"COMPATIBILITY enabled standalone "+("Palanquin" if palanquin else "Organ")+" ignores only new enemy event without changing Player-contact ledger")
	game.queue_free()
	await process_frame
	await process_frame
func run() -> void:
	var args = OS.get_cmdline_user_args()
	if "--organ" in args: await native_contact(false)
	elif "--palanquin" in args: await native_contact(true)
	else:
		await native_contact(false)
		await native_contact(true)
	AudioServer.set_bus_mute(0,prior_mute)
	if failures == 0: print("PASS SYNTHETIC enabled standalone observers/native enemy contact; not earned campaign evidence")
	quit(0 if failures == 0 else 1)
