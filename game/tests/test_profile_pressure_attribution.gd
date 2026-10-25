extends "res://tests/test_profile_pressure.gd"

class AttributionMain:
	extends "res://tests/test_profile_pressure.gd".PressureMain
	var spans: Array = []
	var events: Array = []
	var saves: int = 0
	var collections: Array = []
	func update_passive_triggers(observer: CharacterBody3D) -> void:
		if not tracing:
			super.update_passive_triggers(observer)
			return
		var started: int = Time.get_ticks_usec()
		var first: int = events.size()
		super.update_passive_triggers(observer)
		spans.append({"tick":ticks-start_tick,"start_us":started,"elapsed_us":Time.get_ticks_usec()-started,"events":events.slice(first)})
	func _passive_trigger_visible(spec: Dictionary) -> bool:
		if not tracing: return super._passive_trigger_visible(spec)
		var started: int = Time.get_ticks_usec()
		var result: bool = super._passive_trigger_visible(spec)
		events.append({"kind":"visible","id":spec.id,"tick":ticks-start_tick,"elapsed_us":Time.get_ticks_usec()-started,"visible":result})
		return result
	func collect_pickup(id: String) -> void:
		if not tracing:
			super.collect_pickup(id)
			return
		var started: int = Time.get_ticks_usec()
		super.collect_pickup(id)
		var event: Dictionary = {"kind":"pickup","id":id,"tick":ticks-start_tick,"elapsed_us":Time.get_ticks_usec()-started,"collected":id in state.removed}
		events.append(event)
		collections.append(event)
	func _save() -> Error:
		if not tracing: return super._save()
		var started: int = Time.get_ticks_usec()
		var result: Error = super._save()
		saves += 1
		events.append({"kind":"save","elapsed_us":Time.get_ticks_usec()-started,"result":result})
		return result

func make_main():
	return AttributionMain.new()

func finish(status: int) -> void:
	if is_instance_valid(game):
		if status == 0:
			var earned: Array = game.collections.filter(func(event): return event.collected)
			if not expect(game.spans.size() == PROFILE_TICKS and game.saves == 0 and earned.map(func(event): return event.id) == ["entry_ammo","upper_ammo"] and game.collections.map(func(event): return event.id) == ["entry_ammo","west_health","west_health","upper_ammo"],"Attribution covers every1440 passive callback, two earned pickups/two full-health rejections and no checkpoint/save"):
				status = 1
		var top: Array = []
		for index in range(game.spans.size()):
			var row: Dictionary = game.spans[index].duplicate()
			row["previous_start_gap_us"] = row.start_us-game.spans[index-1].start_us if index > 0 else null
			row["next_start_gap_us"] = game.spans[index+1].start_us-row.start_us if index+1 < game.spans.size() else null
			top.append(row)
		top.sort_custom(func(a,b): return a.elapsed_us > b.elapsed_us)
		var totals: Dictionary = {}
		for event in game.events:
			if not totals.has(event.kind): totals[event.kind] = {"calls":0,"elapsed_us":0,"max_us":0}
			totals[event.kind].calls += 1
			totals[event.kind].elapsed_us += event.elapsed_us
			totals[event.kind].max_us = maxi(totals[event.kind].max_us,event.elapsed_us)
		print("PRESSURE_ATTRIBUTION ",JSON.stringify({"spans":game.spans.size(),"saves":game.saves,"collections":game.collections,"nested_totals":totals,"top":top.slice(0,8),"scope":"inclusive elapsed only, including timer/instrumentation and possible host interruption; no extra rays or manual gameplay calls; adjacent start gaps include normal60Hz pacing, not CPU work"}))
	await super.finish(status)
