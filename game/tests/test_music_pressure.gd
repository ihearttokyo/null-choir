extends SceneTree

const CHANNELS := [0, 1, 2, 3, 9]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var music: Node = load("res://audio/music.gd").new()
	if not expect(music.has_method("set_pressure"), "Music must expose set_pressure(value: float)"):
		music.free()
		return
	if not expect(not same_mix([NAN], [0.0]) and not same_mix([0.0], [NAN]) and not same_mix([INF], [1.0]), "Mix comparison must reject non-finite values"): return
	music.set("level_tracks", PackedStringArray(["res://audio/gate.mid", "res://audio/gate.mid"]))
	root.add_child(music)
	music.set_process(false)
	var player: MidiPlayer = music.get("player")
	player.set_process(false)
	if not expect(player.bank != null, "Pressure test requires the packaged bank"): return
	var bank := player.bank
	var voices := player.audio_stream_players.duplicate()
	var bus_count := AudioServer.get_bus_count()
	var bus := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(bus, -12.0)
	AudioServer.set_bus_mute(bus, true)
	music.call("set_pressure", 0.0)
	music.call("play_level", 0)
	var quiet := settle(music, 0.0)
	player._process(0.2)
	if not expect(player.get_now_playing_polyphony() > 0, "Frozen gate must synthesize actual bank voices"): return
	if not expect(bus_matches(player), "Quiet expression must affect the native channel buses"): return
	var data := player.smf_data
	var position := player.position
	var pointer := player.track_status.event_pointer
	var volumes: Array = []
	for channel in CHANNELS:
		volumes.append(player.channel_status[channel].volume)

	music.call("set_pressure", 1.0)
	if not expect(gains(player) == quiet, "Pressure requests must not jump directly to the target mix"): return
	music.call("_process", 0.05)
	var attack := gains(player)
	if not expect(quiet[0] < attack[0] and attack[0] < 1.0, "Pressure attack must be gradual"): return
	music.call("set_paused", true)
	music.call("set_pressure", 0.0)
	music.call("_process", 8.0)
	player._process(1.0)
	if not expect(gains(player) == attack and player.position == position, "Pause must freeze pressure smoothing and score transport"): return
	music.call("set_paused", false)
	music.call("_process", 0.05)
	if not expect(quiet[0] < gains(player)[0] and gains(player)[0] < attack[0], "Resume must continue pressure release without a jump"): return
	var loud := settle(music, 1.0)
	for i in CHANNELS.size():
		if not expect(quiet[i] > 0.0 and quiet[i] <= loud[i] and loud[i] <= 1.0, "Pressure only attenuates; quiet accompaniment remains audible"): return
		if not expect(player.channel_status[CHANNELS[i]].volume == volumes[i], "Pressure must preserve authored MIDI channel volume"): return
	if not expect(quiet[0] < loud[0] and quiet[3] < loud[3] and quiet[4] < loud[4], "Combat pressure must reveal guitar, synth and drums"): return
	if not expect(is_equal_approx(quiet[2], loud[2]), "The organ's authored mix must remain independent of pressure"): return
	if not expect(bus_matches(player), "Full expression must affect the native channel buses"): return
	music.call("set_pressure", 0.0)
	music.call("_process", 0.05)
	var release := gains(player)
	if not expect(quiet[0] < release[0] and release[0] < loud[0], "Pressure release must be gradual"): return
	if not expect(attack[0] - quiet[0] > loud[0] - release[0], "Pressure attack must be faster than release"): return
	if not expect(same_mix(settle(music, 2.0), loud), "Finite pressure above one must clamp to one"): return
	for value in [-2.0, NAN, INF, -INF]:
		if not expect(same_mix(settle(music, value), quiet), "Negative and non-finite pressure must safely settle at zero"): return
	var middle := settle(music, 0.45)
	if not expect(quiet[0] < middle[0] and middle[0] < loud[0], "Intermediate finite pressure must retain an intermediate mix"): return
	if not expect(music.get("player") == player and player.bank == bank and player.smf_data == data, "Pressure must retain one player, bank and score event data"): return
	if not expect(player.audio_stream_players == voices and AudioServer.get_bus_count() == bus_count, "Pressure must not rebuild voices or multiply audio buses"): return
	if not expect(player.position == position and player.track_status.event_pointer == pointer, "Pressure must not seek, restart or advance score transport"): return
	if not expect(AudioServer.get_bus_volume_db(bus) == -12.0 and AudioServer.is_bus_mute(bus), "Pressure must preserve user Music gain and mute"): return

	AudioServer.set_bus_volume_db(bus, -6.0)
	AudioServer.set_bus_mute(bus, false)
	var repeat_mix := settle(music, 0.0)
	var repeats := {"count": 0}
	player.looped.connect(func(): repeats.count += 1)
	player._process(7.0)
	if not expect(repeats.count == 1 and is_equal_approx(player.position, 0.0), "Frozen gate must repeat at exactly 7.2 seconds"): return
	if not expect(same_mix(gains(player), repeat_mix) and bus_matches(player), "Repeat controller reset must reapply the current pressure mix"): return
	middle = settle(music, 0.45)
	music.call("play_level", 1)
	if not expect(player.bank == bank and player.position == 0.0 and same_mix(gains(player), middle), "Level switch must reuse the bank and reapply current pressure"): return
	if not expect(AudioServer.get_bus_volume_db(bus) == -6.0 and not AudioServer.is_bus_mute(bus), "Repeat and switch must preserve updated user Music settings"): return
	music.call("stop")
	settle(music, 1.0)
	if not expect(not player.playing and player.get_now_playing_polyphony() == 0, "Pressure while stopped must not start music or leave voices"): return
	var batches: Array[int] = []
	for batch in 7:
		var start = Time.get_ticks_usec()
		for step in 1000:
			music.pressure = float(step%101)/100.0
			music._apply_pressure()
		batches.append(Time.get_ticks_usec()-start)
	print("PRESSURE_1000_UPDATES_US: ",JSON.stringify(batches))
	music.free()
	bank = null
	voices.clear()
	var drain_start = Time.get_ticks_usec()
	while Time.get_ticks_usec()-drain_start < 150000:
		await process_frame
	print("PASS MUSIC_PRESSURE_GREEN: finite clamp, asymmetric smoothing, pause, one transport/bank/voice pool, native gain, repeat/switch and independent user settings")
	quit()

func gains(player: MidiPlayer) -> Array[float]:
	var result: Array[float] = []
	for channel in CHANNELS:
		result.append(player.channel_status[channel].expression)
	return result

func settle(music: Node, pressure: float) -> Array[float]:
	music.call("set_pressure", pressure)
	music.call("_process", 8.0)
	return gains(music.get("player"))

func same_mix(a: Array[float], b: Array[float]) -> bool:
	for i in a.size():
		if not is_finite(a[i]) or not is_finite(b[i]) or absf(a[i] - b[i]) > 0.001: return false
	return true

func bus_matches(player: MidiPlayer) -> bool:
	for number in CHANNELS:
		var channel := player.channel_status[number]
		var bus := AudioServer.get_bus_index(MidiPlayer.midi_channel_bus_name % number)
		var observed := AudioServer.get_bus_volume_db(bus)
		var expected := linear_to_db(channel.volume * channel.expression)
		if not is_finite(observed) or not is_finite(expected) or absf(observed - expected) > 0.01: return false
	return true

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
