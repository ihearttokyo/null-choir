extends SceneTree
# DRAFT, arranged geometry only. Never earned-campaign/native acceptance until executed.
const Layout=preload("res://scripts/level_data.gd")
const Enemy=preload("res://scripts/enemy.gd")
const Surfaces=preload("res://scripts/ossuary_surfaces_v3.gd")
var failures=0
func check(ok:bool,message:String)->void:
 if not ok:failures+=1;push_error(message)
func _initialize()->void:
 check(Surfaces.validate_arch_resource().is_empty(),"Actual imported PackedScene satisfies authored arch geometry (also required from future PCK)")
 var layout=Layout.new()
 check(layout.load_level(5),"Load validated actual Ossuary3")
 if layout.data.is_empty():quit(1);return
 layout.world_position([19,24])
 layout.capsule_floor_support(Vector2(76,96),.32)
 check(layout._surface_cache.is_empty(),"Outside-patch point/disc use exact original fast path without building surface cache")
 check(Surfaces.enabled(layout.data),"Only explicit Ossuary3 recipe active")
 check(is_equal_approx(layout.world_position([6.5,18.5]).y,5.3),"New visible upper deck top5.30")
 check(is_equal_approx(layout.surface_position_at_y([6.5,18.5],1.03).y,1.0),"Actual bed below deck is separately queryable")
 check(is_equal_approx(layout.world_position([5.75,18.5]).y,1.0),"Exposed trench is carved, not dark bank5")
 check(is_equal_approx(layout.world_position([5.25,16.5]).y,5.0),"Escape top joins original bank5")
 check(is_equal_approx(layout.world_position([5.25,18.75]).y,1.0),"Escape bottom joins real trench bed")
 for radius in [.32,.34,.42]:
  check(absf(layout.capsule_floor_support_at_y(Vector2(26,74),radius,1.03)-1.0)<.003,"Physical Player/worker/crawler bed layer remains below deck")
  check(absf(layout.capsule_floor_support_at_y(Vector2(26,74),radius,5.33)-5.3)<.003,"Physical bridge actor selects upper deck layer")
 check(rad_to_deg(atan(4.0/8.0)) < 28,"Escape meets unchanged native slope cap")
 check(rad_to_deg(atan(.3/1.2)) < 28,"Deck approaches meet unchanged native slope cap")
 check(layout.migration_capsule_clearance(Vector3(26,5.276,74),.32,1.65,.025),"Actual Player fits central hollow passage")
 check(absf(layout.surface_position_at_y([6.5,18.5],5.276+.025).y-5.3)<.003,"Actual low Player origin selects bridge using physical foot offset")
 check(layout.migration_capsule_clearance(Vector3(26,2.16,74),Enemy.capsule_radius("caster"),Enemy.capsule_height("caster"),0.0),"Max normal caster hover and actual body fit under four-metre span")
 check(layout.migration_capsule_clearance(Vector3(26,1.03,74),Enemy.capsule_radius("guardian"),Enemy.capsule_height("guardian"),0.0),"Actual guardian-height body fits below deck without profile reduction")
 check(not layout.migration_capsule_clearance(Vector3(26,4.9,74),.32,1.65,.025),"Reject capsule intersecting thin deck underside")
 for center in [Vector2(19.9,74),Vector2(20.1,74),Vector2(24.5,74),Vector2(26,74),Vector2(32.1,74)]:
  for radius in [.32,.42,.8]:
   var reference:float=-INF
   for face in layout.surface_faces():
    if not face.walkable:continue
    var t:Array=face.triangle
    var shift=Vector3(center.x,0,center.y)
    reference=maxf(reference,layout._capsule_triangle_support(radius,t[0]-shift,t[1]-shift,t[2]-shift))
   check(absf(layout.capsule_floor_support(center,radius)-reference)<.00001,"Local bins preserve exact clipped patch-edge sphere support")
 check(layout._surface_candidates(Vector2(26,74),.42).size()<layout.surface_faces().size(),"Broadphase excludes distant map triangles before exact work")
 # Independent known authored anchor/world height witnesses: these are BANK, not deck.
 for spec in layout.data.scenery.slice(0,4):
  var placed=layout.world_position(spec.cell)+Vector3.UP*spec.get("height",0.0)
  check(absf(placed.y-5.0)<.000001,"Each original drain altar root remains world5.0; no unnecessary offset")
  check(not spec.has("height"),"No V3 altar-height metadata added")
 check(not layout.migration_patch_overlap(Vector2(-64,-64),.32),"Outside recovery sentinel does not opt into new patch guard")
 check(layout.migration_patch_overlap(Vector2(19.6,74),.32),"Actual .1 parapet extension included in changed-region overlap")
 check(not layout.migration_patch_overlap(Vector2(19.5,74),.32),"No generic map-wide expansion of changed region")
 check(not layout.migration_capsule_clearance(Vector3(26,5.255,74),.32,1.65,.025),"Default geometry remains strict for floor penetration")
 check(layout.migration_capsule_clearance(Vector3(26,5.255,74),.32,1.65,.025,[],.08),"Existing signed floor-only -.02 trust accepted with explicit .08 bound")
 check(not layout.migration_capsule_clearance(Vector3(26,5.185,74),.32,1.65,.025,[],.08),"Beyond existing -.08 floor bound rejected")
 check(not layout.migration_capsule_clearance(Vector3(24.875,5.255,74),.32,1.65,.025,[],.08),"Lateral rail -.02 overlap remains strict despite floor trust")
 check(not layout.migration_capsule_clearance(Vector3(26,2.32,74),.34,2.7,0,[],.08),"Deck underside -.02 overlap remains strict despite floor trust")
 for revision in [0,1,2]:
  var old=layout.floor_at_revision(5,revision)
  check(old != null and old.floor_revision()==revision and not old.data.has("terrain_patch"),"Legacy terrain exact revision and no V3 recipe leak: "+str(revision))
  if old!=null:check(is_finite(old.world_position([6.5,18.5]).y),"Legacy original surface remains queryable")
 for index in [0,1,2,3,4,6,7]:
  var other=Layout.new()
  check(other.load_level(index) and not Surfaces.enabled(other.data),"Other map does not opt into recipe "+str(index))
 print("Ossuary marrow surfaces failures=",failures)
 if failures==0:print("PASS Ossuary marrow surfaces arranged geometry")
 quit(0 if failures==0 else 1)
