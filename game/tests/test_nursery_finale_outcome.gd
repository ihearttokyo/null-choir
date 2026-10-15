extends SceneTree
const Finale = preload("res://tests/test_nursery_finale_loop.gd")
const RESULT = {"health":93,"armor":197,"ammo":[0,99,32,120,0,0],"owned_weapons":[0,1,2,3],"weapon":1}
const SAVE = "15353b6ea7d39856fcd975c2195d391bfdd7cc2f17d567022945bd749f4558ce"
var failures: Array = []
func _initialize() -> void: call_deferred("run")
func check(label: String, actual: bool, expected: bool) -> void:
    print("FINALE_OUTCOME_CASE ",label," actual=",actual," expected=",expected)
    if actual != expected: failures.append(label)
func run() -> void:
    var attacks: Array = [[1,0,0,1,Vector3.ZERO],[2,1,0,1,Vector3.ZERO],[3,0,1,1,Vector3.ZERO],[4,1,1,1,Vector3.ZERO]]
    check("retained",Finale.finale_outcome_matches(attacks,81,RESULT,SAVE),true)
    for i in range(4):
        var missing: Array = attacks.duplicate(true)
        missing.remove_at(i)
        check("missing_pair_"+str(i),Finale.finale_outcome_matches(missing,81,RESULT,SAVE),false)
    for count in [0,80,82,111]:
        check("shots_"+str(count),Finale.finale_outcome_matches(attacks,count,RESULT,SAVE),false)
    for field in ["health","armor","ammo"]:
        var changed: Dictionary = RESULT.duplicate(true)
        if field == "ammo": changed.ammo[1] -= 1
        else: changed[field] -= 1
        check("drift_"+field,Finale.finale_outcome_matches(attacks,81,changed,SAVE),false)
    for digest in ["","0".repeat(64)]:
        check("save_"+str(digest.length()),Finale.finale_outcome_matches(attacks,81,RESULT,digest),false)
    if failures.is_empty(): print("PASS focused synthetic finale outcome predicate; not combat/campaign/app acceptance")
    else: push_error("NATIVE RED finale oracle admitted missing pair or changed retained outcome: "+str(failures))
    quit(0 if failures.is_empty() else 1)
