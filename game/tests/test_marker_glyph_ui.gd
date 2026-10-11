extends SceneTree

const Hud = preload("res://scripts/hud.gd")
const Layout = preload("res://scripts/level_data.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Preferences = preload("res://scripts/preferences.gd")

class HudProbe extends "res://scripts/hud.gd":
	var sprites: Array = []
	func _draw() -> void: pass
	func _hud_sprite(id: String, rect: Rect2, tint: Color = Color.WHITE, flip: Vector2 = Vector2.ONE) -> void:
		sprites.append({"id":id,"rect":rect,"tint":tint,"flip":flip,"texture":call("_hud_texture",id),"region":call("_hud_region",id)})

class LevelFixture extends Node:
	var layout = Layout.new()

class GameFixture extends Node:
	var level: Node
	var player: Node3D
	var state = Campaign.new()
	var preferences = Preferences.new()
	var enemies: Array = []
	var playing: bool = true
	var message: String = ""
	var message_time: float = 0.0
	func interaction_display() -> Dictionary: return {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var hud = HudProbe.new()
	# Parent runs this fixture against rollback runtime first, then the candidate.
	if not expect(hud.has_method("_hud_texture"),"Intended RED: production HUD must select the native marker atlas"): return
	var atlas = load("res://assets/art/hud/marker_glyphs.png") as Texture2D
	var old_atlas = load("res://assets/art/hud/hud_kit.png") as Texture2D
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/hud/marker_glyphs.json"))
	if not expect(atlas != null and atlas.get_size() == Vector2(256,256),"Use the actual compact native glyph texture"): return
	for id in Hud.WEAPON_ART + ["seal_blood","seal_ivory"]:
		var cell: Array = metadata.sprites[id].region
		if not expect(hud.call("_hud_texture",id) == atlas and hud.call("_hud_region",id) == Rect2(cell[0],cell[1],64,64),"Full native cells preserve aspect and gutters: "+id): return
	for id in ["heart","shield","ammo","frame_tile","frame_corner","divider","story_empty","story_filled"]:
		if not expect(hud.call("_hud_texture",id) == old_atlas,"Preserve textured hero HUD and tiny records: "+id): return
	if not expect(hud.call("_hud_region","heart") == Rect2(0,0,64,64) and hud.call("_hud_region","frame_tile") == Rect2(453,80,54,32),"Original hero/tile region contracts remain intact"): return

	var game = GameFixture.new()
	game.level = LevelFixture.new()
	if not expect(game.level.layout.load_level(0),"Use actual validated authored Intake layout"): return
	game.player = load("res://scripts/player.gd").new()
	game.state.new_campaign(1)
	hud.game = game
	root.add_child(hud)
	hud.set_process(false)
	hud.survey.set_physics_process(false)
	if not expect(hud.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and not hud.survey.visible,"Nearest HUD; survey begins closed"): return
	var cases = [
		{"owned":true,"selected":true,"empty":false,"low":false},
		{"owned":false,"selected":false,"empty":false,"low":false},
		{"owned":true,"selected":false,"empty":true,"low":false},
		{"owned":true,"selected":false,"empty":false,"low":true}]
	for slot in cases:
		hud.view = {"health":25,"arsenal":[],"seals":[{"key":"blood","owned":false},{"key":"ivory","owned":true}],"progress":[]}
		for index in 6: hud.view.arsenal.append(slot.duplicate())
		for index in 8: hud.view.progress.append({"discovered":index == 0,"current":index == 0})
		var frozen: Dictionary = hud.view.duplicate(true)
		hud.sprites.clear()
		hud._instrument_art()
		if not expect(hud.view == frozen,"Instrument drawing never writes derived state"): return
		var first_weapon: int = -1
		var last_slot: int = -1
		for index in hud.sprites.size():
			if hud.sprites[index].id in Hud.WEAPON_ART and first_weapon < 0: first_weapon = index
			if hud.sprites[index].id in ["slot_base","slot_selected"] and hud.sprites[index].rect.size == Vector2(28,21): last_slot = index
		if not expect(last_slot < first_weapon,"All slot backgrounds must draw before any weapon glyph"): return
		var glyphs: int = 0
		for sprite in hud.sprites:
			if sprite.texture != atlas: continue
			glyphs += 1
			if not expect(sprite.rect.size == Vector2(32,32) and Rect2(0,312,640,48).encloses(sprite.rect),"Fragile motifs use bounded full-square 32px destinations"): return
			var content: Array = metadata.sprites[sprite.id].content_rect
			var opaque = Rect2(sprite.rect.position+Vector2(content[0],content[1])*0.5,Vector2(content[2],content[3])*0.5)
			if not expect(Rect2(0,316,640,44).encloses(opaque),"Opaque glyphs stay inside expanded instrument"): return
			for label in hud.labels.values():
				if label.name.begins_with("ArsenalSlot") or label.name == "WeaponName":
					if not expect(not opaque.intersects(label.get_rect()),"Numbers/status and weapon name cannot occlude motifs"): return
			if sprite.id in Hud.WEAPON_ART:
				var expected = Color.WHITE.darkened(0.5) if not slot.owned else Hud.DANGER if slot.empty else Hud.AMBER if slot.low else Color.WHITE
				if not expect(sprite.tint == expected,"Ownership, empty and low signals stay distinct"): return
			elif not expect(sprite.tint == (Color.WHITE.darkened(0.5) if sprite.id == "seal_blood" else Color.WHITE),"Missing seals retain their actual shape and dim state"): return
		var chrome: int = 0
		var records: int = 0
		for sprite in hud.sprites:
			if sprite.id == ("slot_selected" if slot.selected else "slot_base") and sprite.rect.size == Vector2(28,21): chrome += 1
			if sprite.id in ["story_filled","story_empty"] and sprite.rect.size == Vector2(8,8): records += 1
		if not expect(chrome == 6 and records == 8,"Selection chrome and all tiny record pips retain original art/geometry"): return
		if not expect(glyphs == 8,"Six weapons and both real seal identities are drawn exactly once"): return
		for sprite in hud.sprites:
			if not expect(sprite.id not in ["lock","dry","seal_empty"],"State overlays cannot conceal hollow motifs"): return
	for index in 6:
		var label: Label = hud.labels["ArsenalSlot"+str(index+1)]
		var font: Font = label.get_theme_font("font")
		if not expect(font.get_string_size(str(index+1)+"!",HORIZONTAL_ALIGNMENT_LEFT,-1,7).x <= label.size.x,"Actual slot font fits two-character state labels"): return
	game.state.owned_weapons = [0,1,3,4,5]
	game.state.ammo[1] = 0
	game.state.weapon = 1
	game.state.keys = ["blood"]
	hud._process(0)
	if not expect(hud.labels.ArsenalSlot1.text == "1" and hud.labels.ArsenalSlot2.text == "2!" and hud.labels.ArsenalSlot3.text == "3-" and hud.labels.SealState.text == "BLOOD [+]  IVORY [-]","Real campaign ownership/ammo/seals produce exact non-color status text"): return
	var campaign_before: Dictionary = game.state.to_dict().duplicate(true)
	hud._process(0)
	var prefs: Dictionary = game.preferences.to_dict().duplicate(true)
	hud.draw_state()
	if not expect(game.state.to_dict() == campaign_before,"HUD refresh/derivation leave campaign resources untouched"): return
	game.playing = false
	hud._process(0)
	if not expect(not hud.labels.WeaponName.visible and not hud.labels.InteractionPrompt.visible and hud.survey.draw_state().is_empty(),"Closed menus do not retain active labels/map markers"): return
	game.playing = true
	var survey = hud.survey
	if not expect(survey.get_script().get_script_constant_map()["MARKER_ATLAS"] == atlas and survey.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,"HUD and survey retain the same native texture, no custom cache"): return
	for id in ["seal_blood","seal_ivory","key","story","checkpoint","exit"]:
		if not expect(survey.call("_glyph_region",id).size == Vector2(64,64),"Survey also samples complete native square cells"): return
	for index in 8:
		if not expect(game.level.layout.load_level(index),"All authored layouts must load"): return
		game.state.explored.clear()
		game.state.removed.clear()
		if not expect(survey.draw_state().icons.is_empty(),"Undiscovered maps reveal no symbols"): return
		for cell in game.level.layout.tiles: game.state.explored.append([cell.x,cell.y])
		for spec in game.level.layout.data.interactions:
			if spec.kind == "key" and spec.key == "blood": game.player.position = game.level.layout.world_position(spec.cell)
		var frozen: Dictionary = game.state.to_dict().duplicate(true)
		var view: Dictionary = survey.draw_state()
		if not expect(not view.has("enemies") and game.state.to_dict() == frozen,"Map derivation is read-only and never exposes enemies"): return
		var found: Array = []
		for icon in view.icons:
			found.append(icon.glyph)
			if not expect([icon.cell.x,icon.cell.y] in game.state.explored and icon.symbol in ["S","R","C",">","G"],"Legacy symbols and discovered-only contract survive"): return
		if not expect(found.size() == 6 and "seal_blood" in found and "seal_ivory" in found and "story" in found and "checkpoint" in found and "exit" in found and "" in found,"Survey uses matching identities and retains G gate"): return
		var geometry: Dictionary = survey.call("_map_geometry",game.level.layout)
		var player_center: Vector2 = geometry.origin+view.player*geometry.scale
		var player_rect = Rect2(player_center-Vector2(6,6),Vector2(12,12))
		var placements: Array = survey.call("_icon_placements",view,geometry)
		if not expect(placements.size() == view.icons.size(),"No discovered marker is dropped during collision placement"): return
		for a in placements.size():
			var marker: Dictionary = placements[a]
			var side: int = 32 if marker.glyph.begins_with("seal_") else 24
			if not expect(marker.rect.size == Vector2(side,side) and survey.get_script().get_script_constant_map()["MAP_FRAME"].encloses(marker.rect),"Survey glyph sizes and frame bounds match review"): return
			if not expect(not marker.rect.grow(2).intersects(player_rect),"Discovered marker glyphs never conceal the player standing on an authored key"): return
			for b in range(a+1,placements.size()):
				if not expect(not marker.rect.grow(2).intersects(placements[b].rect),"Neighbor meanings never overlap"): return
		for spec in game.level.layout.data.interactions+game.level.layout.data.doors: game.state.removed.append(spec.id)
		if not expect(survey.draw_state().icons.is_empty(),"Removed interactions/gates leave no stale marker"): return
		game.state.removed.clear()
		game.state.explored.clear()
	game.level.queue_free()
	if not expect(survey.draw_state().is_empty(),"Retired maps cannot render stale markers"): return
	if not expect(game.preferences.to_dict() == prefs,"No UI presentation changes preferences"): return
	var lifetime = weakref(hud)
	hud.free()
	if not expect(lifetime.get_ref() == null,"HUD and its survey follow native node lifetime"): return
	game.player.free()
	game.level.free()
	game.free()
	print("PASS marker glyph production helpers, resource ownership, full cells, state signals, native font bounds and eight-map read-only placements; no pixel/recognition claim")
	quit()

func expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
