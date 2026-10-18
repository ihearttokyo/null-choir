# Ammo presentation

The selected GPT image reference is `source/art/references/ammo-vfx-reference-01.png`. Its four families became sixteen editable Blender pose collections in `source/art/ammo_vfx.blend`: amber muzzle, hollow copper casing, restrained marrow capsule and broken cyan/violet pressure ring. `source/art/manifest.json` owns their actual source, recipe, reference and runtime pins.

`tools/build_ammo_vfx.py` renders into a fresh explicit `--output-root` using background Blender, the pinned `tools/build_art.py` rendering helpers, CPU four threads and isolated Blender user/config/data/script/extension/resource and temporary paths. It refuses existing output directories and validates all sixteen nonempty frames, four-pixel gutters and each ring coverage floor. Save the source uncompressed to retain the established Blender-header contract. Compare actual produced bytes before replacing an asset or updating its manifest entry; do not overwrite manual edits. The first portable render reproduced the selected PNG exactly. The subsequent uncompressed-source run differed in five color-channel bytes, with unchanged alpha and at most eight channel units; rendering is not claimed bitwise deterministic. Its inspected source/PNG pair is the retained distribution.

Runtime uses two shared 256x256 nearest-filtered atlases. The level lazily owns one driver and at most32 pooled Sprite3D nodes, including inactive slots. Casings and impacts may be recycled under saturation; live projectile-bound sprites cannot be evicted. Weak projectile references disappear on deletion. There are no cosmetic colliders, damage calls, random draws, lights, timers or custom shaders. Pause and current-level checks fence the single process callback.

Travelling shots use `shot_travel.png`: square-headed amber rivets, pale bone/iron flechettes, serrated red-orange needles and hollow cyan/violet choir pulses. Each follows its actual resolved ray. The disruptor ends at its third struck actor, an earlier wall or its finite range. Damage still resolves immediately; cosmetic arrival adds no hit or impact. Admitted routes remain protected until expiry, and reused slots restore the original casing/impact texture and behavior. Presentation starts at the authoritative camera origin, without a muzzle-offset ray that could cross nearby cover. Moving-game readability remains a separate acceptance gate.

The selected construction reference is `source/art/references/shot-transport-construction-20261018.png`. Its original editable mesh source is `source/art/shot_travel.blend`: sixteen pose collections, 280 meshes and 6,952 triangles. `tools/build_shot_travel.py` uses the existing rendering helpers, explicit `--repo-root` and fresh `--output-root`, with the same isolated Blender user/resource/temp environment as the ammo producer. `tools/shot_atlas.py` enforces binary alpha, four-pixel gutters, at least80 occupied pixels per frame and a transparent choir center. The manifest pins the source, reference, recipe, helpers and runtime bytes.

The HUD derives idle/fire/recovery from the selected weapon's existing cooldown and interval; camera shake no longer animates an unfired switched weapon. Muzzle frames use that same clock. Shot timing, ammunition, damage, auto-aim, projectile swept collision and blast rules are unchanged.

Checks: `game/tests/test_weapon_pose.gd`, `game/tests/test_ammo_visuals.gd` and `python3 -B tests/test_ammo_art.py`. Native headless checks exercise actual hooks, physics ownership and pause scheduling; explicit manual deltas are simulation, not real held-fire timing. The art check reads actual Blender/reference/PNG bytes and manifest pins. Headless checks cannot establish rendered placement, visual readability, GPU cost or human playability. Those require the nondisruptive graphics/app validation route.

`game/tests/test_shot_transport.gd` checks real physics discharges, finite misses and wall contacts, piercing termination/damage, pause, clamped arrival, mixed protected-pool saturation and expired-route reuse. Its manually advanced cosmetic clock does not prove rendered motion or sustained performance.

`python3 -B tests/test_shot_art.py` checks the actual artifact pins/pixels, adjacent79/80-pixel limits, outward winding of all36 plate outlines and pre-Blender failure boundaries. Native Blender checks verified all36 saved plate volumes and sampled edit/save/reopen/revert for each family. Repeated-render determinism is unmeasured.

## Conduit integration followthrough

The conduit update changed only the shared helper’s kit/world-export/main paths.
AST comparison confirmed the ammo renderer’s called functions and globals were unchanged.
The producer now pins the current full helper and refuses foreground Blender before
creating output. An isolated background regeneration preserved every alpha byte,
frame coverage, gutter and pose collection. Its five differing color-channel bytes
are within eight channel units of the previous distribution. The manifest records
the actual regenerated source/atlas pair and current recipe/helper pins.

Current-head headless native menu, pose, visual-pool, late-weapon, efficiency, HUD,
transition, save-failure, world and conduit fixtures pass with CoreAudio and muted
fixture buses. A Dummy-driver pose run retained a 15-object WAV/playback shutdown
leak; an otherwise identical CoreAudio run had none. These checks do not prove
physical mouse capture, rendered pixels, held-fire timing, GPU cost or a packed app.

## Repeater balance

The source balance pass raises repeater damage from15 to16; scattergun pellets remain15. A naturally configured76-HP Merciful worker now dies after five hits rather than six. Cadence, spread, random draws, ammunition costs, native collision queries and other weapon damage stay unchanged.

The real-physics regression is `game/tests/test_repeater_damage.gd`. An earned Nursery first-loop witness also fired15 repeater rounds, killed two original actors with them and retained45 rounds, with the prior campaign history and recovery data preserved. That witness uses engine-simulated input and mixed weapons; its survival result does not isolate the benefit of damage16. Full campaign balance, physical controls and packed-app acceptance remain separate gates. This source change does not update an existing downloadable app.
