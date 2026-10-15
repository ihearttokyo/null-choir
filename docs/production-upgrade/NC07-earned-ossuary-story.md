# Earned Ossuary Story receipt runner

`tools/check_ossuary_story.py` runs `res://tests/test_ossuary_story.gd`
with managed Godot, an isolated temporary profile and merged stdout/stderr.
It evaluates the complete output after `subprocess.run` returns. A timeout
fails even if a PASS appeared earlier. The default timeout is 1800 seconds;
default timing does not set `--fixed-fps`.

From the integrated project root:

```sh
python3 -m unittest discover -s tests -p test_ossuary_story_runner.py -v
python3 tools/check_ossuary_story.py
python3 tools/check_ossuary_story.py --fixed-fps --timeout 1800
python3 tools/check_ossuary_story.py --omit-interact --timeout 1800
```

`--fixed-fps` passes `--fixed-fps 60`; it is a simulation setting, not an FPS
measurement. `--omit-interact` passes the Godot user argument
`--omit-ossuary-story-interact`. The two options may be combined.

Positive acceptance requires exit 0, shared `check_game.accepted`, the exact
Story PASS line once, and one each of the `OSSUARY_STORY_EARNED` and
`OSSUARY_SECOND_EARNED` labels with their authored `frames=` prefix.
Earned payload values remain variable. Omission requires exit 1, one Second
receipt, the exact readiness line once and this exact error once:

```text
ERROR: OSSUARY_WITNESS NATIVE RED Story requires one queued rebound E interaction, original marker drain, discovery5 and authored notification
```

Omission rejects Story-earned and Story-PASS receipts. Only that exact error
line is removed before diagnostic checking. Both modes reject unexpected
error, warning, parse, assertion, leak and resource-use diagnostics, including
shutdown output. A profile and its temporary, data, config and cache directories
are removed on success, rejection, timeout or launch failure. The child inherits
only `LANG`; its other environment entries are the managed PATH and isolated
profile paths.

## Retained validation

The source-native replay earns the preceding five maps, both Ossuary loops,
then the optional Story spur and return. The interaction queues a rebound E
press and release through production input. The original marker retires,
discovery 5 and its authored notification appear, and both earlier witnesses
remain frozen. Return resources are 100 health, 196 armor, 169 rivets, 32 shells
and 120 cells; the pre-existing campaign save remains byte-identical.

- Fixed-timing positive: exit 0, 707.933 seconds, 2,564 Story frames.
- Normal-timing positive: exit 0, 1,284.557 seconds, 2,658 Story frames.
- Omitted interaction: exit 1 after the actual earned handoff, exactly one
  readiness receipt and the intentional error above; no other diagnostics.
- Earned-boundary forged callback and stale identity: refused without changing
  frozen records. The restored identity passes; this control skips the spur.
- Detached guard runner: 22 cases and exactly 18 expected errors.
- Python receipt/command tests: 24 methods including the existing guard runner.
  Mocked command tests establish parsing and cleanup cases, not native play.
- Fresh fixed-timing public CLI: exit 0 in 745.690 seconds, both required PASS
  receipts once and zero remaining owned profiles.
- Actual full positive and omitted logs pass the current public classifier.
  A one-second public-runner timeout exits 1 and removes its isolated profile.
  That timeout did not reach the engine startup banner.

Independent correctness and Ponytail reviews cover the current source. All
native acceptance logs retain complete merged output and drained owned process
groups. An earlier omitted run failed a Second-loop bound before Story adoption;
it is retained as a failed attempt, not counted as the intended omission RED.

The snapshot comparison change preserves the existing stored-field oracle.
It reuses equal frozen containers only inside a synchronous local comparison
and canonicalizes unequal containers and Object identities. Native parity
checks cover nested mutation, live/freed Objects and null, container types. In a matched eight-interval instrumented test window, canonicalizer
calls fell from 6,317,184 to 571,128; helper self time fell from 0.798359 to
0.282501 seconds. Script self time and window duration also fell. These are test
helper measurements, not game FPS, startup, GPU or memory improvements.

This is headless source-native evidence with synthetic input. Physical mouse
and gamepad, current packed-app behavior, eight-level campaign completion,
visual fidelity, measured game FPS and listening acceptance remain unverified
by this change. Original sources, runtime maps, gameplay and recordings are
unchanged.
