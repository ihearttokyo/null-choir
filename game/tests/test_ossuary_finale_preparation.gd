extends "res://tests/test_ossuary_story.gd"

const Preparation = preload("res://tests/ossuary_finale_witness.gd")
const PREPARATION_WITNESS_SHA = "61b9b89773ab5f214d9b9a734b58ba32326723c08f41683605557e0554d69d20"
const PREPARATION_STORY_SHA = "901e8cf089fef86ca8f779a620bf165cfb24d19a35512f0c6ef6f00b9aee0df3"

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
