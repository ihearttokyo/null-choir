extends SceneTree

const Transport = preload("res://tests/test_ossuary_transport_loop.gd")
const Exit = preload("res://tests/ossuary_finale_exit_witness.gd")

class Probe:
	extends "res://tests/ossuary_finale_exit_witness.gd"
	# Controlled callback dispatch only; actual earned adoption uses the full route.
	var live: bool = true
	var frozen: bool = true
	func current() -> bool: return live
	func prior_frozen() -> bool: return frozen
	func require(value: bool, label: String) -> bool:
		if not value:
			ok = false
			failures.append(label)
		return value

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> bool:
	if not value: push_error(label)
	return value

func run() -> void:
	var game = Transport.TransportMain.new()
	game.state.new_campaign(1)
	game.level = game.Level.new()
	game.add_child(game.level)
	var passed: bool = check(game.level.layout.load_level(5),"SETUP original Ossuary regions")
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.hud = Node2D.new()
	game.add_child(game.hud)
	game.playing = true
	game.music = null
	game.state.keys = ["blood","ivory"]
	var observer = Probe.new()
	observer.game = game
	observer.scene = game.level
	observer.player = game.player
	game.transport_witness = observer
	for spec in game.level.layout.data.encounters:
		game.state.removed.append("encounter:"+spec.id)
		observer.activated[spec.id] = [1,Vector3.ZERO,["blood","ivory"]]
	observer.removed = game.state.removed.duplicate()
	var fields: Array = Exit.script_fields(observer)
	var original: Dictionary = Exit.fields_image(observer,fields)
	for spec in game.level.layout.data.encounters:
		game.player.position = Vector3((spec.region[0]+spec.region[2])*2,0,(spec.region[1]+spec.region[3])*2)
		var state: Dictionary = game.state.to_dict().duplicate(true)
		var message: Array = [game.message,game.message_time]
		game._process(0.0)
		passed = check(observer.ok and Exit.fields_match(observer,fields,original) and game.state.to_dict() == state and [game.message,game.message_time] == message,"CONTROLLED real render repeats earned encounter without effects: "+spec.id) and passed
	# Keep the real production removed markers so every negative remains a no-op.
	for mutation in ["earned","history","current","dispatch"]:
		observer.ok = true
		observer.failures.clear()
		if mutation == "earned": observer.removed = []
		if mutation == "history": observer.frozen = false
		if mutation == "current": observer.live = false
		if mutation == "dispatch": game.transport_witness = null
		if mutation == "dispatch": observer.before_encounter(game.level.layout.data.encounters[0].id)
		else: game._process(0.0)
		passed = check(not observer.ok,"CONTROLLED invalid repeated callback rejects: "+mutation) and passed
		observer.removed = game.state.removed.duplicate()
		observer.frozen = true
		observer.live = true
		game.transport_witness = observer
	observer.ok = true
	observer.failures.clear()
	observer.before_encounter(game.level.layout.data.encounters[0].id)
	passed = check(not observer.ok,"CONTROLLED forged direct callback rejects despite earned marker") and passed
	game.transport_witness = null
	game.free()
	if passed: print("PASS CONTROLLED C repeated original encounter callbacks through real Main render; forged/unearned/history/current/dispatch reject; not earned campaign")
	quit(0 if passed else 1)
