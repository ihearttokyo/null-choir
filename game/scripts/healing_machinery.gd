extends RefCounted
## Level-owned fixed imported machinery. No primitive fallback and no save authority.
const Supply = preload("res://scripts/earned_supplies.gd")
const REGISTRY_PATH = "res://data/healing_machinery_registry.json"
const REGISTRY_SHA = "d70175911d55e38f9f929bf379f7b0fdc9cb612a0263f8f50ec2fc79a33e83c5"
const PLACEMENTS_PATH = "res://data/healing_machine_placements.json"
const PLACEMENTS_SHA = "8bc49e8072cb08d54736a94111ae60ae673e455218f76d4b433304d4eba7401b"
const CHAPTERS = ["intake","foundry","processional","reliquary","nursery","ossuary","inversion","heart"]
const FAMILIES = ["hanging-pressure-bulb","refractory-ceramic-crucible","capillary-organ","ivory-archive-vessel","clinical-abstract-capsule","ribbed-marrow-tank","canted-supported-orbit-core","organic-valve-cage"]
var _level
var _registry: Dictionary = {}
var _atlas: Texture2D
var _placements: Dictionary = {}
var _families: Dictionary = {} # PackedScene and canonical imported Mesh/Material references, per Level.
var _capacities: Dictionary = {}
var _roots: Dictionary = {} # Private exact roots; the public station book is not an ownership proof.
var _initial_level_transform: Transform3D
var error: String = ""
var binding_diagnostics: PackedStringArray=[]

func _fail(message: String) -> bool:
	error="HEALING MACHINERY / "+message
	return false

static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]),float(a[1]),float(a[2]))

static func _quantize(v: float) -> int:
	return floori(v*10000.0+.5) if v>=0.0 else ceili(v*10000.0-.5)

static func _shape_sha(faces: PackedVector3Array) -> String:
	if faces.is_empty() or faces.size()%3!=0: return ""
	var rows: PackedStringArray=[]
	for i in range(0,faces.size(),3):
		var points: PackedStringArray=[]
		for j in range(3):
			var p: Vector3=faces[i+j]
			if not p.is_finite(): return ""
			points.append("%d,%d,%d" % [_quantize(p.x),_quantize(p.y),_quantize(p.z)])
		points.sort();rows.append("|".join(points))
	rows.sort()
	return "\n".join(rows).sha256_text()

static func _render_arrays_sha(arrays: Array) -> String:
	# Source convention preserves UV/normal/color association and oriented winding.
	if arrays.size()!=Mesh.ARRAY_MAX: return ""
	if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array or not arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array or not arrays[Mesh.ARRAY_COLOR] is PackedColorArray: return ""
	var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
	if positions.is_empty() or normals.size()!=positions.size() or uvs.size()!=positions.size() or colors.size()!=positions.size(): return ""
	var records: PackedStringArray=[]
	for i in range(positions.size()):
		var p: Vector3=positions[i];var n: Vector3=normals[i];var uv: Vector2=uvs[i];var c: Color=colors[i]
		if not p.is_finite() or not n.is_finite() or not uv.is_finite() or absf(n.length_squared()-1.0)>.001: return ""
		var values: Array=[_quantize(p.x),_quantize(p.y),_quantize(p.z),_quantize(n.x),_quantize(n.y),_quantize(n.z),_quantize(uv.x),_quantize(uv.y)]
		for channel in [c.r,c.g,c.b,c.a]:
			if not is_finite(channel) or channel<0.0 or channel>1.0: return ""
			values.append(clampi(floori(channel*255.0+.5),0,255))
		var fields: PackedStringArray=[]
		for value in values: fields.append(str(value))
		records.append(",".join(fields))
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX]!=null:
		if not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array: return ""
		indices=arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in range(records.size()): indices.append(i)
	if indices.size()%3!=0: return ""
	var rows: PackedStringArray=[]
	for i in range(0,indices.size(),3):
		for j in range(3):
			if indices[i+j]<0 or indices[i+j]>=records.size(): return ""
		var a: String=records[indices[i]];var b: String=records[indices[i+1]];var c: String=records[indices[i+2]]
		var cyclic: PackedStringArray=[a+"|"+b+"|"+c,b+"|"+c+"|"+a,c+"|"+a+"|"+b]
		cyclic.sort();rows.append(cyclic[0]) # Reflection is intentionally NOT equivalent.
	rows.sort()
	return "\n".join(rows).sha256_text()

