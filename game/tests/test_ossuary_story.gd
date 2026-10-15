extends "res://tests/test_ossuary_second_loop.gd"

# Functions/constants only: the accepted fixture's stored fields remain unchanged.
const Story = preload("res://tests/ossuary_story_witness.gd")
const STORY_BOUNDARY_SHA = "7b167e6c759a6e8da32dd2a5f57cac5dab387e7e4eac7147a1b784a933818120"
const STORY_WITNESS_SHA = "23e66c6342a391e6af4d98d0afff5c41a2a88f8cbd037b1f7bbae0a870aa49e9"

class QuietStory:
	extends "res://tests/ossuary_story_witness.gd"
	func require(value: bool, label: String) -> bool:
		if not value:
			ok = false
			if not label in failures: failures.append(label)
		return value

func story_pins_match() -> bool:
	return second_pins_match() and FileAccess.get_sha256("res://tests/test_ossuary_second_loop.gd") == STORY_BOUNDARY_SHA and FileAccess.get_sha256("res://tests/ossuary_story_witness.gd") == STORY_WITNESS_SHA

func run() -> void:
	if "--ossuary-story-controls" in OS.get_cmdline_user_args():
		quit(0 if story_controls() else 1)
		return
	if "--ossuary-story-pin-rejection" in OS.get_cmdline_user_args():
		await story_pin_rejection()
		return
	var result: bool = await walk_through_ossuary_story()
	if result:
		if "--ossuary-story-live-controls" in OS.get_cmdline_user_args(): print("PASS earned-boundary Story forged-callback/stale-ID controls; Story spur not executed")
		else: print("PASS bounded earned Ossuary Story spur/return; synthetic native input, not human/app/fullcampaign acceptance")
	await finish(0 if result else 1)

func walk_through_ossuary_story(profile_prefix: String = "") -> bool:
	if not expect(story_pins_match(),"exact Story/returned-Second/ancestor/core/map pins BEFORE allocation/input/profile adoption"): return false
	var accepted = await accepted_ossuary_second_loop(profile_prefix)
	if accepted == null: return false
	var controls: bool = "--ossuary-story-live-controls" in OS.get_cmdline_user_args()
	var segment = QuietStory.new() if controls else Story.new()
	var result: bool = segment.adopt_after(self,accepted)
	# Keep accepted locally alive; no await between return, adoption and dispatch.
	if result:
		game.transport_witness = segment
		if controls: result = story_live_controls(segment)
		else: result = await segment.run_route()
	var released: bool = segment.release_story_input()
	if is_instance_valid(game): game.transport_witness = null
	return expect(released,"Story releases its physical E and pending interaction before inherited cleanup") and result

func story_live_controls(segment) -> bool:
	if not expect(segment.current() and segment.prior_frozen(),"live controls start at real accepted Second handoff"): return false
	var fields: Array = ["inputs","removed","discoveries","pending_story","key_events"]
	var frozen: Dictionary = Second.fields_image(segment,fields)
	segment.before_interact()
	var passed: bool = expect(not segment.ok and Second.fields_image(segment,fields) == frozen and segment.prior_frozen(),"forged callback on current native identity rejected without record/state mutation")
	segment.ok = true
	segment.failures.clear()
	var original: int = segment.main_id
	segment.main_id = -1
	segment.before_interact()
	passed = expect(not segment.current() and not segment.ok and Second.fields_image(segment,fields) == frozen and segment.prior_frozen(),"stale Main ID rejected without mutation at actual earned handoff") and passed
	segment.main_id = original
	return passed and expect(segment.current() and segment.prior_frozen(),"live-control native identity restored; earlier records remain frozen")

func story_controls() -> bool:
	var passed: bool = expect(story_pins_match(),"detached Story controls use exact new boundary/witness pins")
	var segment = QuietStory.new()
	segment.before_interact()
	passed = expect(not segment.ok and segment.inputs.is_empty() and segment.removed.is_empty() and segment.discoveries == [3,4] and not segment.pending_story,"forged detached Story callback rejected before observation/expectation mutation") and passed
	passed = expect(not segment.current() and not segment.actor(null),"unbound Story identity rejected") and passed
	var accepted = Second.new()
	accepted.previous = Witness.new()
	var marker = Node3D.new()
	accepted.previous.markers[Story.STORY.id] = weakref(marker)
	accepted.previous.marker_values[Story.STORY.id] = [marker.get_instance_id(),marker.transform]
	accepted.damage = [["retained",{"nested":[1,2]}]]
	segment.previous = accepted
	segment.previous_frozen = Second.fields_image(accepted,Second.script_fields(accepted))
	segment.first_frozen = Second.fields_image(accepted.previous,Second.script_fields(accepted.previous))
	passed = expect(segment.earlier_frozen(),"both retained witnesses initially frozen") and passed
	marker.free()
	passed = expect(segment.earlier_frozen(),"legitimate marker target retirement preserves stored-history freeze") and passed
	accepted.damage[0][1].nested.append(3)
	passed = expect(not segment.earlier_frozen(),"nested Second record mutation rejected") and passed
	accepted.damage[0][1].nested.pop_back()
	accepted.previous.marker_values[Story.STORY.id][1] = Transform3D(Basis.IDENTITY,Vector3.ONE)
	passed = expect(not segment.earlier_frozen(),"nested first-loop marker-record mutation rejected") and passed
	if passed: print("PASS detached Story callback/identity/stored-history controls; not native Story acceptance")
	return passed

func story_pin_rejection() -> void:
	if not expect(not story_pins_match() and second_pins_match(),"one Story-only dependency mismatch with valid inherited pins"):
		quit(1)
		return
	var prefix: String = "user://ossuary_story_pin_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	var suffixes: Array = ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]
	if not expect(game == null and root.get_child_count() == 0 and not ot_started and suffixes.all(func(suffix): return not FileAccess.file_exists(prefix+suffix)),"fresh Story wrong-pin namespace before allocation"):
		quit(1)
		return
	var result: bool = await walk_through_ossuary_story(prefix)
	var passed: bool = expect(not result and game == null and root.get_child_count() == 0 and not ot_started and suffixes.all(func(suffix): return not FileAccess.file_exists(prefix+suffix)),"actual Story runner refuses wrong pin before scene/profile/input adoption")
	if passed: print("PASS Story wrong-pin pre-adoption refusal")
	quit(0 if passed else 1)
