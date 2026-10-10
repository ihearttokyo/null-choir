extends SceneTree

class WorldOwner extends Node3D:
	var state = preload("res://scripts/campaign.gd").new()
	var level

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var owner = WorldOwner.new()
	root.add_child(owner)
	for index in range(8):
		owner.state.new_campaign(1)
		owner.level = load("res://scripts/level.gd").new()
		owner.add_child(owner.level)
		owner.level.build(owner,index)
		var expected = 0
		for hero in owner.level.layout.data.heroes:
			if hero.has("base"): expected += 1
		for prop in owner.level.layout.data.scenery:
			if prop.has("solid"): expected += 1
			expected += prop.get("supports",[]).size()
		var envelopes = 0
		for node in owner.level.get_children():
			if node is not StaticBody3D: continue
			if node.get_children().any(func(child): return child is MeshInstance3D): continue
			envelopes += 1
			if not expect(node.get_child_count() == 1 and node.get_child(0) is CollisionShape3D and node.collision_layer == 1,"Collision-only envelopes retain one native solid shape, without mesh/material nodes"): return
		if not expect(envelopes == expected and expected > 0,"All authored hidden landmark/scenery envelopes avoid unused rendering allocations"): return
		for hero in owner.level.layout.data.heroes:
			if not hero.has("base"): continue
			var body = owner.level.get_node("LandmarkBase_"+hero.id)
			var shape = body.get_child(0).shape
			if not expect(shape is CylinderShape3D if hero.get("round",false) else shape is BoxShape3D,"Authored round/box collision types stay intact"): return
			if shape is CylinderShape3D:
				if not expect(is_equal_approx(shape.radius,hero.base[0]/2) and is_equal_approx(shape.height,hero.base[1]),"Authored round envelope dimensions stay intact"): return
			elif not expect(shape.size == Vector3(hero.base[0],hero.base[1],hero.base[2]),"Authored box envelope dimensions stay intact"): return
			if not expect(body.position.is_equal_approx(owner.level.layout.world_position(hero.cell)+Vector3.UP*(hero.base[1]/2)),"Authored envelope placement stays intact"): return
			if not expect(is_equal_approx(body.rotation.y,deg_to_rad(hero.yaw)),"Authored envelope yaw stays intact"): return
		print("MEASURE collision_only level=",index," native_envelopes=",envelopes)
		if index in [0,1]:
			var id = owner.level.doors.keys()[0]
			var door = owner.level.doors[id]
			owner.level.open_door(id)
			if not expect(door.collision_layer == 0 and not owner.level.doors.has(id) and not door.is_queued_for_deletion(),"Opening releases collision immediately but retains the visible moving door"): return
			if index == 0:
				await create_timer(0.8).timeout
				await process_frame
				if not expect(not is_instance_valid(door),"Completed native opening tween frees its unreachable door"): return
			# Index one tears down the native level while its opening tween is live.
		owner.level.free()
		owner.level = null
		await process_frame
	owner.free()
	print("PASS eight authored collision-only worlds and native door opening/teardown lifetime")
	quit()

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
