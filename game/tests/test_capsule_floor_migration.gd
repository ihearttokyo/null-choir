extends SceneTree

const Campaign = preload("res://scripts/campaign.gd")
const Layout = preload("res://scripts/level_data.gd")
const Enemy = preload("res://scripts/enemy.gd")
var failures: int = 0

func expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var layout = Layout.new()
	expect(layout.load_level(5),"Real Ossuary loads without scenes/imports: "+layout.load_error)
	if layout.data.is_empty():
		quit(2)
		return
	var old = layout.original_floor(5)
	var state = Campaign.new()
	var spec: Dictionary = layout.data.enemies.filter(func(e): return e.kind == "guardian")[0]
	var point = old.world_position([19.75,31.25])+Vector3.UP*.03
	var actor = {"id":spec.id,"position":[point.x,point.y,point.z],"hp":201,"yaw":Enemy.canonical_yaw(.4),"alerted":false}
	var envelope = {"health":73,"armor":21,"ammo":[0,37,3,4,5,6],"owned_weapons":[0,1,2],"weapon":2,"keys":[],"removed":[],"checkpoint_id":"entry","position":[0.0,0.0,0.0],"actors":[actor]}
	for enemy in old.data.enemies:
		if enemy.id != actor.id: envelope.removed.append(enemy.id)
	var document = envelope.duplicate(true)
	document.merge({"version":1,"difficulty":1,"level_index":5,"discoveries":[0,1],"explored":[],"checkpoint":envelope.duplicate(true),"level_start":envelope.duplicate(true)})
	var before = var_to_bytes(document)
	expect(state._valid_actor_resources(document,old,1),"Original bot guardian passes existing old-pose validation")
	expect(state.from_dict(document),"Legacy document migrates")
	var result = state.to_dict()
	var radius = Enemy.capsule_radius(spec.kind)
	var required_support = layout.world_position([19.75,31.25]).y+radius*(sqrt(1.125)-1.0)
	for name in ["current","checkpoint","level_start"]:
		var a: Dictionary = document if name == "current" else document[name]
		var b: Dictionary = result if name == "current" else result[name]
		expect(absf(b.actors[0].position[1]-(required_support+.03))<.00001,"INTENDED RED: exact bot guardian retains 0.03 capsule support clearance: "+name)
		for field in a:
			if field not in ["actors","position","checkpoint","level_start","version"]: expect(a[field]==b[field],"Preserve resource "+field)
		var aa: Dictionary = a.actors[0]
		var bb: Dictionary = b.actors[0]
		expect(aa.id==bb.id and aa.hp==bb.hp and aa.yaw==bb.yaw and aa.alerted==bb.alerted and aa.position[0]==bb.position[0] and aa.position[2]==bb.position[2],"Actor identity/state/XZ unchanged")
	expect(var_to_bytes(document)==before,"Input dictionary immutable")
	check_math(layout)
	check_trust_and_recovery(state,document,old,layout)
	check_born_crawler(document,old,layout)
	print("CAPSULE_BOT_RESULT ",JSON.stringify({"failures":failures,"expected_actor_y":required_support+.03,"actual_actor_y":result.actors[0].position[1]}))
	if failures==0: print("PASS native capsule floor migration signed clearance/analytic geometry/trust/three envelopes;")
	quit(0 if failures==0 else 1)

