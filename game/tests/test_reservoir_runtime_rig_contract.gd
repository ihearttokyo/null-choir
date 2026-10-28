extends SceneTree
## Actual imported-eight-family native contract. UNRUN until the native window opens.
const Runtime = preload("res://scripts/earned_supply_runtime.gd")
const Machinery = preload("res://scripts/healing_machinery.gd")
const Layout = preload("res://scripts/level_data.gd")
const Supply = preload("res://scripts/earned_supplies.gd")

class FixtureLevel:
	extends Node3D
	var layout = Layout.new()
	var healing_stations: Dictionary={}
	var healing_machinery = Machinery.new()
class FixtureState:
	extends RefCounted
	var earned_supply: Dictionary
class FixtureGame:
	extends RefCounted
	var level: Node3D
	var state = FixtureState.new()
	var enemies: Array=[]
	var failed: bool=false
	func fail_earned_transaction(_message: String) -> void: failed=true

var _ok: bool=true
func _expect(value: bool, message: String) -> void:
	_ok=_ok and value
	if not value: push_error("HEALING_MACHINERY_CONTRACT / "+message)
func _initialize() -> void:
	call_deferred("_run")

func _fixed_structure_ray(part: MeshInstance3D) -> PhysicsRayQueryParameters3D:
	# A strict interior point of an actual pinned support triangle, not its diagonal.
	var faces: PackedVector3Array=part.mesh.get_faces()
	for index in range(0,faces.size(),3):
		var normal: Vector3=(faces[index+1]-faces[index]).cross(faces[index+2]-faces[index])
		if normal.length_squared()<.000001: continue
		normal=normal.normalized()
		if absf(normal.z)<.99: continue
		var center: Vector3=(faces[index]+faces[index+1]+faces[index+2])/3.0
		var span: float=part.mesh.get_aabb().size.dot(normal.abs())+.05
		return PhysicsRayQueryParameters3D.create(part.to_global(center+normal*span),part.to_global(center-normal*span),1)
	return null

