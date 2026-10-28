@tool
extends EditorScenePostImport
## Godot 4.7.2 imports the COLOR_0 arrays but leaves their albedo flag disabled.
## Establish the authored route at import, never repair a mutated live material.

const SOURCE_PATHS = [
	"res://assets/art/healing_machinery/models/canted-supported-orbit-core.glb",
	"res://assets/art/healing_machinery/models/capillary-organ.glb",
	"res://assets/art/healing_machinery/models/clinical-abstract-capsule.glb",
	"res://assets/art/healing_machinery/models/hanging-pressure-bulb.glb",
	"res://assets/art/healing_machinery/models/ivory-archive-vessel.glb",
	"res://assets/art/healing_machinery/models/organic-valve-cage.glb",
	"res://assets/art/healing_machinery/models/refractory-ceramic-crucible.glb",
	"res://assets/art/healing_machinery/models/ribbed-marrow-tank.glb",
]

func _post_import(scene: Node) -> Object:
	if get_source_file() not in SOURCE_PATHS:
		push_error("HEALING MACHINERY IMPORT / foreign source path")
		return null
	var materials: Array[BaseMaterial3D]=[]
	# Validate every part before changing any imported material.
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		if not node.mesh is ArrayMesh or node.mesh.get_surface_count()!=1:
			push_error("HEALING MACHINERY IMPORT / expected one authored ArrayMesh surface")
			return null
		var arrays: Array=node.mesh.surface_get_arrays(0)
		if not arrays[Mesh.ARRAY_COLOR] is PackedColorArray or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or arrays[Mesh.ARRAY_COLOR].is_empty() or arrays[Mesh.ARRAY_COLOR].size()!=arrays[Mesh.ARRAY_VERTEX].size():
			push_error("HEALING MACHINERY IMPORT / missing authored vertex COLOR_0")
			return null
		var material: Material=node.mesh.surface_get_material(0)
		if not material is BaseMaterial3D:
			push_error("HEALING MACHINERY IMPORT / expected authored base material")
			return null
		if material not in materials: materials.append(material)
	if materials.is_empty():
		push_error("HEALING MACHINERY IMPORT / no authored materials")
		return null
	for material in materials:
		material.vertex_color_use_as_albedo=true
	return scene
