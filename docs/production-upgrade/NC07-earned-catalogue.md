# Earned Catalogue route

This fixture continues the actual earned first-three-map, Halo, Blood/story, west-return, Wheel, Ivory and Wheel-return sequence with the same observer and scene. It activates the original both-seal-gated Catalogue region and requires five original native deaths before closure at cell `[17.5,9.25]`.

The fresh phase retains four 240-frame hops, including settling, 480 combat frames and 246 projectile-drain frames: at most 1,686 physics frames and 30.1 wall seconds. Pistol fire is capped at 40 shots and health must remain above 24. Earlier budgets remain unchanged. Only `v_enabled` retires; all 27 other Wheel-return fields and earlier observations stay frozen.

## First native evidence

The corrected candidate passes in 107.707 seconds with 822 phase frames and 20 pistol shots. All five deaths are attributed to the Player. Two worker attacks each deal ten damage with three armor absorbed; final resources are 86 health, 178 armor, 147 pistol rounds and 32 shells. Two caster projectiles are born, one makes a nonfatal enemy contact and both drain. Player projectile contacts, crawler contact and infighting deaths are unobserved. The phase observations match the original candidate apart from measured wall time.

Closure takes 177 frames and drain takes 246. All 31 original actors and capsules remain checked: 22 prior corpses and the four inactive Exit actors retain their accepted state. Every marker keeps its identity and level parent. Pickups and the checkpoint remain untouched; both seals, story discovery, entry/start, actor image and saved-file digest remain checked. The automatic HUD model and seven native labels match the resource ledger.

Omitting the approach reaches only the intended activation refusal after the actual prefix and Catalogue setup. These results use virtual Input and scripted aim in the source engine; they do not establish rendered pixels, physical controls, listening, GPU, performance, packed-app or complete fourth/eight-level acceptance.

The ordinary-wall replay passes in 460.119 seconds through `python3 tools/check_game.py --timeout 480 tests/test_reliquary_catalogue.gd` from the project root, using an isolated test HOME. Its phase frames, relative shot cadence, damage, resources, releases, projectile counts, deaths and closure match the accelerated run. The endpoint differs by 0.00001 meters; global prefix clock offsets differ. These comparisons leave the actual native endpoint and phase assertions unchanged.

## Failure controls and review

Both initial independent review streams ended without final verdicts after recorded WebSocket idle errors. Serial resumes of the same reviewers produced completed reports. Correctness review exposed a stale-witness hole: the earning guard accepted a revived original actor while its recorded death remained intact. A narrow native counterfactual reproduced that acceptance; the corrected guard requires every bound Catalogue original's current HP to be zero. The same counterfactual is rejected and the real route still passes.

Current-source correctness and Ponytail delta reviews are clean, including the baseline-first stale-death control. Earlier reads and interrupted streams are retained separately.

Post-review native controls verify:

- A consistent missing-finish case establishes intact earning before its isolated mutation, then fails the direct five-death guard.
- A single changed retired Wheel-return witness fails the frozen-history guard.
- Stopping the automatic HUD updater fails the stale-resource model guard after actual combat and closure.
- Reparenting an untouched marker, while retaining its dictionary entry and reference, fails the level-owner guard.
- A deliberately mismatched helper pin rejects before adoption and frees the detached observer; only unique fixture filenames are checked.

Omitted fire reaches the original protected health stop before the direct earning guard. The safety threshold and combat limit remain unchanged; the stale-death and consistent missing-finish controls independently exercise the earning guard. Counterfactual harnesses and mutated pin copies stay local, outside Git. Similar older ownership and stale-current-HP predicates remain a separate, bounded followup.

Rollback removes only the candidate fixture overlay. Production, original art, scores and the current private release remain unchanged.
