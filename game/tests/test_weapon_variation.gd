extends SceneTree
# Prepared actual GDScript controls; NOT run by the patch author.
const Variation = preload("res://scripts/weapon_variation.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Preferences = preload("res://scripts/preferences.gd")
class FireHost extends Node3D:
	var state = Campaign.new()
	var playing: bool = false
	var level: Node3D
	var player
	var enemies: Array = []
	var settings: Dictionary = {}
	var stop_on_shot: bool = false
	func shot(_weapon: int) -> void:
		if stop_on_shot: playing = false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Preferences.new().apply_bindings()
	assert(InputMap.has_action("fire"))
	for sequence in [0,1,17,2147483646]:
		for weapon in range(6):
			var sample: float = Variation.unit(sequence,weapon,0)
			assert(sample >= 0 and sample < 1 and sample == Variation.unit(sequence,weapon,0))
			assert(Variation.disk(sequence,weapon,2).length() <= 1.000001)
		assert(Variation.scatter(sequence,0,Vector2.ZERO) == Vector2.ZERO)
		assert(Variation.scatter(sequence,1,Vector2(-.065,0)).length() <= .070001)
	assert(Variation.MARROW_SPEED == 24.0)
	var state = Campaign.new()
	state.new_campaign(1)
	state.shot_sequence = [4,5,6,7,8,9]
	state.repeater_heat = .028
	state.mark_checkpoint("entry",Vector3.ZERO)
	var document: Dictionary = state.to_dict()
	var restored = Campaign.new()
	assert(restored.from_dict(document) and restored.to_dict() == document)
	for envelope in ["current","checkpoint","level_start"]:
		for invalid in [[],[0,0,0,0,0],[0,0,0,0,0,-1],[0,0,0,0,0,2147483647],[0,0,0,0,0,true],[0,0,0,0,0,.5]]:
			var bad = document.duplicate(true)
			var target: Dictionary = bad if envelope == "current" else bad[envelope]
			target.shot_sequence = invalid
			assert(not restored.from_dict(bad) and restored.to_dict() == document)
	# Exact checkpoint replay; each owning envelope restores its own next index.
	restored.repeater_heat = .064
	restored.shot_sequence = [10,11,12,13,14,15]
	restored.restore_checkpoint()
	assert(restored.repeater_heat == .028)
	assert(restored.shot_sequence == [4,5,6,7,8,9])
	restored.repeater_heat = .064
	restored.shot_sequence = [20,21,22,23,24,25]
	restored.restore_level_start()
	assert(restored.repeater_heat == .028)
	assert(restored.shot_sequence == [4,5,6,7,8,9])
	restored.complete_level()
	assert(restored.repeater_heat == 0.0)
	assert(restored.shot_sequence == [4,5,6,7,8,9])
	for envelope in ["current","checkpoint","level_start"]:
		assert(restored.from_dict(document))
		for invalid in [-.001,.071,true,"0",null,INF,NAN]:
			var bad = document.duplicate(true)
			var target: Dictionary = bad if envelope == "current" else bad[envelope]
			target.repeater_heat = invalid
			assert(not restored.from_dict(bad) and restored.to_dict() == document)
	var legacy = document.duplicate(true)
	for snapshot in [legacy,legacy.checkpoint,legacy.level_start]:
		snapshot.erase("shot_sequence")
		snapshot.erase("repeater_heat")
	assert(restored.from_dict(legacy))
	assert(restored.shot_sequence == [0,0,0,0,0,0] and restored.checkpoint.shot_sequence == [0,0,0,0,0,0] and restored.level_start.shot_sequence == [0,0,0,0,0,0])
	assert(restored.repeater_heat == 0 and restored.checkpoint.repeater_heat == 0 and restored.level_start.repeater_heat == 0)
	var host = FireHost.new()
	root.add_child(host)
	host.state.new_campaign(1)
	host.level = Node3D.new()
	host.add_child(host.level)
	host.player = preload("res://scripts/player.gd").new()
	host.level.add_child(host.player)
	host.state.repeater_heat = .028
	host.player.configure(host)
	assert(host.player._repeater_spread == .028) # Reconstruction must not reset.
	host.player._repeater_spread = .032
	assert(host.state.repeater_heat == .032)
	host.player.set_physics_process(false)
	await physics_frame
	assert(not host.player.fire() and host.state.shot_sequence == [0,0,0,0,0,0])
	host.playing = true
	assert(host.player.fire() and host.state.shot_sequence == [0,1,0,0,0,0] and host.player.last_shot_sequence(1) == 0)
	assert(not host.player.fire() and host.state.shot_sequence[1] == 1) # Cooldown.
	host.player.cooldown = 0
	host.state.ammo[1] = 0
	assert(not host.player.fire() and host.state.shot_sequence[1] == 1) # Dry fire.
	host.state.weapon = 1
	host.state.ammo[1] = 10
	host.state.health = 0
	assert(not host.player.fire() and host.state.shot_sequence[1] == 1)
	host.state.health = 100
	host.stop_on_shot = true
	assert(host.player.fire() and host.state.shot_sequence[1] == 2 and not host.playing)
	# Reentrant stop consumes the accepted shot exactly once; never a later query.
	host.queue_free()
	print("PASS deterministic weapon variation/counter codec/fire transaction controls; not pixels/balance acceptance")
	quit(0)
