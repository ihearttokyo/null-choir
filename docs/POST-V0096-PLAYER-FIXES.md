# v0.097 candidate — readable pursuit and automatic fast movement

Status: local implementation, not released or independently accepted. Public v0.096 remains the current qualified download.

Jared reported ordinary creatures becoming invisible, sluggish pursuit and a run-key requirement. Automatic fast movement has **no slow-walk modifier**. The old `run` preference binding remains serialized for compatibility but has no movement effect and is omitted from the controls menu. Existing analog strength, 35Hz-inspired acceleration, friction, collision/slide and pause safety remain unchanged. This is Doom-inspired movement, not exact engine/input parity.

Ordinary live actors now carry a bounded front-facing readability light. It is unshadowed and affects only the actor render layer, not world architecture. Critical equipment/seal/warden actors retain their brighter, shadowed practical and corpse readability. Atlases remain shaded, depth-tested, nearest-filtered and bound to their original hit regions. No global ambient fill, fullbright creature replacement or new artwork is introduced. Actual all-chapter visibility and aggregate native lighting cost remain unqualified.

Crawler, worker, caster, brute, guardian, Warden and Avatar pursuit speeds increase while the summoner retains its stationary role. Crawler lunges commit at18m/s for0.32s with locked aim, readable windup, native collision and single-contact recovery. Brute and Warden charge ranges now derive from their actual finite travel and contact reach; their displayed charge lanes share that authority. The Warden's alternate ranged attack remains separate. Crawler attack pose now persists throughout its longer lunge.

## Evidence so far

- Normal Godot4.7.2 headless import: exit0, no script/import errors.
-270 arranged native movement start/reverse/coast-stop cases across rotated digital/analog directions, with the legacy modifier held/released: PASS. Native wall-slide/corner checks: PASS.
- Arranged real crawler AI/native physics: a meaningful closing lunge with one contact; a lateral dodge escaping the locked aim over a full charge; a wall stopping the charge. Full-charge attack-pose observations pass.
- Actual configured brute/Warden floor settling and charge-lane checks: PASS after repairing the flat fixture's missing current floor-support API. Original failed diagnostic retained privately.
- Synthetic supported corridor/obstruction and ordinary enemy telegraph checks: PASS. Actual enemy damage, infighting, attack/death pose and one-shot corpse removal: PASS.
- Local-light configuration/ownership microtest: PASS. This does not establish rendered visibility.
- Sprite-direction check emitted resource-leak diagnostics at shutdown; it is not a clean pass and remains to be repaired/rechecked.

These use isolated test profiles and arranged fixed-clock native physics; they do not establish physical human control feel, rendered quality, sustained FPS, earned campaign balance, save/Continue qualification or a standalone package. Prior v0.096 screenshots are historical, not images of this changed gameplay source. Required current-pixel checks, affected recovery/art qualification, independent review, signing/notarization, release/README and the same live Site update remain open. Original artwork/audio, saves and rollback builds remain preserved.
