extends SceneTree

const Layout = preload("res://scripts/level_data.gd")
const MAPS = ["nursery","ossuary","inversion","heart"]
var game
var capture: AudioEffectCapture
var music_bus: int = -1
var capture_index: int = -1
var prefix = "user://late_campaign_flow_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	# Clean authored-input RED, before Main, audio setup or direct spec.text access.
	for index in range(4,8):
		var layout = Layout.new()
		if not expect(layout.load_level(index),"SETUP: registered late layout must load: "+str(index)):
			await finish(1)
			return
		for spec in layout.data.interactions:
			if spec.kind == "key" and not expect(spec.get("text") is String and not str(spec.get("text","")).strip_edges().is_empty(),"LATE FLOW RED: "+layout.data.id+" key "+spec.id+" requires nonempty authored recovery text"):
				await finish(1)
				return
	if not expect(AudioServer.get_driver_name() == "CoreAudio","SETUP: live flow requires --audio-driver CoreAudio"):
		await finish(1)
		return
	game = load("res://scripts/main.gd").new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.settings.head_bob = false
	game.settings.camera_shake = false
	music_bus = AudioServer.get_bus_index("Music")
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	capture_index = AudioServer.get_bus_effect_count(music_bus)
	AudioServer.add_bus_effect(music_bus,capture)
	game.state.new_campaign(1)
	game.state.level_index = 4
	game.state.owned_weapons = [0,1,2]
	game.state.ammo = [0,75,6,0,0,0]
	game.state.health = 83
	game.state.armor = 21
	for index in range(4): game.state.discover(index)
	game.start_level()
	freeze()
	for index in range(4,8):
		if not await check_map(index):
			await finish(1)
			return
	print("PASS late native flow: entries/MIDI PCM, E clues/seals/gates, inventory, pre-final checkpoints, firing/death, Continue/restart and three real Descend transitions. Bosses/endings remain pending.")
	await finish(0)

