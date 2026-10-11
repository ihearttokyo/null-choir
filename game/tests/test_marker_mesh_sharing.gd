extends SceneTree

class MarkerOwner extends Node:
	var state = preload("res://scripts/campaign.gd").new()
	var level

var failures = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var owner = MarkerOwner.new()
	root.add_child(owner)
	var sphere = SphereMesh.new()
	sphere.radius = 0.8
	sphere.height = 1.6
	for index in range(8):
		owner.state.new_campaign(1)
		owner.state.level_index = index
		var level = load("res://scripts/level.gd").new()
		owner.level = level
		owner.add_child(level)
		if not expect(level.layout.load_level(index),"Authored map must load"):
			level.free()
			continue
		# Actual consumed-spec filter.
		owner.state.removed = [level.layout.data.pickups[0].id]
		var started = Time.get_ticks_usec()
		level.build(owner,index)
		var build_us = Time.get_ticks_usec()-started
		var level_id = level.layout.data.id
		var specs = level.layout.data.pickups+level.layout.data.interactions
		var meshes = {}
		var materials = {}
		var ids = {}
		for spec in specs:
			if spec.id in owner.state.removed:
				expect(not level.markers.has(spec.id),"Consumed marker absent: "+spec.id)
				continue
			var core = check_core(level,spec,sphere)
			if core == null: continue
			meshes[core.mesh.get_instance_id()] = weakref(core.mesh)
			materials[core.material_override.get_instance_id()] = true
			ids[spec.id] = [core.mesh.get_instance_id(),core.material_override.get_instance_id()]
		var count = level.markers.size()
		expect(count > 1 and count == specs.size()-owner.state.removed.size() and ids.size() == count,"Core per nonremoved spec")
		expect(materials.size() == count,"Independent core materials")
		# Baseline RED: one mesh per marker.
		expect(meshes.size() == 1,"MESH_IDENTITY level="+level_id+" expected=1 actual="+str(meshes.size()))
		if not ids.is_empty():
			var id = ids.keys()[0]
			var marker = level.markers[id]
			var core = marker.get_child(marker.get_child_count()-1)
			var placement = marker.transform
			var color = core.material_override.albedo_color
			marker.position += Vector3.RIGHT
			core.position += Vector3.UP
			core.material_override.albedo_color = Color.MAGENTA
			core.material_override.emission = Color.MAGENTA
			survivors(level,specs,ids,id,sphere)
			marker.transform = placement
			core.position = Vector3(0,2.2,0)
			core.material_override.albedo_color = color
			core.material_override.emission = color
			level.remove_marker(id)
			expect(not level.markers.has(id) and marker.is_queued_for_deletion(),"Marker erased/queued")
			await process_frame
			await process_frame
			expect(not is_instance_valid(marker) and not is_instance_valid(core),"Removed marker/core freed")
			expect(level.markers.size() == count-1,"Other markers retained")
			survivors(level,specs,ids,id,sphere)
		level.free()
		await process_frame
		var released = 0
		for mesh_ref in meshes.values():
			if mesh_ref.get_ref() == null: released += 1
		expect(released == meshes.size(),"Build meshes released: "+level_id)
		print("MEASURE marker_mesh_sharing level=",level_id," markers=",count," mesh_resources=",meshes.size()," build_us=",build_us," released=",released)
	owner.free()
	if failures == 0: print("PASS eight builds: fidelity/sharing/teardown")
	quit(0 if failures == 0 else 1)

func check_core(level, spec: Dictionary, sphere: SphereMesh) -> MeshInstance3D:
	if not expect(level.markers.has(spec.id),"Missing marker: "+spec.id): return null
	var marker = level.markers[spec.id]
	expect(marker.get_parent() == level and marker.scene_file_path == "res://assets/art/world/containment_capsule.glb","Capsule hierarchy: "+spec.id)
	var transform = Transform3D(Basis.from_scale(Vector3(0.25,0.17,0.25)),level.layout.world_position(spec.cell)+Vector3.UP*0.06)
	expect(marker.visible and marker.transform.is_equal_approx(transform),"Capsule transform: "+spec.id)
	var cores = marker.get_children().filter(func(child): return child is MeshInstance3D and child.mesh is SphereMesh)
	if not expect(cores.size() == 1,"One sphere core: "+spec.id): return null
	var core: MeshInstance3D = cores[0]
	expect(core == marker.get_child(marker.get_child_count()-1) and core.visible and core.transform.is_equal_approx(Transform3D(Basis.IDENTITY,Vector3(0,2.2,0))),"Core hierarchy/transform: "+spec.id)
	var mesh: SphereMesh = core.mesh
	expect(is_equal_approx(mesh.radius,0.8) and is_equal_approx(mesh.height,1.6) and mesh.radial_segments == sphere.radial_segments and mesh.rings == sphere.rings and mesh.is_hemisphere == sphere.is_hemisphere,"Dimensions/default tessellation: "+spec.id)
	if expect(mesh.get_surface_count() == 1,"One sphere surface: "+spec.id):
		var arrays = mesh.surface_get_arrays(0)
		expect(mesh.surface_get_material(0) == null and arrays.size() == Mesh.ARRAY_MAX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array and not arrays[Mesh.ARRAY_VERTEX].is_empty() and arrays == sphere.surface_get_arrays(0),"Sphere arrays: "+spec.id)
	if not expect(core.material_override is StandardMaterial3D,"Material override: "+spec.id): return null
	var color = Color(0.85,0.59,0.22)
	if spec.kind == "health": color = Color(0.4,0.7,0.65)
	if spec.kind == "armor": color = Color(0.34,0.5,0.86)
	if spec.kind == "key" and spec.key == "blood": color = Color(0.7,0.12,0.11)
	var material: StandardMaterial3D = core.material_override
	expect(material.albedo_color == color and material.emission == color and material.emission_enabled and is_equal_approx(material.emission_energy_multiplier,0.7) and is_equal_approx(material.roughness,0.83) and material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST,"Core material: "+spec.id)
	return core

func survivors(level, specs: Array, ids: Dictionary, skip_id: String, sphere: SphereMesh) -> void:
	for spec in specs:
		if spec.id == skip_id or not ids.has(spec.id): continue
		var core = check_core(level,spec,sphere)
		if core != null:
			expect([core.mesh.get_instance_id(),core.material_override.get_instance_id()] == ids[spec.id],"Other resources: "+spec.id)

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		failures += 1
		push_error(detail)
	return condition
