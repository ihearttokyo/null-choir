extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/main.gd").new()
	game.progress_path = "user://traversal_contract.json"
	root.add_child(game)
	game.start_campaign(0)
	game.set_process(false)
	game.player.set_physics_process(false)
	for actor in game.enemies:
		actor.set_physics_process(false)
		actor.collision_layer = 0
	game.settings.head_bob = false
	var layout = game.level.layout
	for loop in layout.data.loops:
		var first = loop.route[0]
		game.player.position = layout.world_position([first[0]+0.5,first[1]+0.5])+Vector3(0,0.04,0)
		game.player.velocity = Vector3.ZERO
		for i in range(loop.route.size()-1):
			var start = Vector2i(loop.route[i][0],loop.route[i][1])
			var finish = Vector2i(loop.route[i+1][0],loop.route[i+1][1])
			var route = cell_path(layout,start,finish)
			if not expect(not route.is_empty(),"No cell path: "+loop.id): return
			for cell in route:
				var target = layout.world_position([cell.x+0.5,cell.y+0.5])
				var reached = false
				for frame in range(130):
					var offset = target-game.player.position
					offset.y = 0
					if offset.length() < 0.22:
						reached = true
						break
					var direction = offset.normalized()
					for binding in [["move_right",maxf(0,direction.x)],["move_left",maxf(0,-direction.x)],["move_back",maxf(0,direction.z)],["move_forward",maxf(0,-direction.z)]]:
						Input.action_press(binding[0],binding[1])
					await physics_frame
					game.player._physics_process(1.0/60.0)
				if not expect(reached,"Blocked traversal "+loop.id+" at "+str(cell)+" player "+str(game.player.position)): return
				if not expect(absf(game.player.position.y-target.y) < 0.3,"Floor/ramp height mismatch at "+str(cell)): return
		print("TRAVERSED "+loop.id+" / "+loop.hero)
	for action in ["move_right","move_left","move_back","move_forward"]: Input.action_release(action)
	game.pause_game()
	game.queue_free()
	paused = false
	if FileAccess.file_exists(game.progress_path): DirAccess.remove_absolute(game.progress_path)
	print("PASS native capsule traverses both authored Intake loops without jumping or falling")
	quit()

func cell_path(layout, start: Vector2i, finish: Vector2i) -> Array:
	var queue = [start]
	var previous = {start:start}
	var cursor = 0
	while cursor < queue.size():
		var cell = queue[cursor]
		cursor += 1
		if cell == finish:
			var result = [cell]
			while cell != start:
				cell = previous[cell]
				result.push_front(cell)
			return result
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next = cell+step
			if layout.is_walkable(next) and not previous.has(next):
				previous[next] = cell
				queue.append(next)
	return []

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
