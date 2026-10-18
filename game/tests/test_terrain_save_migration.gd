extends "res://tests/test_actor_snapshot_trust.gd"

func run() -> void:
	var fixture: String = OS.get_environment("NULL_CHOIR_TERRAIN_FIXTURE_ROOT")
	var private_home: String = fixture.get_base_dir().get_base_dir()+"/home"
	if fixture.is_empty() or ProjectSettings.globalize_path("res://").trim_suffix("/") != fixture or OS.get_environment("HOME") != private_home or not OS.get_user_data_dir().begins_with(private_home+"/"):
		print("REFUSED TERRAIN FIXTURE: explicit disposable project and private HOME required")
		quit(2)
		return
	for index in range(8):
		var path = "res://data/"+Layout.FILES[index]+".json"
		var original = FileAccess.get_file_as_string(path)
		var documents: Array = []
		for mode in range(3):
			var document = staged_document(index,mode)
			var baseline = Campaign.new()
			expect(baseline.from_dict(document) and JSON.stringify(baseline.to_dict(),"",true,true) == JSON.stringify(document,"",true,true),"Unchanged map version1 byte-codec parity")
			documents.append(document)
		var changed: Dictionary = JSON.parse_string(original)
		changed["floor_revision"] = 1
		for region in changed.elevations: region.height *= 1.25
		var file = FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify(changed)); file.close()
		var layout = Layout.new()
		expect(layout.load_level(index),"Changed-height real map fixture loads")
		for mode in range(3):
			var document: Dictionary = documents[mode]
			var before = document.duplicate(true)
			var old_layout = Layout.new()
			old_layout.data = JSON.parse_string(original)
			old_layout.tiles = layout.tiles.duplicate()
			var state = Campaign.new()
			var accepted = state.from_dict(document)
			if not accepted:
				for snapshot in [document,document.checkpoint,document.level_start]:
					for actor in snapshot.actors:
						if not state._valid_actor_pose(actor,Campaign.actor_specs(old_layout)[actor.id],old_layout): print("OLD_POSE_TRACE ",actor)
					print("OLD_RESOURCES_TRACE valid=",state._valid_resources(snapshot)," actors=",state._valid_actor_resources(snapshot,old_layout,mode))
			if not accepted:
				file = FileAccess.open(path,FileAccess.WRITE); file.store_string(original); file.close()
				print("INTENDED_TERRAIN_SAVE_RED map=",index," difficulty=",mode," unchanged Campaign rejects old full actor envelopes after counterfactual floor lift")
				quit(1)
				return
			expect(document == before,"Migration leaves input dictionary untouched")
			var migrated = state.to_dict()
			expect(migrated.version == 2 and migrated.floor_revision == 1,"Migrated current revision is explicit")
			for envelope in ["current","checkpoint","level_start"]:
				var old: Dictionary = before if envelope == "current" else before[envelope]
				var new: Dictionary = migrated if envelope == "current" else migrated[envelope]
				expect(new.floor_revision == 1,"Every envelope records current floor")
				for field in old:
					if not field in ["position","actors","checkpoint","level_start","version"]: expect(new[field] == old[field],"Resources and IDs preserved: "+field)
				var old_point = Vector3(old.position[0],old.position[1],old.position[2])
				var old_cell = [old_point.x/old_layout.data.cell_size,old_point.z/old_layout.data.cell_size]
				var expected_y = old_point.y+layout.world_position(old_cell).y-old_layout.world_position(old_cell).y if old_point != Vector3.ZERO else 0.0
				expect(absf(new.position[1]-expected_y) < 0.00001,"Player relative floor offset preserved")
				for number in range(old.actors.size()):
					var a: Dictionary = old.actors[number]
					var b: Dictionary = new.actors[number]
					var cell = [a.position[0]/old_layout.data.cell_size,a.position[2]/old_layout.data.cell_size]
					var expected_actor_y = a.position[1]+layout.world_position(cell).y-old_layout.world_position(cell).y
					expect(absf(b.position[1]-expected_actor_y) < 0.00001,"Actual triangulated delta retains actor hover/fall offset")
					expect(a.id == b.id and a.hp == b.hp and a.yaw == b.yaw and a.alerted == b.alerted and a.position[0] == b.position[0] and a.position[2] == b.position[2],"Full actor identity/resources/XZ preserved")
			var again = Campaign.new()
			expect(again.from_dict(migrated) and again.to_dict() == migrated,"Version2 reload is exactly idempotent")
			for envelope in ["current","checkpoint","level_start"]:
				for defect in ["old-below-floor","nonfinite","overflow","future","mixed-revision","health","future-floor","zero-v2","nan","revision-bool","revision-fraction"]:
					var bad = document.duplicate(true)
					var target: Dictionary = bad if envelope == "current" else bad[envelope]
					match defect:
						"old-below-floor": target.actors[0].position[1] -= 10
						"nonfinite": target.actors[0].position[0] = INF
						"nan": target.actors[0].position[0] = NAN
						"revision-bool": target["floor_revision"] = true
						"revision-fraction": target["floor_revision"] = 0.5
						"overflow": target.actors[0].position[0] = 1e100
						"future": bad.version = 3
						"mixed-revision": target["floor_revision"] = 1
						"health": target.health = -1
						"future-floor":
							bad = migrated.duplicate(true)
							for snapshot in [bad,bad.checkpoint,bad.level_start]: snapshot.floor_revision = 2
						"zero-v2":
							bad = migrated.duplicate(true)
							for snapshot in [bad,bad.checkpoint,bad.level_start]: snapshot.floor_revision = 0
					var untouched = var_to_bytes(bad)
					expect(not state.from_dict(bad) and state.to_dict() == migrated and var_to_bytes(bad) == untouched,"Atomic live/input rejection "+envelope+" "+defect)
			var save_path = "user://migration.json"
			var save_error = state.save_progress(save_path)
			var loaded = again.load_progress(save_path)
			if save_error != OK or not loaded or again.to_dict() != migrated:
				print("DISK_TRACE save_error=",save_error," loaded=",loaded)
				for field in migrated:
					if again.to_dict().get(field) != migrated[field]: print("DISK_DIFF ",field," expected=",migrated[field]," actual=",again.to_dict().get(field))
			expect(save_error == OK and loaded and again.to_dict() == migrated,"Actual v2 atomic disk codec is idempotent")
			for values in [[0.0,0.0,0.0],[-64.0,-100.0,-64.0]]:
				var recoverable = document.duplicate(true)
				for snapshot in [recoverable,recoverable.checkpoint,recoverable.level_start]: snapshot.position = values.duplicate()
				var control = Campaign.new()
				expect(control.from_dict(recoverable) and control.to_dict().position == values and control.checkpoint.position == values and control.level_start.position == values,"Sentinel and outside-floor recovery poses are preserved for Main")
			var fresh = Campaign.new()
			fresh.new_campaign(mode)
			if index == 0: expect(fresh.floor_revision == 1 and fresh.to_dict().version == 2 and fresh.level_start.floor_revision == 1,"New campaign labels current authored floor")
			fresh.level_index = index-1
			fresh.complete_level()
			expect(fresh.floor_revision == 1 and fresh.checkpoint.floor_revision == 1,"Completion labels destination floor")
			if index == 7:
				fresh.complete_level()
				expect(fresh.to_dict().version == 1 and fresh.level_index == 8 and Campaign.new().from_dict(fresh.to_dict()),"Completed campaign resets retired floor labels and remains loadable")
			state.restore_checkpoint()
			var recovered = migrated.duplicate(true)
			recovered.merge(migrated.checkpoint,true)
			expect(state.to_dict() == recovered,"Checkpoint restoration cannot migrate twice or refund resources")
			state.restore_level_start()
			recovered.merge(migrated.level_start,true)
			recovered.checkpoint = migrated.level_start.duplicate(true)
			expect(state.to_dict() == recovered,"Entry restoration cannot migrate twice")
		var keeper = Campaign.new()
		expect(keeper.from_dict(documents[0]),"Prepare live state for unsafe transformed pose rejection")
		var live_before = keeper.to_dict()
		var low_roof = changed.duplicate(true)
		low_roof.ceilings.push_front({"rect":[-100,-100,100,100],"height":0.5})
		file = FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(low_roof)); file.close()
		var input_before = var_to_bytes(documents[0])
		expect(not keeper.from_dict(documents[0]) and keeper.level_load_error.is_empty() and keeper.to_dict() == live_before and var_to_bytes(documents[0]) == input_before,"Unsafe transformed headroom rejects atomically AFTER legacy geometry validation")
		file = FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(changed)); file.close()
		await mesh_witness(layout)
		file = FileAccess.open(path,FileAccess.WRITE); file.store_string(original); file.close()
		print("TERRAIN_SAVE_CASE map=",index," difficulties=3 counterfactual_height_fixture=true")
	if failures == 0: print("PASS terrain save migration narrow production codec fixture; not traversal/GPU/packed acceptance")
	quit(0 if failures == 0 else 1)

