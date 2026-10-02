# NULL CHOIR

Original single-player cosmic-horror FPS for Apple Silicon Macs. Godot draws Blender-built pixel sprites in a 3D containment cathedral; MIDI is synthesized live from a packaged SoundFont, without host audio tools or rendered music playback.

## Development status

The current source registers all eight maps, with two native traversal loops and seven distinct religious-inspired set pieces per level. All 56 pieces have editable Blender sources. Six weapons and eight enemy roles, including two manifested bosses, pass native behavior checks; the boss encounters block descent until their persisted defeat. The HUD now includes a reference-derived restraint instrument with real HP and phase feedback. Eight original MIDI scores are synthesized live. Four image-derived overhead modules now add growth vessels, bone sorting, cosmic fractures and arterial ribs across the late loop chambers.

The private eight-level development build is delivered; final acceptance remains unfinished. Twelve authored late-role assignments pass all 24 difficulty/seal-order cases. A wall-batching experiment reduced draw calls but failed its frame-rate gate and was rolled back. A fresh 0.2.0 Apple Silicon ZIP passes all eight packed scenes, live MIDI, weapon and actor imports. Live isolated-app checks pass menus, rebinding, mouse firing and checkpoint recovery. The original OpenGL stress run exposed sub-60 FPS late views. Six matched renderer comparisons then passed all 30 native Metal treatment samples at 141–181 FPS, with the same art, lights and active enemies. Sixty-four matched 640x360 images and 17 native safeguards pass; the project now selects Godot Mobile/native Metal. The rebuilt Metal ZIP passes native packed-resource checks and live isolated-app menus, settings, stock Escape pause, firing, death, checkpoint recovery and persisted Continue. Initial native first-frame timing is 5.94 seconds, above the three-second target; partial shader baking also misses it, and the full Metal compiler requires Xcode installation. No shader-baker change is promoted. A live exact-app Heart stress canary reports 60 FPS across six whole one-second samples with all authored cohorts active and the player surviving. Eight full native MIDI loops plus repeated intros have zero clipped/discarded capture frames, but remain unheard. Full campaign playthrough, musical listening, physical keyboard/controller checks, cold startup and broader packaged performance acceptance remain before final release acceptance. Native staging, old gameplay regressions, checkpoint/death/Continue/restart, late-level input and final ending gates have passed; these controlled tests do not establish overall pacing or artistic quality. [DESIGN.md](DESIGN.md) owns requirements; [CHECKPOINT.md](CHECKPOINT.md) records current evidence and open gates.

## Run and build

[Private Mac development app: v0.2.0-dev](https://github.com/ihearttokyo/null-choir/releases/tag/v0.2.0-dev) includes all eight levels and the editable project at its source tag. [Source integration PR](https://github.com/ihearttokyo/null-choir/pull/1) remains open; no merge was requested. The exact published ZIP was downloaded and passed native full-eight, signing and dependency checks. This is a development preview, with the validation limits above and signing limitations below. The older v0.1.3-dev remains rollback evidence.

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
