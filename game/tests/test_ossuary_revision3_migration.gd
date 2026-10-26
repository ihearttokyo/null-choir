extends SceneTree
## DRAFT: integrate only alongside reviewed V3 layout/strict clearance helper.
const Campaign=preload("res://scripts/campaign.gd")
const Layout=preload("res://scripts/level_data.gd")
const Enemy=preload("res://scripts/enemy.gd")
func _initialize() -> void:
	var current=Layout.new()
	if not check(current.load_level(5) and current.floor_revision()==3,"Actual opt-in Ossuary3 recipe required"):return
	var original_v2=JSON.parse_string(FileAccess.get_file_as_string("res://data/floors/revision2/ossuary.json"))
	var v2=current.floor_at_revision(5,2)
	if not check(v2!=null and v2.floor_revision()==2 and v2.data==original_v2 and not v2.data.has("terrain_patch"),"Exact complete V2 source lookup, no V3 recipe leakage"):return
	if not check(is_equal_approx(current.capsule_floor_support(Vector2(30,74),0.32),1.0),"Independent trench bed1.0 at exposed safe migration sample"):return
	var spec: Dictionary=v2.data.enemies.filter(func(e):return e.kind=="guardian")[0]
	for revision in [0,1,2]:
		var old=current.floor_at_revision(5,revision)
		if not check(old!=null and old.floor_revision()==revision and not old.data.has("terrain_patch"),"All exact old revisions resolve without new patch"):return
		var center=Vector2(30,74) # Old bank, now intended open trench bed, outside deck/supports.
		var old_player=old.capsule_floor_support(center,0.32)-0.024
		var radius=Enemy.capsule_radius(spec.kind)
		var old_actor=old.capsule_floor_support(center,radius)+0.03
		var envelope={"health":73,"armor":21,"ammo":[0,37,3,4,5,6],"owned_weapons":[0,1,2],"weapon":2,"keys":[],"removed":[],"checkpoint_id":"entry","position":[30.0,old_player,74.0],"actors":[{"id":spec.id,"position":[30.0,old_actor,74.0],"hp":201,"yaw":Enemy.canonical_yaw(0.4),"alerted":false}]}
		for enemy in old.data.enemies:
			if enemy.id!=spec.id:envelope.removed.append(enemy.id)
		if revision>0:envelope.floor_revision=revision
		var document=envelope.duplicate(true)
		document.merge({"version":1 if revision==0 else 2,"difficulty":1,"level_index":5,"discoveries":[0,1],"explored":[],"checkpoint":envelope.duplicate(true),"level_start":envelope.duplicate(true)})
		var path="user://ossuary_v3_migration_"+str(revision)+"_"+str(Time.get_ticks_usec())+".json"
		var raw=JSON.stringify(document);var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(raw);file.close()
		var state=Campaign.new()
		if not check(state.load_progress(path),"Safe old bank/pit-XZ pose must migrate geometrically, not be discarded"):return
		if not check(FileAccess.get_file_as_string(path)==raw and not FileAccess.file_exists(path+".tmp"),"Migration in memory only; exact original save retained"):return
		var migrated=state.to_dict()
		for key in ["current","checkpoint","level_start"]:
			var before: Dictionary=document if key=="current" else document[key]
			var after: Dictionary=migrated if key=="current" else migrated[key]
			if not check(after.floor_revision==3 and after.position[0]==30 and after.position[2]==74,"Three envelopes preserve horizontal coordinates"):return
			if not check(absf(after.position[1]-current.capsule_floor_support(center,0.32)+0.024)<0.00001,"Actual player sphere support signed clearance preserved"):return
			if not check(absf(after.actors[0].position[1]-current.capsule_floor_support(center,radius)-0.03)<0.00001,"Actual guardian sphere support signed clearance preserved"):return
			for field in ["health","armor","ammo","owned_weapons","weapon","keys","removed","checkpoint_id"]:
				if not check(before[field]==after[field],"No resource/progress/checkpoint grants: "+field):return
			for field in ["id","hp","yaw","alerted"]:
				if not check(before.actors[0][field]==after.actors[0][field],"Actor identity/combat state retained: "+field):return
		if not check(migrated.discoveries==document.discoveries,"Records preserved exactly"):return
		if not check(state.save_progress(path)==OK,"Only normal atomic Save persists migration"):return
		var reload=Campaign.new()
		if not check(reload.load_progress(path) and JSON.parse_string(JSON.stringify(reload.to_dict()))==JSON.parse_string(JSON.stringify(state.to_dict())),"Normal V3 disk roundtrip"):return
		var frozen=state.to_dict()
		var invalid=migrated.duplicate(true);invalid.actors[0].position[1]=-10
		if not check(not state.from_dict(invalid) and state.to_dict()==frozen,"Unsafe under-floor actor rejected atomically"):return
		invalid=migrated.duplicate(true);invalid.floor_revision=4
		if not check(not state.from_dict(invalid) and state.to_dict()==frozen,"Unsupported future revision rejected"):return
		DirAccess.remove_absolute(path)
	if not direct_bed_roundtrip(current,v2):return
	if not door_context_roundtrip(current,v2):return
	print("PASS draft Ossuary0/1/2to3 memory-only migration; no native geometry/collision/campaign acceptance claim")
	quit(0)
