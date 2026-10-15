extends SceneTree
const Preparation = preload("res://tests/ossuary_finale_witness.gd")
class Holder:
	extends RefCounted
	var slot: Variant
	var nested: Dictionary = {"values":[1,2]}
class Host:
	extends RefCounted
	var prefix_bookkeeping_retired: bool = true
var passed: bool = true
func check(value: bool, label: String) -> void:
	if not value:
		passed = false
		push_error("PREPARATION_STRICT_HISTORY_CONTROL "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host = Host.new()
	var w = Preparation.new()
	w.game = host
	var gate = Node3D.new()
	var holder = Holder.new()
	holder.slot = weakref(gate)
	var original_ref = holder.slot
	w.gate_alias = gate
	w.freeze_owner(holder,["slot","nested"])
	var image: Dictionary = w.histories[0].image.duplicate(true)
	check(w.prior_frozen(),"actual WeakRef-form gate history initially matches")
	gate.free()
	check(original_ref.get_ref() == null and w.prior_frozen(),"native target retirement leaves exact WeakRef identity/history intact")
	holder.slot = null
	check(not w.prior_frozen(),"null substitution rejected")
	holder.slot = weakref(host)
	check(not w.prior_frozen(),"different WeakRef substitution rejected")
	holder.slot = original_ref
	holder.nested.values.append(3)
	check(not w.prior_frozen(),"nested mutation rejected from an otherwise passing baseline")
	holder.nested.values.pop_back()
	check(w.prior_frozen() and w.histories[0].image == image,"original image immutable across checks")
	var raw = Node3D.new()
	var raw_holder = Holder.new()
	raw_holder.slot = raw
	var strict = Preparation.new()
	strict.game = host
	strict.gate_alias = raw
	strict.phase = "gate_open"
	strict.gate_calls = 1
	strict.freeze_owner(raw_holder,["slot","nested"])
	check(strict.prior_frozen(),"raw original matches before retirement")
	raw.free()
	check(not strict.prior_frozen(),"unneeded raw-gate retirement exception is absent even in gate-open phase")
	var unrelated = Node3D.new()
	var unrelated_holder = Holder.new()
	unrelated_holder.slot = unrelated
	w.freeze_owner(unrelated_holder,["slot","nested"])
	check(w.prior_frozen(),"unrelated live raw object initially matches")
	unrelated.free()
	check(not w.prior_frozen(),"unrelated raw retirement remains strict")
	if passed: print("PASS CONTROLLED strict WeakRef history/native retirement; not earned gate acceptance")
	quit(0 if passed else 1)
