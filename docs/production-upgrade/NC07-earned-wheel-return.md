# Earned Reliquary Wheel return

`game/tests/test_reliquary_wheel_return.gd` continues the live earned first-three-map, Reliquary entry, Halo, Blood/story, west-return, Wheel and Ivory sequence. It activates the original Ivory-gated return region and requires the three original actors, 19–21, to die through witnessed native combat before closing at cell `[21,12.5]`.

The new epoch retires only `w_enabled` and freezes all 36 remaining Wheel fields and earlier observations. The same Main, Campaign, Player, map, profile and 31 original actor/capsule identities remain checked. Nineteen prior corpses and nine later inactive actors retain their accepted state. Recovery, checkpoint, actor-image and saved-file checks remain active.

Thirteen hops keep their 240-frame limits, including settling. Combat is capped at 240 frames and 24 pistol shots; closure drains six measured frames. The fresh phase budget is 3,366 physics frames and 58.1 wall seconds. Earlier phase limits remain unchanged. The outer process deadline is 150 seconds for the cumulative route, not a replacement for the individual phase guards.

## Native results

The corrected accelerated source-native run passes in 93.916 seconds. Its return phase takes 1,287 frames, uses 13 pistol shots and attributes all three deaths to the Player. The original recess pickup restores 14 health; the original rivet pickup adds 32 capped rounds before activation and fire. Final resources are 100 health, 184 armor, 167 pistol rounds and 32 shells. Closure takes 65 frames, followed by six drain frames. Two worker attacks occur; damage, positive contacts and infighting deaths are unobserved.

The normal-wall replay passes in 447.329 seconds through the unchanged public test runner. Its phase frames, relative shot/cadence observations, supplies, resources, closure, role releases and deaths match the accelerated run. Global prefix clock offsets differ. Run from the project root with `python3 tools/check_game.py --timeout 480 tests/test_reliquary_wheel_return.gd`; use an isolated test HOME to preserve player data.

The automatic HUD model and seven native labels must show both earned seals, `OPEN GATE` and the independent resource ledger. Shells and all later branch markers retain their original owners. These assertions cover native model/text, not rendered pixels.

## Failure controls and review

An independent correctness review found that node identity and the marker dictionary did not prove level ownership. An actual reparent-only counterfactual passed the original ownership check. Adding the parent assertion rejects that counterfactual, and the normal route still passes with unchanged observations.

Retained isolated native controls verify:

- Omitted approach fails the original-region activation guard.
- Omitted fire fails the direct three-death earning guard with all three original survivors.
- A consistent living-original counterfactual first proves intact earning, then fails that same guard.
- Changing only the retired Wheel witness fails the frozen-history guard.
- Freezing the actual automatic HUD updater fails the stale-resource model guard.
- A deliberate helper-pin mismatch rejects before scene/profile adoption and frees the fresh observer. Its oracle checks only unique fixture filenames; mutated sources and counterfactual harnesses stay outside Git.

Current-source Astra correctness and Sol Ponytail reviews are clean, including the ownership correction and retained harnesses. Similar older ownership predicates remain a separate followup; this change preserves its upstream pins.

This evidence uses virtual Input and scripted aim in the actual source engine. Full fourth/eight-level completion, physical controls, GPU, audio, performance and current standalone acceptance remain open. Runtime gameplay, maps, art and scores are unchanged.
