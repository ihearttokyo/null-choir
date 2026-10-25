extends SceneTree
## Arranged synthetic RGBA occupancy integration. Real Player.fire and Projectile
## callbacks/physics queries; no campaign traversal, physical input or GPU proof.
const Player = preload("res://scripts/player.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Campaign = preload("res://scripts/campaign.gd")

class Host extends Node3D:
 var state = Campaign.new()
 var level: Node3D
 var player
 var enemies: Array = []
 var playing := true
 var shots := 0
 var feedback := 0
 var impacts := 0
 var stop_on_feedback := false
 var settings := {"head_bob":false,"camera_shake":false,"sensitivity":1.0,"invert_y":false}
 func shot(_index: int) -> void: shots += 1
 func hit_feedback() -> void:
  feedback += 1
  if stop_on_feedback: playing = false
 func impact(_point: Vector3) -> void: impacts += 1
 func hurt_player(amount: int) -> void: state.health -= amount

class Target extends CharacterBody3D:
 var hp := 1000
 var sprite: Sprite3D
 var current := true
 var reject := false
 var swap_map_on_damage := false
 var host: Host
 func visual_hit_sprite() -> Sprite3D: return sprite
 func _current_map() -> bool: return current and is_instance_valid(host) and get_parent() == host.level
 func take_damage(amount: int, _source: Node3D, _context: Dictionary = {}) -> void:
  if not reject and _current_map():
   hp = maxi(0, hp - amount)
   if swap_map_on_damage:
    host.level = Node3D.new()
    host.add_child(host.level)

# Deliberately has no hp and no visual wrapper: preserve the old nonvisual
# damageable callback contract rather than inventing health to satisfy a test.
class CounterTarget extends StaticBody3D:
 var host: Host
 var hits := 0
 var stop_on_damage := false
 func take_damage(_amount: int, _source: Node3D, _context: Dictionary = {}) -> void:
  hits += 1
  if stop_on_damage: host.playing = false

class PhysicsCall extends Node:
 var action: Callable
 var done := false
 var result: Variant
 func _physics_process(_delta: float) -> void:
  if not action.is_valid(): return
  var pending := action
  action = Callable()
  result = pending.call()
  done = true
  set_physics_process(false)

var game: Host
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func physics_call(action: Callable) -> Variant:
 var probe := PhysicsCall.new()
 probe.action = action
 root.add_child(probe)
 for tick in range(4):
  await physics_frame
  if probe.done: break
 expect(probe.done, "Production callback completed within four ordinary physics frames")
 var result: Variant = probe.result
 probe.free()
 return result
func atlas() -> ImageTexture:
 var image := Image.create(128,80,false,Image.FORMAT_RGBA8)
 image.fill(Color.TRANSPARENT)
 # Frame0 has a real center hole; frame1 is solid. All other frames transparent.
 for y in range(16):
  for x in range(32):
   if x < 16 and x >= 6 and x <= 9 and y >= 6 and y <= 9: continue
   image.set_pixel(x,y,Color.WHITE)
 return ImageTexture.create_from_image(image)
func fixture() -> void:
 game = Host.new()
 root.add_child(game)
 game.level = Node3D.new()
 game.add_child(game.level)
 game.player = Player.new()
 game.level.add_child(game.player)
 game.player.configure(game)
 game.player.set_physics_process(false)
 game.player.set_process_unhandled_input(false)
 game.state.health = 100
 game.state.armor = 0
 game.state.owned_weapons = [0,1,2,3,4,5]
 game.state.ammo = [0,20,20,20,20,20]
func target(z: float, frame: int = 1) -> Target:
 var actor := Target.new()
 actor.host = game
 actor.collision_layer = 4
 var shape := CollisionShape3D.new()
 var capsule := CapsuleShape3D.new()
 capsule.radius = 0.25
 capsule.height = 1.65
 shape.shape = capsule
 shape.position.y = 0.85
 actor.add_child(shape)
 actor.sprite = Sprite3D.new()
 actor.sprite.texture = atlas()
 actor.sprite.hframes = 8
 actor.sprite.vframes = 5
 actor.sprite.frame = frame
 actor.sprite.pixel_size = 0.25
 actor.sprite.position.y = 1.55
 actor.sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 actor.sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
 actor.sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
 actor.sprite.alpha_scissor_threshold = 0.5
 actor.add_child(actor.sprite)
 game.level.add_child(actor)
 actor.position.z = z
 game.enemies.append(actor)
 return actor
func wall(z: float) -> StaticBody3D:
 var body := StaticBody3D.new()
 body.collision_layer = 1
 var shape := CollisionShape3D.new()
 shape.shape = BoxShape3D.new()
 shape.shape.size = Vector3(8,8,0.2)
 body.add_child(shape)
 game.level.add_child(body)
 body.position = Vector3(0,1.55,z)
 return body
func settle() -> void:
 await physics_frame
 await physics_frame
func clear_fixture() -> void:
 game.free()
 game = null
 await process_frame

func run() -> void:
 # Match actual Main startup; project.godot does not declare gameplay actions.
 preload("res://scripts/preferences.gd").new().apply_bindings()
 expect(Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60,"Unmodified production physics clock")
 fixture()
 var front := target(-4,0)
 var back := target(-7)
 await settle()
 game.state.weapon = 1
 var ammo: int = game.state.ammo[1]
 var accepted: bool = await physics_call(func():
  var first: bool = game.player.fire()
  expect(not game.player.fire(),"Same-tick repeated fire remains cooldown bounded")
  return first)
 expect(accepted and game.state.ammo[1] == ammo-1,"Real pistol spends exactly one round")
 expect(front.hp == 1000 and back.hp == 978 and game.feedback == 1,"Actual Player ray passes transparent front frame to opaque rear")
 front.sprite.frame = 1
 game.player.cooldown = 0
 await physics_call(game.player.fire)
 expect(front.hp == 978 and back.hp == 978,"Current atlas frame, not previous hole, determines hit")
 game.player.position.x = 1.25 # Independent arranged shot outside the narrow capsule.
 game.player.cooldown = 0
 await physics_call(game.player.fire)
 expect(front.hp == 956,"Visible opaque sprite beyond capsule accepts real Player shot")
 var cover := wall(-2)
 await settle()
 game.player.cooldown = 0
 var feedback: int = game.feedback
 await physics_call(game.player.fire)
 expect(front.hp == 956 and game.feedback == feedback,"Native wall blocks alpha actor hit")
 cover.free()
 game.player.position.x = 0
 front.reject = true
 await settle()
 game.player.cooldown = 0
 feedback = game.feedback
 await physics_call(game.player.fire)
 expect(front.hp == 956 and game.feedback == feedback,"Rejected target damage cannot produce hit feedback")
 await clear_fixture()

 fixture()
 var hole := target(-3,0)
 var victims: Array[Target] = [target(-5),target(-7),target(-9),target(-11)]
 await settle()
 game.state.weapon = 5
 ammo = game.state.ammo[5]
 await physics_call(game.player.fire)
 expect(hole.hp == 1000 and victims[0].hp == 960 and victims[1].hp == 960 and victims[2].hp == 960 and victims[3].hp == 1000,"Transparent front does not consume three accepted piercing victims")
 expect(game.state.ammo[5] == ammo-1 and game.feedback == 3,"One disruptor charge and feedback only for three damaged targets")
 cover = wall(-8)
 for actor in victims: actor.hp = 1000
 game.player.cooldown = 0
 game.feedback = 0
 await settle()
 await physics_call(game.player.fire)
 expect(victims[0].hp == 960 and victims[1].hp == 960 and victims[2].hp == 1000 and victims[3].hp == 1000 and game.feedback == 2,"Piercing retains finite wall stop")
 await clear_fixture()

 fixture()
 front = target(-2)
 await settle()
 for index in [0,2,3]:
  game.state.weapon = index
  game.player.cooldown = 0
  var hp: int = front.hp
  ammo = game.state.ammo[index]
  await physics_call(game.player.fire)
  var expected: int = {0:28,2:105,3:16}[index]
  expect(hp-front.hp == expected,"Real melee/pellets/repeater use shared opaque query and unchanged damage: "+str(index))
  expect(game.state.ammo[index] == ammo-(0 if index == 0 else 1),"Retained finite ammo cost: "+str(index))
 await clear_fixture()

 fixture()
 front = target(-4,0)
 back = target(-7)
 await settle()
 var projectile := Projectile.new()
 game.level.add_child(projectile)
 projectile.configure(game,game.player,game.player.camera.global_position,Vector3(0,1.55,-10))
 projectile.set_physics_process(false)
 await physics_call(func():
  projectile._physics_process(0.8)
  projectile._physics_process(0.8) # Queued contact cannot damage twice.
  return true)
 expect(front.hp == 1000 and back.hp == 986 and game.impacts == 1,"Actual finite projectile sweep skips hole, hits rear once and queues one impact")
 await clear_fixture()
 fixture()
 front = target(-4)
 cover = wall(-2)
 await settle()
 projectile = Projectile.new()
 game.level.add_child(projectile)
 projectile.configure(game,game.player,game.player.camera.global_position,Vector3(0,1.55,-10))
 projectile.set_physics_process(false)
 await physics_call(func():
  projectile._physics_process(0.8)
  return true)
 expect(front.hp == 1000 and game.impacts == 1,"Actual projectile sweep retains native wall contact")
 await clear_fixture()

 fixture()
 front = target(-4)
 await settle()
 # No valid view can reveal sprite texels, but physical player collision stays.
 game.player.camera = null
 projectile = Projectile.new()
 game.level.add_child(projectile)
 projectile.configure(game,front,Vector3(0,1,-2),Vector3(0,1,1))
 projectile.set_physics_process(false)
 await physics_call(func():
  projectile._physics_process(0.25)
  return true)
 expect(game.state.health == 86 and game.impacts == 1,"Null-camera enemy projectile still hits physical player capsule once")
 await clear_fixture()

 fixture()
 front = target(-2)
 front.swap_map_on_damage = true
 game.state.weapon = 2
 await settle()
 await physics_call(game.player.fire)
 expect(front.hp == 985 and game.state.ammo[2] == 19 and game.feedback == 0,"Reentrant damage map swap stops later pellets/feedback without refund")
 await clear_fixture()
 for boundary in ["normal", "damage", "feedback"]:
  fixture()
  var counter := CounterTarget.new()
  counter.host = game
  counter.stop_on_damage = boundary == "damage"
  counter.collision_layer = 4
  var counter_shape := CollisionShape3D.new()
  counter_shape.shape = BoxShape3D.new()
  counter_shape.shape.size = Vector3(4,4,1)
  counter.add_child(counter_shape)
  game.level.add_child(counter)
  counter.position = Vector3(0,1.55,-2)
  game.stop_on_feedback = boundary == "feedback"
  game.state.weapon = 1
  await settle()
  await physics_call(game.player.fire)
  expect(counter.hits == 1 and game.feedback == (0 if boundary == "damage" else 1),"Nonvisual callback compatibility without fake HP: "+boundary)
  expect(game.impacts == (1 if boundary == "normal" else 0),"Nonvisual damage/feedback reentrancy cancels later impact: "+boundary)
  await clear_fixture()
 print("Sprite shot integration failures=",failures,"; arranged RGBA/real Player+Projectile, no physical/earned/render acceptance")
 if failures == 0:
  print("PASS sprite shot integration: actual Player and Projectile share current RGBA coverage, finite piercing, real ammo, nonvisual compatibility and stale-callback guards")
 quit(0 if failures == 0 else 1)
