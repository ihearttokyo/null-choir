extends SceneTree
const WallClock = preload("res://tests/wall_clock_wait.gd")
# Native/manual-clock checks are not real held-fire or pixels.
var game
const GROUP = "ammo_visuals"
const ATLAS = preload("res://assets/art/effects/ammo_vfx.png")

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func visuals(active_only: bool = true) -> Array:
	var found: Array = []
	for node in get_nodes_in_group(GROUP):
		if is_instance_valid(node) and node is Sprite3D:
			if not active_only or node.visible: found.append(node)
	return found

func run() -> void:
	game = load("res://scripts/main.gd").new()
	var prefix = "user://ammo_visuals_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	game.progress_path = prefix+"_campaign.json"
	game.settings_path = prefix+"_preferences.json"
	root.add_child(game)
	game.start_campaign(1)
	freeze()
	await physics_frame
	await physics_frame
	await process_frame
	game.set_process(false)
	var player = game.player
	player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	if not expect(game.playing and not game.placement_pending and is_instance_valid(game.player),"Valid settled gameplay fixture"): return
	var before: Dictionary = game.state.to_dict().duplicate(true)
	var point: Vector3 = player.camera.global_position+Vector3.LEFT*2
	game.impact(point)
	var current = visuals()
	if not expect(not current.is_empty(),"Real impact hook must spawn a visible level-owned atlas Sprite3D (intended RED, UNRUN)"): return
	var sprite: Sprite3D = current[0]
	if not expect(game.level.is_ancestor_of(sprite) and sprite.global_position.distance_to(point)<0.001,"Impact stays in world space under the current level"): return
	if not expect(sprite.texture!=null and sprite.texture.get_width()==256 and sprite.texture.get_height()==256 and sprite.hframes==4 and sprite.vframes==4,"Real sprite uses the selected 4x4 native atlas"): return
	if not expect(sprite.frame>=12 and sprite.frame<=15,"Pressure impacts select only ring-family frames"): return
	if not expect(game.state.to_dict()==before,"Presentation impact does not change ammo/health/campaign"): return
	var driver = sprite.get_parent()
	if not expect(is_equal_approx(sprite.pixel_size,0.012),"Impact family retains its authored world scale"): return
	sprite.visible = false
	driver.casing(player)
	if not expect(driver.slots.size()==1 and driver.slots[0].sprite==sprite and is_equal_approx(sprite.pixel_size,0.0012),"Casing resets reused sprite to centimetre scale, not the 0.768m impact sheet (intended RED)"): return
	sprite.visible = false
	game.impact(point)
	if not expect(driver.slots.size()==1 and driver.slots[0].sprite==sprite and is_equal_approx(sprite.pixel_size,0.012),"Recycled casing restores impact-family scale"): return
	driver.set_process(false)
	if not expect(driver.has_method("_process"),"Level-scoped driver uses one existing Godot process callback"): return
	var frame_before: int = sprite.frame
	driver.call("_process",0.08)
	if not expect(sprite.frame>frame_before and sprite.frame<=15,"Simulated delta advances the actual atlas frame path"): return
	game.pause_game()
	game.show_settings()
	var paused_frame: int = sprite.frame
	var paused_point: Vector3 = sprite.global_position
	var paused_age: float = driver.slots[0].age
	driver.set_process(true)
	for tick in range(4): await process_frame
	if not expect(not driver.can_process() and driver.slots[0].age==paused_age,"Native paused scheduling freezes remaining cosmetic lifetime"): return
	driver.call("_process",0.08)
	if not expect(not game.playing and sprite.frame==paused_frame and sprite.global_position==paused_point,"Selected Settings freezes cosmetic time/position"): return
	game.resume_game()
	game.set_process(false)
	driver.set_process(false)
	game.state.owned_weapons.assign([0,1,2,3,4,5])
	var marrow_sprite: Sprite3D
	var marrow_projectile: Node3D
	await physics_frame # Real firing queries belong to the native physics domain.
	for index in range(1,6):
		game.state.weapon = index
		game.state.ammo[index] = 2
		player.cooldown = 0
		var casings_before: int = visuals().filter(func(node): return node.texture==ATLAS and node.frame in range(4,8)).size()
		if index == 4: player.camera.rotation.x = 0.5
		if not expect(player.fire() and game.state.ammo[index]==1,"Each successful real firearm shot spends exactly one round"): return
		if index in [1,2,3]:
			if not expect(visuals().filter(func(node): return node.texture==ATLAS and node.frame in range(4,8)).size()==casings_before+1,"Each real mechanical firearm emits a new authored casing"): return
		if index == 4:
			var projectile = game.level.get_children().filter(func(node): return node.get_script()==player.Projectile)[0]
			projectile.set_physics_process(false)
			var flight = visuals().filter(func(node): return node.texture==ATLAS and node.frame in range(8,12))
			if not expect(flight.size()==1,"Real launcher owns an authored travelling marrow sprite"): return
			marrow_sprite = flight[0]
			marrow_projectile = projectile
			projectile._physics_process(0.01)
			driver.call("_process",0.01)
			driver.call("_process",0.085)
			if not expect(marrow_sprite.frame==9,"Live marrow retains its separate0.09-second frame clock"): return
			if not projectile.is_queued_for_deletion():
				if not expect(flight[0].global_position.is_equal_approx(projectile.global_position),"Actual marrow step moves its cosmetic without owning collision"): return
		for node in visuals(false):
			if not expect(game.level.is_ancestor_of(node),"Every emitted family is current-level owned"): return
		if not expect(visuals(false).size()<=32,"All world cosmetics stay within the shared32-sprite bound"): return
	for index in range(64): game.impact(point)
	if not expect(not marrow_projectile.is_queued_for_deletion() and marrow_sprite.visible and marrow_sprite.frame in range(8,12),"Impact saturation never evicts the only visual of a live damaging projectile"): return
	if not expect(visuals(false).size()<=32,"Burst saturation recycles/drops cosmetics instead of unbounded allocation"): return
	if not expect(driver.get_children().filter(func(node): return node is Sprite3D).size()==visuals(false).size(),"Group count covers all allocated pool sprites, including queued nodes"): return
	var same_state: Dictionary = game.state.to_dict().duplicate(true)
	for index in range(4): driver.call("_process",0.08)
	if not expect(game.state.to_dict()==same_state,"Cosmetic clock reads never advance combat/ammo/campaign"): return
	driver.call("_process",4.1)
	if not expect(marrow_sprite.visible,"Cosmetic/frame time cannot hide a still-live physics projectile"): return
	marrow_projectile.queue_free()
	driver.call("_process",0.01)
	if not expect(not marrow_sprite.visible,"Queued projectile immediately releases its visual slot without waiting for a stale reference"): return
	driver.call("_process",4.1)
	if not expect(visuals().is_empty(),"Expired effects are hidden while bounded reusable slots remain"): return
	var old_level = game.level
	game.impact(point)
	var stale_point: Vector3 = sprite.global_position
	game.restart_level()
	freeze()
	driver.call("_process",0.08)
	if not expect(sprite.global_position==stale_point,"Queued old-level callback cannot move cosmetic state"): return
	await physics_frame
	await physics_frame
	await process_frame
	freeze()
	if not expect(game.playing and not game.placement_pending and is_instance_valid(game.level) and game.level!=old_level and is_instance_valid(game.player),"Restart must settle a valid replacement map/player, not vacuously return to title"): return
	if not expect(not is_instance_valid(old_level) and not is_instance_valid(driver),"Native deletion flush frees old-level pool and driver"): return
	if is_instance_valid(driver): driver.call("_process",0.08)
	for node in visuals(false):
		if not expect(game.level.is_ancestor_of(node),"Restart cannot retain stale-level cosmetic nodes"): return
	print("PASS scoped ammo visual contracts; source-only fixture does not prove pixels/held-fire/performance/full campaign")
	await finish(0)

func freeze() -> void:
	game.set_process(false)
	if is_instance_valid(game.player):
		game.player.set_physics_process(false)
		game.player.set_process_unhandled_input(false)
	for actor in game.enemies: actor.set_physics_process(false)

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		finish(1)
	return condition

func finish(status: int) -> void:
	if is_instance_valid(game): game.show_title()
	if is_instance_valid(game) and game.music != null: game.music.stop()
	if is_instance_valid(game) and game.effects != null: game.effects.stop()
	paused = false
	# Match the established native effects/HUD grace before releasing playback.
	await WallClock.seconds(self,0.1) # Mixer grace is real time, not fixed-FPS simulation time.
	if is_instance_valid(game): game.free()
	game = null
	await process_frame
	await process_frame
	# Let the awaiting run() coroutine release its local Resource references
	# before SceneTree performs the exit/leak check; do not suppress that check.
	call_deferred("quit",status)
