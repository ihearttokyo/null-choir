extends SceneTree
class QuietMain:
	extends "res://scripts/main.gd"
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
class ProbePlayer:
	extends CharacterBody3D
	var calls: int = 0
	var physics: bool = false
	var callback_tick: int = -1
	func _physics_process(_delta: float) -> void:
		callback_tick = Engine.get_physics_frames()
	func fire() -> bool:
		calls += 1
		physics = Engine.is_in_physics_frame()
		return physics and callback_tick == Engine.get_physics_frames()
var game
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game = QuietMain.new() # No settings/audio/save writes.
	root.add_child(game)
	var current = ProbePlayer.new()
	current.process_physics_priority = -100
	root.add_child(current)
	game.player = current
	if not expect(game.has_method("_verify_fire_tick"),"ActualGPU export fire needs a physics-owned callback, not await-signal timing"):
		current.free(); game.free(); quit(1); return
	var fired: bool = await game.call("_verify_fire_tick")
	var ok: bool = expect(fired and current.calls == 1 and current.physics,"Export fire invokes the current observer once in actual physics callback")
	var replacement = ProbePlayer.new()
	root.add_child(replacement)
	game.call("_verify_fire_tick")
	game.player = replacement
	await physics_frame
	await physics_frame
	ok = expect(current.calls == 1 and replacement.calls == 0,"Replacement cannot fire a retained stale observer") and ok
	game.player = null
	var missing: bool = await game.call("_verify_fire_tick")
	ok = expect(not missing,"Missing current player returns false without firing") and ok
	current.free(); replacement.free(); game.free()
	if ok: print("PASS physics-owned export fire callback; no GPU/app/quality claim")
	quit(0 if ok else 1)
func expect(condition: bool,detail: String) -> bool:
	if not condition: push_error(detail)
	return condition
