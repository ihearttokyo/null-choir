extends SceneTree

class NativeGame extends "res://scripts/main.gd":
	var aim_queries: int = 0
	var interaction_queries: int = 0
	func _ready() -> void: set_process(false)
	func resolve_aim(origin: Vector3,direction: Vector3,reach: float,melee: bool = false) -> Dictionary:
		aim_queries += 1
		return super.resolve_aim(origin,direction,reach,melee)
	func nearest_interaction() -> Dictionary:
		interaction_queries += 1
		return super.nearest_interaction()

var game
var failures: int = 0

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func expect(condition: bool, detail: String) -> void:
	if condition: return
	failures += 1
	push_error(detail)

func run() -> void:
	preload("res://scripts/preferences.gd").new().apply_bindings()
	game = NativeGame.new()
	root.add_child(game)
	game.state.new_campaign(1)
	game.level = game.Level.new()
	game.add_child(game.level)
	game.level.layout.load_level(0)
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.set_physics_process(false)
	game.player.position = Vector3(0,.04,0)
	game.state.weapon = 0
	game.playing = true
	game.settings.auto_aim = true
	var body = game.Enemy.new()
	game.level.add_child(body)
	body.configure(game,{"id":"preview_crawler","kind":"crawler","cell":[0.5,0.5],"yaw":0})
	body.position = Vector3(0,.04,-1.8)
	body.set_physics_process(false)
	game.enemies = [body]
	await physics_frame
	await physics_frame
	if not game.has_method("observe_player"):
		push_error("NC03 RED: missing physics-owned HUD observation")
		game.free()
		await process_frame
		quit(1)
		return
	for args in [[Vector3(NAN,0,0),Vector3.FORWARD,2.7],[Vector3.ZERO,Vector3.ZERO,2.7],[Vector3.ZERO,Vector3.FORWARD,INF],[Vector3.ZERO,Vector3.FORWARD,-1.0]]:
		var invalid: Dictionary = game.resolve_aim(args[0],args[1],args[2],true)
		expect(invalid.contact.is_empty() and invalid.actor_id.is_empty(),"Invalid finite geometry cannot produce a collision selection")
	game.observe_player()
	var observation: Dictionary = game.aim_display()
	expect(observation.get("actor_id","") == body.id and observation.get("assisted",false),"Physics preview selects actual low crawler contact")
	expect(observation.get("player") == game.player and observation.tick == Engine.get_physics_frames(),"Observation binds current player and physics tick")
	var hud = game.Hud.new()
	hud.game = game
	game.add_child(hud)
	var cue: Dictionary = hud.aim_cue()
	expect(not cue.is_empty() and cue.actor_id == body.id and cue.contact == observation.contact.position,"HUD cue reports same native acquired contact")
	for scale_factor in [1.0,2.0,1.5]:
		hud.scale = Vector2.ONE*scale_factor
		hud.position = Vector2(17,23)
		cue = hud.aim_cue()
		expect(not cue.is_empty() and (hud.get_global_transform_with_canvas()*cue.position).distance_to(game.player.camera.unproject_position(observation.contact.position)) < .001,"Actual HUD transform maps cue back to actual camera viewport")
	hud.position = Vector2(1000,1000)
	expect(hud.aim_cue().is_empty(),"Projection outside play area cannot display a misleading cue")
	hud.scale = Vector2.ONE
	hud.position = Vector2.ZERO
	var before_shot: int = game.aim_queries
	game.player.cooldown = 0
	expect(game.player.fire() and game.aim_queries == before_shot+1 and body.hp == body.max_hp-28,"Discharge revalidates exactly once and damages advertised first contact")
	expect(game.aim_display().contact.position == observation.contact.position,"Accepted shot and preview share current geometry")
	var queries: int = game.aim_queries
	var prompt_queries: int = game.interaction_queries
	for index in 10:
		game.aim_display()
		game.interaction_display()
		hud.draw_state()
		hud.aim_cue()
	expect(game.aim_queries == queries and game.interaction_queries == prompt_queries,"Display access performs no native query")
	body.hp = 0
	expect(game.aim_display().is_empty(),"Death after preview invalidates advertised contact")
	body.hp = body.max_hp
	game.observe_player()
	game.state.weapon = 1
	expect(game.aim_display().is_empty(),"Weapon switch invalidates old weapon observation")
	game.state.weapon = 0
	game.observe_player()
	game.player.look(Vector2(.1,0))
	expect(game.aim_display().is_empty(),"Immediate mouse look invalidates old geometry")
	game.player.rotation.y = 0
	game.observe_player()
	game.player.cancel_actions()
	expect(game.aim_display().is_empty() and game.interaction_display().is_empty(),"Cancellation clears both transient observations")
	game.observe_player()
	game.playing = false
	expect(game.aim_display().is_empty(),"Paused gameplay cannot show cached contact")
	game.playing = true
	game.observe_player()
	game.level.queue_free()
	expect(game.aim_display().is_empty() and game.interaction_display().is_empty(),"Retired map invalidates target and prompt")
	game.free()
	await process_frame
	if failures == 0: print("PASS native physics-owned read-only aiming observation and cancellation lifecycle")
	quit(0 if failures == 0 else 1)
