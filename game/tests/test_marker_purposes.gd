extends SceneTree

const StaticSelectedLevel = preload("res://tests/fixtures/static_selected_level.gd")
# Independent test oracle; never read the runtime marker factory's mapping.
const PURPOSE_ART = {
	"ammo":"marker_ammo", "health":"marker_health", "armor":"marker_armor",
	"key":"marker_key", "weapon":"marker_weapon", "story":"marker_story",
	"checkpoint":"marker_checkpoint", "exit":"marker_exit"
}

class MarkerOwner extends Node:
	var state = preload("res://scripts/campaign.gd").new()
	var level

var owner

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var passed: bool = await check_purposes()
	cleanup()
	if passed: print("PASS eight-map purpose identity, native resources, authored anchors/scale and visual-only marker removal; no visual-quality claim")
	quit(0 if passed else 1)

func check_purposes() -> bool:
	owner = MarkerOwner.new()
	root.add_child(owner)
	var seen = {}
	for index in range(8):
		owner.state = StaticSelectedLevel.fresh_selected(index,1)
		owner.level = load("res://scripts/level.gd").new()
		owner.add_child(owner.level)
		var state_before: Dictionary = owner.state.to_dict().duplicate(true)
		if not expect(owner.level.build(owner,index),"Authored map must build: "+str(index)): return false
		var level = owner.level
		var authored: Dictionary = level.layout.data.duplicate(true)
		var specs = authored.pickups+authored.interactions
		if not expect(level.markers.size() == specs.size(),"Complete authored live-marker count: "+authored.id): return false
		for spec in specs:
			if not check_marker(level,spec,expect): return false
			seen[PURPOSE_ART[spec.kind]] = true
		var colliders = collision_nodes(level)
		for spec in specs: level.remove_marker(spec.id)
		await process_frame
		await process_frame
		if not expect(level.markers.is_empty() and collision_nodes(level) == colliders,"Visual-only markers allocate no level colliders and removal leaves all native geometry intact: "+authored.id): return false
		if not expect(level.layout.data == authored and owner.state.to_dict() == state_before,"Presentation/removal never rewrites authored IDs/cells or campaign/save state: "+authored.id): return false
		level.free()
		owner.level = null
		await process_frame
	if not expect(seen.size() == PURPOSE_ART.size(),"Campaign exercises all eight purpose art IDs"): return false
	for id in PURPOSE_ART.values():
		if not expect(seen.has(id),"Campaign purpose coverage: "+id): return false
	return true

static func expected_art(spec: Dictionary) -> String:
	if spec.kind == "key" and spec.key == "ivory": return "marker_ivorykey"
	if spec.kind == "ammo":
		match int(spec.weapon):
			2: return "marker_ammo_shells"
			3: return "marker_ammo_sawtooth"
			4: return "marker_ammo_marrow"
			5: return "marker_ammo_choir"
	return PURPOSE_ART[spec.kind]

static func check_marker(level, spec: Dictionary, check: Callable) -> bool:
	if not check.call(PURPOSE_ART.has(spec.kind),"Known authored marker purpose: "+spec.kind): return false
	if not check.call(level.markers.has(spec.id),"Missing marker: "+spec.id): return false
	var marker = level.markers[spec.id]
	var path: String = "res://assets/art/world/"+expected_art(spec)+".glb"
	if not check.call(marker is Node3D and marker.get_parent() == level and marker.scene_file_path == path,"Purpose-specific native scene: "+spec.id+" expected="+path): return false
	var anchor = level.layout.world_position(spec.cell)+Vector3.UP*0.06
	if not check.call(marker.is_visible_in_tree() and marker.position.is_equal_approx(anchor) and marker.scale.is_equal_approx(Vector3.ONE) and is_equal_approx(marker.rotation.y,deg_to_rad(180)),"Metre-authored visible marker retains exact anchor/default scale: "+spec.id): return false
	if not check.call(collision_nodes(marker).is_empty(),"Visual-only marker has no CollisionObject/CollisionShape/CollisionPolygon: "+spec.id): return false
	var meshes = mesh_nodes(marker)
	if not check.call(not meshes.is_empty(),"Purpose scene has native meshes: "+spec.id): return false
	for node in meshes:
		if not check.call(node.is_visible_in_tree() and node.mesh is ArrayMesh and not node.mesh is SphereMesh,"Authored native ArrayMesh, no generic sphere core: "+spec.id): return false
		if not check.call(node.mesh.get_surface_count() > 0,"Native mesh has surfaces: "+spec.id): return false
		for material in [node.material_override,node.material_overlay]:
			if material != null and not check.call(material is BaseMaterial3D,"Native override/overlay material: "+spec.id): return false
		for surface in range(node.mesh.get_surface_count()):
			var arrays = node.mesh.surface_get_arrays(surface)
			if not check.call(arrays.size() == Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array and not arrays[Mesh.ARRAY_VERTEX].is_empty(),"Native mesh has vertex arrays: "+spec.id): return false
			if not check.call(node.get_active_material(surface) is BaseMaterial3D,"Every native surface has a material: "+spec.id): return false
			var material = node.mesh.surface_get_material(surface)
			if material != null and not check.call(material is BaseMaterial3D,"Native mesh surface material: "+spec.id): return false
	return true

static func mesh_nodes(marker: Node) -> Array:
	var nodes: Array = marker.find_children("*","MeshInstance3D",true,false)
	if marker is MeshInstance3D: nodes.push_front(marker)
	return nodes

static func collision_nodes(node: Node) -> Array:
	var colliders = []
	for child in [node]+node.find_children("*","",true,false):
		if child is CollisionObject3D or child is CollisionShape3D or child is CollisionPolygon3D:
			colliders.append(child.get_instance_id())
	return colliders

func cleanup() -> void:
	if is_instance_valid(owner):
		if is_instance_valid(owner.level): owner.level.free()
		owner.level = null
		owner.free()
	owner = null

func expect(condition: bool, detail: String) -> bool:
	if not condition: push_error(detail)
	return condition
