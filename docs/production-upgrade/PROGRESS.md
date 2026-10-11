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

NC-01, NC-02 and the geometric NC-10 repair have supporting source acceptance. NC-03 follows below. Next repair incoming damage geometry, then continue the remaining contracts and section19 gates. Source progress does not complete the campaign/app goal.

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


## NC-03: finite contact truth and physics-owned HUD observations

The shared resolver preserves valid manual contact first, including dormant activation. Optional fallback samples native capsule points, ranks angular proximity before actual contact distance and stable authored ID, and accepts only a finite first collision with the selected current-map actor. Classic tool correction has separate horizontal and bounded vertical limits; no collider was enlarged. Wrong-map manual identity and order-dependent near-equal ranking were reproduced and repaired.

Native cases cover horizontal crawlers at1.0/1.8/2.4m, surface rather than center reach, floor offsets, cone/vertical limits, low/tall/floating capsules, thin walls, intervening dormant actors, partial cover, manual priority, disabled assistance, death and scene replacement. Removing the native collider-identity fence or the exposed upper sample fails the retained cover regressions; exact production source was restored afterward.

A transient physics observation supplies the HUD contact cue and interaction prompt. Display performs no collision query. A real Player-driven fixture proves one resolver call per ordinary or accepted-shot tick and rejects observation calls after synchronous shot/dry callbacks replace the scene. Cancellation, look, weapon mismatch, death and map retirement invalidate the result. Shot geometry is revalidated rather than firing a cached preview.

The actual GPT image reference was generated, inspected and retained at [aim-cue-reference.png](aim-cue-reference.png). Its small amber contact corners complement the existing ivory manual reticle; they never promise a future projectile hit or every pellet. Projection uses the actual camera viewport and HUD canvas transform, with no fixed division by two. Native scaled/translated-canvas checks prove coordinate agreement; rendered readability remains unproved. PR35 uses canvas-items stretch. Its actual configuration and GPU comparison remain separate integration checks.

```sh
python3 tools/check_game.py tests/test_close_melee.gd tests/test_aim_resolution.gd
python3 tools/check_game.py tests/test_aim_observation.gd tests/test_aim_publication.gd
```

Existing observer fixtures now enter physics or publish on its clock without dropping their prior assertions. The synthetic firing arenas load actual interaction metadata. Combat teardown gives the real audio thread a bounded100ms wall-clock interval; a simulation timer was insufficient in one retained trial. This is fixture calibration, not an audio performance gain or proof of app-exit behavior.

The full save-placement fixture remains blocked on the real window/capture path: headless reports visible mouse mode where it expects capture. Both unchanged72f44 source and this candidate reproduce that limitation with correct replacement identities, playing/music/menu state. The original capture assertion remains intact. Settings/Controls/difficulty wait-frame state checks are separate and do not certify physical capture or cursor behavior.


## NC-04 supporting geometry slice

Guardian armor now reads accepted incoming geometry independently of shooter identity. Hitscan, pellets, melee and piercing carry their actual ray direction; traveling projectiles carry arrival direction; radial damage carries detonation origin. The35% closed-armor multiplier and three existing open windows remain unchanged. Eligible living current-map sources still govern retaliation; moved, freed or retired sources cannot supply replacement geometry.

The native fixed front-projectile witness formerly changed from4 to14 damage when its shooter moved behind the guardian. It now remains4. Additional actual-collision and direct radial-policy cases cover rear arrival, guardian rotation, freed shooter, open windows, front/rear detonation, direct/splash deduplication, thin cover and eligible infighting. Explicit zero/invalid geometry has no armor-bearing direction; legacy empty contexts retain the old valid-source fallback.

Both independent reviews caught nonfinite vertical data being erased before validation. A native NaN-Y probe failed before correction; full-vector validation now precedes horizontal projection, with four added NaN/Inf-Y table cases. Current reviews are qualified clean. Twenty-one affected source-native scripts and both isolated muted CoreAudio save/discard shutdown paths pass; these are synthetic/native evidence, not human combat, heard audio or packaged-app acceptance.

```sh
python3 tools/check_game.py tests/test_damage_geometry.gd tests/test_late_weapons.gd
```

Attack-state art, hostile spatial audio and source-bearing visual feedback remain open NC-04 work. This geometry slice does not certify the complete presentation contract.
