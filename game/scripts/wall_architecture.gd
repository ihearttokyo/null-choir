extends RefCounted
## Physical chapter architecture, not a skin in front of the old wall plane.
## Local X runs along a boundary, Z points OUT of the authored walkable tile.
const INWARD_LIMIT := 0.12 # old boundary boxes occupied 0.14 m inside the floor.
const SILL_HEIGHT := 1.05
const CHUNK_CELLS := 4
const GRILLE_PITCH := 0.60
const GRILLE_WIDTH := 0.12
const PLAYER_DIAMETER := 0.64
# x0,x1,y0,y1,front,back,material,role[,upper_x_shift]. Metres at cell_size 4.
# These authored profiles remain at human scale even under a 26 m cathedral roof.
const FAMILIES = {
	"intake": {"name":"clamped_service_bays","depth":0.94,"parts":[
		[-1.70,-1.32,1.05,3.80,-0.12,0.94,1,"clamp_pier"], [1.32,1.70,1.05,3.80,-0.12,0.94,1,"clamp_pier"],
		[-1.70,1.70,3.35,3.80,-0.12,0.94,1,"deep_lintel"], [-1.28,1.28,1.05,1.28,-0.08,0.94,2,"service_sill"],
		[-1.12,1.12,2.20,2.35,0.62,0.94,2,"recessed_crossbar"]]},
	"foundry": {"name":"corbelled_furnace_throats","depth":1.28,"parts":[
		[-1.75,-1.15,1.05,3.65,-0.12,1.28,1,"furnace_buttress"], [1.15,1.75,1.05,3.65,-0.12,1.28,1,"furnace_buttress"],
		[-1.25,-0.80,2.65,3.05,-0.10,1.28,2,"corbel_course"], [0.80,1.25,2.65,3.05,-0.10,1.28,2,"corbel_course"],
		[-1.20,1.20,3.05,3.65,-0.10,1.28,1,"furnace_crown"], [-0.72,0.72,1.05,1.35,0.48,1.28,2,"deep_hearth"]]},
	"processional": {"name":"organ_arcades","depth":1.12,"parts":[
		[-1.65,-1.30,1.05,4.30,-0.12,1.12,1,"organ_pier"], [1.30,1.65,1.05,4.30,-0.12,1.12,1,"organ_pier"],
		[-1.30,-0.78,2.70,3.25,-0.10,1.12,2,"rising_arch",0.24], [0.78,1.30,2.70,3.25,-0.10,1.12,2,"rising_arch",-0.24],
		[-0.80,0.80,3.25,3.65,-0.10,1.12,2,"arch_keystone"], [-0.18,0.18,1.30,2.90,0.72,1.12,1,"recessed_organ_pipe"]]},
	"reliquary": {"name":"stacked_loculi","depth":1.34,"parts":[
		[-1.72,-1.43,1.05,3.90,-0.12,1.34,1,"loculus_jamb"], [1.43,1.72,1.05,3.90,-0.12,1.34,1,"loculus_jamb"],
		[-0.14,0.14,1.05,3.90,-0.10,1.34,2,"loculus_mullion"], [-1.43,1.43,1.80,1.96,-0.10,1.34,2,"burial_shelf"],
		[-1.43,1.43,2.72,2.88,-0.10,1.34,2,"burial_shelf"], [-1.72,1.72,3.72,3.90,-0.12,1.34,1,"loculus_cornice"]]},
	"nursery": {"name":"cradle_rib_chambers","depth":1.18,"parts":[
		[-1.65,-1.32,1.05,3.70,-0.12,1.18,2,"cradle_rib",0.45], [1.32,1.65,1.05,3.70,-0.12,1.18,2,"cradle_rib",-0.45],
		[-1.20,1.20,3.45,3.72,-0.08,1.18,1,"cradle_lintel"], [-0.32,0.32,1.05,1.45,0.25,1.18,2,"cradle_stem"],
		[-0.70,0.70,1.45,1.67,0.42,1.18,1,"recessed_cradle"]]},
	"ossuary": {"name":"rib_vaults","depth":1.36,"parts":[
		[-1.72,-1.38,1.05,2.70,-0.12,1.36,2,"vault_rib",0.30], [1.38,1.72,1.05,2.70,-0.12,1.36,2,"vault_rib",-0.30],
		[-1.42,-0.80,2.70,3.25,-0.12,1.36,2,"vault_haunch",0.35], [0.80,1.42,2.70,3.25,-0.12,1.36,2,"vault_haunch",-0.35],
		[-0.85,0.85,3.25,3.62,-0.12,1.36,2,"vault_crown"], [-0.50,0.50,1.05,1.27,0.70,1.36,1,"recessed_ossuary"]]},
	"inversion": {"name":"opposed_cantilevers","depth":1.24,"parts":[
		[-1.70,-1.36,1.05,4.20,-0.12,1.24,1,"surgical_return"], [1.36,1.70,1.05,4.20,-0.12,1.24,1,"surgical_return"],
		[-1.36,0.50,2.95,3.30,-0.12,1.24,2,"suspended_cantilever"], [-0.50,1.36,3.75,4.12,-0.12,1.24,2,"opposed_cantilever"],
		[-1.10,-0.82,1.05,2.95,0.30,1.24,1,"diagonal_support",0.64], [0.64,1.00,1.05,1.75,0.58,1.24,2,"recessed_return"]]},
	"heart": {"name":"interlocking_mandibles","depth":1.40,"parts":[
		[-1.75,-1.30,1.05,3.20,-0.12,1.40,2,"mandible",0.52], [1.30,1.75,1.05,3.20,-0.12,1.40,2,"mandible",-0.52],
		[-1.02,-0.60,3.05,3.65,-0.12,1.40,2,"upper_tooth",0.24], [0.60,1.02,3.05,3.65,-0.12,1.40,2,"upper_tooth",-0.24],
		[-0.66,0.66,3.65,4.00,-0.10,1.40,1,"jaw_crown"], [-0.28,0.28,1.05,1.60,0.64,1.40,1,"recessed_tendon"]]}
}
const FACES = [[0,1,2,3],[5,4,7,6],[4,5,1,0],[3,2,6,7],[4,0,3,7],[1,5,6,2]]

