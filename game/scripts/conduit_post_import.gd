@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	# Godot shares filtering across a standard material; isolate the emissive slot.
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var material = node.mesh.surface_get_material(surface)
			if material is BaseMaterial3D and material.emission_enabled and material.emission_texture != null:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return scene
