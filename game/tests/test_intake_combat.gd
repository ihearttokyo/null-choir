extends "res://tests/test_intake_walk.gd"

const COMBAT_LIMIT = 1200
const APPROACH = [[14.5,24.5],[11.5,23.5],[10.5,23.5]]

class CombatMain:
	extends "res://scripts/main.gd"
	var ticks: int = 0
	var rate_ok: bool = true
	var shots: int = 0
	var hits: int = 0
	var impacts: int = 0
	var attacks: int = 0
	var deaths: int = 0
	var last_shot: int = -1
	var shot_slot: float = -1.0
	var shot_ok: bool = true
	var feedback_ok: bool = true
	var player_finish: bool = false
	var victim
	static func accepted_shot_slot(tick: int, last_tick: int, slot: float, interval_ticks: float, count: int, ammo: int, weapon: int, held: bool) -> float:
		if weapon != 1 or not held or count < 1 or ammo < 0 or ammo != 125-count: return -1.0
		if last_tick >= 0:
			var earliest: float = slot if slot >= 0.0 else float(last_tick)+interval_ticks
			if tick <= last_tick or float(tick)+0.000001 < earliest: return -1.0
		var next_slot: float = float(tick)+interval_ticks
		if slot >= 0.0:
			next_slot = slot+interval_ticks
			# Missed nominal slots are discarded, never converted into accepted shots.
			if next_slot <= float(tick)+0.000001:
				next_slot += (floorf((float(tick)+0.000001-next_slot)/interval_ticks)+1.0)*interval_ticks
		return next_slot
	func _physics_process(delta: float) -> void:
		if playing and not get_tree().paused:
			ticks += 1
			rate_ok = rate_ok and absf(delta-1.0/60.0) < 0.000001
			if not Input.is_action_pressed("fire"): shot_slot = -1.0
	func shot(weapon: int) -> void:
		shots += 1
		shot_slot = accepted_shot_slot(ticks,last_shot,shot_slot,Player.WEAPONS[1].interval*60.0,shots,state.ammo[1],weapon,Input.is_action_pressed("fire"))
		shot_ok = shot_ok and Engine.is_in_physics_frame() and shot_slot >= 0.0
		last_shot = ticks
		super.shot(weapon)
		var visuals = level.get_node_or_null("AmmoVisuals")
		feedback_ok = feedback_ok and visuals != null and visuals.slots.any(func(slot): return slot.row == 1 and slot.sprite.visible)
	func hit_feedback() -> void:
		hits += 1
		super.hit_feedback()
		feedback_ok = feedback_ok and hit_flash > 0
	func impact(point: Vector3) -> void:
		impacts += 1
		super.impact(point)
		var visuals = level.get_node_or_null("AmmoVisuals")
		feedback_ok = feedback_ok and visuals != null and visuals.slots.any(func(slot): return slot.row == 3 and slot.sprite.visible)
	func enemy_event(actor, event: String) -> void:
		if actor == victim and playing and actor._current_map() and actor.active:
			if event == "attack" and actor._committed_target == player: attacks += 1
			if event == "death":
				deaths += 1
				player_finish = Input.is_action_pressed("fire") and last_shot == ticks and actor.target == player
		super.enemy_event(actor,event)

func run() -> void:
	prefix = "user://intake_combat_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	release_actions()
	if not expect(Engine.physics_ticks_per_second == 60,"SETUP: requires native 60-Hz physics"):
		await finish(1)
		return
	seed(1304)
	game = CombatMain.new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	if not press_menu("New campaign") or not press_menu("Relentless") or not await wait_entry() or not await walk_route():
		await finish(1)
		return
	game.victim = game.enemies.filter(func(actor): return actor.id == "intake_enemy_00")[0]
	var spec: Dictionary = route_level.layout.data.enemies.filter(func(actor): return actor.id == game.victim.id)[0]
	if not expect(spec.kind == "worker" and Vector2(spec.cell[0],spec.cell[1]) == Vector2(8.5,23.5) and game.victim.encounter_id.is_empty() and game.victim.active and game.victim.hp == 90 and game.shots == 0,"Original full-health early worker is naturally active; verified pickup precedes all firing"):
		await finish(1)
		return
	if not await approach() or not await combat():
		await finish(1)
		return
	print("PASS source-native Intake entry pickup, real approach and active early-worker pistol defeat; virtual movement/camera aim/Input fire, finite ammo and all 23 automatic original actors. Not human/OS input, GPU/audio fidelity, packed-app or full-campaign acceptance.")
	await finish(0)

