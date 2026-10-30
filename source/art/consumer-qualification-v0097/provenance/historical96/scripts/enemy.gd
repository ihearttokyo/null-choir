extends CharacterBody3D

const SealGuardians = preload("res://scripts/seal_guardians.gd")
const WorkerHitRegions = preload("res://scripts/worker_hit_regions.gd")
const WardenPressureWindow = preload("res://scripts/warden_pressure_window.gd")
const BODY_ATLASES := {
    "crawler": "res://assets/art/sprites/bodies-v1/crawler.png",
    "worker": "res://assets/art/sprites/bodies-v1/worker.png",
    "caster": "res://assets/art/sprites/bodies-v1/caster.png",
    "brute": "res://assets/art/sprites/bodies-v1/brute.png",
    "guardian": "res://assets/art/sprites/bodies-v1/guardian.png",
    "summoner": "res://assets/art/sprites/bodies-v1/summoner.png",
    "nursery_warden": "res://assets/art/sprites/bodies-v1/nursery_warden.png",
    "choir_avatar": "res://assets/art/sprites/bodies-v1/choir_avatar.png"
}
# Worker alone owns the actual six-row pressure-vent atlas and authored region mask.
const WORKER_BEAUTY_PATH := "res://assets/art/sprites/bodies-v1/worker.png"
const WORKER_REGION_MANIFEST := "res://assets/art/regions/worker-clutch-v1.json"
const CLUTCH_VENT_SECONDS := 1.1

const CriticalPractical = preload("res://scripts/critical_actor_practical.gd")
const EarnedSupplies = preload("res://scripts/earned_supplies.gd")
const Telegraph = preload("res://scripts/enemy_telegraph.gd")
const Projectile = preload("res://scripts/projectile.gd")
const WINDUPS = {"crawler":0.25,"worker":0.45,"caster":0.70,"brute":0.80,"guardian":0.75,"summoner":1.20,"nursery_warden":1.00,"choir_avatar":1.05}
const LATE = {
	"brute":{"hp":210,"speed":3.1,"radius":0.62,"height":3.3,"scale":4.4,"cooldown":3.0,"recovery":0.8},
	"guardian":{"hp":260,"speed":2.0,"radius":0.65,"height":3.7,"scale":4.7,"cooldown":2.6,"recovery":0.9},
	"summoner":{"hp":150,"speed":0.0,"radius":0.45,"height":4.2,"scale":5.6,"cooldown":3.8,"recovery":0.7},
	"nursery_warden":{"hp":1200,"speed":2.0,"radius":1.0,"height":5.4,"scale":7.3,"cooldown":3.2,"recovery":0.9},
	"choir_avatar":{"hp":1600,"speed":1.6,"radius":1.0,"height":5.6,"scale":7.6,"cooldown":3.0,"recovery":1.1}}

var game: Node
var id: String
var kind: String
var hp: int
var active: bool = true
var encounter_id: String = ""
var alerted: bool = false
var target: Node3D
var attack_time: float = 0
var telegraph_time: float = 0
var stagger_time: float = 0
var recovery_time: float = 0
var _counter_time: float = 0
var _committed_target: Node3D
var _committed_aim: Vector3
var _rush_time: float = 0
var _rush_direction: Vector3
var _rush_hit: bool = false
var _strafe_sign: float = 1
var hurt_time: float = 0
var pose_time: float = 0
var age: float = 0
var path_time: float = 0
var _routing: bool = false
var waypoint: Vector3
var sprite: Sprite3D
var speed: float = 4.0
var max_hp: int
var champion: Dictionary = {}
var champion_identity: Label3D
var phase: int = 0
var _profile: Dictionary = {}
var _attack_variant: int = 0
var _committed_variant: int = -1
var _released: bool = false
var _rush_duration: float = 0
var _recovery_duration: float = 0
var _summoned_total: int = 0
var _summon_owner_id: String = ""
# Transient like attack/stagger; checkpoint/Continue restores a fresh combat state.
var clutch_vent_time: float = 0.0
var _worker_clutch_spent := false
var _worker_regions: Dictionary = {}
var _worker_atlas_valid := true
var _warden_node_binding: Dictionary = {}

static func health_cap(role: String, difficulty: int, multiplier: float = 1.0) -> int:
	return int(LATE.get(role,{}).get("hp",50 if role == "crawler" else 90)*[0.85,1.0,1.3][difficulty]*multiplier)

