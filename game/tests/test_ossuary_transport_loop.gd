extends "res://tests/test_nursery_finale_loop.gd"

const Witness = preload("res://tests/ossuary_transport_witness.gd")
const Finale = preload("res://tests/ossuary_finale_witness.gd")
const Exit = preload("res://tests/ossuary_finale_exit_witness.gd")
# Exact dependency and production-field inventories are appended before delivery.
const OT_ENTRY = [[35.5,23.5],[34.5,23.5],[34.5,24.5],[35.5,25.5],[34.5,25.5],[34.5,24.5]]
const OT_APPROACH = [[30.5,24.5],[24.0,24.0],[13.5,24.5],[12.5,24.5],[6.5,24.5],[6.5,22.5]]
# x6.5 avoids the static altar candidate; native clearance/survival remains unproved.
const OT_BRIDGE = [[6.5,21.5],[6.5,18.5],[6.5,14.5],[9.5,15.0]]
const OT_RETURN = [[9.5,13.5],[13.5,13.5],[14.5,13.5],[16.5,13.5],[19.5,13.5]]
const OT_CLOSE = [[19.5,16.5],[19.5,20.5],[19.5,24.0],[24.0,24.0]]
const OT_BLOOD_GUARD = "NATIVE RED Ossuary transport requires real rebound queued E Blood, original marker retirement and warmed rib-bridge lights BEFORE first return"

class TransportMain:
	extends "res://tests/test_nursery_finale_loop.gd".NurseryFinaleMain
	var transport_witness
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if transport_witness != null: transport_witness.physics(delta)
	func shot(weapon: int) -> void:
		if transport_witness != null: transport_witness.before_shot(weapon)
		super.shot(weapon)
	func collect_pickup(id: String) -> void:
		var record: Dictionary = transport_witness.before_pickup(id) if transport_witness != null else {}
		super.collect_pickup(id)
		if transport_witness != null: transport_witness.after_pickup(record)
	func activate_encounter(id: String) -> void:
		var spec: Dictionary = transport_witness.before_encounter(id) if transport_witness != null else {}
		super.activate_encounter(id)
		if transport_witness != null: transport_witness.after_encounter(spec)
	func enemy_event(actor, event: String) -> void:
		if transport_witness != null: transport_witness.before_enemy(actor,event)
		super.enemy_event(actor,event)
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		if transport_witness != null: transport_witness.before_projectile(projectile,event,data)
		super._debug_projectile_event(projectile,event,data)
	func hurt_player(amount: int) -> void:
		if transport_witness != null: transport_witness.before_hurt(amount)
		super.hurt_player(amount)
		if transport_witness != null: transport_witness.after_hurt()
	func resolve_aim(origin: Vector3, direction: Vector3, max_range: float, melee: bool = false) -> Dictionary:
		var result: Dictionary = super.resolve_aim(origin,direction,max_range,melee)
		if transport_witness != null: transport_witness.after_aim(origin,max_range,melee,result)
		return result
	func interact() -> void:
		if transport_witness is Exit:
			if not _exit_lifecycle():
				transport_witness.forbidden("exit")
				return
			var observer = transport_witness
			if not observer.before_exit(): return
			super.interact()
			observer.after_exit()
			return
		if transport_witness != null: transport_witness.before_interact()
		super.interact()
	func _exit_lifecycle() -> bool:
		return transport_witness != null and transport_witness.get_script() == Exit and transport_witness.game == self
	func collect_key(id: String) -> void:
		if transport_witness != null: transport_witness.before_key(id)
		super.collect_key(id)
		if transport_witness != null: transport_witness.after_key(id)
	func _finale_lifecycle() -> bool:
		return transport_witness != null and transport_witness.get_script() == Finale and transport_witness.game == self
	func unlock_door(id: String) -> bool:
		if transport_witness != null:
			if not _finale_lifecycle():
				transport_witness.forbidden("gate")
				return false
			var observer = transport_witness
			if not observer.before_gate(id): return false
			var result: bool = super.unlock_door(id)
			observer.after_gate(result)
			return result
		return super.unlock_door(id)
	func _capture_actor_state() -> bool:
		if transport_witness != null:
			if not (_finale_lifecycle() or _exit_lifecycle()):
				transport_witness.forbidden("capture")
				return false
			var observer = transport_witness
			if not observer.before_capture(): return false
			var result: bool = super._capture_actor_state()
			observer.after_capture(result)
			return result
		return super._capture_actor_state()
	func _capture_game_mouse() -> void:
		if transport_witness != null:
			transport_witness.forbidden("mouse")
			return
		super._capture_game_mouse()
	func _save() -> Error:
		if transport_witness != null:
			if not (_finale_lifecycle() or _exit_lifecycle()):
				transport_witness.forbidden("save")
				return ERR_INVALID_DATA
			var observer = transport_witness
			if not observer.before_save(): return ERR_INVALID_DATA
			var result: Error = super._save()
			observer.after_save(result)
			return result
		return super._save()
	func start_level() -> void:
		if transport_witness != null:
			transport_witness.forbidden("start")
			return
		await super.start_level()
	func restart_level() -> void:
		if transport_witness != null:
			transport_witness.forbidden("restart")
			return
		await super.restart_level()
	func restore_checkpoint() -> void:
		if transport_witness != null:
			transport_witness.forbidden("restart")
			return
		await super.restore_checkpoint()

