# Game project checkpoint

Date: 2026-10-02
Thread: `01a0f03f-e2f6-7be1-926a-af974a4ed8b7`

[DESIGN.md](DESIGN.md) owns the approved eight-level scope; [ARCHITECTURE.md](ARCHITECTURE.md) owns module boundaries. Goal active. Routine implementation, validation and private project/app delivery remain approved without repeated confirmation. The prior scenery turn was progress: original Intake art, native lighting, eight live MIDI tracks, options and private 0.1.1 delivery. This continuation adds Foundry rather than redefining success around Intake.

## Current piece

Intake and Foundry are implemented: two loops and two unique original Blender hero pieces per map, key gates, one optional clue per map, ramps, checkpoints/death/restart and persisted progression. Foundry adds the vertebral furnace and marrow crucible, 52 supporting placements and 27 lights including four shadowed landmark spots. [FOUNDRY.md](docs/FOUNDRY.md) owns pictures, native behavior and performance evidence; [SCENERY.md](docs/SCENERY.md) owns the Intake correction. Eight MIDI scores/options/rebinding are unchanged and retained.

The earlier entry-health symptom was reproduced: two Intake enemies had immediate native sight, causing 90 damage in ten simulated Merciful seconds. Only their authored positions moved behind the first junction. Both maps now pass damage-free ten-second entry on all three difficulties and retain encounter activation. Review found the live player exit callback overwrote the next spawn after interaction; one early return fixes it. Real engine input proves RED/GREEN and the actual exported app enters Foundry at `[58,0,122]`.

The campaign remains unfinished: six maps, four weapons, four regular roles, two bosses, ending, sound effects, all eight discoveries/alternate revelation, full playthrough/pacing and final visual/performance acceptance remain. Physical controller, heard music, precise packaged cold-start/transition targets and Developer ID signing/notarization are NOT RUN. Do not mark the goal complete or reduce the scope.

## Evidence and preserved state

- Sixteen native CoreAudio gameplay/layout/options checks pass with no warnings; new real-input transition also exercises Foundry clue interaction, gate, automatic checkpoint, death, saved Continue and restart. Actual native capsule traversal passes both Foundry loops and ramps without jumping/falling. Source view rerun passes. Both maps' entry tests pass all three modes; Intake's original floor corners/roof heights remain exactly covered.
- Art parity passes 20 assets/21 exports. Foundry has 296/194 editable meshes, 24,584/23,076 triangles and combined 4,093,296-byte GLBs, seven material groups each. All 35 original source/output hashes and 18 prior manifest entries are unchanged. The initial four-MiB budget failure was repaired by reducing only small gauge-ring tessellation; its assertions remain intact.
- Initial source build was 137 ms and controlled combat 89 FPS; final source views sample 118/105/102/98 FPS and retain a 33.1-second cloud-backed source-load outlier. Native packed data/imported art parity passes 33 resources. Neither source sample establishes full-campaign or packaged cold-launch acceptance.
- Actual Mac GUI passes controlled Intake-exit Continue, E intermission, Descend to correct Foundry entry, pause/save-title/Continue, short fire and restart resource feedback at 1280×784 capture resolution. The owned new app PID 40791/window 2864 is quit. Original campaign SHA `1969dc64b55cfa6c2035d509910d65a2032769fabed1ec84261a249b8778376b` and preferences absence are restored. Existing 0.1.1 PID 10787 was found running and left untouched; do not assume all game processes are owned or quit.
- Final 0.1.2 ZIP SHA `0395ecc3709fe524a8c661a0bbc04345c97b6daa6e49172fde41591cc9f02a77`, 61,339,687 bytes. Strict ad-hoc signature, thin arm64/system-only dependencies, offline native Foundry/art/live-MIDI checks pass. Local immutable ZIP is in the receipt's `release/`; app `/private/tmp/null-choir-foundry-0.1.2-dub_wq8c/NULL CHOIR.app`.
- All eight unchanged scores pass structural/encoder parity. Prior full native CoreAudio repeats/pause/switch/zero-drop evidence remains valid for unchanged songs and synth; listening quality remains separate.
- Raw harness failures are retained: same-frame manual action did not become just-pressed (replaced with real engine tick). Traversal assumed zero yaw (fixed native inverse-basis conversion), then a real altar blocked its route (moved to perimeter); raw source PNG/GLB hashes are unavailable after native import (final check covers shipped caches). An initial snapshot JSON used Path keys; corrected string-key post-build snapshot and actual packed parity are recorded. None is relabeled as an accepted RED or successful check.

## Git, children and resume

Private target [ihearttokyo/null-choir](https://github.com/ihearttokyo/null-choir), live verified private/ADMIN/default main. Source `main@9ddfb8ac78b692c12901efd881571656a1de73a3` is pushed. [0.1.2 private development release](https://github.com/ihearttokyo/null-choir/releases/tag/v0.1.2-dev) is published, with its tag pinned to that tested source commit. GitHub confirms the uploaded `NULL.CHOIR-arm64.zip` is 61,339,687 bytes with SHA-256 `0395ecc3709fe524a8c661a0bbc04345c97b6daa6e49172fde41591cc9f02a77`, matching the immutable tested ZIP. Repository visibility is unchanged. The external receipt's `release/delivery-confirmed.json` records the live server checks. This checkpoint update follows as documentation only; recheck live Git state when resuming. One owned worktree, no topic branch or PR; no branch cleanup needed.

Artist `01a0faa5-a409-7a90-bf5b-4cae190781cb` and read-only correctness/Ponytail reviewer `01a0fab0-4bba-7ba2-a85d-416c982406e6` completed, integrated and archived. Both headers verify gpt-6.1-sol/xhigh/never and scoped sandboxes. Parent requested service_tier default; actual tier/native parent linkage are unavailable telemetry, not a blocker. Serial host Blender CPU builds and native GPU jobs completed; observed 77% available memory, zero swap. Reviews are clean after findings and final parent rechecks.

Next: continue Processional and remaining campaign/combat assets in bounded pieces. Keep real playtests and visual quality gates; no renewed routine approvals. Preserve the delivered Foundry state and exact pending gates across continuation.

Raw receipts/rollback assets remain outside Git under `/Users/jared/.codex/tasks/01a0f03f-e2f6-7be1-926a-af974a4ed8b7/foundry/`. Runtime apps/ZIPs/handles may be stale; inspect live files and processes before using them.
