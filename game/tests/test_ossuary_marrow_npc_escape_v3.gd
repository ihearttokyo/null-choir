extends SceneTree
# DRAFT arranged real AI/physics witness, not earned combat. No collider or actor-profile edits.
class NativeGame extends "res://scripts/main.gd":
 func _ready()->void:set_process(false);set_physics_process(false)
class Driver extends Node:
 var actor
 var remaining=0
 var grounded=0
 var reached=false
 func _physics_process(delta:float)->void:
  if remaining<=0:return
  actor._physics_process(delta)
  if actor.is_on_floor():grounded+=1
  reached=actor.global_position.z<66.2 and actor.global_position.y>4.9
  remaining=0 if reached else remaining-1
var game
var failures=0
func check(ok:bool,message:String)->void:
 if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
 # Must be invoked with Dummy audio, no audible listening or user audio state changes.
 check(AudioServer.get_driver_name()=="Dummy","Explicit Dummy audio required")
 if failures>0:quit(1);return
 preload("res://scripts/preferences.gd").new().apply_bindings()
 check(Engine.physics_ticks_per_second==60 and Engine.time_scale==1.0,"Unchanged production physics clock")
 game=NativeGame.new();root.add_child(game);game.state.new_campaign(1);game.state.level_index=5
 game.level=game.Level.new();game.add_child(game.level)
 check(game.level.build(game,5),"Actual complete Ossuary3 world builds")
 game.player=game.Player.new();game.level.add_child(game.player);game.player.configure(game);game.player.set_physics_process(false)
 # Far enough ahead for normal worker pursuit, not its intended close-range retreat.
 game.player.position=game.level.layout.world_position([5.25,12])+Vector3.UP*.03
 var routes=game.level.get_node("NavigationRoutes")
 var deadline=Time.get_ticks_msec()+30000
 while (not routes.is_ready("worker") or not routes.is_ready("crawler")) and Time.get_ticks_msec()<deadline:await physics_frame
 for role in ["worker","crawler"]:
  check(routes.is_ready(role),"Actual "+role+" profile ready")
  var actor=game.Enemy.new();game.level.add_child(actor)
  actor.configure(game,{"id":"arranged_escape_"+role,"kind":role,"cell":[5.25,18.875],"yaw":0})
  actor.set_physics_process(false)
  actor.active=true;actor.alerted=true;actor.target=game.player
  check(absf(actor._target_capsule_foot_offset()-.025)<.000001,"Target hint uses actual production Player capsule foot offset")
  # Hold firing only; AI route choice, movement, HP, capsule, gravity and collisions unchanged.
  actor.attack_time=1000
  game.enemies=[actor];game.playing=true
  var driver=Driver.new();driver.actor=actor;driver.remaining=1200;game.add_child(driver)
  while driver.remaining>0:await physics_frame
  game.playing=false
  check(driver.reached and driver.grounded>0,"Real "+role+" continuously exits bed up the authored escape without repositioning")
  print("OSSUARY_NPC_ESCAPE role=",role," reached=",driver.reached," grounded=",driver.grounded," final=",actor.global_position)
  driver.free();game.enemies=[];actor.free();await physics_frame
 game.player=null;game.level=null;game.free();await physics_frame;await process_frame
 print("OSSUARY_NPC_ESCAPE failures=",failures," arranged=true earned_campaign=false")
 if failures==0:print("PASS Ossuary real NPC escape")
 quit(0 if failures==0 else 1)