static func capsule_radius(role: String) -> float:
	return LATE.get(role,{}).get("radius",0.42 if role == "crawler" else 0.34)

static func capsule_height(role: String) -> float:
	return LATE.get(role,{}).get("height",1.1 if role == "crawler" else 2.7)

static func canonical_yaw(value: float) -> float:
	if not is_finite(value): return value
	if value < -PI or value >= PI: value = wrapf(value,-PI,PI)
	# Float32 PI is outside [-PI,PI); this clamp rounds to its nearest interior float32.
	return Vector3(0,clampf(value,-3.1415925,3.1415925),0).y

func snapshot() -> Dictionary:
	return {"id":id,"hp":hp,"position":[position.x,position.y,position.z],"yaw":canonical_yaw(rotation.y),"alerted":alerted}

func restore_snapshot(record: Dictionary) -> void:
	# Only called on freshly configured bodies: attacks, targets and physics reset.
	hp = int(record.hp)
	position = Vector3(record.position[0],record.position[1],record.position[2])
	rotation.y = canonical_yaw(record.yaw)
	alerted = record.alerted
	phase = 1 if kind in ["nursery_warden","choir_avatar"] and hp < max_hp/2.0 else 0

func configure(owner_game: Node, spec: Dictionary) -> void:
	game = owner_game
	id = spec.id
	kind = spec.kind
	encounter_id = spec.get("encounter","")
	_summon_owner_id = spec.get("owner","")
	active = encounter_id.is_empty() or "encounter:"+encounter_id in game.state.removed
	alerted = active and not encounter_id.is_empty()
	_strafe_sign = 1 if id.hash()%2 == 0 else -1
	_profile = LATE.get(kind,{})
	champion = SealGuardians.profile(spec)
	hp = health_cap(kind,game.state.difficulty,champion.get("health_multiplier",1.0))
	max_hp = hp
	speed = _profile.get("speed",5.4 if kind == "crawler" else 3.1)
	if kind == "summoner":
		for number in range(1,7):
			if "summon:"+id+":"+str(number) in game.state.removed or id+"_add_"+str(number) in game.state.removed: _summoned_total = number
	position = game.level.layout.world_position(spec.cell)
	# Fresh capsules need their whole lower sphere supported on sloped triangles.
	# Main restores saved poses afterwards; never rewrite their signed clearance.
	position.y = game.level.layout.capsule_floor_support(Vector2(position.x,position.z),capsule_radius(kind)) + 0.03
	rotation.y = deg_to_rad(spec.yaw)
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.5
	if kind in ["caster","choir_avatar"]:
		position.y += 1.0
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		floor_snap_length = 0
	var collider = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = capsule_radius(kind)
	shape.height = capsule_height(kind)
	collider.shape = shape
	collider.position.y = shape.height/2
	add_child(collider)
	sprite = Sprite3D.new()
	# Explicit production worker resource; never fall back to the legacy119 atlas.
	sprite.texture = load(BODY_ATLASES[kind])
	sprite.hframes = 8
	sprite.vframes = 5
	if kind == "worker":
		var rows := WorkerHitRegions.pose_rows(sprite.texture)
		_worker_atlas_valid = rows > 0
		if _worker_atlas_valid: sprite.vframes = rows
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	var cell: int = 256 if kind in ["nursery_warden","choir_avatar"] else 128
	sprite.pixel_size = _profile.get("scale",3.8 if kind == "crawler" else 3.65)/float(cell)
	sprite.position.y = (cell/2.0-8)*sprite.pixel_size
	add_child(sprite)
	var critical: bool=not champion.is_empty()
	for grant in EarnedSupplies.chapter(game.level.layout).get("grants",[]):
		if grant.carrier==id: critical=true;break
	if critical:
		var practical := CriticalPractical.new()
		practical.bind(sprite)
		practical.set_meta("source_actor",id)
		practical.set_meta("source_role","seal_bearer" if champion.has("seal") else "exit_warden" if not champion.is_empty() else "equipment_carrier")
		add_child(practical)
	if not champion.is_empty(): champion_identity = SealGuardians.attach_identity(self,champion)
	if kind == "worker": _worker_regions = WorkerHitRegions.bind(sprite,WORKER_REGION_MANIFEST)
	if kind == "nursery_warden": _warden_node_binding = WardenPressureWindow.bind(sprite)
	if kind in ["worker","brute","nursery_warden"]:
		var tell = Telegraph.new()
		tell.name = "CommittedShotTell"
		add_child(tell)

