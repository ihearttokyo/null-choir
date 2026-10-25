extends SceneTree
## Direct production layout/save-codec checks; not physical traversal or playtest.
const Layout = preload("res://scripts/level_data.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Enemy = preload("res://scripts/enemy.gd")
var failures: int = 0

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var current = Layout.new()
	if not current.load_level(3):
		push_error(current.load_error)
		quit(2)
		return
	var prior = current.floor_at_revision(3,1)
	if prior == null:
		expect(false,"Parent shared lookup must resolve immutable revision1")
		quit(1)
		return
	expect(prior.floor_revision() == 1,"Explicit revision1 resolves immutable terrain")
	expect(not prior.is_walkable(Vector2i(15,20)) and current.is_walkable(Vector2i(15,20)),"Bridge adds actual floor tiles")
	expect(is_equal_approx(current.world_position([15.5,20]).y,3),"Upper authored landing height is correct")
	expect(is_equal_approx(current.world_position([19.5,27]).y,prior.world_position([19.5,27]).y),"Retained lower/outer route stays intact")
	for revision in [0,1]:
		var old = current.floor_at_revision(3,revision)
		var state = Campaign.new()
		state.new_campaign(1)
		state.level_index = 3
		var document = state.to_dict()
		var resources: Dictionary = document.checkpoint.duplicate(true)
		resources.merge({"health":73,"armor":41,"ammo":[0,37,5,0,0,0],"owned_weapons":[0,1,2],"weapon":2,"keys":[],"removed":[],"actors":[],"checkpoint_id":"entry"},true)
		var cell = [17.5,20]
		var point = old.world_position(cell)+Vector3.UP*1.1
		resources.position = [point.x,point.y,point.z]
		if revision == 0: resources.erase("floor_revision")
		else: resources.floor_revision = revision
		for spec in old.data.enemies:
			var location = old.world_position(spec.cell)
			location.y = old.capsule_floor_support(Vector2(location.x,location.z),Enemy.capsule_radius(spec.kind))+0.04+(1.0 if spec.kind == "caster" else 0.0)
			resources.actors.append({"id":spec.id,"hp":Enemy.health_cap(spec.kind,1),"position":[location.x,location.y,location.z],"yaw":0.0,"alerted":false})
		# merge does not remove keys: fresh revision2 root must lose its tag
		# as well as both resource envelopes when constructing a version1 save.
		if revision == 0: document.erase("floor_revision")
		document.merge(resources,true)
		document.version = 1 if revision == 0 else 2
		document.checkpoint = resources.duplicate(true)
		document.level_start = resources.duplicate(true)
		var before = document.duplicate(true)
		var accepted: bool = state.from_dict(document)
		expect(accepted,"Production migration accepts floor "+str(revision)+" to2")
		if not accepted:
			# Stop at the primary failure: no missing-actors cascade or hanging tree.
			quit(1)
			return
		expect(document == before,"Migration does not mutate caller")
		var migrated = state.to_dict()
		expect(migrated.floor_revision == 2,"Current envelope labels revision2")
		for pair in [[before,migrated],[before.checkpoint,migrated.checkpoint],[before.level_start,migrated.level_start]]:
			var a: Dictionary = pair[0]
			var b: Dictionary = pair[1]
			expect(b.floor_revision == 2,"Every resource envelope migrates")
			for field in ["health","armor","ammo","owned_weapons","weapon","keys","removed","checkpoint_id"]:
				expect(a[field] == b[field],"No resource refund or identity change: "+field)
			expect(absf(b.position[1]-current.world_position(cell).y-1.1)<0.00001,"Player retains floor offset")
			for i in range(a.actors.size()):
				var radius = Enemy.capsule_radius(old.data.enemies[i].kind)
				var center = Vector2(a.actors[i].position[0],a.actors[i].position[2])
				var expected_y = a.actors[i].position[1]+current.capsule_floor_support(center,radius)-old.capsule_floor_support(center,radius)
				expect(absf(b.actors[i].position[1]-expected_y)<0.00001,"Actor signed capsule clearance preserved")
		var again = Campaign.new()
		expect(again.from_dict(migrated) and again.to_dict() == migrated,"Revision2 reload idempotent")
		for defect in ["mixed","future","below"]:
			var bad = before.duplicate(true)
			if defect == "mixed": bad.checkpoint.floor_revision = 2
			elif defect == "future":
				bad.version = 2
				for snapshot in [bad,bad.checkpoint,bad.level_start]: snapshot.floor_revision = 3
			else: bad.actors[0].position[1] -= 20
			var accepted_before = state.to_dict()
			expect(not state.from_dict(bad) and state.to_dict() == accepted_before,"Atomic rejection: "+defect)
	print("Reliquary reliquary_archive_rim2 source/layout/save failures=",failures,"; no physics/render/navigation acceptance")
	quit(0 if failures == 0 else 1)
