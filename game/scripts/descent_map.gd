extends RefCounted

# Presentation only. Progress remains the existing validated Campaign state.
const LEVEL_NAMES = ["The Intake", "The Foundry", "The Processional", "The Reliquary", "The Nursery", "The Ossuary", "The Inversion", "The Heart"]

static func overview(campaign) -> Dictionary:
	var depth: int = clampi(campaign.level_index, 0, LEVEL_NAMES.size())
	var rows: Array = []
	var recovered: int = 0
	for index in LEVEL_NAMES.size():
		var found: bool = index in campaign.discoveries
		if found: recovered += 1
		rows.append({"index": index, "name": LEVEL_NAMES[index] if index <= depth else "Uncharted descent",
			"status": "CLEARED" if index < depth else ("CURRENT" if index == depth else "UNREACHED"), "record_found": found})
	var blood: bool = "blood" in campaign.keys
	var ivory: bool = "ivory" in campaign.keys
	var objective: String = "The descent is complete. Recovered records remain available below."
	if depth < LEVEL_NAMES.size():
		if blood and ivory:
			objective = "Both seals recovered. Find the exit; remaining encounters may still bar the route."
		elif blood:
			objective = "Blood seal recovered. Search the current level for the Ivory seal."
		elif ivory:
			objective = "Ivory seal recovered. Search the current level for the Blood seal."
		else:
			objective = "Recover the Blood and Ivory seals. Explore both routes and watch for optional records."
	return {"rows": rows, "cleared": depth, "records": recovered, "blood": blood, "ivory": ivory, "objective": objective}
