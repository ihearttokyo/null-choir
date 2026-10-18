# Earned Reliquary completion

The source-native fixture continues the same Main, Campaign, Player and unique profile through the preceding three maps and the Reliquary. It earns the fourth checkpoint, opens the original gate, defeats the four original Exit actors and uses real virtual Player input to descend. It returns the actual completion menu without starting Nursery.

```sh
python3 tools/check_game.py --timeout 600 tests/test_reliquary_earned_exit.gd
```

The longer command budget covers the continuous prefix. All in-game phase deadlines, shot caps, survival floors and identity assertions remain unchanged.

## Observed fixed-timing paths

Both paths begin after the accepted Catalogue boundary: 86 health, 178 armor, 147 rivets and 32 shells, both seals and discovery 3. The default B route takes the authored health pickup before the checkpoint/rivets. A omits that pickup.

| Path | Fresh physics frames | Pistol shots | Exit deaths | Final health/armor | Rivets/shells |
| --- | ---: | ---: | ---: | --- | --- |
| A | 918 | 18 | 4 Player-attributed | 68 / 170 | 162 / 32 |
| B | 992 | 18 | 4 Player-attributed | 82 / 170 | 162 / 32 |

Each path observed one native crawler contact and one caster projectile birth/player contact. Neither recorded an infighting death. B retains 14 more health for 74 additional physics frames; it remains the default for survival margin, not a claimed engine-performance improvement. Memory and GPU costs were not compared.

## Continuity and regression coverage

- The exact Catalogue source pin is checked before supplied observer or profile adoption. Only `c_enabled` retires; all 30 remaining Catalogue fields and preceding history stay frozen.
- Original actor, capsule, marker and owner identities remain checked. All 31 current original actors must be dead with retired collisions; retained death records alone cannot authorize descent.
- The real checkpoint may trigger before the ammo pickup. Its expected resources, removed IDs, living actor image, facing and exploration use the actual save-time boundary; `level_start` stays unchanged.
- The fresh Nursery live/loaded envelope retains earned resources, difficulty 1 and discovery 3, with entry/zero position, empty keys/removals/exploration and unknown actors/facing. Original scene references drain while Main/profile and completion menu remain.
- The visible, enabled Nursery button must have exactly one `pressed` connection to the same Main's `start_level`. A native intact baseline followed by a wrong-callback mutation exposed the old oracle's false acceptance; the corrected oracle rejects it.

Native controls reject stale current HP, changed frozen Catalogue history, a reparented untouched shell marker, changed checkpoint health, omitted region approach and omitted descent input. The wrong-pin control rejects before adoption and checks only unique fixture paths, never the absence of an unrelated default save. A detached yaw assertion covers float32 positive/negative PI boundaries.

The initial door-child assumption and an independent yaw-oracle mismatch were setup failures, not the intended gate RED. The corrected omitted-gate run reached its exact native input/checkpoint/door-retirement assertion. Independent correctness and Ponytail reviews accepted the final source and control helpers after the callback correction.

## Evidence limits

These are source-native virtual-input and scripted-aim checks. They do not establish physical controls, rendered art/HUD parity, packed-app behavior, listening/PCM quality, GPU or memory gains, both seal orders/all difficulties, a full human campaign or final release acceptance. The current ordinary-timing command passes in 477.551 seconds. It matches normalized Exit shot cadence, attributed damage, resources and final handoff bytes. Its end counter is 994 rather than 992 frames because post-completion process waits are bounded rather than identical; checkpoint bytes vary with save-time pose and are independently checked on each path. This is not exact whole-prefix frame determinism. Deployment integration remains separate.
