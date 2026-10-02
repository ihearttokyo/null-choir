# NULL CHOIR

Original single-player cosmic-horror FPS for Apple Silicon Macs. Godot draws Blender-built pixel sprites in a 3D containment cathedral; MIDI is synthesized live from a packaged SoundFont, without host audio tools or rendered music playback.

## Development status

This is an unfinished three-level build, not the completed eight-level campaign. Intake, Foundry and Processional each have two traversal loops with distinct original Blender hero pieces, keys, one hidden story discovery and mid-level restoration. Three enemy roles and three weapons are implemented; eight original MIDI scores and persisted keyboard/mouse/gamepad rebinding are integrated. Five maps, remaining weapons/enemies/bosses, sound effects, ending, musical listening and full visual/pacing/performance acceptance remain. [Intake scenery](docs/SCENERY.md) and [Foundry scenery](docs/FOUNDRY.md) and [Processional scenery](docs/PROCESSIONAL.md) show native rendered evidence. [DESIGN.md](DESIGN.md) owns the approved scope; [CHECKPOINT.md](CHECKPOINT.md) records current evidence and open gates.

## Run and build

[Private Mac development app: v0.1.3-dev](https://github.com/ihearttokyo/null-choir/releases/tag/v0.1.3-dev) includes Intake, Foundry and Processional. The campaign remains unfinished; signing limitations are described below.

Open `game/project.godot` in Godot 4.7.2, or run:

```sh
godot --path game
```

WASD moves, mouse looks, left click fires, E interacts, Q/Tab cycles weapons, 1/2/3 selects acquired weapons, and Escape pauses. Gamepad defaults use left/right sticks, right trigger, A and shoulder buttons. Settings includes sensitivity, separate music/effects gains, optional motion effects and native control rebinding. Save-and-title/quit preserve the session if saving fails and offer an explicit discard choice.

With matching Godot Mac export templates and Apple command-line tools installed:

```sh
python3 tools/build_macos.py
python3 tests/test_macos.py
```

The builder exports to a temporary local folder, thins the official engine to arm64, applies a local ad-hoc signature, verifies it, and writes `builds/macos/NULL CHOIR-arm64.zip`. It leaves installed templates and global configuration unchanged. This is a development app, without Developer ID signing or notarization. Extract the ZIP with Finder or `ditto`; cloud-folder metadata may invalidate signatures on copied app directories.

The exported binary supports a fixed headless development check:

```sh
"NULL CHOIR.app/Contents/MacOS/NULL CHOIR" --headless --audio-driver CoreAudio -- --verify-export
```

That checks packaged resources, start/fire/pause/checkpoint restoration Foundry and Processional scene/art/live MIDI, scattergun pickup/fire and caster projectile launch. It does not prove GUI usability, audio timbre, frame rate or campaign completion.

## Source and checks

[ARCHITECTURE.md](ARCHITECTURE.md) describes module ownership. [Blender pipeline](docs/ART.md) covers regeneration and editable scenes; [live MIDI](docs/AUDIO.md) records dependency pins, patches, licenses and runtime API.

```sh
python3 tools/check_game.py tests/test_scenery.gd tests/test_campaign.gd tests/test_level.gd tests/test_foundry.gd tests/test_processional.gd tests/test_processional_flow.gd tests/test_combat_expansion.gd tests/test_level_transition.gd tests/test_player.gd tests/test_gameplay.gd tests/test_enemy.gd tests/test_interaction.gd tests/test_autoaim.gd tests/test_completion.gd tests/test_sprite_direction.gd tests/test_save_failure.gd tests/test_music_game.gd tests/test_preferences.gd tests/test_controls.gd
python3 tests/test_music.py
python3 tests/test_art.py
blender -b -t 4 --python-exit-code 1 --python tests/test_art_pose.py
godot --headless --audio-driver CoreAudio --fixed-fps 60 --path game --quit-after 20000 --script tests/test_traversal.gd -- --level=1
```

These use actual native gameplay/assets; headless input is simulated. A PASS marker and clean exit are required. MIDI assertions and native CoreAudio capture are separate from listening and GUI review.

Original code, compositions and art remain project-owned. Third-party notices are retained in `licenses/audio/`, packaged audio/add-on notices and `game/licenses/Godot-Third-Party.txt`. GeneralUser GS permits software redistribution but qualifies historical sample origins; that qualification is retained for this private development build. No copied Doom maps, sprites or songs are included.
