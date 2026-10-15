# Earned Ossuary finale battle

Fixed-clock, normal-clock and expected omitted-fire source replays pass. This is test coverage; the Mac application and full campaign are still unfinished.

The fixture `game/tests/test_ossuary_finale_battle.gd` consumes the actual returned Preparation object from [the checkpoint/gate segment](NC07-earned-ossuary-preparation.md). It retains the same Main, Campaign, Level, Player, profile and 27 original actors. Synthetic native movement and pistol input enter the authored finale region, activate its five original enemies and earn their deaths. The route cannot collect supplies, capture/save, open another gate, exit or replace the world.

## Preserved contract

- Entry resources are 100 health, 200 armor and ammunition `[0,180,32,120,8,0]`, with weapons 0 through 3 owned and the pistol selected. Launcher ammunition does not grant ownership.
- The 22 preceding deaths, their provenance, earlier observers and stored images remain frozen. Five new deaths produce 27 total original deaths without replacements or summons. Damage and ammunition accounting follow actual physics callbacks.
- Preparation's predicted checkpoint bytes remain unchanged. Its saved five-living-actor image stays the recovery image even after the five live actors die; this segment makes no new save.
- The complete eight-waypoint patrol checks native floor, capsule and sweep clearance. Finite projectiles drain through their production lifetimes. Fire, movement, physical E and pending interaction are released before dispatch is cleared.
- Bounds remain 12,000 new physics frames, 600 seconds, 900 frames per leg, 1,800 fight frames and 100 shots. These are test limits, not FPS targets.

The object-returning and boolean APIs share one completion body. The object API refuses its four exact control/omission modes before pin checks or prefix allocation. A future exit flag is allowed. Publication requires the actual successful object and completed input cleanup.

## Recorded checks

| Check | Result |
|---|---|
| Canonical preload/pins and detached inventory | PASS; 213 inherited fixture fields, zero root children or allocated game. |
| History, identity and input-boundary controls | PASS; original/dead aliases, nested fields, older live owners, metadata/images, failures and exact mode refusals. |
| Deliberate guard mutations | PASS; owner, image, other-field and different-dead-alias substitutions trigger their specific assertions. |
| Fixed-clock earned replay | PASS; 1,129 new frames, 21 shots, five new original deaths, 27 total; final ammunition `[0,159,32,120,8,0]`, health 100 and armor 200. |
| Normal-clock earned replay | PASS without a fixed-FPS flag; 1,160 new frames, 21 shots, five new original deaths and 27 total. |
| Current-source omitted-fire replay | PASS; the actual five full originals activate with zero shots and frozen history, then the sole dedicated Battle error occurs. The expected native exit is 1. |
| Debug compilation | The three new Battle warnings were removed. The full inherited fixture still emits 115 older warnings; the new history unit emits none from its own file. |

Accepted native runs require complete merged output, the expected exit and receipts, and clean shutdown. Omission permits only its exact intentional error after the genuine activation READY; other diagnostics reject the run. Engine execution is headless and muted with isolated HOME/temp/data/config/cache paths. These results do not prove packed-app or physical human-input behavior.

The first full positive attempt failed the unchanged 600-second bound after 617 new frames. A subsequent native profile was rejected because its aggregate exceeded the measured window. Neither result is treated as passing performance evidence.

A controlled synchronous experiment then compared the original guard with a narrower metadata transformation. Preparation's saved images are already canonical, so the new guard shallow-copies each metadata row and normalizes only its live owner. It still compares every field, key, image and roster entry, preserves the exact dead-gate alias, and invokes Preparation's older-owner checks. The canonical shared matcher remains unchanged.

For five controlled owners and 2,560 payload rows, seven interleaved measurements produced median times of 3,549 microseconds for the legacy predicate and 218 for the candidate. This measures the test guard only. It establishes neither game FPS nor a memory/GPU improvement. The maintained unit uses deterministic mutation assertions rather than a timing threshold:

```sh
python3 tools/check_game.py tests/test_ossuary_battle_history.gd
```

## Remaining acceptance

Saved exit, actual intermission/Descend, Inversion continuation and the remaining campaign coverage follow separately. Current standalone export, visual fidelity, physical keyboard/mouse/gamepad play, listening and runtime/memory/GPU targets remain open. This test-only change preserves the selected Suno recordings and original MIDI sources.