func check_map(index: int) -> bool:
	await settle()
	var layout = game.level.layout
	var data: Dictionary = layout.data
	var entry: Dictionary = game.state._resources().duplicate(true)
	if not expect(game.playing and game.state.level_index == index and data.id == MAPS[index-4] and game.state.checkpoint_id == "entry" and game.state.keys.is_empty(),"Registered late map starts at its own entry, without inherited seals"): return false
	if not expect(game.state.position.is_equal_approx(layout.world_position(data.spawn)) and game.player.position.is_equal_approx(game.state.position+Vector3.UP*0.04) and floor_position(data.spawn) != null,"Entry uses its real native floor and clear player capsule"): return false
	for group in data.encounters:
		if not expect(not "encounter:"+group.id in game.state.removed and group_dormant(group),"Entry does not activate an authored encounter: "+group.id): return false
	if not await check_music(index): return false
	if not expect(game.state._resources() == entry,"Live entry MIDI must not spend resources or force player damage"): return false
	var story: Dictionary = interaction("story")
	if not expect(not story.is_empty(),"Every late map retains its optional clue"): return false
	var discoveries: Array = game.state.discoveries.duplicate()
	if not await interact_at(story): return false
	if not expect(index in game.state.discoveries and game.state.discoveries.size() == discoveries.size()+1 and story.id in game.state.removed and not game.level.markers.has(story.id) and game.message == story.text,"Actual E recovers the optional contradiction and authored text once"): return false
	var discovered: Array = game.state.discoveries.duplicate()
	await tap_key(KEY_E)
	if not expect(game.state.discoveries == discovered and game.state.removed.count(story.id) == 1,"Repeated input cannot duplicate a clue"): return false
	if not await check_late_pickup(index): return false
	var checkpoint: Dictionary = interaction("checkpoint")
	if not expect(not checkpoint.is_empty() and checkpoint.get("text") is String and not str(checkpoint.get("text","")).strip_edges().is_empty(),"Automatic checkpoint requires authored recovery text: "+data.id): return false
	if not expect(not data.doors.is_empty(),"Late seal gate must exist"): return false
	var gate: Dictionary = data.doors[0]
	if not await check_locked(gate,checkpoint,0): return false
	var keys: Array = data.interactions.filter(func(spec): return spec.kind == "key")
	if index%2 == 1: keys.reverse()
	for key_index in range(keys.size()):
		var key: Dictionary = keys[key_index]
		var heroes: Array = data.heroes.filter(func(hero): return hero.get("seal","") == key.key)
		if not expect(not heroes.is_empty(),"Each seal retains its real hero light association"): return false
		var light_ids: Array = heroes[0].light_ids
		var before: Array = light_colors(light_ids)
		if not await interact_at(key): return false
		if not expect(key.key in game.state.keys and key.id in game.state.removed and not game.level.markers.has(key.id) and game.message == key.text,"Actual E earns the seal, removes its marker and displays its recovery message"): return false
		if not expect(before != light_colors(light_ids) and warm_lights(light_ids),"Recovered seal warms the actual associated native machine lights"): return false
		var resources: Dictionary = game.state._resources().duplicate(true)
		resources.erase("position") # A second real physics input can settle the capsule further.
		await tap_key(KEY_E)
		var repeated: Dictionary = game.state._resources()
		repeated.erase("position")
		if not expect(repeated == resources and game.state.removed.count(key.id) == 1,"Repeated key input cannot duplicate a seal or resources"): return false
		if key_index == 0 and not await check_locked(gate,checkpoint,1): return false
	if not expect(game.state.keys.size() == 2,"Both distinct seals are earned through native input"): return false
	var finales: Array = data.encounters.filter(func(group): return "blood" in group.get("requires",[]) and "ivory" in group.get("requires",[]))
	if not expect(finales.size() == 1,"Late layout has one two-seal final commitment"): return false
	var finale: Dictionary = finales[0]
	var final_flag: String = "encounter:"+finale.id
	if not move_to(checkpoint.cell): return false
	if not expect(not in_region(checkpoint.cell,finale.region),"Checkpoint stands before, not inside, the final commitment region"): return false
	game._process(0)
	if not expect(game.state.checkpoint_id == checkpoint.id and checkpoint.id in game.state.removed and not final_flag in game.state.removed and group_dormant(finale) and FileAccess.file_exists(game.progress_path) and game.message == checkpoint.text,"Both seals automatically save recovery before the final encounter"): return false
	var recovery: Dictionary = game.state.checkpoint.duplicate(true)
	if not await interact_at(gate): return false
	if not expect(gate.id in game.state.removed and not game.level.doors.has(gate.id),"Two seals open the actual native gate"): return false
	if not enter_region(finale): return false
	game._process(0)
	if not expect(final_flag in game.state.removed and group_active(finale),"Final threshold activates its actual authored guards"): return false
	await physics_frame # Commit the staged resource spend in native physics.
	var weapon: int = game.state.weapon
	var ammunition: int = game.state.ammo[weapon]
	game.player.camera.rotation.x = 1.1
	if not expect(weapon > 0 and ammunition > 0 and game.player.fire() and game.state.ammo[weapon] == ammunition-1,"Real selected late weapon discharge spends exactly one unit"): return false
	game.hurt_player(game.state.health+game.state.armor+1)
	if not expect(game.state.health == 0 and not game.playing and paused and game.music.player.playback_paused,"Actual lethal damage enters paused recovery without regeneration"): return false
	if not press_button("Restore checkpoint"): return false
	freeze()
	await settle()
	if not expect(game.playing and game.state._resources() == recovery and game.player.position.is_equal_approx(game.state.position+Vector3.UP*0.04) and not final_flag in game.state.removed and group_dormant(finale),"Death restores exact checkpoint resources, position and pre-final activation state"): return false
	if not expect(game.level.doors.has(gate.id) and not game.level.markers.has(checkpoint.id) and not game.level.markers.has(story.id),"Restoration rebuilds the closed post-checkpoint gate without consumed markers"): return false
	for hero in data.heroes:
		if not expect(warm_lights(hero.light_ids),"Checkpoint restoration silently retains earned machine light state"): return false
	var saved: Dictionary = game.state.to_dict().duplicate(true)
	game.pause_game()
	if not press_button("Save and return to title"): return false
	if not expect(not game.playing and game.level == null and not game.music.player.playing and game.music.player.get_now_playing_polyphony() == 0,"Save/title stops the actual map and native score voices"): return false
	if not press_button("Continue"): return false
	freeze()
	await settle()
	if not expect(game.playing and game.level.layout.data.id == data.id and game.state.to_dict() == saved and group_dormant(finale),"Native Continue loads the exact atomic saved recovery and encounter state"): return false
	if not await check_music(index): return false
	game.pause_game()
	if not press_button("Restart level"): return false
	freeze()
	await settle()
	if not expect(game.playing and game.state._resources() == entry and game.state.discoveries == discovered and game.level.markers.has(story.id) and game.level.doors.has(gate.id),"Native Restart restores entry inventory/seals/removals and retains permanent discoveries"): return false
	# Reload the real saved checkpoint, rather than rebuilding carried inventory by hand.
	game.show_title()
	if not press_button("Continue"): return false
	freeze()
	await settle()
	if not expect(game.state.to_dict() == saved,"Restart must not overwrite the prior atomic campaign save"): return false
	if index == 7: return true # Boss, eighth-map exit and alternate-ending acceptance remain parent-owned.
	if not await interact_at(gate): return false
	var exit_spec: Dictionary = interaction("exit")
	if not expect(not exit_spec.is_empty(),"Actual descent interaction must exist"): return false
	for id in exit_spec.get("requires_defeated",[]):
		var manifestations: Array = game.enemies.filter(func(actor): return actor.id == id and actor.hp > 0)
		if not expect(manifestations.size() == 1,"Authored descent retains its real living manifestation"): return false
		if not await interact_at(exit_spec): return false
		if not expect(game.playing and game.state.level_index == index and not id in game.state.removed,"Actual exit E cannot bypass the living manifestation after two seals"): return false
		manifestations[0].take_damage(100000,game.player) # Gate persistence only; finite-ammo boss fights are separate.
		if not expect(manifestations[0].hp == 0 and game.state.removed.count(id) == 1,"Actual manifestation death releases the descent requirement once"): return false
	var carried: Dictionary = game.state._resources().duplicate(true)
	var old_level = game.level
	if not await interact_at(exit_spec): return false
	if not expect(game.state.level_index == index+1 and not game.playing and game.level == null and game.state.position == Vector3.ZERO and game.state.keys.is_empty() and game.state.removed.is_empty(),"Actual exit E advances once and cannot write the retired player's position into next entry"): return false
	var next_layout = Layout.new()
	if not expect(next_layout.load_level(index+1),"Next registered native layout must load"): return false
	if not press_button("Descend to "+next_layout.data.title.capitalize()): return false
	freeze()
	await settle()
	if not expect(not is_instance_valid(old_level) and game.playing and game.level.layout.data.id == next_layout.data.id and game.state.position.is_equal_approx(game.level.layout.world_position(next_layout.data.spawn)),"Native Descend frees the old map and enters the next map's own floor checkpoint"): return false
	for field in ["health","armor","ammo","owned_weapons","weapon"]:
		if not expect(game.state._resources()[field] == carried[field],"Descend carries actual campaign resource: "+field): return false
	return expect(game.state.discoveries == discovered and game.music.player.file == game.music.level_tracks[index+1] and game.music.player.playing,"Descend retains discoveries and starts the next actual MIDI file")

