extends SceneTree
## ARRANGED finite Heart entry commitment, not earned campaign or physical input.
## Real spawn, Blood then Ivory/Return, checkpoint and finale. No route placement.
const Main = preload("res://scripts/main.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Projectile = preload("res://scripts/projectile.gd")
const MOVES = ["move_left","move_right","move_forward","move_back"]
const LIMIT = 33000
class ObservedMain:
 extends "res://scripts/main.gd"
 var spent = [0,0,0,0,0,0]
 var death_ids: Array = []
 var phases = [0,0]
 var supplies = [0,0,0,0,0,0]
 var shot_ledger_ok = true
 var shot_player_id: int = 0
 var last_shot_time = [-INF,-INF,-INF,-INF,-INF,-INF]

 func shot(slot: int) -> void:
  if shot_player_id != player.get_instance_id():
   shot_player_id = player.get_instance_id()
   last_shot_time = [-INF,-INF,-INF,-INF,-INF,-INF]
  var now: float = player.active_play_time
  shot_ledger_ok = shot_ledger_ok and now-last_shot_time[slot]>=player.WEAPONS[slot].interval-0.017
  last_shot_time[slot] = now
  spent[slot] += 1
  super.shot(slot)
 func collect_pickup(id: String) -> void:
  var before: Array = state.ammo.duplicate()
  super.collect_pickup(id)
  for slot in range(6): supplies[slot] += state.ammo[slot]-before[slot]
 func enemy_event(actor,event: String) -> void:
  if event == "death": death_ids.append(actor.id)
  if actor.id == "heart_choir_avatar" and event == "attack": phases[actor.phase] += 1
  super.enemy_event(actor,event)
var game
var failures = 0
var ticks = 0
var prefix = "user://heart_v2_commitment_"+str(OS.get_process_id())
var initial_ammo: Array
var travelled = 0.0
var projectile_samples: Dictionary = {}
var projectile_steps = 0
func _initialize() -> void:
 AudioServer.set_bus_mute(0,true)
 call_deferred("run")
func check(ok: bool,message: String) -> bool:
 if not ok:
  failures += 1
  push_error(message)
 return ok
func release() -> void:
 for action in MOVES+["fire","interact"]:
  if InputMap.has_action(action): Input.action_release(action)
func event_action(action: String,pressed: bool) -> void:
 var event = InputEventAction.new()
 event.action = action
 event.pressed = pressed
 Input.parse_input_event(event)
func aim(point: Vector3) -> void:
 var heading = point-game.player.camera.global_position
 var yaw = atan2(-heading.x,-heading.z)
 var pitch = atan2(heading.y,Vector2(heading.x,heading.z).length())
 var event = InputEventMouseMotion.new()
 event.screen_relative = Vector2(-wrapf(yaw-game.player.rotation.y,-PI,PI),game.player.camera.rotation.x-pitch)/(game.settings.sensitivity*0.002)
 event.relative = event.screen_relative
 Input.parse_input_event(event)
 Input.flush_buffered_events()
func step() -> bool:
 var prior = game.player.position if is_instance_valid(game.player) else Vector3.ZERO
 await physics_frame
 await process_frame
 ticks += 1
 if not check(ticks <= LIMIT and game.state.health > 0,"Finite33000tick attempt and live player; no resume/refund"): return false
 if is_instance_valid(game.player): travelled += prior.distance_to(game.player.position)
 if not initial_ammo.is_empty():
  for slot in range(1,6):
   if not check(game.state.ammo[slot]==initial_ammo[slot]+game.supplies[slot]-game.spent[slot],"Route-wide exact finite ammo = declared entry + actual pickup delta - accepted shots"): return false
 if not check(game.shot_ledger_ok,"Native accepted-shot interval ledger"): return false
 if ticks%120 == 0: print("COMMITMENT_PROGRESS ",JSON.stringify({"ticks":ticks,"position":str(game.player.position) if is_instance_valid(game.player) else "retired","hp":game.state.health,"ammo":game.state.ammo,"spent":game.spent,"deaths":game.death_ids}))
 return true
func walk(cell: Array,cap: int = 900) -> bool:
 var goal: Vector3 = game.level.layout.world_position(cell)+Vector3.UP*0.03
 var routes = game.level.get_node("NavigationRoutes")
 for ready_tick in range(180):
  if routes.is_ready("worker"): break
  if not await step(): return false
 if not check(routes.is_ready("worker"),"Bounded native route publication after scene reconstruction"): return false
 var path: PackedVector3Array = []
 var waypoint = 0
 for tick in range(cap):
  if not check(game.playing and is_instance_valid(game.player),"Movement retains actual live scene"): return false
  if Vector2(game.player.position.x-goal.x,game.player.position.z-goal.z).length()<0.65:
   release()
   return true
  if tick%30 == 0 or waypoint>=path.size():
   path = routes.route(game.player.position,goal,"worker")
   waypoint = 1 if path.size()>1 else 0
  if path.is_empty():
   print("ROUTE_EMPTY ",JSON.stringify({"position":str(game.player.position),"goal":str(goal),"velocity":str(game.player.velocity),"grounded":game.player.is_on_floor(),"ready":routes.is_ready("worker"),"support":game.level.layout.capsule_floor_support(Vector2(game.player.position.x,game.player.position.z),0.32),"yaw":game.player.rotation.y}))
   check(false,"Actual native route exists to "+str(cell))
   return false
  while waypoint<path.size()-1 and game.player.position.distance_to(path[waypoint])<0.7: waypoint += 1
  var direction: Vector3 = path[waypoint]-game.player.position
  direction.y = 0
  var aim_point: Vector3 = game.player.camera.global_position+direction
  var local: Vector3 = game.player.basis.inverse()*direction.normalized()
  release()
  var threats: Array = game.enemies.filter(func(a): return is_instance_valid(a) and a.active and a.hp>0 and a.position.distance_to(game.player.position)<80)
  if not threats.is_empty():
   threats.sort_custom(func(a,b): return a.position.distance_squared_to(game.player.position)<b.position.distance_squared_to(game.player.position))
   for threat in threats:
    var query = PhysicsRayQueryParameters3D.create(game.player.camera.global_position,threat.position+Vector3.UP,1|4)
    query.exclude = [game.player.get_rid()]
    var hit = game.get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty() and hit.collider==threat:
     aim_point = threat.position+Vector3.UP
     if game.state.ammo[3]<=0 and game.state.ammo[1]>0: event_action("weapon_2",true); event_action("weapon_2",false)
     event_action("fire",true)
     break
  aim(aim_point)
  local = game.player.basis.inverse()*direction.normalized()
  for pair in [["move_right",local.x],["move_left",-local.x],["move_back",local.z],["move_forward",-local.z]]:
   if pair[1]>0: Input.action_press(pair[0],pair[1])
  if not await step(): return false
 check(false,"Route cap pose="+str(game.player.position)+" goal="+str(goal)+" velocity="+str(game.player.velocity))
 return false
func use_at(point: Vector3) -> bool:
 release()
 aim(point)
 event_action("interact",true)
 if not await step(): return false
 event_action("interact",false)
 return await step()
func finish() -> void:
 release()
 if is_instance_valid(game):
  game.show_title()
  game.free()
  game = null
 paused = false
 await process_frame
 await process_frame
 for suffix in [".json",".json.tmp","_preferences.json","_preferences.json.tmp"]:
  if FileAccess.file_exists(prefix+suffix): DirAccess.remove_absolute(prefix+suffix)
 print("HEART_V2_COMMITMENT_RESULT ",JSON.stringify({"failures":failures,"ticks":ticks,"travelled":travelled,"arranged":true,"earned_campaign":false}))
 call_deferred("terminal",0 if failures == 0 else 1)
func terminal(status: int) -> void:
 await process_frame
 await process_frame
 quit(status)
func run() -> void:
 if not check(Engine.physics_ticks_per_second==60 and Engine.time_scale==1.0,"Production60Hz clock"): await finish(); return
 game = ObservedMain.new()
 game.progress_path = prefix+".json"
 game.settings_path = prefix+"_preferences.json"
 root.add_child(game)
 game.settings.head_bob = false
 game.settings.camera_shake = false
 game.state.new_campaign(1)
 game.state.level_index = 7
 game.state.health = 100
 game.state.armor = 100
 game.state.owned_weapons = [0,1,2,3,4,5]
 game.state.ammo = [0,180,32,240,24,120]
 game.state.weapon = 3
 game.state.keys = []
 game.state.discoveries = [0,1,2,3,4,5,6] # Declared prior records, actual Heart story still required.
 game.start_level()
 for tick in range(180):
  await physics_frame
  await process_frame
  if game.playing: break
 if not check(game.playing and game.level.layout.floor_revision()==2,"Current Heart2 ready"): await finish(); return
 initial_ammo = game.state.ammo.duplicate()
 for tick in range(180):
  if game.level.get_node("NavigationRoutes").is_ready("worker"): break
  if not await step(): await finish(); return
 for key in ["blood","ivory"]:
  var spec: Dictionary = game.level.layout.data.interactions.filter(func(row): return row.get("key","")==key)[0]
  if not await walk(spec.cell,2400): await finish(); return
  if not await use_at(game.level.layout.world_position(spec.cell)+Vector3.UP*0.7): await finish(); return
  if not check(key in game.state.keys and spec.id in game.state.removed,"Actual input earns "+key+" without grants"): await finish(); return
  print("COMMITMENT_SEAL ",key," ticks=",ticks," resources=",game.state._resources())
 var story: Dictionary = game.level.layout.data.interactions.filter(func(row): return row.kind=="story")[0]
 if not await walk(story.cell,2400): await finish(); return
 if not await use_at(game.level.layout.world_position(story.cell)+Vector3.UP*0.7): await finish(); return
 if not check(7 in game.state.discoveries,"Actual Heart record recovered"): await finish(); return
 if not await walk([31.5,19.5]): await finish(); return
 for tick in range(30):
  if game.state.checkpoint_id=="heart_checkpoint": break
  if not await step(): await finish(); return
 if not check(game.state.checkpoint_id=="heart_checkpoint" and FileAccess.file_exists(game.progress_path),"Actual passive checkpoint commits disk"): await finish(); return
 var disk = FileAccess.get_file_as_bytes(game.progress_path)
 var disk_sha = FileAccess.get_sha256(game.progress_path)
 var loaded = Campaign.new()
 if not check(loaded.load_progress(game.progress_path) and loaded.keys==["blood","ivory"] and loaded.checkpoint_id=="heart_checkpoint","Independent checkpoint disk parse retains both actually collected seals"): await finish(); return
 game.show_title()
 await process_frame
 await process_frame
 await game.continue_campaign()
 if not check(game.playing and game.state.keys==loaded.keys and game.state.ammo==loaded.ammo and FileAccess.get_file_as_bytes(game.progress_path)==disk,"Actual title Continue preserves saved finite resources and disk bytes"): await finish(); return
 if not await walk([31.5,18.6]): await finish(); return
 var gate: Dictionary = game.level.layout.data.doors[0]
 if not await use_at(game.level.layout.world_position(gate.cell)+Vector3.UP*2): await finish(); return
 if not check(gate.id in game.state.removed,"Actual input opens two-seal gate"): await finish(); return
 if not await walk([31.5,16.3]): await finish(); return
 var ids: Array = game.level.layout.data.encounters.filter(func(g): return g.id=="heart_finale")[0].enemy_ids
 var corner = 0
 var route = [[31.5,16.3],[41,15.5],[41,4.5],[27.5,4.5],[27.5,15.5]]
 for tick in range(5400):
  var living: Array = game.enemies.filter(func(a): return is_instance_valid(a) and a.id in ids and a.hp>0)
  if living.is_empty(): break
  var target = living[0]
  var best = INF
  for actor in living:
   var distance = actor.position.distance_to(game.player.position)
   var ray = PhysicsRayQueryParameters3D.create(game.player.camera.global_position,actor.position+Vector3.UP,1|4)
   ray.exclude = [game.player.get_rid()]
   var hit = game.get_world_3d().direct_space_state.intersect_ray(ray)
   if not hit.is_empty() and hit.collider==actor and distance<best: target=actor; best=distance
  aim(target.position+Vector3.UP)
  var waypoint: Vector3 = game.level.layout.world_position(route[corner])
  var direction = waypoint-game.player.position
  direction.y=0
  if direction.length()<1: corner=(corner+1)%route.size()
  var local: Vector3 = game.player.basis.inverse()*direction.normalized()
  release()
  for pair in [["move_right",local.x],["move_left",-local.x],["move_back",local.z],["move_forward",-local.z]]:
   if pair[1]>0: Input.action_press(pair[0],pair[1])
  event_action("fire",true)
  var before: Array = game.state.ammo.duplicate()
  var spent_before: Array = game.spent.duplicate()
  if not await step(): await finish(); return
  for slot in range(1,6):
   if not check(game.state.ammo[slot]==before[slot]-(game.spent[slot]-spent_before[slot]),"Exact actual accepted-shot/ammo conservation, no pickup injection"): await finish(); return
  for flight in game.level.get_children():
   if flight.get_script()!=Projectile or flight.is_queued_for_deletion(): continue
   var id = flight.get_instance_id()
   if projectile_samples.has(id) and flight.position.distance_to(projectile_samples[id][0])>0.001 and flight.lifetime<projectile_samples[id][1]: projectile_steps += 1
   projectile_samples[id]=[flight.position,flight.lifetime]
 release()
 if not check(ids.all(func(id): return game.death_ids.count(id)==1 and game.state.removed.count(id)==1) and game.phases[0]>0 and game.phases[1]>0 and projectile_steps>0,"All7 actual deaths, both boss attack phases and native progressing projectiles"): await finish(); return
 if not await walk([39.5,5.8]): await finish(); return
 if not await use_at(game.level.layout.world_position([39.5,5.5])+Vector3.UP*0.7): await finish(); return
 if not check(game.state.level_index==8 and not game.playing and game.menu.get_child(0).text.begins_with("YOUR VOICE") and FileAccess.get_sha256(game.progress_path)!=disk_sha,"Actual defeated-boss exit atomically saves complete ending"): await finish(); return
 var completed = Campaign.new()
 if not check(completed.load_progress(game.progress_path) and completed.level_index==8 and completed._resources()==game.state._resources(),"Completed disk resources exactly match actual surviving state"): await finish(); return
 await game.continue_campaign()
 if not check(game.menu.get_child(0).text.begins_with("YOUR VOICE"),"Completed disk Continue retains authored revelation"): await finish(); return
 print("PASS ARRANGED connected Heart2 checkpoint/diskContinue/two-seal gate/all7 active finale/actual exit/complete-record ending; not earned fullcampaign")
 await finish()
