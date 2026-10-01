# Game project checkpoint

Date: 2026-10-01
Thread: `01a0f03f-e2f6-7be1-926a-af974a4ed8b7`

[DESIGN.md](DESIGN.md) owns the approved eight-level brief; [ARCHITECTURE.md](ARCHITECTURE.md) owns file and module boundaries. Jared approved implementation and private GitHub delivery on 2026-09-30. The goal remains active.

## Current state

- The verified private repository is [ihearttokyo/null-choir](https://github.com/ihearttokyo/null-choir). Canonical branch is `main`, tracking `origin/main`; the documentation rollback commit is `e34fae907d77f259fda026205318d17488242427`. Development checkpoints are not release acceptance. Inspect Git for the current commit and divergence.
- One hand-authored Intake level exists. Native Godot combat, two enemy roles, two weapons, pickups, key gate, checkpoint/death restoration, persistent saves, title/pause menus and two physically traversable loops are implemented. Seven levels, four weapons, remaining enemy/boss roles, campaign ending, full settings/rebinding, sound effects and final polish remain.
- Original Blender sources and 13 runtime art exports cover the two enemies, two weapons, two bespoke loop heroes and supporting world kit/textures. The parent stopped the art child and owns integration. Frozen recipe SHA-256: `ba3f8b0414f669b82ca017f28c437085c938447bdf98036c7507f725aaf25776`. All assets were regenerated from that recipe; initial concurrent-build output is rejected.
- The live-MIDI gate passes outside the sandbox with native CoreAudio: two real wall-clock repeats, non-silent PCM, no clipping/discards, and silent mute/pause/stop. Gameplay now owns one persistent bank and passes start/pause/resume/restart/title checks. The current short fixture is not a final level song. All eight final songs remain.

## Evidence and open gates

- Real headless Godot assertions pass for campaign persistence and validation, firing/ammo, gate connectivity, enemy damage/infighting/poses, first-level scene restoration, and interaction occlusion. Native capsule motion traverses both authored loops and ramps without jumping; input is simulated and this does not prove GUI usability or final map pacing.
- Blender pose isolation and art file/provenance/hash contracts pass. Sprite and hero contact renders were inspected; in-game visual review remains open.
- The child supplied actual exported SoundFont PCM, pitch bend and volume checks. Parent CoreAudio execution has no shutdown warning; prior direct child-test warnings remain documented. Listening quality, GUI controls and sustained native playback remain open. Audio input is unavailable to the assistant; Jared was asked to audition the native recording. The provisional GeneralUser sample-origin qualification is retained.
- A first-level Mac ZIP passes arm64-only, strict ad-hoc signature, system-only dependencies and native packaged start/fire/pause/checkpoint checks. It is a development build, not the finished campaign. NOT RUN: computer-use GUI validation, full campaign playthrough, final-song audition, launch/transition/combat performance, Developer ID signing/notarization and GitHub release.
- Required test/child settings are `gpt-6.1-sol`, `xhigh`, `service_tier="default"`, Fast off. Launch headers expose model/effort; fresh service-tier telemetry may be unavailable. Missing telemetry is a reporting limitation, not a blocker. No runtime substitution is authorized.

## Ownership and resume

The parent owns all current implementation and integration paths. Both bounded workers have handed off and are archived. An independent read-only review identified completed-map resume, sprite yaw, occluded auto-aim candidates and failed-save session loss; parent regressions proved each RED and the fixes GREEN. Child sessions: audio `01a0f271-304c-7302-ba0a-0fe0f4d5d279`; interrupted art `01a0f276-d86f-7de0-818e-c03ddf2e3dce`. A resumed child requires fresh nonoverlapping ownership. Native process/tool handles are transient: inspect live state before reusing them.

Next: finish the integrated suite and final Mac rebuild, commit/push explicit validated development paths, and continue settings, sound effects, visual polish and the remaining campaign. A concrete request for foreground playtesting and palette audition is pending; keep independent work moving without treating an absent reply as approval.

Raw receipts are outside Git under `/Users/jared/.codex/tasks/01a0f03f-e2f6-7be1-926a-af974a4ed8b7/`. This checkpoint is development state, not release acceptance.
