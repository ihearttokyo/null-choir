extends "res://tests/test_ossuary_finale_battle.gd"

const EXIT_WITNESS_SHA = "01f312ff02d1e34531394aa51782a3ce5f75698e7d499fa163f66785e1d12c8d"
const EXIT_BATTLE_SHA = "e74d2da260eff823464f524eb69a2178b81138137225b6a5f4c8553ee93e7f79"
const EXIT_NONPUBLISHING = ["--ossuary-exit-controls","--ossuary-exit-live-controls","--ossuary-exit-pin-rejection","--omit-ossuary-exit"]

func exit_pins_match() -> bool:
	return battle_pins_match() and FileAccess.get_sha256("res://tests/ossuary_finale_exit_witness.gd") == EXIT_WITNESS_SHA and FileAccess.get_sha256("res://tests/test_ossuary_finale_battle.gd") == EXIT_BATTLE_SHA

class QuietExit:
	extends "res://tests/ossuary_finale_exit_witness.gd"
	func require(value: bool, label: String) -> bool:
		if not value:
			ok = false
			failures.append(label)
		return value

func exit_controls() -> bool:
	var segment = QuietExit.new()
	var fields: Array = ["cx_phase","captures","saves","cx_pending_capture","cx_pending_save","cx_trace","ledger"]
	var before: Dictionary = Exit.fields_image(segment,fields)
	var passed: bool = expect(not segment.current() and not segment.prior_frozen(),"detached C has no accepted world/history")
	for method in ["before_exit","before_capture","before_save"]:
		segment.ok = true
		segment.failures.clear()
		passed = expect(not segment.call(method) and not segment.ok and Exit.fields_image(segment,fields) == before,"detached C lifecycle rejects before mutation") and passed
	return passed

func run() -> void:
	if "--ossuary-exit-controls" in OS.get_cmdline_user_args():
		var passed: bool = exit_controls()
		if passed: print("PASS CONTROLLED C detached lifecycle guards; no prefix/save/exit acceptance")
		quit(0 if passed else 1)
		return
	if "--ossuary-exit-pin-rejection" in OS.get_cmdline_user_args():
		await exit_pin_rejection()
		return
	var result: bool = await walk_through_ossuary_exit()
	if result:
		if "--ossuary-exit-live-controls" in OS.get_cmdline_user_args(): print("PASS CONTROLLED C earned-B-boundary forged lifecycle/stale-ID/caller-inventory guards; real exit not attempted")
		else: print("PASS bounded earned Ossuary exit/save/intermission; synthetic native input only, not Inversion/app/full campaign")
	await finish(0 if result else 1)

func walk_through_ossuary_exit(profile_prefix: String = "") -> bool:
	return (await _completed_ossuary_exit(profile_prefix)) != null

func accepted_ossuary_exit(profile_prefix: String = "") -> Exit:
	if EXIT_NONPUBLISHING.any(func(flag): return flag in OS.get_cmdline_user_args()): return null
	return await _completed_ossuary_exit(profile_prefix)

func _completed_ossuary_exit(profile_prefix: String = "") -> Exit:
	if not expect(exit_pins_match(),"exact Exit/Battle/ancestor/core/map pins BEFORE prefix allocation"): return null
	var accepted = await accepted_ossuary_battle(profile_prefix)
	if accepted == null: return null
	var controlled: bool = "--ossuary-exit-live-controls" in OS.get_cmdline_user_args()
	var segment = QuietExit.new() if controlled else Exit.new()
	var result: bool = segment.adopt_after(self,accepted)
	if result:
		game.transport_witness = segment
		if controlled: result = exit_live_controls(segment)
		else: result = await segment.run_route()
	var released: bool = segment.release_exit_input()
	if is_instance_valid(game): game.transport_witness = null
	return segment if expect(released,"C physical E/pending cleanup before dispatch release") and result else null

func exit_pin_rejection() -> void:
	if not expect(not exit_pins_match() and battle_pins_match(),"one C-only pin mismatch with valid inherited source"):
		quit(1)
		return
	var prefix: String = "user://CONTROLLED_exit_pin_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	var suffixes: Array = ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]
	if not expect(game == null and root.get_child_count() == 0 and suffixes.all(func(suffix): return not FileAccess.file_exists(prefix+suffix)),"fresh C-only pin-rejection namespace before prefix"):
		quit(1)
		return
	var result: bool = await walk_through_ossuary_exit(prefix)
	quit(0 if expect(not result and game == null and root.get_child_count() == 0 and suffixes.all(func(suffix): return not FileAccess.file_exists(prefix+suffix)),"C mismatch refuses before inherited scene/profile adoption") else 1)

func exit_live_controls(segment) -> bool:
	if not expect(segment.validate() and segment.current() and segment.prior_frozen(),"live C controls begin at actual earned B endpoint"): return false
	var fields: Array = ["cx_phase","captures","saves","cx_pending_capture","cx_pending_save","cx_trace","ledger"]
	var before: Dictionary = Exit.fields_image(segment,fields)
	segment.before_exit()
	var passed: bool = expect(not segment.ok and Exit.fields_image(segment,fields) == before and segment.prior_frozen(),"forged C exit outside actual queued Player physics rejects before effects")
	segment.ok = true
	segment.failures.clear()
	var original_main: int = segment.main_id
	segment.main_id = -1
	passed = expect(not segment.cx_identity() and Exit.fields_image(segment,fields) == before,"stale owning Main ID rejects before lifecycle mutation") and passed
	segment.main_id = original_main
	var record: Dictionary = segment.cx_records[0]
	var original_fields: Array = record.fields.duplicate()
	var original_image: Dictionary = record.image.duplicate(true)
	record.fields.erase("damage")
	record.image.erase("damage")
	passed = expect(not segment.prior_frozen(),"C caller cannot erase a field from both inventory and image") and passed
	record.fields = original_fields
	record.image = original_image
	var original_aliases: Dictionary = record.aliases.duplicate()
	record.aliases["game"] = [segment.game,segment.main_id]
	passed = expect(not segment.prior_frozen(),"C caller cannot widen frozen world-alias inventory") and passed
	record.aliases = original_aliases
	return passed and expect(segment.validate() and segment.current() and segment.prior_frozen() and segment.cx_trace.is_empty() and segment.captures == 0 and segment.saves == 0,"all controlled observer-only mutations restored, prior records intact and real exit untouched")
