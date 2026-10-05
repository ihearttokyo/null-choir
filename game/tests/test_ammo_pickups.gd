extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game = load("res://scripts/main.gd").new()
	game.settings_path = "user://overhaul_ammo_unused.json"
	root.add_child(game)
	game.start_campaign(1)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	game.state.ammo[1] = 180
	game.collect_pickup("entry_ammo")
	if not expect(game.state.ammo[1] == 180 and not "entry_ammo" in game.state.removed and game.level.markers.has("entry_ammo"),"Full ammunition pickup must remain available without changing inventory"): return
	game.state.ammo[1] = 179
	game.collect_pickup("entry_ammo")
	if not expect(game.state.ammo[1] == 180 and "entry_ammo" in game.state.removed,"Partial recovery grants only available capacity and removes exactly once"): return
	game.collect_pickup("entry_ammo")
	if not expect(game.state.ammo[1] == 180,"Collected ammunition cannot be granted twice"): return
	game.restart_level()
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	game.state.ammo[1] = 210
	game.state.mark_checkpoint("legacy",game.player.position)
	game.collect_pickup("entry_ammo")
	if not expect(game.state.ammo[1] == 210 and not "entry_ammo" in game.state.removed,"Valid legacy over-cap ammunition is never truncated or consumed by collection"): return
	var saved = game.state.to_dict()
	if not expect(game.state.from_dict(JSON.parse_string(JSON.stringify(saved))) and game.state.ammo[1] == 210,"Legacy resources survive integral JSON float normalization"): return
	game.state.ammo[1] = 0
	game.state.restore_checkpoint()
	if not expect(game.state.ammo[1] == 210,"Checkpoint restoration preserves legacy resources exactly"): return
	game.level.layout.data.pickups.append({"id":"full_new_weapon","kind":"weapon","weapon":2.0,"amount":16.0})
	game.state.ammo[2] = 32
	game.collect_pickup("full_new_weapon")
	if not expect(2 in game.state.owned_weapons and game.state.weapon == 2 and game.state.ammo[2] == 32 and "full_new_weapon" in game.state.removed,"New weapon ownership is useful even when its stored ammunition is already full"): return
	game.level.layout.data.pickups.append({"id":"full_owned_weapon","kind":"weapon","weapon":2.0,"amount":16.0})
	game.collect_pickup("full_owned_weapon")
	if not expect(not "full_owned_weapon" in game.state.removed and game.state.ammo[2] == 32,"Owned full weapon packs remain available just like ammunition"): return
	game.show_title()
	game.free()
	paused = false
	print("PASS native ammunition capacity, retained full pickups, one-shot partial grants and legacy checkpoint/JSON preservation")
	quit()

func expect(condition: bool, text: String) -> bool:
	if not condition:
		push_error(text)
		quit(1)
	return condition
