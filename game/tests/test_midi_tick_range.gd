extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var player := MidiPlayer.new()
	root.add_child(player)
	player.set_process(false)
	# Each delta fits the four-byte SMF limit; their absolute total exceeds 32 bits.
	var events: Array[SMF.MIDIEventChunk] = []
	for step in range(1, 10):
		events.append(SMF.MIDIEventChunk.new(step * 0x0fffffff, 0, SMF.MIDIEventProgramChange.new(30)))
	events.append(SMF.MIDIEventChunk.new(events[-1].time, 0, SMF.MIDIEventSystemEvent.new({"type": SMF.MIDISystemEventType.end_of_track})))
	var other: Array[SMF.MIDIEventChunk] = [SMF.MIDIEventChunk.new(0, 1, SMF.MIDIEventSystemEvent.new({"type": SMF.MIDISystemEventType.end_of_track}))]
	var data := SMF.SMFData.new(SMF.SMFFormat.format_1, 2, 480, [SMF.MIDITrack.new(0, events), SMF.MIDITrack.new(1, other)])
	var decoded := SMF.new().read_data(SMF.new().write(data, false, false))
	assert(decoded.error == OK and decoded.data.tracks[0].events[-1].time > 0x7fffffff, "Actual native SMF reader must preserve cumulative wide ticks")
	player.smf_data = decoded.data
	print("TICK_RANGE_MERGE_BEGIN")
	assert(player._init_track(), "Wide cumulative score must prepare without hanging")
	var expected: Array[SMF.MIDIEventChunk] = [decoded.data.tracks[1].events[0]]
	expected.append_array(decoded.data.tracks[0].events)
	assert(player.track_status.events == expected, "Wide merge must retain every actual event reference in order")
	assert(player.last_position == 9 * 0x0fffffff, "Last position must preserve the full tick")

	var tick := 0x80000000
	var a: Array[SMF.MIDIEventChunk] = [SMF.MIDIEventChunk.new(0), SMF.MIDIEventChunk.new(tick), SMF.MIDIEventChunk.new(tick)]
	var b: Array[SMF.MIDIEventChunk] = [SMF.MIDIEventChunk.new(tick), SMF.MIDIEventChunk.new(tick)]
	player.smf_data = SMF.SMFData.new(SMF.SMFFormat.format_1, 2, 480, [SMF.MIDITrack.new(0, a), SMF.MIDITrack.new(1, b)])
	assert(player._init_track(), "Same-tick wide events must prepare")
	assert(player.track_status.events == [a[0], a[1], b[0], a[2], b[1]], "Retain the existing per-tick round-robin track order")
	player.free()
	await create_timer(0.2, true).timeout
	print("PASS MIDI_TICK_RANGE: valid cumulative SMF ticks, identity/order and same-tick rounds")
	quit()
