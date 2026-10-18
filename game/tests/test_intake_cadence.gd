extends SceneTree

const Counter = preload("res://tests/test_intake_combat.gd").CombatMain
const Player = preload("res://scripts/player.gd")
var failures: int = 0

func _initialize() -> void:
	var interval_ticks: float = Player.WEAPONS[1].interval*60.0
	expect(is_equal_approx(interval_ticks,12.6),"Fixture pins the approved 210ms pistol at 60Hz")
	expect(trace_ok([673,686,699,711],interval_ticks),"Exact live witness: 13/13/12 gaps retain nominal phase and finite ammo")
	var ordinary: Array = []
	for shot in range(125): ordinary.append(673+ceili(float(shot)*interval_ticks-0.000001))
	expect(trace_ok(ordinary,interval_ticks),"All 125 finite rounds retain cumulative configured rate through exhaustion")
	for illegal in [[673,685],[673,686,698],[673,686,699,710],[673,686,699,711,723],[673,686,686],[673,686,685]]:
		expect(not trace_ok(illegal,interval_ticks),"Reject early phase, cumulative overrate, duplicate or reversed ticks: "+str(illegal))
	var all_twelve: Array = []
	for shot in range(20): all_twelve.append(673+shot*12)
	expect(not trace_ok(all_twelve,interval_ticks),"All-12 gaps cannot gain ammunition-weapon rate")
	for invalid in [[0,124,1,true],[1,125,1,true],[2,124,1,true],[1,124,0,true],[1,124,1,false],[126,-1,1,true]]:
		expect(Counter.accepted_shot_slot(673,-1,-1.0,interval_ticks,invalid[0],invalid[1],invalid[2],invalid[3]) < 0.0,"Counter ordering, exact ammo, held pistol and finite supply remain mandatory: "+str(invalid))
	expect(Counter.accepted_shot_slot(723,711,-1.0,interval_ticks,5,120,1,true) < 0.0,"Observed release ends phase and requires full last-shot recovery")
	expect(is_equal_approx(Counter.accepted_shot_slot(724,711,-1.0,interval_ticks,5,120,1,true),736.6),"Recovered repress starts a new phase at acceptance, not old repeat debt")
	var after_miss: float = Counter.accepted_shot_slot(740,711,723.4,interval_ticks,5,120,1,true)
	expect(is_equal_approx(after_miss,748.6),"Late acceptance skips missed nominal slots, without inventing extra accepted shots")
	expect(Counter.accepted_shot_slot(740,740,after_miss,interval_ticks,6,119,1,true) < 0.0,"A missed slot never permits a same-tick catch-up burst")
	expect(Counter.accepted_shot_slot(748,740,after_miss,interval_ticks,6,119,1,true) < 0.0,"Missed-slot continuation still rejects the next early phase")
	expect(Counter.accepted_shot_slot(749,740,after_miss,interval_ticks,6,119,1,true) > 749.0,"Missed-slot continuation can resume at the future nominal deadline")
	expect(trace_ok([673,700,730],interval_ticks),"Passive ceiling does not force faster shots or repay skipped slots")
	if failures == 0: print("PASS pure Intake passive cadence oracle; synthetic counters only, no Main.shot/gameplay/audio/GPU/app acceptance")
	quit(0 if failures == 0 else 1)

func trace_ok(ticks: Array, interval_ticks: float) -> bool:
	var last: int = -1
	var slot: float = -1.0
	var count: int = 0
	for tick in ticks:
		count += 1
		slot = Counter.accepted_shot_slot(tick,last,slot,interval_ticks,count,125-count,1,true)
		if slot < 0.0: return false
		last = tick
	return true

func expect(condition: bool, detail: String) -> void:
	if condition: return
	failures += 1
	push_error(detail)