func _run() -> void:
	_expect(Machinery._quantize(.00005)==1 and Machinery._quantize(-.00005)==-1 and Machinery._quantize(.00025)==3 and Machinery._quantize(-.00025)==-3,"explicit signed half ties round away from zero")
	for index in range(8):
		var level := FixtureLevel.new();root.add_child(level)
		_expect(level.layout.load_level(index),"real chapter loads")
		var game := FixtureGame.new();game.level=level
		game.state.earned_supply=Supply.fresh(level.layout)
		var helper=level.healing_machinery
		var built: bool=helper.build(level,game.state.earned_supply)
		_expect(built,"bind exact imported family "+str(index)+" / "+helper.error)
		if not built: level.free();continue
		# Actual compiled texture readback, normalized RGBA8; a same-path wrong-pixel resource must fail.
		var atlas: Texture2D=helper._atlas
		var image: Image=atlas.get_image()
		if image.is_compressed(): _expect(image.decompress()==OK,"compiled image decompresses")
		image.clear_mipmaps();image.convert(Image.FORMAT_RGBA8)
		var pixel_bytes: PackedByteArray=image.get_data();pixel_bytes[0]^=1
		var wrong_image := Image.create_from_data(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8,pixel_bytes)
		var wrong_texture := ImageTexture.create_from_image(wrong_image)
		var atlas_path: String=atlas.resource_path
		wrong_texture.take_over_path(atlas_path)
		_expect(wrong_texture.resource_path==atlas_path and not helper._texture_matches(wrong_texture),"same-path actual wrong pixels rejected, not merely resource identity")
		atlas.take_over_path(atlas_path) # Restore loader mapping before any await or other check.
		_expect(helper._texture_matches(atlas),"actual compiled atlas positive restored")
		var runtime := Runtime.new();runtime.refresh(game)
		_expect(not game.failed and helper.validate_book(game.state.earned_supply,true),"real geometry/material/collision/source pins")
		await physics_frame
		await physics_frame
		for station in Supply.chapter(level.layout).stations:
			var row: Dictionary=level.healing_stations[station.id]
			var machine: Node3D=row.root
			var control: MeshInstance3D=row.nodes.DialFace
			var anchor: Node3D=row.nodes.UseTarget
			var fluid: MeshInstance3D=row.nodes.StockVolume
			var needle: MeshInstance3D=row.nodes.StockNeedle
			var fixed_ids: Array=[]
			for fixed in row.colliders.values(): fixed_ids.append(fixed.body.get_instance_id())
			_expect(runtime.station_use_target(game,station)==control and not anchor is MeshInstance3D,"real visible dial, not invisible anchor, owns use")
			var base_y: float=fluid.position.y
			var full_height: float=fluid.scale.y
			var mesh_bottom: float=fluid.mesh.get_aabb().position.y
			_expect(is_zero_approx(mesh_bottom),"real stock mesh authored bottom is zero")
			for remaining in [floori(float(station.capacity)/2.0),0,int(station.capacity)]:
				game.state.earned_supply.healing_remaining[station.id]=remaining
				runtime.refresh(game)
				var ratio: float=float(remaining)/float(station.capacity)
				_expect(machine==level.healing_stations[station.id].root,"stock refresh never replaces fixed root")
				_expect(is_equal_approx(fluid.position.y,base_y) and is_equal_approx(fluid.scale.y,full_height*(ratio if ratio>0 else 1.0)),"full/half/hidden-empty preserve real geometric bottom and invertible scale")
				_expect(absf(fluid.transform.basis.determinant())>.00001 and fluid.visible==(remaining>0),"empty rendered stock hidden; geometric full scale remains positive")
				_expect(is_equal_approx(needle.rotation.z,lerpf(-PI*.75,PI*.75,ratio)),"actual needle tracks authoritative remaining/capacity")
				var ids: Array=[]
				for fixed in row.colliders.values(): ids.append(fixed.body.get_instance_id())
				_expect(ids==fixed_ids and helper.validate_book(game.state.earned_supply,true),"all exact static collision survives refresh")
			# Each mutation tests actual hierarchy/geometry rather than making marker metadata agree.
			control.hide();_expect(runtime.station_use_target(game,station)==null,"hidden physical dial rejected");control.show()
			var wheel: MeshInstance3D=row.nodes.ValveWheel_00
			wheel.hide();_expect(runtime.station_use_target(game,station)==null,"hidden handwheel rejected");wheel.show()
			# Mutate actual imported arrays independently of positions and resource-pointer guards.
			var arrays: Array=control.mesh.surface_get_arrays(0)
			var actual_render: String=Machinery._render_arrays_sha(arrays)
			var uv_arrays: Array=arrays.duplicate(true)
			var wrong_uvs: PackedVector2Array=uv_arrays[Mesh.ARRAY_TEX_UV]
			wrong_uvs[0]+=Vector2(.1,0);uv_arrays[Mesh.ARRAY_TEX_UV]=wrong_uvs
			_expect(uv_arrays[Mesh.ARRAY_VERTEX]==arrays[Mesh.ARRAY_VERTEX] and Machinery._render_arrays_sha(uv_arrays)!=actual_render,"same-position real UV mutation rejected")
			var color_arrays: Array=arrays.duplicate(true)
			var wrong_colors: PackedColorArray=color_arrays[Mesh.ARRAY_COLOR]
			var changed: Color=wrong_colors[0];changed.r=changed.r-.1 if changed.r>.5 else changed.r+.1;wrong_colors[0]=changed;color_arrays[Mesh.ARRAY_COLOR]=wrong_colors
			_expect(color_arrays[Mesh.ARRAY_VERTEX]==arrays[Mesh.ARRAY_VERTEX] and Machinery._render_arrays_sha(color_arrays)!=actual_render,"same-position real COLOR mutation rejected")
			var normal_arrays: Array=arrays.duplicate(true)
			var wrong_normals: PackedVector3Array=normal_arrays[Mesh.ARRAY_NORMAL]
			wrong_normals[0]=-wrong_normals[0];normal_arrays[Mesh.ARRAY_NORMAL]=wrong_normals
			_expect(normal_arrays[Mesh.ARRAY_VERTEX]==arrays[Mesh.ARRAY_VERTEX] and Machinery._render_arrays_sha(normal_arrays)!=actual_render,"same-position real NORMAL mutation rejected")
			var winding_arrays: Array=arrays.duplicate(true)
			var wrong_indices := PackedInt32Array()
			if winding_arrays[Mesh.ARRAY_INDEX]!=null: wrong_indices=winding_arrays[Mesh.ARRAY_INDEX]
			if wrong_indices.is_empty():
				for vertex in range(arrays[Mesh.ARRAY_VERTEX].size()): wrong_indices.append(vertex)
			var index_one: int=wrong_indices[1];wrong_indices[1]=wrong_indices[2];wrong_indices[2]=index_one;winding_arrays[Mesh.ARRAY_INDEX]=wrong_indices
			_expect(winding_arrays[Mesh.ARRAY_VERTEX]==arrays[Mesh.ARRAY_VERTEX] and Machinery._render_arrays_sha(winding_arrays)!=actual_render,"same-position oriented winding mutation rejected")
			# SAME canonical material, no replacement pointer or changed geometry/pixels.
			var painted := control.mesh.surface_get_material(0) as BaseMaterial3D
			var material_identity: int=painted.get_instance_id()
			_expect(painted.vertex_color_use_as_albedo,"import explicitly enables authored COLOR_0 albedo route")
			painted.vertex_color_use_as_albedo=false
			_expect(runtime.station_use_target(game,station)==null and not painted.vertex_color_use_as_albedo,"live disabled COLOR_0 route rejected without runtime auto-repair")
			painted.vertex_color_use_as_albedo=true
			_expect(runtime.station_use_target(game,station)==control,"authored COLOR_0 albedo route restored")
			var original_uv_scale: Vector3=painted.uv1_scale;var original_uv_offset: Vector3=painted.uv1_offset
			var original_triplanar: bool=painted.uv1_triplanar;var original_world_triplanar: bool=painted.uv1_world_triplanar;var original_points: bool=painted.use_point_size
			var original_filter: int=painted.texture_filter;var original_repeat: bool=painted.texture_repeat
			var original_detail: bool=painted.detail_enabled;var original_detail_texture: Texture2D=painted.detail_albedo
			var original_height: bool=painted.heightmap_enabled;var original_height_texture: Texture2D=painted.heightmap_texture
			painted.uv1_scale=Vector3.ZERO
			_expect(painted.get_instance_id()==material_identity and runtime.station_use_target(game,station)==null,"same canonical material zero UV1 scale rejected")
			painted.uv1_scale=original_uv_scale
			painted.uv1_offset=Vector3(.1,0,0);_expect(runtime.station_use_target(game,station)==null,"same material UV1 offset rejected");painted.uv1_offset=original_uv_offset
			painted.uv1_triplanar=true;_expect(runtime.station_use_target(game,station)==null,"same material alternate triplanar rejected");painted.uv1_triplanar=original_triplanar
			painted.uv1_world_triplanar=true;_expect(runtime.station_use_target(game,station)==null,"same material world projection rejected");painted.uv1_world_triplanar=original_world_triplanar
			painted.use_point_size=true;_expect(runtime.station_use_target(game,station)==null,"same material point coordinate route rejected");painted.use_point_size=original_points
			painted.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;_expect(runtime.station_use_target(game,station)==null,"same material source LINEAR sampler drift rejected");painted.texture_filter=original_filter
			painted.texture_repeat=true;_expect(runtime.station_use_target(game,station)==null,"same material source CLAMP sampler drift rejected");painted.texture_repeat=original_repeat
			painted.detail_albedo=atlas;painted.detail_enabled=true
			_expect(runtime.station_use_target(game,station)==null,"same material detail route with actual texture rejected")
			painted.detail_enabled=original_detail;painted.detail_albedo=original_detail_texture
			painted.heightmap_texture=atlas;painted.heightmap_enabled=true
			_expect(runtime.station_use_target(game,station)==null,"same material parallax route with actual texture rejected")
			painted.heightmap_enabled=original_height;painted.heightmap_texture=original_height_texture
			_expect(painted.get_instance_id()==material_identity and painted.uv1_scale==original_uv_scale and painted.uv1_offset==original_uv_offset and runtime.station_use_target(game,station)==control,"same material exact source route restored after all controls")
			var saved_transform: Transform3D=control.transform
			control.position.x+=.01;_expect(runtime.station_use_target(game,station)==null,"moved real dial rejected");control.transform=saved_transform
			var saved_mesh: Mesh=control.mesh
			control.mesh=SphereMesh.new();_expect(runtime.station_use_target(game,station)==null,"substituted visible mesh rejected");control.mesh=saved_mesh
			var fake := StandardMaterial3D.new();fake.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;fake.albedo_color.a=.1
			control.material_override=fake;_expect(runtime.station_use_target(game,station)==null,"transparent/override geometry rejected");control.material_override=null
			anchor.position.z-=.01;_expect(runtime.station_use_target(game,station)==null,"anchor drift rejected against physical dial center");anchor.position.z+=.01
			machine.rotation.y+=.1;_expect(runtime.station_use_target(game,station)==null,"root/yaw drift rejected");machine.rotation.y-=.1
			row.id="foreign";_expect(runtime.station_use_target(game,station)==null,"foreign station identity rejected");row.id=station.id
			var duplicate: Node=control.duplicate();row.visual.add_child(duplicate)
			_expect(runtime.station_use_target(game,station)==null,"duplicate actual control rejected");duplicate.free()
			needle.rotation.z+=.1;_expect(runtime.station_use_target(game,station)==null,"lying real stock needle rejected");needle.rotation.z-=.1
			fluid.scale.y*=.5;_expect(runtime.station_use_target(game,station)==null,"lying physical stock transform rejected");fluid.scale.y*=2.0
			var fixed: Dictionary=row.colliders.values()[0]
			# Transform and disabled changes reach PhysicsServer on physics ticks, not on
			# the scene property readback. Establish physical witnesses on both sides.
			await physics_frame
			await physics_frame
			var frame_ray: PhysicsRayQueryParameters3D=_fixed_structure_ray(row.nodes["RearColumn_-0_32"])
			_expect(frame_ray!=null,"actual source support supplies strict interior triangle LOS witness")
			if frame_ray==null: continue
			var space: PhysicsDirectSpaceState3D=level.get_world_3d().direct_space_state
			var baseline_hit: Dictionary=space.intersect_ray(frame_ray)
			_expect(baseline_hit.get("collider")==fixed.body and not runtime._clear(level,frame_ray.from,frame_ray.to),"enabled exact owning structure blocks actual production LOS before controls")
			var old_ray := PhysicsRayQueryParameters3D.create(machine.to_global(Vector3(-.32,.68,-.6)),machine.to_global(Vector3(-.32,.68,.4)),1)
			var old_baseline_hit: Dictionary=space.intersect_ray(old_ray)
			fixed.node.disabled=true
			_expect(not helper.validate_station(station.id,true),"disabled structural collision rejected")
			await physics_frame
			await physics_frame
			_expect(space.intersect_ray(frame_ray).is_empty() and runtime._clear(level,frame_ray.from,frame_ray.to),"same physical witness clears only after exact structure disabled and physics synchronized")
			fixed.node.disabled=false
			var immediate_hit: Dictionary=space.intersect_ray(frame_ray)
			await physics_frame
			await physics_frame
			_expect(helper.validate_station(station.id,true) and runtime.station_use_target(game,station)==control,"all exact bindings restore after controls")
			var aim: Vector3=helper.station_world_point(station.id)
			var origin: Vector3=machine.to_global(Vector3(anchor.position.x,anchor.position.y,-.8))
			var front_ray := PhysicsRayQueryParameters3D.create(origin,aim,1)
			_expect(space.intersect_ray(front_ray).is_empty() and runtime._clear(level,origin,aim),"actual visible control front point is not self-occluded")
			var restored_hit: Dictionary=space.intersect_ray(frame_ray)
			_expect(restored_hit.get("collider")==fixed.body and not runtime._clear(level,frame_ray.from,frame_ray.to),"exact fixed structure blocks real LOS; no own-fixture bypass")
			print("HEALING_LOS_WITNESS ",JSON.stringify({"station":station.id,"family":row.family,"old_center_ray_after_sync":old_baseline_hit.get("collider")==fixed.body,"triangle_ray_before_disable":baseline_hit.get("collider")==fixed.body,"triangle_ray_immediate_restore":immediate_hit.get("collider")==fixed.body,"triangle_ray_after_sync":restored_hit.get("collider")==fixed.body}))
		level.free()
	print("RESERVOIR_RIG_CONTRACT ","PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