func check(ok: bool,message: String) -> bool:
	if not ok:push_error(message);quit(1)
	return ok

func direct_bed_roundtrip(current,old) -> bool:
	# Same XZ has a bed1.0 AND deck5.30: no default-upper warp on directV3 load.
	var center=Vector2(26,74)
	if not check(is_equal_approx(current.capsule_floor_support(center,0.32),5.30),"Authored default layer remains new deck5.30"):return false
	for role in ["worker","guardian","caster"]:
		var spec: Dictionary=old.data.enemies.filter(func(e):return e.kind==role)[0]
		var feet: float=2.0 if role=="caster" else 1.03
		var envelope={"floor_revision":3,"health":73,"armor":21,"ammo":[0,37,3,4,5,6],"owned_weapons":[0,1,2],"weapon":2,"keys":[],"removed":[],"checkpoint_id":"entry","position":[26.0,0.976,74.0],"actors":[{"id":spec.id,"position":[26.0,feet,74.0],"hp":Enemy.health_cap(role,1),"yaw":0.0,"alerted":false}]}
		for enemy in old.data.enemies:
			if enemy.id!=spec.id:envelope.removed.append(enemy.id)
		var doc=envelope.duplicate(true)
		doc.merge({"version":2,"difficulty":1,"level_index":5,"discoveries":[],"explored":[],"checkpoint":envelope.duplicate(true),"level_start":envelope.duplicate(true)})
		var state=Campaign.new()
		if not check(state.from_dict(doc),"DirectV3 actual bed-layer Player/"+role+" fits without standing-cap rejection"):return false
		var actual=state.to_dict()
		if not check(absf(actual.position[1]-0.976)<0.00001 and absf(actual.actors[0].position[1]-feet)<0.00001,"DirectV3 load must not remigrate/warp underdeck occupants"):return false
		if role=="caster":
			for hover in [1.84,2.0,2.16]:
				var hovering=doc.duplicate(true)
				hovering.actors[0].position[1]=hover
				hovering.checkpoint.actors[0].position[1]=hover
				hovering.level_start.actors[0].position[1]=hover
				if not check(state.from_dict(hovering),"Caster legitimate1±.16 hover remains pure-geometry safe belowdeck"):return false
		var penetration=doc.duplicate(true)
		for snapshot in [penetration,penetration.checkpoint,penetration.level_start]:
			snapshot.position[1]=0.955 # Physical Player foot .980: signed floor−.020.
			snapshot.actors[0].position[1]=0.98 # NPC physical foot−.020.
		if not check(state.from_dict(penetration),"Local valid signed floor−.02 remains unmodified, not sanitized"):return false
		if not check(absf(state.to_dict().position[1]-0.955)<0.00001 and absf(state.to_dict().actors[0].position[1]-0.98)<0.00001,"Accepted penetration preserves signed pose exactly"):return false
		var too_low=penetration.duplicate(true)
		too_low.actors[0].position[1]=0.91
		if not check(not state.from_dict(too_low),"Below historical floor−.08 policy still rejects"):return false
		var side=doc.duplicate(true)
		side.actors[0].position=[31.95,1.03,74.0]
		if not check(not state.from_dict(side),"Floor allowance must never permit actual trench SIDEwall penetration"):return false
		if not check(state.from_dict(doc),"Restore safe independent underdeck control"):return false
		var frozen=state.to_dict()
		var unsafe=doc.duplicate(true)
		# Capsule intersects physical deck underside, though bank roof remains clear.
		unsafe.actors[0].position[1]=5.0-Enemy.capsule_height(role)+0.10
		if not check(not state.from_dict(unsafe) and state.to_dict()==frozen,"Physical deck underside must reject unsafe occupancy without changing progress"):return false
	return true