static func clearance_policy() -> Dictionary:
	return {"max_inward_metres":INWARD_LIMIT,"legacy_inward_metres":0.14,
		"authored_floor_unchanged":true,"old_standing_clearances_preserved":true,
		"new_walkable_floor":false,"niche_entry_blocked_by_visible_solid_ribs":true,"maximum_aperture_metres":GRILLE_PITCH-GRILLE_WIDTH}

static func profile(chapter: String, size: float, height: float, variant: int = 0) -> Array:
	var family: Dictionary = FAMILIES.get(chapter,FAMILIES.intake)
	var depth: float = family.depth
	var parts: Array = [
		[-2.0,2.0,0.0,height,depth,depth+0.18,0,"solid_backing"],
		[-2.0,2.0,0.0,minf(SILL_HEIGHT,height),-0.10,depth,0,"continuous_plinth"],
		[-2.0,-1.80,0.0,height,-0.10,depth,1,"structural_return"],
		[1.80,2.0,0.0,height,-0.10,depth,1,"structural_return"],
		[-2.0,2.0,maxf(0.0,height-0.16),height,-0.10,depth,1,"roof_return"]]
	for authored in family.parts:
		var part: Array = authored.duplicate()
		# Alternate handedness for asymmetric bays, not random runtime topology.
		if variant % 2 == 1:
			var left: float = part[0]
			part[0] = -part[1]
			part[1] = -left
			if part.size() > 8: part[8] = -part[8]
		part[2] = minf(part[2],height)
		part[3] = minf(part[3],height)
		if part[3] > part[2]: parts.append(part)
	# Real, deep structural ribs: a capsule cannot enter a bay from an upper deck,
	# nor fall through its sill into unsupported space outside the authored floor.
	# Apertures scale by adding ribs, NEVER by widening beyond 0.48 m.
	var rib_count: int = ceili(size/GRILLE_PITCH)
	var pitch: float = size/float(rib_count)
	for i in range(1,rib_count):
		var x: float = -size/2.0+float(i)*pitch
		parts.append([x*4.0/size-GRILLE_WIDTH/2.0*4.0/size,x*4.0/size+GRILLE_WIDTH/2.0*4.0/size,
			0.0,height,-0.10,depth,1,"solid_aperture_rib"])
	for part in parts:
		part[0] *= size/4.0
		part[1] *= size/4.0
		if part.size() > 8: part[8] *= size/4.0
	return parts

static func _vertices(part: Array, point: Vector3, tangent: Vector3, outward: Vector3) -> PackedVector3Array:
	var lean: float = float(part[8]) if part.size() > 8 else 0.0
	var vertices := PackedVector3Array()
	for offset in [[part[0],part[2],part[4]],[part[1],part[2],part[4]],
		[part[1]+lean,part[3],part[4]],[part[0]+lean,part[3],part[4]],
		[part[0],part[2],part[5]],[part[1],part[2],part[5]],
		[part[1]+lean,part[3],part[5]],[part[0]+lean,part[3],part[5]]]:
		vertices.append(point+tangent*float(offset[0])+Vector3.UP*float(offset[1])+outward*float(offset[2]))
	return vertices

static func _append(tool: SurfaceTool, vertices: PackedVector3Array, triangles: PackedVector3Array) -> PackedVector3Array:
	for face in FACES:
		# The build frame [tangent,UP,outward] has determinant -1. Reverse
		# the local face order AND normal so Godot clockwise fronts face air.
		var normal: Vector3 = (vertices[face[1]]-vertices[face[0]]).cross(vertices[face[2]]-vertices[face[0]]).normalized()
		for index in [face[0],face[2],face[1],face[0],face[3],face[2]]:
			tool.set_normal(normal)
			tool.set_uv(Vector2(vertices[index].x+vertices[index].z,vertices[index].y)/2.0)
			tool.add_vertex(vertices[index])
			triangles.append(vertices[index])
	return triangles

