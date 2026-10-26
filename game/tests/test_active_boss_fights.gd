extends SceneTree

const PassivePhysicsStep = preload("res://tests/passive_physics_step.gd")
const AudioDrainClock = preload("res://tests/wall_clock_wait.gd")

const ROUTES = {
	4: [[25.5,4.75],[35.5,4.75],[35.5,14.0],[25.5,14.0]],
	7: [[41.0,15.5],[41.0,4.5],[27.5,4.5],[27.5,15.5]]}
const ENTRIES = {4: [25.5,14.5], 7: [31.5,16.5]}
const ACTIONS = ["move_left","move_right","move_forward","move_back","fire"]
const LIMIT = 3600
var game
var retired: Array = []
var prefix = "user://active_boss_fights_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())

class ObservedMain:
	extends "res://scripts/main.gd"
	var boss_id: String
	var attacks: Array = [0,0]
	var deaths: int = 0
	var player_finish: bool = false
	var firing: bool = false
	var ticks: int = 0
	var rate_ok: bool = true
	func _physics_process(delta: float) -> void:
		if playing and not get_tree().paused:
			ticks += 1
			rate_ok = rate_ok and absf(delta-1.0/60.0) < 0.000001
	func enemy_event(actor, event: String) -> void:
		if playing and actor._current_map() and actor.active and actor.id == boss_id:
			if event == "attack" and actor._committed_target == player:
				if actor.phase == 0 and actor.hp >= actor.max_hp/2.0: attacks[0] += 1
				if actor.phase == 1 and actor.hp < actor.max_hp/2.0: attacks[1] += 1
				print("BOSS_ATTACK id=",boss_id," phase=",actor.phase," hp=",actor.hp," tick=",ticks)
			if event == "death":
				deaths += 1
				player_finish = firing and actor.target == player
		super.enemy_event(actor,event)

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	if not expect(Engine.physics_ticks_per_second == 60,"SETUP: requires native 60-Hz physics"):
		await finish(1)
		return
	release_actions()
	game = ObservedMain.new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	game.set_process_unhandled_input(false)
	for index in [4,7]:
		if not await fight(index):
			await finish(1)
			return
		retire_level()
		paused = false
		await process_frame
		await process_frame
	print("PASS controlled actual-Main active Nursery/Heart fights; synthetic seals/poses/checkpoint/gate, finite finale supplies, perfect aim and waypoint input. Not branch traversal, campaign budget, human input, graphics or packed-app acceptance.")
	await finish(0)

func fight(index: int) -> bool:
	seed(1300+index)
	game.set_process(false)
	game.state.new_campaign(1)
	game.state.level_index = index
	game.loaded_positions = false
	await game.start_level()
	if not expect(game.playing and not game.placement_pending and is_instance_valid(game.level) and is_instance_valid(game.player),"Actual Main startup must finish before staging"): return false
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	await physics_frame
	await physics_frame
	var data: Dictionary = game.level.layout.data
	var finale: Dictionary = data.encounters.filter(func(spec): return spec.id == data.id+"_finale")[0]
	game.boss_id = "nursery_warden" if index == 4 else "heart_choir_avatar"
	var boss = game.enemies.filter(func(actor): return actor.id == game.boss_id)[0]
	var actual_ids: Array = game.enemies.map(func(actor): return actor.id)
	var authored_ids: Array = data.enemies.map(func(spec): return spec.id)
	actual_ids.sort()
	authored_ids.sort()
	if not expect(actual_ids == authored_ids,"Complete actual authored actor membership must start"): return false
	if not expect(game.state.health == 100 and game.state.armor == 0 and game.state.ammo == [0,90,0,0,0,0] and game.state.owned_weapons == [0,1] and game.state.weapon == 1,"Fresh normal campaign uses only default HP/pistol inventory"): return false
	if not expect(boss.hp == boss.max_hp and boss.max_hp == (1200 if index == 4 else 1600) and boss.phase == 0 and dormant_except(""),"Full-health manifestation and all authored groups start dormant"): return false
	# Synthetic setup: no branch traversal or campaign resource budget is claimed.
	for spec in data.interactions:
		if spec.kind == "key": game.collect_key(spec.id)
	for kind in ["rivets","armor"]:
		var pod: Dictionary = data.pickups.filter(func(spec): return spec.id == data.id+"_finale_"+kind)[0]
		if not stage(pod.cell): return false
		var before: int = game.state.ammo[1] if kind == "rivets" else game.state.armor
		if not await PassivePhysicsStep.scan(game): return false
		game._process(0) # Render semantics only; staged player/actor physics stays held.
		var after: int = game.state.ammo[1] if kind == "rivets" else game.state.armor
		var capacity: int = game.player.WEAPONS[1].max_ammo if kind == "rivets" else 200
		if not expect(after == mini(capacity,before+int(pod.amount)) and game.state.removed.count(pod.id) == 1 and not game.level.markers.has(pod.id),"Finite authored finale pickup uses production cap/removal: "+pod.id): return false
	var checkpoint: Dictionary = data.interactions.filter(func(spec): return spec.kind == "checkpoint")[0]
	if not stage(checkpoint.cell): return false
	if not await PassivePhysicsStep.scan(game): return false
	game._process(0)
	if not expect(game.state.checkpoint_id == checkpoint.id and FileAccess.file_exists(game.progress_path) and dormant_except(""),"Synthetic pose captures actual pre-finale checkpoint with dormant actors"): return false
	var saved = load("res://scripts/campaign.gd").new()
	if not expect(saved.load_progress(game.progress_path) and saved.level_index == index and saved.checkpoint_id == checkpoint.id,"Current fight checkpoint must persist through real Campaign loader; stale previous-level file is rejected"): return false
	for gate in data.doors:
		if not expect(game.unlock_door(gate.id) and not game.level.doors.has(gate.id),"Actual two-seal gate opens"): return false
	if not stage(ENTRIES[index]): return false
	game._process(0) # Real finale activation through its authored region, not an active-state edit.
	if not expect("encounter:"+finale.id in game.state.removed and boss.active and dormant_except(finale.id),"Only the actual finale region activates its authored actors"): return false
	if not expect(game.state.health == 100 and game.state.ammo[1] == (150 if index == 4 else 170) and game.state.armor == (60 if index == 4 else 40),"Staged resources are exactly default plus finite finale supplies"): return false
	return await battle(index,boss,finale)

