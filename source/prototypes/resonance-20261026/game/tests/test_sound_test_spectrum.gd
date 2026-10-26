extends SceneTree
## Real AudioStreamGenerator→AudioServer Music-bus FFT. Dummy ONLY: no output device/listening.
const Music = preload("res://audio/music.gd")
const SoundTest = preload("res://ui/resonance/sound_test.gd")
var music
var screen
var other_screen
var other_music
var other_recording: WeakRef
var generator: AudioStreamGenerator
var playback: AudioStreamGeneratorPlayback
var failures = 0
var phase = 0.0
var prior_master_mute = true
var recording: WeakRef
var rows: Array = []
var third_party: AudioEffectSpectrumAnalyzer
var shift_name: String
func _initialize() -> void:
 prior_master_mute = AudioServer.is_bus_mute(0)
 AudioServer.set_bus_mute(0,true)
 call_deferred("run")
func check(ok: bool,message: String) -> bool:
 if not ok:
  failures += 1
  push_error(message)
 return ok
func effect_index(bus: int,effect: AudioEffect) -> int:
 if bus<0: return -1
 for index in AudioServer.get_bus_effect_count(bus):
  if AudioServer.get_bus_effect(bus,index)==effect: return index
 return -1
func tone(hz: float,seconds: float) -> Vector3:
 var deadline: int = Time.get_ticks_usec()+int(seconds*1000000)
 while Time.get_ticks_usec()<deadline:
  var count: int = mini(4096,playback.get_frames_available())
  var buffer = PackedVector2Array()
  buffer.resize(count)
  for index in range(count):
   var value: float = sin(phase)*.2
   buffer[index] = Vector2(value,value)
   phase = fposmod(phase+TAU*hz/generator.mix_rate,TAU)
  if count>0: check(playback.push_buffer(buffer),"Actual generator mixer buffer accepts finite tone samples")
  await process_frame
 return screen._audio_bands
