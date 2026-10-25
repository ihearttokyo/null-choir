extends SceneTree

const Music = preload("res://audio/music.gd")
const Release = preload("res://tests/recorded_audio_release.gd")
const WallClock = preload("res://tests/wall_clock_wait.gd")

# Audio-only owner fixture; deliberately does not instantiate Main or a level.
class Owner extends Node:
	var music
	func show_title() -> void: music.play_title()

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var owner = Owner.new()
	root.add_child(owner)
	owner.music = Music.new()
	owner.add_child(owner.music)
	owner.music.play_title()
	assert(not await Release.stop(owner), "Title-only playback must fail the campaign-release precondition")
	owner.music.play_level(0)
	var held = owner.music.player.stream
	var started = Time.get_ticks_usec()
	assert(not await Release.stop(owner), "Held native campaign stream must time out instead of falsely passing")
	assert(Time.get_ticks_usec()-started >= 2000000 and Time.get_ticks_usec()-started < 3000000)
	held = null
	owner.music.play_level(0)
	assert(await Release.stop(owner), "Unretained campaign stream must release after native title replacement")
	assert(owner.music.player.stream is AudioStreamMP3 and owner.music.player.playing)
	var title = weakref(owner.music.player.stream)
	owner.music.play_level(7)
	await WallClock.seconds(self, 0.2)
	assert(title.get_ref() == null, "Title stream must release after native campaign replacement")
	owner.music.stop()
	owner.free()
	owner = null
	await WallClock.seconds(self, 0.15)
	print("PASS native Dummy campaign-release helper rejects title-only/retained recordings; title/campaign replacement releases streams; audio-only owner fixture NOT Main")
	quit()
