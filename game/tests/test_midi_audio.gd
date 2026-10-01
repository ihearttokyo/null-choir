extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var music := preload("res://audio/music.gd").new()
	var objects_before := Performance.get_monitor(Performance.OBJECT_COUNT)
	var before := Time.get_ticks_msec()
	root.add_child(music)
	print("BANK_LOAD_MS: ", Time.get_ticks_msec() - before)
	var player: MidiPlayer = music.player
	player.set_process(false)
	for program in [30, 34, 19, 81, 128 << 7]:
		assert(player.bank.presets.has(program), "representative program must exist without fallback")
		print("PRESET: ", program, " ", player.bank.presets[program].name)
	music.play_level(0)
	assert(player.last_position == 7680, "packaged MIDI explicit loop length")
	player._process(0.2)
	assert(player.get_now_playing_polyphony() > 0, "fixture must synthesize real voices")
	var position := player.position
	var timers := []
	for voice in player.audio_stream_players:
		timers.append(voice.timer)
	music.set_paused(true)
	player._process(1.0)
	assert(player.position == position, "pause freezes event clock")
	for i in player.audio_stream_players.size():
		var voice := player.audio_stream_players[i]
		assert(voice.timer == timers[i], "pause freezes ADSR")
		if voice.playing:
			assert(voice.stream_paused, "pause freezes primary PCM")
		if voice.linked.playing:
			assert(voice.linked.stream_paused, "pause freezes linked PCM")
	music.set_paused(false)
	player._process(0.1)
	assert(player.position > position, "resume advances clock")
	var bank := player.bank
	player._process_track_event_control_change(player.channel_status[0], 64, 127)
	player._process_track_event_control_change(player.channel_status[0], 7, 0)
	player._process_pitch_bend(player.channel_status[0], 16383)
	music.level_tracks.append("res://audio/gate.mid")
	music.play_level(1)
	assert(player.bank == bank and player.position == 0.0, "switch preserves one loaded bank and restarts event data")
	assert(not player.channel_status[0].hold and player.channel_status[0].pitch_bend == 0.0, "switch resets controllers")
	assert(player.get_now_playing_polyphony() == 0, "switch drops old release tails")
	var bus := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(bus, -12.0)
	AudioServer.set_bus_mute(bus, true)
	assert(AudioServer.is_bus_mute(bus) and AudioServer.get_bus_volume_db(bus) == -12.0)
	assert(AudioServer.get_bus_send(AudioServer.get_bus_index(MidiPlayer.midi_master_bus_name)) == &"Music", "synth routes to Music bus")
	AudioServer.set_bus_mute(bus, false)
	music.stop()
	assert(player.get_now_playing_polyphony() == 0, "stop silences every voice")
	# One two-sample voice isolates attenuation and release cleanup from the bank.
	var voice: AudioStreamPlayerADSR = player.audio_stream_players[0]
	var instrument := Bank.Instrument.new()
	var pcm := AudioStreamWAV.new()
	pcm.data = PackedByteArray([1, 0, 2, 0, 1, 0, 2, 0])
	pcm.loop_mode = AudioStreamWAV.LOOP_FORWARD
	pcm.loop_begin = 0
	pcm.loop_end = 4
	instrument.array_stream = [pcm, pcm]
	instrument.array_base_pitch = [0.0, 0.0]
	instrument.ads_state = [Bank.VolumeState.new(0.0, 0.0), Bank.VolumeState.new(10.0, 0.0)]
	instrument.release_state = [Bank.VolumeState.new(0.0, 0.0), Bank.VolumeState.new(0.1, -144.0)]
	instrument.volume_db = -18.0
	voice.set_instrument(instrument)
	voice.velocity = 127
	voice.polyphony_count = 1.0
	voice.note_play()
	assert(is_equal_approx(voice.volume_db, -18.0 + linear_to_db(0.5)), "soundbank initial attenuation must affect PCM gain")
	voice.start_release()
	voice._update_adsr(0.05)
	voice._update_adsr(0.2)
	assert(not voice.playing and not voice.linked.playing, "release completion must stop linked PCM too")
	music.stop()
	music.free()
	bank = null
	instrument = null
	await create_timer(0.15).timeout # Let the audio thread release stopped playback resources.
	assert(Performance.get_monitor(Performance.OBJECT_COUNT) < objects_before + 500, "bank teardown must not retain thousands of skipped preset cycles")
	print("MIDI_AUDIO_GREEN: real bank/fixture, pause, restart, bus, attenuation, stereo release")
	quit()