func visual_hit_sprite() -> Sprite3D:
	# Visual occupancy queries are separate from movement/placement capsules.
	if hp <= 0 or not _current_map() or not game.playing or not _worker_atlas_valid: return null
	return sprite if is_instance_valid(sprite) else null

var _floor_settle_failed: bool = false

func _physics_process(delta: float) -> void:
	if not _current_map() or not game.playing or not is_instance_valid(game.player) or game.player.is_queued_for_deletion(): return
	_released = false
	age += delta
	hurt_time = maxf(0,hurt_time-delta)
	attack_time = maxf(0,attack_time-delta)
	pose_time = maxf(0,pose_time-delta)
	stagger_time = maxf(0,stagger_time-delta)
	clutch_vent_time = maxf(0,clutch_vent_time-delta)
	recovery_time = maxf(0,recovery_time-delta)
	_counter_time = maxf(0,_counter_time-delta)
	var camera = game.player.camera
	var view = global_basis.inverse()*(camera.global_position-global_position)
	var direction_index = posmod(int(round(atan2(view.x,-view.z)/TAU*8)),8)
	var frame = 4 if hp <= 0 else WorkerHitRegions.VENT_POSE if clutch_vent_time > 0 else 3 if telegraph_time > 0 or pose_time > 0 or (not _profile.is_empty() and (recovery_time > 0 or _rush_time > 0)) else 1+int(age*6)%2 if active and alerted else 0
	sprite.frame = frame*8+direction_index
	sprite.modulate = Color(1.7,0.7,0.6) if hurt_time > 0 else Color.WHITE
	if is_instance_valid(champion_identity): SealGuardians.present_identity(self,champion_identity)
	if hp <= 0: return
	if kind in ["nursery_warden","choir_avatar"] and hp < max_hp/2.0: phase = 1
	if not active:
		velocity.x = 0
		velocity.z = 0
		return
	if not _valid_target(target): target = game.player
	if (telegraph_time > 0 or _rush_time > 0) and not _valid_target(_committed_target):
		telegraph_time = 0
		_rush_time = 0
		pose_time = 0
		_committed_variant = -1
		_released = false
	var aim = target.global_position+Vector3(0,1.0,0)
	var query = PhysicsRayQueryParameters3D.create(global_position+Vector3(0,1,0),aim,1)
	var sight = get_world_3d().direct_space_state.intersect_ray(query)
	var range_to_target = global_position.distance_to(target.global_position)
	if range_to_target < 34 and sight.is_empty(): alerted = true
	if kind in ["caster","choir_avatar"]:
		var floor_query = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.5,global_position-Vector3.UP*6,1)
		var floor_hit = get_world_3d().direct_space_state.intersect_ray(floor_query)
		velocity.y = clampf((floor_hit.position.y+1.0+sin(age*2)*0.16-global_position.y)*5,-3,3) if not floor_hit.is_empty() else -3.0
	else:
		velocity.y -= delta*24
	var arrived_waypoint := false
	var heading = target.global_position-global_position
	heading.y = 0
	velocity.x = 0
	velocity.z = 0
	if telegraph_time > 0:
		heading = _committed_aim-global_position
		heading.y = 0
		telegraph_time = maxf(0,telegraph_time-delta)
		if telegraph_time <= 0: _release_attack()
	elif _rush_time > 0:
		_rush_time = maxf(0,_rush_time-delta)
		heading = _rush_direction
		if _rush_time > 0:
			var rush_speed: float = 15.0 if kind == "brute" else 13.0 if kind == "nursery_warden" else 9.0
			velocity.x = _rush_direction.x*rush_speed
			velocity.z = _rush_direction.z*rush_speed
		elif not _profile.is_empty(): _finish_charge()
	elif alerted and stagger_time <= 0:
		if speed > 0:
			path_time -= delta
			if path_time <= 0:
				waypoint = _next_step(target.global_position)
				path_time = 1.0
			if _routing: heading = waypoint-global_position
			heading.y = 0
		var move = heading.normalized()
		var desired = speed
		if (kind == "crawler" or not _profile.is_empty()) and recovery_time > 0:
			desired = 0
		elif kind in ["worker","caster"] and sight.is_empty() and not _routing:
			var side = move.cross(Vector3.UP)*_strafe_sign
			if range_to_target < (8.0 if kind == "worker" else 10.0):
				move = (-move+side*0.5).normalized()
			elif range_to_target < (18.0 if kind == "worker" else 24.0):
				move = side
				desired = 1.8 if kind == "worker" else 1.4
		if _routing and delta > 0:
			desired = minf(desired,heading.length()/delta)
			arrived_waypoint = desired > 0 and heading.length() > .001 and heading.length() <= desired*delta+.00001
		velocity.x = move.x*desired
		velocity.z = move.z*desired
		if kind in WINDUPS and attack_time <= 0 and recovery_time <= 0 and sight.is_empty() and range_to_target < (3.6 if kind == "crawler" else 30.0) and (kind != "summoner" or _summon_budget() > 0):
			_begin_attack(aim)
	if not _current_map() or not game.playing: return
	if heading.length() > 0.2:
		var facing: float = atan2(-heading.x,-heading.z)
		rotation.y = rotate_toward(rotation.y,facing,delta*1.8) if kind == "guardian" else facing
	move_and_slide()
	_settle_live_floor_contact()
	if arrived_waypoint and Vector2(global_position.x-waypoint.x,global_position.z-waypoint.z).length_squared() < .000001: path_time = 0
	if _rush_time > 0 and not _rush_hit: _try_melee()
	if not is_instance_valid(self): return
	if not _profile.is_empty() and hp > 0 and _rush_time > 0 and _current_map() and game.playing and (is_on_wall() or _rush_hit): _finish_charge()
	if kind in ["worker","caster"] and sight.is_empty() and is_on_wall(): _strafe_sign = -_strafe_sign