func check_math(real_layout) -> void:
	var radii: Array = []
	for role in Enemy.WINDUPS:
		var radius = Enemy.capsule_radius(role)
		if not radius in radii: radii.append(radius)
	var triangle_cases: int = 0
	for radius in radii:
		var gradient = Vector2(.7,-.4)
		var triangle = [Vector3(-4,2+gradient.dot(Vector2(-4,-4)),-4),Vector3(8,2+gradient.dot(Vector2(8,-4)),-4),Vector3(-4,2+gradient.dot(Vector2(-4,8)),8)]
		var expected = 2+radius*(sqrt(1+gradient.length_squared())-1)
		check_windings(real_layout,radius,triangle,expected,"Interior sphere tangent")
		var d = radius*.3
		var slope = .8
		triangle = [Vector3(d,2-2*slope,-2),Vector3(d+4,2-2*slope,-2),Vector3(d,2+2*slope,2)]
		expected = 2-radius+sqrt(radius*radius-d*d)*sqrt(1+slope*slope)
		check_windings(real_layout,radius,triangle,expected,"Clipped footprint edge tangent")
		d = radius*.4
		triangle = [Vector3(d,2,d),Vector3(d+4,2,d),Vector3(d,2,d+4)]
		expected = 2-radius+sqrt(radius*radius-2*d*d)
		check_windings(real_layout,radius,triangle,expected,"Vertex-clamped tangent")
		triangle = [Vector3(2,0,2),Vector3(3,0,2),Vector3(2,0,3)]
		expect(real_layout._capsule_triangle_support(radius,triangle[0],triangle[1],triangle[2])==-INF,"Disjoint triangle has no phantom support")
		var center = Vector2(19.75,31.25)*float(real_layout.data.cell_size)
		expected = real_layout.world_position([19.75,31.25]).y+radius*(sqrt(1.125)-1)
		expect(absf(real_layout.capsule_floor_support(center,radius)-expected)<.00002,"Real bot floor support for shared role radius "+str(radius))
		triangle_cases += 19
	var diagonal = Layout.new()
	diagonal.data = {"cell_size":4.0,"elevations":[{"rect":[1,0,1,0],"height":4.0}]}
	diagonal.tiles = {Vector2i.ZERO:true}
	expect(absf(diagonal.capsule_floor_support(Vector2(1.8,2.2),1.0)-(-.4+sqrt(3.0)-1))<.00002,"Footprint crosses runtime diagonal into rising triangle despite flat center")
	var boundary = Layout.new()
	boundary.data = {"cell_size":4.0,"elevations":[{"rect":[2,0,2,1],"height":4.0}]}
	boundary.tiles = {Vector2i.ZERO:true,Vector2i.RIGHT:true}
	expect(absf(boundary.capsule_floor_support(Vector2(3.8,2),1.0)-(-.2+sqrt(2.0)-1))<.00002,"Footprint crosses tile boundary despite flat center")
	boundary.tiles.erase(Vector2i.RIGHT)
	expect(absf(boundary.capsule_floor_support(Vector2(3.8,2),1.0))<.00002,"No phantom floor outside walkable tiles")
	# Signed clearance survives transfers in both directions, without laundering penetration.
	for radius in radii:
		for clearance in [-.04,0.0,.03,.8]:
			var center = Vector2(3.8,2)
			var old_support = boundary.capsule_floor_support(center,radius)
			var new_support = diagonal.capsule_floor_support(center,radius)
			var pose = [center.x,old_support+clearance,center.y]
			var migrated = Campaign.new()._shift_floor(pose,boundary,diagonal,false,radius)
			expect(absf(migrated[1]-new_support-clearance)<.00002,"Signed support clearance preserved, including invalid negative offset")
			var returned = Campaign.new()._shift_floor(migrated,diagonal,boundary,false,radius)
			expect(absf(returned[1]-pose[1])<.00002,"Reverse migration preserves original Y")
	print("CAPSULE_MATH_CASES ",JSON.stringify({"distinct_shared_radii":radii.size(),"triangle_cases":triangle_cases,"signed_transfers":radii.size()*8,"crossing_cases":3}))

func check_windings(layout, radius: float, vertices: Array, expected: float, label: String) -> void:
	for order in [[0,1,2],[1,2,0],[2,0,1],[0,2,1],[2,1,0],[1,0,2]]:
		var actual = layout._capsule_triangle_support(radius,vertices[order[0]],vertices[order[1]],vertices[order[2]])
		expect(absf(actual-expected)<.00002,label+" winding/radius "+str(radius))