static func _render_sha(mesh: Mesh) -> String:
	if not mesh is ArrayMesh or mesh.get_surface_count()!=1: return ""
	var actual := mesh as ArrayMesh
	if actual.surface_get_primitive_type(0)!=Mesh.PRIMITIVE_TRIANGLES or (actual.surface_get_format(0)&Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)!=0: return ""
	return _render_arrays_sha(actual.surface_get_arrays(0))

func _image_sha(image: Image) -> String:
	if image==null or image.is_empty(): return ""
	var pixels := image.duplicate() as Image
	if pixels.is_compressed() and pixels.decompress()!=OK: return ""
	if pixels.get_width()!=int(_registry.atlasPixels.width) or pixels.get_height()!=int(_registry.atlasPixels.height): return ""
	pixels.clear_mipmaps();pixels.convert(Image.FORMAT_RGBA8)
	var bytes: PackedByteArray=pixels.get_data()
	if bytes.size()!=pixels.get_width()*pixels.get_height()*4: return ""
	var hash_context := HashingContext.new()
	if hash_context.start(HashingContext.HASH_SHA256)!=OK or hash_context.update(bytes)!=OK: return ""
	return hash_context.finish().hex_encode()

func _texture_matches(texture: Texture2D) -> bool:
	return texture!=null and texture.resource_path==_registry.atlasPath and _image_sha(texture.get_image())==_registry.atlasPixels.baseLevelSHA256

func _read_contracts() -> bool:
	if FileAccess.get_sha256(REGISTRY_PATH)!=REGISTRY_SHA: return _fail("registry identity")
	if FileAccess.get_sha256(PLACEMENTS_PATH)!=PLACEMENTS_SHA: return _fail("placement identity")
	var registry=JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
	var placements=JSON.parse_string(FileAccess.get_file_as_string(PLACEMENTS_PATH))
	if not registry is Dictionary or registry.get("schema")!="null-choir-healing-machinery-v1" or not registry.get("families") is Dictionary: return _fail("registry schema")
	if not placements is Dictionary or placements.size()!=32: return _fail("placement schema")
	var seen: Dictionary={}
	var chapters: Dictionary=Supply.registry().get("chapters",{})
	for chapter in CHAPTERS:
		for station in chapters.get(chapter,{}).get("stations",[]):
			var row=placements.get(station.id)
			if not Supply.exact_keys(row,["id","chapter","family","cell","yaw_degrees"]): return _fail("placement keys")
			if row.id!=station.id or row.chapter!=chapter or row.family!=FAMILIES[CHAPTERS.find(chapter)]: return _fail("placement station/family")
			if not row.cell is Array or row.cell.size()!=2: return _fail("placement cell")
			for value in row.cell+[row.yaw_degrees]:
				if not (value is float or value is int) or not is_finite(float(value)): return _fail("nonfinite placement")
			if absf(float(row.cell[0]))>100000 or absf(float(row.cell[1]))>100000 or absf(float(row.yaw_degrees))>360: return _fail("placement bounds")
			seen[station.id]=true
	if seen.size()!=32 or placements.keys().any(func(id): return not seen.has(id)): return _fail("foreign placement")
	_registry=registry;_placements=placements
	var atlas=load(_registry.atlasPath)
	if not atlas is Texture2D or not _texture_matches(atlas): return _fail("actual imported atlas RGBA8 pixels")
	_atlas=atlas
	return true

func _named(visual: Node3D) -> Dictionary:
	# Source exports flat named parts. Reject any optimization/substitution that loses them.
	var result: Dictionary={}
	for child in visual.get_children():
		if not child is Node3D or not child.get_children().is_empty() or result.has(str(child.name)): return {}
		result[str(child.name)]=child
	return result

func _specs(family: String) -> Dictionary:
	var result: Dictionary={}
	for raw_name in _registry.families[family].nodes:
		var key: String=str(raw_name).validate_node_name()
		if result.has(key): return {}
		result[key]=_registry.families[family].nodes[raw_name]
	return result

func _position(spec: Array) -> Vector3:
	return _v(spec[3]) if spec.size()>3 else Vector3.ZERO
func _scale(spec: Array) -> Vector3:
	return _v(spec[4]) if spec.size()>4 else Vector3.ONE

