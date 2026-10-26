extends SceneTree
## Current-v2 earned source campaign. No staged campaign state, teleport, direct
## damage, resource grants, AI freezing or old v1 acceptance/golden inheritance.
## Virtual Input and actual menu callbacks are NOT physical human controls.
const Main = preload("res://scripts/main.gd")
const Campaign = preload("res://scripts/campaign.gd")
const MOVES = ["move_left","move_right","move_forward","move_back"]
const RUNTIME = ["main","player","enemy","projectile","sprite_hit_query","campaign","level","level_data","navigation_routes"]
const MAP_TICKS = 36000
const MAP_SECONDS = 600
const HOP_TICKS = 1800
const GLOBAL_TICKS = 288000
const RESUME08_HEART_SAVE_SHA = "d6868c5cc6d35b4bbb310eb89deff5b2bb5c30a338d06d1c3d5c11d8dea688f9"
const RESUME08_HEART_MANIFEST_SHA = "9e835647df5097f6485eb3ce91cd983a8bfc15a317cebb57063c015419da9717"
const RESUME07_SAVE_SHA = "ae71df351fd2ef0741f3c8e7fd7229ec28a62a213f36baff83120057e4d93288"
const RESUME07_MANIFEST_SHA = "da7376ccea92d46db83639f14981b031c4ac4de9d98c741508dda7f94c5d4372"
class EarnedMain:
 extends "res://scripts/main.gd"
 var recordless := false
 var ledger: Dictionary = {}
 var enabled = false
 var ledger_ok = true
 var first_fault: Dictionary = {}
 var event_history: Array = []
 var observed_weapon = -1
 var ticks = 0
 var shots = [0,0,0,0,0,0]
 var consumed: Dictionary = {}
 var deaths: Dictionary = {}
 var saves = 0
 var instance_id = 0
 var last_ticks = [-1,-1,-1,-1,-1,-1]
 var slots = [-1.0,-1.0,-1.0,-1.0,-1.0,-1.0]
 func budget() -> Dictionary:
  return {"health":state.health,"armor":state.armor,"ammo":state.ammo.duplicate(),"owned_weapons":state.owned_weapons.duplicate()}
 func note(event: String,data: Dictionary) -> void:
  var row: Dictionary = data.duplicate(true)
  row.event = event
  row.engine_tick = Engine.get_physics_frames()
  row.level = state.level_index
  row.weapon = state.weapon
  event_history.append(row)
  if event_history.size()>32: event_history.pop_front()
 func audit(ok: bool,category: String,data: Dictionary = {}) -> void:
  if ok: return
  ledger_ok = false
  if first_fault.is_empty():
   first_fault = {"category":category,"event":data.duplicate(true),"engine_tick":Engine.get_physics_frames(),"level":state.level_index,"actual_budget":budget(),"ledger_budget":ledger.duplicate(true),"history":event_history.duplicate(true)}
   if is_instance_valid(player):
    first_fault.player = {"instance":player.get_instance_id(),"active_time":player.active_play_time,"last_shots":player._last_shots.duplicate(),"cooldowns":player.weapon_cooldowns.duplicate(),"repeat_weapon":player._repeat_weapon,"weapon_intent":player._weapon_intent,"fire_held":Input.is_action_pressed("fire"),"position":str(player.position)}
   print("EARNED_V2_FIRST_LEDGER_FAULT ",JSON.stringify(first_fault))
 func observe_player_epoch(identity: int) -> void:
  if instance_id!=identity:
   instance_id = identity
   last_ticks = [-1,-1,-1,-1,-1,-1]
   slots = [-1.0,-1.0,-1.0,-1.0,-1.0,-1.0]
 func observe_weapon_transition() -> void:
  if observed_weapon!=state.weapon:
   note("observed_weapon_change",{"from":observed_weapon,"to":state.weapon})
   # Native Player._end_repeat ends the previous burst on actual weapon change.
   # Keep per-slot last ticks: switching cannot waive its full first-shot interval.
   slots = [-1.0,-1.0,-1.0,-1.0,-1.0,-1.0]
   observed_weapon = state.weapon
 # Exact09 trace: actual switch-return pistol457/470/483/495 is valid on the
 # NEW457+12.6n grid. Stale old grid falsely demanded495.2 at native495.
 func judge_shot_slot(slot: int,tick: int,interval: float) -> Dictionary:
  # Callback can precede next Main physics observer. Synchronize here so the
  # next observer does NOT clear this new burst a second time.
  observe_weapon_transition()
  var nominal: float = slots[slot]
  var previous: int = last_ticks[slot]
  var accepted: bool = previous<0 or (tick>previous and float(tick)+.000001>=(nominal if nominal>=0 else previous+interval))
  var row: Dictionary = {"slot":slot,"previous_tick":previous,"current_tick":tick,"nominal_before":nominal,"interval_ticks":interval,"delta_ticks":tick-previous,"intended_minimum":nominal if nominal>=0 else previous+interval,"accepted":accepted}
  # Same existing finite cadence equation/tolerance; only burst context changes.
  nominal = tick+interval if nominal<0 else nominal+interval
  if nominal<=tick+.000001: nominal += (floorf((tick+.000001-nominal)/interval)+1)*interval
  slots[slot] = nominal
  last_ticks[slot] = tick
  return row
 func _physics_process(delta: float) -> void:
  if not enabled: return
  observe_weapon_transition()
  if playing and not get_tree().paused:
   ticks += 1
   audit(absf(delta-1.0/60.0)<.000001,"physics_delta",{"delta":delta})
  if not Input.is_action_pressed("fire"): slots = [-1.0,-1.0,-1.0,-1.0,-1.0,-1.0]
 func shot(slot: int) -> void:
  if enabled:
   observe_player_epoch(player.get_instance_id())
   var cadence: Dictionary = judge_shot_slot(slot,Engine.get_physics_frames(),Player.WEAPONS[slot].interval*60.0)
   cadence.merge({"active_time":player.active_play_time,"shot_age":player.shot_age(slot),"current_repeat_weapon":player._repeat_weapon})
   note("accepted_shot",cadence)
   audit(cadence.accepted,"accepted_shot_cadence",cadence)
   var expected: Dictionary = ledger.duplicate(true)
   if slot>0: expected.ammo[slot] -= 1
   audit(Engine.is_in_physics_frame(),"shot_outside_physics",cadence)
   audit(Input.is_action_pressed("fire"),"shot_without_held_input",cadence)
   audit(slot in state.owned_weapons,"shot_unowned_weapon",cadence)
   audit(player.shot_age(slot)==0,"shot_age_not_zero",cadence)
   audit(budget()==expected,"accepted_shot_resource_conservation",{"expected":expected,"actual":budget(),"cadence":cadence})
   ledger = expected
   shots[slot] += 1
  super.shot(slot)
 func hurt_player(amount: int) -> void:
  if enabled and state.health>0 and amount>0:
   var absorbed: int = mini(ledger.armor,amount/3)
   ledger.armor -= absorbed
   ledger.health = maxi(0,ledger.health-(amount-absorbed))
  super.hurt_player(amount)
  if enabled: audit(budget()==ledger,"hurt_resource_conservation",{"amount":amount,"expected":ledger,"actual":budget()})
 func collect_pickup(id: String) -> void:
  if not enabled:
   super.collect_pickup(id)
   return
  var expected: Dictionary = ledger.duplicate(true)
  var spec: Dictionary = {}
  for row in level.layout.data.pickups:
   if row.id==id: spec = row
  var acquired_slot = -1
  var consume = not spec.is_empty() and not id in state.removed
  if consume:
   match spec.kind:
    "ammo", "weapon":
     var slot: int = spec.weapon
     var capacity: int = Player.WEAPONS[slot].max_ammo
     var acquired: bool = spec.kind=="weapon" and not slot in expected.owned_weapons
     consume = acquired or expected.ammo[slot]<capacity
     if acquired: expected.owned_weapons.append(slot); acquired_slot = slot
     if consume: expected.ammo[slot] = mini(capacity,expected.ammo[slot]+int(spec.amount))
    "health":
     consume = expected.health<100
     if consume: expected.health = mini(100,expected.health+int(spec.amount))
    "armor":
     consume = expected.armor<200
     if consume: expected.armor = mini(200,expected.armor+int(spec.amount))
  super.collect_pickup(id)
  var key: String = str(state.level_index)+"/"+id
  if consume:
   consumed[key] = int(consumed.get(key,0))+1
   audit(consumed[key]==1 and state.removed.count(id)==1,"pickup_once",{"id":key,"count":consumed[key],"removed_count":state.removed.count(id)})
  ledger = expected
  audit(budget()==ledger,"pickup_resource_conservation",{"id":key,"expected":ledger,"actual":budget()})
  if acquired_slot>=0: audit(state.weapon==acquired_slot,"pickup_automatic_weapon_selection",{"expected_slot":acquired_slot,"actual_slot":state.weapon})
 func enemy_event(actor,event: String) -> void:
  if enabled and event=="death":
   var key: String = str(state.level_index)+"/"+actor.id
   deaths[key] = int(deaths.get(key,0))+1
   audit(deaths[key]==1 and actor.hp==0,"death_once",{"actor":key,"count":deaths[key],"hp":actor.hp})
  super.enemy_event(actor,event)
 func _save() -> Error:
  if enabled and recordless: audit(state.discoveries.is_empty(),"recordless_before_save",{"discoveries":state.discoveries.duplicate()})
  var result: Error = super._save()
  if enabled:
   audit(budget()==ledger,"save_resource_conservation",{"expected":ledger,"actual":budget()})
   if result==OK:
    saves += 1
    var reload = Campaign.new()
    audit(reload.load_progress(progress_path) and not FileAccess.file_exists(progress_path+".tmp"),"atomic_saved_codec",{"path":progress_path})
    if recordless: audit(reload.discoveries.is_empty(),"recordless_saved_codec",{"discoveries":reload.discoveries.duplicate()})
    if ledger_ok:
     for field in ledger: audit(reload.get(field)==ledger[field],"saved_resource_field",{"field":field,"expected":ledger[field],"actual":reload.get(field)})
  return result