func battle(index: int, boss, finale: Dictionary, carried_inventory: bool = false) -> bool:
	game.attacks = [0,0]
	game.deaths = 0
	game.player_finish = false
	game.ticks = 0
	game.rate_ok = true
	var rounds: int = game.state.ammo[1]
	var shots: int = 0
	var spent := [0,0,0,0,0,0]
	var corner: int = 0
	var travelled: float = 0
	var previous: Vector3 = game.player.position
	var projectile_samples: Dictionary = {}
	var projectile_steps: int = 0
	game.set_process(true)
	game.player.set_physics_process(true)
	for actor in game.enemies: actor.set_physics_process(true)
	for tick in range(LIMIT):
		await physics_frame
		if not expect(game.playing and not paused and game.state.health > 0,"Active fight interrupted/dead; no silent resume"): return false
		if boss.hp <= 0: break
		for flight in game.level.get_children():
			if flight.get_script() != preload("res://scripts/projectile.gd") or flight.shooter != boss or flight.is_queued_for_deletion(): continue
			var id: int = flight.get_instance_id()
			if projectile_samples.has(id):
				var sample: Dictionary = projectile_samples[id]
				if flight.global_position.distance_to(sample.position) > 0.001 and flight.lifetime < sample.lifetime: projectile_steps += 1
			projectile_samples[id] = {"position":flight.global_position,"lifetime":flight.lifetime}
		travelled += previous.distance_to(game.player.position)
		previous = game.player.position
		var target = visible_target(boss)
		if target != null:
			var collider: CollisionShape3D = target.get_child(0)
			var aim: Vector3 = target.global_position+collider.position
			var heading: Vector3 = aim-game.player.camera.global_position
			game.player.rotation.y = atan2(-heading.x,-heading.z)
			game.player.camera.look_at(aim,Vector3.UP)
		else: game.player.camera.rotation = Vector3(-1.3,0,0)
		var waypoint: Vector3 = game.level.layout.world_position(ROUTES[index][corner])
		var direction: Vector3 = waypoint-game.player.position
		direction.y = 0
		if direction.length() < 1.0: corner = (corner+1)%ROUTES[index].size()
		var local: Vector3 = game.player.basis.inverse()*direction.normalized()
		release_actions()
		for action_strength in [["move_right",local.x],["move_left",-local.x],["move_back",local.z],["move_forward",-local.z]]:
			if action_strength[1] > 0: Input.action_press(action_strength[0],action_strength[1])
		var before: int = game.state.ammo[1]
		var ammo_before: Array = game.state.ammo.duplicate()
		var weapon_before: int = game.state.weapon
		game.firing = true
		var accepted: bool = game.player.fire() # One call per native combat tick; no fire action/double stepping.
		game.firing = false
		if accepted:
			shots += 1
			if weapon_before > 0: spent[weapon_before] += 1
		if not carried_inventory:
			if not expect(game.state.weapon == 1 and game.state.ammo[1] == before-(1 if accepted else 0) and game.state.ammo[1] == rounds-shots,"Each accepted pistol shot spends one round; rejected calls spend zero"): return false
		else:
			if not expect(weapon_before in game.state.owned_weapons,"Finite campaign fight uses only carried weapon ownership"): return false
			for slot in range(6):
				var cost: int = 1 if accepted and slot > 0 and slot == weapon_before else 0
				if not expect(game.state.ammo[slot] == ammo_before[slot]-cost and game.state.ammo[slot] >= 0,"Every accepted carried-weapon shot spends exactly its own round; rejected calls spend zero"): return false
		if not battle_groups_ok(finale.id): return false
		if tick%300 == 0: print("FIGHT index=",index," tick=",tick," hp=",game.state.health," boss_hp=",boss.hp," phase=",boss.phase," rounds=",game.state.ammo[1]," position=",game.player.position," attacks=",game.attacks)
	release_actions()
	if not expect(projectile_steps > 0,"Boss-owned native projectile position and lifetime must progress across automatic physics ticks"): return false
	if not expect(boss.hp == 0 and boss.phase == 1 and game.attacks[0] > 0 and game.attacks[1] > 0 and game.player_finish,"Natural half-health phase and player-directed attacks precede player-weapon finishing hit within 3600 ticks"): return false
	for tick in range(15): await physics_frame
	if not expect(game.playing and not paused and game.state.health > 0 and game.deaths == 1 and game.state.removed.count(boss.id) == 1 and boss.collision_layer == 0 and boss.collision_mask == 0,"Surviving player and once-only boss death/removal remain stable"): return false
	if not expect(game.rate_ok and game.ticks > 15 and travelled > 9.0,"Actual automatic 60-Hz physics and nonstationary player movement are observed"): return false
	print("ACTIVE_FIGHT index=",index," ticks=",game.ticks," shots=",shots," hp=",game.state.health," armor=",game.state.armor," travelled=",travelled," attacks=",game.attacks," deaths=",game.deaths," projectile_steps=",projectile_steps," carried_inventory=",carried_inventory," spent=",spent)
	return true

