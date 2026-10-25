# NULL CHOIR

Original single-player cosmic-horror FPS for Apple Silicon Macs. Godot draws Blender-built pixel sprites in a 3D containment cathedral; eight selected Suno instrumentals play offline through the native Music bus. Original MIDI compositions and their synth remain preserved.

## Playtest download

[Enter the NULL CHOIR download page](https://null-choir.jaymoney.chatgpt.site).

[![NULL CHOIR: an occupied cathedral-city held by vast restraints above an abyss](https://raw.githubusercontent.com/ihearttokyo/null-choir/9b6828cb72284bd1218441aa9ec7aa0e0506a310/game/assets/art/title/pro-series-v2.jpg)](https://null-choir.jaymoney.chatgpt.site)

[Download the Alpha 4 Major Features Preview 03 for Apple Silicon](https://github.com/ihearttokyo/null-choir/releases/download/v0.2.3-alpha.4/NULL-CHOIR-0.2.3-alpha.4-major-features-preview-03-Apple-Silicon.zip). **Playable Alpha 4 preview. The major-feature roadmap remains in progress.** Requires macOS 14 or newer. The 64-bit Apple Silicon archive is Developer ID-signed, Apple-notarized and stapled; macOS Gatekeeper and launch checks passed for this exact package. Keep system security protections enabled.

Archive size: **204,674,603 bytes**  
SHA-256: `d953d8bbc8611a30fdeed46669c4f86bbf9a02157ce6eb64a20e637c71d2e247`

[Preview source](https://github.com/ihearttokyo/null-choir/tree/a99595a89f0bff0febc2e76bb6bf48053f6e823d/game) · [Alpha 4 Major Features Preview 03 changes and known limitations](https://github.com/ihearttokyo/null-choir/releases/tag/v0.2.3-alpha.4).

### What changed in Major Features Preview 03

- **Shots follow the visible sprite:** manual and assisted aim, melee, pellets, repeater, piercing shots and swept projectiles use the current animation/facing frame’s nontransparent pixels. Transparent gaps are not enemy hits; visible pixels outside the movement capsule can be hit. Native walls still block shots.
- **Combat rules retained:** finite reach, ammunition, cooldowns, three-target piercing, guardian armor, blast cover/falloff and stale-map cancellation remain checked. This is sprite-image coverage—not anatomical regions, headshots or spatial boss weak points. Enemy/weapon artwork is unchanged in this preview.
- **Validation:** 14 native source-integration checks passed. A separate tiny synthetic Metal renderer produced zero coverage mismatches across eight cases. The actual exported package passed resource/art/audio/save/Continue/progression checks plus six real finite shots through the shipped hit module. A connected Heart Blood→Ivory/Return→checkpoint→disk Continue→finale→exit/ending run passed from arranged finite Heart-entry inventory; it is not an earned seven-map prefix or full-campaign acceptance. Physical controls, listening and sustained FPS remain unverified.

Preview 02’s terrain, six title/chapter paintings, illustrated progression/interludes and offline Suno selections remain included below.

### What changed in Major Features Preview 02

- **Eight revision-2 spatial routes:** all eight campaign maps add new elevation relationships with service galleries, ramps and bridge crossings. These are a new revision over Alpha 2's earlier terrain pass; they are not eight new levels.
- **Six new chapter/title illustrations:** the title, Foundry, Processional, Ossuary, Inversion and Heart artwork has been replaced with the new paintings. Intake, Reliquary and Nursery are not among these six image updates.
- **Full-size chapter interludes:** completed chapters open as paintings with a compact Descend/Descent chart control rail. Switch back to the connected eight-depth route map; future paintings stay locked. The ending now uses the Heart painting.
- **Soundtrack continuity:** the title screen reuses the Processional recording and the Heart interlude uses the existing Heart recording. They are selections from the same eight offline Suno tracks, not new compositions or extra tracks.
- **Enemy-spawn correction:** capsule/slope contact no longer produces the prior invalid spawn placement.
- **Resonance Chamber:** the existing track transport now has three procedural visual styles. The richer cathedral treatment remains in progress and has not cleared the strict visual acceptance bar.

### Still unfinished and known limits

This remains an incremental preview. The full eight-level earned campaign—with both seal orders and all difficulties—has not been accepted as complete. Intake, Reliquary and Nursery still need their targeted chapter-art refinements. Fourteen newly generated enemy/weapon atlases remain **concept-only**, not runtime-ready art. Fuller Resonance Chamber visuals, world-graphics work and campaign polish remain in progress. No full-campaign FPS/performance claim, physical keyboard/mouse/gamepad acceptance, human listening acceptance or full playthrough is claimed here. The established Heart Ivory/Return automated route exceeds its original time budget; the remaining campaign route/input-ledger gaps are not waived by this preview.

**Save compatibility:** a save written after entering a revision-2 floor may not load in earlier Alpha 4 binaries. Keep a separate backup before moving between this preview and an older build; do not overwrite the only save you need for rollback.

### Previous downloads and rollback

[Major Features Preview 02](https://github.com/ihearttokyo/null-choir/releases/download/v0.2.3-alpha.4/NULL-CHOIR-0.2.3-alpha.4-major-features-preview-02-Apple-Silicon.zip) remains available for rollback. The previous Alpha 4 release also remains available: [Alpha 4 release](https://github.com/ihearttokyo/null-choir/releases/tag/v0.2.3-alpha.4) · [Alpha 4 chapter-preview package](https://github.com/ihearttokyo/null-choir/releases/download/v0.2.3-alpha.4/NULL-CHOIR-0.2.3-alpha.4-chapter-preview-Apple-Silicon.zip) (SHA-256 `f9880daac9b0036f3a106c000f2e6a8038c584ff2a52d8835af36ab86ac38b04`). [Alpha 3](https://github.com/ihearttokyo/null-choir/releases/tag/v0.2.3-alpha.3) and [Alpha 2](https://github.com/ihearttokyo/null-choir/releases/tag/v0.2.3-alpha.2) remain available as earlier rollback builds. Prior archives are not replaced or deleted.

[LICENSE](LICENSE) governs the original project and soundtrack. Official unmodified binary archives may be shared free of charge for noncommercial use; source and assets are not open source or public domain. Third-party notices retain their own terms.

## Earlier development history

The earlier development baseline registered all eight maps, with two native traversal loops and seven distinct religious-inspired set pieces per level. All 56 pieces have editable Blender sources. Six weapons and eight enemy roles, including two manifested bosses, pass native behavior checks; the boss encounters block descent until their persisted defeat. The HUD now includes a reference-derived restraint instrument with real HP and phase feedback. The current soundtrack maps one selected Suno take to each level; the original eight MIDI scores remain preserved. Four image-derived overhead modules now add growth vessels, bone sorting, cosmic fractures and arterial ribs across the late loop chambers.

Earlier development previews remain available; final campaign acceptance remains unfinished. Inversion now has recessed cosmic cavities, fractured violet incisions and visible sparse stars. Two existing examination spotlights reveal the Nursery organism and the Heart's tooth-lined throat. Independent focused pixel reviews and correctness/Ponytail reviews pass. Strict inventory covers 92 editable art assets and 93 exports. Both changed maps pass source and boundary checks; all 24 native late-map difficulty/seal-order cases pass.

The earlier v0.2.2-suno.1 ZIP passed all eight native packed scenes/art/live MIDI/weapons/actors, strict ad-hoc signing, system-only dependencies and isolated user data. The v0.2.2-suno.2 archive preserves that game payload and additionally passes Developer ID, Apple notarization, stapled-ticket, Gatekeeper and packed-app checks. Actual standalone title/Continue, stock Escape pause, live Heart world, staged death/checkpoint restoration, save/title and normal Quit pass. Historical source-candidate measurements are not a performance acceptance result for Major Features Preview 02; no FPS or full-campaign performance claim is made for this build.

The published 0.2.1 app missed the initial three-second title-frame target. Current source builds bake native Metal libraries into the development app; controlled launch comparisons show an improvement, with measurement limits recorded in [CHECKPOINT.md](CHECKPOINT.md). This does not certify reboot-cold or normal input-ready launch. Held physical controls, heard musical quality and full played pacing remain open. [DESIGN.md](DESIGN.md) owns requirements.

Source-native checks preserve captured actor damage and summoned companions through Continue and checkpoint recovery on all three difficulties; entry restart restores the original entry actor state. Corrected packed-app validation, full-campaign combat, listening and physical controls remain unfinished.

## Run and build

[Mac development builds](https://github.com/ihearttokyo/null-choir/releases) retain the published 0.2.1, 0.2.0 and 0.1.3 previews as rollback evidence. Major Features Preview 02 is a native Metal-baked 0.2.3 app for Apple Silicon Macs running macOS 14 or newer. Use its [pinned release source](https://github.com/ihearttokyo/null-choir/tree/9b6828cb72284bd1218441aa9ec7aa0e0506a310/game) to reproduce this preview; the default branch has not merged every outstanding gameplay PR. [Source integration](https://github.com/ihearttokyo/null-choir/pull/1) tracks the reviewed eight-level development project; merging source does not certify a corrected standalone app.

Open `game/project.godot` in Godot 4.7.2, or run:

```sh
godot --path game
```

WASD moves, mouse looks, left click fires, E interacts, Q/Tab cycles weapons, 1–6 selects acquired weapons, and Escape pauses. Gamepad defaults use left/right sticks, right trigger, A and shoulder buttons. Settings includes sensitivity, separate music/effects gains, optional motion effects and native control rebinding. Save-and-title/quit preserve the session if saving fails and offer an explicit discard choice.

With Python 3.11 or newer, matching Godot 4.7.2 Mac export templates, Xcode and Apple's Metal Toolchain installed:

```sh
python3 tests/test_build_deadline.py
python3 tests/test_build_source.py --allow-window
python3 tests/test_macos.py
```

Shader baking requires a native macOS GPU export; headless export cannot bake these libraries. The build and native source-preservation test refuse by default before creating outputs or launching Godot. Use `--allow-window` only when opening and activating a Godot graphics window is intended; license generation and import remain headless. The builder copies the game into a temporary local folder, imports it separately, exports without rewriting the editable project, thins the official engine to arm64, applies a local ad-hoc signature, verifies it, and writes `builds/macos/NULL CHOIR-arm64.zip`. It leaves installed templates and global configuration unchanged. This is a development app, without Developer ID signing or notarization. Extract the ZIP with Finder or `ditto`; cloud-folder metadata may invalidate signatures on copied app directories.

Build validation retains a 300-second deadline and terminates its isolated process group on timeout. The deadline fixture verifies that no live owned descendant survives.

`tests/test_macos.py` runs the exported binary's `--verify-export` path with a temporary isolated HOME. It checks all eight packed scenes, art, selected recorded audio and retained MIDI sources/soundbank, late weapons/actors/bosses, native Metal cache files, macOS 14 target metadata and the original start/fire/pause/checkpoint assertions. It does not prove GUI usability, audio timbre, frame rate or campaign completion.

## Source and checks

[ARCHITECTURE.md](ARCHITECTURE.md) describes module ownership. [Blender pipeline](docs/ART.md) covers regeneration and editable scenes; [audio playback](docs/AUDIO.md) records dependency pins, patches, licenses and runtime API.

```sh
python3 tools/check_game.py tests/test_scenery.gd tests/test_campaign.gd tests/test_level.gd tests/test_foundry.gd tests/test_processional.gd tests/test_processional_flow.gd tests/test_combat_expansion.gd tests/test_level_transition.gd tests/test_player.gd tests/test_gameplay.gd tests/test_enemy.gd tests/test_interaction.gd tests/test_autoaim.gd tests/test_completion.gd tests/test_sprite_direction.gd tests/test_save_failure.gd tests/test_music_game.gd tests/test_preferences.gd tests/test_controls.gd
python3 tools/check_game.py tests/test_metal_cache.gd
python3 tools/check_game.py --timeout 180 tests/test_save_placement.gd
python3 tools/check_game.py --timeout 360 tests/test_late_roles.gd
python3 tests/test_music.py
python3 tests/test_art.py
blender -b -t 4 --python-exit-code 1 --python tests/test_art_pose.py
godot --headless --audio-driver CoreAudio --fixed-fps 60 --path game --quit-after 20000 --script tests/test_traversal.gd -- --level=1
```

These use actual native gameplay/assets; headless input is simulated. A PASS marker and clean exit are required. The runner enforces a finite wall-clock deadline. The full late-role fixture needs about three minutes on the measured M4 host. MIDI assertions and native CoreAudio capture are separate from listening and GUI review.

Original code, compositions and art remain project-owned. Third-party notices are retained in `licenses/audio/`, packaged audio/add-on notices and `game/licenses/Godot-Third-Party.txt`. GeneralUser GS permits software redistribution but qualifies historical sample origins; that qualification is retained with the redistributed bank. No copied Doom maps, sprites or songs are included.
