extends "res://tests/test_reliquary_halo_feasibility.gd"

const B_HALO_SHA = "f82d38ddbf283a3daf6440e31d3381e8160af230e4b78a923d03af1181b6afd7"
const B_NATIVE_PINS = {"res://scripts/main.gd":"9cae27c174c1bef643e78d685d39afea289355aaaff83b68ecaeea6ae097f459","res://scripts/player.gd":"ebb1b4dba137a736db5450024723b2ff25ac942b0f100c0856a4ac6c87fc2bb4","res://scripts/campaign.gd":"34f9c3347acb72534140335106c6e8a74d778e2f2ad30d25da1028b8830bca6f","res://scripts/enemy.gd":"bf7e811dbf4c3e359791ed0e38ea7783c310fabaf5ba7c6b74d9ffd2255d5826"}
const B_CARRY = {"health":76,"armor":190,"ammo":[0,148,32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
const B_BLOOD = {"id":"reliquary_blood","kind":"key","key":"blood","cell":[11.5,17.5],"text":"FACE REGISTER BLOOD SEAL RECOVERED"}
const B_STORY = {"id":"reliquary_story","kind":"story","cell":[0.75,16.5],"text":"The mission voice is indexed here as a command channel, not a recording. Your replies open the drawers."}
const B_HEALTH = {"id":"reliquary_halo_recess_health","kind":"health","cell":[2.75,18.5],"amount":25.0}
const B_BLOOD_ROUTE = [[10.5,22.4],[10.5,21.5],[10.5,19.5],[10.5,17.5],[11.25,17.5]]
const B_STORY_ROUTE = [[10.5,18.5],[8.5,18.5],[5.5,18.5],[3.5,18.5],[2.75,18.5],[2.5,17.5],[1.5,17.5],[0.75,16.5]]
# Reuse 240-frame hops (including their 12 settling ticks); two six-tick input windows and six idle ticks.
const B_INPUT_LIMIT = 6
const B_IDLE = 6
const B_LIMIT = 13*240+2*B_INPUT_LIMIT+B_IDLE
const B_SECONDS = float(B_LIMIT)/60.0+2.0
const B_HALO_FIELDS = ["h_ok","h_level","h_player","h_bindings","h_ticks","h_shots","h_last","h_slot","h_last_time","h_shot_start_age","h_shot_start_time","h_rivets","h_health_gain","h_armor_gain","h_health_loss","h_absorbed","h_consumed","h_rejected","h_removed","h_activation","h_activated","h_attacks","h_roles","h_damage_attacks","h_hurts","h_deaths","h_finishes","h_births","h_contacts","h_projectile_used","h_pending","h_release","h_melee_pending","h_enemy_contacts","h_enemy_pending","h_enemy_used"]

class BloodMain:
	extends "res://tests/test_reliquary_halo_feasibility.gd".FourthMain
	var b_enabled: bool = false
	var b_ok: bool = true
	var b_ticks: int = 0
	var b_health_gain: int = 0
	var b_health_calls: int = 0
	var b_blood_calls: int = 0
	var b_story_calls: int = 0
	var b_removed: Array = []
	var b_pending: String = ""
	var b_inputs: Array = []
	func b_resources() -> Dictionary:
		var result: Dictionary = B_CARRY.duplicate(true)
		result.health += b_health_gain
		return result
	func b_current() -> bool:
		return h_current() and not h_enabled and b_enabled
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if b_enabled:
			b_ticks += 1
			b_ok = b_ok and b_current() and absf(delta-1.0/60.0) < 0.000001
	func interact() -> void:
		if not b_enabled:
			super.interact()
			return
		var spec: Dictionary = nearest_interaction()
		var valid: bool = spec in [B_BLOOD,B_STORY] and b_selection(spec) and b_pending.is_empty() and budget() == b_resources()
		b_ok = b_ok and valid
		if valid:
			b_pending = spec.id
			b_inputs.append([spec.id,Engine.get_physics_frames(),player.get_instance_id(),level.get_instance_id()])
		super.interact()
		if valid and spec == B_STORY:
			b_story_calls += 1
			b_removed.append(spec.id)
			b_ok = b_ok and b_story_calls == 1 and state.discoveries == [3] and state.removed == b_removed and state.removed.count(spec.id) == 1 and not level.markers.has(spec.id) and message == spec.text
		b_ok = b_ok and budget() == b_resources()
		b_pending = ""
	func b_selection(spec: Dictionary) -> bool:
		if not b_current() or not Engine.is_in_physics_frame() or not Input.is_action_pressed("interact") or not h_stack("/player.gd","_physics_process") or spec.is_empty(): return false
		var marker = level.markers.get(spec.id)
		if not is_instance_valid(marker) or marker.get_parent() != level or marker.is_queued_for_deletion() or spec.id in state.removed: return false
		# Repeat the actual nearest/range/bearing/static-LOS selection independently.
		var selected: Dictionary = {}
		var distance: float = 4.5
		for candidate in level.layout.data.interactions+level.layout.data.doors:
			if candidate.id in state.removed or candidate.get("kind") == "checkpoint": continue
			var point: Vector3 = level.layout.world_position(candidate.cell)
			var gap: float = player.position.distance_to(point)
			var aim: Vector3 = point+Vector3.UP*(float(candidate.size[1])/2.0 if candidate.has("size") else 0.7)
			if gap >= distance or (-player.camera.global_basis.z).dot((aim-player.camera.global_position).normalized()) < 0.4: continue
			var ray = PhysicsRayQueryParameters3D.create(player.camera.global_position,aim,1)
			var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and hit.collider != level.doors.get(candidate.id): continue
			selected = candidate
			distance = gap
		return selected == spec
	func collect_key(id: String) -> void:
		if b_enabled:
			b_ok = b_ok and id == B_BLOOD.id and b_pending == id and b_selection(B_BLOOD) and h_stack("/main.gd","interact") and state.keys.is_empty() and b_blood_calls == 0 and budget() == b_resources()
		super.collect_key(id)
		if b_enabled:
			b_blood_calls += 1
			b_removed.append(id)
			b_ok = b_ok and b_blood_calls == 1 and state.keys == ["blood"] and state.removed == b_removed and state.removed.count(id) == 1 and not level.markers.has(id) and message == B_BLOOD.text and budget() == b_resources()
	func collect_pickup(id: String) -> void:
		if not b_enabled:
			super.collect_pickup(id)
			return
		var marker = level.markers.get(id)
		b_ok = b_ok and b_current() and id == B_HEALTH.id and b_health_calls == 0 and budget() == B_CARRY and Engine.is_in_physics_frame() and h_stack("/main.gd","update_passive_triggers") and h_stack("/player.gd","_physics_process") and level.layout.data.pickups.filter(func(spec): return spec.id == id) == [B_HEALTH] and is_instance_valid(marker) and marker.get_parent() == level and not marker.is_queued_for_deletion() and not id in state.removed and player.position.distance_to(level.layout.world_position(B_HEALTH.cell)) < 1.4 and _passive_trigger_visible(B_HEALTH)
		super.collect_pickup(id)
		b_health_calls += 1
		b_health_gain += mini(25,100-B_CARRY.health)
		b_removed.append(id)
		b_ok = b_ok and b_health_calls == 1 and b_health_gain == 24 and budget() == b_resources() and state.removed == b_removed and state.removed.count(id) == 1 and not level.markers.has(id)
	func activate_encounter(id: String) -> void:
		if b_enabled: b_ok = b_ok and id == "reliquary_halo_commit" and "encounter:"+id in state.removed
		super.activate_encounter(id)
	func shot(weapon: int) -> void:
		if b_enabled: b_ok = false
		super.shot(weapon)
	func hurt_player(amount: int) -> void:
		if b_enabled: b_ok = false
		super.hurt_player(amount)
	func enemy_event(actor, event: String) -> void:
		if b_enabled: b_ok = false
		super.enemy_event(actor,event)
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		if b_enabled: b_ok = false
		super._debug_projectile_event(projectile,event,data)
	func unlock_door(id: String) -> bool:
		if b_enabled: b_ok = false
		return super.unlock_door(id)
	func _capture_actor_state() -> bool:
		if b_enabled: b_ok = false
		return super._capture_actor_state()
	func _save() -> Error:
		if b_enabled: b_ok = false
		return super._save()

var b_started: bool = false
var b_epoch: int = 0
var b_wall: int = 0
var b_fields: Array = []
var b_frozen: Dictionary = {}
var b_actors: Array = []
var b_markers: Dictionary = {}
var b_time: float = 0.0
var b_actors_image: Variant

func run() -> void:
	if not await walk_through_blood_story(BloodMain.new()):
		await finish(1)
		return
	print("PASS source-native virtual-input earned Reliquary Blood/story only; no full-fourth/campaign, physical controls, visual/audio/performance or standalone acceptance")
	await finish(0)

func walk_through_blood_story(observer: BloodMain, profile_prefix: String = "") -> bool:
	for path in B_NATIVE_PINS:
		if not expect(FileAccess.get_sha256(path) == B_NATIVE_PINS[path],"Pinned native source preserves actual Input/Player/Main/Campaign earning and AI: "+path):
			if is_instance_valid(observer) and observer != game and not observer.is_inside_tree(): observer.free()
			return false
	if not expect(FileAccess.get_sha256("res://tests/test_reliquary_halo_feasibility.gd") == B_HALO_SHA,"Exact reviewed nonquitting Halo helper; reconcile parent adoption before running"):
		if is_instance_valid(observer) and observer != game and not observer.is_inside_tree(): observer.free()
		return false
	if not await walk_through_halo(observer,profile_prefix if not profile_prefix.is_empty() else "user://reliquary_blood_story_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())) or not start_blood_story():
		return false
	if not await blood_story_route(B_BLOOD_ROUTE) or not await blood_story_input(B_BLOOD,"--omit-blood-interact") or not await blood_story_route(B_STORY_ROUTE) or not await blood_story_input(B_STORY,"--omit-story-interact"):
		return false
	release_actions()
	for idle in range(B_IDLE):
		if not await route_tick():
			return false
	await process_frame
	if not blood_story_result():
		return false
	return true

func start_blood_story() -> bool:
	if not expect(game is BloodMain and game.h_enabled and game.h_ok and game.h_shots.size() == 32 and H_IDS.all(func(id): return game.h_deaths.get(id,0) == 1 and game.h_finishes.get(id) == "player") and game.budget() == B_CARRY and game.state.keys.is_empty() and game.state.discoveries.is_empty() and game.state.removed == game.h_removed,"Exact accepted actual Halo boundary:32 pistol shots/8 Player kills,76HP190armor148pistol32shells; no grant"): return false
	if not live_route(): return false
	if not expect(B_LIMIT == (B_BLOOD_ROUTE.size()+B_STORY_ROUTE.size())*HOP_LIMIT+2*B_INPUT_LIMIT+B_IDLE,"Fresh bound derives only from13 fixed240-frame hops, two6-tick input windows and6 idle ticks"): return false
	for spec in [B_BLOOD,B_STORY]:
		if not expect(route_level.layout.data.interactions.filter(func(item): return item.id == spec.id) == [spec],"Original interactions schema and protected text: "+spec.id): return false
	if not expect(route_level.layout.data.pickups.filter(func(item): return item.id == B_HEALTH.id) == [B_HEALTH],"Only authored25-health recess supply"): return false
	for actor in game.enemies:
		b_actors.append({"instance":actor.get_instance_id(),"age":actor.age,"position":actor.position,"yaw":actor.rotation.y,"active":actor.active,"alerted":actor.alerted,"shape_disabled":(actor.get_child(0) as CollisionShape3D).disabled})
	for id in route_level.markers: b_markers[id] = weakref(route_level.markers[id])
	for id in [B_BLOOD.id,B_STORY.id,B_HEALTH.id]:
		if not expect(b_markers.has(id) and is_instance_valid(b_markers[id].get_ref()),"Original allowed marker exists at earned boundary: "+id): return false
	b_fields = h_fields+B_HALO_FIELDS
	b_frozen = observer_witness(b_fields)
	b_actors_image = game.state.actors.duplicate(true) if game.state.actors is Array else game.state.actors
	game.b_removed = game.state.removed.duplicate()
	b_time = route_player.active_play_time
	release_actions()
	# Retire observation only; every native super, AI, input and effect remains live.
	game.h_enabled = false
	b_epoch = Engine.get_physics_frames()
	b_wall = Time.get_ticks_usec()
	game.b_enabled = true
	b_started = true
	return live_route()

func east_elapsed() -> int:
	return Engine.get_physics_frames()-b_epoch if b_started else super.east_elapsed()

func route_tick() -> bool:
	if not b_started: return await super.route_tick()
	if not live_route(): return false
	await physics_frame
	return live_route()

func east_fire() -> bool:
	if not b_started: return super.east_fire()
	Input.action_release("fire")
	return false

func clear_point(cell: Array):
	if not b_started: return super.clear_point(cell)
	# Halo's approach-only floor guard cannot describe the original -2m Blood/story floor.
	if cell[0] < 0.0 or cell[0] >= 13.0 or cell[1] < 14.0 or cell[1] > 22.5: return null
	var layout = route_level.layout
	if not layout.is_walkable(Vector2i(floori(cell[0]),floori(cell[1]))): return null
	var point: Vector3 = layout.world_position(cell)
	var floor_y: float = (float(cell[1])-26.0)*0.5 if cell[0] >= 8.0 and cell[0] <= 11.0 and cell[1] >= 22.0 else -2.0
	if absf(point.y-floor_y) > 0.08: return null
	var space = route_level.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2.0,point-Vector3.UP*0.5,1))
	if hit.is_empty() or absf(hit.position.y-point.y) > 0.08 or hit.normal.y < 0.7: return null
	var collider: CollisionShape3D = route_player.get_child(0)
	var pose: Vector3 = point+Vector3.UP*0.04
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(Basis.IDENTITY,pose+collider.position)
	query.collision_mask = route_player.collision_mask
	query.exclude = [route_player.get_rid()]
	return pose if space.intersect_shape(query,1).is_empty() else null

func blood_story_route(cells: Array) -> bool:
	for cell in cells:
		var began: int = east_elapsed()
		if not await east_route([cell]) or not expect(east_elapsed()-began <= HOP_LIMIT,"Blood/story actual finite hop including settling/process: "+str(cell)): return false
	return true

func blood_story_input(spec: Dictionary, omit: String) -> bool:
	aim_interaction(spec.cell)
	var began: int = east_elapsed()
	if not omit in OS.get_cmdline_user_args(): interaction_input(true)
	if not await route_tick(): return false
	await process_frame
	if not live_route(): return false
	interaction_input(false)
	if not await route_tick(): return false
	release_actions()
	await process_frame
	if not live_route() or not expect(east_elapsed()-began <= B_INPUT_LIMIT,"Actual press/hold/release shares six-tick input window"): return false
	if spec == B_BLOOD:
		return expect(game.b_blood_calls == 1 and game.state.keys == ["blood"] and game.state.removed.count(spec.id) == 1 and b_markers[spec.id].get_ref() == null,"NATIVE RED Blood requires actual Player-to-Main interaction and original key marker consumption once after real prefix")
	return expect(game.b_story_calls == 1 and game.state.discoveries == [3] and game.state.removed.count(spec.id) == 1 and b_markers[spec.id].get_ref() == null,"NATIVE RED Story requires actual Player-to-Main interaction and original discovery/marker consumption once after real prefix")

func live_route() -> bool:
	if not b_started: return super.live_route()
	if not expect(east_elapsed() <= B_LIMIT and Time.get_ticks_usec()-b_wall <= B_SECONDS*1000000,"Fresh Blood/story epoch independent of old h_started and h_epoch"): return false
	if not expect(game.b_ok and game.b_current() and not paused and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.settings_path == game.r_settings_origin and game.level == route_level and game.player == route_player and not game.loaded_positions and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and route_player.position.is_finite() and game.enemies.size() == 31 and game.scene_roster_matches(),"Same original live Main/Campaign/profile/map/Player/31; unexpected shot/hurt/AI event/recovery fails"): return false
	if not expect(observer_witness(b_fields) == b_frozen and observer_witness(h_fields) == h_frozen and observers_retired() and not game.h_enabled and retired.all(func(ref): return ref.get_ref() == null) and x_marker_refs.values().all(func(ref): return ref.get_ref() == null),"All old prefix and selected Halo outcome/history witnesses remain deep-frozen; only Halo observer retired"): return false
	for index in range(R_ACTORS.size()):
		var spec: Array = R_ACTORS[index]
		var actor = game.enemies[index]
		var prior: Dictionary = b_actors[index]
		if not expect(is_instance_valid(actor) and actor.id == spec[0] and actor.get_instance_id() == prior.instance and actor.get_instance_id() == game.h_bindings[actor.id] and actor.get_script() == game.Enemy and actor.kind == spec[1] and actor.max_hp == spec[2] and actor._current_map() and actor.is_physics_processing() and actor.age-prior.age >= float(east_elapsed()-2)/60.0 and actor.position == prior.position and actor.rotation.y == prior.yaw and actor.active == prior.active and actor.alerted == prior.alerted and (actor.get_child(0) as CollisionShape3D).disabled == prior.shape_disabled,"Original31 native identities/age/unchanged poses and activation: "+spec[0]): return false
		if actor.id in H_IDS:
			if not expect(actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1,"Accepted original8 corpse/removal remains exact"): return false
		elif not expect(actor.hp == spec[2] and not actor.active and not actor.alerted and actor.collision_layer == 4 and actor.collision_mask == 7 and not (actor.get_child(0) as CollisionShape3D).disabled,"Other original23 inactive/fullHP/capsule; no Wheel/return/catalogue/exit progress"): return false
	var consumed: Array = []
	if game.b_blood_calls == 1: consumed.append(B_BLOOD.id)
	if game.b_health_calls == 1: consumed.append(B_HEALTH.id)
	if game.b_story_calls == 1: consumed.append(B_STORY.id)
	for id in b_markers:
		if id in consumed:
			if not expect(not route_level.markers.has(id) and game.state.removed.count(id) == 1,"Allowed original marker removed once: "+id): return false
		elif not expect(route_level.markers.has(id) and b_markers[id].get_ref() == route_level.markers[id] and not route_level.markers[id].is_queued_for_deletion() and not id in game.state.removed,"Every other original marker and owner preserved: "+id): return false
	if not expect(route_level.markers.size() == b_markers.size()-consumed.size(),"No extra or replacement marker ownership"): return false
	return expect(game.budget() == game.b_resources() and game.state.keys == (["blood"] if game.b_blood_calls == 1 else []) and game.state.discoveries == ([3] if game.b_story_calls == 1 else []) and game.state.removed == game.b_removed and game.state.checkpoint_id == "entry" and game.state.checkpoint == h_frozen.r_start and game.state.level_start == h_frozen.r_start and game.state.actors == b_actors_image and FileAccess.get_sha256(r_profile) == r_saved_sha and game.b_ticks >= east_elapsed()-2 and absf(route_player.active_play_time-b_time-float(east_elapsed())/60.0) <= 2.0/60.0,"Frozen earned carry plus only observed24-health/key/story deltas; old recovery/actor-image/disk envelopes exact")

func blood_story_result() -> bool:
	print("RELIQUARY_BLOOD_STORY_LIMIT frames=",east_elapsed()," wall_us=",Time.get_ticks_usec()-b_wall," resources=",game.b_resources()," inputs=",game.b_inputs," removed=",game.b_removed," halo_shots=",game.h_shots.size())
	return live_route() and expect(game.b_blood_calls == 1 and game.b_story_calls == 1 and game.b_health_calls == 1 and game.b_health_gain == 24 and game.b_inputs.size() == 2 and game.b_inputs[0][0] == B_BLOOD.id and game.b_inputs[1][0] == B_STORY.id and game.b_removed == game.h_removed+[B_BLOOD.id,B_HEALTH.id,B_STORY.id] and game.budget() == {"health":100,"armor":190,"ammo":[0,148,32,0,0,0],"owned_weapons":[0,1,2],"weapon":1} and [B_BLOOD.id,B_STORY.id,B_HEALTH.id].all(func(id): return b_markers[id].get_ref() == null),"Earned Blood/story and automatic finite25-health supply complete exactly once, final100HP190armor148pistol32shells; no extra progress")