var game
var failures = 0
var difficulty = 1
var seal_order = ["blood","ivory"]
var stop_after = 8
var diagnostic_stagnation_stop = false
var no_records = false
var resume07 = false
var resume_heart08 = false
var resume_provenance: Dictionary = {}
var weapon_branches: Array = []
var precommit_branches: Array = []
var output: String
var prefix: String
var source_hashes: Dictionary = {}
var reports: Array = []
var map_start_ticks = 0
var map_start_us = 0
var total_steps = 0
var distance = 0.0
var visited: Array = []
var phase_label = "startup"
var recording: WeakRef
var last_steer: Dictionary = {}
var detour_records: Array = []
func _initialize() -> void:
 AudioServer.set_bus_mute(0,true)
 call_deferred("run")
func check(ok: bool,message: String) -> bool:
 if not ok:
  failures += 1
  push_error("EARNED_V2 "+phase_label+": "+message)
 return ok
func release() -> void:
 for action in MOVES+["fire","interact"]:
  if InputMap.has_action(action): Input.action_release(action)
func action(name: String,pressed: bool) -> void:
 if pressed and name.begins_with("weapon_") and is_instance_valid(game) and game.enabled:
  game.note("weapon_request",{"action":name,"before_weapon":game.state.weapon,"repeat_weapon":game.player._repeat_weapon})
 var event = InputEventAction.new()
 event.action = name
 event.pressed = pressed
 Input.parse_input_event(event)
func aim(point: Vector3) -> void:
 var heading: Vector3 = point-game.player.camera.global_position
 var yaw: float = atan2(-heading.x,-heading.z)
 var pitch: float = atan2(heading.y,Vector2(heading.x,heading.z).length())
 var event = InputEventMouseMotion.new()
 event.screen_relative = Vector2(-wrapf(yaw-game.player.rotation.y,-PI,PI),game.player.camera.rotation.x-pitch)/(game.settings.sensitivity*.002)
 event.relative = event.screen_relative
 Input.parse_input_event(event)
 Input.flush_buffered_events()
func identity() -> Dictionary:
 var result: Dictionary = {}
 var pending: Array[String] = []
 for name in RUNTIME: pending.append("res://scripts/"+name+".gd")
 var imports = RegEx.new()
 imports.compile("(?:preload|load)\\(\"([^\"]+\\.gd)\"\\)")
 while not pending.is_empty() and result.size()<128:
  var path: String = pending.pop_front()
  if result.has(path): continue
  result[path] = FileAccess.get_sha256(path)
  var code: String = FileAccess.get_file_as_string(path)
  for found in imports.search_all(code):
   var target: String = found.get_string(1)
   if not target.begins_with("res://"): target = path.get_base_dir().path_join(target).simplify_path()
   if not result.has(target) and not pending.has(target): pending.append(target)
 if not pending.is_empty(): result["dependency_bound_exceeded"] = ""
 for path in preload("res://scripts/level_data.gd").FILES: result["data/"+path+".json"] = FileAccess.get_sha256("res://data/"+path+".json")
 for kind in ["worker","crawler","caster","brute","guardian","summoner","nursery_warden","choir_avatar"]:
  result["sprites/"+kind] = FileAccess.get_sha256("res://assets/art/sprites/"+kind+".png")
 return result

func menu(label: String) -> bool:
 for node in game.menu.get_children():
  if node is Button and node.text==label:
   node.pressed.emit()
   return true
 return check(false,"Actual menu callback missing: "+label)
func step(require_live: bool = true) -> bool:
 var before: Vector3 = game.player.position if is_instance_valid(game.player) else Vector3.ZERO
 await physics_frame
 await process_frame
 total_steps += 1
 if is_instance_valid(game.player): distance += before.distance_to(game.player.position)
 if no_records and not check(game.state.discoveries.is_empty(),"Recordless route must never acquire any optional record"): return false
 if not check(game.ledger_ok,"Exact finite pickup/hurt/accepted-shot/death/save ledger"): return false
 if game.enabled and game.playing:
  if not check(game.budget()==game.ledger,"Resources changed outside independently observed production mutation"): return false
  if not check(game.state.weapon in game.state.owned_weapons and game.state.difficulty==difficulty and game.player.is_physics_processing(),"Carried owned weapon/difficulty and automatic Player physics retained"): return false
  if not check(game.enemies.all(func(actor): return not is_instance_valid(actor) or actor.hp<=0 or actor.is_physics_processing()),"Every living original/summoned actor keeps automatic AI physics"): return false
 if require_live and not check(game.playing and not paused and game.state.health>0,"Actual player survived; no silent restore/refund/resume"): return false
 if not check(total_steps<=GLOBAL_TICKS,"Global finite288000step bound"): return false
 if map_start_us>0 and not check(game.ticks-map_start_ticks<=MAP_TICKS and Time.get_ticks_usec()-map_start_us<=MAP_SECONDS*1000000,"Per-map finite36000tick/600s bound"): return false
 if total_steps%600==0: print("EARNED_V2_PROGRESS ",JSON.stringify({"map":game.state.level_index,"phase":phase_label,"ticks":game.ticks,"position":str(game.player.position) if is_instance_valid(game.player) else "retired","resources":game.budget(),"shots":game.shots,"deaths":game.deaths.size()}))
 return true
