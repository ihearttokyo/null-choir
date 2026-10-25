extends SceneTree

const Exit = preload("res://tests/ossuary_finale_exit_witness.gd")

class Owner:
	extends RefCounted
	var scene: Variant
	var player: Variant
	var payload: Array = [{"nested":[1,2],"point":Vector3.ONE}]

var passed: bool = true
var checks: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		passed = false
		push_error("C_HISTORY_UNIT "+label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var owner = Owner.new()
	var scene = Node3D.new()
	var player = Node3D.new()
	owner.scene = scene
	owner.player = player
	var fields: Array = ["payload","player","scene"]
	var frozen: Dictionary = Exit.fields_image(owner,fields)
	var original: Dictionary = frozen.duplicate(true)
	var aliases: Dictionary = {"scene":[scene,scene.get_instance_id()],"player":[player,player.get_instance_id()]}
	check(Exit.script_fields(owner) == fields,"controlled owner has exact independent three-field inventory")
	check(Exit.matches(owner,fields,frozen,aliases,false) and Exit.matches(owner,fields,frozen,aliases,true),"exact live original aliases pass in either retirement phase")
	check(not Exit.matches(null,fields,frozen,aliases,true),"missing owner rejects")
	owner.payload[0].nested.append(3)
	check(not Exit.matches(owner,fields,frozen,aliases,true),"live nested payload mutation rejects")
	owner.payload[0].nested.pop_back()
	check(Exit.matches(owner,fields,frozen,aliases,false),"restored payload returns to passing baseline")
	check(not Exit.matches(owner,["payload","player"],frozen,aliases,true),"missing expected field rejects")
	check(not Exit.matches(owner,["payload","player","player"],frozen,aliases,true),"duplicate field rejects")
	check(not Exit.matches(owner,["payload","player","absent"],frozen,aliases,true),"foreign owner field rejects")
	var extra: Dictionary = frozen.duplicate(true)
	extra.unexpected = 1
	check(not Exit.matches(owner,fields,extra,aliases,true),"unexpected frozen-image field rejects")
	var bad: Dictionary = aliases.duplicate(true)
	bad.scene[1] += 1
	check(not Exit.matches(owner,fields,frozen,bad,true),"wrong original instance ID rejects")
	bad = aliases.duplicate(true)
	bad.scene[0] = null
	check(not Exit.matches(owner,fields,frozen,bad,true),"null alias metadata rejects")
	bad = aliases.duplicate(true)
	bad.payload = bad.scene
	bad.erase("scene")
	check(not Exit.matches(owner,fields,frozen,bad,true),"only explicit world alias names may be projected")
	var original_scene: Variant = owner.scene
	owner.scene = null
	check(not Exit.matches(owner,fields,frozen,aliases,true),"null owner alias cannot impersonate original")
	owner.scene = original_scene
	check(Exit.matches(owner,fields,frozen,aliases,false),"all live substitutions restore exact original acceptance")
	scene.free()
	check(not Exit.matches(owner,fields,frozen,aliases,false),"native scene retirement rejects before verified exit")
	check(Exit.matches(owner,fields,frozen,aliases,true),"verified exit projects only exact retired scene, retaining live player")
	var other = Node3D.new()
	var other_dead: Variant = other
	other.free()
	owner.scene = other_dead
	check(not Exit.matches(owner,fields,frozen,aliases,true),"different freed object cannot impersonate original retired scene")
	owner.scene = original_scene
	bad = aliases.duplicate(true)
	bad.scene[1] += 1
	check(not Exit.matches(owner,fields,frozen,bad,true),"retired alias still requires immutable original ID")
	check(Exit.matches(owner,fields,frozen,aliases,true),"restored exact dead alias remains accepted")
	player.free()
	check(not Exit.matches(owner,fields,frozen,aliases,false) and Exit.matches(owner,fields,frozen,aliases,true),"both exact retired aliases require verified exit")
	check(not Exit.matches(owner,fields,frozen,{},true),"verified exit does not project unnamed retired fields")
	owner.payload[0].nested.append(3)
	check(not Exit.matches(owner,fields,frozen,aliases,true),"retirement never waives nested non-world data")
	owner.payload[0].nested.pop_back()
	check(Exit.matches(owner,fields,frozen,aliases,true) and frozen == original,"restored original passes with immutable deep image")
	check(root.get_child_count() == 0,"controlled unit allocates no scene tree, campaign, actors, resources or saves")
	if passed: print("PASS CONTROLLED C retirement/history projection ",checks," checks; not earned exit, Inversion, gameplay, GPU or release acceptance")
	quit(0 if passed else 1)
