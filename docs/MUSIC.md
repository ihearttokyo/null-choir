# Campaign scores

[DESIGN.md](../DESIGN.md) owns the musical requirements; [AUDIO.md](AUDIO.md) owns live synthesis, bank provenance and playback limits. These eight original scores use that approved palette. No existing song or rendered recording is used.

| Level / file | Song | Tempo, BPM | Meter | Loop, seconds | Authored material |
|---|---|---|---|---:|---|
| Intake / `intake` | Skin Bell | 144 | 4/4 | 66.667 | Clipped E pedal with 3+3+2 sixteenth accents; rising alarm, organ answers and an empty-pipe break. |
| Foundry / `foundry` | Trip Hammer | 168 / 112 / 168 | 4/4 | 77.143 | D triplet hammer bursts, chromatic hydraulic press, cooling chords and a bent saw arc. |
| Processional / `processional` | Ten Feet | 112 / 96 / 112 | 5/4 | 84.821 | Ten-beat F-sharp procession, walking bass, independent organ counterpoint and fractured joints. |
| Reliquary / `reliquary` | Faces in the Halo | 88 / 76 / 88 | 4/4 | 102.632 | C doom chords interrupted by D-flat/F-sharp halo stabs, exposed prayer and triplet splinters. |
| Nursery / `nursery` | Glass Cradle | 126 / 108 / 126 | 6/8 | 87.619 | Compound A-minor cradle, dotted bass and glass melody collide with chromatic machine teeth. |
| Ossuary / `ossuary` | Rib Spiral | 156 / 128 / 156 | 7/8 | 77.740 | B bridge riff with 3+2+2 accents, moving bass, slow tomb and a seven-beat climbing saw. |
| Inversion / `inversion` | Under the Sky | 152 / 114 / 152 | 4/4 and 7/8 | 68.421 | B-flat metric cuts, inverted pitch contour, quartal organ and a suspended saw bend. |
| Heart / `heart` | Mouth | 160 / 176 / 88 / 176 | 4/4 | 88.909 | E-flat gallop, alternating blast, slow exposed organ core and a new escape answer. |

## Edit and regenerate

`source/music/<file>.json` is the editable score; `game/audio/<file>.mid` is its deterministic output. Each phrase contains explicit `[quarter-note beat, duration, [MIDI pitches], velocity]` notes. Guitar power chords are already expanded into pitches, so edits need no hidden transposition or authoring helper. Optional `bends` contain `[beat, 14-bit value]`; each bent phrase must finish at center, 8192.

Phrase lengths and section lengths use quarter-note beats even in compound/odd meters. For example, one 6/8 bar lasts three beats, and one 7/8 bar lasts 3.5. Each section's `parts` lists a phrase cycle per voice; the cycle repeats to fill that section exactly. An omitted voice rests. `tempos` contain `[beat, microseconds per quarter note]`; `meters` contain `[beat, numerator, denominator]`. The MIDI conductor contains matching tempo, meter and named section markers. `beats` is the explicit end-of-track boundary on all six tracks.

```sh
python3 -B tools/compose_music.py
python3 -B tools/compose_music.py --gate
python3 -B tests/test_music.py
godot --headless --audio-driver Dummy --path game --script res://tests/test_campaign_music.gd
```

The default command regenerates only the eight campaign files. `--gate` verifies, but never overwrites, the frozen gate fixture. The encoder rejects section tiling errors, same-key overlaps, notes extending beyond a phrase, unsorted/unresolved bends and palette changes.

## Palette and loop contract

Zero-based GM programs remain Distortion Guitar 30 on channel 0, Pick Bass 34 on 1, Pipe Organ 19 on 2, and Saw Lead 81 on 3. Channel 9 uses Standard 1, bank 128/program 0, through the existing player's percussion-channel mapping. These scores use kick 36, snare 38 and closed hat 42. Other inspected kit zones had long looping tails in the shipped synth, so fills use rhythmic/velocity variation within these proven short hits. No additional programs, effects sends or sustain pedal are used. Volume/pan defaults are defined once in the encoder; a score may override them with `mix: {voice: [volume, pan]}`.

Each score ends with a deliberately empty release section lasting at least two seconds; note-offs occur before that section. Pitch bends return to center, sustain stays off, and same-tick note-offs precede retriggers. The runtime can therefore reset a loop without outstanding MIDI notes or controller state. This does not prove the SoundFont release envelope is inaudible at the boundary. Audition the actual loop.

## Evidence and playback

Python assertions check deterministic source/output parity, the frozen gate hash, encoder guards, 60–120 second duration, release sections, phrase use and arrangement variation. Normalized main riffs and drum patterns differ across all eight scores; this is a structural check, not a claim of heard quality. Godot assertions use the shipped SMF reader to check actual track events, note balance, programs/channels/controllers, tempo/meter/section parity, end-of-track and release duration. They also load the actual bank and require every authored pitch/velocity to have a matching zone. Bank release envelopes and percussion auto-release/finite-PCM bounds must finish before the loop, including a 100 ms dispatch/buffer allowance. This deterministic bound does not replace listening or cover arbitrary frame stalls.

`game/audio/music.gd` selects these files in table order and reuses the packaged bank. A full native CoreAudio run completed one repeat of every score, pause/resume and stop/switch checks, with non-silent output, zero clipped frames and zero dropped capture frames. The two-second capture buffer preserves PCM across the observed 1.259-second source-file preparation stall; the zero-drop assertion remains unchanged. Settings tests verify the independent Music gain. Listening quality, perceived loop seams and the complete campaign remain acceptance gates; no static or mixer-capture test approves unheard music.