func combat_visual_state() -> Dictionary:
	if not _current_map(): return {}
	var stage := "idle"
	var progress := 0.0
	if hp <= 0:
		stage = "dead"
		progress = 1.0
	elif not active: stage = "dormant"
	elif kind == "worker" and clutch_vent_time > 0:
		stage = "clutch_vent"
		progress = 1.0-clutch_vent_time/CLUTCH_VENT_SECONDS
	elif stagger_time > 0:
		stage = "stagger"
		progress = 1.0-stagger_time/.25
	elif telegraph_time > 0:
		stage = "windup"
		progress = 1.0-telegraph_time/_windup_seconds()
	elif _rush_time > 0 or _released:
		stage = "release"
		progress = 1.0-_rush_time/_rush_duration if _rush_duration > 0 and _rush_time > 0 else 1.0
	elif recovery_time > 0 or pose_time > 0:
		stage = "recovery"
		progress = 1.0-maxf(recovery_time,pose_time)/_recovery_duration if _recovery_duration > 0 else 0.0
	elif alerted and Vector2(velocity.x,velocity.z).length_squared() > .001: stage = "move"
	return {"phase":stage,"progress":clampf(progress,0,1),"variant":_committed_variant if stage in ["windup","release","recovery"] else -1,
		"facing":sprite.frame%8,"hurt":hurt_time > 0,"boss_phase":phase}

func _current_map() -> bool:
	return is_instance_valid(game) and not game.is_queued_for_deletion() and is_instance_valid(game.level) and game.level == get_parent() and not game.level.is_queued_for_deletion() and not is_queued_for_deletion()

func _valid_target(candidate) -> bool:
	if not is_instance_valid(candidate) or candidate.is_queued_for_deletion(): return false
	if candidate == game.player: return game.state.health > 0
	var health = candidate.get("hp")
	return health != null and health > 0

func _event(event: String) -> void:
	if game.has_method("enemy_event"): game.enemy_event(self,event)

func _windup_seconds() -> float:
	return maxf(WINDUPS[kind],champion.get("attack_windup",0.0))

func _begin_attack(aim: Vector3) -> void:
	_committed_target = target
	_committed_variant = _attack_variant
	_released = false
	_committed_aim = aim
	telegraph_time = _windup_seconds()
	velocity.x = 0
	velocity.z = 0
	_event("windup")