func check_late_pickup(index: int) -> bool:
	var weapon: int = mini(5,index-1)
	var kind = "ammo" if index == 7 else "weapon"
	var specs: Array = game.level.layout.data.pickups.filter(func(spec): return spec.kind == kind and int(spec.get("weapon",-1)) == weapon)
	if not expect(not specs.is_empty(),"Late map supplies its introduced or carried weapon"): return false
	var spec: Dictionary = specs[0]
	var amount: int = game.state.ammo[weapon]
	var acquired: bool = not weapon in game.state.owned_weapons
	if not expect((kind == "weapon" and acquired) or (kind == "ammo" and not acquired),"Late progression introduces each weapon once, then supplies the carried disruptor"): return false
	if not move_to(spec.cell): return false
	game._process(0)
	var capacity: int = game.player.WEAPONS[weapon].max_ammo
	if not expect(weapon in game.state.owned_weapons and game.state.ammo[weapon] == mini(capacity,amount+int(spec.amount)) and spec.id in game.state.removed and not game.level.markers.has(spec.id),"Actual proximity pickup grants finite authored ammo and removes its marker"): return false
	if acquired and not expect(game.state.weapon == weapon,"New late weapon selects itself through actual pickup behavior"): return false
	await tap_key(KEY_1+weapon)
	if not expect(game.state.weapon == weapon,"Actual numeric weapon input selects the owned late weapon"): return false
	var after: Array = game.state.ammo.duplicate()
	game._process(0)
	return expect(game.state.ammo == after and game.state.removed.count(spec.id) == 1,"Repeated pickup processing cannot duplicate finite ammunition")

