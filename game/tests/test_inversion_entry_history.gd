extends SceneTree

const Exit = preload("res://tests/ossuary_finale_exit_witness.gd")
const Entry = preload("res://tests/test_inversion_earned_entry.gd")

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> bool:
	if not value: push_error(label)
	return value

func run() -> void:
	var part = Exit.new()
	var world = Node3D.new()
	var player = CharacterBody3D.new()
	var gate = Node3D.new()
	var button = Button.new()
	part.scene = world
	part.player = player
	part.cx_world_alias = world
	part.cx_player_alias = player
	part.cx_gate_alias = gate
	part.cx_button = button
	var aliases: Dictionary = {}
	for name in ["scene","player","cx_world_alias","cx_player_alias","cx_gate_alias","cx_button"]: aliases[name] = part.get(name)
	world.free()
	player.free()
	gate.free()
	var fields: Array = Exit.script_fields(part)
	var image: Dictionary = Exit.fields_image(part,fields)
	var passed: bool = check(Entry.inversion_history_same(part,fields,image,aliases),"CONTROLLED original naturally retired aliases preserve full snapshot")
	var other_world = Node3D.new()
	part.scene = other_world
	other_world.free()
	passed = check(Exit.fields_match(part,fields,image),"SETUP distinct freed scene has same canonical zero ID") and passed
	passed = check(not Entry.inversion_history_same(part,fields,image,aliases),"CONTROLLED different freed scene alias rejects") and passed
	part.scene = aliases.scene
	var other_gate = Node3D.new()
	part.cx_gate_alias = other_gate
	other_gate.free()
	passed = check(not Entry.inversion_history_same(part,fields,image,aliases),"CONTROLLED different freed gate alias rejects") and passed
	part.cx_gate_alias = aliases.cx_gate_alias
	var short_fields: Array = fields.duplicate()
	var short_image: Dictionary = image.duplicate(true)
	short_fields.erase("cx_ready")
	short_image.erase("cx_ready")
	passed = check(not Entry.inversion_history_same(part,short_fields,short_image,aliases),"CONTROLLED erased field and image cannot shrink frozen inventory") and passed
	var missing: Dictionary = aliases.duplicate()
	missing.erase("scene")
	passed = check(not Entry.inversion_history_same(part,fields,image,missing),"CONTROLLED missing raw alias rejects") and passed
	var extra: Dictionary = aliases.duplicate()
	extra["game"] = part.game
	passed = check(not Entry.inversion_history_same(part,fields,image,extra),"CONTROLLED extra raw alias rejects") and passed
	part.cx_phase = "forged"
	passed = check(not Entry.inversion_history_same(part,fields,image,aliases),"CONTROLLED changed stored history rejects") and passed
	part.cx_phase = image.cx_phase
	part.scene = null
	passed = check(not Entry.inversion_history_same(part,fields,image,aliases),"CONTROLLED null substitution rejects") and passed
	part.scene = aliases.scene
	passed = check(Entry.inversion_history_same(part,fields,image,aliases),"CONTROLLED restored exact originals preserve full snapshot") and passed
	button.free()
	if passed: print("PASS CONTROLLED Inversion complete C history/raw-alias boundary; no earned adoption or entry")
	quit(0 if passed else 1)
