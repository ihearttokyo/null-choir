extends SceneTree

class ArtProbe extends "res://scripts/hud.gd":
	var sprites: Array = []

	func _hud_sprite(id: String, rect: Rect2, tint: Color = Color.WHITE, flip: Vector2 = Vector2.ONE) -> void:
		sprites.append({"id":id,"rect":rect,"tint":tint,"flip":flip})

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var hud = ArtProbe.new()
	if not expect(hud.has_method("_instrument_art") and hud.has_method("_hud_region"),"Intended RED: instrument must use the original native HUD atlas, not old vector glyphs"): return
	var atlas = load("res://assets/art/hud/hud_kit.png") as Texture2D
	if not expect(atlas != null and atlas.get_size() == Vector2(512,192),"Actual HUD texture is the compact native atlas"): return
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/hud/hud_kit.json"))
	for id in metadata.sprites:
		var region: Rect2 = hud.call("_hud_region",id)
		if not expect(region.size.x > 0 and region.size.y > 0 and Rect2(0,0,512,192).encloses(region),"Every sprite uses a nonempty actual metadata region"): return
	if not expect(hud.call("_hud_region","heart") == Rect2(0,0,64,64) and hud.call("_hud_region","frame_tile") == Rect2(453,80,54,32),"Icon cells and cropped tile come from actual pinned metadata"): return
	hud.view = {"health":100,"arsenal":[],"seals":[{"key":"blood","owned":false},{"key":"ivory","owned":false}],"progress":[]}
	for index in 6:
		hud.view.arsenal.append({"owned":true,"selected":index == 2,"empty":false,"low":false})
	for index in 8:
		hud.view.progress.append({"discovered":false,"current":index == 0})
	hud.call("_instrument_art")
	for id in ["heart","shield","ammo","impact_tool","rivet_pistol","scattergun","sawtooth_repeater","marrow_launcher","choir_disruptor"]:
		if not expect(count(hud,id) == 1,"Instrument draws each sculpted vital/ammo/weapon sprite once: "+id): return
	if not expect(count(hud,"seal_empty") == 2 and count(hud,"story_empty") == 8 and count(hud,"lock") == 0 and count(hud,"dry") == 0,"Unrecovered seals and all eight empty records use actual socket shapes"): return
	if not expect(has(hud,"slot_selected",Rect2(224,324,28,21)) and not has(hud,"slot_base",Rect2(224,324,28,21)),"Selected scattergun uses distinct selected chrome"): return
	if not expect(count(hud,"low_health") == 0,"Healthy vital icon has no wound-warning overlay"): return

	hud.sprites = []
	hud.view.arsenal[2].owned = false
	hud.view.arsenal[4].empty = true
	hud.view.arsenal[1].low = true
	hud.view.health = 25
	hud.view.seals[0].owned = true
	hud.view.progress[0].discovered = true
	var before: Dictionary = hud.view.duplicate(true)
	hud.call("_instrument_art")
	if not expect(count(hud,"lock") == 1 and count(hud,"dry") == 1 and count(hud,"low_health") == 1,"Locked, empty and low-health states have separate visible shapes"): return
	if not expect(has(hud,"lock",Rect2(241,334,8,10)) and has(hud,"dry",Rect2(293,325,20,20)),"Lock belongs only to unavailable scattergun and dry slash only to empty marrow launcher"): return
	if not expect(count(hud,"seal_blood") == 1 and count(hud,"seal_empty") == 1 and count(hud,"seal_ivory") == 0,"Blood possession cannot invent an ivory seal"): return
	if not expect(count(hud,"story_filled") == 1 and count(hud,"story_empty") == 7,"Discovery artwork reflects exactly one of eight recovered records"): return
	if not expect(hud.view == before,"Art rendering never changes the derived state"): return
	for sprite in hud.sprites:
		if not expect(Rect2(0,322,640,38).encloses(sprite.rect),"All art stays in the protected 38-pixel instrument footprint"): return

	hud.sprites = []
	hud.view.seals[1].owned = true
	hud.view.health = 26
	hud.view.arsenal[2].owned = true
	hud.view.arsenal[4].empty = false
	hud.call("_instrument_art")
	if not expect(count(hud,"seal_ivory") == 1 and count(hud,"seal_empty") == 0 and count(hud,"lock") == 0 and count(hud,"dry") == 0 and count(hud,"low_health") == 0,"Restored states clear stale overlays without losing true seals"): return
	hud.sprites = []
	hud.view.seals = []
	hud.call("_instrument_art")
	if not expect(count(hud,"seal_empty") == 0 and count(hud,"seal_blood") == 0 and count(hud,"seal_ivory") == 0,"A map without seal requirements draws no invented seals or zero-count division"): return
	hud.free()
	print("PASS native atlas region/state-shape renderer fixture; run original test_hud.gd separately for real game/binding/placement/pause semantics")
	quit()

func count(hud: Node, id: String) -> int:
	var total = 0
	for sprite in hud.sprites:
		if sprite.id == id: total += 1
	return total

func has(hud: Node, id: String, rect: Rect2) -> bool:
	for sprite in hud.sprites:
		if sprite.id == id and sprite.rect == rect: return true
	return false

func expect(condition: bool, text: String) -> bool:
	if not condition:
		push_error(text)
		quit(1)
	return condition
