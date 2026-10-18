# Runtime and authoring layout

[DESIGN.md](DESIGN.md) owns requirements. This file owns implementation boundaries.

- `game/`: Godot runtime project, imported sprites, world models, compressed Suno recordings, preserved MIDI, and the pinned legacy synthesizer dependency. No Blender invocation or host audio library is required during play.
- `source/art/`: editable Blender scenes and art manifest. The recipes documented in [ART.md](docs/ART.md) generate runtime assets before export.
- `source/music/`: editable composition data. `tools/compose_music.py` produces the eight runtime MIDI files.
- `game/tests/` and `tests/`: direct Godot and Python assertions using the real gameplay, asset, and music paths.
- `builds/`: ignored application exports. Raw validation receipts stay outside Git.

Use native Godot nodes, resource loading, collision, audio buses, and input actions. Load one level at a time. Keep campaign state separate from its current scene so death, restart, and continuation share the same restoration path.

Imported campaign placement is checked against the actual native floor and player capsule before gameplay or mouse capture. Healthy saved locations are preferred to the authored entry, without refunding current resources or rewriting recovery snapshots. Loaded continuation, checkpoint restoration and level restart can wait for native physics registration; callers must await completion before assuming gameplay is active. Pause, title, replacement and focus loss cancel pending continuation. A map with no safe candidate returns to title instead of permitting Resume at a rejected location.

The current soundtrack uses eight offline Suno recordings; the original MIDI runtime is preserved as `game/audio/midi_music.gd` for synthesis regression coverage only. Audio work owns `game/audio/`, `game/addons/midi/`, its MIDI tests and composition sources. The parent owns project configuration, gameplay, integration, and publishing. Asset work receives separate ownership before it starts. Workers must preserve one another's edits.

Public music boundary: a Node at `game/audio/music.gd` with `play_level(index)`, `set_paused(paused)`, and `stop()`. It lazily loads one compressed recording into one native AudioStreamPlayer on the Music bus; the game owns user volume settings. Repeat boundaries, release on title, pause behavior and a smoothed -3 to 0 dB combat lift belong to this module. Host conversion tools are authoring-only.

`game/scripts/preferences.gd` owns primitive JSON options and per-action desktop/gamepad bindings. The game loads it before applying native InputMap and audio-bus gains. Native scroll containers expose settings and rebind capture; the HUD reads binding text from this same source. Changes save atomically to `user://preferences.json`, separate from campaign progress.

Level JSON owns authored scenery transforms and light positions. `level.gd` instantiates Blender models, dresses boundary walls with shared kit, and builds local floor/ceiling meshes so the Mobile renderer's per-mesh light limit does not apply to a single whole-map floor. Four shadowed landmark spotlights and native depth fog supply the chamber lighting; ordinary supporting lamps have no shadows. Renderer constraints are documented by [Godot](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).

Level-owned navigation parses static collision on the main thread, then bakes one role at a time through the native asynchronous API. Later process ticks poll completion; published geometry still waits for the native map witness before queries become available. Door invalidation rejects retired generations, and teardown releases local jobs without callbacks retaining the Level. [NAVIGATION.md](docs/NAVIGATION.md) records the regression and timing evidence.

Each level retains one native PackedScene per used world-art ID. The native resource probe showed that scene instances kept meshes alive while their temporary PackedScene left the resource cache, causing repeated scene loading during construction. Level-owned scene references preserve the existing instance transforms, meshes and materials; level destruction releases those references. This is per-level resource ownership, without a global cache or rendering rewrite.

Blender world fronts authored toward -Y export toward Godot +Z. Level JSON uses Godot-space yaw; wall art faces inward and its backing faces the boundary. Native scenery assertions cover front direction, wall mounting and light clearance below ceilings.

Static boundary walls alone own inset native BoxOccluder3D instances. Project-level occlusion hides fully blocked geometry without changing authored assets, lighting or camera range. Floor/ceiling triangles use Godot clockwise front faces; native assertions cover both winding and conservative wall occluder bounds. [SCENERY.md](docs/SCENERY.md) owns visual and GPU comparison evidence.

`level_data.gd` reads each authored map's elevation regions and ceiling heights. Floor corners, native capsule positions and landmark lighting share those values. Hero specifications own their low collision-base dimensions; each level keeps its unique machine geometry. Intake's original floor corners and roof heights remain covered by an exact native regression. Campaign saves retain all three resource envelopes against their per-level floor revision. Legacy actor poses are validated on immutable original floors before a private copy shifts their Y coordinates by the triangulated floor delta; failed validation leaves live state and saved files unchanged.

The revision1 terrain keeps every map footprint, loop, placement, light and art
reference while replacing small isolated rises with connected terraces. Intake
spans0–3m; Foundry0–4m; Processional0–5m; Reliquary−3–4m;
Nursery−3.5–4.5m; Ossuary−4–5m; Inversion−5–5.5m; Heart−6–6m.
The last five maps increase from four to six major flat elevation bands. Both
loops traverse multiple bands. Actual native floor/roof/capsule, actor-placement,
wall-contact and navigation checks cover these maps; the repaired Nursery ramp
avoids the reproduced native navigation-edge warnings. Synthetic traversal and
packed save restoration do not establish earned combat, physical-input play,
visual quality or the sustained GPU target. The original Intake, Foundry and
Processional floor assertions use immutable legacy layouts, separately from the
current terrain checks.

`projectile.gd` owns one finite swept-collision projectile attached to the current level. Native pause and scene ownership govern its lifetime; it checks stale-map/shooter references before applying existing difficulty and infighting damage. Weapon pickups normalize JSON indices in the existing collection path; the player/HUD/campaign implementations remain shared.

The Apple Silicon runtime now selects Godot Mobile with the native macOS Metal driver. Matched M4 tests established higher throughput without reducing art, actors, lights or shadows; actual comparison images preserve the authored look. `game/tests/test_rendering.gd` checks the actual driver/method and unchanged 640x360 target on a real GPU. Headless physics checks cannot establish the graphics backend. [CHECKPOINT.md](CHECKPOINT.md) owns current app and performance evidence.

The packaged `--verify-export --verify-stall` diagnostic requires fresh isolated validation userdata before starting its fixed 24-second Intake route. It uses synthetic engine actions, rejects physical input and initially active mapped actions, preserves normal mouse capture outside that route, and records bounded render/physics timestamps in `user://export_stall_metrics.json`. Collection completion requires a real closing draw; first-draw and terminal no-draw intervals remain visible. Collection success and the 120 FPS target are separate results. Record VSync and display refresh when interpreting cadence; these timestamps do not measure physical presentation, human input or uninstrumented memory. The ordinary `--verify-export` resource checks remain unchanged.

Ammo presentation is level-owned in `ammo_visuals.gd`: two shared nearest atlases, at most32 pooled sprites, protected live-projectile/active-route slots and explicit pause/current-map fences. Reused slots restore the correct texture family. The HUD uses the selected combat cooldown, not a separate animation clock. [AMMO.md](docs/AMMO.md) owns asset provenance, regeneration and evidence limits.
