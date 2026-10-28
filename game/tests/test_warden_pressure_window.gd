extends SceneTree
## Intended future native fixture only. Not executed by this source-only preparation.
const Query = preload("res://scripts/sprite_hit_query.gd")
const Window = preload("res://scripts/warden_pressure_window.gd")
const Variation = preload("res://scripts/weapon_variation.gd")
const AtlasPath = "res://assets/art/sprites/bodies-v1/nursery_warden.png"
class Actor extends CharacterBody3D:
	var id := "nursery_warden"
	var hp := 1200
	var sprite: Sprite3D
	func _current_map() -> bool: return true
	func visual_hit_sprite() -> Sprite3D: return sprite
class PlayerStub extends Node3D:
	var shot := 8
	func last_shot_sequence(_weapon: int) -> int: return shot
class GameStub extends Node:
	var playing := true
	var level: Node
	var player: Node
	var state := {"shot_sequence":[0,9,0,0,0,0]}
var failures := 0
var scene: Node3D
var camera: Camera3D
var actor: Actor
var player: PlayerStub
var game: GameStub
var sprite: Sprite3D
var binding: Dictionary
var tick := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("WARDEN PRESSURE WINDOW: "+label)
func _context(contact: Dictionary, attack_kind := "hitscan", weapon := 1, shot_tick := -1, sequence := 8) -> Dictionary:
	return {"attack_kind":attack_kind,"weapon":weapon,"shot_tick":shot_tick if shot_tick >= 0 else tick,"shot_sequence":sequence,"sprite_contact":contact}
func _valid(contact: Dictionary, context: Dictionary, variant := 0, windup := 0.9, source: Node = null) -> bool:
	return Window.eligible(binding,sprite,contact,actor.get_instance_id(),player if source == null else source,player,game,scene,"nursery_warden",windup,variant,context,tick)
