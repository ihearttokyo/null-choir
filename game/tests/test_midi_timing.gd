extends SceneTree

var repeats := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player := MidiPlayer.new()
	root.add_child(player)
	player.set_process(false)
	var events: Array[SMF.MIDIEventChunk] = [
		SMF.MIDIEventChunk.new(0, 0, SMF.MIDIEventProgramChange.new(30)),
		SMF.MIDIEventChunk.new(0, 0, SMF.MIDIEventSystemEvent.new({"type": SMF.MIDISystemEventType.set_tempo, "bpm": 500000})),
		SMF.MIDIEventChunk.new(480, 0, SMF.MIDIEventSystemEvent.new({"type": SMF.MIDISystemEventType.set_tempo, "bpm": 1000000})),
		SMF.MIDIEventChunk.new(700, 0, SMF.MIDIEventControlChange.new(64, 127)),
		SMF.MIDIEventChunk.new(700, 0, SMF.MIDIEventPitchBend.new(16383)),
		SMF.MIDIEventChunk.new(960, 0, SMF.MIDIEventSystemEvent.new({"type": SMF.MIDISystemEventType.end_of_track})),
	]
	player.smf_data = SMF.SMFData.new(SMF.SMFFormat.format_0, 1, 480, [SMF.MIDITrack.new(0, events)])
	player.loop = true
	player.looped.connect(func(): repeats += 1)
	player.play()
	player._process(0.0)
	assert(player.channel_status[0].program == 30, "tick-zero events must execute at exact start")
	player._process(1.5)
	assert(repeats == 1 and is_equal_approx(player.position, 0.0), "tempo-aware loop must end exactly at 1.5 seconds")
	assert(not player.channel_status[0].hold and player.channel_status[0].pitch_bend == 0.0, "repeat must reset controllers")
	player._process(4.75)
	assert(repeats == 4 and is_equal_approx(player.position, 240.0), "multi-loop overshoot must retain exact elapsed time")
	player.stop()
	player.play()
	player._process(0.5)
	assert(is_equal_approx(player.position, 480.0) and player.tempo == 60.0, "tempo boundary is inclusive")
	player.file = "res://audio/gate.mid"
	player.play()
	var before_fixture := repeats
	player._process(7.2)
	assert(repeats == before_fixture + 1 and is_equal_approx(player.position, 0.0), "actual fixture must repeat at exactly 7.2 seconds")
	player._process(7.25)
	assert(repeats == before_fixture + 2 and is_equal_approx(player.position, 60.0), "actual fixture repeat must retain 50 ms overshoot")
	player.stop()
	player.queue_free()
	print("MIDI_TIMING_GREEN: exact start, tempo, duration, multi-loop overshoot, controller reset, actual 7.2s fixture")
	quit()
