extends "res://tests/test_reliquary_halo_feasibility.gd"

const HH_CARRY = {"health":76,"armor":190,"ammo":[0,148,32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
const HH_FIELDS = ["h_enabled","h_ok","h_shots","h_rivets","h_health_gain","h_armor_gain","h_health_loss","h_absorbed","h_consumed","h_removed","h_activation","h_activated","h_hurts","h_deaths","h_finishes"]

func run() -> void:
	if not expect(has_method("walk_through_halo"),"CONTRACT RED missing actual nonquitting earned Halo helper"):
		await finish(1)
		return
	prefix = "user://reliquary_halo_handoff_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	var observer = FourthMain.new()
	var main_id: int = observer.get_instance_id()
	var campaign_id: int = observer.state.get_instance_id()
	if not await call("walk_through_halo",observer,prefix):
		await finish(1)
		return
	if not expect(game == observer and game.get_instance_id() == main_id and game.state.get_instance_id() == campaign_id and main_id == r_main_id and campaign_id == r_campaign_id and game.progress_path == prefix+"_campaign.json" and game.settings_path == prefix+"_preferences.json" and game.progress_path == r_profile and game.h_enabled and game.prefix_bookkeeping_retired,"Same supplied Main/Campaign/isolated profiles remain alive after unchanged prefix and full accepted Halo") or not halo_result():
		await finish(1)
		return
	if not expect(game.budget() == HH_CARRY and game.h_resources() == HH_CARRY and game.h_shots.size() == 32 and H_IDS.all(func(id): return game.h_finishes.get(id,"") == "player"),"Independent final76HP/190armor/148pistol/32shells versus production and observed finite ledger;32 real shots/eight Player finishes"):
		await finish(1)
		return
	var fields: Array = h_fields+HH_FIELDS
	var witness: Dictionary = observer_witness(fields)
	var current: Dictionary = game.state.to_dict().duplicate(true)
	var point: Vector3 = route_player.position
	var play_time: float = route_player.active_play_time
	var ages: Dictionary = {}
	for actor in game.enemies: ages[actor.id] = actor.age
	var frame: int = Engine.get_physics_frames()
	var ticks: int = game.h_ticks
	var wall: int = Time.get_ticks_usec()
	for tick in range(6):
		await physics_frame
		await process_frame
		if not expect(Engine.get_physics_frames()-frame <= 30 and Time.get_ticks_usec()-wall <= 3000000,"Post-helper idle bounded to30 native frames/three wall seconds") or not live_route():
			await finish(1)
			return
		var expected: Dictionary = current.duplicate(true)
		expected.position = [route_player.position.x,route_player.position.y,route_player.position.z]
		if not expect(game == observer and game.get_instance_id() == main_id and game.state.get_instance_id() == campaign_id and not game.is_queued_for_deletion() and not route_level.is_queued_for_deletion() and not route_player.is_queued_for_deletion() and game.progress_path == prefix+"_campaign.json" and game.settings_path == prefix+"_preferences.json" and observer_witness(fields) == witness and game.state.to_dict() == expected and game.budget() == HH_CARRY and game.h_resources() == HH_CARRY and route_player.position.x == point.x and route_player.position.z == point.z and absf(route_player.position.y-point.y) <= 0.05,"Live same supplied boundary, original31 and frozen historical/combat witnesses survive automatic idle without disposal, resources, grants or save rewrite"):
			await finish(1)
			return
	if not expect(Engine.get_physics_frames()-frame >= 6 and game.h_ticks > ticks and route_player.active_play_time > play_time and game.enemies.all(func(actor): return actor.age > ages[actor.id]),"Actual automatic Main/Player/all31 actor clocks advance after helper returns without quitting"):
		await finish(1)
		return
	print("PASS nonquitting earned Halo handoff plus bounded native automatic idle only; no synthetic kills, further encounters, physical controls, graphics/audio/performance, packed app or full campaign acceptance")
	await finish(0)