var ot_started: bool = false
var ot_fields: Array = []
var ot_frozen: Dictionary = {}
var ot_fixture_fields: Array = []
var ot_fixture_frozen: Dictionary = {}
var ot_witness
var ot_gate
var ot_input_events: Array = []

func run() -> void:
	if "--ossuary-transport-pin-rejection" in OS.get_cmdline_user_args():
		await transport_pin_rejection()
		return
	if "--ossuary-adapter-controls" in OS.get_cmdline_user_args():
		var controls_ok: bool = transport_controls()
		quit(0 if controls_ok else 1)
		return
	var result: bool = await walk_through_ossuary_transport(TransportMain.new())
	if result: print("PASS bounded earned Ossuary transport source route; synthetic native input only, not app/campaign/performance/hearing acceptance")
	await finish(0 if result else 1)

func finish(status: int) -> void:
	# Acceptance ends before inherited title/drain cleanup retires the current map.
	if ot_started and is_instance_valid(game):
		if Input.is_action_pressed("interact"): transport_key(false)
		release_actions()
		game.transport_witness = null
		ot_started = false
	await super.finish(status)

func transport_pins_match() -> bool:
	return finale_pins_match() and OT_PINS.keys().all(func(path): return FileAccess.get_sha256(path) == OT_PINS[path])

