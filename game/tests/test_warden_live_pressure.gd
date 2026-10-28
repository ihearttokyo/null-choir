extends SceneTree
## Prepared native regression, deliberately not run during source-only work.
## Controlled flat arena, but real Main/Player/Enemy/configuration/AI/atlas/query/fire.
class NativeGame extends "res://scripts/main.gd":
	var shots: Array[int] = []
	func _ready() -> void:
		set_process(false)
		preload("res://scripts/preferences.gd").new().apply_bindings()
	func shot(index: int) -> void:
		shots.append(index)
		super.shot(index)

const Query = preload("res://scripts/sprite_hit_query.gd")
const PressureWindow = preload("res://scripts/warden_pressure_window.gd")
const Variation = preload("res://scripts/weapon_variation.gd")
const WARDEN_ID := "nursery_warden"
const NODE_PIXEL := Vector2i(129,142) # Current first texel in the pinned source/RLE contour.
const OPAQUE_NON_NODE_PIXEL := Vector2i(125,142) # Pinned opaque in-envelope but unlabeled witness.
const MAX_WAIT_TICKS := 180
var failures := 0

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func check(condition: bool, detail: String) -> void:
	if condition: return
	failures += 1
	push_error("WARDEN LIVE PRESSURE: "+detail)

func _authored_warden_spec(layout) -> Dictionary:
	for spec in layout.data.get("enemies",[]):
		if spec.get("id") == WARDEN_ID and spec.get("kind") == WARDEN_ID: return spec.duplicate(true)
	return {}

func _arena() -> Dictionary:
	var game = NativeGame.new()
	root.add_child(game)
	game.state.new_campaign(1)
	game.level = game.Level.new()
	game.add_child(game.level)
	if not game.level.layout.load_level(4):
		check(false,"actual Nursery source data loads")
		game.free()
		return {}
	var spec := _authored_warden_spec(game.level.layout)
	if spec.is_empty():
		check(false,"actual 05_nursery.json Nursery Warden id/kind spec exists")
		game.free()
		return {}
	var authored_boss_profile: Dictionary = spec.get("door_warden",{})
	check(spec.cell == [30.5,9.5] and spec.yaw == 180 and authored_boss_profile.get("attack_windup") == 1.2,"fixture spec is the exact authored 05_nursery Warden, not a synthetic replacement")
	game.playing = true
	var authored_position: Vector3 = game.level.layout.world_position(spec.cell)
	# Purpose-built physics floor at the authored Warden's actual height; no map walls,
	# navigation, actor position, target, telegraph or variant are edited by this test.
	var floor_root := Node3D.new()
	game.level.add_child(floor_root)
	floor_root.position = authored_position + Vector3(0,-0.1,6)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_root.add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(24,0.2,40)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	game.level.floor_bodies.append(floor_body)
	var player = game.Player.new()
	game.level.add_child(player)
	game.player = player
	player.configure(game)
	player.position = authored_position + Vector3(0,0.03,12)
	player.set_physics_process(true)
	game.settings.auto_aim = false
	game.state.weapon = 1
	var warden = game.Enemy.new()
	game.level.add_child(warden)
	warden.configure(game,spec)
	game.enemies = [warden]
	return {"game":game,"warden":warden,"player":player,"spec":spec,"authored_position":authored_position}

func _normal_window_open(warden, player) -> bool:
	return is_instance_valid(warden) and warden.hp > 0 and warden.active and warden.target == player and warden._committed_target == player and warden._committed_variant == 0 and warden.telegraph_time > 0 and warden.sprite.frame == 24

func _await_normal_window(warden, player) -> bool:
	for _frame in range(MAX_WAIT_TICKS):
		await physics_frame
		if _normal_window_open(warden,player): return true
	return _normal_window_open(warden,player)

func _aim_camera_at_cell(player, warden, pixel: Vector2i) -> bool:
	for _iteration in range(8):
		var geometry: Dictionary = Query._geometry(warden,player.camera)
		if geometry.is_empty(): return false
		var world_pixel: Vector3 = Query._world_pixel(geometry,Vector2i(0,768)+pixel)
		player.camera.look_at(world_pixel,Vector3.UP)
	var hit: Dictionary = Query.cast(player.get_world_3d().direct_space_state,player.camera.global_position,player.camera.global_position-player.camera.global_basis.z*140.0,player.camera,[warden],[player.get_rid()],1|4)
	return not hit.is_empty() and hit.get("collider") == warden and hit.get("coverage") == "visible_sprite" and hit.get("sprite_frame") == 24 and hit.get("frame_pixel") == pixel