func _release_attack() -> void:
	if not _valid_target(_committed_target): return
	_released = true
	attack_time = _profile.get("cooldown",0.8 if kind == "crawler" else 1.7 if kind == "worker" else 2.2)*(0.8 if phase > 0 else 1.0)
	recovery_time = _profile.get("recovery",0.45 if kind == "crawler" else 0.65 if kind == "worker" else 0.9)
	recovery_time = maxf(recovery_time,champion.get("recovery",0.0))
	_recovery_duration = recovery_time
	pose_time = (0.4 if kind == "caster" else 0.22) if _profile.is_empty() else recovery_time
	_event("attack")
	if not _current_map() or not game.playing: return
	if not _profile.is_empty():
		_release_late_attack()
		return
	var origin = global_position+Vector3.UP*1.4
	if kind == "crawler":
		_rush_direction = _committed_aim-global_position
		_rush_direction.y = 0
		_rush_direction = _rush_direction.normalized()
		_rush_time = 0.18
		_rush_duration = _rush_time
		_rush_hit = false
		velocity.x = _rush_direction.x*9.0
		velocity.z = _rush_direction.z*9.0
	elif kind == "worker":
		var shot = PhysicsRayQueryParameters3D.create(origin,origin+(_committed_aim-origin).normalized()*30.0,1|2|4)
		shot.exclude = [get_rid()]
		shot.hit_from_inside = true
		var hit = get_world_3d().direct_space_state.intersect_ray(shot)
		if not hit.is_empty(): _attack(hit.collider,10,{"attack_kind":"hitscan","origin":origin,"incoming_direction":(shot.to-shot.from).normalized(),"hit_position":hit.position})
	elif kind == "caster":
		var projectile = Projectile.new()
		game.level.add_child(projectile)
		projectile.configure(game,self,origin,_committed_aim)

func _release_late_attack() -> void:
	if hp <= 0 or not active: return
	if kind == "brute" or (kind == "nursery_warden" and _attack_variant == 0):
		_rush_direction = _committed_aim-global_position
		_rush_direction.y = 0
		_rush_direction = _rush_direction.normalized()
		_rush_time = 0.9 if kind == "brute" else 0.7
		_rush_duration = _rush_time
		_rush_hit = false
		recovery_time = 0
		pose_time = _rush_time
		velocity.x = _rush_direction.x*(15.0 if kind == "brute" else 13.0)
		velocity.z = _rush_direction.z*(15.0 if kind == "brute" else 13.0)
	elif kind == "guardian":
		_fire_pattern(1)
	elif kind == "summoner":
		_summon()
	elif kind == "nursery_warden":
		_fire_pattern(5 if phase > 0 else 3)
	elif kind == "choir_avatar":
		_fire_pattern((12 if phase > 0 else 8) if _attack_variant == 1 else (5 if phase > 0 else 3),_attack_variant == 1)
	if kind in ["nursery_warden","choir_avatar"]: _attack_variant = 1-_attack_variant

func _finish_charge() -> void:
	_rush_time = 0
	velocity.x = 0
	velocity.z = 0
	recovery_time = maxf(recovery_time,maxf(_profile.recovery,champion.get("recovery",0.0)))
	pose_time = maxf(pose_time,recovery_time)
	_recovery_duration = maxf(recovery_time,pose_time)

func _fire_pattern(count: int, radial: bool = false) -> void:
	var origin = global_position+Vector3.UP*(1.65 if kind == "guardian" else 2.8)
	var aim = (_committed_aim-origin).normalized()
	for index in range(count):
		if not _current_map() or not game.playing: return
		var angle: float = index*TAU/count if radial else (index-(count-1)/2.0)*0.13
		var projectile = Projectile.new()
		game.level.add_child(projectile)
		projectile.configure(game,self,origin,origin+aim.rotated(Vector3.UP,angle)*30)

func _summon_budget() -> int:
	var living: int = 0
	var global_living: int = 0
	for actor in game.enemies:
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor._current_map() or actor.hp <= 0 or actor._summon_owner_id.is_empty(): continue
		global_living += 1
		if actor._summon_owner_id == id: living += 1
	return maxi(0,mini(6-_summoned_total,mini(2-living,4-global_living)))