func walk_through_ossuary_transport(observer: TransportMain, profile_prefix: String = "") -> bool:
	# Refuse BEFORE inherited helper creates a scene, profile, preferences or input.
	if not expect(transport_pins_match(),"Exact transport/finale/all ancestor/current core/original map pins BEFORE adoption"):
		if is_instance_valid(observer) and observer != game and observer.get_parent() == null and not observer.is_inside_tree(): observer.free()
		return false
	if not await walk_through_nursery_finale(observer,profile_prefix): return false
	if not expect(transport_pins_match() and game.oss_ok and game.oss_enabled and game.oss_current() and game.budget() == Witness.CARRY and FileAccess.get_sha256(r_profile) == Witness.SAVE_SHA and finale_prior_frozen() and observer_witness(nf_entry_fields) == nf_entry_frozen,"actual accepted fresh27-actor Ossuary; earned normal-clock carry and pinned saved handoff"): return false
	if not transport_schema(): return false
	release_actions()
	# Retire only the final active entry observer; preceding disables are asserted.
	game.oss_enabled = false
	for property in game.get_property_list():
		var name: String = str(property.name)
		if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and not name in OT_PRODUCTION_FIELDS and name != "transport_witness":
			if not name in ot_fields: ot_fields.append(name)
	ot_fields.sort()
	ot_frozen = transport_prior_values()
	# Freeze the inherited SceneTree fixture as well, excluding native route bindings.
	for property in get_property_list():
		var name: String = str(property.name)
		if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and not name.begins_with("ot_") and not name in ["game","route_level","route_player"]: ot_fixture_fields.append(name)
	ot_fixture_frozen = transport_fixture_values()
	if not expect(ot_fields.all(func(name): return not name.ends_with("_enabled") or not game.get(name)) and game.prefix_bookkeeping_retired,"EVERY previous observer disabled before fresh witness"): return false
	route_level = game.level
	route_player = game.player
	ot_gate = weakref(route_level.doors["ossuary_transfer_gate"])
	ot_witness = Witness.new()
	if not ot_witness.adopt(game): return false
	game.transport_witness = ot_witness
	ot_started = true
	if not live_route(): return false
	if not await transport_route(OT_ENTRY+OT_APPROACH+OT_BRIDGE): return false
	if not await transport_fight(Witness.GROUPS[0]): return false
	if not await transport_blood(): return false
	if not await transport_route(OT_RETURN): return false
	if not await transport_fight(Witness.GROUPS[1]): return false
	if not await transport_route(OT_CLOSE): return false
	# Drain only finite native projectile lifetime, without changing lifetime/AI.
	for frame in range(246):
		release_actions()
		if not await route_tick(): return false
		await process_frame
	return transport_earned()

func transport_prior_values() -> Dictionary:
	var result: Dictionary = {}
	for name in ot_fields: result[name] = Witness.value_image(game.get(name))
	return result

func transport_fixture_values() -> Dictionary:
	var result: Dictionary = {}
	for name in ot_fixture_fields: result[name] = Witness.value_image(get(name))
	return result

func transport_prior_frozen() -> bool:
	return transport_prior_values() == ot_frozen and transport_fixture_values() == ot_fixture_frozen and ot_fields.all(func(name): return not name.ends_with("_enabled") or not game.get(name)) and game.prefix_bookkeeping_retired and observers_retired() and nf_retired.all(func(ref): return ref.get_ref() == null) and nf_marker_refs.values().all(func(ref): return ref.get_ref() == null)

func live_route() -> bool:
	if not ot_started: return super.live_route()
	return expect(transport_prior_frozen(),"all retired Main and fixture observer VALUES unchanged, including nf/oss") and expect(ot_witness.validate(),"Ossuary per-segment witness: "+str(ot_witness.failures))

func route_tick() -> bool:
	if not ot_started: return await super.route_tick()
	if not live_route(): return false
	await physics_frame
	return live_route()

func transport_schema() -> bool:
	var scene = game.level
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/06_ossuary.json"))
	# Both sides retain native JSON float numbers; no int-vs-float schema weakening.
	if not expect(FileAccess.get_sha256("res://data/06_ossuary.json") == NF_OSSUARY_SHA and scene.layout.data == original and original.id == "ossuary" and original.cell_size == 4.0 and original.enemies.size() == 27 and original.interactions[0] == Witness.BLOOD and original.loops[0] == {"id":"ossuary_loop_transport","hero":"ossuary_rib_bridge","route":[[24.0,24.0],[6.0,24.0],[6.0,18.0],[6.0,13.0],[19.0,13.0],[19.0,24.0],[24.0,24.0]]},"exact SHA-pinned original geometry/schema and authored rib-bridge transport loop"): return false
	return expect(InputMap.action_get_events("interact").any(func(event): return event is InputEventKey and event.physical_keycode == KEY_E) and original.encounters[0].enemy_ids.size() == 8 and original.encounters[2].enemy_ids.size() == 3,"actual rebound E binding and original first8/return3 actors")

