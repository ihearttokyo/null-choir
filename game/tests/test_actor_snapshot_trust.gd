extends SceneTree

const Campaign = preload("res://scripts/campaign.gd")
const Layout = preload("res://scripts/level_data.gd")
const Enemy = preload("res://scripts/enemy.gd")
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func run() -> void:
	check_yaw_boundaries()
	check_codec_roundtrip()
	if "--codec-only" in OS.get_cmdline_user_args():
		if failures == 0: print("PASS exact Campaign actor disk codec: native yaw and PI/current/checkpoint/entry; not scene/physics acceptance")
		quit(0 if failures == 0 else 1)
		return
	for index in range(8):
		for difficulty in range(3):
			var document = fresh_document(index,difficulty)
			var state = Campaign.new()
			expect(state.from_dict(document),"Source-derived authored records load on every map/difficulty")
			expect(state.to_dict() == document,"Records normalize without losing snapshot identity")
			state.removed.append(document.actors.back().id)
			state.health = 0
			state.restore_checkpoint()
			expect(state.to_dict() == document,"Checkpoint selection discards later current deaths and stale current actor records")
			state.checkpoint.actors.back().hp = INF
			var invalid_checkpoint = state.to_dict()
			state.restore_checkpoint()
			expect(state.to_dict() == invalid_checkpoint,"Checkpoint rejection validates before any resource mutation")
			state.from_dict(document)
			state.level_start.actors.back().position[1] = INF
			var invalid_entry = state.to_dict()
			state.restore_level_start()
			expect(state.to_dict() == invalid_entry,"Entry rejection validates before any resource mutation")
			state.from_dict(document)
			var before = state.to_dict()
			for envelope in ["current","checkpoint","level_start"]:
				for defect in ["duplicate","unknown","cross-level","dead","missing","hp-zero","hp-cap","hp-fraction","hp-bool","hp-inf","pose-inf","pose-bool","pose-length","pose-hole","pose-below","pose-roof","yaw-inf","yaw-range","alert-bool","extra","oversized"]:
					var invalid = document.duplicate(true)
					var target: Dictionary = invalid if envelope == "current" else invalid[envelope]
					var actor: Dictionary = target.actors.back()
					match defect:
						"duplicate": target.actors.append(actor.duplicate(true))
						"unknown": actor.id = "unknown"
						"cross-level": actor.id = "heart_enemy_1" if index != 7 else "nursery_enemy_1"
						"dead": target.removed.append(actor.id)
						"missing": target.actors.pop_back()
						"hp-zero": actor.hp = 0
						"hp-cap": actor.hp += 1
						"hp-fraction": actor.hp = 1.5
						"hp-bool": actor.hp = true
						"hp-inf": actor.hp = INF
						"pose-inf": actor.position[0] = INF
						"pose-bool": actor.position[0] = true
						"pose-length": actor.position.append(0)
						"pose-hole": actor.position[0] = -1000
						"pose-below": actor.position[1] = -1000
						"pose-roof": actor.position[1] = 1000
						"yaw-inf": actor.yaw = INF
						"yaw-range": actor.yaw = TAU
						"alert-bool": actor.alerted = 1
						"extra": actor.profile = {"hp":10000}
						"oversized":
							for number in range(36): target.actors.append(actor.duplicate(true))
					expect(not state.from_dict(invalid) and state.to_dict() == before,"Atomic rejection of final-record "+envelope+" "+defect)
			# Field absence is a v1 legacy envelope, not an authoritative empty array.
			var legacy = document.duplicate(true)
			legacy.erase("actors")
			legacy.checkpoint.erase("actors")
			expect(state.from_dict(legacy) and not state.to_dict().has("actors") and not state.checkpoint.has("actors") and state.level_start.has("actors"),"Independent mixed legacy snapshots stay absent")
			state.actors = document.actors.duplicate(true)
			state.restore_checkpoint()
			expect(state.actors == null,"Legacy checkpoint selection erases current actor presence instead of merging it")
			var empty = document.duplicate(true)
			empty.removed = empty.actors.map(func(actor): return actor.id)
			empty.actors = []
			expect(state.from_dict(empty) and state.actors == [] and state.to_dict().has("actors"),"Explicit empty living set is preserved with authored deaths")
			state.restore_level_start()
			expect(state.actors == document.level_start.actors,"Entry restoration owns its actor records")
			state.actors[0].position[0] += 1
			expect(state.level_start.actors == document.level_start.actors and state.checkpoint.actors == document.level_start.actors,"Applied/captured nested records do not alias entry or checkpoint")
			state.complete_level()
			expect(not state.to_dict().has("actors") and not state.checkpoint.has("actors") and not state.level_start.has("actors"),"Advancement clears retired actors from all pending envelopes")
			state.new_campaign(difficulty)
			expect(state.actors == null,"New campaign clears actor presence")
	check_births()
	print("Actor snapshot trust failures=",failures,"; direct native Campaign/source-layout checks, not scene/physics acceptance")
	if failures == 0: print("PASS actor snapshot trust and exact disk codec: malformed/legacy/owner/birth/envelope boundaries; not scene/physics acceptance")
	quit(0 if failures == 0 else 1)

