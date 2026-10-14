extends "res://tests/test_nursery_earned_entry.gd"
func run() -> void:
	if not await walk_into_nursery(NurseryEntryMain.new()):
		await finish(1)
		return
	if not expect(nursery_entry_result(),"CONTROL SETUP: intact earned fifth boundary before mutations"):
		await finish(1)
		return
	var original=game.enemies[0]
	var hp:int=original.hp
	original.hp=hp-1
	var rejected_hp:bool=not nursery_entry_result()
	original.hp=hp
	var restored_hp:bool=nursery_entry_result()
	var health:int=game.state.checkpoint.health
	game.state.checkpoint.health=health+1
	var rejected_checkpoint:bool=not nursery_entry_result()
	game.state.checkpoint.health=health
	var restored_checkpoint:bool=nursery_entry_result()
	var e_ok:bool=game.e_ok
	game.e_ok=not e_ok
	var rejected_history:bool=not nursery_entry_result()
	game.e_ok=e_ok
	var restored_history:bool=nursery_entry_result()
	original.reparent(game)
	var rejected_parent:bool=not nursery_entry_result()
	original.reparent(game.level)
	var restored_parent:bool=nursery_entry_result()
	if not expect(rejected_hp and restored_hp and rejected_checkpoint and restored_checkpoint and rejected_history and restored_history and rejected_parent and restored_parent,"Four single-field/owner corruptions reject and restores recover exact same native boundary without extra input/physics/scene/save mutation"):
		await finish(1)
		return
	print("PASS four original Nursery boundary mutation/restoration controls; source-native only")
	await finish(0)