func transport_fire() -> bool:
	Input.action_release("fire")
	if game.state.weapon != 1 or game.state.ammo[1] <= 0 or ot_witness.shots.size() >= Witness.SHOTS: return false
	var selected = null
	var nearest: float = game.Player.WEAPONS[1].range
	for actor in game.enemies:
		if not ot_witness.actor(actor) or actor.hp <= 0 or not actor.active: continue
		var aim: Vector3 = actor.global_position+actor.get_child(0).position
		var distance: float = route_player.camera.global_position.distance_to(aim)
		if distance >= nearest: continue
		var query = PhysicsRayQueryParameters3D.create(route_player.camera.global_position,aim,1|4)
		query.exclude = [route_player.get_rid()]
		var hit: Dictionary = route_level.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider == actor:
			selected = actor
			nearest = distance
	if selected == null: return false
	var aim: Vector3 = selected.global_position+selected.get_child(0).position
	var heading: Vector3 = aim-route_player.camera.global_position
	route_player.rotation.y = atan2(-heading.x,-heading.z)
	route_player.camera.look_at(aim,Vector3.UP)
	Input.action_press("fire")
	return true

func transport_route(cells: Array) -> bool:
	for cell in cells:
		var target: Vector3 = route_level.layout.world_position(cell)+Vector3.UP*0.04
		var began: int = Engine.get_physics_frames()
		var arrived: bool = false
		for frame in range(Witness.LEG):
			if not live_route(): return false
			var start: Vector3 = route_player.position
			var clear: bool = clear_point(cell) != null
			var samples: int = ceili(Vector2(start.x-target.x,start.z-target.z).length()/0.5)
			for sample in range(samples+1):
				# XZ interpolation only: each sample independently queries real floor triangles.
				var point: Vector3 = start.lerp(target,float(sample)/maxi(1,samples))
				if clear_point([point.x/4.0,point.z/4.0]) == null: clear = false
				if sample > 0:
					var prior: Vector3 = start.lerp(target,float(sample-1)/maxi(1,samples))
					if not nursery_seed_sweep([prior.x/4.0,prior.z/4.0],[point.x/4.0,point.z/4.0]): clear = false
			release_actions()
			if not clear:
				if not expect(transport_fire(),"Blocked transport leg requires visible active native target, not idle navigation: "+str(cell)): return false
			else:
				if Vector2(start.x-target.x,start.z-target.z).length() <= 0.12:
					arrived = true
					break
				if not transport_fire(): route_player.look_at(Vector3(target.x,route_player.position.y,target.z),Vector3.UP)
				nursery_finale_move(target)
			if not await route_tick(): return false
		if not expect(arrived and Engine.get_physics_frames()-began+12 < Witness.LEG,"new-only900-frame leg including settle: "+str(cell)): return false
		release_actions()
		for frame in range(12):
			transport_fire()
			if not await route_tick(): return false
		release_actions()
		await process_frame
		if not live_route() or not expect(route_player.position.distance_to(target) < 0.2 and clear_point(cell) != null,"actual settled native floor/capsule waypoint: "+str(cell)): return false
		ot_witness.waypoints.append(cell.duplicate())
		print("OSSUARY_TRANSPORT_HOP cell=",cell," frame=",Engine.get_physics_frames()-ot_witness.epoch," resources=",ot_witness.ledger)
	return true

