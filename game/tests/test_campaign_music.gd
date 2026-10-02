extends SceneTree

const LEVELS := ["intake", "foundry", "processional", "reliquary", "nursery", "ossuary", "inversion", "heart"]
const CHANNELS := [0, 1, 2, 3, 9]
const PROGRAMS := [30, 34, 19, 81, 0]
var bank: Bank

func _initialize() -> void:
	assert(FileAccess.get_sha256("res://audio/gate.mid") == "6dd153f678b00f3302fe18faf28a93896e33dfd597b024e0e397ee74a1f9dc99")
	var soundfont := SoundFont.new().read_file("res://audio/GeneralUser-GS.sf2")
	assert(soundfont.error == OK and soundfont.data != null)
	bank = Bank.new()
	bank.read_soundfont(soundfont.data, [19, 30, 34, 81, 128 << 7])
	for level in LEVELS:
		if not check_song(level):
			quit(1)
			return
	bank = null
	print("PASS campaign native SMF: eight scores, real note/controller balance, exact sections/tempos/meters, bank coverage/release space")
	quit()

func elapsed_at(tick: int, tempos: Array, ppq: int) -> float:
	var seconds := 0.0
	for i in tempos.size():
		var start: int = tempos[i][0]
		if start >= tick:
			break
		var stop: int = min(tick, tempos[i + 1][0]) if i + 1 < tempos.size() else tick
		seconds += float(stop - start) / ppq * float(tempos[i][1]) / 1000000.0
	return seconds

