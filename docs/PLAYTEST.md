# External playtest preparation

These Python tools prepare a bounded external playtest and verify its local
journal. They are not runtime AI, do not attach to the campaign, and do not
launch Godot or control the desktop. Live provider activation is disabled.
The native bridge, mailbox and viewport producer remain outside this source-only
change pending engine, crash, native and GUI acceptance.

## Gates

Do not enable provider traffic or input from these tests. Existing secure-account,
pricing, fee, credential and live-acceptance gates still apply. This work creates
no keys, funds no account and makes no paid API call. Recorded usage and budget
reservations are not billing evidence. Private captured frames stay local;
structured player-observable state is the intended future provider boundary.

The game must independently expire and release inputs after a 0.2-second lease,
including pause, focus loss, stop and pilot failure. Python fixtures do not prove
that native behavior. Do not run Godot, exports, viewport capture or foreground
checks while their holds remain active. Preserve existing user saves and windows.

## Modules

- `playtest_protocol.py`: allowlisted actions, sanitized observations, serial
  decision reservations and private journal records.
- `playtest_transport.py`: disabled, bounded HTTPS decision adapter; no retries
  or provider response bodies in diagnostics.
- `playtest_supervisor.py`: deadline-bound owned Python worker and process-group
  cleanup; it never launches the game.
- `playtest_bridge.py`: strict wire contracts and a simulated input lease.
- `playtest_mailbox.py`: private descriptor-relative request/response files,
  one in-flight request and bounded atomic commits.
- `playtest_recorder.py`: capture scheduling and journal budget accounting.
- `playtest_capture.py`: verified local PNG handoff, hash/size/profile checks,
  backpressure and a finite next-capture grant.
- `playtest_pilot.py`: serial orchestration, issued-command identity, local
  deadlines, completed-action frame barrier and fail-closed stop.
- `playtest_report.py`: read-only journal/capture integrity and sample statistics.

A prospective run is bounded to 120 seconds, 240 decision attempts, 300 captures
and 250 MiB of journal/capture data. The capture producer must separately bound
its own staging allocations and IPC files. Captures have an 8-MiB byte limit and
at most 1280 by 720 pixels. These limits are safeguards, not activation authority.

## Resident checks

Use Python 3.11 or newer from this checkout:

```sh
python3 -m unittest tests.test_playtest_protocol tests.test_playtest_transport tests.test_playtest_supervisor tests.test_playtest_recorder tests.test_playtest_bridge tests.test_playtest_mailbox tests.test_playtest_pilot tests.test_playtest_capture tests.test_playtest_capture_pilot tests.test_playtest_report -v
```

The 164 checks use real private temporary files and real isolated Python process
cleanup where required. Provider replies, telemetry, clocks and PNG pixels are
controlled fixtures. They do not contact the provider, inject native game input,
launch an engine, capture the user's screen or certify graphics/audio quality.
Local static native-source checks are separate and are not included in this PR.

## Read an existing local journal

Call `tools.playtest_report.report_run(root, run_id=..., build_sha256=...)` with a
known resident, nonsynced, stable run directory and its independently known
identity. The root must be owned and mode 0700; index and referenced PNGs must
be regular owned mode-0600 files with one link. Symlinks, FIFOs, observed dataless
files, drift, invalid schemas and bounds violations are rejected. Do not hydrate
cloud placeholders to make a report pass.

The reader streams up to 4096 rows, each at most 20 KiB, and verifies one bounded
PNG at a time. It does not load the complete capture corpus or read unreferenced
IPC bodies. A sanitized `ReportError` rejects unsafe or changing evidence.
The caller must first obtain stable local evidence before considering a retry.

The returned report counts recorded command attempts and token usage, unique
one-world-unit pose bins, sampled displacement/turns, observed ammo and health
decreases, and missing post-action frames. Scene/player changes reset movement
and resource comparisons. A matching post-action capture needs the same scene,
the exact next action sequence and a frame newer than the issued observation.
Missing stop and frame records produce explicit diagnostics.
A stop record must be terminal; any later row rejects the report before a later
capture is read. Open or interrupted journals still report the missing stop.

These are sample-only observations. No map denominator, coverage percentage,
campaign-completion verdict, native input/render-origin proof or actual API cost
is supplied. A stop record does not prove that a native process exited.

## Next acceptance

The local Python contract is reviewable independently. Native parsing, private
file guarantees, lease release, completed viewport provenance, allocation and
GPU latency, and actual app-path behavior still need their own evidence after
hold clearance. Settings, Controls and difficulty must remain selected during
both placement-wait phases without resuming gameplay or capturing the mouse;
cancel/restart/stale level-player guards must also pass. Source-only checks do
not close those gates or authorize app/project/release promotion.
