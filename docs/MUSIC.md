# Campaign soundtrack

Current playback uses the eight Suno recordings listed in [the selection manifest](../source/music/suno/manifest.json), one first-listed take per campaign idea. Original Opus-in-M4A downloads are retained in `source/music/suno/`; native MP3 runtime copies are in `game/audio/suno/`. FFmpeg 9.0.2 with `libmp3lame -q:a 0` performed the format conversion without structural edits or normalization. The four bonus ideas remain in Jared's Downloads and are not substituted for campaign cues.

Native transport checks cover the full files, near-end repeats, pause/resume/restart and stop. Heard quality and musical loop seams remain unverified. The following sections describe the preserved MIDI compositions and legacy regression coverage, not the active soundtrack.

## Recorded audio shutdown

After stopping playback, Main waits at least 100 ms of monotonic wall time before quitting. Frame timers can count time from before their creation: a controlled long-frame test observed only 23.059 ms of the intended drain. The corrected source waited 111.140 ms normally and 100.774 ms with fixed-FPS execution.

`tests/test_shutdown_drain_clock.gd` starts the real Suno player, introduces a long frame and checks stopped playback, idempotent quit and actual elapsed time. Run it through `tools/check_game.py`; engine exit zero alone does not establish a pass. The controlled brute-interception fixture also lets the native mixer drain after freeing its players.

These source-native checks do not establish packed-app shutdown or heard quality, nor prove that the timing defect caused an earlier intermittent playback-resource leak. GPU/app validation remains separate.

## Preserved original MIDI scores

[DESIGN.md](../DESIGN.md) owns the musical requirements; [AUDIO.md](AUDIO.md) owns live synthesis, bank provenance and playback limits. These eight original scores use that approved palette. These preserved MIDI scores do not contain rendered recordings.

| Level / file | Song | Tempo, BPM | Meter | Loop, seconds | Authored material |
|---|---|---|---|---:|---|
| Intake / `intake` | Skin Bell | 144 | 4/4 | 66.667 | E-F-B-flat-G-E command, clipped valve call, displaced breach answer and descending return bass. |
| Foundry / `foundry` | Trip Hammer | 168 / 112 / 168 | 4/4 | 77.143 | Triplet hammer answered by stop-time snare/bass pickups; D-F-E-A-flat-G-F-E-D molten melody and cooling organ anticipation. |
| Processional / `processional` | Ten Feet | 112 / 96 / 112 | 5/4 | 84.821 | Retained two-foot F-sharp guitar hook; developed reprise, changed bass route and answering organ canon. |
| Reliquary / `reliquary` | Faces in the Halo | 88 / 76 / 88 | 4/4 | 102.632 | C-B-flat-A-flat-G descending prayer; independent lament bass and separated inward guitar/organ replies. |
| Nursery / `nursery` | Glass Cradle | 126 / 108 / 126 | 6/8 | 87.619 | A-C-B-E-D-A lull becomes chromatic; duple fault against compound pulse, damaged bass return. |
| Ossuary / `ossuary` | Rib Spiral | 156 / 128 / 156 | 7/8 | 77.740 | Six-span 3+2+2 bridge develops an answer/ascent/descent arch; anticipatory bass and organ in the gaps. |
| Inversion / `inversion` | Under the Sky | 152 / 114 / 152 | 4/4 and 7/8 | 68.421 | B-flat command and its true contour inversion; exposed bass/quartal organ, suspended rests and scar answer. |
| Heart / `heart` | Mouth | 160 / 176 / 88 / 176 | 4/4 | 88.909 | A-B-A-C-A gallop development, command reharmonized at the exposed organ core, delayed guitar/saw escape answer. |

The five-note command cell has relative pitches `0, +1, +6, +3, 0`. Intake states it in the saw; Inversion reflects it about the first pitch; Heart reharmonizes it over the slow core. The other songs retain their own melodic identities rather than quoting the cell everywhere. Explicit notes and phrase order in each JSON file own the material; the table describes intended musical relationships, not a listening verdict.

## Edit and regenerate

`source/music/<file>.json` is the editable score; `game/audio/<file>.mid` is its deterministic output. Each phrase contains explicit `[quarter-note beat, duration, [MIDI pitches], velocity]` notes. Guitar power chords are already expanded into pitches, so edits need no hidden transposition or authoring helper. Optional `bends` contain `[beat, 14-bit value]`; each bent phrase must finish at center, 8192.