func approach() -> bool:
	for cell in APPROACH:
		var target = clear_point(cell)
		if not expect(target != null,"BLOCKED native approach endpoint "+str(cell)+"; parent must inspect floor/capsule trace"): return false
		var start: Vector3 = route_player.position
		var samples: int = ceili(start.distance_to(target)/0.5)
		for sample in range(samples+1):
			var point: Vector3 = start.lerp(target,float(sample)/maxi(1,samples))
			if not expect(clear_point([point.x/4.0,point.z/4.0]) != null,"BLOCKED native approach segment at "+str(point)+"; no staging or relaxed clearance"): return false
		while Vector2(route_player.position.x-target.x,route_player.position.z-target.z).length() > 0.12:
			if not live_route(): return false
			var distance: float = Vector2(route_player.position.x-target.x,route_player.position.z-target.z).length()
			route_player.look_at(Vector3(target.x,route_player.position.y,target.z),Vector3.UP)
			var deadzone: float = 0.0
			for action in ["move_left","move_right","move_forward","move_back"]: deadzone += InputMap.action_get_deadzone(action)/4.0
			Input.action_press("move_forward",deadzone+(1.0-deadzone)*minf(1.0,distance*6.0/9.0))
			if not await route_tick(): return false
		release_actions()
		for settling in range(12):
			if not await route_tick(): return false
		if not expect(route_player.position.distance_to(target) < 0.2 and game.state.ammo[1] == 125 and game.shots == 0,"Approach settles by real movement with no firing/refill"): return false
		print("INTAKE_APPROACH cell=",cell," tick=",walk_ticks," position=",route_player.position," hp=",game.state.health)
	return true

func combat() -> bool:
	var victim = game.victim
	var damage_steps: int = 0
	var visible_ticks: int = 0
	var hp: int = victim.hp
	print("INTAKE_COMBAT_START player=",route_player.position," worker=",victim.position," hp=",hp," active=",victim.active," alerted=",victim.alerted)
	for tick in range(240):
		if not live_route(): return false
		if victim.hp <= 0: break
		var aim: Vector3 = victim.global_position+victim.get_child(0).position
		var heading: Vector3 = aim-route_player.camera.global_position
		var query = PhysicsRayQueryParameters3D.create(route_player.camera.global_position,aim,1|4)
		query.exclude = [route_player.get_rid()]
		var hit = route_level.get_world_3d().direct_space_state.intersect_ray(query)
		if tick%60 == 0: print("INTAKE_LOS tick=",tick," player=",route_player.position," worker=",victim.position," hp=",victim.hp," hit=",hit," shots=",game.shots)
		release_actions()
		if not hit.is_empty() and hit.collider == victim and victim.active and victim.alerted and victim.target == route_player:
			visible_ticks += 1
			route_player.rotation.y = atan2(-heading.x,-heading.z)
			route_player.camera.look_at(aim,Vector3.UP)
			Input.action_press("fire")
		if not await route_tick(): return false
		if victim.hp < hp: damage_steps += 1
		hp = victim.hp
		if not expect(game.shot_ok and game.state.weapon == 1 and game.state.ammo[1] == 125-game.shots and game.state.ammo[1] > 0,"Passive accepted-shot count equals finite ammo delta and native pistol cooldown"): return false
	release_actions()
	if not expect(victim.hp == 0 and game.deaths == 1 and game.player_finish and visible_ticks > 0 and damage_steps > 0 and game.hits > 0 and game.impacts > 0 and game.feedback_ok,"BLOCKED early-worker fight: require actual LOS/damage/player finish/production feedback within 240 ticks; inspect last position and LOS, never stage or weaken"): return false
	for settling in range(15):
		if not await route_tick(): return false
	for actor in game.enemies:
		if not expect(actor.age-actors[actor.id][1] >= float(walk_ticks-2)/60.0,"Every original actor retains automatic native age progression: "+actor.id): return false
	if not expect(game.deaths == 1 and game.state.removed.count(victim.id) == 1 and game.state.removed.size() == 2 and game.state.removed.count("entry_ammo") == 1 and victim.collision_layer == 0 and victim.collision_mask == 0 and game.state.ammo == [0,125-game.shots,0,0,0,0] and game.state.armor == 0 and game.state.owned_weapons == [0,1] and game.state.weapon == 1 and game.rate_ok and game.ticks >= walk_ticks-2,"Once-only natural death/removal, finite entry-only supply, unchanged ownership and automatic Main persist"): return false
	print("INTAKE_COMBAT ticks=",walk_ticks," shots=",game.shots," hits=",game.hits," damage_steps=",damage_steps," attacks=",game.attacks," deaths=",game.deaths," ammo=",game.state.ammo[1]," health=",game.state.health," metres=",travelled," position=",route_player.position)
	return true

func route_tick() -> bool:
	# The inherited 600-tick walk remains bounded; this adds one finite approach/fight.
	if not expect(walk_ticks < COMBAT_LIMIT,"BLOCKED total 1200-tick route budget; inspect native geometry/LOS instead of enlarging the bot"): return false
	await physics_frame
	walk_ticks += 1
	if not live_route(): return false
	var point: Vector3 = route_player.position
	travelled += Vector2(point.x-previous.x,point.z-previous.z).length()
	peak = maxf(peak,Vector2(point.x-origin.x,point.z-origin.z).length())
	previous = point
	return true