func transport_fight(group: String) -> bool:
	if not expect(ot_witness.activated.has(group),"fight follows actual earned region activation: "+group): return false
	for frame in range(Witness.FIGHT):
		if not live_route(): return false
		if ot_witness.all_dead(group):
			release_actions()
			await process_frame
			return live_route()
		release_actions()
		if not transport_fire():
			var rows: Array = []
			for actor in game.enemies:
				if actor.hp <= 0 or not actor.active: continue
				var aim: Vector3 = actor.global_position+actor.get_child(0).position
				var query = PhysicsRayQueryParameters3D.create(route_player.camera.global_position,aim,1|4)
				query.exclude = [route_player.get_rid()]
				var hit: Dictionary = route_level.get_world_3d().direct_space_state.intersect_ray(query)
				var collider = hit.get("collider")
				rows.append({"id":actor.id,"hp":actor.hp,"position":actor.position,"target":actor.target.get_instance_id() if is_instance_valid(actor.target) else 0,"distance":route_player.camera.global_position.distance_to(aim),"hit":collider.id if is_instance_valid(collider) and collider.get_script() == game.Enemy else str(collider),"hit_position":hit.get("position"),"hit_rid":str(hit.get("rid"))})
			print("OSSUARY_FIGHT_NO_TARGET group=",group," player=",route_player.position," weapon=",game.state.weapon," ammo=",game.state.ammo[1]," shots=",ot_witness.shots.size()," frame=",Engine.get_physics_frames()-ot_witness.epoch," alive_rays=",rows)
			return expect(false,"finite native committed fight requires visible target: "+group)
		if not await route_tick(): return false
	release_actions()
	return expect(false,"new-only1800-frame fight cap: "+group)

func transport_key(pressed: bool) -> bool:
	var event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.keycode = KEY_E
	event.pressed = pressed
	if not expect(InputMap.event_is_action(event,"interact"),"transport uses actual physical rebound E binding"): return false
	ot_input_events.append([pressed,Engine.get_physics_frames()])
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	return true

func transport_blood() -> bool:
	if not live_route(): return false
	aim_interaction(Witness.BLOOD.cell)
	ot_witness.intent = Witness.BLOOD.id
	var omitted: bool = "--omit-ossuary-blood" in OS.get_cmdline_user_args()
	if not omitted and not transport_key(true): return false
	for frame in range(6):
		if not await route_tick(): return false
		if not ot_witness.inputs.is_empty(): break
	if not omitted and not transport_key(false): return false
	release_actions()
	ot_witness.intent = ""
	await process_frame
	if not live_route(): return false
	if omitted:
		if not expect(ot_witness.keys.is_empty() and game.state.keys.is_empty() and ot_witness.inputs.is_empty() and ot_input_events.is_empty() and not "ossuary_blood" in game.state.removed and route_level.markers.get("ossuary_blood") == ot_witness.markers.ossuary_blood.get_ref() and is_instance_valid(ot_witness.markers.ossuary_blood.get_ref()) and not ot_witness.markers.ossuary_blood.get_ref().is_queued_for_deletion() and ot_witness.activated.keys() == [Witness.GROUPS[0]] and transport_prior_frozen(),"omitted-Blood RED precondition: absent key, live marker, first return never entered, every prior value frozen"): return false
		print("OSSUARY_OMITTED_BLOOD_READY prior_frozen=true key_absent=true marker_live=true first_return=false")
	var warmed: bool = ["ossuary_bridge_feed","ossuary_bridge_core"].all(func(id): return route_level.machine_lights[id].light_color == Color(1.0,0.76,0.44))
	return expect(ot_witness.keys == ["blood"] and game.state.keys == ["blood"] and ot_witness.inputs.size() == 1 and ot_witness.inputs[0][0] == Witness.BLOOD.id and ot_input_events.size() == 2 and not route_level.markers.has(Witness.BLOOD.id) and ot_witness.markers[Witness.BLOOD.id].get_ref() == null and warmed and transport_prior_frozen(),OT_BLOOD_GUARD)