func check_trust_and_recovery(state, document: Dictionary, old, layout) -> void:
	var migrated = state.to_dict()
	var again = Campaign.new()
	expect(again.from_dict(migrated) and again.to_dict()==migrated,"Same floor is exactly idempotent")
	state.restore_checkpoint()
	var restored = migrated.duplicate(true)
	restored.merge(migrated.checkpoint,true)
	expect(state.to_dict()==restored,"Checkpoint recovery never migrates twice")
	state.restore_level_start()
	restored.merge(migrated.level_start,true)
	restored.checkpoint = migrated.level_start.duplicate(true)
	expect(state.to_dict()==restored,"Level restart never migrates twice")
	state.from_dict(migrated)
	for envelope in ["current","checkpoint","level_start"]:
		for defect in ["below-floor","ceiling","unknown","hp","nan","malformed","future","revision","mixed","born-history"]:
			var invalid = document.duplicate(true)
			var target: Dictionary = invalid if envelope=="current" else invalid[envelope]
			match defect:
				"below-floor": target.actors[0].position[1] = -1.0
				"ceiling": target.actors[0].position[1] = 1000.0
				"unknown": target.actors[0].id = "unknown"
				"hp": target.actors[0].hp = 0
				"nan": target.actors[0].position[1] = NAN
				"malformed": target.actors[0].position = [0,0]
				"future": invalid.version = 3
				"revision":
					invalid = migrated.duplicate(true)
					for snapshot in [invalid,invalid.checkpoint,invalid.level_start]: snapshot.floor_revision = layout.floor_revision()+1
				"mixed": target["floor_revision"] = 1
				"born-history": target.removed.append("summon:unknown:1")
			var before = var_to_bytes(invalid)
			expect(not state.from_dict(invalid) and state.to_dict()==migrated and var_to_bytes(invalid)==before,"Unchanged atomic trust rejection "+envelope+" "+defect)
		for pose in [[0.0,0.0,0.0],[-64.0,-100.0,-64.0]]:
			var recoverable = document.duplicate(true)
			var target: Dictionary = recoverable if envelope=="current" else recoverable[envelope]
			target.position = pose.duplicate()
			var control = Campaign.new()
			expect(control.from_dict(recoverable),"Existing player recovery remains accepted")
			var output = control.to_dict()
			var actual: Dictionary = output if envelope=="current" else output[envelope]
			expect(actual.position==pose,"ZERO/outside player pose unchanged for native recovery")
		# Existing static tolerance allows small penetration. Migration must not sanitize it.
		var invalid = document.duplicate(true)
		var target: Dictionary = invalid if envelope=="current" else invalid[envelope]
		target.actors[0].position[1] = -.02
		var control = Campaign.new()
		expect(control.from_dict(invalid),"Static legacy floor tolerance remains unchanged")
		var output = control.to_dict()
		var actual: Dictionary = output if envelope=="current" else output[envelope]
		var radius = Enemy.capsule_radius("guardian")
		var support = layout.capsule_floor_support(Vector2(actual.actors[0].position[0],actual.actors[0].position[2]),radius)
		expect(absf(actual.actors[0].position[1]-support+.02)<.00002,"Old invalid negative capsule clearance is not laundered")
	# Compare direct player shift with the exact unchanged center-delta path.
	var point = old.world_position([19.75,31.25])+Vector3.UP*.2
	var shifted = state._shift_floor([point.x,point.y,point.z],old,layout,true)
	expect(absf(shifted[1]-(point.y+layout.world_position([19.75,31.25]).y-old.world_position([19.75,31.25]).y))<.00002,"Player center delta unchanged")
	print("CAPSULE_TRUST_CASES envelopes=3 atomic_rejections=30 player_recovery=6 signed_invalid=3")

func check_born_crawler(document: Dictionary, old, layout) -> void:
	var owner: Dictionary = old.data.enemies.filter(func(e): return e.kind=="summoner")[0]
	var specs = Campaign.actor_specs(old)
	var born = document.duplicate(true)
	var point = old.world_position([19.75,31.25])+Vector3.UP*.03
	var add_id: String = owner.id+"_add_1"
	expect(specs[add_id].kind=="crawler" and specs[add_id].owner==owner.id,"Shared actor_specs resolves born crawler role")
	for snapshot in [born,born.checkpoint,born.level_start]:
		if not specs[owner.id].encounter.is_empty(): snapshot.removed.append("encounter:"+specs[owner.id].encounter)
		snapshot.removed.append("summon:"+owner.id+":1")
		snapshot.actors.append({"id":add_id,"position":[point.x,point.y,point.z],"hp":17,"yaw":Enemy.canonical_yaw(-.6),"alerted":true})
	var before = var_to_bytes(born)
	var control = Campaign.new()
	expect(control._valid_actor_resources(born,old,1) and control.from_dict(born),"Real summoner birth history migrates with authored dead owner unchanged")
	var migrated = control.to_dict()
	for name in ["current","checkpoint","level_start"]:
		var a: Dictionary = born if name=="current" else born[name]
		var b: Dictionary = migrated if name=="current" else migrated[name]
		var add: Dictionary = b.actors[1]
		var support = layout.capsule_floor_support(Vector2(point.x,point.z),Enemy.capsule_radius("crawler"))
		expect(absf(add.position[1]-support-.03)<.00002,"Born crawler uses shared crawler radius in every envelope")
		expect(b.removed==a.removed and add.id==a.actors[1].id and add.hp==17 and add.yaw==a.actors[1].yaw and add.alerted,"Birth history and add identity/state remain unchanged")
	var again = Campaign.new()
	expect(var_to_bytes(born)==before and again.from_dict(migrated) and again.to_dict()==migrated,"Born history input immutable and current revision idempotent")
	print("CAPSULE_BORN_CASES envelopes=3 shared_role=crawler birth_history_preserved=true")
