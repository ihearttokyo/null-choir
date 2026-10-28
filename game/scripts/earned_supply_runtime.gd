extends RefCounted
## Main-thread runtime adapter. Authority is Campaign primitive state, not markers.
const Supply = preload("res://scripts/earned_supplies.gd")
var _scene: Node3D
var _observer: CharacterBody3D
var _last: Vector3
var _markers: Dictionary = {}
var _drop_practicals: Dictionary = {} # Exact ephemeral marker-instance to light ownership.
var _equipment: Dictionary = {} # Ephemeral only; Level owns fixed machines/colliders.
var _raw: InputEvent
var _eligible: bool = false
var _down: bool = false
var _release_required: bool = true
var _intent: Dictionary = {}
var _display: Dictionary = {}

func reset(game) -> void:
	_scene=game.level
	_observer=game.player
	_last=game.player.position if is_instance_valid(game.player) else Vector3.ZERO
	_intent={}; _display={}; _raw=null; _eligible=false
	_down=Input.is_action_pressed("use_asset")
	_release_required=_down

func cancel(game) -> void:
	reset(game)

func device_changed() -> void:
	_intent={}; _raw=null; _eligible=false; _down=true; _release_required=true

func record_input(game, event: InputEvent) -> void:
	_eligible=false
	_raw=event
	if event.is_action_released("use_asset"):
		_down=false; _release_required=false
		return
	if not event.is_action_pressed("use_asset") or event.is_echo(): return
	var rising: bool = not _down
	_down=true
	_eligible=rising and not _release_required and game.playing and not game.get_tree().paused and game.state.health>0

func queue_use(game, observer: CharacterBody3D, event: InputEvent) -> bool:
	if event!=_raw or not _eligible or not event.is_action_pressed("use_asset"): return false
	_eligible=false
	if observer!=game.player or not observer._current_map() or not game.playing: return false
	_intent={"scene":game.level,"player":observer,"tick":Engine.get_physics_frames()+1}
	# One deliberate action per physical edge, even if custom bindings overlap.
	# The use-asset action wins; default PadX leaves existing PadA/E untouched.
	game._cancel_interaction_input(observer)
	return true

func _clear(game, from: Vector3, to: Vector3) -> bool:
	if from.distance_squared_to(to)<.000001: return true
	var query := PhysicsRayQueryParameters3D.create(from,to,1)
	return game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _point(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])

func _station_point(game, station: Dictionary) -> Vector3:
	return game.level.to_local(game.level.healing_machinery.station_world_point(station.id))

func _station_use_target(game, station: Dictionary) -> MeshInstance3D:
	if not is_instance_valid(game.level) or not _markers.has(station.id): return null
	var row=game.level.healing_stations.get(station.id)
	if not row is Dictionary or _markers[station.id]!=row.get("root"): return null
	if row.get("capacity")!=int(station.capacity) or row.get("remaining")!=int(game.state.earned_supply.healing_remaining.get(station.id,-1)): return null
	return game.level.healing_machinery.use_target(station.id)

func station_use_target(game, station: Dictionary) -> MeshInstance3D:
	return _station_use_target(game,station)

func nearest_station(game) -> Dictionary:
	if not is_instance_valid(game.player) or not game.player._current_map() or not game.playing or game.state.health<=0: return {}
	if not Engine.is_in_physics_frame(): return {}
	var closest: Dictionary = {}
	var distance: float = 2.8
	for station in Supply.chapter(game.level.layout).get("stations",[]):
		if not game._has_keys(station.requires): continue
		var point: Vector3 = _station_point(game,station)
		if not point.is_finite(): continue
		var d: float = game.player.position.distance_to(point)
		if d>=distance or absf(game.player.position.y-game.level.healing_machinery.root_point(station.id).y)>.60: continue
		var target := _station_use_target(game,station)
		if not is_instance_valid(target): continue
		var aim: Vector3 = game.level.healing_machinery.station_world_point(station.id)
		if not aim.is_finite(): continue
		if (-game.player.camera.global_basis.z).dot((aim-game.player.camera.global_position).normalized())<.45: continue
		if not _clear(game,game.player.camera.global_position,aim): continue
		closest=station;distance=d
	return closest