func _cast_to(pixel: Vector2i) -> Dictionary:
	var geometry: Dictionary = Query._geometry(actor,camera)
	if geometry.is_empty(): return {}
	var point: Vector3 = Query._world_pixel(geometry,Vector2i(0,768)+pixel)
	var direction := (point-camera.global_position).normalized()
	return Query.cast(scene.get_world_3d().direct_space_state,camera.global_position,camera.global_position+direction*30.0,camera,[actor],[],1|4)
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	scene = Node3D.new(); root.add_child(scene)
	camera = Camera3D.new(); scene.add_child(camera); camera.position = Vector3(0,3.4,0); camera.current = true
	player = PlayerStub.new(); scene.add_child(player)
	game = GameStub.new(); scene.add_child(game); game.level = scene; game.player = player
	actor = Actor.new(); actor.collision_layer = 4; actor.collision_mask = 1; scene.add_child(actor); actor.position = Vector3(0,0,6)
	var shape := CollisionShape3D.new(); var capsule := CapsuleShape3D.new(); capsule.radius = 1.0; capsule.height = 5.4; shape.shape = capsule; shape.position.y = 2.7; actor.add_child(shape)
	sprite = Sprite3D.new(); actor.sprite = sprite; sprite.texture = load(AtlasPath); sprite.hframes = 8; sprite.vframes = 5; sprite.frame = 24; sprite.pixel_size = 7.3/256.0; sprite.position.y = (256.0/2.0-8.0)*sprite.pixel_size; sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED; sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD; actor.add_child(sprite)
	camera.look_at(actor.global_position+Vector3.UP*3.4)
	await physics_frame
	await physics_frame
	tick = Engine.get_physics_frames()
	binding = Window.bind(sprite); check(not binding.is_empty(),"exact normal-runtime atlas plus pinned RLE binds")
	if binding.is_empty(): quit(1); return
	var mask: PackedByteArray = binding.mask
	var positive := Vector2i(129,142) # first explicit opaque run in the pinned contour
	var hit := _cast_to(positive)
	var contact: Dictionary = {"coverage":"visible_sprite","collider_id":actor.get_instance_id(),"sprite_frame":hit.get("sprite_frame"),"sprite_pixel":hit.get("sprite_pixel"),"frame_pixel":hit.get("frame_pixel")}
	check(not hit.is_empty() and contact.frame_pixel == positive,"actual query returns current front node texel")
	var context := _context(contact)
	check(_valid(contact,context),"direct current player shot / live variant-0 front telegraph qualifies")
	check(Window.bonus_damage(22)==33,"bonus is exact 1.5x and bounded to hit damage")
	check(not _valid(contact,context,1),"wrong committed variant stays ordinary")
	check(not _valid(contact,context,0,0.0),"closed telegraph stays ordinary")
	check(not _valid(contact,context,0,0.9,scene),"foreign caller stays ordinary")
	check(not _valid(contact,_context(contact,"projectile",4)),"projectile/splash path stays ordinary")
	check(not _valid(contact,_context(contact,"hitscan",1,tick-1)),"old physics-tick contact is stale")
	player.shot=9; game.state.shot_sequence[1]=10
	check(not _valid(contact,context),"old per-weapon shot sequence is stale")
	player.shot=8; game.state.shot_sequence[1]=9
	# The region itself refuses adjacent opaque pixels even when inside its envelope.
	var outside := Vector2i.ZERO
	var cell_image := sprite.texture.get_image().get_region(Rect2i(0,768,256,256))
	var found := false
	for y in range(142,167):
		for x in range(125,142):
			if not found and mask[y*256+x] == 0 and cell_image.get_pixel(x,y).a >= 0.5:
				outside=Vector2i(x,y); found=true
	if found:
		var outside_hit := _cast_to(outside)
		var outside_contact: Dictionary={"coverage":"visible_sprite","collider_id":actor.get_instance_id(),"sprite_frame":outside_hit.get("sprite_frame"),"sprite_pixel":outside_hit.get("sprite_pixel"),"frame_pixel":outside_hit.get("frame_pixel")}
		check(not outside_hit.is_empty() and Window.region(binding,sprite,outside_contact,actor.get_instance_id())==0,"opaque neighboring mechanism inside envelope is ordinary")
	else: check(false,"fixture found opaque inside-envelope/outside-contour witness")
	# Transparent pixels never become contacts; source wall also wins before sprite.
	var transparent := Vector2i(0,0)
	var transparent_hit := _cast_to(transparent)
	check(transparent_hit.is_empty(),"transparent/background pixel produces no sprite contact")
	var wall := StaticBody3D.new(); wall.collision_layer=1; scene.add_child(wall); wall.position=Vector3(0,3.4,3)
	var wall_shape:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(8,8,.2); wall_shape.shape=box; wall.add_child(wall_shape)
	await physics_frame; await physics_frame
	tick = Engine.get_physics_frames()
	var blocked := _cast_to(positive)
	var wall_context := _context(blocked)
	check(not blocked.is_empty() and blocked.get("collider") == wall and blocked.get("coverage") != "visible_sprite","query returns the intervening native wall, not a sprite contact")
	check(wall_context.get("shot_tick") == tick and wall_context.get("shot_sequence") == player.last_shot_sequence(1) and game.state.shot_sequence[1] == (wall_context.get("shot_sequence")+1)%Variation.PERIOD,"wall negative carries otherwise-current direct shot provenance")
	check(Window.region(binding,sprite,blocked,actor.get_instance_id()) == 0 and not _valid(blocked,wall_context),"native wall contact cannot qualify the masked node or receive a bonus")
	wall.queue_free(); await physics_frame; await physics_frame
	# Wrong current visible cell and foreign texture fail closed.
	sprite.frame=25; check(Window.region(binding,sprite,contact,actor.get_instance_id())==0,"wrong direction fails closed")
	sprite.frame=16; check(Window.region(binding,sprite,contact,actor.get_instance_id())==0,"wrong pose fails closed")
	sprite.frame=24
	var original: Texture2D=sprite.texture; sprite.texture=load("res://assets/art/sprites/bodies-v1/choir_avatar.png"); check(Window.bind(sprite).is_empty(),"foreign atlas cannot bind"); sprite.texture=original
	Query.invalidate_texture(original); check(Window.region(binding,sprite,contact,actor.get_instance_id())==0,"invalidated texture generation rejects stale binding")
	# No runtime contact causes no hp change in this helper fixture; persistence is separately frozen by source tests.
	print("WARDEN_PRESSURE_WINDOW_SOURCE_FIXTURE failures=",failures," atlas=",Window.ATLAS_RGBA_SHA256," mask=",Window.MASK_SHA256)
	quit(1 if failures>0 else 0)
