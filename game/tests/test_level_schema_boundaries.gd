extends SceneTree
const Schema = preload("res://scripts/level_schema.gd")
var failures := 0
func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/01_intake.json"))
	for name in ["door_requires","cue_text","cue_sound","floor_work","floor_native","tiny_cell","support_product","light_target","huge_amount","pickup_id","encounter_id","interaction_dispatch"]:
		var bad: Dictionary = baseline.duplicate(true)
		var field := ""
		match name:
			"door_requires": bad.doors[0].erase("requires"); field = "doors[0].requires"
			"cue_text": bad.encounters[0].cue.erase("text"); field = "cue.text"
			"cue_sound": bad.encounters[0].cue.erase("sound"); field = "cue.sound"
			"floor_work": bad.rects = [[0,0,100000,100000]]; field = "rects"
			"floor_native": bad.rects = [[1e20,0,1e20,0]]; field = "rects"
			"tiny_cell": bad.cell_size = 1e-100; field = "cell_size"
			"support_product":
				bad.scenery[0]["scale"] = [2e20,2e20,2e20]
				bad.scenery[0]["supports"] = [{"offset":[0,0,0],"size":[2e20,2e20,2e20]}]
				field = "scenery[0]"
			"light_target": bad.lights[0]["target"] = [1e38,1]; field = "lights[0].target"
			"huge_amount": bad.pickups[0].amount = 1e100; field = "pickups[0].amount"
			"pickup_id": bad.pickups[0].id = "p".repeat(129); field = "pickups[0].id"
			"encounter_id": bad.encounters[0].id = "e".repeat(119); field = "encounters[0].id"
			"interaction_dispatch": bad.interactions[0]["size"] = [1,1,1]; field = "interactions[0].size"
		var error: String = Schema.validate(bad,art_exists)
		var rejected := not error.is_empty() and field in error
		print("SCHEMA_BOUNDARY ",name," rejected=",rejected," detail=",error)
		if not rejected:
			failures += 1
			push_error("NC13 reviewed consumer boundary must reject "+name)
	check_exact_boundaries(baseline)
	if failures == 0: print("PASS reviewed schema consumer boundaries without expanding hostile rectangles")
	quit(0 if failures == 0 else 1)
func art_exists(id: String) -> bool:
	return ResourceLoader.exists("res://assets/art/world/"+id+".glb")


