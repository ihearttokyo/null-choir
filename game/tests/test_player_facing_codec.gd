extends SceneTree

const Campaign = preload("res://scripts/campaign.gd")
const Enemy = preload("res://scripts/enemy.gd")

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func expect(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		quit(1)
	return ok

func run() -> void:
	var original = Campaign.new()
	original.new_campaign(1)
	var document: Dictionary = original.to_dict()
	document.yaw = .7
	document.pitch = -.4
	document.checkpoint.yaw = -1.2
	document.checkpoint.pitch = .6
	document.level_start.yaw = 2.1
	document.level_start.pitch = -.8
	var state = Campaign.new()
	if not expect(state.from_dict(document),"Valid three-envelope facing must decode"): return
	var restored: Dictionary = state.to_dict()
	if not expect(is_equal_approx(restored.get("yaw",INF),.7) and is_equal_approx(restored.get("pitch",INF),-.4),"INTENDED RED current facing survives actual codec roundtrip"): return
	state.restore_checkpoint()
	if not expect(is_equal_approx(state.to_dict().get("yaw",INF),-1.2) and is_equal_approx(state.to_dict().get("pitch",INF),.6),"Checkpoint chooses its own facing rather than current/entry"): return
	state.restore_level_start()
	if not expect(is_equal_approx(state.to_dict().get("yaw",INF),2.1) and is_equal_approx(state.to_dict().get("pitch",INF),-.8),"Restart chooses its own entry facing"): return
	for field in ["yaw","pitch"]:
		for envelope in ["current","checkpoint","level_start"]:
			for value in [null,true,"0",[],{},NAN,INF,-INF]:
				var bad: Dictionary = document.duplicate(true)
				var target: Dictionary = bad if envelope == "current" else bad[envelope]
				target[field] = value
				var before: Dictionary = state.to_dict().duplicate(true)
				if not expect(not state.from_dict(bad) and state.to_dict() == before,"Malformed present facing rejects atomically: "+envelope+"/"+field+"/"+str(value)): return
	for pitch in [-1.35001,1.35001]:
		for envelope in ["current","checkpoint","level_start"]:
			var bad: Dictionary = document.duplicate(true)
			var target: Dictionary = bad if envelope == "current" else bad[envelope]
			target.pitch = pitch
			var before: Dictionary = state.to_dict().duplicate(true)
			if not expect(not state.from_dict(bad) and state.to_dict() == before,"Pitch outside native look limit rejects entire envelope"): return
	for yaw in [-PI,PI,TAU*3+.25,-TAU*2-.5,1e100,-1e308]:
		for pitch in [-1.35,1.35]:
			var valid: Dictionary = document.duplicate(true)
			valid.yaw = yaw
			valid.pitch = pitch
			if not expect(state.from_dict(valid),"Finite yaw/camera boundary remains valid"): return
			var pose: Dictionary = state.to_dict()
			if not expect(pose.yaw == Enemy.canonical_yaw(yaw) and pose.yaw >= -PI and pose.yaw < PI and pose.pitch == pitch,"Yaw uses exact existing actor canonical policy; pitch boundaries stay exact"): return
	var legacy: Dictionary = document.duplicate(true)
	for envelope in [legacy,legacy.checkpoint,legacy.level_start]:
		envelope.erase("yaw")
		envelope.erase("pitch")
	if not expect(state.from_dict(legacy) and not state.to_dict().has("yaw") and not state.to_dict().has("pitch"),"Legacy missing facing remains unknown until authored reconstruction"): return
	var mixed: Dictionary = document.duplicate(true)
	mixed.checkpoint.erase("yaw")
	mixed.checkpoint.erase("pitch")
	if not expect(state.from_dict(mixed),"Legacy checkpoint coexists with current facing"): return
	state.restore_checkpoint()
	if not expect(not state.to_dict().has("yaw") and not state.to_dict().has("pitch"),"Legacy checkpoint omission cannot inherit current envelope facing"): return
	state.from_dict(document)
	state.complete_level()
	if not expect(not state.to_dict().has("yaw") and not state.to_dict().has("pitch"),"Ordinary next level resets to authored entry policy"): return
	state.from_dict(document)
	state.new_campaign(2)
	if not expect(not state.to_dict().has("yaw") and not state.to_dict().has("pitch"),"New campaign clears previous player facing"): return
	print("PASS optional facing codec: distinct envelopes, legacy omission, finite/canonical bounds and atomic malformed rejection")
	quit(0)