func _material_ok(part: MeshInstance3D, expected: Material=null) -> bool:
	if part.material_override!=null or part.material_overlay!=null or part.mesh==null or part.mesh.get_surface_count()!=1: return false
	if part.get_surface_override_material(0)!=null or part.transparency>0.0 or part.layers!=1: return false
	if not is_zero_approx(part.visibility_range_begin) or not is_zero_approx(part.visibility_range_end): return false
	var material: Material=part.mesh.surface_get_material(0)
	if expected!=null and material!=expected: return false
	if not material is BaseMaterial3D: return false
	var painted := material as BaseMaterial3D
	if painted.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or not painted.albedo_color.is_equal_approx(Color.WHITE): return false
	if painted.shading_mode!=BaseMaterial3D.SHADING_MODE_UNSHADED or not painted.vertex_color_use_as_albedo or painted.vertex_color_is_srgb or painted.emission_enabled: return false
	# glTF source uses untransformed UV1, LINEAR + CLAMP, no alternate/detail/parallax route.
	if not painted.uv1_scale.is_equal_approx(Vector3.ONE) or not painted.uv1_offset.is_equal_approx(Vector3.ZERO): return false
	if painted.uv1_triplanar or painted.uv1_world_triplanar or painted.use_point_size: return false
	if painted.texture_filter!=BaseMaterial3D.TEXTURE_FILTER_LINEAR or painted.texture_repeat: return false
	if painted.detail_enabled or painted.heightmap_enabled: return false
	if painted.cull_mode!=BaseMaterial3D.CULL_BACK or painted.albedo_texture!=_atlas or painted.albedo_texture.resource_path!=_registry.atlasPath: return false
	return true

func _fixed_faces(nodes: Dictionary, names: Array) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for name in names:
		if name in ["StockVolume","StockNeedle"]: continue
		var part: MeshInstance3D=nodes[name]
		for point in part.mesh.get_faces(): faces.append(part.transform*point)
	return faces

func _load_family(family: String) -> bool:
	if _families.has(family): return true
	if not _registry.families.has(family): return _fail("unknown family")
	var spec: Dictionary=_registry.families[family]
	var scene=load(spec.path)
	if not scene is PackedScene or scene.resource_path!=spec.path: return _fail("missing imported family "+family)
	var canonical=scene.instantiate()
	if not canonical is Node3D:
		if is_instance_valid(canonical): canonical.free()
		return _fail("nonspatial family")
	var nodes: Dictionary=_named(canonical)
	var expected: Dictionary=_specs(family)
	var meshes: Dictionary={};var materials: Dictionary={}
	var notes: PackedStringArray=[]
	var valid: bool=not expected.is_empty() and nodes.size()==expected.size() and canonical.transform.is_equal_approx(Transform3D.IDENTITY)
	for name in expected:
		if not nodes.has(name): valid=false;notes.append("missing node "+name);continue
		var node: Node3D=nodes[name];var pin: Array=expected[name]
		if not node.position.is_equal_approx(_position(pin)) or not node.rotation.is_equal_approx(Vector3.ZERO) or not node.scale.is_equal_approx(_scale(pin)): valid=false
		if pin[0]=="":
			if node is MeshInstance3D: valid=false
			continue
		if not node is MeshInstance3D: valid=false;continue
		var part := node as MeshInstance3D
		if part.mesh==null or not _material_ok(part): valid=false;continue
		var faces: PackedVector3Array=part.mesh.get_faces()
		var actual_sha: String=_render_sha(part.mesh)
		if faces.size()!=int(pin[1])*3 or actual_sha!=pin[0]:
			valid=false;notes.append(name+" triangles="+str(faces.size()/3)+" expected="+str(pin[1])+" geometry="+actual_sha+" expected="+str(pin[0]))
		var material: Material=part.mesh.surface_get_material(0)
		if material.resource_name!=_registry.materials[int(pin[2])]: valid=false
		meshes[name]=part.mesh;materials[name]=material
	var fixed_faces := PackedVector3Array()
	if valid:
		fixed_faces=_fixed_faces(nodes,meshes.keys())
		if fixed_faces.size()!=int(spec.fixedTriangles)*3 or _shape_sha(fixed_faces)!=spec.fixedSHA256:
			valid=false;notes.append("combined exact fixed triangle geometry mismatch")
	canonical.free()
	if not valid:
		binding_diagnostics.append(family+" actualNodes="+str(nodes.keys())+" / "+"; ".join(notes))
		return _fail("imported source shape/material/transform mismatch "+family+"; inspect binding_diagnostics (do not relax pins)")
	_families[family]={"scene":scene,"meshes":meshes,"materials":materials,"specs":expected,"fixed_faces":fixed_faces,"fixed_sha":spec.fixedSHA256}
	return true

