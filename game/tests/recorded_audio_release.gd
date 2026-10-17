extends RefCounted

static func stop(game) -> bool:
	if game.music.player.stream == null: return false
	var recording: WeakRef = weakref(game.music.player.stream)
	var tree: SceneTree = game.get_tree()
	game.show_title()
	# Headless process frames can outrun the native audio callback.
	var deadline: int = Time.get_ticks_usec()+2000000
	while recording.get_ref() != null and Time.get_ticks_usec() < deadline:
		OS.delay_msec(2)
		await tree.process_frame
	return recording.get_ref() == null
