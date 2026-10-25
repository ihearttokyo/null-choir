extends SceneTree
const Music = preload("res://audio/music.gd")
const WallClock = preload("res://tests/wall_clock_wait.gd")
const SOURCES = {
 "res://audio/suno/processional.mp3":"81c5f60d034fb18a900cdb54ebe1d6cb8f43aac81c405e75b07325f9b310897d",
 "res://audio/suno/heart.mp3":"2df85b64edf66df4a0217a610a7ff5afaa6c0a7a92d0a8b70a52cde807a59104",
 "res://audio/title/title-suno.mp3":"81c5f60d034fb18a900cdb54ebe1d6cb8f43aac81c405e75b07325f9b310897d",
 "res://audio/title/interlude-suno.mp3":"2df85b64edf66df4a0217a610a7ff5afaa6c0a7a92d0a8b70a52cde807a59104"}
func _initialize() -> void: call_deferred("run")
func run() -> void:
 for path in SOURCES: assert(FileAccess.get_sha256(path) == SOURCES[path])
 var music = Music.new()
 root.add_child(music)
 var player = music.player
 var bus = AudioServer.get_bus_index("Music")
 AudioServer.set_bus_volume_db(bus, -9)
 AudioServer.set_bus_mute(bus, true)
 paused = true
 music.play_title()
 assert(music.playback_context == "title" and player.stream.resource_path == "res://audio/title/title-suno.mp3")
 assert(player.stream is AudioStreamMP3 and not player.stream.loop and absf(player.stream.get_length() - 269.4535) < .01)
 await WallClock.seconds(self,.15)
 assert(player.playing and player.get_playback_position() > 0)
 for role in ["interlude", "title", "interlude"]:
  if role == "interlude": music.play_interlude()
  else: music.play_title()
  var expected: String = music.interlude_track if role == "interlude" else music.title_track
  assert(player.stream.resource_path == expected and music.playback_context == role and not player.stream.loop)
  assert(player.playing and not player.stream_paused and music.get_child_count() == 1 and music.player == player)
  if role == "interlude": assert(absf(player.stream.get_length()-299.6135)<.01)
  await WallClock.seconds(self,.15)
  music.set_paused(true)
  await WallClock.seconds(self,.1)
  var position: float = player.get_playback_position()
  var stream = player.stream
  await WallClock.seconds(self,.1)
  assert(is_equal_approx(position,player.get_playback_position()))
  if role == "interlude": music.play_interlude()
  else: music.play_title()
  assert(player.stream == stream and not player.stream_paused and player.get_playback_position() >= position)
 player.seek(player.stream.get_length() - .08)
 await WallClock.seconds(self,.25)
 assert(not player.playing,"Interlude one-shot must stop at its native end")
 music.play_interlude()
 assert(player.playing and player.get_playback_position() < .15,"Finished interlude may restart only on an explicit request")
 assert(music.title_track not in music.level_tracks and music.interlude_track not in music.level_tracks)
 for index in [2,7,0]:
  music.play_level(index)
  assert(music.playback_context == "campaign" and player.stream.resource_path == music.level_tracks[index] and player.stream.loop)
  var campaign_stream = player.stream
  var campaign_ref: WeakRef = weakref(campaign_stream)
  music.set_pressure(1)
  music._process(1)
  music.play_interlude()
  assert(music.playback_context == "interlude" and player.stream.resource_path == music.interlude_track and not player.stream.loop)
  assert(music.pressure == 0 and music.pressure_target == 0 and player.volume_db == -3)
  assert(campaign_stream != player.stream and campaign_stream.loop,"Menu must not mutate held campaign loop state")
  campaign_stream = null
  var deadline = Time.get_ticks_usec() + 2000000
  while campaign_ref.get_ref() != null and Time.get_ticks_usec() < deadline:
   OS.delay_msec(2)
   await process_frame
  assert(campaign_ref.get_ref() == null,"Campaign recording must release even when menu reuses its exact song bytes")
 assert(AudioServer.get_bus_volume_db(bus) == -9 and AudioServer.is_bus_mute(bus))
 for path in SOURCES: assert(FileAccess.get_sha256(path) == SOURCES[path],"No existing Suno recording may be overwritten")
 music.stop()
 music.free()
 paused = false
 await WallClock.seconds(self,.15)
 print("PASS native Dummy Suno menu roles: exact original selected bytes, recorded lengths, one owner, explicit role switching/loop policy, same-role resume, pause/mute; NOT audition or actual Main completion proof")
 quit(0)