func run() -> void:
 if not check(AudioServer.get_driver_name()=="Dummy","Spectrum tone fixture MUST use Dummy; never opens CoreAudio/listening"):
  await finish()
  return
 music = Music.new()
 root.add_child(music)
 var bus: int = AudioServer.get_bus_index("Music")
 AudioServer.set_bus_mute(bus,false)
 third_party = AudioEffectSpectrumAnalyzer.new()
 AudioServer.add_bus_effect(bus,third_party)
 var old_effects: int = AudioServer.get_bus_effect_count(bus)
 screen = SoundTest.new()
 screen.bind_music(music)
 root.add_child(screen)
 if not check(screen.play_track(0),"Actual SoundTest establishes owned single-player preview before source arrangement"):
  await finish()
  return
 recording = weakref(music.player.stream)
 music.stop()
 generator = AudioStreamGenerator.new()
 generator.mix_rate = 48000
 generator.buffer_length = .2
 music.player.stream = generator
 # Explicitly arranged known native source, NOT fake FFT/bands or a campaign recording.
 screen._preview_stream = generator
 screen._preview_player_ref = weakref(music.player)
 music.player.play()
 playback = music.player.get_stream_playback() as AudioStreamGeneratorPlayback
 if not check(playback!=null,"Actual native AudioStreamGeneratorPlayback exists"):
  await finish()
  return
 screen._ensure_analyzer()
 var owned: AudioEffectSpectrumAnalyzer = screen._analyzer
 check(owned!=null and owned!=third_party,"SoundTest owns a distinct real analyzer resource")
 screen._ensure_analyzer()
 check(AudioServer.get_bus_effect_count(bus)==old_effects+1 and effect_index(bus,owned)>=0,"Analyzer attachment idempotent and existing external effect retained")
 # Positive analysis unmuted ONLY after hard Dummy-driver guard above. No sound device exists.
 AudioServer.set_bus_mute(0,false)
 for pair in [[110.0,0],[800.0,1],[6000.0,2]]:
  var bands: Vector3 = await tone(pair[0],.85)
  var channel: int = pair[1]
  var other: float = maxf(bands[(channel+1)%3],bands[(channel+2)%3])
  check(bands[channel]>.05 and bands[channel]>other+.08,"Actual known tone dominates its real FFT band "+str(pair[0])+"Hz: "+str(bands))
  check(bands.is_finite() and bands.min_axis_index()>=0 and bands.x>=0 and bands.y>=0 and bands.z>=0 and bands.x<=1 and bands.y<=1 and bands.z<=1,"Normalized native spectral bands remain finite0..1")
  var material_bands: Vector3 = screen._art_material.get_shader_parameter("audio_bands")
  check(material_bands==bands,"Actual measured native FFT bands reach exact ShaderMaterial uniform: "+str(pair[0])+"Hz")
  rows.append({"source_hz":pair[0],"bands":str(bands),"material_audio_bands":str(material_bands),"actual_generator":true})
 # Empirical actual mixer placement probe; NEVER assume fader order from API names.
 var probe_music_db: float = AudioServer.get_bus_volume_db(bus)
 var probe_master_db: float = AudioServer.get_bus_volume_db(0)
 AudioServer.set_bus_volume_db(0,0.0)
 var gain_samples: Array = []
 for gain in [1.0,.25]:
  AudioServer.set_bus_volume_db(bus,linear_to_db(gain))
  var bands: Vector3 = await tone(800.0,.85)
  var location: Vector2i = screen._analyzer_location()
  var instance = AudioServer.get_bus_effect_instance(location.x,location.y) as AudioEffectSpectrumAnalyzerInstance
  if not check(instance!=null,"Actual owned analyzer instance exists for fader placement probe"):
   await finish()
   return
  var raw: Vector2 = instance.get_magnitude_for_frequency_range(250,2000,AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX)
  var material: Vector3 = screen._art_material.get_shader_parameter("audio_bands")
  check(material==bands,"Gain probe real measured bands equal actual shader uniform")
  gain_samples.append({"Music_gain":gain,"raw_mid_left":raw.x,"raw_mid_right":raw.y,"bands":str(bands),"shader_bands":str(material),"Music_peak_db":AudioServer.get_bus_peak_volume_left_db(bus,0)})
 var raw_one: float = maxf(gain_samples[0].raw_mid_left,gain_samples[0].raw_mid_right)
 var raw_quarter: float = maxf(gain_samples[1].raw_mid_left,gain_samples[1].raw_mid_right)
 var raw_ratio: float = raw_quarter/raw_one if raw_one>0 else -1.0
 check(raw_one>.00001 and raw_quarter>.00001,"Known800Hz actual generator produces finite positive analyzer magnitude at both gains")
 var placement = "pre-Music-fader" if raw_ratio>.85 and raw_ratio<1.15 else ("post-Music-fader" if raw_ratio>.18 and raw_ratio<.32 else "INDETERMINATE: requires investigation")
 print("SOUND_TEST_FADER_PLACEMENT ",JSON.stringify({"source_hz":800,"generator_amplitude":.2,"Master_gain":1.0,"raw_quarter_over_one":raw_ratio,"inference":placement,"samples":gain_samples,"scope":"Actual Dummy mixer measurement only, not acoustic listening; no forced placement assertion"}))
 AudioServer.set_bus_volume_db(bus,probe_music_db)
 AudioServer.set_bus_volume_db(0,probe_master_db)
 var music_db: float = AudioServer.get_bus_volume_db(bus)
 screen._change_volume(0.0)
 await tone(800.0,.1)
 check(screen._audio_bands==Vector3.ZERO,"Real Music volume0 suppresses pre-fader FFT bands")
 AudioServer.set_bus_volume_db(bus,music_db)
 var master_db: float = AudioServer.get_bus_volume_db(0)
 AudioServer.set_bus_volume_db(0,linear_to_db(0.0))
 await tone(800.0,.1)
 check(screen._audio_bands==Vector3.ZERO,"Real Master volume0 suppresses pre-fader FFT bands")
 AudioServer.set_bus_volume_db(0,master_db)
 await tone(6000.0,.2)
 var held: Vector3 = screen._audio_bands
 var held_phase: float = screen._phase
 screen.toggle_playback()
 await tone(110.0,.15)
 check(music.player.stream_paused and screen._audio_bands==held and screen._phase==held_phase,"Paused real transport freezes spectrum/phase, not wallclock motion")
 screen.toggle_playback()
 AudioServer.set_bus_mute(bus,true)
 await tone(800.0,.1)
 check(screen._audio_bands==Vector3.ZERO,"Muted Music bus immediately publishes zero bands, no stale FFT glow")
 AudioServer.set_bus_mute(bus,false)
 AudioServer.set_bus_mute(0,true)
 await tone(800.0,.1)
 check(screen._audio_bands==Vector3.ZERO,"Muted Master immediately publishes zero bands")
 AudioServer.set_bus_mute(0,false)
 screen.set_reduced_motion(true)
 await tone(6000.0,.1)
 check(screen._audio_bands==Vector3.ZERO and screen._phase==0 and screen._art_energy==0,"Reduced motion disables spectrum/phase/energy motion")
 screen.set_reduced_motion(false)
 await tone(110.0,.2)
 shift_name = "SpectrumFixtureShift_"+str(OS.get_process_id())
 AudioServer.add_bus(bus)
 AudioServer.set_bus_name(bus,shift_name)
 var shifted: int = AudioServer.get_bus_index("Music")
 check(shifted==bus+1 and screen._analyzer_location().x==shifted,"Analyzer lookup follows exact resource across actual bus index shift")
 check(effect_index(shifted,third_party)>=0,"Index shift preserves unrelated same-class external effect")
 var foreign = AudioEffectSpectrumAnalyzer.new()
 AudioServer.add_bus_effect(bus,foreign)
 other_music = Music.new()
 root.add_child(other_music)
 other_screen = SoundTest.new()
 other_screen.bind_music(other_music)
 root.add_child(other_screen)
 if not check(other_screen.play_track(1),"Second actual Music owner independently establishes preview on shared Music bus"):
  await finish()
  return
 other_recording = weakref(other_music.player.stream)
 check(screen._owns_preview() and other_screen._owns_preview() and music.player!=other_music.player,"Two screens concurrently own distinct real players, not impossible shared-player ownership")
 other_screen._ensure_analyzer()
 var other_owned: AudioEffectSpectrumAnalyzer = other_screen._analyzer
 check(other_owned!=null and other_owned!=screen._analyzer and effect_index(shifted,other_owned)>=0,"Two SoundTests own distinct analyzer identities on same Music bus")
 screen._remove_analyzer()
 check(effect_index(shifted,owned)<0 and effect_index(shifted,third_party)>=0 and effect_index(shifted,other_owned)>=0 and effect_index(bus,foreign)>=0,"Remove deletes ONLY exact owned analyzer, retaining second screen and foreign effects across buses")
 screen._ensure_analyzer()
 check(screen._analyzer!=null and effect_index(shifted,screen._analyzer)>=0,"Owned analyzer can reattach after explicit retirement")
 other_screen.close()
 other_screen.free()
 other_screen = null
 other_music.stop()
 other_music.free()
 other_music = null
 check(effect_index(shifted,other_owned)<0 and effect_index(shifted,screen._analyzer)>=0 and effect_index(shifted,third_party)>=0 and effect_index(bus,foreign)>=0,"Second-screen close retains first-screen and external effects by identity")
 # Music bus was created by this fixture; removal is a real owner-loss boundary.
 AudioServer.remove_bus(shifted)
 await process_frame
 screen._update_art(.1)
 check(screen._analyzer_location()==Vector2i(-1,-1) and screen._audio_bands==Vector3.ZERO,"Removed Music bus fails closed without stale index/effect access")
 check(effect_index(AudioServer.get_bus_index(shift_name),foreign)>=0,"Removing Music bus leaves foreign-bus effect untouched")
 print("SOUND_TEST_NATIVE_FFT_TONES ",JSON.stringify(rows))
 await finish()
