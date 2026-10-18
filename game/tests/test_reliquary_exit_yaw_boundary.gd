extends SceneTree
const ExitFixture = preload("res://tests/test_reliquary_earned_exit.gd")
func _initialize() -> void:
	var observer = ExitFixture.ReliquaryExitMain.new()
	var negative_pi32: float = Vector3(0,-PI,0).y
	var positive_pi32: float = Vector3(0,PI,0).y
	var minimum: float = Vector3(0,-3.1415925,0).y
	var result: bool = observer.e_yaw(negative_pi32) == minimum and observer.e_yaw(positive_pi32) == minimum and observer.e_yaw(0.0) == 0.0 and observer.e_yaw(1.0) == 1.0 and observer.e_yaw(-1.0) == -1.0
	print("EXIT_YAW_BOUNDARY negative=",observer.e_yaw(negative_pi32)," positive=",observer.e_yaw(positive_pi32)," expected=",minimum)
	observer.free()
	if not result: push_error("NATIVE RED Exit checkpoint independent yaw must preserve Godot float32 negative-PI canonical boundary")
	else: print("PASS detached Exit checkpoint yaw boundaries; no profile or scene adoption")
	quit(0 if result else 1)
