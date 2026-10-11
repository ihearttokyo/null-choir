extends Node2D

const Survey = preload("res://scripts/survey.gd")
const AMMO_ATLAS = preload("res://assets/art/effects/ammo_vfx.png")
const HUD_ATLAS = preload("res://assets/art/hud/hud_kit.png")
const WEAPON_ART = ["impact_tool","rivet_pistol","scattergun","sawtooth_repeater","marrow_launcher","choir_disruptor"]

# Native translation of the selected source/art/references/overhaul-01.png instrument.
const IVORY = Color(0.9,0.85,0.72)
const COPPER = Color(0.5,0.31,0.17)
const INK = Color(0.025,0.025,0.029)
const AMBER = Color(0.98,0.65,0.25)
const DANGER = Color(0.91,0.25,0.16)

var game: Node
var message_label: Label
var weapon_texture: Texture2D
var weapon_asset: String = ""
var labels: Dictionary = {}
var view: Dictionary = {}
var survey: Node2D
var hud_art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/hud/hud_kit.json")).sprites

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_label("LevelTitle",Rect2(12,8,306,22),14)
	_label("Discovery",Rect2(12,30,306,18),10)
	_label("Objective",Rect2(348,8,280,20),12,HORIZONTAL_ALIGNMENT_RIGHT)
	_label("SealState",Rect2(374,30,254,30),10,HORIZONTAL_ALIGNMENT_RIGHT)
	_label("BossTitle",Rect2(156,47,216,17),11)
	_label("BossPhase",Rect2(375,47,109,17),10,HORIZONTAL_ALIGNMENT_RIGHT)
	_label("BossHealth",Rect2(252,79,136,16),10,HORIZONTAL_ALIGNMENT_CENTER)
	_label("VitalCaption",Rect2(34,348,47,12),8).text = "VITAL"
	_label("VitalValue",Rect2(33,323,49,27),18)
	_label("ArmorCaption",Rect2(112,348,47,12),8).text = "ARMOR"
	_label("ArmorValue",Rect2(111,323,49,27),18)
	_label("WeaponName",Rect2(164,345,180,15),10,HORIZONTAL_ALIGNMENT_CENTER)
	for index in 6:
		_label("ArsenalSlot"+str(index+1),Rect2(166+index*30,325,12,12),7)
	_label("AmmoValue",Rect2(367,323,105,27),18)
	_label("AmmoCapacity",Rect2(428,348,44,12),7,HORIZONTAL_ALIGNMENT_RIGHT)
	_label("AmmoStatus",Rect2(367,348,59,12),8)
	_label("RecoveryProgress",Rect2(558,348,76,12),8,HORIZONTAL_ALIGNMENT_RIGHT)
	_label("InteractionPrompt",Rect2(128,250,384,32),12,HORIZONTAL_ALIGNMENT_CENTER)
	_label("InteractionBinding",Rect2(96,286,448,30),11,HORIZONTAL_ALIGNMENT_CENTER)
	message_label = _label("Transmission",Rect2(16,64,608,68),12)
	survey = Survey.new()
	survey.game = game
	add_child(survey)
	_process(0)

