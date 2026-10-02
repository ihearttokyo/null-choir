# Game project checkpoint

Date: 2026-10-02
Thread: `01a0f03f-e2f6-7be1-926a-af974a4ed8b7`

[DESIGN.md](DESIGN.md) owns the approved eight-level brief; [ARCHITECTURE.md](ARCHITECTURE.md) owns implementation boundaries. The goal remains active. Routine implementation, validation and private GitHub delivery are approved without repeated confirmation. The same confirmation rule is recorded in the canonical global custom instructions.

## Current piece

The Oct 2 scenery correction is implemented. Intake has original Blender ribbed walls, conduits, vaults, reliefs, suspended anatomy, containment machinery, drain altars and actual lamps. Both loop heroes were rebuilt with editable Blender sources. Warm/cold pools, four shadowed landmark spots, depth fog, textured clockwise-facing floors/ceilings and shaded sprites now render in-game. Collectibles reuse miniature Blender cages with color-coded fluid cores instead of cubes. [SCENERY.md](docs/SCENERY.md) owns rendered views and GPU evidence.

Persisted settings, native keyboard/mouse/gamepad rebinding, motion toggles and independent Music/Effects sliders are integrated. Native screen-relative mouse look and event-based short firing taps retain held-fire cooldown. Eight original MIDI files select in campaign order and reuse the packaged SoundFont. [MUSIC.md](docs/MUSIC.md) owns compositions and playback evidence.

The campaign remains unfinished: Intake has two loops, two weapons, two enemy roles, one optional story discovery, pickups, key gate, ramps, checkpoint/death restoration and saves. Seven maps, remaining weapons/enemies/bosses, ending, sound effects, heard musical quality and full pacing/performance acceptance remain. Merciful entry lost 83 health during an unattended GUI interval; inspect early combat pacing before treating this as finished-game playability.

## Evidence

- Native scene regressions prove local mesh bounds, clockwise faces, texture tint, inward art fronts, wall mounting, lamp ceiling clearance, collision bases, supporting art, collectible scale and wall-only conservative occlusion. Intentional RED/GREEN receipts are retained.
- The latest 14 native gameplay checks pass after the final collectible change; actual fixed-FPS native capsule traversal passes both loops and ramps. Art checks pass 18 assets/19 exports and source/output parity. Parent verified 33 Blender handoff hashes and all 22 protected originals. Eight source/import native Blender/Godot checks pass.
- Three serial native GPU control/treatment pairs retained wall occlusion with pixel-identical static views and 61.7→115.5 controlled-combat median FPS. Final pod-dressed source views sample 96.4 FPS at entrance and 118.7 in controlled combat. Warm level builds are 111–122 ms. One cloud-backed source load took 28.4 seconds; this is not a packaged cold-start measurement.
- All eight songs completed full native CoreAudio repeats, pause/resume and stop/switch, with non-silent output, zero clipping and zero dropped capture frames. A one-second collector previously overflowed during a measured 1.259-second preparation stall. The bounded two-second collector passed the full rerun without changing production playback or weakening its zero-drop assertion. Listening quality and perceived seams are not approved by mixer capture.
- Actual Mac GUI checks pass title/settings/scrolling, sensitivity/toggle/audio feedback, keyboard rebind with retained pad axis, cancellation, defaults, difficulty, entrance rendering, short tap firing (ammo 90→89), Escape pause and save-to-title/Continue. Final exported Bell/Siphon views use valid controlled saved-game positions with cleared hostiles, not completed playthroughs. Other apps/windows are untouched; the validation app is quit and original save bytes/settings absence are exactly restored.
- The arm64 0.1.1 ZIP is `builds/macos/NULL CHOIR-arm64.zip`, SHA-256 `a708e9a83208a6d8d87bb4d8a666d24d18a3ca1b1cfff12a35ee616d0ab183bf`. Strict ad-hoc signature, system-only dependencies, packaged notices and offline start/fire/pause/checkpoint checks pass. Local validation app: `/private/tmp/null-choir-scenery-0.1.1-delivery/NULL CHOIR.app`.
- Dummy-driver assertion fixtures retain 15-ObjectDB teardown warnings in several immediate-quit cases. Real CoreAudio song capture, native traversal and packaged checks have clean teardown; warnings are not relabeled clean passes. Physical controller testing, precise cold-launch targets, full campaign, listening acceptance and Developer ID signing/notarization are NOT RUN.

## Git, children and resume

Private target: [ihearttokyo/null-choir](https://github.com/ihearttokyo/null-choir), verified private with ADMIN permission and default branch main. Last published development commit is `28f7101a693e58a91efe00ce81f315cad721caef`, tracking origin/main. One owned worktree; no topic branches or PR. Current integration edits are uncommitted; final delivery is being prepared. Reconcile live Git before resuming.

Music worker `01a0f9df-92e9-70c0-b7c6-08e137d16603`, controls reviewer `01a0f9ea-2bb1-7a61-9b5a-300de57839c8`, Blender worker `01a0fa0e-0197-7941-87cd-e9f70c6c8999` and scenery reviewer `01a0fa21-0ada-77b1-9d5a-584a6e079c11` completed and are archived. Parent integrated actionable findings and repeated correctness/Ponytail reviews for winding, sprite lighting, occlusion, audio instrumentation and collectible changes. CLI children used gpt-6.1-sol xhigh, requested service_tier="default", approval never and bounded ownership; actual service-tier telemetry and independent native parent linkage are unavailable. Memory observations were 75–76% free with zero swap.

Next: final exported screenshots and save restoration are complete. Verify staged diff/secrets/targets, commit and push the validated source, then publish the exact ZIP as a private 0.1.1 development prerelease. Update this delivery state and continue the remaining campaign in pieces, with early pacing and final visual quality still requiring real playtests. Do not reopen accepted design or routine approval decisions.

Raw receipts and rollback copies remain outside Git under `/Users/jared/.codex/tasks/01a0f03f-e2f6-7be1-926a-af974a4ed8b7/`. Old ZIPs/handles are stale; inspect live files/processes rather than reusing them blindly.