static func _highest_support(layout) -> float:
	var highest: float = 0.0
	for cell in layout.tiles:
		for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
			highest = maxf(highest,layout.height_at(Vector2(cell)+offset))
	if layout.OssuarySurfaces.enabled(layout.data):
		for face in layout.surface_faces():
			if face.walkable:
				for vertex in face.triangle: highest = maxf(highest,vertex.y)
	for hero in layout.data.heroes:
		if hero.has("base"):
			highest = maxf(highest,layout.world_position(hero.cell).y+float(hero.base[1]))
	for door in layout.data.doors:
		highest = maxf(highest,layout.world_position(door.cell).y+float(door.size[1]))
	for spec in layout.data.scenery:
		var base: float = layout.world_position(spec.cell).y+float(spec.get("height",0.0))
		var scale_y: float = float(spec.get("scale",[1,1,1])[1])
		if spec.has("solid"): highest = maxf(highest,base+float(spec.solid[1]))
		for support in spec.get("supports",[]):
			highest = maxf(highest,base+(float(support.offset[1])+float(support.size[1]))*scale_y)
	return highest

static func build(level: Node3D, layout, wall_material: Material) -> void:
	var chapter: String = layout.data.id
	var size: float = layout.data.cell_size
	# Close above all authored standing surfaces; no new reachable exterior roof ledge.
	var closure_top: float = _highest_support(layout)+3.0
	var materials: Array = [wall_material,level._material(Color(0.23,0.24,0.25)),level._material(Color(0.60,0.48,0.34))]
	if chapter == "foundry": materials[2] = level._material(Color(0.44,0.14,0.06))
	elif chapter == "nursery": materials[2] = level._material(Color(0.44,0.40,0.31))
	elif chapter == "inversion": materials[2] = level._material(Color(0.56,0.64,0.64))
	elif chapter == "heart": materials[2] = level._material(Color(0.39,0.12,0.10))
	var chunks: Dictionary = {}
	for cell in layout.tiles:
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if layout.is_walkable(cell+direction): continue # Never bridge a real opening.
			var point := Vector2(cell)+Vector2(0.5,0.5)+Vector2(direction)*0.5
			var edge := Vector2(-direction.y,direction.x)*0.5
			var a: float = layout.height_at(point-edge)
			var b: float = layout.height_at(point+edge)
			var bottom: float = minf(a,b)
			var height: float = maxf(layout.roof_height(cell)+absf(a-b),closure_top-bottom)
			var origin := Vector3(point.x*size,bottom,point.y*size)
			var outward := Vector3(direction.x,0,direction.y)
			var tangent := Vector3(-direction.y,0,direction.x)
			var key := Vector2i(floori(cell.x/float(CHUNK_CELLS)),floori(cell.y/float(CHUNK_CELLS)))
			if not chunks.has(key):
				var tools: Array = [SurfaceTool.new(),SurfaceTool.new(),SurfaceTool.new()]
				for tool in tools: tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				chunks[key] = {"tools":tools,"triangles":PackedVector3Array()}
			var parts: Array = profile(chapter,size,height,absi(cell.x*17+cell.y*31+direction.x+direction.y))
			var triangles: PackedVector3Array = chunks[key].triangles
			for part in parts:
				triangles = _append(chunks[key].tools[int(part[6])],_vertices(part,origin,tangent,outward),triangles)
			chunks[key].triangles = triangles
			# Occlude ONLY the actual recessed solid backing. Never seal the niche front.
			var back: Array = parts[0]
			var occluder := OccluderInstance3D.new()
			occluder.name = "RecessedWallBacking"
			var box := BoxOccluder3D.new()
			box.size = Vector3(size-0.04,height-0.04,float(back[5])-float(back[4])-0.04)
			occluder.occluder = box
			occluder.position = origin+Vector3.UP*height/2+outward*(float(back[4])+float(back[5]))/2
			occluder.rotation.y = atan2(outward.x,outward.z)
			level.add_child(occluder)
	for key in chunks:
		var root := StaticBody3D.new()
		root.name = "WallArchitecture_"+str(key.x)+"_"+str(key.y)
		root.collision_layer = 1
		level.add_child(root)
		for material_index in range(materials.size()):
			var mesh := MeshInstance3D.new()
			mesh.mesh = chunks[key].tools[material_index].commit()
			mesh.material_override = materials[material_index]
			root.add_child(mesh)
		var collider := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(chunks[key].triangles)
		shape.backface_collision = true
		collider.shape = shape
		root.add_child(collider)
