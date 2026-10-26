extends RefCounted
## Static processional vaults: an architectural rhythm tied to the authored loops.
## These are overhead dressings, never replacement terrain or navigation geometry.
## One surface/material per level; no lights, animation, collision or process ticks.
const CLEARANCE = 4.8
const THICKNESS = 0.22
const MAX_FRAMES = 16
const PROFILES = {
	"intake": [[-1.0,0.0],[-1.0,0.68],[-0.68,1.0],[0.68,1.0],[1.0,0.68],[1.0,0.0]],
	"foundry": [[-1.0,0.0],[-1.0,0.55],[-0.6,0.55],[-0.6,1.0],[0.6,1.0],[0.6,0.55],[1.0,0.55],[1.0,0.0]],
	"processional": [[-1.0,0.0],[-0.8,0.5],[0.0,1.0],[0.8,0.5],[1.0,0.0]],
	"reliquary": [[-1.0,0.0],[-1.0,0.6],[-0.55,1.0],[0.55,1.0],[1.0,0.6],[1.0,0.0]],
	"nursery": [[-1.0,0.8],[-0.75,0.2],[0.0,0.0],[0.75,0.2],[1.0,0.8]],
	"ossuary": [[-1.0,0.0],[-0.9,0.45],[-0.5,0.85],[0.0,1.0],[0.5,0.85],[0.9,0.45],[1.0,0.0]],
	"inversion": [[-1.0,1.0],[-0.75,0.5],[0.0,0.0],[0.75,0.5],[1.0,1.0]],
	"heart": [[-1.0,0.9],[-0.85,0.3],[-0.4,0.0],[0.0,0.3],[0.4,0.0],[0.85,0.3],[1.0,0.9]]
}

# A frame spans only contiguous walkable tiles. Roof/floor bounds are sampled at
# every floor corner under the entire span, including both sides of its thickness.
static func plan(layout) -> Array:
	var frames: Array = []
	var occupied: Dictionary = {}
	for loop in layout.data.loops:
		var route: Array = loop.route
		for i in range(1,route.size()-1):
			var center = Vector2(route[i][0],route[i][1])
			var previous = Vector2(route[i-1][0],route[i-1][1])
			var forward = (center-previous).normalized()
			# Only cardinal route segments: diagonal turns retain their authored view.
			if absf(forward.x) > 0.01 and absf(forward.y) > 0.01: continue
			var tile = Vector2i(center.floor())
			if occupied.has(tile) or not layout.is_walkable(tile): continue
			var across = Vector2i(0,1) if absf(forward.x) > 0.5 else Vector2i(1,0)
			var low: Vector2i = tile
			var high: Vector2i = tile
			while layout.is_walkable(low-across) and (tile-low).length() < 3: low -= across
			while layout.is_walkable(high+across) and (high-tile).length() < 3: high += across
			var size = float(layout.data.cell_size)
			var width = float((high-low).length()+1)*size-0.8
			var floor_top: float = -INF
			var roof_bottom: float = INF
			var cursor: Vector2i = low
			while true:
				var roof: float = layout.roof_height(cursor)
				for corner in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
					var height: float = layout.height_at(Vector2(cursor)+corner)
					floor_top = maxf(floor_top,height)
					roof_bottom = minf(roof_bottom,height+roof)
				if cursor == high: break
				cursor += across
			var bottom = floor_top+CLEARANCE+THICKNESS
			var top = roof_bottom-0.35-THICKNESS
			if top-bottom < 0.25: continue
			var midpoint = (Vector2(low+high)+Vector2.ONE)*0.5*size
			frames.append({"center":Vector3(midpoint.x,bottom,midpoint.y),"across":Vector3(across.x,0,across.y),"width":width,"rise":minf(top-bottom,4.5),"floor_top":floor_top,"roof_bottom":roof_bottom})
			occupied[tile] = true
			if frames.size() >= MAX_FRAMES: return frames
	return frames

static func build(level: Node3D, layout) -> void:
	var frames = plan(layout)
	if frames.is_empty(): return
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var profile: Array = PROFILES[layout.data.id]
	for frame in frames:
		for i in range(profile.size()-1):
			var a = frame.center+frame.across*float(profile[i][0])*frame.width*0.5+Vector3.UP*float(profile[i][1])*frame.rise
			var b = frame.center+frame.across*float(profile[i+1][0])*frame.width*0.5+Vector3.UP*float(profile[i+1][1])*frame.rise
			_beam(tool,a,b)
	tool.generate_normals()
	var mesh = MeshInstance3D.new()
	mesh.name = "ProcessionalVaults_"+str(layout.data.id)
	mesh.mesh = tool.commit()
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.38,0.31,0.27)
	material.roughness = 0.87
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(mesh)

static func _beam(tool: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var direction = (b-a).normalized()
	var normal = direction.cross(Vector3.FORWARD)
	if normal.length_squared() < 0.01: normal = direction.cross(Vector3.RIGHT)
	normal = normal.normalized()*THICKNESS*0.5
	var side = direction.cross(normal).normalized()*THICKNESS*0.5
	var corners = [a-normal-side,a+normal-side,a+normal+side,a-normal+side,b-normal-side,b+normal-side,b+normal+side,b-normal+side]
	for face in [[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
		for index in [0,1,2,0,2,3]: tool.add_vertex(corners[face[index]])