func entry() -> bool:
 if no_records and not check(game.state.discoveries.is_empty(),"Recordless entry/Continue carries EMPTY discoveries"): return false
 for tick in range(180):
  if game.playing and not game.placement_pending and is_instance_valid(game.player): break
  if not await step(false): return false
 var expected_floor_revision = 3 if game.state.level_index==5 else 2
 if not check(game.playing and game.level.layout.floor_revision()==expected_floor_revision,"Actual explicit per-map floor revision entry ready"): return false
 var route = game.level.get_node("NavigationRoutes")
 for tick in range(180):
  if route.is_ready("worker"): break
  if not await step(): return false
 return check(route.is_ready("worker"),"Actual native route published within180ticks")
func visible_target() -> Dictionary:
 var candidates: Array = game.enemies.filter(func(a): return is_instance_valid(a) and a._current_map() and a.hp>0 and a.active and a.position.distance_to(game.player.position)<100)
 candidates.sort_custom(func(a,b): return a.position.distance_squared_to(game.player.position)<b.position.distance_squared_to(game.player.position))
 var origin: Vector3 = game.player.camera.global_position
 var excluded: Array[RID] = [game.player.get_rid()]
 for index in range(mini(4,candidates.size())):
  var actor = candidates[index]
  var points = game.SpriteHitQuery.candidate_points(actor,game.player.camera,origin)
  for point_index in range(mini(3,points.size())):
   var point: Vector3 = points[point_index]
   var hit = game.SpriteHitQuery.cast(game.get_world_3d().direct_space_state,origin,origin+(point-origin).normalized()*140,game.player.camera,game.enemies,excluded,5)
   if hit.get("collider")==actor: return {"actor":actor,"point":point}
 return {}
func stagnation_diagnostic(cell: Array,goal: Vector3,path: PackedVector3Array,waypoint: int,stagnant: int) -> void:
 var observer = game.player
 var points: Array = []
 for index in range(mini(64,path.size())): points.append(str(path[index]))
 # Emit essential pose BEFORE optional detail so any later diagnostic error cannot hide it.
 print("EARNED_V2_STAGNANT_POSE ",JSON.stringify({"cell":cell,"goal":str(goal),"position":str(observer.position),"velocity":str(observer.velocity),"grounded":observer.is_on_floor(),"yaw":observer.rotation.y,"input_vector":str(Input.get_vector("move_left","move_right","move_forward","move_back")),"stagnant_ticks":stagnant,"waypoint_index":waypoint,"next_waypoint":str(path[waypoint]) if waypoint<path.size() else "none","path_points":points,"steer":last_steer}))
 var collisions: Array = []
 for index in range(mini(8,observer.get_slide_collision_count())):
  var collision: KinematicCollision3D = observer.get_slide_collision(index)
  var collider = collision.get_collider()
  var row: Dictionary = {"normal":str(collision.get_normal()),"position":str(collision.get_position()),"depth":collision.get_depth(),"collider":str(collider.get_path()) if collider is Node else str(collider)}
  if collider is CollisionObject3D:
   var shape_node = collider.shape_owner_get_owner(collider.shape_find_owner(collision.get_collider_shape_index()))
   if shape_node is CollisionShape3D:
    row["shape"] = shape_node.shape.get_class()
    row["shape_transform"] = str(shape_node.global_transform)
    if shape_node.shape is BoxShape3D:
     var size: Vector3 = shape_node.shape.size
     row["world_aabb"] = str(shape_node.global_transform*AABB(-size*.5,size))
    if shape_node.shape is CapsuleShape3D:
     row["radius"] = shape_node.shape.radius
     row["height"] = shape_node.shape.height
  collisions.append(row)
 var floor_ray = PhysicsRayQueryParameters3D.create(observer.position+Vector3.UP*.25,observer.position-Vector3.UP*.75,1)
 var floor_hit = game.get_world_3d().direct_space_state.intersect_ray(floor_ray)
 print("EARNED_V2_STAGNANT_GEOMETRY ",JSON.stringify({"goal_authored_floor":str(game.level.layout.world_position(cell)),"current_capsule_support":game.level.layout.capsule_floor_support(Vector2(observer.position.x,observer.position.z),observer.get_child(0).shape.radius),"floor_position":str(floor_hit.get("position",Vector3.INF)),"floor_normal":str(floor_hit.get("normal",Vector3.ZERO)),"slides":collisions}))

func navigation_diagnostic(routes,goal: Vector3,before: Dictionary) -> void:
 var row: Dictionary = {"before_request":before,"after_queries":routes._queries,"after_query_tick":routes._query_tick,"physics_frame":Engine.get_physics_frames(),"ready":routes.is_ready("worker"),"actual_position":str(game.player.position),"goal":str(goal)}
 print("EARNED_V2_NAV_ADMISSION ",JSON.stringify(row))
 var role: Dictionary = routes._roles.get("worker",{})
 if role.has("map"):
  var map: RID = role.map
  var start: Vector3 = game.player.position
  var nearest_start: Vector3 = NavigationServer3D.map_get_closest_point(map,start)
  var nearest_goal: Vector3 = NavigationServer3D.map_get_closest_point(map,goal)
  var native: PackedVector3Array = NavigationServer3D.map_get_path(map,nearest_start,nearest_goal,true,1)
  var points: Array = []
  for index in range(mini(64,native.size())): points.append(str(native[index]))
  print("EARNED_V2_NAV_PROJECTION ",JSON.stringify({"start_closest":str(nearest_start),"goal_closest":str(nearest_goal),"start_distance":start.distance_to(nearest_start),"goal_distance":goal.distance_to(nearest_goal),"start_owner":str(NavigationServer3D.map_get_closest_point_owner(map,start)),"goal_owner":str(NavigationServer3D.map_get_closest_point_owner(map,goal)),"profile":role.profile,"native_path_points":points,"diagnostic_only_not_used_for_movement":true}))

func steer(point: Vector3,combat: bool = true) -> void:
 release()
 var direction: Vector3 = point-game.player.position
 direction.y = 0
 var target: Dictionary = visible_target() if combat else {}
 var aim_point: Vector3 = target.point if not target.is_empty() else game.player.camera.global_position+direction
 aim(aim_point)
 if not target.is_empty():
  var target_distance: float = game.player.position.distance_to(target.actor.position)
  var desired = 0
  for slot in ([3,2,1,5,4] if target_distance<8 else [1,3,4,5,2]):
   if slot in game.state.owned_weapons and game.state.ammo[slot]>0: desired=slot; break
  if desired!=game.state.weapon: action("weapon_"+str(desired+1),true); action("weapon_"+str(desired+1),false)
  if target_distance<=game.Player.WEAPONS[desired].range: action("fire",true)
 var local: Vector3 = game.player.basis.inverse()*direction.normalized()
 var dz = 0.0
 for name in MOVES: dz += InputMap.action_get_deadzone(name)/4
 var strength: float = dz+(1-dz)*minf(1,direction.length()*6/9)
 for pair in [["move_right",local.x],["move_left",-local.x],["move_back",local.z],["move_forward",-local.z]]:
  if pair[1]>0: Input.action_press(pair[0],pair[1]*strength)
 last_steer = {"requested_waypoint":str(point),"horizontal_direction":str(direction),"aim_point":str(aim_point),"target":target.actor.id if not target.is_empty() else "none","local_axes":str(local),"strength":strength,"yaw_after_input":game.player.rotation.y}
