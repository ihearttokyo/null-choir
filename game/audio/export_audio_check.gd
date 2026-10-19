extends RefCounted

const LEVELS = ["intake", "foundry", "processional", "reliquary", "nursery", "ossuary", "inversion", "heart"]
const LEGACY_FILES = ["gate.mid", "GeneralUser-GS.sf2"]

static func retained_sources_present(root: String = "res://audio") -> bool:
	for file in LEGACY_FILES:
		if not FileAccess.file_exists(root.path_join(file)): return false
	for level in LEVELS:
		if not FileAccess.file_exists(root.path_join(level + ".mid")): return false
	return true

static func decoded_pcm(tree: SceneTree, player: AudioStreamPlayer) -> bool:
	if not is_instance_valid(player) or not (player.stream is AudioStreamMP3 or player.stream is AudioStreamOggVorbis) or player.stream_paused or not player.playing:
		return false
	var recording = player.stream
	var duration = recording.get_length()
	var bus = AudioServer.get_bus_index(player.bus)
	if bus < 0 or not is_finite(duration) or duration <= 0:
		return false
	var master_muted = AudioServer.is_bus_mute(0)
	var position = player.get_playback_position()
	var capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	var effect_index = AudioServer.get_bus_effect_count(bus)
	AudioServer.add_bus_effect(bus, capture)
	AudioServer.set_bus_mute(0, true)
	player.seek(duration * 0.5)
	# Mixer progress is wall-clock work, not a SceneTreeTimer's inherited frame delta.
	await _wait(tree, 0.15)
	capture.clear_buffer()
	var discarded = capture.get_discarded_frames()
	await _wait(tree, 0.25)
	var samples = capture.get_buffer(capture.get_frames_available())
	var energy = 0.0
	var finite = true
	for sample in samples:
		finite = finite and is_finite(sample.x) and is_finite(sample.y)
		energy += sample.length_squared()
	var same_stream = is_instance_valid(player) and player.stream == recording and not player.stream_paused
	var valid = same_stream and samples.size() >= 256 and finite and is_finite(energy) and energy > 0.000001 and capture.get_discarded_frames() == discarded
	AudioServer.remove_bus_effect(bus, effect_index)
	if same_stream: player.seek(position)
	AudioServer.set_bus_mute(0, master_muted)
	return valid

static func _wait(tree: SceneTree, seconds: float) -> void:
	var end_us = Time.get_ticks_usec() + ceili(seconds * 1000000.0)
	while Time.get_ticks_usec() < end_us:
		await tree.process_frame
