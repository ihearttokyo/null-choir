extends Node2D

var game: Node
var message_label: Label
var weapon_texture: Texture2D
var weapon_asset: String = ""

func _ready() -> void:
	message_label = Label.new()
	message_label.position = Vector2(24,38)
	message_label.size = Vector2(592,85)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size",14)
	message_label.add_theme_color_override("font_color",Color(0.85,0.75,0.6))
	add_child(message_label)

func _draw() -> void:
	var font = ThemeDB.fallback_font
	var cream = Color(0.87,0.79,0.65)
	message_label.text = game.message if game.message_time > 0 else ""
	if game.level == null:
		draw_rect(Rect2(0,0,640,360),Color(0.025,0.022,0.029))
		for x in range(20,640,40):
			draw_line(Vector2(x,0),Vector2(x-60,360),Color(0.16,0.075,0.10),1)
		draw_circle(Vector2(320,330),21,Color(0.25,0.12,0.12))
		draw_circle(Vector2(320,330),12,Color(0.025,0.022,0.029))
		draw_line(Vector2(320,305),Vector2(320,355),cream,1)
	else:
		var player = game.player
		var profile = player.WEAPONS[game.state.weapon]
		var path = "res://assets/art/weapons/"+profile.asset+".png"
		if weapon_asset != profile.asset:
			weapon_asset = profile.asset
			weapon_texture = load(path) if ResourceLoader.exists(path) else null
		if weapon_texture != null:
			var frame = 1 if player.shot_flash > 0.07 else 2 if player.cooldown > 0.1 else 0
			var sway = Vector2(sin(player.stride)*3,cos(player.stride*2)*2) if game.settings.head_bob else Vector2.ZERO
			draw_texture_rect_region(weapon_texture,Rect2(Vector2(180,143)+sway+Vector2(0,player.recoil*8),Vector2(320,200)),Rect2(frame*320,0,320,200))
		draw_rect(Rect2(0,322,640,38),Color(0.045,0.028,0.034))
		draw_line(Vector2(0,322),Vector2(640,322),Color(0.45,0.26,0.19),1)
		draw_string(font,Vector2(18,347),"VITAL %03d" % game.state.health,HORIZONTAL_ALIGNMENT_LEFT,-1,18,cream)
		draw_string(font,Vector2(178,347),"ARMOR %03d" % game.state.armor,HORIZONTAL_ALIGNMENT_LEFT,-1,18,cream)
		var ammo = "--" if game.state.weapon == 0 else str(game.state.ammo[game.state.weapon])
		draw_string(font,Vector2(368,347),"AMMO "+ammo,HORIZONTAL_ALIGNMENT_LEFT,-1,18,cream)
		draw_string(font,Vector2(16,23),game.level.layout.data.title,HORIZONTAL_ALIGNMENT_LEFT,-1,15,cream)
		for offset in [-1,1]:
			draw_line(Vector2(320+offset*4,180),Vector2(320+offset*8,180),cream,1)
			draw_line(Vector2(320,180+offset*4),Vector2(320,180+offset*8),cream,1)
		if game.hit_flash > 0:
			for direction in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
				draw_line(Vector2(320,180)+direction*9,Vector2(320,180)+direction*13,Color.WHITE,1)
		if game.playing:
			var interaction = game.nearest_interaction()
			if not interaction.is_empty(): draw_string(font,Vector2(230,302),"[E / A] INTERACT",HORIZONTAL_ALIGNMENT_LEFT,-1,14,cream)
		if game.damage_flash > 0: draw_rect(Rect2(0,0,640,322),Color(0.65,0.035,0.05,game.damage_flash*0.7))
	if not game.playing and game.level != null:
		draw_rect(Rect2(0,0,640,360),Color(0.025,0.012,0.02,0.76))
