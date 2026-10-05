extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not expect(ResourceLoader.exists("res://audio/effects.gd"),"Gameplay effects must have an offline native playback path"): return
	AudioServer.set_bus_mute(0,true)
	var effects = load("res://audio/effects.gd").new()
	root.add_child(effects)
	await process_frame
	var bus = AudioServer.get_bus_index("Effects")
	AudioServer.set_bus_volume_db(bus,-12)
	AudioServer.set_bus_mute(bus,true)
	if not expect(not effects.play("rivet") and not effects.players.rivet.playing,"Muted Effects bus must reject new PCM voices without changing user controls"): return
	if not expect(AudioServer.is_bus_mute(bus) and is_equal_approx(AudioServer.get_bus_volume_db(bus),-12),"Muted cue rejection preserves exact user mute and volume"): return
	AudioServer.set_bus_mute(bus,false)
	AudioServer.set_bus_volume_db(bus,linear_to_db(0.0))
	if not expect(not effects.play("rivet") and not effects.players.rivet.playing,"Zero Effects gain must reject inaudible new PCM voices"): return
	if not expect(not AudioServer.is_bus_mute(bus) and db_to_linear(AudioServer.get_bus_volume_db(bus)) == 0.0,"Zero-gain cue rejection preserves user controls"): return
	AudioServer.set_bus_volume_db(bus,-12)
	if not expect(effects.get("players") is Dictionary,"Finite cues need native fixed players with safe immediate stop/restart teardown"): return
	if not expect(effects.players.size() == 12 and effects.streams.size() == 12,"All twelve original cues retain reusable native resources"): return
	for cue in effects.players:
		var player = effects.players[cue]
		if not expect(player.bus == &"Effects" and player.stream == effects.streams[cue] and player.max_polyphony == 2,"Each fixed cue routes bounded PCM through the independent Effects bus"): return
	var stream = effects.players.rivet.stream
	if not expect(effects.play("rivet") and effects.players.rivet.playing,"Rivet events play a real finite native PCM voice"): return
	effects.set_paused(true)
	if not expect(effects.players.rivet.stream_paused and not effects.play("scatter"),"Pause freezes PCM and rejects new event voices"): return
	effects.set_paused(false)
	if not expect(not effects.players.rivet.stream_paused and effects.play("scatter"),"Resume accepts the next real event"): return
	if not expect(not AudioServer.is_bus_mute(bus) and is_equal_approx(AudioServer.get_bus_volume_db(bus),-12),"Event playback never replaces user mute or volume"): return
	if not expect(not effects.play("unknown") and effects.players.rivet.stream == stream,"Unknown cues do not replace transport or resources"): return
	effects.stop()
	for player in effects.players.values():
		if not expect(not player.playing,"Title/scene teardown silences current cue voices"): return
	if not expect(effects.play("tool") and effects.players.rivet.stream == stream,"Next-level playback reuses native resources safely"): return
	AudioServer.set_bus_mute(bus,true)
	effects.stop()
	if not expect(AudioServer.is_bus_mute(bus),"Late user mute is preserved through stop"): return
	# Native audio releases stopped voices on its next mix callback.
	await create_timer(0.1).timeout
	effects.free()
	await process_frame
	print("PASS offline original native effects, real PCM, independent bus, pause/restart and finite teardown")
	quit()

func expect(condition: bool, text: String) -> bool:
	if not condition:
		push_error(text)
		quit(1)
	return condition
