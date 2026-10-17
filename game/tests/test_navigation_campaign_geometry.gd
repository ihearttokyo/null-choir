extends SceneTree

# Cold native geometry and varied server queries, not Enemy AI or game FPS.
const Level = preload("res://scripts/level.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Owner = preload("res://scripts/navigation_routes.gd")
const Campaign = preload("res://scripts/campaign.gd")
class Host extends Node:
	var level
	var state = Campaign.new()
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(condition: bool, detail: String) -> void:
	if condition: return
	failures += 1
	push_error(detail)
func run() -> void:
	var host := Host.new()
	root.add_child(host)
	for index in range(8):
		host.state.new_campaign(1)
		host.state.level_index = index
		var level = Level.new()
		host.level = level
		host.add_child(level)
		var construction_started := Time.get_ticks_usec()
		level.build(host,index)
		var routes = level.get_node("NavigationRoutes")
		var profiles := {}
		var records: Dictionary = {}
		for record in level.layout.data.enemies:
			if Enemy.LATE.get(record.kind,{}).get("speed",1.0) == 0: continue
			profiles[record.kind] = {"radius":Enemy.capsule_radius(record.kind),"height":Enemy.capsule_height(record.kind),"hover":1.16 if record.kind in ["caster","choir_avatar"] else 0.0}
			records[record.kind] = record
		var started := construction_started
		expect(routes._roles.keys() == profiles.keys(),"Actual production owner configures authored moving-role profiles")
		var wait_deadline := Time.get_ticks_usec()+10000000
		while Time.get_ticks_usec() < wait_deadline:
			OS.delay_msec(2) # Native synchronization is wall-clock work under --fixed-fps.
			await process_frame
			await physics_frame
			var syncing := false
			for entry in routes._roles.values(): syncing = syncing or entry.sync
			if not routes._dirty and routes._pending.is_empty() and routes._baking.is_empty() and not syncing: break
		var cold_us := Time.get_ticks_usec()-started
		var role_report := {}
		for role in profiles:
			var entry: Dictionary = routes._roles[role]
			expect(entry.ready,"Campaign role has some navigable geometry: "+str(index)+"/"+role)
			var from: Vector3 = level.layout.world_position(records[role].cell)+Vector3.UP*.03
			var near: Vector3 = NavigationServer3D.map_get_closest_point(entry.map,from)
			var witness_near: Vector3 = NavigationServer3D.map_get_closest_point(entry.map,entry.witness)
			print("CAMPAIGN_NATIVE_ENDPOINT ",JSON.stringify({"level":index,"role":role,"from":str(from),"closest":str(near),"gap":from.distance_to(near),"witness":str(entry.witness),"witness_gap":entry.witness.distance_to(witness_near),"self_points":NavigationServer3D.map_get_path(entry.map,entry.witness,entry.witness,true,1).size(),"ready":entry.ready}))
			var reached := 0
			var attempted := 0
			var queries_us := 0
			for target in level.layout.data.pickups+level.layout.data.interactions:
				if attempted >= 20: break
				var goal: Vector3 = level.layout.world_position(target.cell)+Vector3.UP*.03
				var query_started := Time.get_ticks_usec()
				var path: PackedVector3Array = routes.route(from,goal,role)
				queries_us += Time.get_ticks_usec()-query_started
				attempted += 1
				if not path.is_empty():
					reached += 1
					expect(path[-1].distance_to(goal) < Owner.ENDPOINT_TOLERANCE+.04,"Returned campaign route reaches legitimate endpoint")
					for point in path: expect(point.is_finite(),"Native campaign routes remain finite")
				await physics_frame
			role_report[role] = {"polygons":entry.mesh.get_polygon_count(),"vertices":entry.mesh.get_vertices().size(),"attempted":attempted,"reachable":reached,"queries_us":queries_us}
		print("CAMPAIGN_NATIVE_GEOMETRY ",JSON.stringify({"level":index,"tiles":level.layout.tiles.size(),"cold_us":cold_us,"source_coordinates":routes._source.get_vertices().size(),"roles":role_report,"not_ai_or_fps":true,"memory_static_mesh_counts_only":true}))
		for door_id in level.doors: level.open_door(door_id)
		routes.invalidate_doors()
		wait_deadline = Time.get_ticks_usec()+10000000
		while Time.get_ticks_usec() < wait_deadline:
			OS.delay_msec(2)
			await process_frame
			await physics_frame
			var syncing := false
			for entry in routes._roles.values(): syncing = syncing or entry.sync
			if not routes._dirty and routes._pending.is_empty() and routes._baking.is_empty() and not syncing: break
		for role in profiles:
			var reached := 0
			var attempted := 0
			expect(routes.is_ready(role),"Opened campaign doors finish native role synchronization: "+str(index)+"/"+role)
			var from: Vector3 = level.layout.world_position(records[role].cell)+Vector3.UP*.03
			for target in level.layout.data.pickups+level.layout.data.interactions:
				if attempted >= 20: break
				var goal: Vector3 = level.layout.world_position(target.cell)+Vector3.UP*.03
				if not routes.route(from,goal,role).is_empty(): reached += 1
				attempted += 1
				await physics_frame
			print("CAMPAIGN_NATIVE_OPEN ",JSON.stringify({"level":index,"role":role,"attempted":attempted,"reachable":reached,"ready":routes.is_ready(role)}))
		var maps: Array[RID] = []
		for entry in routes._roles.values(): maps.append(entry.map)
		host.level = null
		level.free()
		await physics_frame
		await physics_frame
		for map in maps: expect(not NavigationServer3D.get_maps().has(map),"Campaign owner releases role map")
	host.free()
	if failures == 0: print("PASS eight-map native geometry ownership/varied route diagnostics; no AI/FPS/app claim")
	quit(0 if failures == 0 else 1)
