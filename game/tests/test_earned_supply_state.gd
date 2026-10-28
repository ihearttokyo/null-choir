extends SceneTree
## Prepared future fixture, UNRUN until independently reviewed and root-granted.
const Supply = preload("res://scripts/earned_supplies.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Layout = preload("res://scripts/level_data.gd")
const Preferences = preload("res://scripts/preferences.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, name: String) -> bool:
	checks+=1
	if not ok:
		failures+=1
		push_error("Earned supply: "+name)
	return ok

func campaign(index: int) -> Campaign:
	var value = Campaign.new()
	value.new_campaign(1)
	value.level_index=index
	value._label_floor()
	value._reset_earned_supply()
	value.mark_checkpoint("entry",Vector3.ZERO)
	return value

func _run() -> void:
	var count: int = 0
	for index in range(8):
		var layout = Layout.new()
		if not check(layout.load_level(index),"load chapter"): quit(1);return
		var content: Dictionary = Supply.chapter(layout)
		if not check(not content.is_empty(),"exact registry available"): quit(1);return
		count+=content.legacy_pickups.size()
		check(layout.data.pickups.is_empty(),"all old floor supplies including armor removed")
		check(content.stations.size()==4,"four finite reservoirs")
		var baseline = campaign(index)
		var document: Dictionary = baseline.to_dict()
		check(Campaign.new().from_dict(document),"all3 modern envelopes roundtrip")
		for field in ["current","checkpoint","level_start"]:
			var bad: Dictionary = document.duplicate(true)
			var envelope: Dictionary = bad if field=="current" else bad[field]
			envelope.earned_supply["foreign"]=true
			var before: Dictionary = baseline.to_dict()
			check(not baseline.from_dict(bad),"reject malformed "+field)
			check(baseline.to_dict()==before,"atomic no live mutation "+field)
		var grant: Dictionary = {}
		for row in content.grants:
			if row.kind=="ammo" and int(row.weapon)==1:
				grant=row;break
		if not check(not grant.is_empty(),"authored ordinary Rivet carrier"): quit(1);return
		# Legacy absence is sole migration branch: dead/uncollected becomes finite.
		var old: Dictionary = document.duplicate(true)
		for envelope in [old,old.checkpoint,old.level_start]: envelope.erase("earned_supply")
		old.removed.append(grant.carrier)
		var recovered = Campaign.new()
		if check(recovered.from_dict(old),"legacy dead carrier materializes once"):
			var modern: Dictionary = recovered.to_dict()
			check(Campaign.new().from_dict(modern),"resave idempotent")
			check(Supply.migrate(modern,layout,1)==modern.earned_supply,"no second materialization")
			var same: Dictionary = Supply.defeated(recovered._resources(),layout,1,grant.carrier,layout.world_position(grant.recovery_cell))
			check(same==recovered.earned_supply,"repeated death finite")
			var pending: Dictionary = {}
			for row in recovered.earned_supply.loot_drops:
				if row.grant_id==grant.id: pending=row
			if check(not pending.is_empty(),"sole pending reward retained"):
				var snapshot: Dictionary = recovered._resources()
				snapshot.ammo[1]=178
				# Existing baseline grants are >=10. Preserve exact partial remainder.
				var first: Dictionary = Supply.collect(snapshot,layout,1,grant.id)
				if check(not first.is_empty(),"partial transfer accepted"):
					check(first.ammo[1]==180,"capacity no overflow")
					var left: int = 0
					for row in first.earned_supply.loot_drops:
						if row.grant_id==grant.id: left=int(row.remaining)
					check(left==int(pending.remaining)-2,"exact remainder")
					check(Supply.collect(first,layout,1,grant.id).is_empty(),"full cap leaves remainder")
					first.ammo[1]-=3
					var second: Dictionary = Supply.collect(first,layout,1,grant.id)
					check(not second.is_empty() and second.ammo[1]==180,"spend then transfer3")
		# Collected exact alias may preclaim a still-living new carrier, but
		# arbitrary removals and absent alias links never get this exception.
		var legacy: Dictionary = document.duplicate(true)
		for envelope in [legacy,legacy.checkpoint,legacy.level_start]: envelope.erase("earned_supply")
		legacy.removed.append(grant.legacy_alias)
		var linked = Campaign.new()
		check(linked.from_dict(legacy),"legacy living-carrier exact preclaim")
		check(grant.id in linked.earned_supply.loot_claimed,"exact linked entitlement claimed")
		var unknown: Dictionary = document.duplicate(true)
		unknown.removed.append("loot:forged")
		check(not Campaign.new().from_dict(unknown),"no prefix removal bypass")
		# Exact health tombstone consumes its historical entitlement, no refill.
		var station: Dictionary = content.stations[0]
		var alias: String = station.aliases[0]
		var old_units: int = 0
		for row in content.legacy_pickups:
			if row.id==alias: old_units=int(row.amount)
		var health_old: Dictionary = document.duplicate(true)
		for envelope in [health_old,health_old.checkpoint,health_old.level_start]: envelope.erase("earned_supply")
		health_old.removed.append(alias);health_old.health=95
		var healing = Campaign.new()
		check(healing.from_dict(health_old),"health alias migration")
		check(healing.health==95 and healing.earned_supply.healing_remaining[station.id]==int(station.capacity)-old_units,"no retrospective health/stock refill")
		var fresh: Dictionary = baseline._resources()
		fresh.health=95
		var healed: Dictionary = Supply.heal(fresh,layout,1,station.id)
		check(not healed.is_empty() and healed.health==100,"heal only missing5")
		check(healed.earned_supply.healing_remaining[station.id]==int(station.capacity)-5,"finite station decrement")
		check(Supply.heal(healed,layout,1,station.id).is_empty(),"full health consumes0")
		# Tombstones cannot be combined with restored full reservoir stock.
		var forged: Dictionary = healing.to_dict()
		forged.earned_supply.healing_remaining[station.id]=int(station.capacity)
		check(not Campaign.new().from_dict(forged),"legacy station refill contradiction rejected")
	check(count==145,"exact chapter-scoped145 legacy records")
	preferences_cases()
	failure_path_case()
	print("EARNED_SUPPLY_STATE checks=",checks," failures=",failures," native_physics_and_economy_not_claimed=true")
	quit(0 if failures==0 else 1)

func preferences_cases() -> void:
	var current = Preferences.new()
	var modern: Dictionary = current.to_dict()
	check(modern.version==4 and modern.bindings.has("use_asset"),"v4 additive action")
	for version in [1,2,3]:
		var old: Dictionary = modern.duplicate(true)
		old.version=version
		# Joint integration sets V4_ADDITIONS=[run,use_asset].
		for action in Preferences.V4_ADDITIONS: old.bindings.erase(action)
		if version==1:
			old.bindings.erase("survey")
			old.values.erase("reduced_damage_flashes")
		if version<=2: old.values.erase("sound_test_reduced_motion")
		old.bindings.interact[0].code=KEY_F
		var migrated = Preferences.new()
		check(migrated.from_dict(old),"legacy bindings migration v"+str(version))
		check(migrated.bindings.interact==old.bindings.interact,"custom interaction binding preserved")
		for action in Preferences.V4_ADDITIONS:
			var injected: Dictionary = old.duplicate(true)
			injected.bindings[action]=modern.bindings[action]
			check(not Preferences.new().from_dict(injected),"reject old envelope modern action injection")
	# Existing v1 also accepted the already-added survey action. Keep it.
	var v1_survey: Dictionary = modern.duplicate(true)
	v1_survey.version=1
	for action in Preferences.V4_ADDITIONS: v1_survey.bindings.erase(action)
	v1_survey.values.erase("reduced_damage_flashes")
	v1_survey.values.erase("sound_test_reduced_motion")
	check(Preferences.new().from_dict(v1_survey),"legitimate v1 with survey preserved")

class RecoveryMain:
	extends "res://scripts/main.gd"
	var captured_choices: Array = []
	func _ready() -> void: pass # No menus/audio/mouse capture on construction.
	func _show_menu(_heading: String, choices: Array) -> void:
		captured_choices=choices.map(func(row): return row[0])

class RecoveryLevel:
	extends Node3D
	var layout = preload("res://scripts/level_data.gd").new()
	var loaded: bool = false
	func _init() -> void: loaded=layout.load_level(0)

class FailedCarrier:
	extends CharacterBody3D
	var hp: int = 0
	var id: String = "intake_enemy_00"
	var owner_game
	func _current_map() -> bool:
		return get_parent()==owner_game.level

func failure_path_case() -> void:
	var paused_before: bool = paused
	var game = RecoveryMain.new()
	root.add_child(game)
	game.state.new_campaign(1)
	game.state.earned_supply={} # Causal invalid pre-commit invariant, no reward.
	game.level=RecoveryLevel.new()
	check(game.level.loaded,"failure fixture has actual loaded layout")
	game.add_child(game.level)
	var actor = FailedCarrier.new()
	actor.owner_game=game
	actor.collision_layer=4;actor.collision_mask=1
	actor.set_physics_process(true)
	game.level.add_child(actor)
	game.enemies=[actor]
	game.playing=true
	var before: Dictionary = game.state.to_dict()
	check(not game.earned_runtime.commit_defeat(game,actor),"failed lethal preparation refuses commit")
	check(game.earned_recovery_only and not game.playing and paused,"failure enters non-resumable recovery")
	check(actor.collision_layer==0 and actor.collision_mask==0 and not actor.is_physics_processing(),"half-death scene collider/physics inert")
	check(not "Resume" in game.captured_choices and "Restore checkpoint" in game.captured_choices and "Restart level" in game.captured_choices,"explicit healthy recovery choices, no Resume")
	game.resume_game()
	check(not game.playing and paused,"Escape/direct resume cannot revive poisoned scene")
	game.pause_game()
	check(not "Resume" in game.captured_choices,"ordinary pause cannot restore Resume")
	check(game._save()==ERR_INVALID_DATA,"poisoned scene never writes current save")
	game.save_and_title()
	check(not "Resume" in game.captured_choices,"save fallback has no resumable branch")
	check(not game.quit_game(),"window close requires explicit no-save/recovery choice")
	check(game.state.to_dict()==before,"no partial removed/grant/seal/state publication")
	game.free()
	paused=paused_before