func battle_groups_ok(finale: String) -> bool:
	return expect(dormant_except(finale),"Battle must not activate unrelated authored groups")

func dormant_except(finale: String) -> bool:
	for actor in game.enemies:
		if not actor.encounter_id.is_empty() and actor.encounter_id != finale and actor.active: return false
	for group in game.level.layout.data.encounters:
		if group.id != finale and "encounter:"+group.id in game.state.removed: return false
	return true

func visible_target(boss):
	var chosen = null
	var distance: float = INF
	var origin: Vector3 = game.player.camera.global_position
	for actor in game.enemies:
		if actor.hp <= 0 or not actor.active or actor.is_queued_for_deletion(): continue
		var aim: Vector3 = actor.global_position+actor.get_child(0).position
		var query = PhysicsRayQueryParameters3D.create(origin,aim,1|4)
		query.exclude = [game.player.get_rid()]
		var hit = game.level.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider != actor: continue
		var score: float = origin.distance_to(aim)+(1000.0 if actor == boss else 0.0)
		if score < distance:
			distance = score
			chosen = actor
	return chosen

func stage(cell: Array) -> bool:
	var layout = game.level.layout
	var point: Vector3 = layout.world_position(cell)
	var space = game.level.get_world_3d().direct_space_state
	var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*0.5,1))
	if not expect(layout.is_walkable(Vector2i(floori(cell[0]),floori(cell[1]))) and not hit.is_empty() and absf(hit.position.y-point.y) <= 0.08 and hit.normal.y >= 0.7,"Synthetic staging needs actual native floor: "+str(cell)): return false
	var collider: CollisionShape3D = game.player.get_child(0)
	var pose: Vector3 = point+Vector3.UP*0.04
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(Basis.IDENTITY,pose+collider.position)
	query.collision_mask = game.player.collision_mask
	query.exclude = [game.player.get_rid()]
	if not expect(space.intersect_shape(query,1).is_empty(),"Synthetic staging needs native capsule clearance: "+str(cell)): return false
	game.player.position = pose
	game.player.velocity = Vector3.ZERO
	return true

func release_actions() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action): Input.action_release(action)

func retire_level() -> void:
	if is_instance_valid(game.level):
		retired.append(weakref(game.level))
		for child in game.level.get_children(): retired.append(weakref(child))
	game.show_title()

func finish(status: int) -> void:
	release_actions()
	if is_instance_valid(game):
		retire_level()
		for node in [game,game.music,game.effects]: retired.append(weakref(node))
		game.music.stop()
	paused = false
	await create_timer(0.1,true).timeout
	await AudioDrainClock.seconds(self,0.15)
	if is_instance_valid(game): game.free()
	await process_frame
	await process_frame
	if not expect(retired.all(func(reference): return reference.get_ref() == null),"Native level/player/actor/projectile/Main/audio nodes must drain"): status = 1
	for suffix in ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]:
		var path: String = prefix+suffix
		if FileAccess.file_exists(path) and not expect(DirAccess.remove_absolute(path) == OK,"Remove only unique isolated fixture profile"): status = 1
	quit(status)

func expect(ok: bool, label: String) -> bool:
	if not ok: push_error(label)
	return ok
