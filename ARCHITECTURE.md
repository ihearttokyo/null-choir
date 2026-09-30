# Runtime and authoring layout

[DESIGN.md](DESIGN.md) owns requirements. This file owns implementation boundaries.

- `game/`: Godot runtime project, imported sprites, world models, MIDI, and the pinned synthesizer dependency. No Blender invocation or host audio library is required during play.
- `source/art/`: editable Blender scenes and art manifest. `tools/build_art.py` generates runtime assets before export.
- `source/music/`: editable composition data. `tools/compose_music.py` produces the eight runtime MIDI files.
- `game/tests/` and `tests/`: direct Godot and Python assertions using the real gameplay, asset, and music paths.
- `builds/`: ignored application exports. Raw validation receipts stay outside Git.

Use native Godot nodes, resource loading, collision, audio buses, and input actions. Load one level at a time. Keep campaign state separate from its current scene so death, restart, and continuation share the same restoration path.

The first gate is offline live MIDI in a self-contained Mac export. Audio work owns `game/audio/`, `game/addons/midi/`, its MIDI tests and composition sources. The parent owns project configuration, gameplay, integration, and publishing. Asset work receives separate ownership before it starts. Workers must preserve one another's edits.

Public music boundary: a Node at `game/audio/music.gd` with `play_level(index)`, `set_paused(paused)`, and `stop()`. It routes synthesized voices to the Music bus; the game owns user volume settings. MIDI timing, repeat boundaries, voice cleanup, and pause behavior belong to this module.
