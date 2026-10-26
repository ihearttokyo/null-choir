extends "res://tests/test_ossuary_story.gd"

# Controlled arithmetic inputs only: none of these ticks are earned telemetry.
# Functions/constants only, preserving the inherited fixture field inventory.
const PISTOL_SUPPLIES = ["ossuary_second_approach_rivets","ossuary_second_approach_shells","ossuary_second_return_rivets","ossuary_second_return_health"]

class PistolHistoryOwner:
	extends RefCounted
	var prefix_bookkeeping_retired: bool = true

class SupplyLayout:
	extends RefCounted
	func world_position(_cell: Array) -> Vector3: return Vector3.ZERO

class SupplyBranch:
	extends "res://tests/ossuary_story_witness.gd"
	var terminal: Array = []
	func route(_cells: Array) -> bool: return true
	func story_input() -> bool: return true
	func validate() -> bool: return true
	func require(value: bool, label: String) -> bool:
		if label.begins_with("Story spur returns to junction"):
			terminal.append(value)
			return false # Stop before the actual method's EARNED print.
		return value

func pistol_budget(rounds: int, health: int = 92, armor: int = 196) -> Dictionary:
	return {"health":health,"armor":armor,"ammo":[0,rounds,32,120,0,0],"owned_weapons":[0,1,2,3],"weapon":1}

func pistol_pickup(id: String, tick: int, before: int, after: int) -> Array:
	# No synthetic combat transitions: non-pistol supplies are capped no-ops.
	return [id,tick,pistol_budget(before,100,200),pistol_budget(after,100,200),before != after]

func pistol_trace(before_return: int, after_return: int) -> Dictionary:
	var shots: Array = []
	for index in range(before_return+after_return):
		shots.append([13*(index+1),float(index+1)*0.21,1,0.21])
	var entry: int = 180-before_return
	var replenished: int = mini(180,entry+45)
	var pickups: Array = [pistol_pickup(PISTOL_SUPPLIES[0],1,165,180),pistol_pickup(PISTOL_SUPPLIES[1],2,180,180),pistol_pickup(PISTOL_SUPPLIES[2],13*before_return+1,entry,replenished),pistol_pickup(PISTOL_SUPPLIES[3],13*before_return+2,replenished,replenished)]
	return {"shots":shots,"pickups":pickups,"ledger":pistol_budget(replenished-after_return)}

func pistol_replay(trace: Dictionary, live: Dictionary = {}) -> Dictionary:
	var probe = Story.new()
	return probe.call("verified_pistol_carry",trace.shots,trace.pickups,trace.ledger,trace.ledger.duplicate(true) if live.is_empty() else live)

func pistol_case(label: String, trace: Dictionary, expected: Dictionary, live: Dictionary = {}) -> bool:
	var before: Dictionary = trace.duplicate(true)
	var live_before: Dictionary = live.duplicate(true)
	var actual: Dictionary = pistol_replay(trace,live)
	return expect(actual == expected and trace == before and live == live_before,"CONTROLLED pistol "+label+"; replay owns no input mutations")

func pistol_binding_control() -> bool:
	var segment = QuietStory.new()
	var accepted: bool = segment.adopt_after(self,null)
	return expect(not accepted and not segment.ok and segment.fixture == null and segment.previous == null and segment.game == null,"CONTROLLED direct forged adoption refuses BEFORE fixture/previous/game binding")

func pistol_detachment_control() -> bool:
	var trace: Dictionary = pistol_trace(48,11)
	var live: Dictionary = trace.ledger.duplicate(true)
	var ledger_before: Dictionary = trace.ledger.duplicate(true)
	var live_before: Dictionary = live.duplicate(true)
	var actual: Dictionary = pistol_replay(trace,live)
	if not expect(actual == pistol_budget(166),"CONTROLLED detached carry begins at independently verified166"): return false
	actual.ammo[1] = 0
	return expect(trace.ledger == ledger_before and live == live_before,"CONTROLLED returned ammo array detaches from BOTH input ledger and live vector")