func _fire_and_check_node_damage(game, warden, player, expected_damage: int, note: String) -> void:
	check(Engine.is_in_physics_frame(),note+": accepted fire is called in physics")
	var hp_before: int = warden.hp
	var ammo_before: int = game.state.ammo[1]
	var sequence_before: int = game.state.shot_sequence[1]
	var accepted: bool = player.fire()
	var observation: Dictionary = game.aim_observation
	var contact: Dictionary = observation.get("contact",{})
	check(accepted,note+": actual Player.fire accepts the Rivet shot")
	check(game.state.ammo[1] == ammo_before-1 and game.state.shot_sequence[1] == (sequence_before+1)%Variation.PERIOD and player.last_shot_sequence(1) == sequence_before,note+": one real accepted-fire transaction spends one round and advances one matching sequence")
	check(observation.get("tick") == Engine.get_physics_frames() and observation.get("level") == game.level and observation.get("player") == player and observation.get("actor_id") == WARDEN_ID and contact.get("collider") == warden and contact.get("frame_pixel") == NODE_PIXEL and contact.get("sprite_frame") == 24 and contact.get("coverage") == "visible_sprite",note+": actual aim/visible-contact/HP trace identifies the pinned live texel")
	check(hp_before-warden.hp == expected_damage,note+": observed enemy HP loss is exactly %d (was %d, now %d)" % [expected_damage,hp_before,warden.hp])
	check(game.shots == [1],note+": exactly one actual weapon discharge is recorded")

func _bonus_then_closed_non_node_case() -> void:
	var arena := _arena()
	if arena.is_empty(): return
	var game = arena.game
	var warden = arena.warden
	var player = arena.player
	check(warden.kind == WARDEN_ID and warden.id == WARDEN_ID and warden.active and warden.hp > 0,"fixture uses the actual configured Nursery actor/spec")
	check(warden.champion.get("attack_windup",0.0) == 1.2 and warden._attack_variant == 0,"authored Nursery Warden profile retains its first normal variant / windup")
	var reached_window: bool = await _await_normal_window(warden,player)
	if not reached_window:
		check(false,"bounded normal AI ticks naturally reach live variant-0 windup and visible frame24")
		game.free(); await process_frame; return
	check(warden.target == game.player and warden._committed_target == game.player and warden.combat_visual_state().get("phase") == "windup" and warden.combat_visual_state().get("variant") == 0,"actual AI acquired the real player and owns this unedited attack transition")
	check(warden.sprite.texture.resource_path == "res://assets/art/sprites/bodies-v1/nursery_warden.png" and warden.sprite.frame == 24 and warden._warden_node_binding.get("valid",false),"actual configured sprite uses the normal imported pinned Warden atlas / cell")
	var binding: Dictionary = PressureWindow.bind(warden.sprite)
	if binding.is_empty():
		var raw_manifest: String=FileAccess.get_file_as_string(PressureWindow.MANIFEST_PATH)
		var parsed_manifest: Dictionary=JSON.parse_string(raw_manifest)
		var cache: Dictionary=Query._texture_cache(warden.sprite.texture)
		var frame_bytes:=PackedByteArray()
		for y in range(256):
			var start: int=((768+y)*2048)*4
			frame_bytes.append_array(cache.get("data",PackedByteArray()).slice(start,start+1024))
		var validated_mask: Variant=PressureWindow._validated_mask(parsed_manifest.get("mask",{}))
		print("WARDEN_BIND_DIAGNOSTIC ",JSON.stringify({"path":warden.sprite.texture.resource_path,"size":str(warden.sprite.texture.get_size()),"hframes":warden.sprite.hframes,"vframes":warden.sprite.vframes,"region_enabled":warden.sprite.region_enabled,"manifest_bytes":raw_manifest.length(),"manifest_accepted":not PressureWindow._manifest(raw_manifest).is_empty(),"manifest":parsed_manifest,"cache_bytes":cache.get("data",PackedByteArray()).size(),"cache_sha":PressureWindow.sha256(cache.get("data",PackedByteArray())),"expected_cache_sha":PressureWindow.ATLAS_RGBA_SHA256,"frame_sha":PressureWindow.sha256(frame_bytes),"expected_frame_sha":PressureWindow.RUNTIME_FRAME_RGBA_SHA256,"mask_type":type_string(typeof(validated_mask)),"mask_sha":PressureWindow.sha256(validated_mask) if validated_mask is PackedByteArray else "INVALID"}))
	check(not binding.is_empty(),"runtime region binding verifies exact current atlas bytes")
	check(_aim_camera_at_cell(player,warden,NODE_PIXEL),"camera aims at an actually queryable RLE node texel without capsule/headbox assistance")
	_fire_and_check_node_damage(game,warden,player,33,"live charge pressure node")
	check(warden.telegraph_time == 0 and warden._committed_variant == -1 and warden.stagger_time > 0,"ordinary first hit keeps existing interrupt/counter behavior; no new interrupt claim")
	# Let Player's real cooldown expire while the ordinary Warden recovery/stagger window
	# stays closed. This is a second actual shot at the reviewed opaque non-node texel.
	var second_ready := false
	for _frame in range(18):
		await physics_frame
		if player.cooldown <= 0 and warden.telegraph_time <= 0 and warden.stagger_time > 0:
			second_ready = true
			break
	check(second_ready,"bounded real Player cooldown reaches zero before normal Warden stagger ends")
	if second_ready:
		check(warden.telegraph_time == 0 and warden._committed_variant == -1 and warden.sprite.frame == 24,"closed-window follow-up is still the actual recovery sprite cell")
		check(_aim_camera_at_cell(player,warden,OPAQUE_NON_NODE_PIXEL),"actual query reaches the opaque in-envelope non-node pixel")
		var hp_before: int = warden.hp
		var ammo_before: int = game.state.ammo[1]
		var sequence_before: int = game.state.shot_sequence[1]
		check(Engine.is_in_physics_frame(),"closed-window control shot remains in physics")
		var accepted: bool = player.fire()
		var hit: Dictionary = game.aim_observation.get("contact",{})
		check(accepted and game.state.ammo[1] == ammo_before-1 and game.state.shot_sequence[1] == (sequence_before+1)%Variation.PERIOD,"closed-window control is another accepted finite shot")
		check(hit.get("collider") == warden and hit.get("coverage") == "visible_sprite" and hit.get("sprite_frame") == 24 and hit.get("frame_pixel") == OPAQUE_NON_NODE_PIXEL and PressureWindow.region(binding,warden.sprite,hit,warden.get_instance_id()) == 0,"outside-contour contact is actual opaque visible artwork but not the labeled mechanism")
		check(hp_before-warden.hp == 22,"closed-window/non-node control receives exactly ordinary Rivet damage22")
		check(game.shots == [1,1],"both accepted Rivet discharges are recorded once")
	game.free()
	await process_frame

