extends SceneTree

const PurposeContract = preload("res://tests/test_marker_purposes.gd")

class MarkerOwner extends Node:
	var state = preload("res://scripts/campaign.gd").new()
	var level

var owner

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var passed: bool = await check_sharing()
	cleanup()
	if passed: print("PASS eight builds: purpose fidelity, same-art mesh/material sharing, independent transforms, removal and full resource teardown")
	quit(0 if passed else 1)

func check_sharing() -> bool:
	owner = MarkerOwner.new()
	root.add_child(owner)
	for index in range(8):
		owner.state.new_campaign(1)
		owner.state.level_index = index
		owner.level = load("res://scripts/level.gd").new()
		owner.add_child(owner.level)
		if not expect(owner.level.layout.load_level(index),"Authored map must load"): return false
		# Actual consumed-spec filter.
		owner.state.removed = [owner.level.layout.data.pickups[0].id]
		var started = Time.get_ticks_usec()
		if not expect(owner.level.build(owner,index),"Authored map must build"): return false
		var build_us = Time.get_ticks_usec()-started
		var level = owner.level
		var level_id = level.layout.data.id
		var specs = level.layout.data.pickups+level.layout.data.interactions
		var resources = {"meshes":{},"materials":{},"scenes":{}}
		var ids = {}
		var by_art = {}
		var repeated = false
		for spec in specs:
			if spec.id in owner.state.removed:
				if not expect(not level.markers.has(spec.id),"Consumed marker absent: "+spec.id): return false
				continue
			if not PurposeContract.check_marker(level,spec,expect): return false
			var art: String = PurposeContract.PURPOSE_ART[spec.kind]
			if not expect(level._model_scenes.has(art) and level._model_scenes[art] is PackedScene,"One level-owned PackedScene per used purpose: "+art): return false
			var marker = level.markers[spec.id]
			if not expect(level._model_scenes[art].resource_path == marker.scene_file_path,"Owned native scene matches marker purpose: "+spec.id): return false
			resources.scenes[art] = weakref(level._model_scenes[art])
			ids[spec.id] = {"placement":marker.transform,"meshes":capture_marker(marker,resources)}
			if by_art.has(art):
				if not expect(ids[spec.id].meshes == by_art[art],"Same-art native meshes/materials and authored local transforms shared: "+spec.id): return false
				repeated = true
			else: by_art[art] = ids[spec.id].meshes
		var count = level.markers.size()
		if not expect(count > 1 and count == specs.size()-owner.state.removed.size() and ids.size() == count,"One native scene per nonremoved spec"): return false
		if not expect(repeated,"Each map exercises repeated same-art markers"): return false
		if not await check_removal(level,specs,ids,resources): return false
		level.free()
		owner.level = null
		await process_frame
		await process_frame
		for kind in resources:
			for resource_ref in resources[kind].values():
				if not expect(resource_ref.get_ref() == null,"Build "+kind+" released: "+level_id): return false
		print("MEASURE marker_mesh_sharing level=",level_id," markers=",count," mesh_resources=",resources.meshes.size()," material_resources=",resources.materials.size()," marker_scenes=",resources.scenes.size()," build_us=",build_us," released=all")
	return true

func capture_marker(marker: Node3D, resources: Dictionary) -> Dictionary:
	# Only IDs, value transforms and WeakRefs escape; no retained native resources.
	var snapshot = {}
	for node in PurposeContract.mesh_nodes(marker):
		resources.meshes[node.mesh.get_instance_id()] = weakref(node.mesh)
		var materials = []
		var native_materials = [node.material_override,node.material_overlay]
		for surface in range(node.mesh.get_surface_count()):
			native_materials.append(node.mesh.surface_get_material(surface))
			native_materials.append(node.get_active_material(surface))
		for material in native_materials:
			if material == null:
				materials.append(null)
				continue
			materials.append([material.get_instance_id(),material.albedo_color,material.emission,material.emission_enabled,material.emission_energy_multiplier,material.roughness,material.texture_filter])
			resources.materials[material.get_instance_id()] = weakref(material)
		snapshot[str(marker.get_path_to(node))] = [node.mesh.get_instance_id(),materials,node.transform]
	return snapshot

func check_removal(level, specs: Array, ids: Dictionary, resources: Dictionary) -> bool:
	var id: String = ""
	for spec in specs:
		if not ids.has(spec.id): continue
		for peer in specs:
			if peer.id != spec.id and ids.has(peer.id) and peer.kind == spec.kind:
				id = spec.id
				break
		if not id.is_empty(): break
	if not expect(not id.is_empty(),"Transform/removal witness has a live same-art peer"): return false
	var marker = level.markers[id]
	var mesh_node = PurposeContract.mesh_nodes(marker)[0]
	var placement: Transform3D = marker.transform
	var local_transform: Transform3D = mesh_node.transform
	marker.position += Vector3.RIGHT
	mesh_node.position += Vector3.UP
	# Imported materials are immutable shared art, not per-instance color state.
	if not survivors(level,specs,ids,id,resources): return false
	marker.transform = placement
	mesh_node.transform = local_transform
	var marker_ref = weakref(marker)
	var node_ref = weakref(mesh_node)
	var count = level.markers.size()
	level.remove_marker(id)
	if not expect(not level.markers.has(id) and marker.is_queued_for_deletion(),"Marker erased/queued"): return false
	marker = null
	mesh_node = null
	await process_frame
	await process_frame
	if not expect(marker_ref.get_ref() == null and node_ref.get_ref() == null,"Removed marker/mesh freed"): return false
	if not expect(level.markers.size() == count-1,"Other markers retained"): return false
	return survivors(level,specs,ids,id,resources)

func survivors(level, specs: Array, ids: Dictionary, skip_id: String, resources: Dictionary) -> bool:
	for spec in specs:
		if spec.id == skip_id or not ids.has(spec.id): continue
		if not PurposeContract.check_marker(level,spec,expect): return false
		if not expect(level.markers[spec.id].transform == ids[spec.id].placement and capture_marker(level.markers[spec.id],resources) == ids[spec.id].meshes,"Other native resources/root/local transforms unchanged: "+spec.id): return false
	return true

func cleanup() -> void:
	if is_instance_valid(owner):
		if is_instance_valid(owner.level): owner.level.free()
		owner.level = null
		owner.free()
	owner = null

func expect(condition: bool, detail: String) -> bool:
	if not condition: push_error(detail)
	return condition
