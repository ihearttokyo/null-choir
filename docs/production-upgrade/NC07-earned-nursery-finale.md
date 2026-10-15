# Earned Nursery finale and Ossuary entry

## Contract

The source fixture continues the same earned Main, Campaign and save profile through the first four maps and both Nursery loops. It freezes every completed observer, then reaches the optional Nursery story, actual supplies and checkpoint, opens the two-key growth gate with queued physical-key input and fights the seven original finale actors, including the 1,200-HP Warden.

Acceptance requires all 29 original Nursery deaths, independently reconciled resources and native damage provenance. The real descent must save a fresh Ossuary handoff, show the connected restored intermission, retire the original scene and use its actual Descend signal to start a fresh sixth-map Player and all 27 original actors. Live entry recovery and Survey are checked separately from the persisted zero-position handoff.

The earned path grants no inventory, teleports no actors, assigns no damage and bypasses no attacks. Input is synthetic native input, not physical controls.

## Native evidence

The retained baseline runs use Standard difficulty (index 1) and source SHA256 70d30c476ecfd7a265ddf7382991ff801e94323484cff6dfc6c6a68210365dac. They precede the stronger outcome oracle and remain historical observations, not current-head reruns.

Both runs pass with the same 81 new-phase pistol shots, 93 HP, 197 armor, ammo [0,99,32,120,0,0], owned weapons [0,1,2,3] and selected weapon 1. Their persisted handoff SHA256 is 15353b6ea7d39856fcd975c2195d391bfdd7cc2f17d567022945bd749f4558ce.

| Run | Whole-run wall time | New-phase physics frames | Ossuary entry frames |
| --- | ---: | ---: | ---: |
| Fixed-fps source diagnostic | 112.637 s | 3,737 | 2 |
| Unmodified public runner, normal clock | 643.128 s | 3,761 | 6 |

These timings are test execution costs, not game performance measurements. Frame and pose timing vary; the earned budget and persisted save match.

The regression now requires all four variant/phase pairs, exactly 81 shots, the explicit resource vector and the fixed final save digest. A focused predicate test rejects missing pairs and changed outcomes; either named forged-source flag selects its negative path when used alone.

Both runs observe Warden variants 0 and 1 in each of its two phases and 884 actual projectile steps. Neither records a charge hit. Separate controlled tests cover charge contact; the earned route does not claim that coverage.

Omitting gate E, exit E or the actual Ossuary Descend signal yields its sole intended refusal. A deliberately wrong predecessor pin refuses before scene/profile adoption and frees only the detached observer. The self-contained ordering fixture retains three same-tick positive cases and two explicitly forged-source negative modes, including an already-set rush flag.

## Reproduction

Use an isolated test profile and the existing public runner. The full earned prefix needs the longer deadline.

~~~sh
python3 tools/check_game.py --timeout 840 tests/test_nursery_finale_loop.gd
python3 tools/check_game.py tests/test_warden_contact_order.gd
~~~

The named --forged-melee-source and --forged-rush-hit modes are deliberate negative controls. Their direct event/damage calls never enter the earned route.

## Failures retained and limits

Initial schema attempts failed because strict nested JSON comparisons distinguished expected integers from parsed floats. Correcting only the expected door height/yaw and actor-yaw types preserved the original map, numeric values and every strict schema, pose, capsule, ownership and save assertion.

An initial negative report also retained the positive case label because Dictionary.merge defaults to preserving existing keys. The overwrite flag and exact-label checks correct that reporting defect; earlier logs remain historical evidence.

Independent correctness and Ponytail reviews cover the source and retained regressions. These checks do not establish a played eight-level campaign, physical mouse/gamepad, final visual fidelity, hearing, GPU performance or the updated standalone app. The new coverage ends at fresh Ossuary entry; its combat and the final two maps remain separate work.

Rollback removes these test helpers and documentation without changing gameplay, authored maps, assets, soundtrack or saves.