func dormant_blocker(toward: Vector3):
 var origin: Vector3 = game.player.position
 var segment = Vector2(toward.x-origin.x,toward.z-origin.z)
 for index in range(game.player.get_slide_collision_count()):
  var body = game.player.get_slide_collision(index).get_collider()
  if is_instance_valid(body) and body in game.enemies and body.hp>0 and not body.active: return body
 if segment.length_squared()<.000001: return null
 var player_shape: CollisionShape3D = game.player.get_child(0)
 for body in game.enemies:
  if not is_instance_valid(body) or not body._current_map() or body.hp<=0 or body.active or (body.collision_layer&4)==0: continue
  if body.position.distance_to(origin)>3: continue
  var shape: CollisionShape3D = body.get_child(0)
  if not shape.shape is CapsuleShape3D: continue
  var offset = Vector2(body.position.x-origin.x,body.position.z-origin.z)
  var projection: float = offset.dot(segment)/segment.length_squared()
  var closest = segment*clampf(projection,0,1)
  if projection>=0 and projection<=1.5 and offset.distance_to(closest)<player_shape.shape.radius+shape.shape.radius+.15: return body
 return null

func detour_segment_clear(a: Vector3,b: Vector3) -> bool:
 var collider: CollisionShape3D = game.player.get_child(0)
 var samples: int = maxi(1,ceili(Vector2(b.x-a.x,b.z-a.z).length()/.12))
 if samples>40: return false # Local obstacle avoidance, never a long shortcut.
 var query = PhysicsShapeQueryParameters3D.new()
 query.shape = collider.shape # SAME production shape/radius, no test-sized capsule.
 query.collision_mask = game.player.collision_mask
 query.exclude = [game.player.get_rid()] # Dormant NPCs are NOT excluded.
 for index in range(1,samples+1):
  var point: Vector3 = a.lerp(b,float(index)/samples)
  var cell = Vector2(point.x,point.z)/float(game.level.layout.data.cell_size)
  if not game.level.layout.is_walkable(Vector2i(floori(cell.x),floori(cell.y))): return false
  var support: float = game.level.layout.capsule_floor_support(Vector2(point.x,point.z),collider.shape.radius)
  if not is_finite(support): return false
  var pose: Transform3D = game.player.global_transform
  pose.origin = Vector3(point.x,support+.03,point.z)
  query.transform = pose*collider.transform # QUERY ONLY: never writes Player pose.
  if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
 return true

func plan_dormant_detour(body,goal: Vector3,routes) -> Dictionary:
 var frame: int = Engine.get_physics_frames()
 # At most two sides x three admitted subgoal queries. Wait a real physics tick
 # if that bounded reservation does not fit; NEVER reset/bypass service budget.
 var used: int = routes._queries if routes._query_tick==frame else 0
 if used+6>routes.MAX_QUERIES_PER_TICK: return {"defer":true}
 var player_shape: CollisionShape3D = game.player.get_child(0)
 var obstacle_shape: CollisionShape3D = body.get_child(0)
 var clearance: float = player_shape.shape.radius+obstacle_shape.shape.radius+.25
 var forward: Vector3 = goal-body.position
 forward.y = 0
 if forward.length_squared()<.01: return {} # Do not invent a replacement authored goal.
 forward = forward.normalized()
 var side = Vector3(-forward.z,0,forward.x)
 var origin: Vector3 = game.player.position
 for sign_value in [-1.0,1.0]:
  var points: Array[Vector3] = []
  for along in [-1.0,0.0,1.0]:
   var point: Vector3 = body.position+side*sign_value*clearance+forward*along*clearance
   point = game.level.layout.world_position([point.x/game.level.layout.data.cell_size,point.z/game.level.layout.data.cell_size])+Vector3.UP*.03
   points.append(point)
  var clear = true
  var previous: Vector3 = origin
  for point in points:
   if not detour_segment_clear(previous,point): clear=false; break
   var admitted: PackedVector3Array = routes.route(previous,point,"worker")
   if admitted.is_empty(): clear=false; break # Unknown{} is NOT considered retryable.
   previous = point
  if clear:
   var row: Dictionary = {"map":game.state.level_index,"actor":body.id,"actor_active":body.active,"actor_hp":body.hp,"actor_position":str(body.position),"player_radius":player_shape.shape.radius,"actor_radius":obstacle_shape.shape.radius,"planned_clearance":clearance,"side":sign_value,"points":[str(points[0]),str(points[1]),str(points[2])],"authored_goal_unchanged":str(goal),"budget_used_before":used,"budget_used_after":routes._queries}
   detour_records.append(row)
   print("EARNED_V2_DYNAMIC_DETOUR ",JSON.stringify(row))
   return {"points":points}
 return {}

func walk(cell: Array,cap: int = HOP_TICKS) -> bool:
 var goal: Vector3 = game.level.layout.world_position(cell)+Vector3.UP*.03
 var routes = game.level.get_node("NavigationRoutes")
 for wait in range(180):
  if routes.is_ready("worker"): break
  if not await step(): return false
 var path: PackedVector3Array = []
 var waypoint = 0
 var stagnant = 0
 var previous_position: Vector3 = game.player.position
 var query_before: Dictionary = {}
 var detour: Array[Vector3] = []
 var detour_attempts = 0
 var blocked_id = ""
 for tick in range(cap):
  if Vector2(game.player.position.x-goal.x,game.player.position.z-goal.z).length()<.65:
   release()
   visited.append(cell.duplicate())
   return true
  if tick%30==0 or waypoint>=path.size():
   query_before = {"queries":routes._queries,"query_tick":routes._query_tick,"physics_frame":Engine.get_physics_frames()}
   path = routes.route(game.player.position,goal,"worker")
   waypoint = 1 if path.size()>1 else 0
  if path.is_empty():
   print("EARNED_V2_ROUTE_RED ",JSON.stringify({"cell":cell,"position":str(game.player.position),"goal":str(goal),"velocity":str(game.player.velocity),"grounded":game.player.is_on_floor(),"ready":routes.is_ready("worker")}))
   navigation_diagnostic(routes,goal,query_before)
   stagnation_diagnostic(cell,goal,path,waypoint,stagnant)
   return check(false,"Actual authored waypoint has no native route; no fallback endpoint/radius change")
  while waypoint<path.size()-1 and game.player.position.distance_to(path[waypoint])<.7: waypoint += 1
  if detour.is_empty():
   var blocker = dormant_blocker(path[waypoint])
   if blocker!=null and blocker.id!=blocked_id:
    var planned: Dictionary = plan_dormant_detour(blocker,goal,routes)
    if planned.get("defer",false):
     release()
     if not await step(): return false
     continue # Same finite hop/map clocks; no generic empty-path retry.
    blocked_id = blocker.id
    detour_attempts += 1
    if not check(detour_attempts<=8 and detour_records.size()<=256,"Finite local detour planning bound"): return false
    if planned.has("points"): detour = planned.points
  if not detour.is_empty():
   while not detour.is_empty() and Vector2(game.player.position.x-detour[0].x,game.player.position.z-detour[0].z).length()<.18: detour.pop_front()
   if detour.is_empty():
    path = PackedVector3Array()
    waypoint = 0
    blocked_id = ""
    continue # Recompute ORIGINAL authored goal after physical dogleg, no skip.
   steer(detour[0],false) # No attack/activation of dormant blocker; all AI still runs.
  else: steer(path[waypoint])
  if not await step(): return false
  stagnant = stagnant+1 if game.player.position.distance_to(previous_position)<.005 else 0
  previous_position = game.player.position
  if stagnant in [120,600,1200]: stagnation_diagnostic(cell,goal,path,waypoint,stagnant)
  if stagnant==120 and diagnostic_stagnation_stop:
   return check(false,"Requested diagnostic-only stop after first stagnation snapshot; default1800hop bound unchanged, no earned acceptance")
 stagnation_diagnostic(cell,goal,path,waypoint,stagnant)
 return check(false,"Hop1800tick cap at "+str(game.player.position)+" target="+str(cell))