func check_locked(gate: Dictionary, checkpoint: Dictionary, seals: int) -> bool:
	if not await interact_at(gate): return false
	if not expect(game.state.keys.size() == seals and not gate.id in game.state.removed and game.level.doors.has(gate.id) and game.level.doors[gate.id].collision_layer == 1 and game.message == "BLOOD AND IVORY SEALS REQUIRED","Native gate stays solid with "+str(seals)+" seals"): return false
	if not move_to(checkpoint.cell): return false
	game._process(0)
	return expect(game.state.checkpoint_id == "entry" and not checkpoint.id in game.state.removed,"Automatic checkpoint cannot commit with "+str(seals)+" seals")

func interaction(kind: String) -> Dictionary:
	for spec in game.level.layout.data.interactions:
		if spec.kind == kind: return spec
	return {}

func freeze() -> void:
	game.set_process(false)
	game.hud.survey.set_physics_process(false)
	game.player.set_physics_process(false)
	# Only real authored guards stop ticking; no HP, active state or collider changes.
	var ids: Array = game.level.layout.data.enemies.map(func(spec): return spec.id)
	for actor in game.enemies:
		if actor.id in ids: actor.set_physics_process(false)

func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func floor_position(cell: Array):
	var layout = game.level.layout
	if not layout.is_walkable(Vector2i(floori(cell[0]),floori(cell[1]))): return null
	var floor_point: Vector3 = layout.world_position(cell)
	var space = game.level.get_world_3d().direct_space_state
	var ray = PhysicsRayQueryParameters3D.create(floor_point+Vector3.UP*2,floor_point-Vector3.UP*0.5,1)
	var hit = space.intersect_ray(ray)
	if hit.is_empty() or absf(hit.position.y-floor_point.y) > 0.08 or hit.normal.y < 0.7: return null
	var position: Vector3 = floor_point+Vector3.UP*0.04
	var collider: CollisionShape3D = game.player.get_children().filter(func(node): return node is CollisionShape3D)[0]
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(Basis.IDENTITY,position+collider.position)
	query.collision_mask = game.player.collision_mask
	query.exclude = [game.player.get_rid()]
	if not space.intersect_shape(query,1).is_empty(): return null
	return position

func move_to(cell: Array) -> bool:
	var position = floor_position(cell)
	if not expect(position != null,"SETUP: real floor and solid/actor capsule clearance at "+str(cell)): return false
	game.player.position = position
	game.player.velocity = Vector3.ZERO
	return true

