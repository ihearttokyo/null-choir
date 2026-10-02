# Game project checkpoint

Date: 2026-10-02
Thread: `01a0f03f-e2f6-7be1-926a-af974a4ed8b7`

[DESIGN.md](DESIGN.md) owns the approved eight-level scope; [ARCHITECTURE.md](ARCHITECTURE.md) owns module boundaries. Goal active. Implementation, validation and private project/app delivery remain approved without repeated confirmation. Previous turn: progress, with Foundry source and private 0.1.2 app delivered. This continuation implements Processional and its combat additions.

## Current implementation

Three maps are implemented, with two closed loops and two unique original Blender landmarks each, keys, optional clues, ramps, checkpoints/death/restart and saved progression. Processional adds the walking bone organ and ossified palanquin, 57 supporting placements, 28 lights and four shadowed landmark spots. [PROCESSIONAL.md](docs/PROCESSIONAL.md) owns native pictures, GUI and behavior/performance evidence; [FOUNDRY.md](docs/FOUNDRY.md) and [SCENERY.md](docs/SCENERY.md) retain earlier scenery evidence. Eight original live MIDI tracks, options and rebinding are unchanged.

The scattergun pickup and floating projectile caster bring the implemented totals to three weapons and three regular roles. Shared player/HUD/campaign paths remain unchanged. A real authored JSON pickup exposed float weapon IDs in the inventory; one integer conversion in the shared collection branch repairs ownership/selection/ammo persistence. The original failing assertion is intact, and the narrow regression now parses actual JSON.

Remaining scope: five maps, ten unique loop landmarks, three weapons, three regular roles, two bosses, ending, sound effects, all eight optional discoveries/alternate revelation and full playthrough/pacing/visual/performance acceptance. Physical controller, heard musical quality, precise packaged cold-menu/transition timing and Developer ID signing/notarization are NOT RUN. The goal remains active with its full approved scope.

## Accepted evidence

- Clean native RGR for missing third-map layout, weapon pickup and packaged Processional workflow. Initial child sandbox startup-noise RED remains unaccepted; parent host RED is clean. A first pickup PASS was rejected because a test changed during execution; frozen native pickup/full-combat GREEN subsequently passed. Raw failures remain outside Git.
- Native caster/projectile checks pass: flight before damage, one-hit cleanup, fast thin-wall/player collision, enemy infighting, fixed difficulty, hover above a real raised floor, pause/resume, finite lifetime, destroyed participants and map/resource teardown. These are controlled fixtures, not combat playthroughs.
- Actual Foundry E exit, Processional descent/spawn, native optional clue, both seals, automatic checkpoint, death restoration, saved Continue and entry restart pass. Capsule traversal completes both third-map loops and ramps without jumping/falling. Third-map ten-second entry stays at 100 health on all three difficulties and still activates the nave encounter. Prior maps' protected data and scenery remain unchanged; related gameplay/save/options/music regressions pass.
- Serial native Blender CPU builds produce four original editable assets. Art parity passes 24 assets/25 exports; all 41 prior source/output/helper hashes and 20 prior manifest entries remain unchanged. New hero GLBs fit the unchanged four-MiB combined budget. [ART.md](docs/ART.md) owns dimensions, geometry and regeneration.
- Actual GPU images show entry, organ, palanquin and native combat. Limited final M4 samples are 119/116/112/93 FPS; warm source build 125 ms. The earlier 25.8-second cloud-backed source load is retained. Neither establishes packaged cold-start or full-campaign performance acceptance.
- Actual arm64 app GUI passes controlled Foundry Continue/E/intermission/descent, Processional save/title/Continue, real scattergun pickup/fire16→15, persisted earned inventory, death restoration and entry restart to pistol/90 rivets. The active-hostile pickup fixture died during operator delay; that edge and restoration were verified. Revised GUI-only hostile removal does not alter production AI or grant invulnerability.
- Temporary HOME isolates the GUI files. Original campaign/preferences hashes match the pre-run snapshot; older user game PIDs10787 and46670 stay running untouched. Owned validation PID23628/window3213 is closed. Recheck live processes before any future action; never reuse a stale Computer Use binding.
- Current 0.1.3 ZIP is 62,877,182 bytes, SHA256 `b3921c4a61c50101aa7189257a02c79c84cfd8fad070aabdf4237e8d50f02854`. Source/import hashes are stable across build; 39 actual packed data/art/MIDI/SoundFont/notices resources match exact hashes. Strict ad-hoc signature, thin arm64/system-only dependencies and offline three-scene live MIDI/projectile checks pass. It remains an unnotarized development app.

## Git, children and next step

Verified starting source is main `8fd0ece02c155c464c2c412fa00fd2a95498ddd6`, matching origin/main. Existing private release v0.1.2-dev remains available. The validated 0.1.3 candidate awaits source commit/push and private publication. Parent next stages explicit paths, reviews the staged diff, checks whitespace/secrets, verifies the private target and delivers the exact tested ZIP. A later documentation-only checkpoint records live server confirmation.

CLI artist `01a0faf9-03df-7930-b24e-6380daab06e9` and combat worker `01a0faf9-0ced-7210-8200-236e360c85ec` completed, integrated and archived with confirmation. Headers prove gpt-6.1-sol/xhigh/never and scoped workspace-write; default service tier was requested, but actual tier/native parent linkage telemetry is unavailable. Parent-owned CPU/GPU/native jobs ran serially; observed 77% available memory and zero swap. Correctness and Ponytail reviews are clean after the JSON-index repair and final rechecks.

After this delivery, continue Reliquary and remaining campaign/combat assets in bounded pieces. Preserve full acceptance and real playtests; do not renew routine approvals or stop at status-only planning.

Raw receipts and immutable candidate are outside Git under `/Users/jared/.codex/tasks/01a0f03f-e2f6-7be1-926a-af974a4ed8b7/processional/`. Actual app: `/private/tmp/null-choir-processional-0.1.3-xn20lqab/NULL CHOIR.app`. Reconcile source, runtime and external state before resuming.
