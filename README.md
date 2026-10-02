# NULL CHOIR

Original single-player cosmic-horror FPS for Apple Silicon Macs. Godot draws Blender-built pixel sprites in a 3D containment cathedral; MIDI is synthesized live from a packaged SoundFont, without host audio tools or rendered music playback.

## Development status

The current source registers all eight maps, with two native traversal loops and seven distinct religious-inspired set pieces per level. All 56 pieces have editable Blender sources. Six weapons and eight enemy roles, including two manifested bosses, pass native behavior checks; the boss encounters block descent until their persisted defeat. The HUD now includes a reference-derived restraint instrument with real HP and phase feedback. Eight original MIDI scores are synthesized live. Four image-derived overhead modules now add growth vessels, bone sorting, cosmic fractures and arterial ribs across the late loop chambers.

The private 0.2.1 development preview is delivered; final campaign acceptance remains unfinished. Inversion now has recessed cosmic cavities, fractured violet incisions and visible sparse stars. Two existing examination spotlights reveal the Nursery organism and the Heart's tooth-lined throat. Independent focused pixel reviews and correctness/Ponytail reviews pass. Strict inventory covers 92 editable art assets and 93 exports. Both changed maps pass source and boundary checks; all 24 native late-map difficulty/seal-order cases pass.

The exact uploaded Apple Silicon ZIP was downloaded and passed all eight native packed scenes/art/live MIDI/weapons/actors, strict ad-hoc signing, system-only dependencies and isolated user data. Actual standalone title/Continue, stock Escape pause, live Heart world, staged death/checkpoint restoration, save/title and normal Quit pass. Thirty M4/Metal source-candidate stress samples measure 105.81–120.77 FPS with warm scene construction at most 417.10 ms. These are source diagnostics, not a release-binary matrix or full playthrough.

Controlled first-frame checks of the exact published 0.2.1 app still miss the three-second target: the initial written native title frame takes 7.98 seconds, while later fresh-home/path launches take 1.85 and 1.94 seconds. Godot's fixed-frame movie writer provides actual native title pixels; shared OS/GPU caches may be warm, so these are not uninstrumented or reboot-cold certification. Warm results do not erase the initial failure. The prior 0.2.0 initial measurement and partial shader baking also missed the target. The full Metal compiler still requires Xcode installation, and no shader-baker change is promoted. Held physical keyboard/controller checks, heard musical quality and full campaign pacing remain open. Eight native whole MIDI loops and three actual mixed clips are available for listening; capture metrics cannot certify their musical quality. [DESIGN.md](DESIGN.md) owns requirements; [CHECKPOINT.md](CHECKPOINT.md) records current evidence and open gates.

## Run and build

[Private Mac development app: v0.2.1-dev](https://github.com/ihearttokyo/null-choir/releases/tag/v0.2.1-dev) includes all eight levels and the editable project at its source tag. [Source integration PR](https://github.com/ihearttokyo/null-choir/pull/1) remains open; no merge was requested. The exact published ZIP was downloaded and passed native full-eight, signing and dependency checks. This is a development preview, with the validation limits above and signing limitations below. The older v0.2.0-dev and v0.1.3-dev remain rollback evidence.

Open `game/project.godot` in Godot 4.7.2, or run:

```sh
godot --path game
```

WASD moves, mouse looks, left click fires, E interacts, Q/Tab cycles weapons, 1–6 selects acquired weapons, and Escape pauses. Gamepad defaults use left/right sticks, right trigger, A and shoulder buttons. Settings includes sensitivity, separate music/effects gains, optional motion effects and native control rebinding. Save-and-title/quit preserve the session if saving fails and offer an explicit discard choice.

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

That checks all eight packed scenes, art, live MIDI and retained soundbank, plus late-weapon pickups/fire/ammo and actor/boss imports. It retains the original start/fire/pause/checkpoint, Foundry/Processional, scattergun and caster-flight assertions. It does not prove GUI usability, audio timbre, frame rate or campaign completion.

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
