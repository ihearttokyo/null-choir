# Earned Ossuary preparation receipt runner

`tools/check_ossuary_preparation.py` runs the canonical
`res://tests/test_ossuary_finale_preparation.gd` with managed Godot, headless
rendering, CoreAudio and an isolated temporary profile. The fixture inherits
Master-bus muting from the existing campaign test chain. This runner evaluates
complete merged stdout/stderr only after the child finishes. A timeout rejects
partial output even when all success lines have already appeared.

From the coherently integrated project root:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_ossuary_preparation_runner.py -v
python3 tools/check_ossuary_preparation.py
python3 tools/check_ossuary_preparation.py --fixed-fps --timeout 1800
python3 tools/check_ossuary_preparation.py --omit-gate --timeout 1800
```

Default timing adds no fixed-FPS flag. `--fixed-fps` passes `--fixed-fps 60`;
this is simulation timing, not an FPS measurement. `--omit-gate` passes the
Godot user argument `--omit-ossuary-preparation-gate`. The flags may be combined.
The default timeout is 1800 seconds; supplied timeouts must be finite and
positive. Other scripts, engine overrides, option abbreviations and unrelated
user flags are rejected before launch.

## Receipt contract

Both modes require exactly one `OSSUARY_SECOND_EARNED` and one
`OSSUARY_STORY_EARNED` line. Each earned line has the exact authored label,
a decimal `frames=` value, a nonempty variable payload and terminal
`prior_frozen=true`. Values in Godot's printed dictionaries and arrays remain
opaque: the Python parser does not independently prove resources, capture
counts, saved bytes or physical input from that text.

Positive acceptance requires exit 0, shared `check_game.accepted`, one
`OSSUARY_PREPARATION_EARNED` line with the same framing and this exact PASS
line once:

```text
PASS bounded earned Ossuary saved checkpoint/original gate preparation; synthetic native input, not finale/app acceptance
```

Positive mode rejects omitted-readiness receipts. Gate omission instead
requires exit 1, the same completed Second/Story evidence, this exact readiness
line once and the exact intentional error once:

```text
OSSUARY_PREPARATION_OMITTED_GATE_READY checkpoint_saved=true gate_live=true finale_dormant=true prior_frozen=true
ERROR: OSSUARY_WITNESS NATIVE RED preparation requires queued rebound E original gate after saved checkpoint
```

Omission rejects preparation-earned and preparation-PASS lines. It exempts
only the exact error line above from diagnostics. Missing, duplicate,
case-changed, malformed or mode-mixed reserved receipts fail. Both modes reject
unexpected errors, warnings, parse/assertion failures, leaks and resource-use
diagnostics anywhere in the full stream, including shutdown. A benign Godot
`push_error` backtrace frame is not itself an additional error.

The runner resolves `godot` only through `/opt/homebrew/bin:/usr/bin:/bin`.
It creates temporary HOME, temp, data, config and cache directories and removes
them after success, rejection, launch failure or timeout. Only `LANG` is
inherited; managed PATH and isolated profile paths form the remaining child
environment. Existing user campaign/settings files are outside that profile.
It uses the existing headless fixture, without moving user windows or adding
GPU, microphone, listening or human-input checks.

## Recorded source-native evidence

The source-native checks below completed with Godot 4.7.2 on the Apple Silicon
Mac. The campaign inputs are synthetic. Neither timing mode measures FPS or
proves human-input or packed-app acceptance.

| Check | Recorded result |
|---|---|
| Canonical preload/pin chain and detached fixture | PASS; the inherited 213 script fields remain unchanged, with no allocated game/root children. |
| Adopted-policy negatives | PASS after the actual completed Second/Story prefix. Forged/stale capture attempts preserve state, file and frozen history before re-adoption. A real Player/passive checkpoint attempt in the wrong observer phase rolls back without capture/save. Exactly four intentional observer errors are expected in this separate control run. |
| Public fixed-timing gate omission | PASS; actual saved-checkpoint/live-gate/five-dormant/frozen-history READY precedes the sole exact gate error. The native child exits 1; the public expected-omission workflow exits 0. |
| Public fixed-timing positive | PASS; 612 new preparation physics frames, two captures, one save, one queued E gate operation, original-body drain and crossing to [22.5,30.5]. |
| Public normal-timing positive | PASS without a fixed-FPS flag; 647 new preparation physics frames and the same capture/save/gate and endpoint invariants. |
| Existing guardian controls | PASS; 22 controlled cases with exactly 18 intentional errors and no unexpected diagnostics. |
| Native frozen-history unit | PASS through the public clean-output runner; exact WeakRef identity survives target retirement, while substitutions, nested changes and unapproved raw-object retirement fail. |
| Python receipt/command tests | PASS; 48 methods across the preparation and existing Story runner suites. Subprocess streams are simulated; temporary-profile cleanup uses real local directories. |

Both positive runs finish with 100 health, 200 armor, ammunition
`[0,180,32,120,8,0]`, weapons 0 through 3 owned and the pistol selected. Slot 4
ammunition does not grant launcher ownership. All five finale originals remain
full and dormant; the 22 earlier deaths and prior stored records remain frozen.
The checkpoint marker remains present despite its recorded removed ID.

Before capture 1, the witness constructs the complete expected checkpoint
document, canonical bytes and digest. During the save, production performs
capture 2; its bytes, digest and a separate validated reload must match that
prediction. Fixed and normal checkpoint digests differ.
These checks prove each run's predicted serialization, not byte-identical
cross-run determinism. Both public runs consume complete merged output, reject
shutdown diagnostics and remove their isolated temporary profiles.

The source proposal's pure RED showed the existing Story classifier rejecting
these new receipts. Independent correctness and Ponytail reviews also found
and closed the early-prediction ordering gap and a missing per-rejection
frozen-history assertion in the private policy harness. Their controlled
mutation checks remain separate from the earned native results above.

Run the maintained history unit with:

```sh
python3 tools/check_game.py tests/test_ossuary_preparation_history.gd
```

## Remaining acceptance

This segment stops before the finale encounter. Subsequent five-actor combat
coverage is recorded in [the finale battle receipt](NC07-earned-ossuary-finale-battle.md).
Saved exit, Inversion entry and the rest of the full campaign remain unfinished. Current
standalone export, physical keyboard/mouse/gamepad play, visual fidelity,
GPU/performance and listening acceptance are separate requirements. Source
replay results do not certify them. The retained original MIDI sources and the
selected Suno playback are unchanged by this test-only work.

The preceding Story receipts are described in
[the Story runner documentation](NC07-earned-ossuary-story.md).