func finish() -> void:
 AudioServer.set_bus_mute(0,true)
 if is_instance_valid(other_screen): other_screen.close(); other_screen.free()
 other_screen = null
 if is_instance_valid(other_music): other_music.stop(); other_music.free()
 other_music = null
 if is_instance_valid(screen): screen.close(); screen.free()
 screen = null
 if is_instance_valid(music): music.stop(); music.free()
 music = null
 playback = null
 generator = null
 var shift: int = AudioServer.get_bus_index(shift_name) if not shift_name.is_empty() else -1
 if shift>=0: AudioServer.remove_bus(shift)
 await process_frame
 var deadline: int = Time.get_ticks_usec()+2000000
 while ((recording!=null and recording.get_ref()!=null) or (other_recording!=null and other_recording.get_ref()!=null)) and Time.get_ticks_usec()<deadline:
  OS.delay_msec(2)
  await process_frame
 check(recording==null or recording.get_ref()==null,"Replaced native MP3 actually releases after source ownership transfer")
 check(other_recording==null or other_recording.get_ref()==null,"Second independent owner MP3 releases after close and mixer drain")
 AudioServer.set_bus_mute(0,prior_master_mute)
 call_deferred("terminal")
func terminal() -> void:
 await process_frame
 await process_frame
 if failures==0: print("PASS actual Dummy AudioStreamGenerator low/mid/high→Music FFT dominance/mute/paused/reduced/identity lifecycle; NOT listening or fabricated-band proof")
 quit(0 if failures==0 else 1)