func _cache_display(game) -> void:
	_display={}
	var station := nearest_station(game)
	if station.is_empty(): return
	var remaining: int = int(game.state.earned_supply.healing_remaining[station.id])
	_display={"id":station.id,"position":_station_point(game,station),"remaining":remaining,
		"text":station.name+" / "+str(remaining)+" UNITS"+(" / DEPLETED" if remaining==0 else ""),
		"binding":game.preferences.binding_text("use_asset"),"scene":game.level,"player":game.player,
		"origin":game.player.camera.global_position,"direction":-game.player.camera.global_basis.z,"tick":Engine.get_physics_frames()}

func display(game) -> Dictionary:
	if _display.is_empty() or not is_instance_valid(game.player) or not game.player._current_map() or not game.playing or game.state.health<=0: return {}
	if game.get_tree().paused or _display.scene!=game.level or _display.player!=game.player: return {}
	if Engine.get_physics_frames()-int(_display.tick)>1 or _display.origin!=game.player.camera.global_position or _display.direction!=-game.player.camera.global_basis.z: return {}
	return _display

func _drop_clear(game, values: Array) -> bool:
	var shape := SphereShape3D.new()
	shape.radius=.08
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform=Transform3D(Basis.IDENTITY,game.level.to_global(_point(values)+Vector3.UP*.08))
	query.collision_mask=1
	return game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func commit_defeat(game, actor) -> bool:
	if not is_instance_valid(actor) or actor.hp!=0 or not actor._current_map(): return false
	var before: Dictionary = game.state._resources()
	if not actor.id in before.removed: before.removed.append(actor.id)
	var value: Dictionary = Supply.defeated(before,game.level.layout,game.state.difficulty,actor.id,actor.position)
	if value.is_empty():
		game.fail_earned_transaction("EARNED SUPPLY INVARIANT FAILED / SAVE PRESERVED")
		return false
	var grants := Supply.grant_map(Supply.chapter(game.level.layout))
	for drop in value.loot_drops:
		if grants[drop.grant_id].carrier!=actor.id: continue
		if not _drop_clear(game,drop.position):
			drop.position=Supply.recovery_position(grants[drop.grant_id],game.level.layout)
			if not Supply.position_valid(drop.position,game.level.layout,before.removed) or not _drop_clear(game,drop.position):
				game.fail_earned_transaction("CORPSE SUPPLY SUPPORT INVALID / SAVE PRESERVED")
				return false
	# No callbacks until actor defeat and every finite equipment grant coexist.
	game.state.removed=before.removed
	game.state.earned_supply=value
	refresh(game)
	return true

func tick(game, observer: CharacterBody3D) -> void:
	if not game._passive_scan_current(observer,game.level): return
	if _scene!=game.level or _observer!=observer:
		reset(game)
		return
	var point: Vector3 = observer.position
	var start: Vector3 = _last
	_last=point # Latch before any collection/notification callback.
	if not _intent.is_empty():
		var intent: Dictionary = _intent
		_intent={}
		if intent.scene==game.level and intent.player==observer and int(intent.tick)>=Engine.get_physics_frames():
			var station := nearest_station(game)
			if not station.is_empty():
				var next := Supply.heal(game.state._resources(),game.level.layout,game.state.difficulty,station.id)
				if not next.is_empty():
					game.state._apply_resources(next)
					refresh(game)
					game.notify("RESERVOIR TRANSFER COMPLETE")
	if not game._passive_scan_current(observer,game.level): return
	_cache_display(game)
	# Real movement only. Teleports/load/recovery call reset; defensive large
	# discontinuities also reset instead of creating a world-spanning magnet.
	if start.distance_to(point)>2.0 or not _clear(game,game.level.to_global(start+Vector3.UP*.55),game.level.to_global(point+Vector3.UP*.55)): return
	var drops: Array = game.state.earned_supply.loot_drops.duplicate(true)
	var changed: bool = false
	for drop in drops:
		if not game._passive_scan_current(observer,_scene): return
		var location := _point(drop.position)
		var near: Vector3 = Geometry3D.get_closest_point_to_segment(location,start,point)
		if near.distance_to(location)>.80 or absf(near.y-(location.y-.20))>.45: continue
		if not _clear(game,game.level.to_global(near+Vector3.UP*.45),game.level.to_global(location+Vector3.UP*.20)): continue
		var next := Supply.collect(game.state._resources(),game.level.layout,game.state.difficulty,drop.grant_id)
		if next.is_empty(): continue
		game.state._apply_resources(next)
		changed=true
	# Keys use the SAME locality/visibility sweep but retain existing independent
	# SealGuardians availability, defeated requirements and one-life accounting.
	for key in game.level.layout.data.interactions:
		if not game._passive_scan_current(observer,_scene): return
		if key.get("kind")!="key" or key.id in game.state.removed: continue
		if not game.SealGuardians.available(game.state,key): continue
		var location: Vector3 = game.SealGuardians.interaction_position(game,key)
		var near: Vector3 = Geometry3D.get_closest_point_to_segment(location,start,point)
		if near.distance_to(location)>.80 or absf(near.y-(location.y-.20))>.45: continue
		if _clear(game,game.level.to_global(near+Vector3.UP*.45),game.level.to_global(location+Vector3.UP*.20)): game.collect_key(key.id)
	if changed and game._passive_scan_current(observer,_scene):
		refresh(game)
		game.notify("CARRIED SUPPLIES RECOVERED")
	if game._passive_scan_current(observer,_scene): _cache_display(game)

