extends SceneTree
# Prepared production-boundary tests. Running Godot is separately authorized.
const Campaign = preload("res://scripts/campaign.gd")
const Layout = preload("res://scripts/level_data.gd")

func _initialize() -> void:
	for index in range(8):
		var layout = Layout.new()
		if not expect(layout.load_level(index),"real chapter loads"): return
		var keys: Array = layout.data.interactions.filter(func(item): return item.has("seal_bearer"))
		if not expect(keys.size() == 2,"two independent seal carriers"): return
		var state = Campaign.new()
		state.new_campaign(1)
		state.level_index = index
		state.floor_revision = layout.floor_revision()
		state.mark_checkpoint("entry",Vector3.ZERO)
		if not roundtrip(state,"before kill"): return
		for key in keys:
			var bearer: String = key.seal_bearer
			var point: Vector3 = layout.world_position(key.cell)+Vector3.UP*0.2
			var drop = {"guardian":bearer,"position":[point.x,point.y,point.z]}
			var living = state.to_dict()
			living.seal_drops.append(drop)
			if not expect(not Campaign.new().from_dict(living),"living bearer cannot drop"): return
			state.removed.append(bearer)
			state.seal_drops.append(drop)
			if not roundtrip(state,"after kill before pickup"): return
			state.mark_checkpoint("seal_test",Vector3.ZERO)
			if not roundtrip(state,"checkpoint preserves pending corpse origin"): return
			var missing = state.to_dict()
			missing.seal_drops.clear()
			if not expect(not Campaign.new().from_dict(missing),"modern missing drop rejected"): return
			# Each envelope is independently authoritative. A single XOR must fail
			# atomically; other snapshots stay valid and cannot conceal it.
			for envelope in ["current","checkpoint","level_start"]:
				for owned_without_retired in [false,true]:
					var inconsistent = state.to_dict()
					var target: Dictionary = inconsistent if envelope == "current" else inconsistent[envelope]
					if not bearer in target.removed: target.removed.append(bearer)
					target.seal_drops = target.seal_drops.filter(func(item): return item.guardian != bearer)
					if owned_without_retired:
						if not key.key in target.keys: target.keys.append(key.key)
						target.removed.erase(key.id)
					else:
						target.keys.erase(key.key)
						if not key.id in target.removed: target.removed.append(key.id)
					var destination = Campaign.new()
					var unchanged: Dictionary = destination.to_dict()
					if not expect(not destination.from_dict(inconsistent),"modern seal ownership/removal XOR rejected in "+envelope): return
					if not expect(destination.to_dict() == unchanged,"invalid XOR leaves destination unchanged"): return
			var duplicate = state.to_dict()
			duplicate.seal_drops.append(drop.duplicate(true))
			if not expect(not Campaign.new().from_dict(duplicate),"duplicate drop rejected"): return
			var outside = state.to_dict()
			outside.seal_drops[-1].position = [99999,0,99999]
			if not expect(not Campaign.new().from_dict(outside),"unreachable drop rejected"): return
			var legacy = state.to_dict()
			for snapshot in [legacy,legacy.checkpoint,legacy.level_start]: snapshot.erase("seal_drops")
			var migrated = Campaign.new()
			if not expect(migrated.from_dict(legacy),"legacy missing corpse coordinate migrates"): return
			if not expect(migrated.seal_drops == state.seal_drops,"legacy authored-anchor fallback"): return
			state.keys.append(key.key)
			state.removed.append(key.id)
			state.seal_drops = state.seal_drops.filter(func(item): return item.guardian != bearer)
			if not roundtrip(state,"after pickup, no duplicate"): return
			state.mark_checkpoint("seal_test",Vector3.ZERO)
			if not roundtrip(state,"checkpoint after pickup"): return
		# Earned old keys remain earned even when their old floor pickup preceded
		# the newly designated enemy's defeat. No enemy removal is fabricated.
		var grandfather = state.to_dict()
		for snapshot in [grandfather,grandfather.checkpoint,grandfather.level_start]:
			snapshot.erase("seal_drops")
			for key in keys:
				if not key.key in snapshot.keys: snapshot.keys.append(key.key)
				if not key.id in snapshot.removed: snapshot.removed.append(key.id)
				snapshot.removed.erase(key.seal_bearer)
		var old = Campaign.new()
		if not expect(old.from_dict(grandfather) and old.keys == ["blood","ivory"],"old collected seals grandfathered"): return
		if not expect(old.seal_drops.is_empty(),"collected seals never respawn"): return
		# Explicit absent-field legacy migration retains already owned keys even
		# if a matching pickup retirement was missing. No live bearer is killed.
		var owned_legacy = grandfather.duplicate(true)
		for snapshot in [owned_legacy,owned_legacy.checkpoint,owned_legacy.level_start]:
			for key in keys: snapshot.removed.erase(key.id)
		var normalized_legacy = Campaign.new()
		if not expect(normalized_legacy.from_dict(owned_legacy),"owned legacy seal marker bookkeeping migrates"): return
		if not expect(normalized_legacy.keys == ["blood","ivory"] and normalized_legacy.seal_drops.is_empty(),"legacy ownership retained without duplicate drops"): return
		for key in keys:
			if not expect(key.id in normalized_legacy.removed and not key.seal_bearer in normalized_legacy.removed,"legacy migration retires pickup only, never guardian"): return
		if not roundtrip(normalized_legacy,"normalized legacy collection remains consistent on resave"): return

		var inherited: String = Campaign.LEGACY_NEW_EXIT_WARDENS.get(layout.data.id,"")
		if not expect(old.legacy_exit_wardens == ([inherited] if not inherited.is_empty() else []),"only newly mandatory exit guardian grandfathered"): return
		if not inherited.is_empty():
			if not expect(not inherited in old.removed,"grandfathering never fabricates guardian defeat"): return
			for snapshot in [old.to_dict(),old.checkpoint,old.level_start]:
				if not expect(snapshot.legacy_exit_wardens == [inherited],"each earned legacy recovery envelope retains exit access"): return
			if not roundtrip(old,"legacy both seals unopened exit survives resave"): return
		# A post-feature save never earns an exemption merely by owning both keys.
		var modern = state.to_dict()
		var new_state = Campaign.new()
		if not expect(new_state.from_dict(modern) and new_state.legacy_exit_wardens.is_empty(),"modern both seals do not manufacture legacy access"): return
		var forged = modern.duplicate(true)
		forged.legacy_exit_wardens = ["nursery_warden"]
		if not expect(not Campaign.new().from_dict(forged),"foreign or preexisting boss exemption refused"): return
		if not inherited.is_empty():
			var one_seal = grandfather.duplicate(true)
			one_seal.keys.erase("ivory")
			one_seal.removed.erase(keys.filter(func(item): return item.key == "ivory")[0].id)
			var incomplete = Campaign.new()
			if not expect(incomplete.from_dict(one_seal) and incomplete.legacy_exit_wardens.is_empty(),"one old seal does not waive new exit guard"): return

	print("PASS seal guardian save phases across all eight chapters")
	quit(0)

func roundtrip(state, context: String) -> bool:
	var data: Dictionary = state.to_dict()
	var restored = Campaign.new()
	return expect(restored.from_dict(data) and restored.to_dict() == data,context)

func expect(value: bool, context: String) -> bool:
	if not value:
		push_error(context)
		quit(1)
	return value
