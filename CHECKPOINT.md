# Game project checkpoint

> Historical record. For the maintained priorities, current candidate, acceptance state and next action, start with [Major Feature Priorities](docs/MAJOR-FEATURE-PRIORITIES.md). Older release/status/hold statements below are dated evidence, not current instructions.

Date: 2026-10-03
Thread: `01a0f03f-e2f6-7be1-926a-af974a4ed8b7`

## Alpha 2 checkpoint — 19 October 2026

**Current public download: unfinished alpha for Apple Silicon, macOS 14 or newer.**

[Download Alpha 2](https://github.com/ihearttokyo/null-choir/releases/download/v0.2.3-alpha.2/NULL-CHOIR-0.2.3-alpha.2-Apple-Silicon.zip).
[Release notes and known limits](https://github.com/ihearttokyo/null-choir/releases/tag/v0.2.3-alpha.2).

Alpha 2 adds original offline title music and the nine-track Resonance Chamber
Sound test with its animated fractal instrument. It includes the reviewed HUD
update and bounded frame-trace instrumentation. Alpha 1's map, campaign-art,
recorded-level-score, player, enemy, level and save-codec blobs are unchanged.

### Exact delivered artifact

- Source: [`1a07030cf86deca39709ee87743ad9fe83500697`](https://github.com/ihearttokyo/null-choir/commit/1a07030cf86deca39709ee87743ad9fe83500697).
  This combines main `0e6d5a4fd54282911c65799817d6bca371d5d53e` with
  the previously published Alpha 1 source `a5cd327773e53ef0707fe097ea88720bb0ec82be`;
  it does not merge PR95 into main or certify its remaining campaign work.
- Archive: `NULL-CHOIR-0.2.3-alpha.2-Apple-Silicon.zip`, 182147397 bytes.
- Archive SHA-256: `4a015443733ec78eb158dd429a9d7ec7602fb9f465058f22b73ac5af42e3fed9`.
- Resource pack SHA-256: `7579f58312deeafc0fdaa4cbe4e2b53c9c9e14dad7954ad3dbc48b3a72771626`.
- Native export: Godot 4.7.2, Metal shader baking, arm64-only; application
  version 0.2.3 and macOS 14 minimum. Developer ID signature uses hardened
  runtime and a secure timestamp.
- Apple notarization: Accepted, submission
  `716a8141-cc1c-4ed9-be88-faa4eb7a31c2`. Stapled ticket included.

### Evidence and remaining work

| Status | Evidence |
| --- | --- |
| PASS — actual standalone | The extracted final ZIP passes strict signature, staple validation and Gatekeeper. Its actual arm64 binary passes all eight scene/art/recorded-PCM and retained-MIDI checks, late weapons/boss imports, title/start/fire/pause/checkpoint, native Metal caches, isolated userdata and system-only dependencies. |
| PASS — exact resources | The exported map and retained-MIDI bytes match the source archive. Git blob/tree equality confirms the retained Alpha 1 content listed above. |
| PASS — affected native tests | Exact exported resources pass Sound test, title transport/decoded PCM/release, menu retirement and HUD checks. The bounded trace's native source/schema/guard checks pass separately; its plaintext-source subtest cannot run against compiled export scripts. Expected invalid-audio rejection controls are counted explicitly. These are not human listening. |
| PASS — native Metal UI | Sound test focus, scrolling, real UI event dispatch and reduced-motion checks pass at 640×360, 360×640 and 1280×720. The fixture uses programmatic inputs and instantiates no gameplay. Physical controller acceptance remains open. |
| PASS — public download | The complete public ZIP was downloaded after publication. Its byte count, SHA-256 and CRC match the final signed/notarized archive, and GitHub's asset digest agrees. |
| NOT RUN — full acceptance | Full earned/physical campaign across both seal orders and all difficulties, physical gamepad coverage, final listening, sustained frame rate, cold input-ready startup, transitions and final GPU/memory/scaling acceptance remain open. |

Fullscreen performance remains under investigation; this release establishes
no frame-rate improvement. New final-size level-intro art is not included.
The longer campaign regressions remain in progress; PR95 stays unmerged.
Prior releases and the historical checkpoints below remain available for rollback.

## Historical Alpha 1 checkpoint — 19 October 2026

**Unfinished alpha. Expect bugs, hitches and balance changes.**
The full campaign, physical gamepad coverage, musical quality and sustained
120 FPS target remain unverified. This checkpoint does not close the production
upgrade.

[Download the Apple Silicon Mac alpha](https://github.com/ihearttokyo/null-choir/releases/download/v0.2.3-alpha.1/NULL-CHOIR-0.2.3-alpha.1-Apple-Silicon.zip)
requires macOS 14 or newer. See the
[Alpha 1 release notes](https://github.com/ihearttokyo/null-choir/releases/tag/v0.2.3-alpha.1)
for the archive checksum and installation details.

Archive SHA-256: `c49a64a434b10422947e894f1335d0479dc442be1c0f6ff3985d61ba03d67331`.

### Included

This build retains the eight-level campaign, current artwork, six weapons,
HUD inventory and seal indicators, expanded story records and eight recorded
level scores with their editable MIDI sources. Terrain descends from Intake's
0–3 m range to Heart's −6–6 m range; later maps gain more elevation bands.
Landmark aprons cover their full rotated bases. Save migration now preserves
capsule clearance on slopes, and standing-floor recovery accepts only bounded
contacts with the level's own floors.

App source: [`a5cd327773e53ef0707fe097ea88720bb0ec82be`](https://github.com/ihearttokyo/null-choir/commit/a5cd327773e53ef0707fe097ea88720bb0ec82be),
from the development branch in [PR95](https://github.com/ihearttokyo/null-choir/pull/95).
PR95 remains unmerged while the remaining campaign regressions are completed.
The prior public release and source history remain available for rollback.

### Evidence and limits

| Status | Evidence |
| --- | --- |
| PASS — source/native | Independent correctness and Ponytail reviews; all 79 source pins; immutable legacy-floor checks; capsule geometry and trust cases; 255 landmark floor contacts; all eight navigation maps with 64 closed/open role-state routes; 24 actor restoration cases. |
| PASS — scripted input | Normal-time Intake, Foundry and Processional route checks, plus targeted Reliquary checks. The accelerated four-map earned route also passes; it is not physical gameplay or FPS evidence. |
| PASS — candidate CI | Native terrain/save compatibility and both Python art-contract jobs at the exact app source commit. |
| PASS — actual standalone archive | ARM64-only app, system-only dependencies, native Metal shader caches, all eight scene/art/recorded-PCM and MIDI checks, late weapons/boss imports, title/start/fire/pause/checkpoint checks and isolated userdata. Developer ID signature, Apple notarization, staple validation and Gatekeeper pass on the extracted final ZIP. |
| BLOCKED — longer normal-time replay | Two attempts stopped under the host swap-growth safeguard. Neither establishes campaign completion. Later saved-outcome regression guards remain fail-closed pending new earned outcomes. |
| NOT RUN — full acceptance | Full physical-input campaign, both seal orders across all difficulties, final listening, sustained 120 FPS, input-ready cold menu ≤3 s, ordinary transitions ≤2 s, final GPU/memory/scaling and rendered 8K level-intro acceptance. |

The unreleased level-intro art and title-music experiments are excluded from
this archive. Keep system security protections enabled and save progress
through the pause menu.

## Current recovery and hill-climb — 2026-10-06

Jared released the NULL CHOIR launch, native, GUI and project promotion holds.
Root AGENTS.md records the current authority. Older hold paragraphs below are
historical evidence, not current permission gates. Preserve isolated saves,
original assets, unrelated sync pauses and platform safeguards.

Private main includes merged instruction PR17, music-guard PR12, marker-sharing
PR18 and HUD-visibility PR19 (`f9ac67ef`).
The eight-level project and cumulative 30M goal remain active; queue up to 30
independent improvement tracks within actual concurrency and resource limits.

The current candidate adds optional version-1 living-actor records to current,
checkpoint and entry snapshots. Legacy absence differs from authoritative empty.
Native G07's nine controlled recovery cases, exact disk-codec/trust and owner-
death/legacy/empty/retired-level lifecycle checks pass. Four small NPC position
repairs preserve their original tiles, floors, IDs, profiles, yaws and encounters;
all eight actual worlds at three difficulties pass native clearance (24 cases).
These results do not establish played campaign victory.

The current Metal/CoreAudio placement fixture passes Settings, Controls and
difficulty at both wait phases, plus cancel/restart/new-campaign and stale level/
player guards. Eight-map fallback retains resources and story/routes. The native
run completed in 16.16 seconds without errors or leaks. Headless mode reports
visible mouse mode when capture is requested and cannot certify this regression.
An earlier native attempt hit the parent's undersized file limit before the
fixture; it is not a game pass or demonstrated game defect.

Independent clean reviews and native checks support two resource changes:
collectible spheres use 8 mesh resources instead of 177 in the consumed-marker
fixture, with identical arrays/materials and released weak references; settled
HUD refreshes emit zero visibility transitions instead of 48, with exact
presentation/state parity across 12 cases. These are resource/mutation counts,
not FPS, GPU or whole-process memory gains. The scenery source binding and its
28 affected checks pass.

Broader campaign, save-failure, level-transition, world-lifecycle, HUD, boss-HUD
and survey checks pass. Encounter fixtures now capture through the shared
production boundary before controlled checkpoints or exact saved-state witnesses.
Late flow freezes the unrelated survey writer during controlled teleports; its
trace isolated exploration as the only mismatch. Original full-dictionary,
resource, membership and birth-budget assertions remain intact. Encounter, late
encounter, late flow, weapon-efficiency, HUD-visibility and marker-sharing checks
pass. All eight religious set-piece checks pass after resolving actual collision
children by type rather than assuming an obsolete visual-child index. Current
fixture-delta reviews are clean. The assembled cohort now passes 57 of 58
registered headless targets; the unchanged eight-score full-repeat PCM test is
running with its proper long deadline. Both actual save/discard shutdown paths
pass. Synthetic role arenas explicitly use the supported validated legacy
format; all 66 original role assertions remain, and six boss/difficulty fights
complete with finite ammunition. This is not played campaign victory or new-
format boss-persistence certification. The authored-actor suite independently
retains current-schema coverage. The new phase-local build controller remains
unaccepted pending three independent findings, targeted fixes and a real OS
process-group canary; it is not part of this repository change.

Land the reviewed actor/source improvement, finish the full PCM repeat and
corrected build-control acceptance, then
build a new source-bound Apple Silicon app under the reserved 3 GB build phase.
The corrected packed app, manual usability, listening/pacing and performance
remain unverified. Notarization requires real authentication; no credential or
security policy is created here. Source progress is not full project completion.

## Earlier tools and native-baked development candidate

Xcode 27.0/27A266a and the official Metal Toolchain are installed. An actual
Metal kernel compiled to AIR and linked into a metallib; installation no longer
requires user action. Older installation failures below remain historical evidence.

Focused save-placement PR5 was merged before a late menu-race review was cleared
because the shell continued after a failed assertion. Promotion was held.
Corrective [PR6](https://github.com/ihearttokyo/null-choir/pull/6) merged at
`c0f14c51d89cb967cc3e7f92b3b3934fe7253f58` after a fail-closed exact-head gate.
The review thread is resolved. Eleven native fixtures and actual packed Settings
cancellation, Continue/position repair, Pause/Resume/Quit pass. The editable source
is backported with per-file hashes; whole cloud-backed Git status is not certified.
The extracted Documents bundle repeatedly acquired FinderInfo that invalidated
strict signing. A nonsynced local app verifies correctly; the validated ZIP stays
in the project, and the unverified cloud copy is retained under a non-app name.
No quarantine or security protection was changed.

The experimental export contains 48 cache files with 546/546 decoded native Metal stage
libraries, totaling 14,900,664 library bytes. Exact cache bytes are present in the
actual PCK. Independent correctness/Ponytail review accepts this pinned-data proof;
it does not prove every runtime pipeline selects those libraries. Both native M4
GPU exports pass the original packed all-eight art/MIDI/weapon/recovery checks.
Compiler warnings about upstream generated shader return paths are retained;
exports and native runs have no errors, and runtime logs have no warnings/leaks.

The first three-pair experiment improved median first-written title-frame time by
17.37%, but failed its 21.02% noise threshold. It remains a failed promotion trial.
A separate, pre-registered eight-pair balanced confirmatory cohort keeps the same
three-second and max(10%, twice control MAD) guards: control median 1.8500 seconds,
MAD 0.0446 seconds; baked median 1.4153 seconds, a 23.50% improvement. All eight
baked samples remain below three seconds, and all title PNGs are byte-identical.
The first baked frame in the earlier cohort was 1.6686 seconds, compared with the
initial control's 6.4841 seconds. No failed observation is removed or pooled away.
These are fresh HOME/path, fixed-60 movie first-written-frame measurements with
potentially warm shared OS/GPU caches. They are not reboot-cold, normal input-ready,
whole-process RSS, combat FPS or full campaign certification.

Current source builds a native-baked 0.2.2 development candidate. Apple Silicon's
minimum is macOS 14 because the pinned Godot 4.7.2 baker has an
[open below-14 startup issue](https://github.com/godotengine/godot/issues/123266).
Both experiment arms use the same minimum. Native-GPU export is required by
[Godot's shader baker](https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html).
Actual prior normal and baked ZIPs prove intended REDs for target metadata and
cache acceptance. The cache guard also covers absent/empty/non-Metal directories
and nested Metal filenames; fixture placeholders certify filenames only, while
the separate decoded actual PCK proof certifies compiled-library presence.
A real source-preservation RED caught native editor normalization of project.godot.
The builder now imports and exports a scratch copy; its regression requires unchanged
project, preset and main bytes. The original game-content assertions and old
published preview remain protected.
Independent review caught a parent-only validation timeout that could orphan Godot.
A real POSIX descendant fixture reproduced the defect. Isolated process-group
termination and reaping now pass normal/error/deadline cases, and focused
correctness/Ponytail review clears the fix without weakening the 300-second deadline.

Physical keyboard/gamepad, listening, full played pacing, normal input-ready/cold
launch and notarization authentication remain unfinished. The eight-level goal is
active; the 64-item audit is not a claim that all findings are implemented.

## Current priority: integrated overhaul and image-derived set pieces

The approved full eight-level goal remains active. All eight maps are registered,
and native scenery, mounted lights, solid roofs and both capsule loops pass.
A fresh 0.2.1 standalone Apple Silicon ZIP passes native packed-resource checks,
and the private v0.2.1-dev preview is published; final overhaul acceptance remains open. The prior 0.1.3 delivery below remains
rollback evidence. Authored role assignments, boss gates and overhead scenery are
integrated; full played/heard acceptance, physical controls and final packaged
performance remain before final release acceptance.

All 56 religious-aesthetic pieces have actual editable Blender sources and
compact GLBs. Each level contains Christian, Buddhist, Shinto, Islamic, Hindu,
Jewish and ancient Egyptian-inspired apparatus. The fictional controller
commandeers worship systems; real communities are not villains. Selected GPT
Image sheets and prompts are retained under source/art/references, with actual
implementing-child inspection ACKs. Existing unique loop heroes stay protected.
Strict native inventory parity passes 92 assets and 93 exports, including eight
late combat assets and four atmosphere modules; all late sources were reopened, edited and restored in memory.

All eight native set/scenery/traversal checks pass. Authored late-map corrections
repair actual floor envelopes, mission/recovery strings, seven mounted lights and
two wall reliefs without runtime fallbacks or weaker assertions. Floor placement
now matches real triangulated ramps. Sixteen actual late-map M4 images at 640x360
show 69–119 FPS and 166–205 ms warm source builds. These controlled samples do not
certify packaged cold start, combat performance or visual quality. Their generic
ceilings and underfilled vertical space prompted a new retained GPT Image reference,
world-polish-late-01.png. Fast world-art child 01a0fc40-69c2-7791-842f-10f4af5c00ce
completed four bounded atmosphere-module recipes/tests. Parent serial native builds,
actual embedded-texture/geometry checks, source reopen/edit/revert and Godot
import/bounds checks pass. Four modules total 4,044,984 GLB bytes, retain four
editable assemblies each and merge into four or five material meshes. Native
staging now passes eight overhead mounts and four nonshadow supporting lights
per late map; unique heroes, every roof triangle and reserved boss arenas remain
clear. Twelve scenery/set/capsule checks pass. All sixteen central-mount M4 views
were inspected after rejecting a sparse peripheral arrangement; these four assets
and thirty-two mounts are now installed. Actual default texture-extraction RED
was repaired with existing Godot embedded-image mode 3. The overhead modules
are accepted as an integration piece, not final campaign visual acceptance.
The wall-kit batching candidate passed native geometry and visual safeguards but
failed paired frame-rate gates. Rollback restores the original renderer; its four staging,
encounter, boss-gate and HUD checks pass. A role-suite timeout omitted the original
fixed test clock; restoring that flag passes all six fights in 14.7 seconds with
unchanged source, assertions and deadline. No batching code was promoted.
The generated paintover is reference material, not an actual game screenshot.

Late repeater, marrow projectile and three-hit disruptor behavior pass the frozen
native fixture cleanly with explicit CoreAudio, plus seven old-weapon regressions.
The initial 15 WAV-object leak failure remains in receipts; the same source and
assertions pass with the real Mac audio driver. No behavior assertion was relaxed.
Late-role child 01a0fd28-8c93-73e2-88cc-f1ddec3ab4d4 completed enemy.gd source only;
the exact native fixture passes all five roles and six bounded-ammunition boss
fights, followed by 15 old combat/weapon/campaign/menu regressions. Source
headers verify 6.1-sol/xhigh/workspace-write/never; actual tier/native parent linkage
telemetry is unavailable. Only the requested world-art worker uses Fast on.

Actual E input, all four late clues/seals/gates, weapon pickups, checkpoints,
firing/death, Continue/restart, eight real CoreAudio PCM windows and three Descend
transitions now pass the frozen late-flow fixture. A recursive native save diff
identified nested checkpoint float64 JSON drift at a native float32 height; two
lines in existing campaign normalization restore exact coordinates. The original
exact equality passes, including a new fractional checkpoint/entry regression.
Both authored manifestations now block descent until their real persisted death.
Native boss gates, final-map standard/all-eight-clue exits and completed Continue
pass. Saved completion menus also pass zero/seven/eight-clue cases. A new retained
GPT Image reference, boss-hud-01.png, now drives a native capped pressure rail:
exact boss HP/phase, living-exit objective/prompt, pause/death/title clearing and
transmission separation pass, along with ten HUD/ending/save regressions. All six
actual M4 boss-state images were inspected at 640x360; labels are readable and
the instrument preserves the world and existing HUD. These controlled stages do
not establish full campaign fights, packaged performance or heard audio.

Late encounter source child 01a0fb7d-98b3-7850-bc99-4933a55faf61 completed its
staging fixture and layout extension. After actual missing-role RED, twelve kind
replacements add one brute, guardian and summoner per late map, preserving all
117 regular IDs, positions, memberships and resources. All 24 native difficulty/
seal-order cases pass twice, including after renderer rollback; conservative
source budgets report no deficits. This is controlled staging, not played combat.
The wall-kit source child also completed. Parent owns every native job.
Packaged-validation source child 01a0fdb3-265e-77f1-9308-fba5c1e3f696 now extends
the existing release check to all eight maps and version 0.2.0. The original caster
flight assertion exposed a dormant staged cohort; the fixture now activates it
through the shared production API, without changing normal gameplay. Clean
source checks and a fresh 88,025,379-byte arm64 ZIP pass all packed scenes/art/live
MIDI, late weapons/actors, strict ad-hoc signature and system-only dependencies.
Actual isolated-app menus, settings/rebinding, mouse fire, death and checkpoint
recovery pass; primary campaign/preferences hashes stay unchanged. Short virtual
keys do not establish stock physical movement/pause. No controller is connected.
All source children, including the Fast artist and packaging worker, are closed
and archived. Eight native 16-second MIDI excerpts are retained for listening,
which has not been certified. Thirty real all-cohort M4 samples stay alive and
pass warm builds below 288 ms, but late stressed views fall below 60 FPS. Native
profiling and process-only renderer experiments precede any performance change;
failed results remain retained and no visual or gameplay safeguard is waived.
Six matched renderer runs then cover ten dense scenes three times each. All thirty
Mobile/native Metal samples pass at 141–181 FPS, with median gains of 38.6–174.3%
and the same art, lights, shadows and active actors. All sixty-four actual matched
640x360 images were inspected; seventeen original native safeguards pass. The
project now selects Mobile/Metal through three metadata/selection lines and retains
a native backend/resolution check. A default-vsync GPU role-runner timeout is
preserved; supported test-only uncapping passes the same fixed-clock fixture and
150-second deadline in 70.2 seconds. No gameplay assertion or production vsync
setting changed. A fresh Metal ZIP now passes native packed full-eight checks: 88,025,807 bytes, SHA256 360bb71da7858995bf70aab86a31ebf94fcf5398c839cda784e86ce883d6a4b7. Live exact-app menus, settings/rebinding, stock Escape pause, mouse fire, death, checkpoint restore, save-and-title and persisted Continue pass; native close exits zero and primary user data remains unchanged. Its initial actual first-frame upper bound is 5.94 seconds, so cold startup remains failed. Native shader baking with the installed command-line tools emits a missing-Metal-toolchain warning; its first treatment frame takes 3.49 seconds. It is not promoted. A separate clean import recovers an import-during-export engine crash. Official Xcode 27 is free and compatible with this Mac, but noninteractive installation requires administrator authentication. Jared was asked to install Xcode and its Metal Toolchain while independent work continues. No security, developer-default or global-cache change was made.
Fresh independent source review found that marrow hits on tall boss caps could
spend ammunition without direct damage because splash radius was checked first.
A native upper-cap shot reproduced zero damage. One shared branch now applies
radius/cover only to splash victims; all six boss/difficulty cap shots deal exactly
110 damage once. Original late-weapon assertions remain byte-identical outside
the added case and call; parent correctness/Ponytail and independent delta reviews pass, followed by eight old native regressions.

The permanent universal image-first instructions have authoritative/installed
parity at /Users/jared/.codex/control-surface-local/AGENTS.md and
/Users/jared/.codex/AGENTS.md. Visible audit thread
01a0fb9c-84ca-7612-8c0a-c72911770e50 verified three provider-capacity failures;
134 tests and six parity checks passed. Controlled goal/provider canaries are
unrun. No perfect-pipeline or instruction-based twenty-minute timeout is claimed.

Rollback remains main@c25d0bc. Current branch is codex/full8-overhaul; private
v0.2.0-dev and PR #1 are delivered as recorded below. Reconcile
live Git/default/private state before any further publication. Fresh isolated
snapshots avoid intermittent cloud reads without global cache changes.
Exact prior human approval for a dedicated foreground playtest window is retained;
preserve unrelated windows and game processes. Parent heavy jobs remain serial.

Live hashes, receipts, active handles and next steps are in
/Users/jared/.codex/tasks/01a0f03f-e2f6-7be1-926a-af974a4ed8b7/overhaul-01/STATE.json.
Direct-hit regressions, the exact Metal rebuild and private preview delivery
are complete. Continue remaining played/heard and physical-control acceptance,
and cold-start remediation after Xcode/Metal Toolchain installation.
A milestone never completes or pauses the goal.

## Inversion depth and landmark examination lights

The latest bounded native visual review passes the corrected Inversion vaults.
Fresh retained GPT Image references drove recessed nested geometry, narrow violet
incisions and an original sparse star field. All four Blender atmosphere sources
were rebuilt coherently, reopened and edited/restored in memory. Actual exports,
embedded textures, vertex bounds and staging pass unchanged caps. Inversion has
13,498 triangles and five material meshes inside its original physical bounds;
the four modules total 4,646,440 bytes. The other three have identical actual
oriented triangles, attributes, materials and textures, with export-order changes
recorded rather than invented old hashes.

Two existing examination spotlights now illuminate the Nursery organism and the
Heart's teeth, tissue and narrowing throat. Positions and heights changed; Heart
uses warm amber. Targets, energies, ranges, shadows and light counts remain
unchanged. Both old placements fail the new proximity/aim guard; both corrected
maps pass it and native scenery checks. Independent ordinary-eye-height views
pass for Heart, Nursery and Foundry without enlarging their geometry. Diagnostic
light probes initially omitted spot re-aiming; those captures were rejected and
corrected using the existing production factory's exact targeting method.

All 30 actual M4/Metal source-candidate combat stress samples pass at 105.81–120.77
FPS, with warm scene construction at most 417.10 ms and all actors/music active.
These are source diagnostics, not cold-start, physical-control, heard-music or
full-playthrough certification. The prior private v0.2.0-dev is preserved. A fresh 0.2.1 Apple Silicon ZIP passes
full-eight native packed scenes/art/live MIDI/weapons/actors, strict ad-hoc signing,
system-only dependencies and isolated user data: 88,374,685 bytes, SHA256
`a942165ac91accb17265db275da70b5894689beed2e352ed94053875fd4ebfb2`. Actual standalone title, Continue, stock Escape pause, live Heart
world, staged death, checkpoint restoration, save/title and normal Quit pass.
Primary campaign/preferences remain unchanged. The stationary 100-health canary
died during operator latency; it is retained as death/recovery evidence, not an
alive-stress result. Private v0.2.1-dev is published and its exact attachment passes downloaded native
full-eight, signing, dependency and isolated-userdata verification.
The full goal remains active; Xcode/Metal Toolchain, listening and physical/full
playthrough gates remain open.

## Prior delivered piece (historical, superseded)

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
- An optional ignored import-cache `.md5` hash read stalled in cloud I/O and was stopped with process diagnostics. Final checks verify all 162 source hashes and actual packed resources. The destruction guard stayed enabled; no global/cache-setting change or source assertion weakening occurred.
- Delivered 0.1.3 ZIP is 62,877,182 bytes, SHA256 `b3921c4a61c50101aa7189257a02c79c84cfd8fad070aabdf4237e8d50f02854`. Source/import hashes are stable across build; 39 actual packed data/art/MIDI/SoundFont/notices resources match exact hashes. Strict ad-hoc signature, thin arm64/system-only dependencies and offline three-scene live MIDI/projectile checks pass. It remains an unnotarized development app.

## Git, children and next step

Source implementation `main@07a94282e7ec319e5e431c4b2040a66b963d0531` is pushed to the verified private/ADMIN/default-main target [ihearttokyo/null-choir](https://github.com/ihearttokyo/null-choir). [Private 0.1.3 development release](https://github.com/ihearttokyo/null-choir/releases/tag/v0.1.3-dev) pins that exact tested source commit. GitHub confirms uploaded `NULL.CHOIR-arm64.zip`, 62,877,182 bytes, digest `sha256:b3921c4a61c50101aa7189257a02c79c84cfd8fad070aabdf4237e8d50f02854`, matching the immutable tested ZIP. Release body, tag and unchanged private visibility are verified in `processional/release/delivery-confirmed.json`. Prior main8fd0ece and private 0.1.2 release remain rollback evidence. This checkpoint update follows as documentation only; recheck live branch/commit/upstream when resuming.

CLI artist `01a0faf9-03df-7930-b24e-6380daab06e9` and combat worker `01a0faf9-0ced-7210-8200-236e360c85ec` completed, integrated and archived with confirmation. Headers prove gpt-6.1-sol/xhigh/never and scoped workspace-write; default service tier was requested, but actual tier/native parent linkage telemetry is unavailable. Parent-owned CPU/GPU/native jobs ran serially; observed 77% available memory and zero swap. Correctness and Ponytail reviews are clean after the JSON-index repair and final rechecks.

Next, continue Reliquary and remaining campaign/combat assets in bounded pieces. Preserve full acceptance and real playtests; do not renew routine approvals or stop at status-only planning.

Raw receipts and immutable candidate are outside Git under `/Users/jared/.codex/tasks/01a0f03f-e2f6-7be1-926a-af974a4ed8b7/processional/`. Actual app: `/private/tmp/null-choir-processional-0.1.3-xn20lqab/NULL CHOIR.app`. Reconcile source, runtime and external state before resuming.

## Private eight-level development delivery

On 2026-10-03 Tokyo time, branch `codex/full8-overhaul` at
`88a5faa41728eb70df2c158daf2e5617729ee402` was pushed to the verified private
`ihearttokyo/null-choir` repository. [PR #1](https://github.com/ihearttokyo/null-choir/pull/1)
is open against main; no merge or automatic merge was requested.
[Private v0.2.0-dev](https://github.com/ihearttokyo/null-choir/releases/tag/v0.2.0-dev)
targets that exact implementation SHA. GitHub names the uploaded attachment
`NULL.CHOIR-arm64.zip`; its 88,025,807 bytes and SHA256
`360bb71da7858995bf70aab86a31ebf94fcf5398c839cda784e86ce883d6a4b7`
match the tested local ZIP. The actual published attachment was downloaded,
hash-checked and passed native full-eight resources/live MIDI/weapons/actors,
strict arm64 ad-hoc signature, system-only dependencies and isolated-userdata
checks. Every one of 361 frozen game inputs matches canonical source. No remote
CI is configured. Main and v0.1.3-dev remain unchanged rollback points.

This delivery is a preview, not full-goal completion. Initial cold first-frame,
played campaign pacing, heard musical quality, held physical movement, connected
gamepad and Developer ID/notarization remain open. The universal image-first
source/installed instructions have verified parity. Eight native full-loop-plus-
six-second MIDI recordings now pass repeat, nonzero PCM and zero clipped/discarded
frame checks. All eight still require listening; runtime synthesis is unchanged.

The exact published app also passes one live Heart mouth-vault stress canary at
production vsync: six whole one-second samples each report 60 FPS while all
authored cohorts are active. A validated simulated save supplies legal initial
200 health and 200 armor once, without refresh. Two actual live images and stock Escape pause were
inspected; the isolated save retains 15 health, and the app closes cleanly. Primary
user data and older app processes remain unchanged. The initial pipe-based run
is retained as inconclusive because stdout was buffered until exit; native PTY
output repairs observation only. This bounded case is not a full packaged matrix,
physical movement test or campaign playthrough.

## Native shipped-data-pack performance

The exact published 0.2.0 PCK passes thirty real M4/Metal stress samples through
Godot's supported pack loader: eight spawn views and two Heart landmark views,
each repeated three times. All authored cohorts are active; every player remains
alive without health/armor refresh. Rates are 118.70–120.38 FPS with diagnostic
uncapping; scene construction takes at most 427.26 ms. The actual PCK bytes match
the published ZIP. CoreAudio, clean exit and unchanged primary user data pass.

This uses the installed official Godot engine, not the release executable. That
release template disables path overrides, so an external-script probe ran the
normal title until its owned twenty-second timeout. The native help and official
source establish the cause. No engine, security or path-override control changed;
the supported pack-loader result is distinct from the release app's existing
normal-vsync sixty-FPS canary. It does not certify full played routes, cold menu
timing, physical controls or heard music. The frozen thirty-case release-binary
matrix remains NOT RUN. The unsupported probe and all raw evidence are retained.

An independent eleven-image review flagged Inversion depth and requested
unobstructed Heart, Nursery and Foundry views. The focused reviews now pass those
supplied views after the correction documented above. Four other maps retain their
bounded supplied-view verdicts. These pixel reviews do not certify full played
routes or artistic acceptance by Jared; imports and prop counts alone remain
insufficient.

## Private 0.2.1 delivery confirmation

[Private v0.2.1-dev](https://github.com/ihearttokyo/null-choir/releases/tag/v0.2.1-dev) pins tested source
`ac0fbdfa44753553c064ae332cc4afb5d63dfaae` on `codex/full8-overhaul`. Its uploaded
`NULL.CHOIR-arm64.zip` is 88,374,685 bytes and SHA256
`a942165ac91accb17265db275da70b5894689beed2e352ed94053875fd4ebfb2`. The downloaded attachment matches exactly and passes
original native full-eight live-MIDI, weapon/actor, strict arm64 ad-hoc signature,
system-only dependency and isolated-userdata checks. PR #1 remains open against
main, without configured CI or reviews. Main@c25d0bc and v0.2.0-dev are preserved.
The local versioned ZIP is `builds/macos/NULL CHOIR-0.2.1-arm64.zip`; the prior
default 0.2.0 ZIP is retained. This documentation follows the tested source tag.

Canonical whole-tree Git readers stalled in filesystem mmap; native sampling
records that wait. A complete 559-file byte-frozen local project supports the
build and per-command Git work-tree operations, without global Git/cache changes.
Every staged blob matched the tested snapshot, only 23 explicit owned paths were
committed, and canonical owned-path hashes matched. Generated test UID sidecars
and import/build/receipt artifacts remain outside Git. Cold-start, heard music,
held physical controls and full played campaign remain the unmet acceptance.
The bounded correction is delivered; the full game goal remains active.

## Published 0.2.1 startup measurement

Three serial launches use the exact downloaded published ZIP and unchanged
binary/PCK, separate fresh HOME/path pairs, native M4/Metal and CoreAudio, and
Godot's supported `--write-movie first.png --quit-after 1` path. The first written
640x360 title frame appears at 7.9827 seconds; process-to-clean-exit takes 8.0625
seconds. The later written frames take 1.8539 and 1.9445 seconds, with process
upper bounds of 1.8998 and 2.0003 seconds. All three title images are byte-identical
and the actual pixels show the expected campaign, Continue, settings and Quit
menu. All processes close cleanly and primary progress/preferences are unchanged.

The controlled initial-start target still fails. Fresh HOME/path does not purge
shared OS/GPU caches; fixed-frame movie writing is not normal input-ready timing,
reboot-cold certification or a full campaign check. No source, export preset,
cache, global developer setting or security control changes. `/Applications/Xcode.app`
is still absent and `xcrun --find metal` exits 72. The prior partial-baking experiment
remains unpromoted; its native warning and official implementation require the
missing Metal compiler for full baking. Once Xcode and Metal Toolchain are
installed through human authentication, verify the compiler and resume the
existing one-variable paired bake experiment with per-job `DEVELOPER_DIR`,
separate clean import and the original three-second target.

Music listening, held physical controls, full played campaign/pacing and release
notarization authentication remain open. The complete eight-level objective is
unchanged; diagnostic warm frames do not establish completion.

## Current delivery and gates — 2026-10-08

The delivery/startup entries above are historical. [PR1](https://github.com/ihearttokyo/null-choir/pull/1) merged on 2026-10-05. Current `main` and the published [private v0.2.2-dev prerelease](https://github.com/ihearttokyo/null-choir/releases/tag/v0.2.2-dev) both pin `acbb99bdc2f3fa578692ae7eaf7ad008548ce07b`. Hosted asset metadata records `NULL.CHOIR-arm64.zip`, 100,161,084 bytes, SHA256 `72a3615e5aea7c167a0577a5fa550ec2d6c1751caa4fdaff811f8c5a09791d7f`; this readback did not redownload or retest the release.

Xcode is now present at `/Applications/Xcode.app`, and `xcode-select -p` selects `/Applications/Xcode.app/Contents/Developer`. The retained Metal Toolchain's executable `usr/bin/metal` also exists. These live filesystem checks remove the earlier missing-installation diagnosis; they do not establish compiler health or current app acceptance. No developer-path, security or account setting was changed.

[Draft PR21](https://github.com/ihearttokyo/null-choir/pull/21) contains the bounded ammo presentation and metadata-test repair. Its source milestone is `f5dd650d7f9a519b74abdbb2d4ff5c43e58fd9e8`; documentation followthrough does not replace its runtime evidence. Source-overlay native regressions, actual art-byte checks and independent correctness/Ponytail reviews pass. The metadata regression runs under ordinary Python with simulated geometry callbacks. Hosted checks are absent.

Current complete resident-project import, selected weapon poses, ammo-VFX pool/lifecycle, late weapons and all eight collision-world lifecycles pass headless native checks. The focused Settings/Controls/difficulty fixture passes both placement-wait phases and three subsequent physics frames; removing production menu cancellation produces its intended failure. The original full placement fixture is unchanged: a headless run fails only at requested mouse capture (mode 2 reads back as 0), which the actual display-capability probe confirms is unsupported. Physical cursor/foreground, full original placement acceptance, current rendered readability, held-fire and performance remain unverified. Jared removed the fixed 8 GB reserve on 2026-10-08 and authorized development-cache cleanup. Use actual free space and a bounded peak-allocation preflight rather than the retired reserve threshold. Retain the existing release and artifacts, reconcile the exact PR head, then validate before merge/promotion. Full campaign playthrough, heard music, physical controls and notarization authentication are not certified by these source milestones.


## Background build correction and cache cleanup — 2026-10-08

Six verified inactive Homebrew installer archives were removed, totaling 1,225,867,264 allocated bytes. Installed tools, editable sources, saves, retained apps, validation evidence and other projects’ Xcode DerivedData remain intact. The fixed 8 GB reserve is removed; actual free space and next-operation peak checks replace it.

An experimental all-headless export produced an ad-hoc-signed arm64 ZIP but failed the unchanged actual app contract at `native_metal_caches`. Godot 4.7.2 requires an active native renderer for shader baking; its macOS graphics startup may activate the application. No supported no-window/no-focus bake route was found. The failed ZIP remains diagnostic only, not a promoted release. No retained cache was copied to fake current shader coverage.

The build now refuses before engine or filesystem effects by default. Explicit `--allow-window` permits the native Metal exporter; notice generation and import remain headless. The source-preservation build test propagates the same explicit option. Simulated command/refusal checks pass; a fresh windowed bake and actual current-asset graphics/cursor acceptance are NOT RUN while preserving Jared’s desktop. Existing private v0.2.2-dev remains the verified rollback release.
