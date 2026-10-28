extends SceneTree
const StaticSelectedLevel = preload("res://tests/fixtures/static_selected_level.gd")
## Cold production navigation endpoint evidence, not earned/physical traversal.
const Level = preload("res://scripts/level.gd")
const Campaign = preload("res://scripts/campaign.gd")
class Host extends Node:
	var level
	var state = Campaign.new()
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var host = Host.new()
	root.add_child(host)
	host.state = StaticSelectedLevel.fresh_selected(5,1)
	var level = Level.new()
	host.level = level
	host.add_child(level)
	if not level.build(host,5):
		push_error(level.layout.load_error)
		quit(2)
		return
	var routes = level.get_node("NavigationRoutes")
	var deadline = Time.get_ticks_usec()+10000000
	while Time.get_ticks_usec() < deadline and not (routes.is_ready("worker") and routes.is_ready("crawler")):
		OS.delay_msec(2)
		await process_frame
		await physics_frame
	for role in ["worker","crawler"]:
		expect(routes.is_ready(role),"Revision2 native navigation ready: "+role)
		for pair in [[[9,18],[19,18]],[[9,18],[13,18]],[[14,18],[19,18]],[[19,18],[19,24]],[[25,9],[33,9]]]:
			for reverse in [false,true]:
				var a: Array = pair[1] if reverse else pair[0]
				var b: Array = pair[0] if reverse else pair[1]
				var start = level.layout.world_position(a)+Vector3.UP*0.03
				var goal = level.layout.world_position(b)+Vector3.UP*0.03
				var path: PackedVector3Array = routes.route(start,goal,role)
				expect(not path.is_empty(),"Bidirectional actual crossing/retained route "+role+str(a)+" -> "+str(b))
				if not path.is_empty(): expect(path[-1].distance_to(goal)<0.29,"Endpoint reaches actual authored landing")
				await physics_frame
	host.level = null
	level.free()
	host.free()
	await physics_frame
	print("Ossuary crossing2 native navigation failures=",failures,"; not physical-input/earned/visual acceptance")
	quit(0 if failures == 0 else 1)