func check_yaw_boundaries() -> void:
	var limit: float = Vector3(0,3.1415925,0).y
	for value in [0.0,0.000000001,-0.000000001,0.73,-2.8966147899627686,-2.896614789962769,-PI,PI,PI-0.00000001,-PI+0.00000001,Vector3(0,PI,0).y,-Vector3(0,PI,0).y]:
		var yaw: float = Enemy.canonical_yaw(value)
		expect(yaw >= -PI and yaw < PI and yaw == Vector3(0,yaw,0).y,"Canonical yaw is a valid native float32, not a decimal/binary64 surrogate")
		expect(Enemy.canonical_yaw(yaw) == yaw,"Native yaw normalization is exactly idempotent, including PI neighbors")
	var native: float = Vector3(0,-2.8966147899627686,0).y
	expect(Enemy.canonical_yaw(-2.896614789962769) == native,"The observed one-bit JSON parser drift normalizes to the original native yaw")
	expect(Enemy.canonical_yaw(-PI) == -limit and Enemy.canonical_yaw(PI) == -limit,"Exact negative/positive PI choose the stable negative interior boundary")
	expect(Enemy.canonical_yaw(PI-0.00000001) == limit,"Near-positive PI cannot round outside the trusted half-open interval")
	expect(is_nan(Enemy.canonical_yaw(NAN)) and Enemy.canonical_yaw(INF) == INF,"Invalid nonfinite native yaw remains invalid for the strict trust boundary")

func check_codec_roundtrip() -> void:
	var path = "user://actor_codec_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())+".json"
	for yaw in [0.73,-0.41,0.29,-0.67,PI,-PI,PI-0.0000001,-PI+0.0000001]:
		var document = fresh_document(4,1)
		# The production snapshot reads a real native CharacterBody3D rotation,
		# including float32 promotion and the canonical PI boundary.
		var actor = Enemy.new()
		var record: Dictionary = document.actors[0]
		actor.id = record.id
		actor.hp = record.hp
		actor.position = Vector3(record.position[0],record.position[1],record.position[2])
		actor.rotation.y = yaw
		for envelope in [document,document.checkpoint,document.level_start]:
			envelope.actors[0] = actor.snapshot()
		var captured: Dictionary = actor.snapshot()
		actor.restore_snapshot(captured)
		expect(actor.snapshot() == captured,"Actual native snapshot/restore/snapshot is exactly stable, including PI neighbors")
		# Cover the exact canonical binary64 boundary observed in G07 as well.
		document.level_start.actors[1].yaw = -PI
		actor.free()
		document.health = 73
		document.armor = 21
		document.ammo[1] = 37
		document.checkpoint.health = 91
		document.checkpoint.ammo[1] = 79
		document.discoveries = [0,3]
		document.explored = [[1,1]]
		var state = Campaign.new()
		expect(state.from_dict(document),"SETUP: native yaw snapshots satisfy the unchanged strict validator")
		var before: Dictionary = state.to_dict()
		var saved: Error = state.save_progress(path)
		expect(saved == OK,"Actual Campaign atomic disk save succeeds for native yaw "+str(yaw))
		if saved != OK: continue
		var restored = Campaign.new()
		expect(restored.load_progress(path),"Actual Campaign disk load accepts native yaw "+str(yaw))
		expect(restored.to_dict() == before,"Exact Campaign disk roundtrip preserves ALL current/checkpoint/entry fields for native yaw "+str(yaw))
	for candidate in [path,path+".tmp"]:
		if FileAccess.file_exists(candidate): expect(DirAccess.remove_absolute(candidate) == OK,"Remove only the isolated actor codec fixture file")