Phrase lengths and section lengths use quarter-note beats even in compound/odd meters. For example, one 6/8 bar lasts three beats, and one 7/8 bar lasts 3.5. Each section's `parts` lists a phrase cycle per voice; the cycle repeats to fill that section exactly. An omitted voice rests. `tempos` contain `[beat, microseconds per quarter note]`; `meters` contain `[beat, numerator, denominator]`. The MIDI conductor contains matching tempo, meter and named section markers. `beats` is the explicit end-of-track boundary on all six tracks.

```sh
python3 -B tools/compose_music.py
python3 -B tools/compose_music.py --gate
python3 -B tests/test_music.py
godot --headless --audio-driver Dummy --path game --script res://tests/test_campaign_music.gd
```

The default command validates and encodes all eight scores before writing any campaign file. A missing, malformed or invalid score therefore leaves the existing MIDI files unchanged. This does not make the write phase a filesystem transaction: an I/O failure during writing can still leave partial output. `--gate` verifies, but never overwrites, the frozen gate fixture. The encoder rejects section tiling errors, same-key overlaps, notes extending beyond a phrase, unsorted/unresolved bends and palette changes.

## Palette and loop contract

Zero-based GM programs remain Distortion Guitar 30 on channel 0, Pick Bass 34 on 1, Pipe Organ 19 on 2, and Saw Lead 81 on 3. Channel 9 uses Standard 1, bank 128/program 0, through the existing player's percussion-channel mapping. These scores use kick 36, snare 38 and closed hat 42. Other inspected kit zones had long looping tails in the shipped synth, so fills use rhythmic/velocity variation within these proven short hits. No additional programs, effects sends or sustain pedal are used. Volume/pan defaults are defined once in the encoder; each revised score authors its own `mix: {voice: [volume, pan]}`, with centered bass/drums and modest guitar/organ/saw separation. Channel volumes stay at or below the previous defaults; the synth master remains unchanged. [AUDIO.md](AUDIO.md#api) owns the independent combat-pressure contract.

Each score ends with a deliberately empty release section lasting at least two seconds; note-offs occur before that section. Pitch bends return to center, sustain stays off, and same-tick note-offs precede retriggers. The runtime can therefore reset a loop without outstanding MIDI notes or controller state. This does not prove the SoundFont release envelope is inaudible at the boundary. Audition the actual loop.

## Evidence and playback

Encoder guards remain active under normal Python, `-O` and `-OO`, including
invalid score rejection and the frozen gate comparison. They preserve the
existing `AssertionError` behavior through explicit runtime checks: Python's
[optimization option](https://docs.python.org/3/using/cmdline.html#cmdoption-O)
removes ordinary `assert` statements. `tests/test_music_runtime_guards.py`
checks those interpreter modes, unchanged MIDI bytes and late-failure write
protection using private fixture copies; it never edits the source project's
scores or tracks. These are Python source/CLI checks, not heard or native-game
acceptance.

Python assertions check deterministic source/output parity, the frozen gate hash, encoder guards, 60–120 second duration, release sections, phrase use and arrangement variation. Normalized main riffs and drum patterns differ across all eight scores; this is a structural check, not a claim of heard quality. Godot assertions use the shipped SMF reader to check actual track events, note balance, programs/channels/controllers, tempo/meter/section parity, end-of-track and release duration. They also load the actual bank and require every authored pitch/velocity to have a matching zone. Bank release envelopes and percussion auto-release/finite-PCM bounds must finish before the loop, including a 100 ms dispatch/buffer allowance. This deterministic bound does not replace listening or cover arbitrary frame stalls.

`game/audio/midi_music.gd` retains this legacy playback path; current campaign playback uses the Suno recordings. Before this overhaul, a full native CoreAudio run completed one repeat of every baseline score, pause/resume and stop/switch checks, with non-silent output, zero clipped frames and zero dropped capture frames. That evidence does not validate the revised songs or pressure mix. The two-second capture buffer preserves PCM across the previously observed 1.259-second source-file preparation stall; the zero-drop assertion remains unchanged. Re-run native bank/tail assertions and CoreAudio capture, then listen to complete revised arcs, repeats and representative gameplay at quiet/intermediate/full pressure. Listening quality, attack-cue audibility, perceived loop seams and the complete campaign remain acceptance gates; no static or mixer-capture test approves unheard music.
