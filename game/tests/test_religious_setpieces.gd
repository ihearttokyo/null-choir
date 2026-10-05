extends SceneTree

const INTAKE_PIECES = {
	"Christian":"intake_throat_frame", "Buddhist":"intake_wheel_reservoir",
	"Shinto":"intake_bound_gate", "Islamic":"intake_pressure_screen",
	"Hindu":"intake_ascending_engine", "Jewish":"intake_seven_lamps",
	"ancient Egyptian":"intake_solar_seal"}
const FOUNDRY_PIECES = {
	"Christian":"foundry_cross_spine", "Buddhist":"foundry_slag_wheel",
	"Shinto":"foundry_bound_furnace", "Islamic":"foundry_pressure_canopy",
	"Hindu":"foundry_tower_cluster", "Jewish":"foundry_lamp_manifold",
	"ancient Egyptian":"foundry_solar_crucible"}
const PROCESSIONAL_PIECES = {
	"Christian":"processional_pipe_choir", "Buddhist":"processional_gong_carousel",
	"Shinto":"processional_bound_drums", "Islamic":"processional_acoustic_canopy",
	"Hindu":"processional_reed_chariot", "Jewish":"processional_seven_reeds",
	"ancient Egyptian":"processional_winged_sarcophagus"}
const RELIQUARY_PIECES = {
	"Christian":"reliquary_face_halo", "Buddhist":"reliquary_memory_wheel",
	"Shinto":"reliquary_bound_gate", "Islamic":"reliquary_cell_vault",
	"Hindu":"reliquary_tower_cluster", "Jewish":"reliquary_seven_vessels",
	"ancient Egyptian":"reliquary_winged_seal"}
const NURSERY_PIECES = {
	"Christian":"nursery_gestation_engine", "Buddhist":"nursery_seed_orrery",
	"Shinto":"nursery_bound_gate", "Islamic":"nursery_cell_canopy",
	"Hindu":"nursery_tower_cluster", "Jewish":"nursery_seven_vessels",
	"ancient Egyptian":"nursery_winged_cradle"}
const OSSUARY_PIECES = {
	"Christian":"ossuary_rib_bridge", "Buddhist":"ossuary_bone_mandala",
	"Shinto":"ossuary_bound_gate", "Islamic":"ossuary_cell_archive",
	"Hindu":"ossuary_tower_cluster", "Jewish":"ossuary_seven_reservoirs",
	"ancient Egyptian":"ossuary_winged_sarcophagus"}
const INVERSION_PIECES = {
	"Christian":"inversion_surgical_cradle", "Buddhist":"inversion_tilted_gyroscope",
	"Shinto":"inversion_bound_gate", "Islamic":"inversion_cell_prism",
	"Hindu":"inversion_tower_cluster", "Jewish":"inversion_seven_vessels",
	"ancient Egyptian":"inversion_winged_cradle"}
const HEART_PIECES = {
	"Christian":"heart_mouth_restraint", "Buddhist":"heart_pulse_mandala",
	"Shinto":"heart_bound_gate", "Islamic":"heart_cell_crown",
	"Hindu":"heart_tower_cluster", "Jewish":"heart_seven_reservoirs",
	"ancient Egyptian":"heart_winged_seal"}
