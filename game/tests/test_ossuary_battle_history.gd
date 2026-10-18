extends SceneTree
const Battle = preload("res://tests/ossuary_finale_battle_witness.gd")
const Preparation = preload("res://tests/ossuary_finale_witness.gd")
class Host:
	extends RefCounted
	var prefix_bookkeeping_retired: bool = true
class Owner:
	extends RefCounted
	var payload: Array = [{"nested":[1,2],"point":Vector3.ONE}]
func check(value: bool, label: String) -> bool:
	if not value: push_error("BATTLE_HISTORY_UNIT "+label)
	return value
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var completed = Preparation.new()
	completed.game = Host.new()
	for n in range(5):
		var record_owner = Owner.new()
		completed.histories.append({"owner":record_owner,"fields":["payload"],"image":Battle.fields_image(record_owner,["payload"])})
	var gate = Node3D.new()
	completed.gate_alias = gate
	completed.damage = [["retained",{"nested":[1,2]}]]
	gate.free()
	var original_alias: Variant = completed.gate_alias
	var segment = Battle.new()
	var passed: bool = check(segment.freeze_preparation(completed) and segment.prior_frozen(),"actual Preparation five-owner canonical history baseline")
	var image: Dictionary = segment.previous_frozen.duplicate(true)
	var row: Dictionary = completed.histories[0]
	var owner = row.owner
	completed.gate_alias = null
	passed = check(not segment.preparation_fields_unchanged(),"null gate alias refused") and passed
	var other_gate = Node3D.new()
	var other_alias: Variant = other_gate
	other_gate.free()
	completed.gate_alias = other_alias
	passed = check(Battle.fields_match(completed,segment.preparation_fields,image) and not segment.preparation_fields_unchanged(),"different-freed alias refuses despite canonical ID0 collapse") and passed
	completed.gate_alias = original_alias
	completed.damage[0][1].nested.append(3)
	passed = check(not segment.preparation_fields_unchanged(),"non-history stored field mutation") and passed
	completed.damage[0][1].nested.pop_back()
	owner.payload[0].nested.append(3)
	passed = check(segment.preparation_fields_unchanged() and not segment.prior_frozen(),"older live owner checked independently of its saved image") and passed
	owner.payload[0].nested.pop_back()
	row.image.payload[0].nested.append(3)
	passed = check(not segment.preparation_fields_unchanged(),"stored canonical owner image mutation") and passed
	row.image.payload[0].nested.pop_back()
	row.fields.append("unexpected")
	passed = check(not segment.preparation_fields_unchanged(),"owner field inventory mutation") and passed
	row.fields.pop_back()
	row.owner = Owner.new()
	passed = check(not segment.preparation_fields_unchanged(),"foreign live owner with matching payload") and passed
	row.owner = null
	passed = check(not segment.preparation_fields_unchanged(),"null owner") and passed
	row.erase("owner")
	passed = check(not segment.preparation_fields_unchanged(),"missing owner metadata") and passed
	row.owner = owner
	row.extra = 1
	passed = check(not segment.preparation_fields_unchanged(),"unexpected metadata retained rather than filtered out") and passed
	row.erase("extra")
	var prior_fields = row.fields
	row.fields = null
	passed = check(not segment.preparation_fields_unchanged(),"malformed field metadata") and passed
	row.fields = prior_fields
	var prior_image = row.image
	row.image = []
	passed = check(not segment.preparation_fields_unchanged(),"malformed image metadata") and passed
	row.image = prior_image
	var last_row: Dictionary = completed.histories.pop_back()
	passed = check(not segment.preparation_fields_unchanged(),"history roster shrinks") and passed
	# Reject a same-size replacement before restoring the retained row.
	var last_owner = Owner.new()
	completed.histories.append({"owner":last_owner,"fields":["payload"],"image":Battle.fields_image(last_owner,["payload"])})
	passed = check(not segment.preparation_fields_unchanged(),"same-size replacement history owner") and passed
	completed.histories.pop_back()
	completed.histories.append(last_row)
	segment.previous_frozen.histories[0].image.payload[0].nested.append(3)
	passed = check(not segment.preparation_fields_unchanged(),"frozen metadata image mutation") and passed
	segment.previous_frozen.histories[0].image.payload[0].nested.pop_back()
	passed = check(segment.previous_frozen == image and segment.prior_frozen() and is_same(completed.gate_alias,original_alias),"all original fields, participant aliases and stored images restored unchanged") and passed
	if passed: print("PASS controlled Battle history mutation guards; not earned campaign")
	quit(0 if passed else 1)