func use(spec: Dictionary) -> bool:
 release()
 aim(game.level.layout.world_position(spec.cell)+Vector3.UP*(float(spec.size[1])*.5 if spec.has("size") else .7))
 action("interact",true)
 if not await step(false): return false
 action("interact",false)
 return await step(false)
func supplies_near() -> bool:
 var options: Array = []
 for spec in game.level.layout.data.pickups:
  if spec.id in game.state.removed: continue
  var wanted = (spec.kind=="health" and game.state.health<85) or (spec.kind=="armor" and game.state.armor<100)
  if spec.kind in ["weapon","ammo"]:
   var slot: int = spec.weapon
   wanted = (spec.kind=="weapon" and not slot in game.state.owned_weapons) or game.state.ammo[slot]<game.Player.WEAPONS[slot].max_ammo*.6
  var point: Vector3 = game.level.layout.world_position(spec.cell)
  if wanted and point.distance_to(game.player.position)<14: options.append(spec)
 options.sort_custom(func(a,b): return game.level.layout.world_position(a.cell).distance_squared_to(game.player.position)<game.level.layout.world_position(b.cell).distance_squared_to(game.player.position))
 for spec in options:
  var routes = game.level.get_node("NavigationRoutes")
  var goal: Vector3 = game.level.layout.world_position(spec.cell)+Vector3.UP*.03
  if routes.route(game.player.position,goal,"worker").is_empty(): continue # Optional supply beyond closed geometry is not granted or required.
  if not await walk(spec.cell,900): return false
 return true
func weapon_pickup_branches(anchor: Array,require_all: bool) -> bool:
 var prior_phase: String = phase_label
 var candidates: Array = game.level.layout.data.pickups.filter(func(row): return row.kind=="weapon" and not int(row.weapon) in game.state.owned_weapons)
 for spec in candidates:
  if int(spec.weapon) in game.state.owned_weapons: continue
  var routes = game.level.get_node("NavigationRoutes")
  var goal: Vector3 = game.level.layout.world_position(spec.cell)+Vector3.UP*.03
  # Reserve only this actual service query. Waiting consumes the SAME normal clocks.
  for wait in range(60):
   if routes._query_tick!=Engine.get_physics_frames() or routes._queries<routes.MAX_QUERIES_PER_TICK: break
   release()
   if not await step(): return false
  var admitted: PackedVector3Array = routes.route(game.player.position,goal,"worker")
  if admitted.is_empty():
   if require_all:
    navigation_diagnostic(routes,goal,{"weapon":spec.id,"required_after_seals":true})
    return check(false,"Required unowned authored weapon unreachable after seals; no grant/drop: "+spec.id)
   # Defer ONLY while an actual unopened authored seal-locked door exists.
   var locked: bool = game.level.layout.data.doors.any(func(door): return not door.id in game.state.removed and not game._has_keys(door.get("requires",[])))
   if not check(locked,"Unreachable weapon is not explained by an actual seal-locked door: "+spec.id): return false
   print("EARNED_V2_WEAPON_DEFER ",spec.id)
   continue
  phase_label = game.level.layout.data.id+"/weapon_branch/"+spec.id
  var before: Dictionary = game.budget()
  if not await walk(spec.cell,900): return false
  for tick in range(30):
   if spec.id in game.state.removed and int(spec.weapon) in game.state.owned_weapons: break
   release()
   if not await step(): return false
  if not check(spec.id in game.state.removed and int(spec.weapon) in game.state.owned_weapons and game.consumed.get(str(game.state.level_index)+"/"+spec.id,0)==1,"Actual proximity earns weapon exactly once through independent pickup ledger: "+spec.id): return false
  weapon_branches.append({"map":game.state.level_index,"id":spec.id,"authored_cell":spec.cell,"return_anchor":anchor,"before":before,"after":game.budget()})
  if not await walk(anchor): return false
  phase_label = prior_phase
 return true

func resume07_preconditions() -> bool:
 var expected_save: String = RESUME08_HEART_SAVE_SHA if resume_heart08 else RESUME07_SAVE_SHA
 var expected_manifest: String = RESUME08_HEART_MANIFEST_SHA if resume_heart08 else RESUME07_MANIFEST_SHA
 var path: String = OS.get_environment("NULL_CHOIR_EARNED_V2_RESUME07_SAVE")
 var manifest_path: String = OS.get_environment("NULL_CHOIR_EARNED_V2_RESUME07_SOURCES")
 if not check(FileAccess.get_sha256(path)==expected_save and FileAccess.get_sha256(manifest_path)==expected_manifest,"Exact retained earned checkpoint and immutable43file manifest required"): return false
 var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
 if not check(manifest is Dictionary and manifest.size()==43,"Retained source manifest has43 baseline inputs"): return false
 var checked = 0
 for name in manifest:
  if name=="tests/test_campaign_earned_v2.gd": continue # This authorized controller-only revision is separately bound.
  if not check(FileAccess.get_sha256("res://"+name)==manifest[name],"Retained noncontroller baseline input unchanged: "+name): return false
  checked += 1
 var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
 var file = FileAccess.open(prefix+"_campaign.json",FileAccess.WRITE)
 if not check(file!=null,"Own isolated checkpoint-continuation profile can be staged"): return false
 file.store_buffer(original)
 file.close()
 if not check(FileAccess.get_sha256(prefix+"_campaign.json")==expected_save,"Only exact real earned checkpoint bytes staged; no resource/actor rewriting"): return false
 var evidence = FileAccess.open(output+"/resume-input-original.json",FileAccess.WRITE)
 if not check(evidence!=null,"Own immutable resume-input receipt writable"): return false
 evidence.store_buffer(original)
 evidence.close()
 resume_provenance = {"source_attempt":"08 Heart" if resume_heart08 else "07 Nursery","actual_input_save_sha256":expected_save,"actual_source_manifest_sha256":expected_manifest,"noncontroller_files_exact":checked,"prior_outcomes":"07 Nursery death;08 Heart aggregate ledgerRED, neither retroactively passed/refunded","prior_completed_maps_not_counted_as_new":[0,1,2,3,4,5,6] if resume_heart08 else [0,1,2,3],"new_scope":"Exact earned checkpoint recovery onward, NOT a fresh single-attempt full8 pass"}
 return true

