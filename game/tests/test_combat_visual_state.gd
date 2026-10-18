extends SceneTree

const Projectile = preload("res://scripts/projectile.gd")

class NativeGame extends "res://scripts/main.gd":
	func _ready() -> void: set_process(false)

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	var game = NativeGame.new()
	root.add_child(game)
	game.state.new_campaign(1)
	game.level = game.Level.new()
	game.add_child(game.level)
	game.level.layout.load_level(0)
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.set_physics_process(false)
	game.player.position = Vector3(0,.04,-10)
	game.playing = true
	var actor = game.Enemy.new()
	game.level.add_child(actor)
	actor.configure(game,{"id":"visual_guardian","kind":"guardian","cell":[.5,.5],"yaw":0})
	actor.position = Vector3.ZERO
	actor.set_physics_process(false)
	actor.target = game.player
	game.enemies = [actor]
	await physics_frame
	await physics_frame
	actor._begin_attack(game.player.position+Vector3.UP)
	if not actor.has_method("combat_visual_state"):
		push_error("NC04 RED: actual committed windup has no read-only presentation state")
		game.free()
		await process_frame
		quit(1)
		return
	var state: Dictionary = actor.combat_visual_state()
	if state.get("phase","") != "windup" or state.get("progress",-1) != 0:
		push_error("Actual start of committed guardian tell must report windup progress zero")
		game.free()
		await process_frame
		quit(1)
		return
	var failures := 0
	actor.telegraph_time = 0
	actor._release_attack()
	var released: Dictionary = actor.combat_visual_state()
	if released.get("phase") != "release" or released.get("progress",0) != 1:
		failures += 1
		push_error("Instantaneous guardian discharge must expose its actual release event")
	game.playing = false
	await physics_frame
	await physics_frame
	actor._physics_process(.5)
	if released != actor.combat_visual_state():
		failures += 1
		push_error("Paused actor release observation must not advance with global physics frames")
	game.playing = true
	actor.collision_layer = 0
	var floor = game.level._box(Vector3(20,.2,30),Vector3(0,-.1,-10),null,true)
	var wall = game.level._box(Vector3(10,6,.1),Vector3(0,3,-.8),null,true)
	var brute = game.Enemy.new()
	game.level.add_child(brute)
	brute.configure(game,{"id":"visual_brute","kind":"brute","cell":[.5,.5],"yaw":0})
	brute.position = Vector3.ZERO
	brute.set_physics_process(false)
	brute.target = game.player
	game.enemies.append(brute)
	await physics_frame
	await physics_frame
	brute._begin_attack(game.player.position+Vector3.UP)
	brute.telegraph_time = 0
	brute._release_attack()
	brute._physics_process(1.0/60.0)
	if not brute.is_on_wall() or brute._rush_time != 0 or brute.pose_time <= brute.recovery_time:
		failures += 1
		push_error("SETUP actual early native wall collision leaves longer pose than recovery")
	await physics_frame
	brute._physics_process(.81)
	var recovery: Dictionary = brute.combat_visual_state()
	print("MEASURE early wall recovery=",brute.recovery_time," pose=",brute.pose_time," reported=",recovery)
	if recovery.get("phase") != "recovery" or recovery.get("progress",1) >= 1 or brute.pose_time <= 0:
		failures += 1
		push_error("Recovery progress cannot finish while its actual admitted pose remains")
	wall.collision_layer = 0
	brute.collision_layer = 0
	for child in game.level.get_children():
		if child is Projectile: child.free()
	for role in ["crawler","worker","caster","brute","guardian","summoner","nursery_warden","choir_avatar"]:
		var body = game.Enemy.new()
		game.level.add_child(body)
		body.configure(game,{"id":"state_"+role,"kind":role,"cell":[.5,.5],"yaw":0})
		body.position = Vector3(5,1 if role == "caster" or role == "choir_avatar" else 0,-2)
		body.set_physics_process(false)
		body.target = game.player
		game.enemies.append(body)
		await physics_frame
		body._begin_attack(game.player.position+Vector3.UP)
		body._physics_process(body.WINDUPS[role]*.5)
		var windup: Dictionary = body.combat_visual_state()
		if windup.get("phase") != "windup" or absf(windup.get("progress",0)-.5) > .00001:
			failures += 1
			push_error("Actual half windup must derive normalized progress for "+role)
		var timers = [body.telegraph_time,body.pose_time,body.recovery_time,body._rush_time,body._attack_variant,body._committed_variant,body._released,body._rush_duration,body._recovery_duration,body.hp,body.position,body.velocity,game.state.to_dict()]
		for index in 20: body.combat_visual_state()
		if timers != [body.telegraph_time,body.pose_time,body.recovery_time,body._rush_time,body._attack_variant,body._committed_variant,body._released,body._rush_duration,body._recovery_duration,body.hp,body.position,body.velocity,game.state.to_dict()]:
			failures += 1
			push_error("Presentation reads must not mutate gameplay timers/variant/resources for "+role)
		body.take_damage(1,game.player)
		var counter: Dictionary = body.combat_visual_state()
		if counter.get("phase") != "stagger" or counter.get("variant",0) != -1 or not counter.get("hurt",false):
			failures += 1
			push_error("Actual windup counter cancels advertised commitment for "+role)
		body.take_damage(body.hp,game.player)
		var dead: Dictionary = body.combat_visual_state()
		if dead.get("phase") != "dead" or dead.get("variant",0) != -1:
			failures += 1
			push_error("Same tick death cannot advertise an attack for "+role)
		body.free()
	for role in ["nursery_warden","choir_avatar"]:
		var boss = game.Enemy.new()
		game.level.add_child(boss)
		boss.configure(game,{"id":"variant_"+role,"kind":role,"cell":[.5,.5],"yaw":0})
		boss.position = Vector3(5,1 if role == "choir_avatar" else 0,-2)
		boss.set_physics_process(false)
		boss.target = game.player
		await physics_frame
		for variant in [0,1]:
			boss._attack_variant = variant
			boss._begin_attack(game.player.position+Vector3.UP)
			if boss.combat_visual_state().variant != variant:
				failures += 1
				push_error("Boss windup binds pending variant")
			boss.telegraph_time = 0
			var before: int = game.level.get_child_count()
			boss._release_attack()
			var born: int = game.level.get_child_count()-before
			var expected := 0 if role == "nursery_warden" and variant == 0 else 3 if variant == 0 or role == "nursery_warden" else 8
			if born != expected or boss._attack_variant != 1-variant or boss.combat_visual_state().variant != variant:
				failures += 1
				push_error("Actual boss release count and displayed commitment agree after next-variant toggle")
			for child in game.level.get_children():
				if child is Projectile: child.free()
			boss._rush_time = 0
		boss.queue_free()
		if not boss.combat_visual_state().is_empty():
			failures += 1
			push_error("Queued map actor cannot expose presentation state")
		await process_frame
	var cancelled = game.Enemy.new()
	game.level.add_child(cancelled)
	cancelled.configure(game,{"id":"cancel_charge","kind":"brute","cell":[.5,.5],"yaw":0})
	cancelled.position = Vector3(5,0,-2)
	cancelled.set_physics_process(false)
	var victim = game.Enemy.new()
	game.level.add_child(victim)
	victim.configure(game,{"id":"lost_target","kind":"worker","cell":[.5,.5],"yaw":0})
	victim.position = Vector3(5,0,-8)
	victim.set_physics_process(false)
	cancelled.target = victim
	await physics_frame
	cancelled._begin_attack(victim.position+Vector3.UP)
	cancelled.telegraph_time = 0
	cancelled._release_attack()
	victim.free()
	cancelled.attack_time = 10
	cancelled._physics_process(.01)
	if cancelled._rush_time != 0 or cancelled.combat_visual_state().variant != -1:
		failures += 1
		push_error("Lost committed native target cancels charge and advertised variant")
	cancelled.free()
	var dormant = game.Enemy.new()
	game.level.add_child(dormant)
	dormant.configure(game,{"id":"dormant_tell","kind":"worker","cell":[.5,.5],"yaw":0,"encounter":"sleeping"})
	dormant.set_physics_process(false)
	if dormant.active or dormant.combat_visual_state().get("phase") != "dormant" or dormant.combat_visual_state().variant != -1:
		failures += 1
		push_error("Actual dormant encounter does not advertise a pending attack")
	dormant.active = true
	dormant.target = game.player
	dormant._begin_attack(game.player.position+Vector3.UP)
	var saved: Dictionary = dormant.snapshot()
	var fresh = game.Enemy.new()
	game.level.add_child(fresh)
	fresh.configure(game,{"id":"dormant_tell","kind":"worker","cell":[.5,.5],"yaw":0})
	fresh.set_physics_process(false)
	fresh.restore_snapshot(saved)
	if fresh.combat_visual_state().get("phase") != "idle" or fresh.combat_visual_state().variant != -1 or fresh.telegraph_time != 0:
		failures += 1
		push_error("Fresh snapshot restoration cannot replay an unsaved half-completed tell")
	fresh.free()
	dormant.free()
	for role in ["nursery_warden","choir_avatar"]:
		var crossing = game.Enemy.new()
		game.level.add_child(crossing)
		crossing.configure(game,{"id":"phase_"+role,"kind":role,"cell":[.5,.5],"yaw":0})
		crossing.position = Vector3(5,1 if role == "choir_avatar" else 0,-2)
		crossing.set_physics_process(false)
		crossing.target = game.player
		crossing._attack_variant = 1
		await physics_frame
		crossing._begin_attack(game.player.position+Vector3.UP)
		crossing._counter_time = 2 # Preserve the real windup through an ineligible counter window.
		crossing.take_damage(int(crossing.max_hp/2)+1,game.player)
		crossing._physics_process(.01)
		var tell: Dictionary = crossing.combat_visual_state()
		if tell.phase != "windup" or tell.boss_phase != 1 or tell.variant != 1:
			failures += 1
			push_error("Real boss half-health transition retains its committed tell variant")
		crossing.telegraph_time = 0
		var before: int = game.level.get_child_count()
		crossing._release_attack()
		var rupture_release: Dictionary = crossing.combat_visual_state()
		if game.level.get_child_count()-before != (5 if role == "nursery_warden" else 12) or rupture_release.boss_phase != 1 or rupture_release.variant != 1:
			failures += 1
			push_error("Displayed ruptured boss tell matches its actual release pattern")
		for child in game.level.get_children():
			if child is Projectile: child.free()
		crossing.free()
	game.free()
	await process_frame
	if failures > 0:
		quit(1)
		return
	print("PASS actual8-role combat state/purity/counter/death, pause/wall recovery, boss variant/phase, target loss/dormancy/restore; not authored visual approval")
	quit()
