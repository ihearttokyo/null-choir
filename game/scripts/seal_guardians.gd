extends RefCounted
# Named champions reuse the approved actor art and role attacks. Their committed
# windup/recovery is explicit; seal state belongs to Campaign, never visual nodes.
const CORPSE_SCALE = {"crawler":3.8,"worker":3.65,"caster":3.65,"brute":4.4,"guardian":4.7,"summoner":5.6,"nursery_warden":7.3,"choir_avatar":7.6}

static func profile(spec: Dictionary) -> Dictionary:
	return spec.get("seal_guardian",spec.get("door_warden",{}))

static func bearer_spec(layout, guardian: String) -> Dictionary:
	for spec in layout.data.enemies:
		if spec.id == guardian and spec.has("seal_guardian"): return spec
	return {}

static func drop_for(state, guardian: String) -> Dictionary:
	for drop in state.seal_drops:
		if drop.guardian == guardian: return drop
	return {}

static func available(state, spec: Dictionary) -> bool:
	if spec.get("kind") != "key" or not spec.has("seal_bearer"): return true
	return not spec.key in state.keys and spec.seal_bearer in state.removed and not drop_for(state,spec.seal_bearer).is_empty()

static func exit_warden_required(state, guardian: String) -> bool:
	return not guardian in state.removed and not guardian in state.legacy_exit_wardens

static func interaction_position(game, spec: Dictionary) -> Vector3:
	if spec.get("kind") == "key" and spec.has("seal_bearer"):
		var drop = drop_for(game.state,spec.seal_bearer)
		if not drop.is_empty(): return Vector3(drop.position[0],drop.position[1],drop.position[2])
	return game.level.layout.world_position(spec.cell)

static func attach_identity(actor, champion: Dictionary) -> Label3D:
	var label = Label3D.new()
	label.name = "SealGuardianIdentity"
	label.text = champion.name+"\n"+(champion.get("seal","").to_upper()+" SEAL" if champion.has("seal") else "DOOR WARDEN")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.font_size = 28
	label.outline_size = 6
	label.pixel_size = .008
	label.modulate = Color(.96,.86,.64)
	label.position.y = actor.get_child(0).shape.height+.55
	actor.add_child(label)
	return label

static func present_identity(actor, label: Label3D) -> void:
	label.visible = actor.hp > 0 and actor.position.distance_to(actor.game.player.position) < 34
	label.modulate = Color(1,.58,.24) if actor.telegraph_time > 0 else Color(.96,.86,.64)
	var seal: String = actor.champion.get("seal","")
	var status: String = seal.to_upper()+" SEAL" if not seal.is_empty() else "DOOR WARDEN"
	if actor.telegraph_time > 0: status += " · COMMITTED — EVADE"
	elif actor.recovery_time > 0: status += " · RECOVERING"
	label.text = actor.champion.name+"\n"+status

static func defeated(game, actor) -> void:
	var spec = bearer_spec(game.level.layout,actor.id)
	if spec.is_empty() or actor.hp > 0 or not actor.id in game.state.removed: return
	var key_id: String = spec.seal_guardian.key_id
	if key_id in game.state.removed or spec.seal_guardian.seal in game.state.keys or not drop_for(game.state,actor.id).is_empty(): return
	# The actor occupied this physical layer. Project only its seal vertically onto
	# its own support; never teleport it to the original floor collectible/exit.
	var cell = Vector2(actor.position.x,actor.position.z)/float(game.level.layout.data.cell_size)
	var point: Vector3 = game.level.layout.surface_position_at_y([cell.x,cell.y],actor.position.y+.08)
	point.y += .2
	game.state.seal_drops.append({"guardian":actor.id,"position":[point.x,point.y,point.z]})
	refresh_markers(game,false)
	game.notify(spec.seal_guardian.name.to_upper()+" FALLS / "+spec.seal_guardian.seal.to_upper()+" SEAL RELEASED",5)

static func refresh_markers(game, restore_corpses: bool) -> void:
	for spec in game.level.layout.data.interactions:
		if spec.get("kind") != "key" or not spec.has("seal_bearer"): continue
		var marker = game.level.markers.get(spec.id)
		if not is_instance_valid(marker): continue
		marker.visible = not spec.id in game.state.removed and available(game.state,spec)
		if not marker.visible: continue
		marker.position = interaction_position(game,spec)
		if restore_corpses: _restore_corpse(game,spec)

static func _restore_corpse(game, key: Dictionary) -> void:
	var spec = bearer_spec(game.level.layout,key.seal_bearer)
	if spec.is_empty() or game.level.has_node("FallenSealBearer_"+spec.id): return
	var corpse = Sprite3D.new()
	corpse.name = "FallenSealBearer_"+spec.id
	corpse.texture = load("res://assets/art/sprites/bodies-v1/"+spec.kind+".png")
	corpse.hframes = 8
	corpse.vframes = 6 if spec.kind == "worker" else 5
	corpse.frame = 32
	corpse.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	corpse.shaded = true
	corpse.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	corpse.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	var cell: int = 256 if spec.kind in ["nursery_warden","choir_avatar"] else 128
	corpse.pixel_size = CORPSE_SCALE[spec.kind]/float(cell)
	corpse.position = interaction_position(game,key)-Vector3.UP*.2
	corpse.position.y += (cell/2.0-8)*corpse.pixel_size
	game.level.add_child(corpse)
