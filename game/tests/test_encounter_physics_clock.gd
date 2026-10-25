extends "res://tests/test_profile_workload.gd"

const ENTRY_ROUTE = [[11.7,28.5],[11.7,27.0],[11.7,28.5],[11.7,24.5],[10.5,23.15],[7.5,23.15],[6.5,23.15],[6.5,20.5],[5.5,20.5],[6.5,20.5],[6.5,18.5]]
const ENCOUNTER = "intake_bell_release"

class ClockMain:
	extends "res://tests/test_active_boss_fights.gd".ObservedMain
	var witness: Dictionary = {}
	var activation: Dictionary = {}
	func activate_encounter(id: String) -> void:
		super.activate_encounter(id)
		if id == ENCOUNTER and "encounter:"+id in state.removed and activation.is_empty():
			activation = {"tick":ticks,"physics":Engine.is_in_physics_frame()}
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if not witness.is_empty() or not playing or not is_instance_valid(player): return
		var cell = Vector2(player.position.x,player.position.z)/float(level.layout.data.cell_size)
		var group: Dictionary = level.layout.data.encounters.filter(func(spec): return spec.id == ENCOUNTER)[0]
		var r: Array = group.region
		if cell.is_equal_approx(cell.clamp(Vector2(r[0],r[1]),Vector2(r[2],r[3]))):
			witness = {"tick":ticks,"physics":Engine.is_in_physics_frame(),"activated":"encounter:"+ENCOUNTER in state.removed,"cell":[cell.x,cell.y]}

func run() -> void:
	prefix = "user://encounter_clock_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	release_actions()
	seed(1304)
	game = ClockMain.new()
	game.process_physics_priority = 100 # Observe after the original native Player callback.
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	if not press_menu("New campaign") or not press_menu("Relentless") or not await wait_entry():
		await finish(1)
		return
	for cell in ENTRY_ROUTE:
		var target = clear_point(cell)
		if not expect(target != null,"Encounter route endpoint has native clearance: "+str(cell)):
			await finish(1)
			return
		var hop: int = 0
		while Vector2(route_player.position.x-target.x,route_player.position.z-target.z).length() > 0.12:
			if not live_route() or not expect(walk_ticks < 1200 and hop < 240,"Encounter crossing has finite native movement budget"):
				await finish(1)
				return
			var offset: Vector3 = target-route_player.position
			var distance: float = Vector2(offset.x,offset.z).length()
			var desired: float = atan2(-offset.x,-offset.z)
			route_player.look(Vector2(wrapf(route_player.rotation.y-desired,-PI,PI),0))
			Input.action_press("move_forward",0.2+0.8*minf(1.0,distance*6.0/9.0))
			await physics_frame
			walk_ticks += 1
			hop += 1
			if not game.witness.is_empty():
				print("ENCOUNTER_CLOCK ",JSON.stringify({"crossing":game.witness,"activation":game.activation,"health":game.state.health,"ammo":game.state.ammo,"removed":game.state.removed}))
				var ok: bool = expect(game.witness.physics and game.witness.activated,"Native encounter must activate in the same physics tick as the original Player enters its authored region, before rendering")
				ok = live_route() and ok
				ok = expect(game.state.ammo == [0,170,0,0,0,0] and game.state.armor == 0 and game.state.keys.is_empty() and game.state.owned_weapons == [0,1] and game.state.weapon == 1,"Only default90 plus earned entry35/upper45 supply; no fire/grants/refunds/keys") and ok
				for actor in game.enemies: ok = expect(actor.hp > 0,"Crossing preserves all23 original live automatic actors") and ok
				if ok: print("PASS earned native encounter region crossing is physics-owned with all23 original actors; no GPU or physical-input claim")
				await finish(0 if ok else 1)
				return
		release_actions()
	if not expect(false,"Route must actually cross the original authored encounter"):
		await finish(1)