func resume07_run() -> bool:
 var index: int = 7 if resume_heart08 else 4
 var checkpoint_id: String = "heart_checkpoint" if resume_heart08 else "nursery_checkpoint"
 var expected = Campaign.new()
 if not check(expected.load_progress(game.progress_path) and expected.level_index==index and expected.floor_revision==2 and expected.difficulty==1 and expected.checkpoint_id==checkpoint_id and expected.keys==["blood","ivory"] and expected.discoveries==range(index+1),"Actual earned Nursery checkpoint retains exact version/difficulty/seals/records"): return false
 game.ledger = {"health":expected.health,"armor":expected.armor,"ammo":expected.ammo.duplicate(),"owned_weapons":expected.owned_weapons.duplicate()}
 game.enabled = true
 if not menu("Continue"): return false
 # Synchronous actual title callback loads the original state before automatic physics.
 for field in ["health","armor","ammo","owned_weapons","keys","discoveries","actors","position","yaw","pitch"]:
  if not check(game.state.get(field)==expected.get(field),"Actual Title Continue original input field before physics: "+field): return false
 if not await entry(): return false
 map_start_ticks = game.ticks
 map_start_us = Time.get_ticks_usec()
 visited = []
 var data: Dictionary = game.level.layout.data
 var checkpoint: Dictionary = data.interactions.filter(func(row): return row.id==checkpoint_id)[0]
 phase_label = data.id+"/earned_checkpoint_recovery"
 if not await weapon_pickup_branches(checkpoint.cell,true): return false
 # Real player SAVE after actual weapon branch, never change checkpoint resources directly.
 if not await checkpoint_roundtrip(index,checkpoint): return false
 if not await map_commitment(index,data,[],true): return false
 for next_index in range(index+1,8):
  if not await map_run(next_index): return false
 return true

func map_run(index: int) -> bool:
 phase_label = "entry"+str(index)
 if not await entry(): return false
 map_start_ticks = game.ticks
 map_start_us = Time.get_ticks_usec()
 visited = []
 var data: Dictionary = game.level.layout.data
 if not check(game.state.level_index==index and game.state.keys.is_empty() and data.loops.size()==2 and data.heroes.size()==2,"Actual new map has two authored exploration loops/heroes, no inherited seals"): return false
 var actor_ids: Array = game.enemies.map(func(a): return a.id)
 var authored_ids: Array = data.enemies.map(func(a): return a.id)
 actor_ids.sort(); authored_ids.sort()
 if not check(actor_ids==authored_ids,"All original authored actors live in actual scene; no omission/freeze"): return false
 if not await weapon_pickup_branches(data.spawn,false): return false
 var loop_ids: Array = []
 for seal in seal_order:
  var hero: Dictionary = data.heroes.filter(func(row): return row.get("seal","")==seal)[0]
  var loop: Dictionary = data.loops.filter(func(row): return row.hero==hero.id)[0]
  phase_label = data.id+"/"+loop.id
  var key: Dictionary = data.interactions.filter(func(row): return row.kind=="key" and row.key==seal)[0]
  # A seal's RETURN actors deliberately stay dormant until that seal is earned.
  # Walk its actual key branch from the nearest outbound authored waypoint,
  # return to that SAME waypoint, then finish every original loop waypoint.
  var outbound_end: int = loop.route.size()
  for point_index in range(loop.route.size()):
   var cell: Array = loop.route[point_index]
   for encounter in data.encounters:
    var required: Array = encounter.get("requires",[])
    var region: Array = encounter.region
    if required.size()==1 and required[0]==seal and cell[0]>=region[0] and cell[0]<=region[2] and cell[1]>=region[1] and cell[1]<=region[3]: outbound_end = mini(outbound_end,point_index)
  if not check(outbound_end>0,"Authored loop has an outbound waypoint before single-seal return region"): return false
  var anchor = 0
  var nearest = INF
  for point_index in range(outbound_end):
   var point: Array = loop.route[point_index]
   var separation: float = Vector2(point[0]-key.cell[0],point[1]-key.cell[1]).length_squared()
   if separation<nearest: nearest=separation; anchor=point_index
  var key_collected = false
  for point_index in range(loop.route.size()):
   var cell: Array = loop.route[point_index]
   if not await supplies_near() or not await walk(cell): return false
   if point_index==anchor:
    phase_label = data.id+"/"+loop.id+"/outbound_key_branch"
    if not await walk(key.cell) or not await use(key): return false
    if not check(seal in game.state.keys and key.id in game.state.removed,"Actual E earns authored seal BEFORE its return encounter: "+seal): return false
    key_collected = true
    if not await walk(cell): return false
    phase_label = data.id+"/"+loop.id+"/earned_return"
  if not check(key_collected,"Actual key branch and all authored loop waypoints completed"): return false
  loop_ids.append(loop.id)
 phase_label = data.id+"/record"
 var story: Dictionary = data.interactions.filter(func(row): return row.kind=="story")[0]
 if no_records:
  phase_label = data.id+"/optional_record_deliberately_skipped"
  if not check(game.state.discoveries.is_empty() and not story.id in game.state.removed,"Actual player chooses not to E optional record"): return false
  if not await weapon_pickup_branches(data.spawn,true): return false
 else:
  if not await walk(story.cell) or not await use(story): return false
  if not check(index in game.state.discoveries and story.id in game.state.removed,"Actual optional record recovered by E"): return false
  if not await weapon_pickup_branches(story.cell,true): return false
 phase_label = data.id+"/checkpoint"
 var checkpoint: Dictionary = data.interactions.filter(func(row): return row.kind=="checkpoint")[0]
 if not await walk(checkpoint.cell): return false
 for tick in range(60):
  if game.state.checkpoint_id==checkpoint.id: break
  if not await step(): return false
 if not check(game.state.checkpoint_id==checkpoint.id and game.saves>0,"Actual automatic checkpoint saved before commitment"): return false
 if not await checkpoint_roundtrip(index,checkpoint): return false
 return await map_commitment(index,data,loop_ids,false)

func precommit_wanted(spec: Dictionary) -> bool:
 if spec.id in game.state.removed: return false
 match spec.kind:
  "health": return game.state.health<100
  "armor": return game.state.armor<200
  "ammo", "weapon":
   var slot: int = int(spec.weapon)
   return (spec.kind=="weapon" and not slot in game.state.owned_weapons) or game.state.ammo[slot]<game.Player.WEAPONS[slot].max_ammo
 return false

