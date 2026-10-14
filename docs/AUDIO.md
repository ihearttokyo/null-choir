# Current campaign playback

`game/audio/music.gd` uses one native AudioStreamPlayer and lazily loads the selected MP3 for each level. It routes to Music without changing user bus gain or mute, repeats the recording, freezes playback on pause, restarts on level restart and releases its stream on title. Combat pressure smoothly lifts the complete stereo mix from -3 to 0 dB; separate MIDI stem expression no longer applies. `playback_started` provides the synchronous placement/recovery regression observation point after native playback starts.

Original downloads, selected song IDs, hashes and conversion provenance are in [the Suno manifest](../source/music/suno/manifest.json). FFmpeg is needed only for authoring; Godot decodes the packaged recordings without host tools. Full listening and standalone-app acceptance remain separate.

## Preserved MIDI implementation

The remaining documentation describes the retained synth and `game/audio/midi_music.gd`, exercised by legacy MIDI tests rather than campaign playback.

# Live MIDI runtime

`game/audio/midi_music.gd` is a persistent Node. Add it once after the audio bus layout is loaded. It creates the Music bus only when absent, loads the packaged bank once, and retains that bank across track changes. The game owns Music volume and mute settings.

## API

- `play_level(index)`: zero-based index into `level_tracks`; replaces MIDI event data and resets notes, tempo and channel controllers. Invalid/missing tracks leave current playback unchanged and report an error.
- `set_paused(paused)`: freezes the MIDI clock, envelope timers and both sides of stereo PCM playback. The Node processes independently of SceneTree pause; the game must call this API when pausing.
- `set_pressure(value: float)`: requests an accompaniment mix without seeking or restarting playback. Finite values clamp to `[0, 1]`; non-finite values request zero. Linear smoothing traverses the full range in 0.25 seconds on attack and one second on release, and freezes while paused. Repeat and level switch reapply the current mix after the player's controller reset.
- `stop()`: silences primary and linked voices immediately and clears note bookkeeping. The next play resets channel state.

Pressure defaults to zero. At zero, expression is 0.35 for guitar, 0.8 for bass, 0.6 for saw and 0.55 for drums; at one, each reaches one. Organ expression remains untouched at one. These factors only attenuate authored channel volumes through the existing volume-only `_apply_channel_volume` API. The same player, bank and voice pool remain in use. Pressure never writes the user Music bus gain/mute or the synth-master gain. The parent derives pressure from active threats and damage; the music node owns only its smoothing and expression application.

The track list contains the eight original campaign MIDI files in level order. [Campaign scores](MUSIC.md) owns their editable sources, arrangement and generation contract. The retained gate fixture isolates scheduler and synthesis regressions. The approved palette uses Distortion Guitar (30), Pick Bass (34), Pipe Organ (19), Saw Lead (81) and Standard 1 drums (bank 128/program 0), with zero-based GM program numbers.

## Timing and tails

The patched player consumes elapsed seconds up to each MIDI event before applying the next tempo. Tick-zero and exact-boundary events are inclusive. It retains overshoot across multiple loops, resets controllers/tempo on seek or repeat, and uses the final end-of-track tick as the explicit loop boundary. `source/music/gate.json` owns the fixture data; `python3 tools/compose_music.py --gate` verifies its frozen MIDI without replacing it. The default composer command generates the eight campaign files.

Natural note-offs use the SoundFont release envelope. Repeat, stop and level switch cut old release tails; they do not carry sustained voices into a new track. Author silence/release space before an end-of-track boundary, then audition the boundary. The scheduler dispatches on frames. Frame and audio-buffer latency affect event placement; exact logical tick duration alone cannot prove an inaudible seam.

## Dependency provenance and patches

The synth is pure GDScript, using native Godot audio streams and effects. No FluidSynth, Homebrew audio library, native plug-in or rendered music file is part of playback. The project-local dependency is necessary for reproducible offline application behavior.

