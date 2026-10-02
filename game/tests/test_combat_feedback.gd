extends SceneTree

var game
var stale
var prefix = "user://combat_feedback_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	game = load("res://scripts/main.gd").new()
	game.progress_path = prefix+"_campaign.json"
	game.settings_path = prefix+"_preferences.json"
	root.add_child(game)
	game.start_campaign(1)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.music.set_process(false)
	game.music.player.set_process(false)
	for actor in game.enemies:
		actor.set_physics_process(false)
		actor.active = false
		actor.alerted = false
	var actor = game.enemies[0]
	actor.active = true
	actor.alerted = true
	actor.target = game.player
	actor.position = game.player.position+Vector3(4,0,0)
	game._process(0)
	if not expect(is_equal_approx(game.music.pressure_target,0.25),"A nearby active pursuing threat must raise the actual game's MIDI pressure (intended RED)"): return
	var bus = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(bus,-12)
	AudioServer.set_bus_mute(bus,true)
	for number in range(4):
		var threat = game.enemies[number]
		threat.active = true
		threat.alerted = true
		threat.target = game.player
		threat.position = game.player.position+Vector3(4+number,0,0)
	game._process(0)
	if not expect(game.music.pressure_target == 1.0,"Four actual pursuing actors saturate pressure without touching the user bus"): return
	game.music._process(0.25)
	if not expect(game.music.pressure == 1.0 and AudioServer.is_bus_mute(bus) and AudioServer.get_bus_volume_db(bus) == -12,"Native expression smoothing preserves user Music volume and mute"): return
	game.enemies[1].hp = 0
	game.enemies[2].position.x += 100
	game.enemies[3].target = actor
	game._process(0)
	if not expect(is_equal_approx(game.music.pressure_target,0.25),"Dead, distant and infighting actors cannot inflate player-threat pressure"): return
	actor.active = false
	stale = game.Enemy.new()
	root.add_child(stale)
	stale.configure(game,{"id":"stale_pressure","kind":"worker","cell":game.level.layout.data.spawn,"yaw":0})
	stale.set_physics_process(false)
	stale.alerted = true
	stale.target = game.player
	stale.position = game.player.position+Vector3(2,0,0)
	game.enemies.append(stale)
	game._process(0)
	if not expect(game.music.pressure_target == 0,"Dormant and wrong-map actors cannot raise pressure"): return
	stale.alerted = false
	game.shot(1)
	if not expect(not stale.alerted,"Firing cannot alert a wrong-map actor"): return
	stale.position = game.player.position+Vector3(0,0,-2)
	var origin = game.player.camera.global_position
	var aim = (stale.global_position+Vector3.UP*0.85-origin).normalized()
	if not expect(game.autoaim_target(origin,aim,35) != stale,"Aim assistance cannot select a wrong-map actor"): return
	game.damage_flash = 0
	game.hurt_player(0)
	game._process(0)
	if not expect(game.damage_flash == 0 and game.music.pressure_target == 0,"Zero damage cannot fabricate damage pressure or feedback"): return
	game.hurt_player(10)
	game._process(0)
	if not expect(is_equal_approx(game.music.pressure_target,0.75),"Real damage produces a bounded transient pressure signal"): return
	game.pause_game()
	var pressure = game.music.pressure
	var target = game.music.pressure_target
	game._process(1)
	game.music._process(1)
	if not expect(game.music.pressure == pressure and game.music.pressure_target == target,"Pause freezes pressure and its scene-derived target"): return
	game.resume_game()
	game._process(0)
	if not expect(game.music.pressure_target == 0,"Expired damage settles toward quiet after resume"): return
	AudioServer.set_bus_mute(bus,false)
	actor.hp = 90
	actor.active = true
	actor.target = game.player
	for kind in ["crawler","worker","caster"]:
		actor.kind = kind
		game.effects.stop()
		actor._begin_attack(game.player.global_position+Vector3.UP)
		if not expect(game.effects.players[kind+"_charge"].playing,"Real "+kind+" windup callback selects its distinct native tell"): return
		game.effects.stop()
		actor.take_damage(1,game.player)
		if not expect(game.effects.players.stagger.playing,"Eligible real windup counter routes native stagger feedback"): return
		actor._counter_time = 0
	game.effects.stop()
	actor.take_damage(1000,game.player)
	if not expect(game.effects.players.death.playing,"One real death routes native feedback"): return
	game.effects.stop()
	actor.take_damage(1,game.player)
	if not expect(not game.effects.players.death.playing,"Corpse hits cannot replay death"): return
	game.enemy_event(stale,"windup")
	if not expect(game.effects.players.values().all(func(voice): return not voice.playing),"Wrong-map callback cannot leak effect voices"): return
	game.level.queue_free()
	game.enemy_event(actor,"death")
	if not expect(game.effects.players.values().all(func(voice): return not voice.playing),"Queued-map callback cannot leak effect voices"): return
	game.show_title()
	if not expect(game.music.pressure_target == 0 and game.music.player.get_now_playing_polyphony() == 0,"Title clears threat target and transport"): return
	stale.free()
	stale = null
	game.free()
	game = null
	paused = false
	await create_timer(0.2).timeout
	print("PASS actual game threat/damage MIDI pressure, native tell/counter/death feedback, pause, bus and scene lifetime")
	quit()

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error("Combat feedback contract: "+detail)
		if is_instance_valid(stale): stale.free()
		if is_instance_valid(game):
			game.show_title()
			game.free()
		paused = false
		quit(1)
	return condition