func interact_at(spec: Dictionary) -> bool:
	var layout = game.level.layout
	var location: Vector3 = layout.world_position(spec.cell)
	var directions = [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT,Vector2(1,1).normalized(),Vector2(-1,1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]
	if spec.has("size"):
		var checkpoint = interaction("checkpoint")
		var near_side: Vector2 = Vector2(checkpoint.cell[0]-spec.cell[0],checkpoint.cell[1]-spec.cell[1]).normalized()
		directions.push_front(near_side)
	for radius in [1.5,2.25,3.0,3.75]:
		for direction in directions:
			var cell: Array = [spec.cell[0]+direction.x*radius/float(layout.data.cell_size),spec.cell[1]+direction.y*radius/float(layout.data.cell_size)]
			var position = floor_position(cell)
			if position == null: continue
			game.player.position = position
			game.player.velocity = Vector3.ZERO
			var aim: Vector3 = location+Vector3.UP*(spec.size[1]/2.0 if spec.has("size") else 0.7)
			game.player.look_at(Vector3(aim.x,position.y,aim.z),Vector3.UP)
			game.player.camera.look_at(aim,Vector3.UP)
			if game.nearest_interaction().get("id","") != spec.id: continue
			game._process(0)
			await tap_key(KEY_E)
			return true
	return expect(false,"Native E requires a clear native floor pose and real nearest interaction: "+spec.id)

func tap_key(code: int) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game.player.set_physics_process(true)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await physics_frame
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if is_instance_valid(game.player): game.player.set_physics_process(false)
	await process_frame

func press_button(label: String) -> bool:
	for node in game.menu.get_children():
		if node is Button and not node.is_queued_for_deletion() and node.text == label:
			node.pressed.emit()
			return true
	return expect(false,"Actual native menu action must exist: "+label)

func in_region(cell: Array, region: Array) -> bool:
	return cell[0] >= region[0] and cell[1] >= region[1] and cell[0] <= region[2] and cell[1] <= region[3]

func enter_region(group: Dictionary) -> bool:
	for cell in game.level.layout.tiles:
		var center: Array = [cell.x+0.5,cell.y+0.5]
		if in_region(center,group.region) and floor_position(center) != null: return move_to(center)
	return expect(false,"Final commitment needs a real unblocked native floor pose: "+group.id)

func group_dormant(group: Dictionary) -> bool:
	var found: bool = false
	for actor in game.enemies:
		if actor.id in group.enemy_ids:
			found = true
			if actor.active: return false
	return found

func group_active(group: Dictionary) -> bool:
	var found: bool = false
	for actor in game.enemies:
		if actor.id in group.enemy_ids and actor.hp > 0:
			found = true
			if not actor.active: return false
	return found

func light_colors(ids: Array) -> Array:
	var colors: Array = []
	for id in ids:
		if game.level.machine_lights.has(id): colors.append(game.level.machine_lights[id].light_color)
	return colors

func warm_lights(ids: Array) -> bool:
	var colors = light_colors(ids)
	return not ids.is_empty() and colors.size() == ids.size() and colors.all(func(color): return color.is_equal_approx(Color(1.0,0.76,0.44)))

func check_music(index: int) -> bool:
	if not expect(game.music.player.bank != null and game.music.player.playing and not game.music.player.playback_paused and game.music.player.file == game.music.level_tracks[index],"Map entry/Continue runs its actual packaged live MIDI score"): return false
	capture.clear_buffer()
	var discarded: int = capture.get_discarded_frames()
	var start: float = game.music.player.position
	var frames: int = 0
	var energy: float = 0.0
	for _interval in range(40):
		await create_timer(0.05).timeout
		var pcm = capture.get_buffer(capture.get_frames_available())
		frames += pcm.size()
		for sample in pcm: energy += sample.length_squared()
		if frames >= 256 and energy > 0.000001: break
	print("MEASURE late MIDI map=",MAPS[index-4]," frames=",frames," energy=",energy)
	return expect(frames >= 256 and energy > 0.000001 and game.music.player.position > start and capture.get_discarded_frames() == discarded,"CoreAudio muted output contains real score PCM and an advancing MIDI clock, without dropped frames during this capture window")

func expect(condition: bool, detail: String) -> bool:
	if not condition: push_error(detail)
	return condition

func finish(status: int) -> void:
	for action in ["interact","fire","weapon_4","weapon_5","weapon_6"]:
		if InputMap.has_action(action): Input.action_release(action)
	if is_instance_valid(game): game.show_title()
	paused = false
	await create_timer(0.1).timeout # Established stopped-mix release before native scene teardown.
	if capture_index >= 0: AudioServer.remove_bus_effect(music_bus,capture_index)
	if is_instance_valid(game): game.free()
	await process_frame
	await process_frame
	for suffix in ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]:
		var path = prefix+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit(status)