func build(level, finite: Dictionary) -> bool:
	if _level!=null or not _roots.is_empty(): return _fail("build called twice")
	_level=level;_initial_level_transform=level.transform
	if not finite.get("healing_remaining") is Dictionary or absf(level.transform.basis.determinant())<.00001: return _fail("invalid finite state/level transform")
	if not _read_contracts(): return false
	for station in Supply.chapter(level.layout).get("stations",[]):
		if not Supply.integer(finite.healing_remaining.get(station.id),0,int(station.capacity)): return _fail("invalid finite stock")
		var placement: Dictionary=_placements[station.id]
		var family: String=placement.family
		if not _load_family(family): return false
		var root := Node3D.new();root.name="HealingMachine_"+station.id
		root.position=level.layout.world_position(placement.cell)
		root.rotation.y=deg_to_rad(float(placement.yaw_degrees))
		if not root.position.is_finite(): root.free();return _fail("nonfinite floor")
		level.add_child(root)
		var visual: Node3D=_families[family].scene.instantiate()
		root.add_child(visual)
		var nodes: Dictionary=_named(visual)
		# One station-lifetime exact triangle body. No box surrogate; authored holes remain holes.
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(_families[family].fixed_faces);shape.backface_collision=true
		var body := StaticBody3D.new();body.name="FixedMachineryStructure"
		body.collision_layer=1;body.collision_mask=0
		var collision := CollisionShape3D.new();collision.name="ExactVisibleStructure";collision.shape=shape
		root.add_child(body);body.add_child(collision)
		var colliders: Dictionary={"fixed_structure":{"body":body,"node":collision,"shape":shape}}
		var remaining: int=int(finite.healing_remaining[station.id])
		var row: Dictionary={"id":station.id,"chapter":level.layout.data.id,"family":family,"root":root,"root_transform":root.transform,"visual":visual,"nodes":nodes,"colliders":colliders,"remaining":remaining,"capacity":int(station.capacity)}
		level.healing_stations[station.id]=row;_roots[station.id]=root;_capacities[station.id]=int(station.capacity)
		_apply_stock(row,remaining)
		if not validate_station(station.id,true): return _fail("station bind "+station.id)
	return _roots.size()==Supply.chapter(level.layout).stations.size()

func _apply_stock(row: Dictionary, remaining: int) -> void:
	var ratio: float=float(remaining)/float(row.capacity)
	var pin: Dictionary=_registry.families[row.family].stock
	var fluid: MeshInstance3D=row.nodes.StockVolume
	fluid.position=Vector3(0,float(pin.bottomMeters),0)
	fluid.scale=Vector3(1,float(pin.fullHeightMeters)*(ratio if ratio>0.0 else 1.0),1)
	fluid.visible=remaining>0
	var needle: MeshInstance3D=row.nodes.StockNeedle
	needle.rotation=Vector3(0,0,lerpf(-PI*.75,PI*.75,ratio))
	row.remaining=remaining

func update_stock(id: String, remaining: int, capacity: int) -> bool:
	if not validate_station(id,false): return false
	var row: Dictionary=_level.healing_stations[id]
	if capacity!=row.capacity or remaining<0 or remaining>capacity: return false
	_apply_stock(row,remaining)
	return validate_station(id,false)

