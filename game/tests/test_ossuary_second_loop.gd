extends "res://tests/test_ossuary_transport_loop.gd"

# Functions/constants only: no new Main/SceneTree fields enter the first-loop freeze.
const Second = preload("res://tests/ossuary_second_loop_witness.gd")
const SECOND_WITNESS_SHA = "6924ba8bc72588d497ab22625798ff7d1f09ed3de713c1ba3fbea19a181d2bfb"
const FIRST_ADAPTER_SHA = "92c669c2e18741b42e235a48ef2d6780b59f36ec299cdbacfcd112c045acfa26"
const FIRST_GUARDS_SHA = "f0565c786674df1475c88de08e5e98ee471e058cdfce5ba2f978f89abdbea17a"

func second_pins_match() -> bool:
	return transport_pins_match() and FileAccess.get_sha256("res://tests/ossuary_second_loop_witness.gd") == SECOND_WITNESS_SHA and FileAccess.get_sha256("res://tests/test_ossuary_transport_loop.gd") == FIRST_ADAPTER_SHA and FileAccess.get_sha256("res://tests/test_ossuary_witness_guards.gd") == FIRST_GUARDS_SHA

func run() -> void:
	if "--ossuary-second-controls" in OS.get_cmdline_user_args():
		quit(0 if second_controls() else 1)
		return
	if "--ossuary-second-pin-rejection" in OS.get_cmdline_user_args():
		await second_pin_rejection()
		return
	var result: bool = await walk_through_ossuary_second_loop()
	if result: print("PASS bounded earned Ossuary second loop; synthetic native input, not app/fullcampaign acceptance")
	await finish(0 if result else 1)

func walk_through_ossuary_second_loop(profile_prefix: String = "") -> bool:
	return (await accepted_ossuary_second_loop(profile_prefix)) != null

func accepted_ossuary_second_loop(profile_prefix: String = "") -> Second:
	if not expect(second_pins_match(),"exact second-witness/ancestor/core/map pins BEFORE any adoption"): return null
	# The whole accepted prefix still earns every state change through production.
	var result: bool = await walk_through_ossuary_transport(TransportMain.new(),profile_prefix)
	var segment = Second.new()
	if result: result = segment.adopt_after(self,ot_witness)
	if result:
		game.transport_witness = segment
		result = await segment.run_route()
	# Preserve inherited Blood E-up cleanup; do not clear its action early.
	if is_instance_valid(game):
		if segment.key_events.size() == 1 and segment.key_events[0][0]: segment.physical_key(false)
		game.transport_witness = null
	return segment if result else null

func second_controls() -> bool:
	# Detached controls only. This branch cannot enter the earned replay.
	var passed: bool = expect(second_pins_match(),"controls use pinned source")
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/06_ossuary.json"))
	passed = expect(authored.loops[1] == {"id":"ossuary_loop_mandala","hero":"ossuary_bone_mandala","route":[[24.0,24.0],[27.0,24.0],[27.0,18.0],[27.0,16.0],[33.0,16.0],[33.0,9.0],[25.0,9.0],[25.0,11.0],[19.0,11.0],[19.0,24.0],[24.0,24.0]]} and authored.interactions[1] == Second.IVORY and authored.interactions[3].cell == [1.5,15.5] and authored.encounters[1].enemy_ids == ["ossuary_enemy_08","ossuary_enemy_09","ossuary_enemy_10","ossuary_enemy_11","ossuary_enemy_12","ossuary_enemy_13","ossuary_enemy_14","ossuary_enemy_15"] and authored.encounters[3].enemy_ids == ["ossuary_enemy_19","ossuary_enemy_20","ossuary_enemy_21"],"exact authored mandala route/Ivory/off-route Story/new original IDs") and passed
	passed = expect(Second.guarded_amount(22,Vector3.FORWARD,Vector3.FORWARD,true) == 7 and Second.guarded_amount(14,Vector3.FORWARD,Vector3.FORWARD,true) == 4 and Second.guarded_amount(10,Vector3.FORWARD,Vector3.FORWARD,true) == 3 and Second.guarded_amount(12,Vector3.FORWARD,Vector3.FORWARD,true) == 4,"guardian truncates each original incoming damage independently") and passed
	passed = expect(Second.guarded_amount(22,Vector3.RIGHT,Vector3.FORWARD,true) == 22 and Second.guarded_amount(22,Vector3.BACK,Vector3.FORWARD,true) == 22 and Second.guarded_amount(22,Vector3.UP,Vector3.FORWARD,true) == 22 and Second.guarded_amount(22,Vector3.FORWARD,Vector3.FORWARD,false) == 22 and Second.guarded_amount(22,Vector3(NAN,0,0),Vector3.FORWARD,true) == 22 and Second.guarded_amount(22,Vector3.FORWARD,Vector3(0,0,-0.5),true) == 22,"side/back/vertical/invalid and exposed guardian remain full damage") and passed
	var marker = Node3D.new()
	var ref = weakref(marker)
	var record: Dictionary = {"ref":ref,"values":[marker.get_instance_id(),marker.transform]}
	var frozen: Dictionary = Second.stored_image(record)
	marker.free()
	passed = expect(ref.get_ref() == null and Second.stored_image(record) == frozen,"stored WeakRef/data identity survives legitimate target retirement") and passed
	record["values"][1] = Transform3D(Basis.IDENTITY,Vector3.ONE)
	passed = expect(Second.stored_image(record) != frozen,"earlier stored marker data mutation is still rejected") and passed
	var witness = Second.new()
	passed = expect(not witness.current() and not witness.actor(null) and witness.shots.is_empty() and witness.key_events.is_empty(),"unbound second witness rejects foreign/stale identity") and passed
	if passed: print("PASS detached second-loop shield/value-freeze controls; not earned campaign")
	return passed

func second_pin_rejection() -> void:
	if not expect(not second_pins_match() and transport_pins_match(),"negative uses one second-only dependency mismatch; inherited pins remain valid"):
		quit(1)
		return
	var prefix: String = "user://reliquary_catalogue_exit_nursery_ossuary_second_pin_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	var suffixes: Array = ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]
	if not expect(game == null and root.get_child_count() == 0 and not ot_started and suffixes.all(func(suffix): return not FileAccess.file_exists(prefix+suffix)),"fresh detached second-only negative namespace"):
		quit(1)
		return
	var result: bool = await walk_through_ossuary_second_loop(prefix)
	var passed: bool = expect(not result and game == null and root.get_child_count() == 0 and not ot_started and suffixes.all(func(suffix): return not FileAccess.file_exists(prefix+suffix)),"actual guarded runner refused before allocation/input/profile adoption")
	if passed: print("PASS second-loop shared-runner wrong-pin pre-adoption refusal")
	quit(0 if passed else 1)
