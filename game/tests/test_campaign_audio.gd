extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not expect(AudioServer.get_driver_name() == "CoreAudio","This live check requires --audio-driver CoreAudio"): return
	var music = load("res://audio/music.gd").new()
	root.add_child(music)
	var bank = music.player.bank
	var capture = AudioEffectCapture.new()
	# Source-backed score preparation measured 1.259s; retain mixer PCM across that I/O window.
	capture.buffer_length = 2.0
	var bus = AudioServer.get_bus_index("Music")
	AudioServer.add_bus_effect(bus,capture)
	AudioServer.set_bus_volume_db(bus,linear_to_db(0.65))
	AudioServer.set_bus_mute(0,true)
	var stats = {"loops":0}
	music.player.looped.connect(func(): stats.loops += 1)
	for index in music.level_tracks.size():
		stats.loops = 0
		capture.clear_buffer()
		var prepare = Time.get_ticks_msec()
		music.play_level(index)
		print("PREPARE_MS score=",index," ms=",Time.get_ticks_msec()-prepare," discarded=",capture.get_discarded_frames())
		if not expect(music.player.bank == bank,"Every score must reuse the loaded bank"): return
		var start = Time.get_ticks_msec()
		var frames = 0
		var sum_square = 0.0
		var peak = 0.0
		var clipped = 0
		var paused_once = false
		var last_loop = 0
		while stats.loops < 1 or Time.get_ticks_msec()-last_loop < 2000:
			await create_timer(0.04).timeout
			var pcm = capture.get_buffer(capture.get_frames_available())
			frames += pcm.size()
			for sample in pcm:
				sum_square += sample.x*sample.x+sample.y*sample.y
				peak = maxf(peak,maxf(absf(sample.x),absf(sample.y)))
				if maxf(absf(sample.x),absf(sample.y)) >= 1.0: clipped += 1
			if stats.loops > 0 and last_loop == 0: last_loop = Time.get_ticks_msec()
			if not paused_once and Time.get_ticks_msec()-start > 2000:
				music.set_paused(true)
				var tick = music.player.position
				await create_timer(0.3).timeout
				if not expect(music.player.position == tick,"Real pause freezes score clock"): return
				music.set_paused(false)
				paused_once = true
			if not expect(Time.get_ticks_msec()-start < 130000,"Score failed its wall-clock repeat deadline"): return
		if not expect(frames > 40000 and sum_square/frames > 0.0000001,"Native score output must be non-silent"): return
		if not expect(float(clipped)/frames < 0.001,"Authored mix clips excessively"): return
		if not expect(capture.get_discarded_frames() == 0,"Capture lost native mixer frames score="+str(index)+" count="+str(capture.get_discarded_frames())): return
		print("PASS CoreAudio score ",index," frames=",frames," rms=",sqrt(sum_square/(frames*2))," peak=",peak," clipped=",clipped," repeats=",stats.loops," wall_ms=",Time.get_ticks_msec()-start)
		music.stop()
		if not expect(music.player.get_now_playing_polyphony() == 0,"Track switch must clear all native voices"): return
	music.free()
	bank = null
	await create_timer(0.2).timeout
	print("PASS live CoreAudio: eight original score repeats, pause/resume, bank reuse and stop/switch without dropped capture frames")
	quit()

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