func precommit_resupply(checkpoint: Dictionary) -> bool:
 # Purpose-authored nearby boss supplies are real player choices, not scripted
 # resources. Stock below existing caps BEFORE Save/Continue; AI stays live.
 var prior_phase: String = phase_label
 var checkpoint_world: Vector3 = game.level.layout.world_position(checkpoint.cell)
 var options: Array = game.level.layout.data.pickups.filter(func(spec): return precommit_wanted(spec) and game.level.layout.world_position(spec.cell).distance_to(checkpoint_world)<=14.0)
 options.sort_custom(func(a,b):
  var a_health: bool = a.kind=="health"
  var b_health: bool = b.kind=="health"
  if a_health!=b_health: return a_health
  return game.level.layout.world_position(a.cell).distance_squared_to(checkpoint_world)<game.level.layout.world_position(b.cell).distance_squared_to(checkpoint_world))
 if not check(options.size()<=game.level.layout.data.pickups.size(),"Finite authored precommit candidate set"): return false
 for spec in options:
  if not precommit_wanted(spec): continue # Another REAL pickup may have filled its cap.
  phase_label = game.level.layout.data.id+"/precommit_resupply/"+spec.id
  var routes = game.level.get_node("NavigationRoutes")
  var goal: Vector3 = game.level.layout.world_position(spec.cell)+Vector3.UP*.03
  for wait in range(60):
   if routes._query_tick!=Engine.get_physics_frames() or routes._queries<routes.MAX_QUERIES_PER_TICK: break
   release()
   if not await step(): return false
  if not check(routes._query_tick!=Engine.get_physics_frames() or routes._queries<routes.MAX_QUERIES_PER_TICK,"Bounded precommit query admission wait; no budget bypass or false unreachable label"): return false
  var before_query: Dictionary = {"queries":routes._queries,"query_tick":routes._query_tick,"physics_frame":Engine.get_physics_frames(),"optional_supply":spec.id}
  var admitted: PackedVector3Array = routes.route(game.player.position,goal,"worker")
  if admitted.is_empty():
   # Optional does not mean granted or coerced: retain exact target, record why,
   # and leave inaccessible stock untouched. Never classify unknown{} as busy.
   navigation_diagnostic(routes,goal,before_query)
   precommit_branches.append({"map":game.state.level_index,"id":spec.id,"authored_cell":spec.cell,"outcome":"unreachable_untouched","return_checkpoint":checkpoint.cell})
   continue
  var before_budget: Dictionary = game.budget()
  if not await walk(spec.cell,900): return false
  for tick in range(30):
   if spec.id in game.state.removed or not precommit_wanted(spec): break
   release()
   if not await step(): return false
  var consumed: bool = spec.id in game.state.removed
  if not check(consumed or not precommit_wanted(spec),"Reachable wanted supply must be acquired by native proximity or genuinely capped: "+spec.id): return false
  if consumed and not check(game.consumed.get(str(game.state.level_index)+"/"+spec.id,0)==1,"Precommit native pickup consumes its actual ID exactly once: "+spec.id): return false
  if not check(game.ledger_ok and game.budget()==game.ledger and game.state.health>0 and game.state.health<=100 and game.state.armor>=0 and game.state.armor<=200,"Independent actual pickup/hurt ledger and unchanged health/armor caps"): return false
  for slot in range(1,6):
   if not check(game.state.ammo[slot]>=0 and game.state.ammo[slot]<=game.Player.WEAPONS[slot].max_ammo,"Precommit actual ammo remains inside original weapon cap"): return false
  var row: Dictionary = {"map":game.state.level_index,"id":spec.id,"authored_cell":spec.cell,"outcome":"actual_once_only_pickup" if consumed else "capped_without_consuming","before":before_budget,"after":game.budget(),"return_checkpoint":checkpoint.cell}
  if not await walk(checkpoint.cell): return false
  row["returned_actual_checkpoint"] = true
  precommit_branches.append(row)
  print("EARNED_V2_PRECOMMIT_SUPPLY ",JSON.stringify(row))
 phase_label = prior_phase
 return true

func checkpoint_roundtrip(index: int,checkpoint: Dictionary) -> bool:
 if not await precommit_resupply(checkpoint): return false
 game.pause_game() # Actual menu callback, not Player/resource movement.
 if not menu("Save and return to title"): return false
 await process_frame
 await process_frame
 var bytes: PackedByteArray = FileAccess.get_file_as_bytes(game.progress_path)
 var digest: String = FileAccess.get_sha256(game.progress_path)
 var reload = Campaign.new()
 if not check(reload.load_progress(game.progress_path) and reload.level_index==index and reload.checkpoint_id==checkpoint.id,"Actual atomic disk image independently loads checkpoint"): return false
 if no_records and not check(reload.discoveries.is_empty(),"Recordless saved checkpoint contains EMPTY discoveries"): return false
 if not menu("Continue") or not await entry(): return false
 if not check(FileAccess.get_file_as_bytes(game.progress_path)==bytes and FileAccess.get_sha256(game.progress_path)==digest and game.state.keys==reload.keys and game.state.discoveries==reload.discoveries,"Title Continue preserves original disk bytes/keys/records and finite resources"): return false
 return true

func map_commitment(index: int,data: Dictionary,loop_ids: Array,from_checkpoint: bool) -> bool:
 for door in data.doors:
  phase_label = data.id+"/gate/"+door.id
  # Door normal is authored yaw; approach from the already-visited checkpoint side.
  var centre: Vector3 = game.level.layout.world_position(door.cell)
  var offset: Vector3 = game.player.position-centre
  offset.y = 0
  var approach: Vector3 = centre+offset.normalized()*2
  var cell = [approach.x/data.cell_size,approach.z/data.cell_size]
  if not await walk(cell) or not await use(door): return false
  if not check(door.id in game.state.removed,"Actual two-seal gate opened via E"): return false
 var exit: Dictionary = data.interactions.filter(func(row): return row.kind=="exit")[0]
 phase_label = data.id+"/finale"
 # Exit route enters actual encounter regions; bosses must die through native fire.
 if not await walk(exit.cell,5400): return false
 for tick in range(5400):
  var needed: Array = exit.get("requires_defeated",[])
  if needed.all(func(id): return id in game.state.removed): break
  var finales: Array = data.encounters.filter(func(row): return row.get("requires",[]).has("blood") and row.get("requires",[]).has("ivory"))
  if not check(not finales.is_empty(),"Boss gate retains authored finale region"): return false
  var region: Array = finales[0].region
  var corner: Array = [region[0]+.8,region[1]+.8] if (tick/180)%2==0 else [region[2]-.8,region[3]-.8]
  steer(game.level.layout.world_position(corner))
  if not await step(): return false
 if not check(exit.get("requires_defeated",[]).all(func(id): return id in game.state.removed),"Actual boss-gated exit earned by native death, not direct damage"): return false
 if not await walk(exit.cell) or not await use(exit): return false
 if not check(game.state.level_index==index+1 and not game.playing,"Actual E exit advances one map after earned seals/defeats"): return false
 var disk = Campaign.new()
 if no_records:
  if not check(disk.load_progress(game.progress_path) and disk.level_index==index+1 and disk.discoveries.is_empty() and game.state.discoveries.is_empty(),"Recordless actual exit atomically carries EMPTY discoveries"): return false
 else:
  if not check(disk.load_progress(game.progress_path) and disk.level_index==index+1 and disk.discoveries==range(index+1),"Exit atomically carries exact records to next index"): return false
 for field in game.ledger:
  if not check(disk.get(field)==game.ledger[field],"Actual exit disk finite carry: "+field): return false
 reports.append({"map":index,"id":data.id,"loops":loop_ids,"checkpoint_continuation_only":from_checkpoint,"authored_waypoints_visited":visited.size(),"ticks":game.ticks-map_start_ticks,"seconds":(Time.get_ticks_usec()-map_start_us)/1000000.0,"budget":game.budget(),"shots_total":game.shots.duplicate(),"checkpoint_saves_total":game.saves})
 map_start_us = 0
 if index<7 and index+1<stop_after:
  for button in game.menu.get_children():
   if button is Button and button.text.begins_with("Descend to "): button.pressed.emit(); return true
  return check(false,"Actual connected Descend callback exists")
 return true