func check_song(level: String) -> bool:
	var source := ProjectSettings.globalize_path("res://").path_join("../source/music/%s.json" % level)
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	var result := SMF.new().read_file("res://audio/%s.mid" % level)
	assert(result.error == OK and result.data != null, "Real SMF reader must accept every campaign file")
	var data := result.data
	assert(data.format_type == SMF.SMFFormat.format_1 and data.track_count == 6 and data.tracks.size() == 6 and data.timebase == 480)
	var end: int = roundi(float(spec.beats) * data.timebase)
	var tempos: Array = []
	var markers: Array = []
	var meters: Array = []
	var note_count := 0
	var last_off := 0
	var release_deadlines: Array = []
	for i in data.tracks.size():
		var active := {}
		var previous := -1
		var bend := 8192
		var hold := 0
		var program := -1
		var end_count := 0
		var notes := 0
		var controls := {}
		for chunk in data.tracks[i].events:
			assert(previous <= chunk.time and chunk.time <= end)
			previous = chunk.time
			var event := chunk.event
			if event.type != SMF.MIDIEventType.system_event:
				assert(i > 0 and chunk.channel_number == CHANNELS[i - 1], "Fixed voice/channel contract")
			match event.type:
				SMF.MIDIEventType.program_change:
					assert(chunk.time == 0 and event.number == PROGRAMS[i - 1])
					program = event.number
				SMF.MIDIEventType.note_on:
					assert(program == PROGRAMS[i - 1] and chunk.time < end)
					assert(event.note >= 0 and event.note <= 127 and event.velocity > 0 and event.velocity <= 127)
					assert(not active.has(event.note), "No same-key overlap may orphan a voice")
					active[event.note] = [chunk.time, event.velocity]
					notes += 1
				SMF.MIDIEventType.note_off:
					assert(active.has(event.note) and active[event.note][0] < chunk.time, "Every off must close a sounding note")
					var preset_number: int = PROGRAMS[i - 1] | ((128 if chunk.channel_number == 9 else 0) << 7)
					assert(bank.presets.has(preset_number), "Exact preset must exist without fallback")
					var layers: Variant = bank.presets[preset_number].instruments[event.note]
					assert(layers != null)
					var covered := false
					for instrument: Bank.Instrument in layers:
						if active[event.note][1] >= instrument.vel_range_min and active[event.note][1] <= instrument.vel_range_max:
							covered = true
							var deadline := elapsed_at(chunk.time, tempos, data.timebase) + instrument.release_state[-1].time + 0.1
							if chunk.channel_number == 9:
								# Drum offs are ignored: auto-release starts after ADS, or finite PCM ends first.
								var pcm_seconds := 0.0
								for sample_index in instrument.array_stream.size():
									var sample: AudioStreamWAV = instrument.array_stream[sample_index]
									var sample_seconds := sample.get_length() / pow(2.0, instrument.array_base_pitch[sample_index]) if sample.loop_mode == AudioStreamWAV.LOOP_DISABLED else INF
									pcm_seconds = maxf(pcm_seconds, sample_seconds)
								var terminal: Bank.VolumeState = instrument.ads_state[-1]
								var envelope_seconds := terminal.time + (0.0 if terminal.volume_db <= -144.0 else instrument.release_state[-1].time)
								deadline = elapsed_at(active[event.note][0], tempos, data.timebase) + minf(pcm_seconds, envelope_seconds) + 0.1
							release_deadlines.append([deadline, preset_number, event.note])
					assert(covered, "Every authored pitch/velocity must have an actual bank zone")
					active.erase(event.note)
					last_off = max(last_off, chunk.time)
				SMF.MIDIEventType.pitch_bend:
					assert(event.value >= 0 and event.value < 16384)
					bend = event.value
				SMF.MIDIEventType.control_change:
					assert(event.number in [0, 32, 7, 10, 64, 91] and event.value >= 0 and event.value <= 127)
					assert(chunk.time == 0, "Scores must not leave uncontrolled channel state")
					controls[event.number] = event.value
					if event.number in [0, 32, 91]:
						assert(event.value == 0, "No unapproved banks or effect sends")
					if event.number == 64:
						hold = event.value
				SMF.MIDIEventType.system_event:
					match event.args.type:
						SMF.MIDISystemEventType.end_of_track:
							assert(chunk.time == end)
							end_count += 1
						SMF.MIDISystemEventType.set_tempo:
							assert(i == 0)
							tempos.append([chunk.time, event.args.bpm])
						SMF.MIDISystemEventType.marker:
							assert(i == 0)
							markers.append([chunk.time, event.args.text])
						SMF.MIDISystemEventType.beat:
							assert(i == 0)
							meters.append([chunk.time, event.args.numerator, 1 << event.args.denominator])
				_:
					assert(false, "Unexpected event outside the approved score contract")
		assert(active.is_empty() and bend == 8192 and hold == 0 and end_count == 1, "Loop must close every note and neutralize controllers")
		if i > 0:
			assert(notes > 0 and controls.size() == 6, "All five approved voices need notes and initialized controllers")
		note_count += notes
	assert(tempos.size() == spec.tempos.size() and markers.size() == spec.sections.size() and meters.size() == spec.meters.size())
	for i in tempos.size():
		assert(tempos[i] == [roundi(float(spec.tempos[i][0]) * data.timebase), int(spec.tempos[i][1])])
	var section_tick := 0
	for i in markers.size():
		assert(markers[i] == [section_tick, spec.sections[i].name])
		section_tick += roundi(float(spec.sections[i].beats) * data.timebase)
	for i in meters.size():
		assert(meters[i] == [roundi(float(spec.meters[i][0]) * data.timebase), int(spec.meters[i][1]), int(spec.meters[i][2])])
	var duration := elapsed_at(end, tempos, data.timebase)
	var release := duration - elapsed_at(last_off, tempos, data.timebase)
	assert(duration >= 60.0 and duration <= 120.0 and release >= 2.0)
	for deadline in release_deadlines:
		assert(deadline[0] <= duration, "%s preset %s note %s tail ends at %.3fs beyond loop %.3fs" % [level, deadline[1], deadline[2], deadline[0], duration])
	print("PASS native ", level, ": ", snapped(duration, 0.001), "s; notes=", note_count, "; release=", snapped(release, 0.001), "s; EOT=", end)
	return true
