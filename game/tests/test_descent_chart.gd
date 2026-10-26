extends SceneTree
const Chart = preload("res://scripts/descent_chart.gd")
const Overview = preload("res://scripts/descent_map.gd")
const Campaign = preload("res://scripts/campaign.gd")
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 for depth in range(9):
  var campaign = Campaign.new()
  campaign.new_campaign(1)
  campaign.level_index = depth # Arranged presentation state, not earned traversal.
  var before = campaign.to_dict().duplicate(true)
  var view = Overview.overview(campaign)
  var chart = Chart.new()
  chart.configure(view)
  root.add_child(chart)
  await process_frame
  var art = chart.get_child(1)
  assert(art.rows.size() == 8 and art.textures.size() == mini(8, depth + 1))
  assert(not art.is_processing() and art.phase == 0.0)
  for index in range(8):
   assert(art.textures.has(index) == (index <= depth))
   if art.textures.has(index):
    assert(art.textures[index] is Texture2D)
    assert(art.textures[index].get_width() == 640 and art.textures[index].get_height() == 360)
   else:
    assert(art.rows[index].name == "Uncharted descent")
  assert(campaign.to_dict() == before)
  view.rows[0].name = "Not shared"
  assert(art.rows[0].name != "Not shared")
  chart.free()
 await process_frame
 print("PASS native illustrated chart: all nine progress states, earned-only textures, compact dimensions, detached rows, motion off and unchanged campaign; no earned-playthrough/rendered-pixel claim")
 call_deferred("quit", 0)