func _wall_case() -> void:
	var arena := _arena()
	if arena.is_empty(): return
	var game = arena.game
	var warden = arena.warden
	var player = arena.player
	var reached_window: bool = await _await_normal_window(warden,player)
	if not reached_window:
		check(false,"wall case first reaches the same normal live AI window")
		game.free(); await process_frame; return
	check(_aim_camera_at_cell(player,warden,NODE_PIXEL),"wall case first resolves the actual node texel aim")
	var wall = game.level._box(Vector3(8,4,0.2),arena.authored_position+Vector3(0,2.0,6),null,true)
	await physics_frame
	check(_normal_window_open(warden,player),"committed variant-0 telegraph remains naturally live behind a new wall")
	check(Engine.is_in_physics_frame(),"wall-blocked actual Player.fire is called in physics")
	var hp_before: int = warden.hp
	var ammo_before: int = game.state.ammo[1]
	var sequence_before: int = game.state.shot_sequence[1]
	var accepted: bool = player.fire()
	var contact: Dictionary = game.aim_observation.get("contact",{})
	check(accepted and game.state.ammo[1] == ammo_before-1 and game.state.shot_sequence[1] == (sequence_before+1)%Variation.PERIOD,"wall-blocked trigger is still one accepted shot with ordinary ammo/sequence accounting")
	check(contact.get("collider") == wall and contact.get("coverage") != "visible_sprite" and contact.get("collider") != warden,"real SpriteHitQuery/physics trace returns the intervening wall, never a Warden texel")
	check(hp_before == warden.hp,"native wall prevents damage: Warden HP loss is exactly zero")
	check(_normal_window_open(warden,player),"wall hit neither damages/interupts nor fabricates the Warden precision event")
	check(game.shots == [1],"wall-blocked accepted discharge is still recorded once")
	game.free()
	await process_frame

func run() -> void:
	check(PressureWindow._exact_pair([0.0,768.0],0,768) and PressureWindow._exact_pair([256.0,256.0],256,256),"JSON integral-float coordinate pairs preserve exact numeric source identity")
	for invalid in [[0.0,768.25],["0",768],[0],[0,768,1],null]:
		check(not PressureWindow._exact_pair(invalid,0,768),"fractional, string, missing and oversized coordinate pairs fail closed")
	await _bonus_then_closed_non_node_case()
	await _wall_case()
	if failures == 0:
		print("PASS Warden live AI/native fire/HP source fixture: controlled arena, actual authored Nursery actor spec and imported atlas; not authored campaign, human input, balance or visual acceptance")
	quit(0 if failures == 0 else 1)
