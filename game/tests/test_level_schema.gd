extends SceneTree

const Schema = preload("res://scripts/level_schema.gd")
const FILES = ["01_intake", "02_foundry", "03_processional", "04_reliquary", "05_nursery", "06_ossuary", "07_inversion", "08_heart"]

func _initialize() -> void:
	var sources: Array = []
	for file in FILES:
		var parser = JSON.new()
		if not expect(parser.parse(FileAccess.get_file_as_string("res://data/"+file+".json")) == OK, file+": real JSON parses"): return
		var content: Dictionary = parser.data
		var before: Dictionary = content.duplicate(true)
		var error: String = Schema.validate(content, art_exists)
		if not expect(error.is_empty(), file+": "+error): return
		if not expect(content == before, file+": validation must not mutate primitives"): return
		sources.append(content)
	var baseline: Dictionary = sources[0]
	for mutation in [
		["enemies",1,"id",baseline.enemies[0].id,"enemies[1].id"],
		["pickups",0,"id",baseline.interactions[0].id,"pickups[0].id"],
		["enemies",0,"kind","unknown_role","enemies[0].kind"],
		["pickups",0,"weapon",6,"pickups[0].weapon"],
		["pickups",0,"weapon",1.5,"pickups[0].weapon"],
		["scenery",0,"art","missing_art","scenery[0].art"],
		["scenery",0,"art","../skin_bell","scenery[0].art"],
		["encounters",0,"enemy_ids",["missing_enemy"],"encounters[0].enemy_ids"],
		["encounters",0,"requires",["missing_seal"],"encounters[0].requires"],
		["interactions",2,"requires",[baseline.interactions[0].id],"interactions[2].requires"],
		["interactions",4,"requires_defeated",["missing_enemy"],"interactions[4].requires_defeated"],
		["heroes",0,"light_ids",["missing_light"],"heroes[0].light_ids"],
		["heroes",0,"base",[1,0,1],"heroes[0].base"],
		["lights",0,"shadow",1,"lights[0].shadow"],
		["enemies",0,"cell",[1],"enemies[0].cell"],
		["enemies",0,"cell",[1e100,1],"enemies[0].cell"],
		["scenery",0,"supports",[{"offset":[0,0,0],"size":[1,-1,1]}],"scenery[0].supports[0].size"],
		["lights",1,"id",baseline.lights.filter(func(light): return light.has("id"))[0].id,"lights"],
		["pickups",0,"amount",true,"pickups[0].amount"],
		["pickups",0,"amount",0,"pickups[0].amount"],
		["elevations",0,"rect",[0,0,-1,1],"elevations[0].rect"],
		["enemies",0,"yaw",true,"enemies[0].yaw"],
		["elevations",0,"axis",2,"elevations[0].axis"],
		["elevations",0,"end",baseline.elevations[0].start,"elevations[0].end"],
		["loops",0,"hero","missing_hero","loops[0].hero"],
		["loops",1,"hero",baseline.loops[0].hero,"loops[1].hero"],
		["loops",0,"route",[[0,0],[1,0],[1,1]],"loops[0].route"],
		["loops",0,"route",[[0,0],[0,0],[0,0],[0,0]],"loops[0].route"]]:
		var bad: Dictionary = baseline.duplicate(true)
		bad[mutation[0]][mutation[1]][mutation[2]] = mutation[3]
		if not rejected(bad,mutation[4]): return
	for value in [null,true,"4",0,-1,NAN,INF,-INF]:
		var bad: Dictionary = baseline.duplicate(true)
		bad.cell_size = value
		if not rejected(bad,"cell_size"): return
	for value in [true,NAN,INF,-INF]:
		for path in [["enemies",0,"yaw"],["elevations",0,"height"],["lights",0,"energy"]]:
			var bad: Dictionary = baseline.duplicate(true)
			bad[path[0]][path[1]][path[2]] = value
			if not rejected(bad,path[0]+"[0]."+path[2]): return
	for value in [null,[],true]:
		if not rejected(value,"level"): return
	var bad: Dictionary = baseline.duplicate(true)
	bad.enemies = {}
	if not rejected(bad,"enemies"): return
	bad = baseline.duplicate(true)
	bad.encounters[1].enemy_ids.append(bad.encounters[0].enemy_ids[0])
	if not rejected(bad,"encounters[1].enemy_ids"): return
	bad = baseline.duplicate(true)
	bad["visual_profile"] = {"unknown_setting":1}
	if not rejected(bad,"visual_profile"): return
	bad = baseline.duplicate(true)
	bad["optional_metadata"] = {"value":NAN}
	if not rejected(bad,"optional_metadata.value"): return
	bad = baseline.duplicate(true)
	bad.rects[0][0] = 11.5
	if not rejected(bad,"rects[0]"): return
	bad = baseline.duplicate(true)
	bad.encounters[0].cue.light_ids = ["missing_light"]
	if not rejected(bad,"encounters[0].cue.light_ids"): return
	bad = baseline.duplicate(true)
	bad["optional_metadata"] = RefCounted.new()
	if not rejected(bad,"optional_metadata"): return
	var valid: Dictionary = baseline.duplicate(true)
	valid.pickups[0].weapon = 1.0
	valid.rects[0][0] = float(valid.rects[0][0])
	valid.scenery.append(valid.scenery[0].duplicate(true))
	valid["optional_metadata"] = {"label":"inert", "weight":0.5}
	if not expect(Schema.validate(valid,art_exists).is_empty(),"Integer-valued JSON floats, repeated scenery art and inert primitive metadata remain valid"): return
	if not expect(not Schema.validate(baseline,Callable()).is_empty(),"Art boundary must be supplied"): return
	print("PASS pure schema: eight real sources, domain IDs, references, shapes, numeric safety and loop associations")
	quit(0)

func art_exists(id: String) -> bool:
	return ResourceLoader.exists("res://assets/art/world/"+id+".glb")

func rejected(content: Variant, field: String) -> bool:
	var error: String = Schema.validate(content,art_exists)
	return expect(not error.is_empty() and field in error,"Malformed "+field+" must give its field error, got: "+error)

func expect(ok: bool, detail: String) -> bool:
	if not ok:
		push_error("Level schema: "+detail)
		quit(1)
	return ok
