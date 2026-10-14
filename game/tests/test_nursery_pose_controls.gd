extends "res://tests/test_nursery_earned_campaign.gd"
func run() -> void:
    if not await walk_through_nursery(NurseryCampaignMain.new()):
        await finish(1)
        return
    var accepted = []
    for field in ["position","yaw","pitch"]:
        var old = game.state.get(field)
        game.state.set(field,old+Vector3(1,0,0) if field=="position" else old+0.2)
        accepted.append(nursery_segment_result())
        game.state.set(field,old)
        if not nursery_segment_result():
            await finish(1)
            return
    print("POSE_CORRUPTION_ACCEPTED ",accepted)
    var valid = expect(accepted==[false,false,false],"NATIVE RED current position/yaw/pitch corruptions must each reject without touching physical Player")
    await finish(0 if valid else 1)