func _marker(parent: Node3D, point: Vector3, text: String) -> Node3D:
	var root := Node3D.new()
	root.name="CorpseEquipment"
	root.position=point
	parent.add_child(root)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size=Vector3(.34,.12,.22)
	mesh.mesh=box
	mesh.position.y=.06
	var material := StandardMaterial3D.new()
	material.albedo_color=Color(.56,.36,.18)
	material.roughness=.9
	# The existing carried/drop case supplies the small steady practical source.
	material.emission_enabled=true
	material.emission=Color(.56,.36,.18)
	material.emission_energy_multiplier=.18
	mesh.material_override=material
	root.add_child(mesh)
	var label := Label3D.new()
	label.text=text
	label.font_size=18
	label.pixel_size=.008
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y=.38
	root.add_child(label)
	if not parent is CharacterBody3D:
		var practical := OmniLight3D.new()
		practical.name="EarnedDropPractical"
		practical.position=Vector3(0,.32,0)
		practical.light_color=Color(.95,.8,.6)
		practical.light_energy=1.0
		practical.omni_range=2.0
		practical.shadow_enabled=true
		practical.set_meta("practical_source","earned_drop_case")
		practical.set_meta("source_role","earned_equipment_drop")
		root.add_child(practical)
		_drop_practicals[root.get_instance_id()]=practical
	return root

func refresh(game) -> void:
	for marker in _equipment.values():
		if is_instance_valid(marker): marker.visible=false;marker.queue_free()
	_equipment={}
	_drop_practicals={}
	_markers={}
	if not is_instance_valid(game.level): return
	for station in Supply.chapter(game.level.layout).get("stations",[]):
		var remaining: int = int(game.state.earned_supply.healing_remaining[station.id])
		if not game.level.healing_machinery.update_stock(station.id,remaining,int(station.capacity)):
			game.fail_earned_transaction("HEALING MACHINERY INVALID / SAVE PRESERVED")
			return
		_markers[station.id]=game.level.healing_stations[station.id].root
	var grants := Supply.grant_map(Supply.chapter(game.level.layout))
	var equipped: Dictionary = {}
	for grant in grants.values():
		if grant.id in game.state.earned_supply.loot_claimed or equipped.has(grant.carrier): continue
		for actor in game.enemies:
			if not is_instance_valid(actor) or actor.hp<=0 or actor.id!=grant.carrier or not actor._current_map(): continue
			var label: String = "CARRIED RESONATOR" if actor.kind=="caster" else "RITUAL CACHE" if actor.kind=="summoner" else "CARRIED EQUIPMENT"
			equipped[actor.id]=true
			_markers["carrier:"+actor.id]=_marker(actor,Vector3(.4,1.0,.15),label)
	for drop in game.state.earned_supply.get("loot_drops",[]):
		var grant: Dictionary = grants[drop.grant_id]
		var name: String = "ARMOR" if grant.kind=="armor" else game.Player.WEAPONS[int(grant.weapon)].name
		_markers[drop.grant_id]=_marker(game.level,_point(drop.position),name+(" UNLOCK" if grant.kind=="unlock" else " x"+str(drop.remaining)))

	for id in _markers:
		if not game.level.healing_stations.has(id): _equipment[id]=_markers[id]
