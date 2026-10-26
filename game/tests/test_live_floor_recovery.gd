extends "res://tests/test_campaign_earned_v2.gd"
# Exact19 disk recovery + explicitly arranged LIVE collision contract cases, not campaign replay.
func frames() -> void:
 for tick in range(4): await physics_frame
func obstacle(at: Vector3,size: Vector3,mask: int=1) -> StaticBody3D:
 var body = StaticBody3D.new(); body.collision_layer = mask
 var shape = CollisionShape3D.new(); var box = BoxShape3D.new(); box.size = size; shape.shape = box
 body.add_child(shape); game.level.add_child(body); body.global_position = at
 return body
func run() -> void:
 output = OS.get_environment("NULL_CHOIR_EARNED_V2_OUTPUT")
 var input = OS.get_environment("NULL_CHOIR_RECOVERY_INPUT")
 if not check(AudioServer.get_driver_name()=="Dummy" and FileAccess.get_sha256(input)=="7de227ba8efc5809764f207e864288b9eb33ae44d7dce5b82b8f29bc24b9a55a","Exact19 raw/Dummy"): await finish(); return
 var image = Campaign.new()
 if not check(image.load_progress(input),"Unchanged exact19 codec accepts original image"): await finish(); return
 prefix = "user://live_floor_"+str(OS.get_process_id())
 var file = FileAccess.open(prefix+"_campaign.json",FileAccess.WRITE); file.store_buffer(FileAccess.get_file_as_bytes(input)); file.close()
 game = EarnedMain.new(); game.progress_path = prefix+"_campaign.json"; game.settings_path = prefix+"_prefs.json"; root.add_child(game)
 if not menu("Continue"): await finish(); return
 await frames()
 if not check(not game.playing and not is_instance_valid(game.player) and game.message=="NO SAFE RECOVERY POSITION","Exact19 bad CURRENT actor remains rejected without repair"): await finish(); return
 check(FileAccess.get_sha256(game.progress_path)==FileAccess.get_sha256(input),"Rejected current disk remains exact")
 var labels: Array = []
 for node in game.menu.get_children():
  if node is Button: labels.append(node.text)
 check("Restore checkpoint" in labels and "Restart level" in labels,"Actual visible recovery choices break title Continue trap")
 if not menu("Restore checkpoint"): await finish(); return
 await frames()
 if not check(game.playing and not game.placement_pending,"Actual original healthy CHECKPOINT starts via real button"): await finish(); return
 # Observe before any fixture-issued physics/input. Native restored pose may have advanced naturally.
 for field in ["health","armor","ammo","owned_weapons","keys"]:
  check(game.state.get(field)==image.checkpoint[field],"Checkpoint original finite field, not current refund: "+field)
 check(game.state.discoveries.is_empty() and FileAccess.get_sha256(game.progress_path)==FileAccess.get_sha256(input),"Actual checkpoint keeps EMPTY lore and original disk until real save")
 var actor = game.enemies.filter(func(a):return a.id=="heart_enemy_10")[0]
 # Arranged isolated collision validation from here; no earned/run claims.
 game.playing = false
 for a in game.enemies: a.set_physics_process(false)
 game.player.set_physics_process(false)
 var collider: CollisionShape3D = actor.get_child(0)
 var layout = game.level.layout
 var point: Array = image.actors.filter(func(a):return a.id=="heart_enemy_10")[0].position
 actor.position = Vector3(point[0],point[1],point[2]); await frames()
 check(not game._valid_restored_actors(),"Original19 exact1.154mm floor overlap still STRICT rejected")
 var old = actor.snapshot(); var before: Vector3 = actor.position
 check(actor._settle_live_floor_contact(),"LIVE native floor-only settling succeeds")
 check(actor.position.y>before.y and actor.snapshot().hp==old.hp and actor.snapshot().alerted==old.alerted,"Actual native body moved; ID/HP/alert unchanged")
 check(game._valid_restored_actors(),"Unchanged strict native final pose passes")
 print("LIVE_SETTLE_DELTA ",actor.position-before)
 var support: float = layout.capsule_floor_support_at_y(Vector2(actor.position.x,actor.position.z),collider.shape.radius,actor.position.y,.08)
 # Main's old deep-negative contract is untouched, even though LIVE physics can recover it.
 actor.position.y = support-.002; await frames()
 check(not game._valid_restored_actors(),"EXACT existing-.002 Main trust rejection preserved")
 var blocked = obstacle(actor.position+Vector3(0,collider.shape.height+.0011,0),Vector3(1,.002,1)); await frames()
 check(not actor._settle_live_floor_contact(),"Blocked lift/ceiling cannot be repaired")
 check(actor._floor_settle_failed and not game._capture_actor_state(),"Known failed LIVE settle cannot serialize")
 blocked.free(); await frames()
 actor.position = before
 var foreign = obstacle(actor.position+Vector3(collider.shape.radius,1,0),Vector3(.02,1,.02),4); await frames()
 check(not actor._settle_live_floor_contact(),"Foreign NPC-layer overlap rejects before lift")
 foreign.free(); await frames()
 actor.position = before; actor.position.y = support+.03; await frames()
 var clear: Vector3 = actor.position
 check(actor._settle_live_floor_contact() and actor.position==clear,"Clear body is never moved")
 var kind_before = actor.kind; actor.kind = "caster"; actor.position.y = support+1
 var hovering: Vector3 = actor.position
 check(actor._settle_live_floor_contact() and actor.position==hovering,"Hover role not forced to ground")
 actor.kind = kind_before
 # Height selection contract: legitimate underdeck feet cannot be lifted onto the deck.
 var stacked = preload("res://scripts/level_data.gd").new()
 check(stacked.load_level(5),"Current Ossuary3 layout loads")
 check(absf(stacked.capsule_floor_support_at_y(Vector2(26,74),.34,1.03,.08)-1)<.00001 and stacked.capsule_floor_support(Vector2(26,74),.34)>5,"Height-aware native helper selects bed, never upper deck")
 # Production automatic _physics_process → move_and_slide → settlement path.
 actor.position = before; actor.set_physics_process(true); game.playing = true
 var age_before: float = actor.age
 for tick in range(12):
  await physics_frame
  check(not actor._floor_settle_failed and game._valid_restored_actors(),"Automatic live movement leaves only strict-admissible actor image")
 check(actor.age>age_before and actor.position!=before,"Real AI/physics advanced normally, not frozen or snapshot-clamped")
 actor.set_physics_process(false); game.playing = false
 game.pause_game()
 if not menu("Restart level"): await finish(); return
 await frames()
 check(game.playing and not game.placement_pending,"Actual original LEVEL START also safe through real Restart button")
 for field in ["health","armor","ammo","owned_weapons","keys"]:
  check(game.state.get(field)==image.level_start[field],"Restart exact original finite level-start field: "+field)
 check(game.state.discoveries.is_empty() and FileAccess.get_sha256(game.progress_path)==FileAccess.get_sha256(input),"Explicit Restart retains EMPTY lore/original disk")
 check(FileAccess.get_sha256(input)=="7de227ba8efc5809764f207e864288b9eb33ae44d7dce5b82b8f29bc24b9a55a","Original19 untouched")
 await finish()