func _label(id: String, rect: Rect2, font_size: int, alignment: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label = Label.new()
	label.name = id
	label.position = rect.position
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",IVORY)
	label.add_theme_color_override("font_outline_color",INK)
	label.add_theme_constant_override("outline_size",1)
	labels[id] = label
	add_child(label)
	label.size = rect.size
	return label

# Derived each frame, never persisted: both the native text and instrument drawing use this view.
func draw_state() -> Dictionary:
	if game.level == null or game.player == null: return {}
	var state = game.state
	var profile: Dictionary = game.player.WEAPONS[state.weapon]
	var arsenal: Array = []
	for index in game.player.WEAPONS.size():
		var weapon: Dictionary = game.player.WEAPONS[index]
		var owned: bool = index in state.owned_weapons
		var amount: int = state.ammo[index]
		arsenal.append({"owned":owned,"selected":index == state.weapon,
			"empty":owned and index > 0 and amount == 0,
			"low":owned and index > 0 and amount > 0 and amount <= weapon.get("low_ammo",0)})
	var required: Array = []
	var pending_manifestation: bool = false
	var closed_gate: bool = false
	var data: Dictionary = game.level.layout.data
	for spec in data.doors + data.interactions:
		if spec.has("size") and not spec.id in state.removed: closed_gate = true
		if spec.get("kind","") != "exit" and not spec.has("size"): continue
		for key in spec.get("requires",[]):
			if not key in required: required.append(key)
		for id in spec.get("requires_defeated",[]):
			if not id in state.removed: pending_manifestation = true
	var seals: Array = []
	var seal_text: PackedStringArray = []
	var recovered: int = 0
	for key in required:
		var owned: bool = key in state.keys
		seals.append({"key":key,"owned":owned})
		seal_text.append(str(key).to_upper()+(" [+]" if owned else " [-]"))
		if owned: recovered += 1
	var objective = "RECOVER SEALS %d/%d" % [recovered,required.size()] if recovered < required.size() else "OPEN GATE" if closed_gate else "BREAK THE RESTRAINT" if pending_manifestation else "REACH DESCENT"
	var boss: Dictionary = {}
	for actor in game.enemies:
		if is_instance_valid(actor) and actor._current_map() and actor.active and actor.hp > 0 and actor.kind in ["nursery_warden","choir_avatar"]:
			boss = {"id":actor.id,"name":"NURSERY WARDEN" if actor.kind == "nursery_warden" else "CHOIR AVATAR",
				"hp":actor.hp,"max_hp":actor.max_hp,"phase":actor.phase}
			break
	var discovery: bool = state.level_index in state.discoveries
	var progress: Array = []
	for index in 8:
		progress.append({"discovered":index in state.discoveries,"current":index == state.level_index})
	var interaction: Dictionary = game.nearest_interaction() if game.playing else {}
	var prompt: String = ""
	if not interaction.is_empty():
		var missing: PackedStringArray = []
		for key in interaction.get("requires",[]):
			if not key in state.keys: missing.append(str(key).to_upper())
		if not missing.is_empty(): prompt = "MISSING SEALS: "+" / ".join(missing)
		elif interaction.has("size"): prompt = "OPEN GATE"
		else:
			match interaction.get("kind",""):
				"key": prompt = "RECOVER "+str(interaction.get("key","")).to_upper()+" SEAL"
				"story": prompt = "READ MAINTENANCE RECORD"
				"exit":
					prompt = "DESCEND"
					for id in interaction.get("requires_defeated",[]):
						if not id in state.removed: prompt = "MANIFESTATION STILL LIVING"
	var empty: bool = arsenal[state.weapon].empty
	var low: bool = arsenal[state.weapon].low
	var capacity: int = profile.get("max_ammo",0)
	return {"arsenal":arsenal,"seals":seals,"discovery":discovery,"progress":progress,"boss":boss,
		"title":"%02d/08  %s" % [state.level_index+1,data.title],
		"objective":objective,"seal_text":"  ".join(seal_text),
		"discovery_text":("RECORD RECOVERED" if discovery else "RECORD UNREAD")+"  //  %d/8" % state.discoveries.size(),
		"progress_text":"RECORDS %d/8" % state.discoveries.size(),
		"health":state.health,"armor":state.armor,"weapon_name":profile.name,
		"ammo":"TOOL" if state.weapon == 0 else "EMPTY" if empty else str(state.ammo[state.weapon]),
		"capacity":"CAP %d" % capacity if state.weapon > 0 and capacity > 0 else "RESERVE" if state.weapon > 0 else "AMMO-FREE",
		"ammo_status":"EMPTY" if empty else "LOW" if low else "CYCLING" if game.player.cooldown > 0 else "READY",
		"prompt":prompt,"binding":game.preferences.binding_text("interact") if not prompt.is_empty() else ""}

func _process(_delta: float) -> void:
	view = draw_state()
	var active: bool = not view.is_empty() and game.playing
	for id in labels:
		if id not in ["InteractionPrompt","InteractionBinding","BossTitle","BossHealth","BossPhase","Transmission"]:
			labels[id].visible = active
	if not view.is_empty():
		labels.LevelTitle.text = view.title
		labels.Discovery.text = view.discovery_text
		labels.RecoveryProgress.text = view.progress_text
		labels.Objective.text = view.objective
		labels.SealState.text = view.seal_text
		labels.BossTitle.text = view.boss.get("name","")
		labels.BossHealth.text = "%d / %d" % [view.boss.hp,view.boss.max_hp] if not view.boss.is_empty() else ""
		labels.BossPhase.text = "RUPTURE" if view.boss.get("phase",0) > 0 else "MANIFEST"
		labels.BossPhase.add_theme_color_override("font_color",DANGER if view.boss.get("phase",0) > 0 else IVORY)
		labels.VitalValue.text = str(view.health)
		labels.VitalValue.add_theme_color_override("font_color",DANGER if view.health <= 25 else IVORY)
		labels.ArmorValue.text = str(view.armor)
		labels.WeaponName.text = view.weapon_name
		labels.AmmoValue.text = view.ammo
		labels.AmmoCapacity.text = view.capacity
		labels.AmmoStatus.text = view.ammo_status
		var ammo_color = DANGER if view.ammo_status == "EMPTY" else AMBER if view.ammo_status == "LOW" else IVORY
		labels.AmmoValue.add_theme_color_override("font_color",ammo_color)
		labels.AmmoStatus.add_theme_color_override("font_color",ammo_color)
		for index in view.arsenal.size():
			var slot: Dictionary = view.arsenal[index]
			var label: Label = labels["ArsenalSlot"+str(index+1)]
			label.text = str(index+1)+("-" if not slot.owned else "!" if slot.empty else "")
			label.add_theme_color_override("font_color",DANGER if slot.empty else AMBER if slot.selected or slot.low else IVORY if slot.owned else COPPER)
		labels.InteractionPrompt.text = view.prompt
		labels.InteractionBinding.text = view.binding
	labels.InteractionPrompt.visible = active and not view.get("prompt","").is_empty()
	labels.InteractionBinding.visible = labels.InteractionPrompt.visible
	for id in ["BossTitle","BossHealth","BossPhase"]: labels[id].visible = active and not view.get("boss",{}).is_empty()
	message_label.text = game.message if game.message_time > 0 else ""
	message_label.visible = not message_label.text.is_empty()
	message_label.position = Vector2(16,100 if not view.get("boss",{}).is_empty() else 64) if active else Vector2(16,324)
	message_label.size = Vector2(608,68) if active else Vector2(608,36)
	queue_redraw()

func _draw() -> void:
	if view.is_empty() or game.level == null or game.player == null:
		draw_rect(Rect2(0,0,640,360),Color(0.025,0.022,0.029))
		for x in range(20,640,40):
			draw_line(Vector2(x,0),Vector2(x-60,360),Color(0.16,0.075,0.10),1)
		# Pre-reference menu backdrop retained; parent owns its image comparison.
		for side in [-1,1]:
			for rib in 7:
				var x = 320+side*(192+rib*6)
				draw_line(Vector2(x,34+rib*4),Vector2(x+side*12,310-rib*3),Color(0.45,0.26,0.19),1)
	else:
		var player = game.player
		var profile = player.WEAPONS[game.state.weapon]
		var path = "res://assets/art/weapons/"+profile.asset+".png"
		if weapon_asset != profile.asset:
			weapon_asset = profile.asset
			weapon_texture = load(path) if ResourceLoader.exists(path) else null
		if weapon_texture != null:
			var frame = player.weapon_frame()
			var sway = Vector2(sin(player.stride)*3,cos(player.stride*2)*2) if game.settings.head_bob else Vector2.ZERO
			draw_texture_rect_region(weapon_texture,Rect2(Vector2(180,143)+sway+Vector2(0,player.recoil*8),Vector2(320,200)),Rect2(frame*320,0,320,200))
			var flash_duration: float = minf(0.12,profile.interval)
			var elapsed: float = player.shot_age()
			if game.state.weapon > 0 and elapsed < flash_duration:
				var flash_frame = mini(3,int(elapsed/flash_duration*4))
				draw_texture_rect_region(AMMO_ATLAS,Rect2(Vector2(272,157)+sway,Vector2(96,96)),Rect2(flash_frame*64,0,64,64))
		_instrument_frame()
		_instrument_art()
		if game.playing:
			draw_line(Vector2(348,28),Vector2(628,28),COPPER.darkened(0.3),1)
			if not view.boss.is_empty(): _restraint_instrument()
			if not view.prompt.is_empty():
				draw_rect(Rect2(124,246,392,38),Color(0.025,0.022,0.029,0.85))
				draw_rect(Rect2(92,284,456,34),Color(0.025,0.022,0.029,0.85))
				for side in [124,515]:
					draw_line(Vector2(side,250),Vector2(side,278),COPPER,1)
					draw_line(Vector2(side-2,252),Vector2(side-2,263),IVORY.darkened(0.3),1)
		for offset in [-1,1]:
			draw_line(Vector2(320+offset*4,180),Vector2(320+offset*8,180),IVORY,1)
			draw_line(Vector2(320,180+offset*4),Vector2(320,180+offset*8),IVORY,1)
		if game.hit_flash > 0:
			for direction in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
				draw_line(Vector2(320,180)+direction*9,Vector2(320,180)+direction*13,Color.WHITE,1)
		if game.damage_flash > 0:
			var wound = Color(0.85,0.12,0.08,minf(0.45,game.damage_flash*1.3)*(1.0 if game.settings.camera_shake else 0.6))
			for rect in [Rect2(0,0,640,4),Rect2(0,4,5,318),Rect2(635,4,5,318)]: draw_rect(rect,wound)
			for x in [0,640]:
				var sign_x = 1 if x == 0 else -1
				draw_colored_polygon(PackedVector2Array([Vector2(x,40),Vector2(x+sign_x*10,55),Vector2(x+sign_x*4,78),Vector2(x+sign_x*12,105),Vector2(x,132)]),wound)
			draw_arc(Vector2(17,341),14,0,TAU,16,wound,2)
	if not game.playing and game.level != null:
		draw_rect(Rect2(0,0,640,360),Color(0.025,0.012,0.02,0.76))

func _restraint_instrument() -> void:
	# Native translation of selected source/art/references/boss-hud-01.png.
	var rail = Rect2(154,66,332,10)
	var ratio = clampf(float(view.boss.hp)/view.boss.max_hp,0,1)
	draw_rect(Rect2(140,46,360,50),Color(INK,0.82))
	draw_rect(rail,INK)
	if ratio > 0: draw_rect(Rect2(rail.position,Vector2(rail.size.x*ratio,rail.size.y)),DANGER.darkened(0.15))
	draw_rect(rail,COPPER,false,1)
	for index in range(1,24):
		var x = rail.position.x+rail.size.x*index/24.0
		draw_line(Vector2(x,67),Vector2(x,75),INK,1)
	for index in range(7):
		var x = 158+index*54
		draw_line(Vector2(x,62),Vector2(x,65),IVORY,1)
		draw_circle(Vector2(x,61),1,COPPER)
	for x in [143,491]:
		draw_rect(Rect2(x,49,6,34),COPPER,false,1)
		draw_rect(Rect2(x-2,47,10,3),IVORY.darkened(0.2),false,1)
		draw_rect(Rect2(x-2,82,10,3),IVORY.darkened(0.2),false,1)
		draw_arc(Vector2(x+3,55),2,0,TAU,8,DANGER,1)
		draw_line(Vector2(x+3,60),Vector2(x+3,78),IVORY.darkened(0.2),1)
	draw_line(Vector2(154,88),Vector2(245,88),COPPER,1)
	draw_line(Vector2(395,88),Vector2(486,88),COPPER,1)

func _instrument_frame() -> void:
	draw_rect(Rect2(0,322,640,38),INK)
	for x in range(0,640,64):
		_hud_sprite("frame_tile",Rect2(x,322,64,38),Color(0.36,0.36,0.36))
	for x in [82,160,345,476,554]:
		_hud_sprite("divider",Rect2(x-1,327,3,28))
	_hud_sprite("frame_corner",Rect2(0,322,14,14))
	_hud_sprite("frame_corner",Rect2(626,322,14,14),Color.WHITE,Vector2(-1,1))
	_hud_sprite("frame_corner",Rect2(0,346,14,14),Color.WHITE,Vector2(1,-1))
	_hud_sprite("frame_corner",Rect2(626,346,14,14),Color.WHITE,Vector2(-1,-1))

func _instrument_art() -> void:
	_hud_sprite("heart",Rect2(1,324,32,34))
	_hud_sprite("shield",Rect2(81,324,30,34))
	_hud_sprite("ammo",Rect2(346,327,20,22))
	if view.health <= 25: _hud_sprite("low_health",Rect2(1,326,32,30))
	for index in view.arsenal.size():
		var slot: Dictionary = view.arsenal[index]
		var cell = Rect2(164+index*30,324,28,21)
		_hud_sprite("slot_selected" if slot.selected else "slot_base",cell,Color(0.8,0.8,0.8) if slot.selected else Color(0.5,0.5,0.5))
		var icon = Rect2(cell.position+Vector2(9,1),Vector2(20,20))
		_hud_sprite(WEAPON_ART[index],icon,Color.WHITE.darkened(0.7) if not slot.owned else AMBER if slot.low else Color.WHITE)
		if not slot.owned:
			_hud_sprite("lock",Rect2(cell.position+Vector2(17,10),Vector2(8,10)))
		elif slot.empty:
			_hud_sprite("dry",icon)
	for index in view.seals.size():
		var seal: Dictionary = view.seals[index]
		var spacing = 72.0/view.seals.size()
		var diameter = minf(24,spacing-4)
		var center = Vector2(480+(index+0.5)*spacing,339)
		_hud_sprite("seal_"+str(seal.key) if seal.owned else "seal_empty",Rect2(center-Vector2.ONE*diameter/2,Vector2.ONE*diameter))
	for index in view.progress.size():
		var pip: Dictionary = view.progress[index]
		if pip.current: _hud_sprite("slot_selected",Rect2(559+index*9,330,10,10))
		_hud_sprite("story_filled" if pip.discovered else "story_empty",Rect2(560+index*9,331,8,8))

func _hud_region(id: String) -> Rect2:
	var data: Dictionary = hud_art[id]
	var cell: Array = data.region
	var region = Rect2(cell[0],cell[1],cell[2],cell[3])
	if id in ["frame_tile","frame_corner","divider","slot_base","slot_selected","lock","seal_blood","seal_ivory","seal_empty","story_empty","story_filled"]:
		var content: Array = data.content_rect
		region = Rect2(region.position+Vector2(content[0],content[1]),Vector2(content[2],content[3]))
	return region

func _hud_sprite(id: String, rect: Rect2, tint: Color = Color.WHITE, flip: Vector2 = Vector2.ONE) -> void:
	draw_set_transform(rect.get_center(),0,flip)
	draw_texture_rect_region(HUD_ATLAS,Rect2(-rect.size/2,rect.size),_hud_region(id),tint)
	draw_set_transform(Vector2.ZERO)