func fresh_document(index: int, difficulty: int) -> Dictionary:
	var state = Campaign.new()
	state.new_campaign(difficulty)
	state.level_index = index
	var layout = Layout.new()
	expect(layout.load_level(index),"Actual layout loads")
	state.actors = []
	# Unattached real Main/Level instances provide the production configure inputs;
	# no scene, physics, music or GUI startup is claimed by this codec/trust fixture.
	var owner = load("res://scripts/main.gd").new()
	owner.state = state
	owner.level = load("res://scripts/level.gd").new()
	owner.level.layout = layout
	owner.add_child(owner.level)
	var specs: Dictionary = Campaign.actor_specs(layout)
	for spec in layout.data.enemies:
		var actor = Enemy.new()
		owner.level.add_child(actor)
		actor.configure(owner,specs[spec.id])
		state.actors.append(actor.snapshot())
	owner.free()
	state.mark_checkpoint("entry",layout.world_position(layout.data.spawn))
	return state.to_dict()

func check_births() -> void:
	var document = fresh_document(4,1)
	var owner = "nursery_enemy_17"
	var layout = Layout.new()
	layout.load_level(4)
	var registry: Dictionary = Campaign.actor_specs(layout)
	var group: String = registry[owner].encounter
	document.removed.append("encounter:"+group)
	for actor in document.actors:
		if registry[actor.id].encounter == group: actor.alerted = true
	for number in range(1,7):
		document.removed.append("summon:"+owner+":"+str(number))
		if number <= 4: document.removed.append(owner+"_add_"+str(number))
		else:
			var point: Vector3 = layout.world_position([28.5 if number == 5 else 32.0,10.5 if number == 5 else 9.0])+Vector3.UP*0.03
			document.actors.append({"id":owner+"_add_"+str(number),"hp":Enemy.health_cap("crawler",1)-number,"position":[point.x,point.y,point.z],"yaw":0.0,"alerted":true})
	var state = Campaign.new()
	expect(state.from_dict(document),"Six births, four deaths and exact living fifth/sixth form a valid snapshot")
	for defect in ["missing-live","missing-birth","gap","seventh","foreign-owner","dormant-owner","owner-cap","cross-removal","unknown-removal"]:
		var invalid = document.duplicate(true)
		match defect:
			"missing-live": invalid.actors.pop_back()
			"missing-birth": invalid.removed.erase("summon:"+owner+":6")
			"gap": invalid.removed.erase("summon:"+owner+":2")
			"seventh": invalid.removed.append("summon:"+owner+":7")
			"foreign-owner": invalid.actors.back().id = "nursery_enemy_16_add_6"
			"dormant-owner": invalid.removed.erase("encounter:"+group)
			"owner-cap":
				invalid.removed.erase(owner+"_add_4")
				var actor = invalid.actors.back().duplicate(true)
				actor.id = owner+"_add_4"
				invalid.actors.append(actor)
			"cross-removal": invalid.removed.append("heart_enemy_1")
			"unknown-removal": invalid.removed.append("summon:invented:1")
		var before = state.to_dict()
		expect(not state.from_dict(invalid) and state.to_dict() == before,"Atomic owner/birth rejection: "+defect)
	document.removed.append(owner)
	document.actors = document.actors.filter(func(actor): return actor.id != owner)
	expect(state.from_dict(document),"Living children remain valid after their actual authored owner's death")
	var ambiguous = document.duplicate(true)
	ambiguous.erase("actors")
	expect(state.from_dict(ambiguous) and state.actors == null,"Legacy orphaned births load without invented living adds or deaths")
	document.level_index = 5
	expect(not state.from_dict(document),"Prior-level actor envelopes cannot be moved to a new level")

func expect(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