func transport_earned() -> bool:
	if not live_route(): return false
	var expected_ids: Array = route_level.layout.data.encounters[0].enemy_ids+route_level.layout.data.encounters[2].enemy_ids
	var dormant: Array = game.enemies.filter(func(actor): return ot_witness.originals.has(actor.id) and not actor.id in expected_ids)
	if not expect(expected_ids.size() == 11 and dormant.size() == 16 and expected_ids.all(func(id): return ot_witness.deaths.get(id,0) == 1) and ot_witness.deaths.size() == 11+ot_witness.summons.size() and ot_witness.summons.keys().all(func(id): return ot_witness.deaths.get(id,0) == 1) and ot_witness.all_dead(Witness.GROUPS[0]) and ot_witness.all_dead(Witness.GROUPS[1]) and ot_witness.activated.keys() == Witness.GROUPS and ot_witness.keys == ["blood"] and ot_witness.shots.size() > 0 and ot_witness.shots.size() <= Witness.SHOTS,"eleven original plus ALL actual legitimate summoned deaths;16 dormant originals; only Blood/two earned regions"): return false
	if not expect(ot_witness.waypoints == OT_ENTRY+OT_APPROACH+OT_BRIDGE+OT_RETURN+OT_CLOSE and route_player.position.distance_to(route_level.layout.world_position([24.0,24.0])+Vector3.UP*0.04) < 0.2 and game.state.position == route_player.position and game.state.yaw == game.Enemy.canonical_yaw(route_player.rotation.y) and game.state.pitch == clampf(route_player.camera.rotation.x,-1.35,1.35),"full bounded native transport route returns to original24,24 junction with actual CURRENT pose"): return false
	for id in ot_witness.markers:
		if id in ot_witness.removed and not expect(ot_witness.markers[id].get_ref() == null,"all collected original markers actually drained"): return false
	var gate = ot_gate.get_ref()
	if not expect(is_instance_valid(gate) and route_level.doors.get("ossuary_transfer_gate") == gate and gate.collision_layer == 1 and not "ossuary_transfer_gate" in game.state.removed and route_level.get_children().filter(func(node): return node.get_script() == preload("res://scripts/projectile.gd") and not node.is_queued_for_deletion()).is_empty(),"original closed transfer gate and finite projectiles drained; no checkpoint/finale/transition"): return false
	if not expect(Witness.SUPPLIES.all(func(id): return ot_witness.pickup_attempts.has(id)),"all nine entry/first-approach/return supplies actually scanned, including clamped uncollected markers"): return false
	var inventory: Array = []
	for spec in route_level.layout.data.pickups:
		inventory.append([spec.id,ot_witness.pickup_attempts.get(spec.id,0),ot_witness.consumed.has(spec.id),route_level.markers.has(spec.id),ot_witness.pickups.filter(func(record): return record[0] == spec.id)])
	print("OSSUARY_EARNED_TRANSPORT frames=",Engine.get_physics_frames()-ot_witness.epoch," shots=",ot_witness.shots.size()," deaths=",ot_witness.deaths," provenance=",ot_witness.finishes," summons=",Witness.value_image(ot_witness.summons)," resources=",ot_witness.ledger," supplies=",inventory," saved_sha=",ot_witness.saved_sha," prior_frozen=",transport_prior_frozen())
	return true

func transport_pin_rejection() -> void:
	if not expect(not transport_pins_match(),"pin rejection requires deliberate parent-owned ONE dependency mismatch"):
		quit(1)
		return
	var fixture: String = "user://ossuary_transport_pin_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	var suffixes: Array = ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]
	if not expect(game == null and root.get_child_count() == 0 and suffixes.all(func(suffix): return not FileAccess.file_exists(fixture+suffix)),"fresh detached wrong-pin namespace"):
		quit(1)
		return
	var observer = TransportMain.new()
	var reference = weakref(observer)
	var result: bool = await walk_through_ossuary_transport(observer,fixture)
	var passed: bool = expect(not result and reference.get_ref() == null and game == null and root.get_child_count() == 0 and suffixes.all(func(suffix): return not FileAccess.file_exists(fixture+suffix)),"mismatched pin frees detached adapter BEFORE scene/profile/input adoption")
	quit(0 if passed else 1)