func check_exact_boundaries(baseline: Dictionary) -> void:
	for rect in [[0,0,127,127],[-4194303,0,-4194303,0],[4194303,0,4194303,0]]:
		var valid: Dictionary = baseline.duplicate(true)
		valid.rects = [rect]
		check(valid,"", "floor at permitted expansion/native boundary")
	for rect in [[0,0,128,127],[-2147483648,0,-2147483648,0],[2147483647,0,2147483647,0],[-2147483647,0,-2147483647,0],[2147483646,0,2147483646,0]]:
		var bad: Dictionary = baseline.duplicate(true)
		bad.rects = [rect]
		check(bad,"rects", "floor beyond permitted expansion/native boundary")
	var valid: Dictionary = baseline.duplicate(true)
	valid.rects = [[0,0,127,63],[0,0,127,63]]
	check(valid,"", "raw duplicate rectangle work exactly 16384")
	valid.rects.append([0,0,0,0])
	check(valid,"rects", "raw duplicate rectangle work 16385")
	var bad: Dictionary = baseline.duplicate(true)
	bad.rects = [[1073741889,0,1073741889,0]]
	bad.cell_size = 3.4028234e38 / 1073741890
	bad.spawn = [0,0]
	check(bad,"rects", "native coordinate rounding before scaling cannot overflow corners")
	bad = baseline.duplicate(true)
	bad.spawn = [0,0]
	bad.cell_size = 1e38
	bad.rects = [[3,0,3,0]]
	check(bad,"rects", "finite tile origin with overflowing next floor corner")
	for amount in [2147483647,2147483647.0]:
		valid = baseline.duplicate(true)
		valid.pickups[0].amount = amount
		check(valid,"", "maximum exact pickup amount remains valid")
	valid.pickups[0].amount = 2147483648.0
	check(valid,"pickups[0].amount", "amount above conversion/addition limit")
	if int(2147483647.0)+9999 != 2147493646:
		failures += 1
		push_error("Maximum accepted grant plus maximum campaign ammo must add exactly")
	for value in [1e-30,1.0]:
		valid = baseline.duplicate(true)
		valid.cell_size = value
		check(valid,"", "positive native cell size")
	for value in [0.0,1e-100]:
		bad = baseline.duplicate(true)
		bad.scenery[0]["scale"] = [value,1,1]
		check(bad,"scenery[0].scale", "zero or underflowing native dimension")
	valid = baseline.duplicate(true)
	valid.scenery[0]["scale"] = [1e10,1e10,1e10]
	valid.scenery[0]["supports"] = [{"offset":[-1e10,1e10,1e10],"size":[1e10,1e10,1e10]}]
	check(valid,"", "finite positive component products and signed offsets")
	bad = baseline.duplicate(true)
	bad.scenery[0]["scale"] = [1e20,1e20,1e20]
	bad.scenery[0]["supports"] = [{"offset":[-1e20,0,0],"size":[1,1,1]}]
	check(bad,"scenery[0].supports[0].offset", "overflowing signed support offset product")
	bad = baseline.duplicate(true)
	bad.scenery[0]["scale"] = [1e-30,1,1]
	bad.scenery[0]["supports"] = [{"offset":[0,0,0],"size":[1e-30,1,1]}]
	check(bad,"scenery[0].supports[0].size", "positive component product rounds to zero")
	for target in [[1e20,1],[-1e20,-1]]:
		valid = baseline.duplicate(true)
		valid.lights[0]["target"] = target
		check(valid,"", "finite positive/negative scaled light target")
	bad = baseline.duplicate(true)
	bad.lights[0]["target"] = [-1e38,1]
	check(bad,"lights[0].target", "negative scaled light target overflow")
	for length in [128,129]:
		valid = baseline.duplicate(true)
		valid.pickups[0].id = "p".repeat(length)
		check(valid,"" if length == 128 else "pickups[0].id", "persisted pickup ID length "+str(length))
		valid = baseline.duplicate(true)
		valid.interactions[2].id = "c".repeat(length)
		check(valid,"" if length == 128 else "interactions[2].id", "checkpoint ID length "+str(length))
		valid = baseline.duplicate(true)
		valid.interactions.append({"id":"extra_key","kind":"key","key":"k".repeat(length),"cell":[1,1],"text":"Extra seal"})
		check(valid,"" if length == 128 else "interactions[5].key", "persisted seal ID length "+str(length))
	for length in [118,119]:
		valid = baseline.duplicate(true)
		valid.encounters[0].id = "e".repeat(length)
		check(valid,"" if length == 118 else "encounters[0].id", "prefixed encounter ID length "+str(length))
	for length in [119,120]:
		valid = baseline.duplicate(true)
		valid.enemies.append({"id":"s".repeat(length),"kind":"summoner","cell":[1,1],"yaw":0})
		check(valid,"" if length == 119 else "enemies[23].id", "generated summon ID length "+str(length))
	bad = baseline.duplicate(true)
	bad.elevations[0].height = 2e38
	bad.lights[0].height = 2e38
	check(bad,"lights[0].height", "finite height components overflow their native sum")
	bad = baseline.duplicate(true)
	bad.elevations[0].height = 2e38
	bad.ceilings[0].height = 2e38
	check(bad,"ceilings[0].height", "finite floor/roof components overflow their native sum")
	valid = baseline.duplicate(true)
	valid.doors[0].requires = []
	check(valid,"", "explicit empty door requirements remain valid")
	valid.heroes[0]["supports"] = "inert metadata"
	check(valid,"", "scenery support metadata is inert on unrelated hero records")

func check(content: Dictionary, field: String, detail: String) -> void:
	var before: Dictionary = content.duplicate(true)
	var error: String = Schema.validate(content,art_exists)
	var passed: bool = error.is_empty() if field.is_empty() else not error.is_empty() and field in error
	if not passed or content != before:
		failures += 1
		push_error(detail+": "+error)