var game

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var index = 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="): index = int(arg.trim_prefix("--level="))
	if not expect(index in range(8),"Set-piece fixture selects one of the eight maps"): return
	var expected = [INTAKE_PIECES, FOUNDRY_PIECES, PROCESSIONAL_PIECES, RELIQUARY_PIECES, NURSERY_PIECES, OSSUARY_PIECES, INVERSION_PIECES, HEART_PIECES][index]
	var layout = load("res://scripts/level_data.gd").new()
	if not expect(layout.load_level(index),"Selected native map must be registered (intended RED)"): return
	if not expect(layout.data.get("mission","") is String and not layout.data.get("mission","").is_empty(),"Actual authored mission is required by the native start_level path"): return
	var pieces = (layout.data.scenery+layout.data.heroes).filter(func(spec): return spec.has("tradition") or spec.has("tradition_aesthetic"))
	if not expect(pieces.size() == 7,"Level requires seven image-derived religious-aesthetic set pieces (intended RED)"): return
	var found = {}
	for spec in pieces:
		var art = spec.get("art",spec.get("id",""))
		var tradition = spec.get("tradition",spec.get("tradition_aesthetic",""))
		if not expect(expected.get(tradition,"") == art and not found.has(tradition),"Seven distinct original Blender identities, one for each selected tradition"): return
		found[tradition] = true
		if not expect(ResourceLoader.exists("res://assets/art/world/"+art+".glb"),"Actual imported Blender game asset required: "+art): return
	game = load("res://scripts/main.gd").new()
	game.settings_path = "user://religious_setpiece_preferences.json"
	game.progress_path = "user://religious_setpiece_progress.json"
	root.add_child(game)
	AudioServer.set_bus_mute(0,true)
	game.state.new_campaign(0)
	game.state.level_index = index
	game.start_level()
	if not expect(game.playing and game.message == layout.data.mission,"Actual map entry must finish gameplay, mission and live MIDI startup"): return
	game.pause_game()
	await physics_frame
	if not expect(game.enemies.size() == layout.data.enemies.size() and game.enemies.all(func(actor): return actor.sprite != null and actor.get_children().any(func(node): return node is CollisionShape3D)),"All real authored actors must configure their sprite and capsule before scenery acceptance (intended RED)"): return
	for spec in pieces:
		var art = spec.get("art",spec.get("id",""))
		var solid = spec.get("solid",spec.get("base",[]))
		var path = "res://assets/art/world/"+art+".glb"
		var models = game.level.get_children().filter(func(node): return node.scene_file_path == path)
		if not expect(models.size() == 1,"Set piece appears exactly once in the real playable scene: "+art): return
		var model = models[0]
		if not expect(model.position.is_equal_approx(layout.world_position(spec.cell)) and is_equal_approx(model.rotation.y,deg_to_rad(spec.yaw)),"Native authored placement and facing retained"): return
		var meshes = 0
		var local_bounds: AABB
		var roof = model.position.y+layout.roof_height(Vector2i(spec.cell[0],spec.cell[1]))
		for child in model.get_children():
			if not expect(not child is Camera3D and not child is Light3D and not child is CollisionObject3D,"Runtime asset excludes authoring cameras/lights and anatomical collision"): return
			if child is MeshInstance3D:
				meshes += 1
				var part = child.transform*child.get_aabb()
				local_bounds = part if meshes == 1 else local_bounds.merge(part)
				var bounds = child.global_transform*child.get_aabb()
				if not expect(bounds.end.y < roof-0.15,"Set piece must fit below the real solid ceiling: "+art): return
		if not expect(meshes > 0 and meshes <= 7,"Actual game meshes preserve the per-material draw budget"): return
		if art == "ossuary_rib_bridge":
			if not expect(solid.is_empty() and game.level.get_node_or_null("LandmarkBase_"+art) == null,"Open rib bridge must have no whole-footprint base blocking its central passage"): return
			var center = layout.world_position(spec.cell)
			var space = game.level.get_world_3d().direct_space_state
			if not expect(space.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3.UP*1.2,center+Vector3.UP*.05,1)).is_empty(),"Bridge central passage has no raised blocking collider"): return
			var floor_hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3.UP*.05,center-Vector3.UP*.25,1))
			if not expect(not floor_hit.is_empty() and absf(floor_hit.position.y-center.y) < .003,"Bridge passage retains its actual raised walkable floor"): return
			var supports = layout.data.scenery.filter(func(s): return s.art == "drain_altar" and s.get("scale",[]) == [.23,.25,.3])
			if not expect(supports.size() == 4,"Open bridge retains four modeled lateral supports"): return
			for support in supports:
				var p = layout.world_position(support.cell)
				var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.6,p+Vector3.UP*.05,1))
				if not expect(not hit.is_empty() and hit.collider is StaticBody3D and hit.collider.get_child(1).shape is BoxShape3D and hit.collider.get_child(1).shape.size.is_equal_approx(Vector3(.85,.3,.8)),"Each lateral bridge support retains its small authored native collision"): return
			continue
		var base_position = model.position+Vector3.UP*solid[1]/2.0
		if not expect(game.level.get_children().any(func(node): return node is StaticBody3D and node.position.is_equal_approx(base_position) and node.get_child(1).shape is BoxShape3D),"Explicit low authored base prevents phasing through floor machinery"): return
		var base = game.level.get_children().filter(func(node): return node is StaticBody3D and node.position.is_equal_approx(base_position))[0]
		var size = base.get_child(1).shape.size
		var footprint = local_bounds.size*model.scale
		if not expect(absf(size.x-footprint.x) < .003 and absf(size.z-footprint.z) < .003 and base.rotation.is_equal_approx(model.rotation),"Base footprint uses model-local dimensions and rotates with the model exactly once: "+art): return
	if not expect(layout.data.heroes.size() == 2 and layout.data.loops.size() == 2 and game.level.get_children().filter(func(node): return node is Light3D and node.shadow_enabled).size() == 4,"Original loop heroes and four-shadow budget remain intact"): return
	if index == 5:
		game.state.keys = ["blood"]
		game.level.refresh_machine_lights()
		game.level.apply_encounter_cue(layout.data.encounters[0],true)
		for id in ["ossuary_bridge_feed","ossuary_bridge_core"]:
			if not expect(game.level.machine_lights[id].light_color.is_equal_approx(Color(1,.76,.44)),"Bridge seal lighting restores warm through the existing hero/cue path"): return
	game.show_title()
	paused = false
	await create_timer(.1).timeout
	game.free()
	await process_frame
	await process_frame
	print("PASS seven actual Blender set pieces, traditions, staging, ceiling clearance, low bases and preserved loop/shadow budgets: "+layout.data.id)
	quit()

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		if is_instance_valid(game): game.free()
		paused = false
		quit(1)
	return condition