func pistol_hold_control() -> bool:
	# Only the actual stored-value component is exercised. No current-map,
	# dispatch, native acceptance, adoption, actors or earned history is claimed.
	var accepted = Second.new()
	accepted.previous = Witness.new()
	accepted.ledger = pistol_budget(166)
	accepted.damage = [["CONTROLLED",{"nested":[1,2]}]]
	var segment = QuietStory.new()
	segment.previous = accepted
	segment.game = PistolHistoryOwner.new()
	segment.fixture = self
	segment.previous_frozen = Second.fields_image(accepted,Second.script_fields(accepted))
	segment.first_frozen = Second.fields_image(accepted.previous,Second.script_fields(accepted.previous))
	segment.set("entry_carry",pistol_budget(166))
	var passed: bool = expect(segment.prior_frozen(),"CONTROLLED stored-value component accepts detached entry carry matching previous_frozen.ledger; NOT native accepted history")
	segment.get("entry_carry").ammo[1] -= 1
	passed = expect(not segment.prior_frozen(),"CONTROLLED stored-value component rejects entry ammo mutation") and passed
	segment.get("entry_carry").ammo[1] += 1
	passed = expect(segment.prior_frozen(),"CONTROLLED stored-value component restores exact entry carry") and passed
	accepted.damage[0][1].nested.append(3)
	passed = expect(not segment.prior_frozen(),"CONTROLLED entry carry does not waive older nested history mutation") and passed
	accepted.damage[0][1].nested.pop_back()
	return expect(segment.prior_frozen(),"CONTROLLED stored-value component restores original full images") and passed

func pistol_supply_branch(entry: int, result: int, retired: bool, corrupt: bool, terminal: Array) -> bool:
	# Pure shims reach the actual Story terminal expression, never adoption,
	# native input, Main, earned history or a successful EARNED publication.
	var branch = SupplyBranch.new()
	branch.entry_carry = pistol_budget(entry)
	branch.ledger = pistol_budget(result)
	branch.entry_supplies = {Story.STORY_SUPPLIES[0]:retired,Story.STORY_SUPPLIES[1]:true}
	if not retired:
		branch.pickup_attempts[Story.STORY_SUPPLIES[0]] = 1
		branch.consumed[Story.STORY_SUPPLIES[0]] = 1
		branch.pickups = [[Story.STORY_SUPPLIES[0],1,{}, {},true]]
	elif corrupt: branch.pickup_attempts[Story.STORY_SUPPLIES[0]] = 1
	var target = RefCounted.new()
	branch.markers[Story.STORY_SUPPLIES[0]] = weakref(target)
	target = null
	branch.waypoints = Story.OUTWARD+Story.HOMEWARD
	branch.scene = {"layout":SupplyLayout.new()}
	branch.player = {"position":Vector3.UP*0.04,"rotation":Vector3.ZERO,"camera":{"rotation":Vector3.ZERO}}
	branch.game = {"state":{"position":branch.player.position,"yaw":0.0,"pitch":0.0},"Enemy":preload("res://scripts/enemy.gd")}
	var returned: bool = await branch.story_route()
	return expect(not returned and branch.terminal == terminal,"CONTROLLED actual Story supply condition "+str([entry,result,retired,corrupt])+"; no Main/native history/EARNED print")

