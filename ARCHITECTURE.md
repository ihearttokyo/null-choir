# Runtime and authoring layout

[DESIGN.md](DESIGN.md) owns requirements. This file owns implementation boundaries.

- `game/`: Godot runtime project, imported sprites, world models, MIDI, and the pinned synthesizer dependency. No Blender invocation or host audio library is required during play.
- `source/art/`: editable Blender scenes and art manifest. The recipes documented in [ART.md](docs/ART.md) generate runtime assets before export.
- `source/music/`: editable composition data. `tools/compose_music.py` produces the eight runtime MIDI files.
- `game/tests/` and `tests/`: direct Godot and Python assertions using the real gameplay, asset, and music paths.
- `builds/`: ignored application exports. Raw validation receipts stay outside Git.

Use native Godot nodes, resource loading, collision, audio buses, and input actions. Load one level at a time. Keep campaign state separate from its current scene so death, restart, and continuation share the same restoration path.

The first gate is offline live MIDI in a self-contained Mac export. Audio work owns `game/audio/`, `game/addons/midi/`, its MIDI tests and composition sources. The parent owns project configuration, gameplay, integration, and publishing. Asset work receives separate ownership before it starts. Workers must preserve one another's edits.

Public music boundary: a Node at `game/audio/music.gd` with `play_level(index)`, `set_paused(paused)`, and `stop()`. It routes synthesized voices to the Music bus; the game owns user volume settings. MIDI timing, repeat boundaries, voice cleanup, and pause behavior belong to this module.

`game/scripts/preferences.gd` owns primitive JSON options and per-action desktop/gamepad bindings. The game loads it before applying native InputMap and audio-bus gains. Native scroll containers expose settings and rebind capture; the HUD reads binding text from this same source. Changes save atomically to `user://preferences.json`, separate from campaign progress.

Level JSON owns authored scenery transforms and light positions. `level.gd` instantiates Blender models, dresses boundary walls with shared kit, and builds local floor/ceiling meshes so Compatibility's per-mesh light limit does not apply to a single whole-map floor. Four shadowed landmark spotlights and native depth fog supply the chamber lighting; ordinary supporting lamps have no shadows. Renderer constraints are documented by [Godot](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).

Blender world fronts authored toward -Y export toward Godot +Z. Level JSON uses Godot-space yaw; wall art faces inward and its backing faces the boundary. Native scenery assertions cover front direction, wall mounting and light clearance below ceilings.

Static boundary walls alone own inset native BoxOccluder3D instances. Project-level occlusion hides fully blocked geometry without changing authored assets, lighting or camera range. Floor/ceiling triangles use Godot clockwise front faces; native assertions cover both winding and conservative wall occluder bounds. [SCENERY.md](docs/SCENERY.md) owns visual and GPU comparison evidence.

`level_data.gd` reads each authored map's elevation regions and ceiling heights. Floor corners, native capsule positions and landmark lighting share those values. Hero specifications own their low collision-base dimensions; each level keeps its unique machine geometry. Intake's original floor corners and roof heights remain covered by an exact native regression.

`projectile.gd` owns one finite swept-collision projectile attached to the current level. Native pause and scene ownership govern its lifetime; it checks stale-map/shooter references before applying existing difficulty and infighting damage. Weapon pickups normalize JSON indices in the existing collection path; the player/HUD/campaign implementations remain shared.
