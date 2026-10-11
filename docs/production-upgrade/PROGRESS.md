# Production upgrade progress

## NC-01: heading-independent movement

The shared player callback now approaches desired planar velocity with one vector step. Speed remains9m/s, acceleration remains50m/s², and Input.get_vector(), native capsule, gravity, floor snap and mouse look are unchanged. The native fixture exercises135 forward/strafe/diagonal start/full-reversal/stop cases at five yaws and three action strengths. Each tick checks an independent scalar distance budget, actual displacement and settled floor contact.

The old component-axis source fails the retained native regression. Omitting move_and_slide() also fails, so a stationary player cannot pass by reporting a plausible velocity. A low analog speed can stop in one tick without displacement; that valid case is preserved. Two independent-review fixture findings were fixed before broader validation.

Run from the project root:

```sh
python3 tools/check_game.py tests/test_movement_response.gd
```

The retained parent trials use official Godot4.7.2, headless/Dummy audio and a fixed60 simulation. They establish source-native behavior under virtual input, not physical-controller comfort, GPU presentation or a packaged playthrough. Thirteen focused checks, all sixteen controlled authored loops, and an additional native wall-slide/corner fixture pass. A wall-collision-disabled mutation fails the contact fixture. Current-head review receipts remain outside Git.

## Existing independent candidates

PR35 retains the sharper-world/pixel-HUD experiment; no competing renderer patch was made. The separately reviewed Nursery source candidate preserves the original source and other102 asset entries. Its reference-richness, in-game transparency and performance remain separate acceptance checks. All prior releases, source originals and failed experiments are retained.

## Continuation

Next implement NC-02 through the actual input, readiness, accepted-shot-age and HUD callers after freezing its lifecycle tests. Preserve all six weapon behaviors, dry fallback, stale/reentrant callback guards and asynchronous menu/placement regressions. All14 spec contracts and section19 gates remain in scope. Source progress does not complete the full campaign/app goal.

## NC-10: geometric ramp normals

Floor and ceiling normals now come from native flat-triangle generation before mesh commit. The calibrated native test rejects5,478 slope vertices in the old source and passes1,826 authored sloped triangles in the candidate. All902 floor/ceiling chunks across eight maps retain exact vertex, UV, index, bounds and floor-collision fingerprints. No surfaces, lights, positions or collision shapes were retuned.

The first fixture tolerance incorrectly rejected decoded flat normals. A measured storage-precision tolerance of0.0001 replaces that invalid measurement, and the unchanged baseline still fails every map's slopes. Failed trials remain retained. Independent correctness and Ponytail review cleared the production fix; a capture-write guard finding was repaired and independently closed. Complete capture readback and a native bad-open case pass their intended contracts. Injected flush failure was not run.

```sh
python3 tools/check_game.py tests/test_surface_normals.gd tests/test_movement_contacts.gd
```

This is source-native geometry acceptance. Matched GPU lighting, startup/frame cost and the exact new packaged app remain unverified. [Godot SurfaceTool](https://docs.godotengine.org/en/4.7/classes/class_surfacetool.html) documents flat groups and normal generation; the runtime fixture checks this game's actual winding.

## NC-02: physics-owned input and accepted-shot age

Fire and interaction press edges are retained for a physics-owned attempt; eligible short taps survive between ticks, while unavailable taps are consumed. Weapon selection is also latched. Pause, title, replacement and activation cancel queued actions and require release of already-held triggers. A real restart regression caught an initial gate being applied only to the old player; the replacement now gates at activation after placement.

Weapon-local countdowns remain, but only uninterrupted held fire retains nominal cadence remainder. Fresh presses/switches preserve recovery, and hitches skip missed slots without a burst. One active-play clock supplies accepted-shot age to viewmodel poses and flashes independently of readiness. Native real-input tests retain118 repeater shots per10 simulated seconds against117.65 configured, with exact ammunition and five/six-tick gaps. Two injected-hitch floating-point boundaries were reproduced and repaired; these are native supplied-step tests, not OS/GPU latency measurements.

```sh
python3 tools/check_game.py tests/test_fire_intent.gd tests/test_trigger_replacement.gd
python3 tools/check_game.py tests/test_player.gd tests/test_ammo_input.gd tests/test_weapon_pose.gd tests/test_ammo_visuals.gd
```

Existing fixtures now enter physics before valid direct fire. Pose-unit fixtures stage timestamps honestly and assert read-only clocks; separate real discharges check first-post-shot age. Pause/Resume tests retain exact recovery before time advances, with an actual reset mutation failing. A pose-clock mutation also fails. Original damage, ammunition, resource, birth-ledger and cancellation assertions remain. Independent correctness/Ponytail findings were repaired before broader checks.

The current focused pending-menu fixture passes all six Settings/Controls/difficulty cases at both wait phases and three following physics frames. This is headless state evidence; physical capture, cursor/focus and full original app-path placement acceptance remain unproved. Full campaign play with human-earned inventory, heard standalone audio, current GPU/readability/performance and an updated packaged app are still pending.