func run() -> void:
	var passed: bool = pistol_binding_control()
	var probe = Story.new()
	if not probe.has_method("verified_pistol_carry"):
		passed = expect(Story.STORY_CARRY.ammo[1] == 166,"CONTROLLED current legacy literal rejects39 validated166") and passed
		expect(false,"CONTROLLED independent pistol replay API absent; semantic expected RED")
		quit(1)
		return
	passed = story_controls() and passed
	passed = pistol_detachment_control() and passed
	passed = pistol_hold_control() and passed
	passed = pistol_case("synthetic100shot125 boundary",pistol_trace(89,11),pistol_budget(125)) and passed
	for row in [[125,170,false,false,[true]],[135,180,false,false,[true]],[125,125,true,false,[true]],[125,169,false,false,[false]],[125,125,true,true,[]]]:
		passed = await pistol_supply_branch(row[0],row[1],row[2],row[3],row[4]) and passed
	for pair in [[45,11,169],[48,11,166]]:
		var trace: Dictionary = pistol_trace(pair[0],pair[1])
		passed = pistol_case("positive synthetic "+str(pair[2]),trace,pistol_budget(pair[2])) and passed
	var original: Dictionary = pistol_trace(48,11)
	var changed: Dictionary = original.duplicate(true)
	changed.ledger.ammo[1] += 1
	passed = pistol_case("coordinated ledger and live pistol mutation with unchanged events",changed,{}) and passed
	changed = original.duplicate(true)
	var live: Dictionary = changed.ledger.duplicate(true)
	live.ammo[1] += 1
	passed = pistol_case("live-only mutation",changed,{},live) and passed
	for operation in ["drop","duplicate","reorder","add"]:
		changed = original.duplicate(true)
		if operation == "drop": changed.shots.remove_at(0)
		elif operation == "duplicate": changed.shots.insert(1,changed.shots[0].duplicate())
		elif operation == "reorder":
			var first = changed.shots[0]
			changed.shots[0] = changed.shots[1]
			changed.shots[1] = first
		else: changed.shots.append([13*60,12.6,1,0.21])
		passed = pistol_case(operation+" shot",changed,{}) and passed
	for operation in ["drop","duplicate","reorder","unknown","amount","cap","before","after","granted"]:
		changed = original.duplicate(true)
		if operation == "drop": changed.pickups.remove_at(1)
		elif operation == "duplicate": changed.pickups.insert(1,changed.pickups[0].duplicate(true))
		elif operation == "reorder":
			var first = changed.pickups[0]
			changed.pickups[0] = changed.pickups[1]
			changed.pickups[1] = first
		elif operation == "unknown": changed.pickups[1][0] = "CONTROLLED_unknown_supply"
		elif operation == "amount": changed.pickups[2][3].ammo[1] -= 1
		elif operation == "cap": changed.pickups[0][3].ammo[1] = 181
		elif operation == "before": changed.pickups[2][2].ammo[1] += 1
		elif operation == "after": changed.pickups[1][3].ammo[1] -= 1
		else: changed.pickups[2][4] = false
		passed = pistol_case(operation+" pickup",changed,{}) and passed
	# A full-capacity return scan is retained once; a later same-tick shot must
	# debit first, making the next original return scan effective and retiring it.
	var ordering: Dictionary = {"shots":[[13,0.21,1,0.21]],"pickups":[pistol_pickup(PISTOL_SUPPLIES[0],1,165,180),pistol_pickup(PISTOL_SUPPLIES[2],2,180,180),pistol_pickup(PISTOL_SUPPLIES[1],3,180,180),pistol_pickup(PISTOL_SUPPLIES[3],4,180,180),pistol_pickup(PISTOL_SUPPLIES[2],13,179,180)],"ledger":pistol_budget(180)}
	passed = pistol_case("capped no-op then shot then effective; same-tick shot first",ordering,pistol_budget(180)) and passed
	changed = ordering.duplicate(true)
	changed.pickups[-1] = pistol_pickup(PISTOL_SUPPLIES[2],13,180,180)
	passed = pistol_case("same-tick pickup-first counterexample",changed,{}) and passed
	changed = ordering.duplicate(true)
	changed.pickups.append(pistol_pickup(PISTOL_SUPPLIES[2],14,180,180))
	passed = pistol_case("repeat retired effective supply",changed,{}) and passed
	for field in ["health","armor","ammo","owned_weapons","weapon"]:
		changed = original.duplicate(true)
		if field == "ammo": changed.ledger.ammo[2] -= 1
		elif field == "owned_weapons": changed.ledger.owned_weapons.pop_back()
		else: changed.ledger[field] -= 1
		passed = pistol_case("other fixed field drift "+field,changed,{}) and passed
	# Reject malformed event schemas and non-finite scalar history, not merely
	# final arithmetic discrepancies.
	for operation in ["short_shot","weapon","nan_time","short_pickup"]:
		changed = original.duplicate(true)
		if operation == "short_shot": changed.shots[0].pop_back()
		elif operation == "weapon": changed.shots[0][2] = 2
		elif operation == "nan_time": changed.shots[0][1] = NAN
		else: changed.pickups[0].pop_back()
		# NaN cannot compare equal to its own deep snapshot; no mutation claim
		# uses equality for this deliberately malformed input.
		if operation == "nan_time": passed = expect(pistol_replay(changed).is_empty(),"CONTROLLED pistol rejects nonfinite shot time") and passed
		else: passed = pistol_case(operation,changed,{}) and passed
	passed = expect(game == null and root.get_child_count() == 0 and not ot_started,"CONTROLLED pistol creates no world, actors, campaign or save") and passed
	if passed: print("PASS CONTROLLED Story pistol replay and pre-binding refusal; synthetic arithmetic, not earned Second/Story/C or gameplay acceptance")
	quit(0 if passed else 1)