func transport_controls() -> bool:
	# Explicitly controlled token data only; never injected into the earned path.
	var witness = Witness.new()
	var detached = TransportMain.new()
	var foreign = StaticBody3D.new()
	var other = StaticBody3D.new()
	var passed: bool = expect(not witness.current() and not witness.actor(foreign) and detached.transport_witness == null,"unbound/stale-map/foreign identity rejected before expensive replay")
	var token: Dictionary = {"key":"control","source_id":11,"victim_id":22,"rid":foreign.get_rid(),"tick":3,"map_id":44,"caller":"worker"}
	var used: Dictionary = {}
	passed = expect(not Witness.claim(used,token,12,22,foreign.get_rid(),3,44,"worker") and not Witness.claim(used,token,11,23,foreign.get_rid(),3,44,"worker") and not Witness.claim(used,token,11,22,foreign.get_rid(),4,44,"worker") and not Witness.claim(used,token,11,22,foreign.get_rid(),3,45,"worker") and not Witness.claim(used,token,11,22,foreign.get_rid(),3,44,"forged") and not Witness.claim(used,token,11,22,other.get_rid(),3,44,"worker") and used.is_empty(),"token rejects foreign source/victim/stale tick/map/caller without consuming") and passed
	passed = expect(Witness.claim(used,token,11,22,foreign.get_rid(),3,44,"worker") and not Witness.claim(used,token,11,22,foreign.get_rid(),3,44,"worker"),"contact token consumed once") and passed
	var image: Dictionary = witness.snapshot()
	witness.shots.append([1])
	passed = expect(image.shots.is_empty() and witness.snapshot().shots == [[1]],"witness snapshot is a detached VALUE image") and passed
	other.free()
	foreign.free()
	detached.free()
	return passed

# Main runtime fields stay live; EVERY subclass observer property is value-frozen.
const OT_PRODUCTION_FIELDS = ["state", "playing", "loaded_positions", "placement_pending", "preferences", "settings", "progress_path", "settings_path", "level", "player", "music", "effects", "enemies", "menu", "menu_scroll", "pending_action", "pending_button", "hud", "canvas", "message", "message_time", "damage_flash", "hit_flash", "quitting", "_scene_level_index", "aim_observation", "interaction_observation", "_passive_scan_tick", "_interaction_edges", "_interaction_incoming_eligible", "_interaction_pending_player", "_interaction_axis_held"]

