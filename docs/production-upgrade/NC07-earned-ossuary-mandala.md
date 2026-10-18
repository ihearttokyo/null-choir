# Earned Ossuary mandala loop

This source-native regression continues the accepted five-map prefix and first Ossuary loop without replacing Main, Campaign, profile, Level or Player. Earlier Main, fixture and witness records stay frozen. A separate witness independently tracks the mandala approach, Ivory seal and return to the junction.

The route must earn eleven additional original deaths, both seals and all four authored supply scans. Five finale originals remain dormant and undamaged; the transfer gate stays closed. The predecessor save and recovery snapshots remain unchanged. Story, the launcher, finale and later maps remain outside this slice. Story lies on a detour from the first loop.

## Current evidence

The fixed-FPS replay passed in 828.735 seconds. The new phase used 2,589 physics frames and 56 pistol shots, ending at 92 health, 196 armor and ammunition [0,169,32,120,0,0]. All eleven new original deaths had production provenance, bringing the cumulative Ossuary count to 22. Two actual guardian projectile births were reconciled, all projectiles drained, and the predecessor save SHA stayed unchanged. These are measured results, not a hardcoded cross-clock outcome oracle.

The omitted-Ivory replay reached its absent-key, live-marker, unentered-return and frozen-prior-record precondition, then produced only the intended refusal (583.639 seconds, expected exit1). Its approach and interaction bytes are unchanged by the later return-waypoint fix. The public normal-clock replay also passed (1,320.404 seconds): 4,081 new-phase frames, 56 shots, three guardian projectile births and the same final resources/save. Frame and release counts differ across clocks; the independent earned-state assertions pass in both.

Twenty-two controlled native cases cover actual pistol, caster-projectile and crawler-melee shield contacts; malformed birth records; duplicate births/contacts; forged release; stale Level/Player contacts; and a same-ID replacement shooter. Observer refusal is distinguished from production damage suppression. Another case kills a shooter through real worker attacks before resuming its admitted projectile. These positioned, frozen-actor controls are not earned gameplay.

Raw-source controls reproduce zero-direction birth and overwritten-release failures. Held-key controls reproduce Blood release failure and detect removal of segment-owned Ivory release even when inherited cleanup releases physical E. Independent correctness and Ponytail reviews cover the corrected sources and retained control evidence.

## Route corrections

The first stationary fight could not finish before the player traversed the northern room. It now follows that traversal; both fights and every earned assertion remain required. The original failure did not record its terminal shot count, so line-of-sight versus shot-cap refusal remains unresolved for that old version.

A second failure came from whole-leg clearance seeing an inactive worker beyond the encounter boundary. The route now visits [20.75,11.5] before [19.5,11.5], crossing the Ivory-gated region before the worker blocks travel. A controlled native check proves the old leg is blocked, the short leg is clear, and real Player movement activates the three original return actors once. Its seeded pose/key and frozen AI are explicitly controlled evidence. Production maps, actors and combat behavior were not changed.

## Running the checks

The full positive uses the strict public runner:

```sh
python3 tools/check_game.py --timeout 1800 tests/test_ossuary_second_loop.gd
```

Run the mixed positive/negative controls through their strict wrapper:

```sh
python3 tools/check_ossuary_guards.py
python3 tests/test_ossuary_guard_runner.py
```

The wrapper isolates user data and waits for process exit before checking the complete output. It requires the exact final receipt and exact multiplicities of all 18 intentional rejection labels, then rejects every other error, warning or leak diagnostic. The ordinary public runner deliberately rejects mixed-error output.

## Limits

Synthetic native input is not physical playtesting, visual fidelity, audio quality, GPU performance or packed-app acceptance. This slice does not complete Ossuary or the campaign.