func _summon() -> void:
	var remaining: int = _summon_budget()
	var layout = game.level.layout
	var space = get_world_3d().direct_space_state
	var shape = CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.1
	# Fixed eight-point search: no navigation or retry chain for a blocked ritual.
	for offset in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized(),Vector2(-1,1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]:
		if remaining <= 0 or hp <= 0 or not active or not _current_map() or not game.playing: return
		var cell = Vector2(global_position.x+offset.x*2.4,global_position.z+offset.y*2.4)/float(layout.data.cell_size)
		if not layout.is_walkable(Vector2i(cell.floor())): continue
		var point: Vector3 = layout.world_position([cell.x,cell.y])
		var ray = PhysicsRayQueryParameters3D.create(point+Vector3.UP*3,point-Vector3.UP,1)
		var floor_hit = space.intersect_ray(ray)
		if floor_hit.is_empty() or absf(floor_hit.position.y-point.y) > 0.08: continue
		point = floor_hit.position+Vector3.UP*0.03
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*0.55)
		query.collision_mask = 1|2|4
		if not space.intersect_shape(query,1).is_empty(): continue
		# ponytail: conservative actor envelopes reject tight gaps; native-only checks after same-frame births are verified.
		var crowded: bool = false
		for body in game.enemies+[game.player]:
			if not is_instance_valid(body) or body.is_queued_for_deletion() or body.get_parent() != game.level: continue
			if body != game.player and body.hp <= 0: continue
			var other_shape = body.get_child(0).shape
			var horizontal = Vector2(point.x-body.position.x,point.z-body.position.z)
			if horizontal.length() < shape.radius+other_shape.radius and point.y < body.position.y+other_shape.height and point.y+shape.height > body.position.y:
				crowded = true
				break
		if crowded: continue
		_summoned_total += 1
		var add = get_script().new()
		game.level.add_child(add)
		add.configure(game,{"id":id+"_add_"+str(_summoned_total),"kind":"crawler","cell":[cell.x,cell.y],"yaw":rad_to_deg(rotation.y)})
		add.position = point
		add._summon_owner_id = id
		add.target = _committed_target
		add.alerted = true
		game.enemies.append(add)
		game.state.removed.append("summon:"+id+":"+str(_summoned_total))
		remaining -= 1

func _try_melee() -> void:
	if not _valid_target(_committed_target) or global_position.distance_to(_committed_target.global_position) >= (2.4 if kind in ["brute","nursery_warden"] else 1.9): return
	var query = PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.6,_committed_target.global_position+Vector3.UP*0.7,1|2|4)
	query.exclude = [get_rid()]
	query.hit_from_inside = true
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (hit.collider == game.player or hit.collider.has_method("take_damage")):
		_rush_hit = true
		if kind in ["crawler","brute","nursery_warden"] and OS.is_debug_build() and game.has_method("enemy_event"):
			var original_map: Node = game.level
			var original_player: Node = game.player
			var original_victim: Node = hit.collider
			_event("melee_contact")
			if not is_instance_valid(self) or not _current_map() or not game.playing or game.level != original_map or game.player != original_player or not is_instance_valid(original_player) or original_player.is_queued_for_deletion() or original_player.get_parent() != original_map or not is_instance_valid(original_victim) or original_victim.is_queued_for_deletion() or original_victim.get_parent() != original_map: return
		_attack(hit.collider,24 if kind == "brute" else 32 if kind == "nursery_warden" else 12,{"attack_kind":"melee","origin":query.from,"incoming_direction":(query.to-query.from).normalized(),"hit_position":hit.position})

func _attack(victim: Node, amount: int, context: Dictionary = {}) -> void:
	if not _current_map() or not game.playing or hp <= 0 or not active or not is_instance_valid(victim) or victim.is_queued_for_deletion(): return
	pose_time = 0.22
	# Named seal/door champions punish a missed readable commitment, not faster fire.
	if not champion.is_empty(): amount = int(ceil(amount*1.15))
	if victim == game.player:
		game.hurt_player(int(amount*[0.7,1.0,1.4][game.state.difficulty]))
	elif victim.has_method("take_damage"):
		victim.take_damage(amount,self,context)

