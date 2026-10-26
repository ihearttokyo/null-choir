extends Node3D
## Presentation only. Level owns the independent unscripted cover handle and physics.
var frame:Node3D
var cover:Node3D
var leaf:Node3D
var blood_latch:Node3D
var ivory_latch:Node3D
var released_closure:Node3D
var _blood_origin=Vector3.ZERO
var _ivory_origin=Vector3.ZERO
var _opening=false
var _removed=false

func configure(parts:Dictionary)->void:
 frame=parts.frame;cover=parts.cover;leaf=parts.leaf
 blood_latch=parts.blood;ivory_latch=parts.ivory;released_closure=parts.released
 _blood_origin=blood_latch.position;_ivory_origin=ivory_latch.position
 set_process(false);set_physics_process(false)
 hydrate(false,false,false)

# Explicit reconstruction is absolute; ordinary key refresh cannot resurrect an opened gate.
func hydrate(blood:bool,ivory:bool,removed:bool)->void:
 _opening=removed;_removed=removed
 _pose_keys(blood,ivory)
 cover.visible=not removed
 released_closure.visible=removed

func present_keys(blood:bool,ivory:bool)->void:
 if _opening or _removed:return
 _pose_keys(blood,ivory)

func _pose_keys(blood:bool,ivory:bool)->void:
 blood_latch.position=_blood_origin+Vector3(-1.35 if blood else 0,0,0)
 ivory_latch.position=_ivory_origin+Vector3(1.35 if ivory else 0,0,0)

func begin_open_visuals()->void:
 # Level must hide cover BEFORE callback; repeat hide is defensive, never a new authority.
 cover.hide()
 _opening=true
 released_closure.show()

func present_removed()->void:
 _removed=true;_opening=true
 cover.hide();released_closure.show()