func run() -> void:
 if not check(AudioServer.get_driver_name()=="Dummy" and Engine.physics_ticks_per_second==60 and Engine.time_scale==1,"Dummy/no hardware audio and unchanged60Hz required"): await finish(); return
 output = OS.get_environment("NULL_CHOIR_EARNED_V2_OUTPUT")
 if not check(not output.is_empty() and DirAccess.dir_exists_absolute(output),"Explicit existing owned evidence directory required"): await finish(); return
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--earned-v2-difficulty="): difficulty = int(arg.get_slice("=",1))
  if arg=="--earned-v2-no-records": no_records = true
  if arg=="--earned-v2-resume-nursery-07": resume07 = true
  if arg=="--earned-v2-resume-heart-08": resume07 = true; resume_heart08 = true
  if arg=="--earned-v2-stagnation-stop": diagnostic_stagnation_stop = true
  if arg=="--earned-v2-ivory-first": seal_order = ["ivory","blood"]
  if arg.begins_with("--earned-v2-stop-after="): stop_after = int(arg.get_slice("=",1))
 if not check(difficulty in [0,1,2] and stop_after>=1 and stop_after<=8,"Explicit difficulty0/1/2 and diagnostic stop1..8 only"): await finish(); return
 if not check(not no_records or (not resume07 and stop_after==8),"Recordless mode requires fresh full8 NewCampaign; incompatible with all checkpoint resumes or diagnostic partial stops"): await finish(); return
 source_hashes = identity()
 if not check(source_hashes.values().all(func(value): return value.length()==64),"Current runtime/map source identity readable; no oldv1SHA repins"): await finish(); return
 prefix = "user://campaign_earned_v2_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
 if resume07:
  if not check(difficulty==1 and seal_order==["blood","ivory"] and stop_after==8,"Explicit actual07 continuation only: originalRelentlessBloodfirst/fullremainingchain"): await finish(); return
  if not resume07_preconditions(): await finish(); return
 game = EarnedMain.new()
 game.recordless = no_records
 game.settings_path = prefix+"_preferences.json"
 game.progress_path = prefix+"_campaign.json"
 root.add_child(game)
 game.settings.head_bob = false
 game.settings.camera_shake = false
 if resume07:
  if not await resume07_run(): await finish(); return
 else:
  if not menu("New campaign"): await finish(); return
  var label: String = ["Merciful","Relentless","Terminal"][difficulty]
  if not menu(label) or not await entry(): await finish(); return
  if not check(game.state.level_index==0 and game.state.difficulty==difficulty and game.state.health==100 and game.state.armor==0 and game.state.ammo==[0,90,0,0,0,0] and game.state.owned_weapons==[0,1] and game.state.keys.is_empty() and game.state.discoveries.is_empty(),"Genuine menu NewCampaign default state; no grants"): await finish(); return
  game.ledger = game.budget()
  game.enabled = true
  for index in range(stop_after):
   if not await map_run(index): await finish(); return
 if stop_after==8:
  phase_label = "ending"
  if no_records:
   if not check(game.state.level_index==8 and game.state.discoveries.is_empty() and game.menu.get_child(0).text=="THE RESTRAINT IS OPEN\nTHE VOICE NOW USES YOUR NAME","Fresh recordless full8 real exit selects actual normal ending"): await finish(); return
  else:
   if not check(game.state.level_index==8 and game.state.discoveries==range(8) and game.menu.get_child(0).text.begins_with("YOUR VOICE"),"All8 earned records and actual final exit select intended complete revelation"): await finish(); return
  var bytes = FileAccess.get_file_as_bytes(game.progress_path)
  game.show_title()
  if not menu("Continue"): await finish(); return
  await process_frame
  if no_records:
   if not check(game.state.level_index==8 and not game.playing and game.state.discoveries.is_empty() and FileAccess.get_file_as_bytes(game.progress_path)==bytes and game.menu.get_child(0).text=="THE RESTRAINT IS OPEN\nTHE VOICE NOW USES YOUR NAME","Recordless completed disk Continue preserves EMPTY discoveries and actual normal ending"): await finish(); return
  else:
   if not check(game.state.level_index==8 and not game.playing and FileAccess.get_file_as_bytes(game.progress_path)==bytes and game.menu.get_child(0).text.begins_with("YOUR VOICE"),"Completed disk Continue preserves final budget/records/ending"): await finish(); return
 if not check(identity()==source_hashes,"Runtime+8current map source hashes unchanged across actual attempt"): await finish(); return
 await finish()
func finish() -> void:
 release()
 var result: Dictionary = {"record_mode":"none" if no_records else "all8","intended_ending":"normal" if no_records else "complete_revelation","all8_lore_claim":false,"failures":failures,"difficulty":difficulty,"seal_order":seal_order,"completed_maps":reports.size(),"requested_stop":stop_after,"diagnostic_stagnation_stop":diagnostic_stagnation_stop,"full8":not resume07 and failures==0 and reports.size()==8,"checkpoint_continuation":resume07,"resume_provenance":resume_provenance,"weapon_branches":weapon_branches,"precommit_branches":precommit_branches,"reports":reports,"source_hashes":source_hashes,"phase":phase_label,"virtual_input":true,"physical_input":false,"render":false,"listening":false,"old_v1_goldens_replaced":false,"dynamic_detours":detour_records}
 if is_instance_valid(game):
  result["live_budget"] = game.budget()
  result["finite_ledger_ok"] = game.ledger_ok
  result["first_ledger_fault"] = game.first_fault
  result["last_ledger_events"] = game.event_history
  result["shots"] = game.shots
  result["pickup_ids"] = game.consumed.keys()
  result["death_ids"] = game.deaths.keys()
  result["last_save_present"] = FileAccess.file_exists(game.progress_path)
  if result.last_save_present and not output.is_empty():
   var raw_save: PackedByteArray = FileAccess.get_file_as_bytes(game.progress_path)
   var saved = Campaign.new()
   result["last_save_codec_valid"] = saved.load_progress(game.progress_path)
   result["last_save_sha256"] = FileAccess.get_sha256(game.progress_path)
   result["last_save_bytes"] = raw_save.size()
   var evidence = FileAccess.open(output+"/last-save-raw.json",FileAccess.WRITE)
   if evidence!=null:
    evidence.store_buffer(raw_save)
    evidence.close()
    check(FileAccess.get_sha256(output+"/last-save-raw.json")==result.last_save_sha256,"Preserved exact owned save bytes/hash before profile cleanup")
   else: check(false,"Owned last-save forensic evidence writable")
  # A live-state JSON is diagnostic only, NEVER substitute it for an actual earned disk save.
  result["live_state_diagnostic_only"] = game.state.to_dict()
  game.playing = false
  if game.music.player.stream!=null: recording = weakref(game.music.player.stream)
  game.music.stop(); game.effects.stop()
  game.queue_free()
 paused = false
 await process_frame
 game = null
 var deadline: int = Time.get_ticks_usec()+2000000
 while recording!=null and recording.get_ref()!=null and Time.get_ticks_usec()<deadline:
  OS.delay_msec(2)
  await process_frame
 check(recording==null or recording.get_ref()==null,"Owned native recording releases before exit")
 for suffix in ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]:
  if not prefix.is_empty() and FileAccess.file_exists(prefix+suffix): DirAccess.remove_absolute(prefix+suffix)
 call_deferred("terminal",result)
func terminal(result: Dictionary) -> void:
 await process_frame
 await process_frame
 result.failures = failures
 result.full8 = not resume07 and failures==0 and reports.size()==8
 result.all8_lore_claim = result.full8 and not no_records
 result.continuation_completed = resume07 and failures==0 and reports.map(func(row): return row.map)==([7] if resume_heart08 else [4,5,6,7])
 if not output.is_empty():
  var file = FileAccess.open(output+"/result.json",FileAccess.WRITE)
  if file!=null: file.store_string(JSON.stringify(result,"  ")); file.close()
  else: check(false,"Owned final evidence JSON writable")
 if failures==0:
  print("PASS EARNED_V2_CHECKPOINT_CONTINUATION " if result.continuation_completed else ("PASS EARNED_V2_FULL8 " if result.full8 else "EARNED_V2_PREFIX_DIAGNOSTIC_ONLY "),JSON.stringify({"maps":reports.size(),"difficulty":difficulty,"seal_order":seal_order,"full8":result.full8}))
 quit(0 if failures==0 else 1)