func validate_station(id: String, deep: bool=true) -> bool:
	if deep and not _texture_matches(_atlas): return false
	if not is_instance_valid(_level) or not _roots.has(id) or not _level.transform.is_equal_approx(_initial_level_transform): return false
	var row=_level.healing_stations.get(id)
	if not row is Dictionary or row.get("id")!=id or row.get("chapter")!=_level.layout.data.id or row.get("capacity")!=_capacities.get(id): return false
	var placement: Dictionary=_placements[id]
	if row.get("family")!=placement.family or not _families.has(row.family): return false
	if not row.get("nodes") is Dictionary or not row.get("colliders") is Dictionary or not row.get("remaining") is int: return false
	var root=row.get("root")
	if not root is Node3D: return false
	if not is_instance_valid(root) or root!=_roots[id] or root.get_parent()!=_level or root.is_queued_for_deletion() or not root.is_inside_tree() or not root.is_visible_in_tree(): return false
	var expected_transform := Transform3D(Basis(Vector3.UP,deg_to_rad(float(placement.yaw_degrees))),_level.layout.world_position(placement.cell))
	if not root.transform.is_equal_approx(expected_transform): return false
	for other in _level.healing_stations:
		if not _level.healing_stations[other] is Dictionary: return false
		if other!=id and _level.healing_stations[other].get("root")==root: return false
	var visual=row.get("visual")
	if not visual is Node3D: return false
	if not is_instance_valid(visual) or visual.get_parent()!=root or visual.is_queued_for_deletion() or visual.scene_file_path!=_registry.families[row.family].path or not visual.transform.is_equal_approx(Transform3D.IDENTITY) or not visual.is_visible_in_tree(): return false
	var nodes: Dictionary=_named(visual);var binding: Dictionary=_families[row.family]
	if nodes.size()!=binding.specs.size() or nodes.size()!=row.nodes.size(): return false
	var ratio: float=float(row.remaining)/float(row.capacity)
	if row.capacity<=0 or row.remaining<0 or row.remaining>row.capacity: return false
	for name in binding.specs:
		if not nodes.has(name) or nodes[name]!=row.nodes.get(name): return false
		var part: Node3D=nodes[name];var pin: Array=binding.specs[name]
		if part.is_queued_for_deletion() or not part.is_inside_tree(): return false
		var pos: Vector3=_position(pin);var scale: Vector3=_scale(pin);var rotation: Vector3=Vector3.ZERO
		if name=="StockVolume": scale.y*=ratio if ratio>0.0 else 1.0
		if name=="StockNeedle": rotation.z=lerpf(-PI*.75,PI*.75,ratio)
		if not part.position.is_equal_approx(pos) or not part.scale.is_equal_approx(scale) or not part.rotation.is_equal_approx(rotation) or absf(part.transform.basis.determinant())<.00001: return false
		if pin[0]=="":
			if part is MeshInstance3D: return false
			continue
		if not part is MeshInstance3D: return false
		var mesh_part := part as MeshInstance3D
		if mesh_part.mesh!=binding.meshes[name] or not _material_ok(mesh_part,binding.materials[name]): return false
		if name=="StockVolume":
			if mesh_part.visible!=(row.remaining>0): return false
		elif not mesh_part.is_visible_in_tree(): return false
		if deep and _render_sha(mesh_part.mesh)!=pin[0]: return false
	# The imported anchor is NOT the visible control. Both are independently source-pinned.
	var anchor: Node3D=nodes.UseTarget;var control: MeshInstance3D=nodes.DialFace
	var local_control: Vector3=control.transform*control.mesh.get_aabb().get_center()
	if not (anchor.position-local_control).is_equal_approx(Vector3(0,0,-.025)): return false
	if nodes.StockNeedle.position.distance_to(local_control)>.02: return false
	if row.colliders.size()!=1 or not row.colliders.has("fixed_structure") or root.get_child_count()!=2: return false
	if root.find_children("*","MeshInstance3D",true,false).size()!=binding.meshes.size(): return false
	if root.find_children("*","CollisionShape3D",true,false).size()!=1: return false
	var fixed=row.colliders.fixed_structure
	if not fixed is Dictionary: return false
	var body=fixed.get("body");var collision=fixed.get("node")
	if not body is StaticBody3D or not collision is CollisionShape3D: return false
	if not is_instance_valid(body) or body.get_parent()!=root or body.is_queued_for_deletion() or body.get_child_count()!=1 or body.collision_layer!=1 or body.collision_mask!=0: return false
	if not body.transform.is_equal_approx(Transform3D.IDENTITY) or not is_instance_valid(collision) or collision.get_parent()!=body or collision.disabled or not collision.transform.is_equal_approx(Transform3D.IDENTITY): return false
	var polygon := collision.shape as ConcavePolygonShape3D
	if polygon==null or polygon!=fixed.get("shape") or not polygon.backface_collision: return false
	if deep and _shape_sha(polygon.get_faces())!=binding.fixed_sha: return false
	return true

func use_target(id: String) -> MeshInstance3D:
	if not validate_station(id,false): return null
	return _level.healing_stations[id].nodes.DialFace

func station_world_point(id: String) -> Vector3:
	if not validate_station(id,false): return Vector3.INF
	return _level.healing_stations[id].nodes.UseTarget.global_position

func root_point(id: String) -> Vector3:
	return _roots[id].position if _roots.has(id) and is_instance_valid(_roots[id]) else Vector3.INF

func validate_book(finite: Dictionary, deep: bool=true) -> bool:
	if not is_instance_valid(_level) or _level.healing_stations.size()!=_roots.size(): return false
	var expected: Array=Supply.chapter(_level.layout).stations
	if expected.size()!=_roots.size(): return false
	for station in expected:
		if not validate_station(station.id,deep): return false
		var row: Dictionary=_level.healing_stations[station.id]
		if row.remaining!=int(finite.healing_remaining[station.id]) or row.capacity!=int(station.capacity): return false
	return true
