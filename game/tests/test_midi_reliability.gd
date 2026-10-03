extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for stereo in [false,true]:
		var sf = SoundFont.SoundFontData.new()
		sf.sdta = SoundFont.SoundFontSampleData.new()
		sf.sdta.smpl = PackedByteArray([9,8,1,2,3,4,5,6,7,8,9,10])
		sf.pdta = SoundFont.SoundFontPresetData.new()
		var sample = SoundFont.SoundFontSampleHeader.new()
		sample.start = 1
		sample.end = 4
		sample.sample_rate = 44100
		sample.sample_type = SoundFont.sample_link_left_sample if stereo else SoundFont.sample_link_mono_sample
		sample.sample_link = 1
		var right = SoundFont.SoundFontSampleHeader.new()
		right.start = 4
		right.end = 6
		right.sample_rate = 44100
		right.sample_type = SoundFont.sample_link_right_sample
		sf.pdta.shdr.assign([sample,right])
		var ibag = Bank.TempSoundFontInstrumentBag.new()
		ibag.sample = sample
		ibag.key_range = Bank.TempSoundFontRange.new(60,60)
		var pbag = Bank.TempSoundFontBag.new()
		pbag.instrument = Bank.TempSoundFontInstrument.new()
		pbag.instrument.bags.append(ibag)
		var preset = Bank.Preset.new()
		preset.bags.append(pbag)
		var bank = Bank.new()
		bank.head_silent.resize(Bank.head_silent_samples*2)
		bank._read_soundfont_preset_compose_sample(sf,preset)
		var streams = preset.instruments[60][0].array_stream
		if not expect(streams.size() == (2 if stereo else 1),"Native mono/stereo stream count"): return
		for i in streams.size():
			var expected = PackedByteArray([1,2,3,4,5,6]) if i == 0 else PackedByteArray([7,8,9,10])
			var actual = streams[i].data.slice(Bank.head_silent_samples*2)
			if not expect(actual == expected and actual.size()%2 == 0,"Every selected 16-bit sample keeps its final byte (stereo="+str(stereo)+")"): return
		preset.instruments.clear()
		preset.bags.clear()
	var parsed = SoundFont.new().read_file("res://audio/GeneralUser-GS.sf2")
	if not expect(parsed.error == OK and parsed.data != null,"Pinned campaign bank parses"): return
	var requested = [0,19,30,34,81,128<<7]
	var selected = Bank.new()
	var start = Time.get_ticks_usec()
	selected.read_soundfont(parsed.data,requested)
	var elapsed = Time.get_ticks_usec()-start
	var streams: Array = []
	var bytes = 0
	for preset in selected.presets.values():
		if not expect(preset.bags.is_empty(),"Composed bank must release temporary zone metadata"): return
		for instruments in preset.instruments:
			if instruments == null: continue
			for instrument in instruments:
				for stream in instrument.array_stream:
					if stream in streams: continue
					streams.append(stream)
					bytes += stream.data.size()
	print("BANK_METRIC presets=",selected.presets.size()," streams=",streams.size()," sample_bytes=",bytes," compose_us=",elapsed)
	if not expect(selected.presets.size() == requested.size(),"Encoded program selection must not load unused bank variants"): return
	for program in requested:
		if not expect(selected.presets.has(program),"Every authored program remains available"): return
	if not expect(selected.head_silent.size() == Bank.head_silent_samples*2,"Native packed silence retains exact sample length"): return
	for byte in selected.head_silent:
		if not expect(byte == 0,"Every leading silent PCM byte is zero"): return
	if not expect(selected.get_preset(81).instruments[72].size() == 2,"Pinned overlapping Saw Lead zones survive exact selection"): return
	AudioServer.set_bus_mute(0,true)
	var player = MidiPlayer.new()
	player.max_polyphony = 3
	root.add_child(player)
	player.set_process(false)
	for i in 3:
		var voice = player.audio_stream_players[i]
		voice.set_instrument(selected.get_preset(19).instruments[60][0])
		voice.velocity = 100
		voice.note_play()
		voice.using_timer = 100.0-i
		voice.releasing = i > 0
		voice.volume_db = -10.0-i*10.0
		if not expect(voice.playing,"Voice-stealing fixture fills actual native playback pool"): return
	if not expect(player._get_idle_player() == player.audio_stream_players[2],"Saturated native pool steals quietest releasing voice before sustained notes"): return
	player.audio_stream_players[0].note_stop()
	if not expect(player._get_idle_player() == player.audio_stream_players[0],"Idle native voice still takes priority over stealing"): return
	player.stop()
	player.free()
	selected = null
	var valid = FileAccess.get_file_as_bytes("res://audio/gate.mid")
	var wrong_id = valid.duplicate()
	wrong_id[0] = 88
	var wrong_length = valid.slice(0,14)+PackedByteArray([0,0])+valid.slice(14)
	wrong_length[7] = 8
	for encoded in [wrong_id,wrong_length]:
		var result = SMF.new().read_data(encoded)
		if not expect(result.error != OK and result.data == null,"Native SMF rejects either malformed header field"): return
	var missing = "user://missing_audio_"+str(Time.get_ticks_usec())
	for reader in [SoundFont.new(),SMF.new()]:
		var result = reader.read_file(missing)
		if not expect(result.error != OK and result.data == null,"Missing audio file returns a parse result without null-object errors"): return
	var empty = Bank.new()
	if not expect(empty.get_preset(0) == null,"Empty native bank returns no preset without indexing missing keys"): return
	var silent = MidiPlayer.new()
	root.add_child(silent)
	silent.set_process(false)
	silent.bank = empty
	silent._process_track_event_note_on(silent.channel_status[0],60,100)
	if not expect(silent.get_now_playing_polyphony() == 0,"Empty bank note remains silent"): return
	var empty_events: Array[SMF.MIDIEventChunk] = []
	for tracks in [[],[SMF.MIDITrack.new(0,empty_events)]]:
		silent.smf_data = SMF.SMFData.new()
		silent.smf_data.tracks.assign(tracks)
		silent.play()
		if not expect(not silent.playing and silent.get_now_playing_polyphony() == 0,"Empty merged MIDI tracks fail preparation with all notes stopped"): return
	var empty_smf = "MThd".to_ascii_buffer()+PackedByteArray([0,0,0,6,0,0,0,0,1,224])
	if not expect(not silent.load_from_bytes(empty_smf) and not silent.playing,"Byte-loading API rejects empty tracks at the same native preparation boundary"): return
	for timebase in [0,32768]:
		var encoded = valid.duplicate()
		encoded[12] = timebase>>8
		encoded[13] = timebase&255
		if not expect(SMF.new().read_data(encoded).error != OK,"SMF rejects zero or unsupported SMPTE timebase"): return
		silent.smf_data = SMF.new().read_data(valid).data
		silent.smf_data.timebase = timebase
		silent.play()
		if not expect(not silent.playing,"Constructed MIDI data cannot bypass timebase validation"): return
	var clock = [silent.tempo,silent.seconds_to_timebase,silent.timebase_to_seconds]
	for tempo in [0.0,-1.0,NAN,INF,-INF]:
		silent.set_tempo(tempo)
		if not expect([silent.tempo,silent.seconds_to_timebase,silent.timebase_to_seconds] == clock,"Invalid tempo cannot corrupt native scheduler rate"): return
	var zero_tempo = valid.duplicate()
	var found = false
	for i in range(zero_tempo.size()-5):
		if zero_tempo[i] != 255 or zero_tempo[i+1] != 81 or zero_tempo[i+2] != 3: continue
		for j in range(i+3,i+6): zero_tempo[j] = 0
		found = true
		break
	if not expect(found and silent.load_from_bytes(zero_tempo),"Encoded zero-tempo fixture reaches actual MIDI event path"): return
	silent.play()
	silent._process(0.01)
	if not expect(silent.tempo == 120 and is_finite(silent.position) and silent.position > 0,"Decoded zero-tempo event preserves a finite advancing default clock"): return
	silent.stop()
	silent.free()
	print("PASS native PCM endpoints, exact palette, metadata release, voice stealing, missing files, header/empty-track/timebase/tempo guards")
	quit()

func expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