func take_damage(amount: int, source: Node3D, context: Dictionary = {}) -> void:
	if hp <= 0 or amount <= 0 or not _current_map() or not game.playing: return
	# A masked front-node precision bonus; ordinary damage and interruption stay identical.
	if kind == "nursery_warden" and Engine.is_in_physics_frame() and WardenPressureWindow.eligible(_warden_node_binding,sprite,context.get("sprite_contact",{}),get_instance_id(),source,game.player,game,game.level,kind,telegraph_time,_committed_variant,context,Engine.get_physics_frames()):
		amount = WardenPressureWindow.bonus_damage(amount)
	if kind == "guardian" and telegraph_time <= 0 and pose_time <= 0 and recovery_time <= 0:
		var incoming := Vector3.ZERO
		if context.is_empty():
			if is_instance_valid(source): incoming = source.global_position-global_position
		elif context.get("incoming_direction") is Vector3:
			incoming = -context.incoming_direction
		elif context.get("origin") is Vector3:
			incoming = context.origin-global_position
		# Explicit invalid or vertical geometry has no front bearing; never use a moved shooter.
		if incoming.is_finite(): incoming.y = 0
		if incoming.is_finite() and incoming.length_squared() > 0.0001 and (-global_basis.z).dot(incoming.normalized()) > 0.5: amount = maxi(1,int(amount*0.35))
	hp = maxi(0,hp-amount)
	hurt_time = 0.12
	alerted = true
	if not active:
		active = true
		if not encounter_id.is_empty() and game.has_method("activate_encounter"): game.activate_encounter(encounter_id)
	if not _current_map(): return
	if source != self and _valid_target(source) and source.get_parent() == game.level: target = source
	if hp == 0:
		if game.has_method("earned_defeated") and not game.earned_defeated(self): return
		_committed_variant = -1
		_released = false
		telegraph_time = 0
		stagger_time = 0
		clutch_vent_time = 0
		recovery_time = 0
		_rush_time = 0
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		if not id in game.state.removed: game.state.removed.append(id)
		if game.has_method("guardian_defeated"): game.guardian_defeated(self)
		_event("death")
	elif telegraph_time > 0 and _counter_time <= 0:
		_committed_variant = -1
		_released = false
		telegraph_time = 0
		pose_time = 0
		stagger_time = 0.25
		recovery_time = 0.35
		_recovery_duration = recovery_time
		attack_time = maxf(attack_time,0.45)
		# The lock exceeds retry + the longest windup; further hits cannot refresh it.
		_counter_time = 1.4 if _profile.is_empty() else 2.0
		_event("stagger")
	# Leave the complete ordinary-hit/death transaction above unchanged. This is
	# an additional authored consequence, never the condition for interruption.
	if _current_map() and game.playing and hp > 0:
		_try_worker_clutch(source,context)

func _try_worker_clutch(source: Node3D, context: Dictionary) -> void:
	if kind != "worker" or _worker_clutch_spent or hp <= 0: return
	if not _current_map() or not game.playing or not is_instance_valid(source) or source != game.player or source.get_parent() != game.level: return
	if context.get("attack_kind") not in ["melee","hitscan","piercing"]: return
	var contact = context.get("sprite_contact",{})
	if not contact is Dictionary or WorkerHitRegions.region(_worker_regions,sprite,contact,get_instance_id()) != WorkerHitRegions.CLUTCH: return
	_worker_clutch_spent = true
	clutch_vent_time = CLUTCH_VENT_SECONDS
	_committed_variant = -1
	_committed_target = null
	_released = false
	telegraph_time = 0
	pose_time = 0
	_rush_time = 0
	stagger_time = maxf(stagger_time,CLUTCH_VENT_SECONDS)
	recovery_time = maxf(recovery_time,CLUTCH_VENT_SECONDS)
	_recovery_duration = recovery_time
	attack_time = maxf(attack_time,CLUTCH_VENT_SECONDS)
	# Never shorten ordinary counter protection or allow vent/pellets to refresh it.
	_counter_time = maxf(_counter_time,1.4)
	velocity.x = 0
	velocity.z = 0
	_event("clutch_vent")


