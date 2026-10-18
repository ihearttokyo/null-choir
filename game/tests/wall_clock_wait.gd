extends RefCounted

# SceneTreeTimer can inherit an old long frame delta before CoreAudio has advanced.
static func seconds(tree: SceneTree, duration: float) -> void:
	var end_us = Time.get_ticks_usec() + ceili(duration * 1000000.0)
	while Time.get_ticks_usec() < end_us:
		await tree.process_frame
