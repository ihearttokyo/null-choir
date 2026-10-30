extends "res://tests/qualify_v0097_visibility.gd"
## Bounded supplemental actual offcenter current-source views and draw/readback
## observations. Pistol/HUD remain intact; no FPS or exclusive GPU timing claim.
func bounded_cost() -> void:
 var count=ordinary_lights(.65)
 # Warm BOTH modes before alternating batches, holding actor/camera/world fixed.
 for energy in [0.0,.65,0.0,.65]:
  ordinary_lights(energy);await warm_draws(8)
 var batches=[]
 for batch in range(8):
  var energy: float=.65 if batch%2==0 else 0.0
  ordinary_lights(energy);await warm_draws(5)
  var samples=[]
  for sample_index in range(8):
   var start=Time.get_ticks_usec()
   RenderingServer.force_draw(false)
   var pixels: Image=view.get_texture().get_image()
   samples.append({"draw_and_readback_usec":Time.get_ticks_usec()-start,"width":pixels.get_width(),"height":pixels.get_height()})
  batches.append({"batch":batch,"energy":energy,"samples":samples})
 ordinary_lights(.65)
 report.events.append({"kind":"warmed_alternating_draw_readback_not_GPU_or_FPS","chapter":chapter,"ordinary_lights":count,"batches":batches,"scope":"Actual forced renderer plus synchronization/readback, fixed standing view; not exclusive GPUtime, sustained FPS or presentation latency"})

func run() -> void:
 output=OS.get_environment("NC97_OUTPUT")
 if output.is_empty() or not DirAccess.dir_exists_absolute(output):push_error("Explicit output required");quit(1);return
 report["schema"]="null-choir-v097-offcenter-supplement-v1"
 report["required_chapters"]=range(8);report["completed_chapters"]=[]
 var pump=HiddenDrawPump.new();pump.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(pump)
 report["hidden_manual_draw"]=true
 view=SubViewport.new();view.size=Vector2i(640,360);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 for chapter_index in range(8):
  if not await build_scene(chapter_index):await finish97();return
  host.player.set_physics_process(false)
  for actor in host.enemies:actor.set_physics_process(false)
  var cost_subject
  for actor in host.enemies:
   var light=actor.get_node_or_null("CarriedPractical")
   if actor.kind=="worker" and actor.active and light!=null and light.get_meta("source_role","")=="ordinary_threat":cost_subject=actor;break
  if cost_subject==null or not await physics_call(func():return frame_subject(cost_subject)):
   fail("Supported fixed cost view required");await finish97();return
  actor_pose(cost_subject);await warm_draws(6);await bounded_cost()
  for role in ["crawler","caster"]:
   var subject
   for actor in host.enemies:
    var light=actor.get_node_or_null("CarriedPractical")
    if actor.kind==role and actor.active and light!=null and light.get_meta("source_role","")=="ordinary_threat":subject=actor;break
   if subject==null:continue
   if not await physics_call(func():return frame_subject(subject)):
    fail("Actual supported offcenter view required");await finish97();return
   aim_off_center(subject.sprite.global_position);actor_pose(subject)
   # Retire preceding attack overlays through the unchanged Main process.
   await WallClock.seconds(self,.7)
   await warm_draws(4)
   report.arrangements.append({"kind":"natural_UI_transient_drain_before_pair","chapter":chapter,"role":role,"damage_flash":host.damage_flash,"hit_flash":host.hit_flash,"weapon_hidden":false,"camera_eye":v3(host.player.camera.position),"fov":host.player.camera.fov})
   if host.damage_flash>0.0 or host.hit_flash>0.0:
    fail("Undrained UI transient");await finish97();return
   var prefix="chapter-%d-%s-offcenter"%[chapter_index,role]
   ordinary_lights(0.0);await warm_draws();await snap(prefix+"-mid-off-control",subject)
   ordinary_lights(.65);await warm_draws();await snap(prefix+"-mid-current",subject)
   subject.sprite.hide();await warm_draws();await snap(prefix+"-mid-hidden-control",subject)
   subject.sprite.show();host.settings.reduced_damage_flashes=true;await warm_draws();await snap(prefix+"-mid-reduced",subject)
   host.settings.reduced_damage_flashes=false
   subject.alerted=true;subject.target=host.player;subject.set_physics_process(true)
   var start: Vector3=subject.position
   for tick in range(36):
    await physics_frame
    aim_off_center(subject.sprite.global_position)
    report.motion.append({"chapter":chapter_index,"role":role,"actor":subject.id,"tick":tick,"actor_position":v3(subject.position),"speed":subject.speed,"rush_time":subject._rush_time,"telegraph":subject.telegraph_time,"recovery":subject.recovery_time})
    if tick in [0,11,23,35]:await snap(prefix+"-motion-%02d"%tick,subject)
   subject.set_physics_process(false)
   report.events.append({"kind":"actual_AI_short_approach_not_earned_combat","chapter":chapter_index,"role":role,"actor":subject.id,"start":v3(start),"end":v3(subject.position)})
  report.completed_chapters.append(chapter_index)
 if report.completed_chapters!=Array(report.required_chapters):fail("Incomplete supplemental chapters")
 await finish97()
