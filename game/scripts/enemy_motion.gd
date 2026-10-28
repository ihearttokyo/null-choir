extends RefCounted
## Authoritative pace/charge constants. No state, artwork, damage or save writes.
## Late-role walking speeds remain Enemy.LATE's single active authority.
const REGULAR_SPEEDS = {"crawler":7.6,"worker":4.4,"caster":3.8}
const STRAFE_SPEEDS = {"worker":2.8,"caster":2.4}
const CHARGES = {
	"crawler":{"speed":18.0,"seconds":0.32,"contact":1.9,"commit_cap":7.0},
	"brute":{"speed":18.0,"seconds":0.75,"contact":2.4,"commit_cap":30.0},
	"nursery_warden":{"speed":16.0,"seconds":0.65,"contact":2.4,"commit_cap":30.0}}

static func charge_speed(role: String) -> float:
	return float(CHARGES.get(role,{}).get("speed",0.0))

static func charge_seconds(role: String) -> float:
	return float(CHARGES.get(role,{}).get("seconds",0.0))

static func charge_distance(role: String) -> float:
	return charge_speed(role)*charge_seconds(role)

static func commit_range(role: String, variant: int = 0) -> float:
	# Warden's alternate volley still retains its original30m range.
	if role == "nursery_warden" and variant != 0: return 30.0
	if not CHARGES.has(role): return 30.0
	var profile: Dictionary = CHARGES[role]
	return minf(float(profile.commit_cap),charge_distance(role)+float(profile.contact))
