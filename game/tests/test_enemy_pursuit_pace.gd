extends "res://tests/test_crawler_lunge.gd"
## Arranged real Enemy/native physics. Quantifies pace and finite commitment;
## not visibility, earned campaign balance, human feel or sustained-FPS evidence.
const EXPECTED_PACE = {"crawler":7.6,"worker":4.4,"caster":3.8,"brute":4.8,"guardian":3.2,"summoner":0.0,"nursery_warden":3.6,"choir_avatar":2.8}
const BASELINE_096_PACE = {"crawler":5.4,"worker":3.1,"caster":3.1,"brute":3.1,"guardian":2.0,"summoner":0.0,"nursery_warden":2.0,"choir_avatar":1.6}
const EXPECTED_STRAFE = {"worker":2.8,"caster":2.4}
var observations: Array = []

func measure(role: String, distance: float, frames: int, cooldown: float = 0.0, variant: int = 0) -> Dictionary:
 var host = Host.new()
 root.add_child(host)
 host.level = Room.new()
 host.add_child(host.level)
 host.level.floor_bodies.append(box(host.level,Vector3(0,-.1,-30),Vector3(100,.2,150)))
 host.player = Viewer.new()
 host.level.add_child(host.player)
 host.player.position = Vector3(0,.03,-distance)
 host.player.camera = Camera3D.new()
 host.player.add_child(host.player.camera)
 host.player.camera.position.y = 1.55
 host.player.camera.current = true
 var actor = Enemy.new()
 host.level.add_child(actor)
 actor.configure(host,{"id":"pace_"+role,"kind":role,"cell":[0,0],"yaw":0})
 actor.set_physics_process(false)
 await physics_frame;await physics_frame;await process_frame
 actor.alerted=true;actor.target=host.player;actor.path_time=1000;actor.waypoint=host.player.position
 actor.attack_time=cooldown;actor._attack_variant=variant
 var initial: Vector3=actor.position
 var first_tick: int=Engine.get_physics_frames()
 var windup_frames: int=0
 var rush_frames: int=0
 var committed: int=-1
 actor.set_physics_process(true)
 for i in range(frames):
  await physics_frame;await process_frame
  if actor.telegraph_time>0:windup_frames+=1;committed=actor._committed_variant
  if actor._rush_time>0:rush_frames+=1
 actor.set_physics_process(false)
 var ticks: int=Engine.get_physics_frames()-first_tick
 var displacement: float=Vector2(actor.position.x-initial.x,actor.position.z-initial.z).length()
 var result={"role":role,"target_distance":distance,"actual_physics_ticks":ticks,"metres":displacement,"delta_x":actor.position.x-initial.x,"delta_z":actor.position.z-initial.z,"metres_per_second":displacement/(float(ticks)/Engine.physics_ticks_per_second),"windup_frames":windup_frames,"rush_frames":rush_frames,"committed_variant":committed,"hits":host.hits,"final_position":str(actor.position)}
 observations.append(result)
 host.queue_free();await process_frame;await physics_frame
 return result

func run() -> void:
 for role in ["crawler","worker","caster","brute","guardian","summoner","nursery_warden","choir_avatar"]:
  var expected: float=EXPECTED_PACE[role] # Independent reviewed intent, not the production value.
  var row: Dictionary=await measure(role,42.0,45)
  check(absf(row.metres_per_second-expected)<.12,"Actual open-floor pursuit speed must match role: "+role+" "+str(row))
  if role!="summoner":
   check(row.metres_per_second>BASELINE_096_PACE[role] and row.delta_z<0 and absf(row.delta_x)<.01,"Faster actual pursuit must close toward target, not just move: "+role)
  check(row.windup_frames==0 and row.rush_frames==0,"Far target must be approached, not an empty short charge: "+role)
 for role in ["brute","nursery_warden"]:
  var row: Dictionary=await measure(role,25.0,30)
  check(row.metres>1.0 and row.windup_frames==0 and row.rush_frames==0,"Beyond finite commitment range must pursue: "+role)
 for role in ["worker","caster"]:
  var row: Dictionary=await measure(role,12.0,20,100.0)
  check(absf(row.metres_per_second-EXPECTED_STRAFE[role])<.12,"Real cooldown strafe preserves role with faster lateral pressure: "+role)
  check(absf(row.delta_z)<.10 and absf(row.delta_x)>absf(row.delta_z)*5,"Strafe must be lateral, not straight approach at a matching scalar speed: "+role)
 var volley: Dictionary=await measure("nursery_warden",25.0,15,0.0,1)
 check(volley.windup_frames>0 and volley.committed_variant==1,"Warden alternate ranged variant still admits25m target")
 for row in observations:print("PURSUIT_OBSERVATION ",JSON.stringify(row))
 print("ENEMY_PURSUIT_PACE failures=",failures," observations=",observations.size()," arranged real AI/physics, not rendered or earned-campaign evidence")
 quit(0 if failures==0 else 1)