func door_context_roundtrip(current,old) -> bool:
	var door: Dictionary=old.data.doors[0]
	var center: Vector3=current.world_position(door.cell)
	var door_pose=[center.x,center.y-0.024,center.z]
	var envelope={"floor_revision":3,"health":73,"armor":21,"ammo":[0,37,3,4,5,6],"owned_weapons":[0,1,2],"weapon":2,"keys":["blood","ivory"],"removed":[],"checkpoint_id":"entry","position":door_pose,"actors":[]}
	for enemy in old.data.enemies:envelope.removed.append(enemy.id)
	var closed=envelope.duplicate(true)
	closed.merge({"version":2,"difficulty":1,"level_index":5,"discoveries":[],"explored":[],"checkpoint":envelope.duplicate(true),"level_start":envelope.duplicate(true)})
	var state=Campaign.new()
	if not check(state.from_dict(closed),"Outside changed patch retains historical Campaign doorway trust"):return false
	if not check(not current.migration_capsule_clearance(Vector3(door_pose[0],door_pose[1],door_pose[2]),0.32,1.65,0.025,closed.removed),"Explicit pure geometry still rejects actual closed doorway overlap"):return false
	var opened=closed.duplicate(true)
	for snapshot in [opened,opened.checkpoint,opened.level_start]:snapshot.removed.append(door.id)
	if not check(state.from_dict(opened),"Exact known removed door remains a valid saved context"):return false
	for snapshot in [opened,opened.checkpoint,opened.level_start]:
		if not check(current.migration_capsule_clearance(Vector3(door_pose[0],door_pose[1],door_pose[2]),0.32,1.65,0.025,snapshot.removed),"Explicit pure geometry uses each own known-open context"):return false
	var mixed=opened.duplicate(true)
	mixed.checkpoint.removed.erase(door.id)
	if not check(not current.migration_capsule_clearance(Vector3(door_pose[0],door_pose[1],door_pose[2]),0.32,1.65,0.025,mixed.checkpoint.removed),"Pure geometry older checkpoint retains its own closed door"):return false
	mixed.level_start.removed.erase(door.id)
	if not check(not current.migration_capsule_clearance(Vector3(door_pose[0],door_pose[1],door_pose[2]),0.32,1.65,0.025,mixed.level_start.removed),"Pure geometry older level_start retains its own closed door"):return false
	if not check(state.from_dict(mixed),"New local patch must not invent global closed-door Campaign prerequisite"):return false
	var worker: Dictionary=old.data.enemies.filter(func(e):return e.kind=="worker")[0]
	if not check(current.migration_capsule_clearance(center+Vector3.UP*0.03,Enemy.capsule_radius("worker"),Enemy.capsule_height("worker"),0.0,opened.removed),"Explicit known-open NPC doorway clearance"):return false
	if not check(not current.migration_capsule_clearance(center+Vector3.UP*0.03,Enemy.capsule_radius("worker"),Enemy.capsule_height("worker"),0.0,closed.removed),"Explicit closed NPC doorway geometry remains strict"):return false
	var unknown=opened.duplicate(true)
	unknown.removed.append("unknown_collision_bypass")
	if not check(not state.from_dict(unknown),"Unknown removal cannot disable arbitrary collision or bypass original ID validation"):return false
	return true
