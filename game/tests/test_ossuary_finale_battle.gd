extends "res://tests/test_ossuary_finale_preparation.gd"

const Battle = preload("res://tests/ossuary_finale_battle_witness.gd")
const BATTLE_WITNESS_SHA = "051b6324c32537773ed66ec56d9788f236a0fff7433a476b7d4f7b843772ad86"
const BATTLE_PREPARATION_SHA = "411ab1ce82617fd1d5646058ee96635bee625af11750b9074ac2a93d864d35c3"
const BATTLE_NONPUBLISHING = ["--ossuary-battle-controls","--ossuary-battle-live-controls","--ossuary-battle-pin-rejection","--omit-ossuary-battle-fire"]

class QuietBattle:
	extends "res://tests/ossuary_finale_battle_witness.gd"
	func require(value: bool, label: String) -> bool:
		if not value:
			ok = false
			if not label in failures: failures.append(label)
		return value

func battle_pins_match() -> bool:
	return preparation_pins_match() and FileAccess.get_sha256("res://tests/ossuary_finale_battle_witness.gd") == BATTLE_WITNESS_SHA and FileAccess.get_sha256("res://tests/test_ossuary_finale_preparation.gd") == BATTLE_PREPARATION_SHA

func run() -> void:
	if "--ossuary-battle-controls" in OS.get_cmdline_user_args():
		quit(0 if battle_controls() else 1)
		return
	if "--ossuary-battle-pin-rejection" in OS.get_cmdline_user_args():
		await battle_pin_rejection()
		return
	var result: bool = await walk_through_ossuary_battle()
	if result:
		if "--ossuary-battle-live-controls" in OS.get_cmdline_user_args(): print("PASS earned-boundary Battle forged-callback/stale-ID controls; finale combat not executed")
		else: print("PASS bounded earned Ossuary five-original finale battle; synthetic native input, not exit/Inversion/app acceptance")
	await finish(0 if result else 1)

func walk_through_ossuary_battle(profile_prefix: String = "") -> bool:
	return (await _completed_ossuary_battle(profile_prefix)) != null

func accepted_ossuary_battle(profile_prefix: String = "") -> Battle:
	if BATTLE_NONPUBLISHING.any(func(flag): return flag in OS.get_cmdline_user_args()): return null
	return await _completed_ossuary_battle(profile_prefix)

func _completed_ossuary_battle(profile_prefix: String = "") -> Battle:
	if not expect(battle_pins_match(),"exact Battle/Preparation/ancestor/core/map pins BEFORE prefix allocation"): return null
	var accepted = await accepted_ossuary_preparation(profile_prefix)
	if accepted == null: return null
	var controls: bool = "--ossuary-battle-live-controls" in OS.get_cmdline_user_args()
	var segment = QuietBattle.new() if controls else Battle.new()
	var result: bool = segment.adopt_after(self,accepted)
	# Keep the actual Preparation local; no await before Battle adoption/dispatch.
	if result:
		game.transport_witness = segment
		if controls: result = battle_live_controls(segment)
		else: result = await segment.run_route()
	var released: bool = segment.release_battle_input()
	if is_instance_valid(game): game.transport_witness = null
	return segment if expect(released,"Battle releases its fire/movement/physical E and pending interaction before inherited cleanup") and result else null

func battle_live_controls(segment) -> bool:
	if not expect(segment.current() and segment.prior_frozen(),"live Battle controls start at actual accepted Preparation handoff"): return false
	var fields: Array = ["ledger","shots","slot","last_tick","last_time","events","encounter_pending","activation_record","removed","deaths"]
	var frozen: Dictionary = Battle.fields_image(segment,fields)
	segment.before_shot(1)
	var passed: bool = expect(not segment.ok and Battle.fields_image(segment,fields) == frozen and segment.prior_frozen(),"forged shot rejected before new observer debit; old records remain frozen")
	segment.ok = true
	segment.failures.clear()
	var identity: int = segment.main_id
	segment.main_id = -1
	segment.before_encounter(Battle.FINALE.id)
	passed = expect(not segment.ok and not segment.current() and Battle.fields_image(segment,fields) == frozen and segment.prior_frozen(),"stale Main identity rejected before encounter expectations mutate") and passed
	segment.main_id = identity
	return passed and expect(segment.current() and segment.prior_frozen(),"actual identity restored without prior record mutation")

func battle_controls() -> bool:
	if not expect(battle_pins_match(),"detached controls use real Battle/Preparation/ancestor pins"): return false
	var completed = Preparation.new()
	var gate = Node3D.new()
	completed.gate_alias = gate
	completed.damage = [["retained",{"nested":[1,2]}]]
	gate.free()
	var segment = QuietBattle.new()
	var passed: bool = expect(segment.freeze_preparation(completed),"actual Preparation stored fields and already-freed alias bind")
	var image: Dictionary = segment.previous_frozen.duplicate(true)
	var original: Variant = completed.gate_alias
	passed = expect(segment.preparation_fields_unchanged(),"unchanged original freed Variant matches") and passed
	completed.gate_alias = null
	passed = expect(not Battle.fields_match(completed,segment.preparation_fields,image) and not segment.preparation_fields_unchanged(),"null already fails canonical stored image") and passed
	var replacement = Node3D.new()
	var different: Variant = replacement
	replacement.free()
	completed.gate_alias = different
	passed = expect(Battle.fields_match(completed,segment.preparation_fields,image) and not segment.preparation_fields_unchanged(),"actual different-freed collapse rejected by the new exact participant alias guard") and passed
	completed.gate_alias = original
	completed.damage[0][1].nested.append(3)
	passed = expect(not segment.preparation_fields_unchanged(),"nested Preparation record mutation rejected") and passed
	completed.damage[0][1].nested.pop_back()
	passed = expect(segment.preparation_fields_unchanged() and segment.previous_frozen == image and is_same(completed.gate_alias,original),"original participant field and frozen image preserved") and passed
	var fields: Array = ["ledger","shots","slot","last_tick","last_time"]
	var frozen: Dictionary = Battle.fields_image(segment,fields)
	segment.before_shot(1)
	passed = expect(not segment.ok and Battle.fields_image(segment,fields) == frozen,"detached shot refuses before observer mutation") and passed
	if passed: print("PASS CONTROLLED Battle actual-Preparation alias/nested-history/forged-shot guards; no earned campaign")
	return passed

func battle_pin_rejection() -> void:
	if not expect(not battle_pins_match() and preparation_pins_match(),"one Battle-only dependency mismatch with valid inherited pins"):
		quit(1)
		return
	var isolated_prefix: String = "user://CONTROLLED_battle_pin_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	var suffixes: Array = ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]
	if not expect(game == null and root.get_child_count() == 0 and suffixes.all(func(suffix): return not FileAccess.file_exists(isolated_prefix+suffix)),"fresh pin-rejection root/profile before allocation"):
		quit(1)
		return
	var result: bool = await walk_through_ossuary_battle(isolated_prefix)
	if not expect(not result and game == null and root.get_child_count() == 0 and suffixes.all(func(suffix): return not FileAccess.file_exists(isolated_prefix+suffix)),"Battle pin rejection creates no root/profile"):
		quit(1)
		return
	print("PASS CONTROLLED Battle pin rejection before prefix allocation; not earned battle")
	quit(0)