func _next_step(destination: Vector3) -> Vector3:
	_routing = true
	var routes = game.level.get_node_or_null("NavigationRoutes")
	if routes == null: return global_position
	var layout = game.level.layout
	var size: float = layout.data.cell_size
	var start: Vector3 = layout.world_position([global_position.x/size,global_position.z/size])+Vector3.UP*.03
	var goal: Vector3 = layout.world_position([destination.x/size,destination.z/size])+Vector3.UP*.03
	if layout.OssuarySurfaces.enabled(layout.data):
		# Select the physical layer already occupied; never move the actor or project
		# an unreachable endpoint. Native .25 start guard and route budget stay unchanged.
		start = layout.surface_position_at_y([global_position.x/size,global_position.z/size],global_position.y)+Vector3.UP*.03
		goal = layout.surface_position_at_y([destination.x/size,destination.z/size],destination.y+_target_capsule_foot_offset())+Vector3.UP*.03
	# A player fits wall corners outside the larger actor's eroded navigation mesh.
	var path: PackedVector3Array = routes.route(start,goal,kind,capsule_radius(kind)*sqrt(2.0)+.4)
	var line := Vector2(goal.x-start.x,goal.z-start.z)
	if not path.is_empty() and line.length() > .001 and Vector2(path[-1].x-goal.x,path[-1].z-goal.z).length() <= .15:
		var straight := true
		for point in path:
			if absf(line.cross(Vector2(point.x-start.x,point.z-start.z)))/line.length() > .02:
				straight = false
				break
		if straight:
			_routing = false
			return path[-1]
	for point in path:
		if Vector2(point.x-global_position.x,point.z-global_position.z).length() <= .15: continue
		_routing = Vector2(point.x-destination.x,point.z-destination.z).length() > .15
		return point
	return global_position

# Physical target foot relative to its origin; Player's .85 centre/1.65 height is +.025,
# whereas normal Enemy capsules start at their origin. This is not endpoint projection.
func _target_capsule_foot_offset() -> float:
	if not is_instance_valid(target): return 0.0
	for child in target.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D and not child.disabled:
			return child.global_position.y-child.shape.height*0.5*child.global_basis.y.length()-target.global_position.y
	return 0.0

# LIVE movement only. Restored snapshots never call this before strict trust checks.
# CharacterBody slope solving can leave >safe_margin floor penetration (actual19).
# Use native swept movement, not position/snapshot rewriting, and never repair hover.
func _settle_live_floor_contact() -> bool:
	_floor_settle_failed = false
	if kind in ["caster","choir_avatar"] or hp <= 0 or not _current_map(): return true
	var collider: CollisionShape3D = get_child(0)
	var layout = game.level.layout
	var radius: float = collider.shape.radius
	var support: float = layout.capsule_floor_support_at_y(Vector2(position.x,position.z),radius,position.y,.08)
	if not is_finite(support): return true # Airborne/falling, not a floor repair candidate.
	var deficit: float = support-position.y
	var allowance: float = minf(safe_margin,.001)
	if deficit <= allowance: return true
	_floor_settle_failed = true
	if deficit > .08 or safe_margin <= 0: return false # Existing codec trust envelope, not new admission.
	var space = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = collider.global_transform
	query.collision_mask = 1|4
	query.exclude = [get_rid()]
	var contacts = space.intersect_shape(query,32)
	if contacts.is_empty() or contacts.size()==32: return false
	for hit in contacts:
		if not hit.collider is StaticBody3D or not hit.collider in game.level.floor_bodies or hit.collider.get_parent().get_parent()!=game.level: return false
	var pairs = space.collide_shape(query,32)
	if pairs.is_empty() or pairs.size()==64: return false
	var sphere_y: float = collider.global_position.y-collider.shape.height*.5+radius
	for index in range(0,pairs.size(),2):
		var point: Vector3 = pairs[index+1]
		# Lower sphere only; ceilings/side contacts never become floor settlement.
		if point.y > sphere_y or Vector2(point.x-position.x,point.z-position.z).length()>radius: return false
		var ray = space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.05,point-Vector3.UP*.05,1))
		if ray.is_empty() or ray.normal.y<.5 or not ray.collider in game.level.floor_bodies: return false
		if absf(ray.position.y-point.y)>.001: return false
	# Native motion performs its own depenetration; actual travel can include XZ drift.
	var collision = move_and_collide(Vector3.UP*(deficit+safe_margin))
	if collision!=null: return false
	support = layout.capsule_floor_support_at_y(Vector2(position.x,position.z),radius,position.y,.08)
	if not is_finite(support) or position.y < support-allowance: return false
	query.transform = collider.global_transform
	if not space.intersect_shape(query,1).is_empty(): return false
	_floor_settle_failed = false
	return true
