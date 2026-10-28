extends RefCounted
## Source-only static Level.build fixtures; this is not a played or restored campaign.
const Campaign = preload("res://scripts/campaign.gd")
const Layout = preload("res://scripts/level_data.gd")
const Supply = preload("res://scripts/earned_supplies.gd")

static func fresh_selected(index: int, difficulty: int = 1):
	if index < 0 or index >= 8: return null
	var layout = Layout.new()
	if not layout.load_level(index):
		push_error("STATIC LEVEL FIXTURE: selected authored layout failed to load: "+str(index))
		return null
	var state = Campaign.new()
	state.new_campaign(difficulty)
	# Explicit fixture selection, not a change to saved/current/checkpoint state.
	state.level_index = index
	state.floor_revision = layout.floor_revision()
	state.earned_supply = Supply.fresh(layout)
	if state.earned_supply.is_empty():
		push_error("STATIC LEVEL FIXTURE: no authoritative finite registry for selected layout: "+str(index))
		return null
	state.mark_checkpoint("entry",layout.world_position(layout.data.spawn))
	if not Supply.valid(state.earned_supply,state.to_dict(),layout,state.difficulty):
		push_error("STATIC LEVEL FIXTURE: selected finite snapshot failed source validation: "+str(index))
		return null
	return state
