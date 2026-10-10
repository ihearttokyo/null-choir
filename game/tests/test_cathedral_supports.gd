extends SceneTree
var game
func _initialize(): call_deferred("run")
func run():
	AudioServer.set_bus_mute(0,true)
	game=load("res://scripts/main.gd").new()
	game.settings_path="user://cathedral_support_preferences.json"
	game.progress_path="user://cathedral_support_progress.json"
	root.add_child(game)
	game.state.new_campaign(0)
	game.start_level()
	# Physics-only fixture; avoid creating mixer voices on the dummy display.
	game.music.set_paused(true)
	game.set_process(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	await physics_frame
	await physics_frame
	var boxes=game.level.get_children().filter(func(n):return n.name.begins_with("ScenerySupport_"))
	if not expect(boxes.size()==36,"INTENDED RED: all eighteen arches need two physical supports, not ghost pillars"):return
	var layout=game.level.layout
	var index=0
	for spec in layout.data.scenery:
		var scale_model=Vector3.ONE
		if spec.has("scale"):scale_model=Vector3(spec.scale[0],spec.scale[1],spec.scale[2])
		for support in spec.get("supports",[]):
			var box=boxes[index];index+=1
			var size=Vector3(support.size[0],support.size[1],support.size[2])*scale_model
			var offset=Vector3(support.offset[0],support.offset[1],support.offset[2])*scale_model
			var base=layout.world_position(spec.cell)+Vector3.UP*spec.get("height",0)
			var expected=base+offset.rotated(Vector3.UP,deg_to_rad(spec.get("yaw",0)))+Vector3.UP*size.y/2
			if not expect(box is StaticBody3D and box.get_child(0).shape is BoxShape3D and box.position.is_equal_approx(expected) and box.get_child(0).shape.size.is_equal_approx(size),"Support scale/yaw/ground transforms must match the actual art"):return
			var q=PhysicsRayQueryParameters3D.create(box.position+Vector3.UP*(size.y/2+.1),box.position,1)
			var hit=game.level.get_world_3d().direct_space_state.intersect_ray(q)
			if not expect(not hit.is_empty() and hit.collider==box,"Native visible post must physically block its base"):return
	if not expect(game._valid_restored_actors(),"Authored living actors must clear the new supports"):return
	for loop in layout.data.loops:
		for i in range(loop.route.size()-1):
			var a=Vector2(loop.route[i][0]+.5,loop.route[i][1]+.5)
			var b=Vector2(loop.route[i+1][0]+.5,loop.route[i+1][1]+.5)
			var count=ceili(a.distance_to(b)*4/.2)
			for step in range(count+1):
				var p=a.lerp(b,float(step)/maxi(count,1))
				var location=layout.world_position([p.x,p.y])
				var collider=game.player.get_child(0)
				var q=PhysicsShapeQueryParameters3D.new();q.shape=collider.shape
				q.transform=Transform3D(Basis.IDENTITY,location+Vector3.UP*.04)*collider.transform
				q.collision_mask=1;q.exclude=[game.player.get_rid()]
				# Existing props may need steering; this checks new post regression only.
				for hit in game.level.get_world_3d().direct_space_state.intersect_shape(q,32):
					if not expect(not hit.collider.name.begins_with("ScenerySupport_"),"New post obstructs original closed route: "+loop.id+" "+str(p)):return
	print("PASS native 36 physical supports, original actor clearance and both closed loop polylines")
	game._finish_quit()
func expect(ok:bool,why:String)->bool:
	if not ok:
		push_error(why)
		fail_clean()
		return false
	return true

func fail_clean():
	await game._finish_quit()
	quit(1)