const OT_PINS = {
 "res://data/06_ossuary.json": "781a86ab846db76d7189f108281f009b300812a5c2136faa754b9a74000bc74c",
 "res://scripts/campaign.gd": "34f9c3347acb72534140335106c6e8a74d778e2f2ad30d25da1028b8830bca6f",
 "res://scripts/enemy.gd": "a927bd16ec949430015cd9f3843441361f2ea9490c8e4ab04ad92cf1c3dd6ebe",
 "res://scripts/level.gd": "bfd64a31f8d9df56e5e9dfbd5a4e16ce5df5ec738423a4e75436750318bee053",
 "res://scripts/level_data.gd": "40b6946232de22af2cd60c6f98db3852a6ebac9eb6cd42b8994ef4345a777674",
 "res://scripts/level_schema.gd": "20c67dfe1dcd776fbac7dabfeba1b63187a7d575449ec6edf5e1e6106291d0ce",
 "res://scripts/main.gd": "934c797718eb8b8b55b11248cad87476791db37be13be842e96f64a7efdf0915",
 "res://scripts/player.gd": "ed55b3961296d9bacb80e31286ea25d3d43702a5c7f499e6bbfffaa27571e8a9",
 "res://scripts/preferences.gd": "e225e74aabaafdd3f3e25a31b22264a5ba365e4ba7d0f6e3709f67b10f327139",
 "res://scripts/projectile.gd": "bbda549a1c3d964bea81171dfc44d0395084023e804e3bdb72e22d285f87e873",
 "res://scripts/survey.gd": "0a9a1d70718dcc57d475ddd51b65d90adb24c314a99ebbbcdb199a5c0b55b8e5",
 "res://tests/passive_physics_step.gd": "021399c7412fa45714932b0cc410817e4a3b938c5276b4dd568d1c377e5c0085",
 "res://tests/test_active_boss_fights.gd": "cf19198056b5e2b56fc246ce4ecf9c2eca34681838959edccb90109508bdcfa0",
 "res://tests/test_foundry_earned_walk.gd": "9c22c9e1533e60bdd95cb2875a14c8a7b35449ec856fab7d997b34bc28ebd2d0",
 "res://tests/test_intake_combat.gd": "be3af33d75e3ae1ffec46a3435228d1f991660537093048c55059a5ee7722166",
 "res://tests/test_intake_complete_walk.gd": "876dd3a47336776c18871779faed569ec2295e00099994e1b48654b16e06d50b",
 "res://tests/test_intake_walk.gd": "4716c98dbe10abb4d5a0b1613428760509ec9925082870b475ea0c3c3ea372ea",
 "res://tests/test_intake_west_seal.gd": "e7339710046bdf7c4cc18bc6a86622f87531c7bc4b58bb13db04049f2e024e0a",
 "res://tests/test_nursery_earned_campaign.gd": "b26c6b1be2b82029fd16217950ff1e4e7189930332dfab41645b9496bf033bdf",
 "res://tests/test_nursery_earned_entry.gd": "5d004adb23e6fa957c7a58c3e812c6525a83ea7ffd566fa363f9d4f49942df6e",
 "res://tests/test_nursery_finale_loop.gd": "aed0a4b2a59cad0b626ac8f3fb1acb234618a7b5a576e3f3ceb55169b20c6937",
 "res://tests/test_nursery_seed_loop.gd": "b2efd4ecf6f306c38ac276480b2e2fe8cb96fb967241e0c5b2303d0f86b4e2ab",
 "res://tests/test_processional_earned_entry.gd": "3d690414263b1a79a5c18988e60576603d105f6d6723a86ed55f680835ac6782",
 "res://tests/test_processional_earned_exit.gd": "c512f7e5d526eb792373e9602f5d46e7baa6e33db1ba851c0b243094aee36854",
 "res://tests/test_processional_earned_organ.gd": "713c477ee98f8dde6097cacfaf251a28b33166dffba413c75981c367d311b7c0",
 "res://tests/test_processional_earned_palanquin.gd": "2c5ae831c35ac47512e68845581722e4b3699983502b92acace0853dcae9c831",
 "res://tests/test_reliquary_blood_story.gd": "fb3c7286b7ddcca4944c2ae2ddcf48630fc69300f9227606e60e4a384d19b1fb",
 "res://tests/test_reliquary_catalogue.gd": "44be18e60b63166e1c75fd563e297e3c4a77a4ff2d56d0742c68e382da6a8748",
 "res://tests/test_reliquary_earned_entry.gd": "6ed92c140d451aa20f5c10ed26025e9b2210e88c02e573f17c06121753328c21",
 "res://tests/test_reliquary_earned_exit.gd": "af9859ad52ae635df6e49dc3ace67b9919282d5b443ff9ee706a0a018ae15c51",
 "res://tests/test_reliquary_halo_feasibility.gd": "f82d38ddbf283a3daf6440e31d3381e8160af230e4b78a923d03af1181b6afd7",
 "res://tests/test_reliquary_halo_return.gd": "9dfd1f0483f0adb9877e082ab864d0d638d59ba6dbaab7920daf10277245dad4",
 "res://tests/test_reliquary_wheel_ivory.gd": "8340e199457f9555c1615824d1df7582c2b632a3fc6f8a1885afb8206e3fb83f",
 "res://tests/test_reliquary_wheel_return.gd": "51c21745098e62e6f62cc0878ef552b1db8ada101d8cb136e150006383f2bb1e",
 "res://tests/ossuary_transport_witness.gd": "734692066ee86c1dfeb8b9c0da9cb07f4873ef396227c448fd7cae48c87c78db"
}
