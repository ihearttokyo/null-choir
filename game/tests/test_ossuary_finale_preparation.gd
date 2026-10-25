extends "res://tests/test_ossuary_story.gd"

const Preparation = preload("res://tests/ossuary_finale_witness.gd")
const PREPARATION_WITNESS_SHA = "53003583eef045bb8041ffe25400777a52caadc01962b01bf8d22f2f5385ad18"
const PREPARATION_STORY_SHA = "b916330757b56403d0c43867e3a9d70caa129a50ecaee48ac5ac3350a511db57"

func preparation_pins_match() -> bool:
	return story_pins_match() and FileAccess.get_sha256("res://tests/ossuary_finale_witness.gd") == PREPARATION_WITNESS_SHA and FileAccess.get_sha256("res://tests/test_ossuary_story.gd") == PREPARATION_STORY_SHA

func run() -> void:
	var result: bool = await walk_through_ossuary_preparation()
	if result: print("PASS bounded earned Ossuary saved checkpoint/original gate preparation; synthetic native input, not finale/app acceptance")
	await finish(0 if result else 1)

func walk_through_ossuary_preparation(profile_prefix: String = "") -> bool:
	return (await _completed_ossuary_preparation(profile_prefix)) != null

func accepted_ossuary_preparation(profile_prefix: String = "") -> Preparation:
	if "--omit-ossuary-preparation-gate" in OS.get_cmdline_user_args(): return null
	return await _completed_ossuary_preparation(profile_prefix)

func _completed_ossuary_preparation(profile_prefix: String = "") -> Preparation:
	if not expect(preparation_pins_match(),"exact preparation witness/returned-Story/ancestor/core/map pins BEFORE prefix adoption"): return null
	var accepted = await accepted_ossuary_story(profile_prefix)
	if accepted == null: return null
	var segment = Preparation.new()
	var result: bool = segment.adopt_after(self,accepted)
	# Actual accepted Story remains local; adoption/dispatch have no intervening await.
	if result:
		game.transport_witness = segment
		result = await segment.run_route()
	var released: bool = segment.release_preparation_input()
	if is_instance_valid(game): game.transport_witness = null
	return segment if expect(released,"preparation releases its own physical E and pending interaction before inherited cleanup") and result else null