func staged_document(index: int, mode: int) -> Dictionary:
	var document = fresh_document(index,mode)
	var layout = Layout.new()
	layout.load_level(index)
	var cell: Array = []
	for tile in layout.tiles:
		var sample = [tile.x+0.2,tile.y+0.8]
		var point = layout.world_position(sample)
		if absf(point.y) > 0.1 and absf(point.y-layout.height_at(Vector2(sample[0],sample[1]))) > 0.001:
			cell = sample
			break
	if cell.is_empty():
		for tile in layout.tiles:
			var sample = [tile.x+0.2,tile.y+0.8]
			if absf(layout.world_position(sample).y) > 0.1:
				cell = sample
				break
	expect(not cell.is_empty(),"Real fractional elevated floor position exists")
	var point = layout.world_position(cell)
	for snapshot in [document,document.checkpoint,document.level_start]:
		var player_pose = point+Vector3.DOWN*0.04
		snapshot.position = [player_pose.x,player_pose.y,player_pose.z]
		snapshot["yaw"] = Enemy.canonical_yaw(0.73)
		snapshot["pitch"] = Vector3(0.29,0,0).x
		var keys = layout.data.interactions.filter(func(spec): return spec.kind == "key").map(func(spec): return spec.key)
		if mode == 2: keys.reverse()
		snapshot.keys = keys
		var specs = Campaign.actor_specs(layout)
		for record in snapshot.actors:
			if specs[record.id].kind == "crawler":
				var actor_pose = point+Vector3.UP*0.03
				record.position = [actor_pose.x,actor_pose.y,actor_pose.z]
				break
		var summoners = layout.data.enemies.filter(func(spec): return spec.kind == "summoner")
		if not summoners.is_empty():
			var spec = specs[summoners[0].id]
			if not spec.encounter.is_empty():
				snapshot.removed.append("encounter:"+spec.encounter)
				for record in snapshot.actors:
					if specs[record.id].encounter == spec.encounter: record.alerted = true
			for number in range(1,7):
				snapshot.removed.append("summon:"+spec.id+":"+str(number))
				if number <= 4: snapshot.removed.append(spec.id+"_add_"+str(number))
				else:
					var owner = load("res://scripts/main.gd").new()
					owner.state = Campaign.new()
					owner.state.difficulty = mode
					owner.level = load("res://scripts/level.gd").new()
					owner.level.layout = layout
					owner.add_child(owner.level)
					var actor = Enemy.new()
					owner.level.add_child(actor)
					actor.configure(owner,specs[spec.id+"_add_"+str(number)])
					actor.hp = maxi(1,actor.hp-number)
					snapshot.actors.append(actor.snapshot())
					owner.free()
	document.health = 73
	document.armor = 21
	document.ammo[1] = 37
	document.checkpoint.health = 91
	document.checkpoint.ammo[1] = 79
	document.level_start.health = 97
	document.level_start.ammo[1] = 88
	document.level_start.position = [0.0,0.0,0.0]
	return document

func mesh_witness(layout) -> void:
	var level = load("res://scripts/level.gd").new()
	level.layout = layout
	root.add_child(level)
	level._build_geometry()
	await physics_frame
	await physics_frame
	var samples = 0
	for tile in layout.tiles:
		for offset in [Vector2(.2,.8),Vector2(.8,.2)]:
			var point = layout.world_position([tile.x+offset.x,tile.y+offset.y])
			if absf(point.y) < .1: continue
			var ray = PhysicsRayQueryParameters3D.create(point+Vector3.UP*.1,point-Vector3.UP*.1,1)
			var hit = level.get_world_3d().direct_space_state.intersect_ray(ray)
			expect(not hit.is_empty() and absf(hit.position.y-point.y)<.003,"Counterfactual fractional floor matches actual native collision triangles")
			samples += 1
		if samples >= 4: break
	expect(samples >= 4,"Both triangle halves have native witnesses")
	print("TERRAIN_NATIVE_FLOOR samples=",samples," map=",layout.data.id)
	level.free()
	await physics_frame
