extends SceneTree

const WallClock = preload("res://tests/wall_clock_wait.gd")

func _initialize(): call_deferred("run")

func run():
	if is_silence(PackedVector2Array()):
		push_error("INTENDED RED: empty capture must not certify silence")
		quit(1)
		return
	var invalid_samples = PackedVector2Array()
	invalid_samples.resize(256)
	invalid_samples.fill(Vector2(NAN, 0))
	if is_silence(invalid_samples):
		push_error("Non-finite samples must not certify silence")
		quit(1)
		return
	invalid_samples.fill(Vector2(0.01, 0))
	if is_silence(invalid_samples):
		push_error("Audible samples must not certify silence")
		quit(1)
		return
	invalid_samples.fill(Vector2.ZERO)
	if not is_silence(invalid_samples):
		push_error("Valid silent samples must pass the silence oracle")
		quit(1)
		return
	var music = load("res://audio/music.gd").new()
	root.add_child(music)
	music.set_process(false)
	var bus = AudioServer.get_bus_index("Music")
	var capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(bus, capture)
	AudioServer.set_bus_mute(0, true)
	for i in music.level_tracks.size():
		music.play_level(i)
		music.player.seek(music.player.stream.get_length() * 0.5)
		await WallClock.seconds(self, 0.15)
		capture.clear_buffer()
		var discarded = capture.get_discarded_frames()
		await WallClock.seconds(self, 0.25)
		var samples = capture.get_buffer(capture.get_frames_available())
		var energy = 0.0
		for sample in samples:
			if not is_finite(sample.x) or not is_finite(sample.y):
				push_error("Native Suno PCM contains non-finite output")
				quit(1)
				return
			energy += sample.length_squared()
		if samples.size() < 256 or energy < 0.000001 or capture.get_discarded_frames() != discarded:
			push_error("Native Suno PCM must contain actual non-silent score samples without dropped capture frames")
			quit(1)
			return
		print("PCM ", i, " frames=", samples.size(), " energy=", energy)
	music.stop()
	await WallClock.seconds(self, 0.15)
	capture.clear_buffer()
	await WallClock.seconds(self, 0.15)
	var silence = capture.get_buffer(capture.get_frames_available())
	if not is_silence(silence):
		push_error("Stopped campaign playback must leave valid silent Music output")
		quit(1)
		return
	print("POST_STOP_SILENCE frames=", silence.size())
	AudioServer.remove_bus_effect(bus, 0)
	music.free()
	capture = null
	await WallClock.seconds(self, 0.15)
	print("PASS eight Suno recordings produce actual CoreAudio PCM; title stop drains to silence")
	quit()

func is_silence(samples: PackedVector2Array) -> bool:
	if samples.size() < 256: return false
	for sample in samples:
		if not is_finite(sample.x) or not is_finite(sample.y) or sample.length_squared() > 0.0000000001: return false
	return true
