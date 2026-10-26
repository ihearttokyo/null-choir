extends SceneTree

const Campaign = preload("res://scripts/campaign.gd")
const DescentMap = preload("res://scripts/descent_map.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var campaign = Campaign.new()
	campaign.new_campaign(1)
	var before: Dictionary = campaign.to_dict().duplicate(true)
	var view: Dictionary = DescentMap.overview(campaign)
	assert(view.rows.size() == 8 and view.cleared == 0 and view.records == 0)
	assert(view.rows[0].name == "The Intake" and view.rows[0].status == "CURRENT")
	for index in range(1,8):
		assert(view.rows[index].name == "Uncharted descent" and view.rows[index].status == "UNREACHED")
		assert(not view.rows[index].record_found)
	assert(not view.blood and not view.ivory and "Recover the Blood and Ivory" in view.objective)
	view.rows[0].name = "Presentation changed"
	assert(campaign.to_dict() == before and DescentMap.overview(campaign).rows[0].name == "The Intake")
	# Controlled progress presentation, not an earned campaign claim.
	campaign.level_index = 3
	campaign.discover(0)
	campaign.discover(2)
	campaign.keys = ["ivory"]
	before = campaign.to_dict().duplicate(true)
	view = DescentMap.overview(campaign)
	assert(view.cleared == 3 and view.records == 2 and view.ivory and not view.blood)
	assert(view.rows[2].status == "CLEARED" and view.rows[3].status == "CURRENT")
	assert(view.rows[3].name == "The Reliquary" and view.rows[4].name == "Uncharted descent")
	assert(view.rows[0].record_found and view.rows[2].record_found and not view.rows[1].record_found)
	assert("Blood seal" in view.objective and campaign.to_dict() == before)
	campaign.keys.append("blood")
	assert("Both seals recovered" in DescentMap.overview(campaign).objective)
	campaign.level_index = 8
	view = DescentMap.overview(campaign)
	assert(view.cleared == 8 and "descent is complete" in view.objective)
	for row in view.rows: assert(row.status == "CLEARED" and row.name != "Uncharted descent")
	print("PASS descent map: eight depths, spoiler-safe progress, earned record membership, seal objectives and detached read-only presentation; controlled state, not campaign completion")
	quit()