- [arlez80/godot-midi-player-g4](https://github.com/arlez80/godot-midi-player-g4), revision `252157b64e9a94686b363b3cce53f195cb828aa2`; prepared archive SHA-256 `ac12e4ffae838caa83bba5a278a1ab63ad87aab3b6a82a121564c83c0249ddbd`. MIT license: `licenses/audio/godot-midi-player-MIT.txt`, packaged copy `game/addons/midi/LICENSE.txt`.
- [mrbumpy409/GeneralUser-GS](https://github.com/mrbumpy409/GeneralUser-GS), revision `684543d5e5efaef08d02be50dcda8d552478fa60`; bank SHA-256 `9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe`. License: `licenses/audio/GeneralUser-GS-license.txt`, packaged copy `game/audio/LICENSE-GeneralUser-GS.txt`.

GeneralUser GS permits music creation and software packaging, but its author explicitly cannot establish every historical sample origin. This bank is provisional for private project playback. These permissions are not a claim of independently verified sample clearance or authorization to publish the game externally.

Local patches are owned by these files:

- `MidiPlayer.gd`: event-boundary clock, complete pause, fresh channel state, replaced voice cleanup, quietest released-voice selection and guards for empty tracks/banks, unsupported timebases and invalid tempo.
- `ADSR.gd`: sample attenuation and linked PCM cleanup at release completion.
- `Bank.gd`: intersected key ranges, exact encoded bank/program selection, complete even-length PCM slices, packed silence and immediate removal of unused parsing metadata/backreferences.
- `SMF.gd` and `SoundFont.gd`: failed-file-open guards; SMF additionally rejects either malformed header field and unsupported timebases.

Raw upstream diffs and RED/GREEN evidence belong to the task receipt, not Git. No selected sample data is compressed or resampled by these patches.

This add-on does not implement every SoundFont modulator/filter or GS feature. Approve the actual palette by audition; a correctly mapped program is not proof of equivalent full SoundFont synthesis. Jared approved the presented native palette on 2026-10-02. Final-song composition and synthesis checks may proceed without another palette confirmation; song quality and repeat/switch checks still need evidence.

## Validation and integration

Run direct assertions with Godot 4.7.2 after importing the project:

```sh
python3 tools/check_game.py --timeout 150 tests/test_midi_reliability.gd tests/test_midi_timing.gd tests/test_midi_audio.gd tests/test_midi_bank.gd tests/test_music_pressure.gd tests/test_campaign_music.gd
```

The pressure assertion manually advances the real scheduler and checks finite clamping, attack/release, pause, channel-bus gains, unchanged transport/bank/voice pool, repeat/switch and independent user settings. The runner uses native CoreAudio and rejects runtime errors and leaked resources. Reliability checks include exact mono/linked-stereo bytes, voice saturation, empty tracks/banks, malformed headers, invalid timebases and an encoded zero-tempo event. Audio teardown yields native frames for at least 150 milliseconds of monotonic wall time; simulated SceneTree timers are not audio-thread timing evidence. Headless native checks establish PCM/state behavior, not perceived mix or musical quality. Actual mixed gameplay listening remains required.

The isolated gate, export preset and Mac application are under ignored `builds/midi_gate/`. The receipt at `/Users/jared/.codex/tasks/01a0f03f-e2f6-7be1-926a-af974a4ed8b7/midi-runtime/` owns current results, raw logs, captured output and remaining gates. Parent integration must include `*.mid` and `*.sf2` in export filters, retain the packaged licenses, and use an arm64 Mac export. The installed official Mac template contains universal binaries; the gate derives arm64 template binaries locally with Apple `lipo`, without changing global templates.

The final gate report distinguishes deterministic timing, actual exported synthesis capture, objective instrument assessment, listening, and GUI checks. No headless assertion establishes usability or unheard musical quality.

Before the first source commit, inherited trailing whitespace was removed from MidiPlayer.gd, SMF.gd and SoundFont.gd. The executable token/indentation content is unchanged by that cleanup. GeneralUser license bytes retain their original CRLF endings through scoped Git attributes.

## Shutdown checks

The corrected quit helper stops audio through `show_title()`, cancels pending placement, releases map/player ownership and schedules final quit after a 0.1-second mixer grace. Normal quit and explicit discard share this path. Save failure retains the recoverable session instead of starting shutdown.

`python3 -B tests/test_native_shutdown_import.py` runs two mocked-subprocess checks. Importing the native runner must launch nothing; explicit entry must retain its normal/discard modes, isolated profile, deadline and strict error/leak assertions. These checks never run Godot.

The separate `tests/test_native_shutdown.py` runner intentionally uses windowed Metal/CoreAudio because the retained headless diagnostic did not expose the playback leak. Its explicit entry remains held until engine/crash and nondisruptive GUI authority are cleared. Do not run it during ordinary import/discovery or assume headless physics can certify audio shutdown. Retained pre-hold native GREENs support the reviewed source identity; corrected packed-app behavior, expanded placement checks and release promotion still require their own acceptance evidence.
