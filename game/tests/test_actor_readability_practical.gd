extends SceneTree
const Practical = preload("res://scripts/critical_actor_practical.gd")
class Actor extends Node3D:
	var hp: int = 100
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	var actor = Actor.new()
	root.add_child(actor)
	var camera = Camera3D.new()
	actor.add_child(camera)
	camera.position = Vector3(0,1,4)
	camera.current = true
	var sprite = Sprite3D.new()
	var image = Image.create(128,128,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.vframes = 1
	sprite.pixel_size = .03
	actor.add_child(sprite)
	var ordinary = Practical.new()
	actor.add_child(ordinary)
	ordinary.bind(sprite,false)
	var critical = Practical.new()
	actor.add_child(critical)
	critical.bind(sprite)
	ordinary.set_physics_process(false)
	critical.set_physics_process(false)
	await physics_frame
	await physics_frame
	ordinary._physics_process(.016)
	critical._physics_process(.016)
	print("LIGHT_STATE ordinary=",ordinary.visible," energy=",ordinary.light_energy," shadow=",ordinary.shadow_enabled," critical=",critical.visible," energy=",critical.light_energy," shadow=",critical.shadow_enabled)
	check(ordinary.visible and is_equal_approx(ordinary.light_energy,.65) and not ordinary.shadow_enabled and ordinary.light_cull_mask == 2,"Ordinary live actor receives a bounded no-shadow front practical")
	check(critical.visible and is_equal_approx(critical.light_energy,1.4) and critical.shadow_enabled,"Existing critical practical contract remains unchanged")
	check(ordinary.global_position.z > sprite.global_position.z,"Readability light follows the visible front, not actor yaw")
	actor.hp = 0
	ordinary._physics_process(.016)
	critical._physics_process(.016)
	check(not ordinary.visible and critical.visible,"Only retained critical corpses keep a supply-readable practical")
	actor.queue_free()
	await process_frame
	print("ACTOR_READABILITY_PRACTICAL failures=",failures," (arranged source/native ownership, NOT rendered visibility acceptance)")
	quit(0 if failures == 0 else 1)
