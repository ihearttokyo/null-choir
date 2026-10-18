# NULL CHOIR: Production Upgrade Specification

**Purpose:** A commit-specific implementation brief for a coding model to turn into a reviewed PR, followed by native and packaged-game acceptance.

**Prepared:** 11 October 2026, Asia/Tokyo.
**Repository:** [ihearttokyo/null-choir](https://github.com/ihearttokyo/null-choir).
**Audited main commit:** `7229bce579d0188d03d93c14cb9cc2279355b167`.
**Audited tree:** `20e41b9988facbc70dfd7d273c1ec5b19a432256`.
**Companion:** [Audit workflow and reusable prompt templates](NULL_CHOIR_Audit_Workflow_and_Prompt_Template.md).

## Navigation

- [Implementation instructions](#1-executive-decision-and-instructions-to-the-implementing-model), [evidence and branch state](#2-evidence-scope-and-current-branch-state), and [priorities](#3-priorities-and-target-experience)
- Controls: [movement](#4-nc-01-make-movement-independent-of-heading), [firing and cadence](#5-nc-02-one-input-to-shot-contract-accurate-sustained-cadence), [targeting](#6-nc-03-make-targeting-match-player-intent-and-collision-truth)
- Combat: [attack communication and damage](#7-nc-04-communicate-attacks-and-preserve-correct-damage-geometry), [enemy routes](#8-nc-05-demonstrate-and-repair-real-enemy-route-stalls)
- Campaign: [recovery facing](#9-nc-06-restore-player-facing-through-the-existing-recovery-path), [progression and pacing](#10-nc-07-give-exploration-and-combat-loops-a-measured-progression)
- Visuals: [markers](#11-nc-08-give-every-interactive-purpose-a-distinct-original-shape), [weapons and actors](#12-nc-09-build-a-coherent-weapon-and-actor-art-system), [architecture and lighting](#13-nc-10-make-the-architecture-light-and-surfaces-support-the-game)
- Interface and structure: [HUD and preferences](#14-nc-11-a-readable-hud-and-safe-comfort-setting-migration), [interactions and records](#15-nc-12-keep-interactions-and-messages-consistent-with-the-world), [code boundaries](#16-nc-13-reduce-code-coupling-where-the-repaired-behavior-needs-it)
- Delivery: [performance and release](#17-nc-14-measure-rendering-loading-audio-and-the-actual-release), [PR sequence](#18-suggested-implementation-and-pr-sequence), [acceptance matrix](#19-production-acceptance-matrix)
- [Source map and research](#20-source-map-and-primary-research), [final handoff checklist](#21-final-handoff-checklist-for-the-implementing-model)

## 1. Executive decision and instructions to the implementing model

Keep the existing Godot game and repair the relationship between player intent, combat results, visible information, and authored spaces. The committed code already contains substantial safeguards and content. A broad engine, controller, AI, or asset-system replacement would increase regression risk before resolving the clearest problems.

The first implementation should make movement consistent at every heading, put firing and target queries under one physics-owned contract, repair close melee assistance, and give the player reliable information about targets and threats. The next changes should establish distinct marker shapes, readable enemy attack phases, coherent weapon artwork, and a clear HUD. Improve the traveled architecture and campaign pacing through controlled comparisons once those fundamentals are trustworthy.

Here, **gameplay conformity means consistent rules and communication**: an input produces the expected action; the crosshair and assistance cue describe the actual shot; the enemy tell describes the attack that follows; pickups look like their function; the recovery point restores a coherent situation; and each exploration loop teaches and rewards an understandable decision. It does not require every weapon, encounter, or level to feel identical.

This document contains recommendations and implementation contracts. No repository source or release was changed during this audit. The game has not been certified production ready. The native Apple Silicon application, physical controls, actual audio, full campaign, and sustained GPU performance could not be exercised in this environment. Those remain explicit gates in section 19.

### Working rules

1. Read the current `AGENTS.md`, `DESIGN.md`, `ARCHITECTURE.md`, and `CHECKPOINT.md` before editing. Verify actual HEAD and reconcile changes since this audit. Use the source permalinks below to understand the reviewed behavior; do not overwrite newer work to recreate this snapshot.
2. Create an isolated branch/worktree from the appropriate current base. Preserve unrelated changes, original editable assets, existing saves, prior releases, and a rollback commit. Use an isolated game profile for every destructive gameplay test.
3. Implement one coherent integration PR with separately reviewable commits and evidence per slice. Keep it draft until its stated gates pass. If a very large asset batch needs a dependent branch, declare that dependency and integrate only reviewed outputs.
4. For a deterministic defect, demonstrate a failing assertion through the real production path, repair the shared cause, and retain the regression. For a visual or feel hypothesis, capture a matched baseline and change one variable before judging it.
5. Obtain independent correctness and complexity review after the first passing nontrivial change, repair findings, then run affected broader/native/packed paths. Follow the repository's current worker profile and resource rules. A named Ponytail skill was not exposed during this audit; the independent review performed here checked correctness, complexity, and preservation of existing contracts.
6. Every substantial art redesign must follow the repository's reference-first process: generate and inspect selected image references, verify each implementing artist/model actually inspected their pixels, then create original editable Blender sources and runtime exports. A path or image-generation prompt alone is not inspected visual evidence.
7. Preserve the complete eight-level game, all six weapons, six regular roles, both bosses, original art, eight offline live MIDI scores, fixed difficulty choices, and native collision. Proposed tuning values below are experiments, not permission to lower the accepted game or performance targets.

### Existing work that must survive

| Existing capability | Why it matters to these changes |
|---|---|
| `screen_relative` mouse look and `Input.get_vector()` | Preserve responsive mouse input, analog magnitude, and normalized maximum diagonal speed. The acceleration defect is a different issue. |
| Center-ray damageable-hit priority | A precise manual hit already wins before optional assistance. Keep this precedence. |
| Weapon-local recovery, finite ammo, dry fallback | Switching must not bypass recovery; empty fallback must not spend or fire inside the failed call. |
| Swept projectiles, wall-aware splash, finite piercing, infighting | Presentation and damage-context changes must preserve actual collision, cover, and attacker identity. |
| Windups, committed aim, recovery, counter refractory, boss gates | Improve how these mechanics are communicated before altering their balance. |
| Current/checkpoint/entry resource envelopes and actor snapshots | Living actor HP, identity, position, yaw, alert state, and summon records are already restored. Add player facing without replacing recovery. |
| Two-frame native placement validation and cancellation guards | Continue/restart can await physics registration; stale continuations must never reactivate an old map. |
| Derived HUD, exact resource values, boss display, survey, rebindings | Redesign hierarchy while retaining truthful data, unusual legacy values, and user settings. |
| Level-owned scene references, local surface chunks, conservative occluders | Preserve successful loading and rendering ownership while changing architecture. |
| Bounded 32-slot ammunition effects with protected projectile slots | Add feedback within existing lifetime and capacity rules. |
| Current Intake cathedral, skin bell, angled rivet pistol, sculpted HUD | Use these as current production inputs. Historical screenshots do not erase these improvements. |

The old `docs/IMPROVEMENTS.md` reviews an earlier baseline. In particular, its actor recovery, global muzzle-flash switching, and short-interval weapon-animation complaints have already been addressed. This specification does not reopen them as missing features. A new cadence scheduler can still regress their behavior, so they remain acceptance constraints. [Recovery][C-recovery] [Weapon frames][C-weapon-frames] [Current flash][C-hud-weapon]

## 2. Evidence, scope, and current branch state

### What was actually examined

The GitHub connector returned an untruncated recursive tree with **743 entries and 710 blobs**. The audit materialized **443 text files** and verified their Git blob hashes against the pinned source. Focused review covered runtime gameplay, HUD, scene construction, persistence, relevant tests, asset builders, manifests, and architecture/evidence documents. Retrieval and hash verification do not mean every line of every file received equal review.

The visual review inspected **19 committed PNGs**: three historical app screenshots, the current HUD and ammunition-effect atlases, six weapon sheets, and eight actor/boss sheets. Their bytes matched repository blob hashes. The historical captures show an older HUD and pistol. The current source and current assets are the authority for present behavior; no fresh runtime capture was made here.

Several selected reference images larger than 1 MiB could not be read through the available approved connector paths. The base64 reader returned empty content and the blob reader rejected non-UTF-8 content. Their existence and provenance were inspected in source, but their pixels were not. The implementing model must obtain and inspect them before art adoption.

### Evidence classes used below

| Label | Meaning | What it does not establish |
|---|---|---|
| **S: source** | A behavior or structure is present in the pinned code/data. | Actual runtime incidence, comfort, or performance. |
| **M: mathematics** | A consequence follows from the source constants and stated model. | Native physics/input timing or human playtesting. |
| **V: inspected pixels** | Actual committed image pixels were inspected or measured. | Current packed-game rendering or animation quality. |
| **E: executed check** | A named local command was run and its result retained. | Other platforms or broader suites. |
| **H: hypothesis** | A plausible user-facing problem or proposed improvement. | Acceptance until a suitable comparison is performed. |

Native engine, GPU, physical-player, heard-audio, and exact packaged-artifact receipts must be added during implementation. Keep those evidence categories separate.

### Checks executed during this audit

| Check | Actual result | Interpretation |
|---|---|---|
| Python syntax compilation of `tools/` and `tests/` | Successful for 82 Python source files. | Syntax only. |
| `tests/test_art_recipe.py` | 4 passed. | Art-recipe helper coverage only. |
| `tests/test_playtest_protocol.py` | 33 passed. | Simulated protocol coverage, not a game playthrough. |
| `tests/test_music_demand.py` | 17 passed; one of 18 errored. | The failing case hardcodes `/private/tmp`, absent on this Linux host. This is an environment block, not evidence of a native music regression or a fully passing suite. |
| Real marker-validator `load_inputs()` | Failed with `immutable helper drift`. | A reproducible preflight blocker in the prepared marker-production path. It is not evidence that the entire current runtime cannot build. |
| Movement, FOV, aim-cone, cadence calculations | Reproduced from source constants in Python/algebra. | Mathematical diagnostics, not Godot execution. |
| Native Godot, Blender, Mac export, GPU, physical gamepad, live MIDI audition | Not run; required runtime/platform unavailable. | Pending implementation/release gates. |

### Release and work already in progress

The published release metadata identifies **`v0.2.2-art.4`**, an art-preview prerelease targeting the audited commit. Its asset is `NULL.CHOIR-arm64.zip`, 108,176,942 bytes, with reported SHA-256 `22344f971edc60aca465dec087aaa480c39b20e46fb9c6a0e765b4788ba45e7a`. This audit read metadata; it did not download, verify, launch, or play that ZIP. [Release][R-release]

**Draft PR #35 already proposes sharper 3D rendering while preserving pixel HUD scale.** The inspected head is `b1203c859b816e20feddcd349063f8b1d3e1ff95`, based on audited main. Its three-file change switches stretch mode from `viewport` to `canvas_items`, updates rendering tests, and documents the intended behavior. It is not merged into this baseline. Its author reports native checks and packed samples, while sustained gameplay/GPU/full-campaign acceptance remains open. Treat those as author-reported evidence, not this audit's independently reproduced result. Inspect and reuse or reconcile that PR before proposing the same change. [Draft rendering PR][R-pr35]

No `.github/workflows` files were present in the pinned tree, and the commit-status endpoint returned no statuses. This establishes that these particular CI/status surfaces supplied no acceptance evidence; it does not prove that no external or local checks exist.

## 3. Priorities and target experience

The priorities below rank implementation value and dependency. They are not claims of measured player-impact magnitude. **P1** addresses control or information consistency; **P2** improves readability, content, or maintainability; release gates remain mandatory even where no current crash was reproduced.

| ID | Priority | Finding or opportunity | Evidence | First bounded outcome |
|---|---|---|---|---|
| NC-01 | P1 | Acceleration/braking depend on world heading | S, M | Isotropic planar velocity step with current speed retained |
| NC-02 | P1 | Input and physics both execute firing; held cadence discards remainder | S, M | Physics-owned shot intent and explicit cadence/shot-age contracts |
| NC-03 | P1 | Close melee assistance excludes low targets; fallback ranks distance | S, M | Weapon-aware aim solution matching actual collision and HUD |
| NC-04 | P1 | Attack phases and damage origin are weakly communicated | S, V, H | Visible committed tells, source-bearing feedback, correct hit geometry |
| NC-05 | P2 | Enemy route abstraction ignores real obstacles/clearance | S, H | Native blocked-route reproduction and smallest demonstrated repair |
| NC-06 | P2 | Player facing is missing from recovery resources | S | Backward-compatible yaw/pitch restoration |
| NC-07 | P2 | Opening loadouts and checkpoint placement merit pacing trials | S, H | Measured first-loop/checkpoint/weapon-introduction comparison |
| NC-08 | P1 | Marker purposes share one silhouette; prepared producer is blocked | S, V, E | Distinct original shapes with reproducible asset lineage |
| NC-09 | P2 | Five weapons and some actor angles lack the current pistol's clarity | V, H | Coherent silhouettes, pose metadata, muzzle sockets |
| NC-10 | P2 | Shared surfaces/boundaries limit room identity; ramp normals are wrong | S, V, H | Correct normals and authored level visual profiles |
| NC-11 | P1 | HUD hierarchy, bindings, and comfort settings need clearer contracts | S, V, H | Truthful readable layouts plus safe preference migration |
| NC-12 | P2 | Prompt queries, passive triggers, and message replacement reduce clarity | S, H | Physics-owned interaction results and durable discovered records |
| NC-13 | P2 | Parsing and orchestration need smaller explicit boundaries | S, H | Focused validators/policies with existing lifecycle ownership retained |
| NC-14 | P2 | Rendering, load, audio, and distribution acceptance remain incomplete | S, H | Measured PR #35 decision and exact standalone release evidence |

### Proposed experience contract

The player should recognize a threat, understand its pending action, choose a useful weapon or movement response, see and hear the result, collect a legible reward, and recognize the route back to the junction. Different rooms should change the decision through distance, cover, elevation, role combinations, and resources. The following four layers should be tested independently and then together:

| Layer | Observable result |
|---|---|
| Controls | Equal movement response at rotated headings; deliberate taps preserved; menu inputs do not leak into combat; no hidden target redirection. |
| Combat | Windup precedes the attack it depicts; damage has a source; recoveries and armor openings are recognizable; finite resources support a deliberate weapon choice. |
| Exploration | Landmarks distinguish the two branches and their returns; seals, checkpoint, story, and exit are different visual objects; replay after death has a measured cost. |
| Presentation | Threat, route, landmark, HUD, and background have a clear visual priority; meaningful color and shape survive the final pixel size and motion. |

Keep existing performance targets: normal combat at 60 FPS on the verified M4 Mac at the chosen render configuration, input-ready cold menu within three seconds, and ordinary level transitions within two seconds. Eight-to-twelve minutes per level and 75-to-100 minutes for a first campaign are design targets, not findings from this audit. [Accepted design][C-design]

## 4. NC-01: Make movement independent of heading

### Observed cause

`player.gd` rotates normalized local input into world space and independently approaches target X and Z velocity by `50 * delta`. Each axis receives the full acceleration budget. At 9 m/s, an axis-aligned start takes 0.180 s in the continuous model; a 45-degree start takes approximately 0.1273 s. The corresponding ideal 60 Hz arrival counts are 11 and 8 ticks. Rotating the camera changes the response to the same forward input. Maximum diagonal speed is already normalized; that is not the defect. [Movement][C-player-control]

### Required first change

Move the horizontal velocity as one vector, keeping 9 m/s and 50 m/s² for the initial correctness comparison:

```gdscript
# Illustrative replacement for the planar step, not a replacement controller.
var wanted_3d := basis * Vector3(axes.x, 0.0, axes.y) * MAX_SPEED
var wanted := Vector2(wanted_3d.x, wanted_3d.z)
var planar := Vector2(velocity.x, velocity.z)
planar = planar.move_toward(wanted, GROUND_ACCEL * delta)
velocity.x = planar.x
velocity.z = planar.y
```

Keep analog magnitude, gravity, floor snap, capsule dimensions, collision masks, and the native `move_and_slide()` path. Its velocity is already in distance per second; do not multiply velocity by delta again when invoking it. A vector `move_toward` supplies one bounded step toward the desired vector. [Godot movement][S-character] [Vector step][S-vector]

### Tuning after the correctness repair

Measure starting acceleration, stopping distance, and full reversal separately. As an initial experiment, compare full-speed starting times of 120/150/180 ms, stop times of 80/100/120 ms, and 180-degree reversal times of 140/170/200 ms. These are proposed search points, not accepted defaults. For a constant-rate model, start/brake rate is `v / time`; full reversal covers `2v / time`. Define how the chosen rate is selected for partial sticks and oblique turns, avoiding a discontinuity around zero input or a dot-product threshold.

Preserve immediate mouse rotation. Do not add camera smoothing, mandatory jumping, sprint, inertia animation, or a movement upgrade tree to repair this local defect. Bob can smoothly return to neutral at rest if native comparison shows its frozen stride phase is distracting; keep that cosmetic comparison separate from acceleration.

### Decisive checks

Exercise forward/strafe/diagonal input at camera yaw 0, 22.5, 45, 90, and 135 degrees; analog magnitudes 0.25, 0.5, and 1.0; start, stop, reverse, wall slide, corner contact, and authored ramps. Compare time to 90% target speed and stopping distance within one physics tick at equal input magnitude. Retain native player capsule and Intake floor/traversal tests. A rotated mathematical fixture establishes isotropy; a physical mouse/gamepad traversal establishes whether the selected response feels controllable.

## 5. NC-02: One input-to-shot contract, accurate sustained cadence

### Observed cause and intended ownership

`_unhandled_input()` calls `fire()` directly, and the physics loop also calls it while fire is held. `fire()` performs direct-space ray queries. Existing cooldown guards usually prevent duplicate damage; do not report an unconditional double-shot bug. The proven issue is execution in two timing domains. Godot documents direct-space access during physics processing because the space can be locked during input callbacks. [Input and shot path][C-player-fire] [Physics access][S-ray]

Keep mouse look responsive in the input callback, but latch a fire press edge and resolve gameplay actions in `_physics_process()`. A press and release entirely between two ticks must still produce one eligible attempt. Use physics-time camera pose consistently for that attempt and its feedback. Make ordering explicit: apply current look, apply weapon selection, update locomotion/camera pose, resolve current aim, then attempt one shot. If the existing scene order requires a different safe sequence, document and test the chosen sequence instead of relying on node callback accident.

Use a one-slot transient edge latch plus current held state. A tap during unavailable recovery is consumed without a later surprise shot; continued hold remains eligible when recovery finishes. Clear queued attempts on pause, focus loss, death, title, and map replacement. On returning to gameplay, require release of a still-held fire/interaction trigger before a new attempt. Clearing only the edge is insufficient because held polling can immediately fire again. Avoid blocking ordinary held movement without a device/accessibility reason.

All direct tests of `player.fire()` must move to an authoritative physics-safe entry point or explicitly execute within a physics callback. Do not leave a public bypass that silently retains unsafe query timing. Keep production callback guards before and after external calls: `game.shot()` can trigger state changes, and the old map/player must never continue applying damage afterward.

### Cadence is distinct from time since the last shot

The current physics loop clamps weapon countdowns at zero. Each accepted shot restores a full interval, discarding overshoot. For the repeater's 0.085-second profile at 60 Hz, the simple steady-held model waits six ticks, or 0.100 seconds: approximately 10 shots/second instead of 11.7647, a 15% shortfall. This is a source-derived timing prediction; native floating-point and input boundaries still need measurement. [Weapon profiles and timers][C-player-control]

Use one player-local **active-play clock**, per-weapon readiness deadlines, and per-weapon last accepted-shot times. Preserve only the current uninterrupted held sequence's nominal phase. At 60 Hz, the 0.085-second repeat should normally use a mixture of five- and six-tick gaps; preserving its average rate cannot also require every individual gap to be at least 0.085 seconds. On release or switch, end that repeat phase and normalize readiness to `max(retained_nominal_deadline, last_accepted_shot_at + interval)`. This preserves full recovery for fresh taps and prevents switching/repressing from exploiting a shortened repeat gap. The implementation can use equivalent bounded countdowns if it retains these semantics:

| Situation | Required behavior |
|---|---|
| Fresh eligible tap or new held sequence | Accept once and establish the next readiness from this accepted time. |
| Continued hold, ordinary small tick lateness | Advance from the previous nominal deadline so residual lateness does not permanently slow the weapon. |
| Release or switch | End repeat phase and apply the readiness normalization above. Keep that deadline per weapon; no idle debt accumulates. |
| Switch back before ready | Respect that weapon's deadline. |
| Switch back after ready | Accept one new shot when intended; do not replay missed slots. |
| Large hitch | At most one accepted shot per physics tick. Skip missed nominal slots to the next future deadline; no catch-up `while fire()` burst. |
| Pause or inactive scene | Advance neither gameplay clock nor shot/effect age. |
| Empty ammo | Debounced dry cue, no spend, supplied owned fallback selection, no fallback discharge inside the same failed attempt. |

**Critical regression:** current HUD derives flash age as `interval - cooldown`. After residual preservation, readiness remaining no longer equals age since discharge. Derive `shot_age = active_play_time - last_accepted_shot_at` for flash/pose presentation and `ready_at - active_play_time` for readiness. Both use the same authoritative clock; do not add a separately ticking animation system. Preserve interval-relative weapon poses, selected-weapon flashes, and pause behavior. [Current pose and flash][C-hud-weapon]

Record an accepted shot locally, with weapon ID, accepted time, actual origin/direction, and result needed by existing callbacks. Use a small direct interface. A global event bus, input replay framework, or second combat scheduler is unnecessary.

### Decisive checks

Use real `InputEvent` delivery followed by physics ticks for short taps, hold, double edge, menu-consumed click, simultaneous switch/fire, trigger-axis events, unavailable taps, release/repress, dry fallback, and scene retirement. Test just before/at/after readiness; ten seconds of repeat at several deltas; one large hitch; pause/focus/death with fire held. Shot count should meet the configured average within a stated one-shot boundary tolerance under ordinary ticks; ammunition expenditure must equal accepted ammunition-weapon shots at their specified cost. Impact-tool acceptance spends no ammunition. Check all six weapon flashes at the actual first post-shot frame, during recoil, and when switching mid-flash.

Retain `test_player.gd`, `test_controls.gd`, `test_ammo_input.gd`, `test_weapon_efficiency.gd`, `test_late_weapons.gd`, and stale/reentrant callback cases. Synthetic cadence calculation alone does not pass this ticket.

## 6. NC-03: Make targeting match player intent and collision truth

### Current behavior and close-target failure

The direct center ray already protects a manual damageable hit. On a miss, optional assistance considers `enemy.global_position + Vector3(0, 0.85, 0)`, admits a 3D dot product greater than 0.975, and chooses the shortest distance. That cone has a **12.8386-degree half-angle**. Candidate visibility tests world layer 1, while the actual shot tests world and actors, layers 1 and 4. [Aim selection][C-autoaim] [Production ray][C-player-fire]

Using authored construction offsets before native settling or bob, the level-looking camera is approximately 0.71 m above the fixed crawler aim anchor. It cannot admit that anchor until horizontal distance exceeds approximately 3.115 m, yet impact-tool reach is only 2.7 m. With equal actor/player floor origins, the 0.70 m separation gives a threshold of about 3.071 m. Both source-derived examples exclude the anchor throughout tool reach; native fixtures must verify the settled pose. A horizontal direct ray also passes above the crawler's 1.1 m capsule in those examples. Manual downward aim can hit; the defect concerns this horizontal assisted-melee case, not invulnerability. Choosing the capsule midpoint alone makes the vertical mismatch larger. [Camera/tool][C-player-control] [Crawler body][C-enemy-body]

### Required resolver

Implement one bounded, physics-owned `AimSolution`, initially in the current owner or a small extracted policy. It should describe this tick and this weapon: level identity, physics tick, weapon ID, origin, manual direction, resolved direction, finite range, first collision, selected actor ID if any, assistance mode, and cue status. It is transient and never saved.

1. Reject inactive/stale scene state before querying.
2. Resolve the current manual center ray using the production mask and exclusions. A valid direct damageable hit always wins.
3. If assistance is off, retain that result. No hidden correction occurs.
4. If assistance is on and the manual ray missed a damageable object, evaluate a small number of meaningful target points per valid actor. Derive those points from visible body and hurt-volume relationships for the role and pose. Do not use an arbitrary universal height or enlarge every collider.
5. For ordinary ranged fallback, rank angular proximity before distance. Use stable authored actor ID as the final tie-break. First test this simple ranking; add target hysteresis only if actual footage demonstrates disruptive switching.
6. For classic vertical assistance and melee, evaluate horizontal angular tolerance separately from bounded vertical correction. Trace the resulting **finite 3D segment** to a reachable surface/contact point. The true path length and actual collision must stay within weapon reach.
7. Validate the first relevant collision against world and intervening actors. For ordinary weapons, the cue's actor must match that contact. An obscured rear actor cannot be advertised while another actor receives damage. Disruptor penetration retains its explicit finite actor-count and wall-stop rules.
8. Revalidate current-map membership, liveness, readiness, and actual current-tick geometry before accepting a shot. Clear the cached display result on switch, pause, death, focus loss, and map retirement.

Decide dormant-target policy explicitly. A reasonable first candidate excludes dormant groups from automatic redirection while preserving intentional manual hits and their existing activation behavior. Compare that choice against authored encounters; do not silently remove dormant manual-hit activation or infighting.

### HUD and weapon-specific truth

Keep the central manual reticle. A modest additional cue can report assistance acquisition or obstruction. It must not promise damage that the weapon cannot guarantee: scatter shows selected center direction rather than seven guaranteed pellet hits; repeater spread remains spread; launcher acquisition describes its initial path rather than a future moving-target hit; disruptor communicates its own penetration policy.

HUD drawing reads the last valid physics-owned result. It performs no fresh direct-space query. A projected actor cue must convert actual camera viewport coordinates to the logical HUD canvas, including stretch and letterboxing. Never assume a fixed division by two. This is particularly important if draft PR #35 is adopted.

### Decisive checks

Build native fixtures for a horizontal crawler at 1.0, 1.8, and 2.4 m and beyond reach; positive/negative floor offsets; narrow yaw boundaries; a thin wall; a tall intervening actor; manual downward hit with assistance off; and low/tall/floating roles. Validate finite contact distance, not just target-center distance.

Add two missed-center candidates where the near peripheral actor competes with a farther centered actor, direct-center priority, actor occlusion, partial cover, stable ties, dormant policy, removal/death after preview, and map replacement. Preserve scatter's one assistance resolution before spread, launcher collision/cover, and disruptor finite piercing. Record the displayed cue and actual accepted first contact in the same native fixture.

## 7. NC-04: Communicate attacks and preserve correct damage geometry

### 7.1 Derive visible phases from existing mechanics

The code already has windups, committed aim, release, recovery, late-role charges, and boss variants. The displayed actor sheet largely uses the same attack row for these distinct states. Current five-pose sheets provide idle, two walks, attack, and death. [Actor display][C-enemy-pose] [Attack commitments][C-enemy-attack]

Expose a read-only `combat_visual_state()` containing phase, normalized progress, committed variant, facing, hurt state, and boss phase. Derive it from the actual timers/flags. Bind the pending attack variant when the windup begins; the cue and attack must agree even when phase thresholds, interrupts, or death occur. A presentation clock must not continue an attack after the gameplay state cancelled it.

| Role | Proposed readable preparation | Visible commitment and recovery |
|---|---|---|
| Crawler | Body compression and raised striking mass | Clear forward release; visibly low recovery |
| Worker | Weapon/arm raise with a recognizable firing orientation | Brief actual shot line and impact; lowered/reset pose |
| Caster | Gathering structure around its emitting organ | Emission separates from residual glow; spent recovery |
| Brute | Weight shift and loaded stance | Committed charge body line; collision/end recovery distinct |
| Guardian | Closed armor is a broad readable mass | Open plates/weak region match real vulnerability windows |
| Summoner | Raised apparatus and grounded summoning action | Visible completion and interruption, separate from idle |
| Nursery Warden | Different preparation for charge and projectile pattern | The displayed committed variant produces that attack |
| Choir Avatar | Different formation for aimed/fan and radial pressure | Phase and recovery remain readable from quarter/side views |

These are original art directions to develop against selected references, not preapproved final images. First verify state selection with current assets and bounded debug cues, then introduce per-asset pose metadata and minimum necessary authored frames. Preserve existing damage, windup duration, counter refractory, and boss gate behavior during the first presentation comparison.

Native checks establish phase/timer agreement, pause, counter cancellation, same-tick death, charge collision, boss phase transition, and restoration without replaying a half-finished tell. Human viewing and physical play establish whether a person can distinguish the pending attack and recovery in time.

### 7.2 Separate attacker identity from incoming-hit geometry

Guardian armor currently classifies front-facing damage from the attacker's **current position** when damage lands. A projectile can arrive after its shooter has moved; radial damage should use the explosion origin. Infighting still needs shooter identity. [Armor][C-enemy-damage] [Projectile and blast][C-projectile]

Extend the damage interface with a small optional context, keeping source identity separate. Carry weapon/attack kind, hit position, and the appropriate geometric input:

| Attack type | Geometry for target-facing classification |
|---|---|
| Hitscan/pellet | Actual ray origin and incoming ray direction |
| Traveling projectile | Arrival direction/velocity at contact; target-to-source bearing is the negative travel direction |
| Explosion | Detonation origin relative to each victim, retaining existing cover checks |
| Melee | Actual attacker/contact origin and resolved contact direction |

Define finite/zero-length fallbacks explicitly. Retain the current armor multiplier and existing open windows until a separate balance trial justifies a change. The shooter may be dead or freed when an existing projectile collides; damage geometry remains valid, while retaliation still requires a valid eligible source. Update every production caller and test double deliberately.

Check identical projectile paths with the shooter moved front/back before impact, guardian rotation during flight, freed source, front/rear blast, zero horizontal direction, vulnerable phases, direct-plus-splash deduplication, thin-wall cover, and infighting. Never use shooter launch position as a universal replacement; it is still wrong for radial damage.

### 7.3 Make hostile damage locatable

Worker hitscan has committed aim and cover checks, but supplies little visible source-to-impact information. `hurt_player(amount)` receives no bearing. Hostile sound effects use ordinary `AudioStreamPlayer` voices with distance gain changes, so they do not convey 3D direction. Several player weapon cues are also reused. [Worker and cues][C-enemy-attack] [Damage feedback][C-hurt] [Effects][C-effects]

Carry the accepted attack's origin, direction, hit endpoint, and responsible actor through direct callbacks. Add a short bounded worker trace/impact, source-bearing damage indication, and a small level-owned spatial sound pool for hostile/world cues. Keep UI/player sounds appropriately nonspatial. Respect effects volume, pause, scene teardown, and priority for dangerous windups when the pool is saturated. Reuse the bounded effect ownership pattern; avoid an unbounded node or dynamic light per bullet.

Evaluate distinct original sound families for repeater, launcher, and disruptor, preserving the eight live MIDI tracks. Mix dangerous tells above ambient detail without making every sound loud. Test simultaneous left/right workers, misses and wall impacts, muted effects, paused voices, repeated level changes, and stale attacker callbacks. A listener should be able to identify the attack side in a controlled trial. That requires actual audio playback; an event log cannot approve it.

## 8. NC-05: Demonstrate and repair real enemy route stalls

The existing four-neighbor search treats authored floor tiles as walkable. It does not represent closed doors, hero bases, support geometry, or the pursuing actor's clearance. The native capsule still collides with those things. This abstraction gap can select an unusable route, but this audit did not observe a live campaign stall. [Enemy route search][C-path] [Walkable data][C-level-data]

Create a small native fixture with a reachable player, blocked shortest route, valid alternate route, low hero base, and closed/open door. Exercise crawler, worker, brute, and boss sizes with live AI. Record intended waypoint, position, collision normals, and meaningful progress over a bounded interval. A valid failing case repeatedly chooses the blocked edge despite a reachable alternative.

If reproduced, first assess capsule-aware edge clearance and dynamic door exclusions in the existing search. Build bounded per-level navigation knowledge after native geometry registration, invalidate the affected door edges on change, and let actual native movement remain authoritative. Do not rebuild all routes every rendered frame. If this cannot represent the demonstrated geometry cleanly, compare a small native navigation-region prototype with role-appropriate clearance; adopt it only if it reduces implementation complexity and passes the same fixture.

Retain direct steering where valid, alert/group rules, attack commitment, counter windows, finite update cadence, and scene ownership. Do not remove prop collision or let enemies phase through scenery to pass a movement check. Confirm no new stuck behavior across all eight maps, narrow passages, ramps, crowd contact, and both bosses. Keep pathfinding refactoring out of the initial control patch unless a reproduced stall blocks that test.

## 9. NC-06: Restore player facing through the existing recovery path

Current resource snapshots include player position but no yaw/pitch. Level construction resets yaw to authored entry orientation and creates a fresh camera pitch. Living actors already have considerably more complete restoration. This mismatch can make Continue or checkpoint recovery disorienting. [Resource envelopes][C-recovery] [Level restoration][C-start]

Add optional validated player yaw and pitch to **current, checkpoint, and level-start** resources. Capture the authoritative physics pose along with position. Normalize finite yaw consistently and validate pitch against the actual current look bounds, approximately ±1.35 radians. Legacy absence must use a documented authored-entry or envelope fallback, while malformed present fields are rejected before mutating live state.

An additive optional field may avoid a save-version change. If a version changes, write explicit migration and fixtures before adoption. Preserve primitive JSON validation, atomic writes, all three envelope checks, actor completeness/summon validation, and the distinction between missing legacy actor state and an authoritative empty actor list.

When native placement repair chooses a different valid location, define the corresponding facing policy. Preserve the current rule that repair does not refund resources or rewrite the checkpoint. New game and ordinary next-level entry use authored facing. Checkpoint death and level restart use their own saved resource envelopes. Clear transient velocity, trigger latches, target previews, and effects on reconstruction; do not serialize queued shots or resume half-finished attacks.

Extend campaign, actor recovery/trust/lifecycle, save placement, floor placement, and placement-menu tests with valid/legacy/malformed facing, save while looking at an enemy, checkpoint restore, restart, and cancellation during asynchronous placement. This is a small extension of recovery, not a new save codec.

## 10. NC-07: Give exploration and combat loops a measured progression

### Authored facts

Static JSON inspection found **222 authored enemy records and 44 encounter groups** across eight levels, with two authored traversal loops per level. These totals do not include all dynamically summoned actors and do not describe simultaneous enemy counts. Both Intake and Foundry use only workers/crawlers and contain no weapon pickup. The first authored scattergun pickup is in Processional. Every authored mid-map checkpoint requires both blood and ivory seals. Entry recovery and later checkpoint behavior already exist. [Campaign data][C-data]

| Level | Authored enemies | Encounter groups | Weapon pickup indices present |
|---|---:|---:|---|
| Intake | 23 | 6 | None |
| Foundry | 23 | 6 | None |
| Processional | 26 | 6 | 2: scattergun |
| Reliquary | 31 | 6 | 2: scattergun |
| Nursery | 29 | 5 | 2: scattergun; 3: repeater |
| Ossuary | 27 | 5 | 2: scattergun; 4: launcher |
| Inversion | 30 | 5 | 2: scattergun; 5: disruptor |
| Heart | 33 | 5 | 2: scattergun; 4: launcher |

These facts justify testing the opening and death-replay cost. They do not establish observed boredom, unaffordable combat, or a failed 8-to-12-minute level target. Authored route-polyline length is also not a player completion time.

### Author a loop contract before changing quantities

For each branch, record its actual encounter IDs, entry landmark, threat lesson, useful response, finite supply, seal reward, changed return condition, checkpoint relationship, and recognizable return view. Keep this small authoring table near level documentation/data validation. Use existing JSON entities and stable IDs; do not build a procedural mission framework.

The intended sequence is: recognize the junction, choose a branch, read a threat, commit/dodge/counter, collect the seal, survive a changed return, recognize the junction again, and prepare for the final encounter. Different branches should emphasize different distances, cover, and role combinations. A graph containing two cycles does not establish this experience by itself.

### Three separate first experiments

1. **Opening teaching:** Stage one existing role's tell in a sightline where the player can notice it, react, and see the result before a mixed encounter. Use actual rebound controls if a brief contextual prompt is needed. Preserve agency and avoid compulsory tutorial pauses. Confirm that the first worker/crawler combination makes movement and weapon purpose understandable after NC-01 through NC-04.
2. **Recovery cost:** Compare one earlier junction or pre-branch checkpoint against the baseline, retaining the current final checkpoint. Measure minutes and already-completed combat replayed after one branch death in both seal orders. Check that repeated recovery cannot duplicate finite pickups or reset actors inconsistently.
3. **Weapon introduction:** Compare an earlier scattergun acquisition in late Intake or early Foundry with the baseline. Choose one location after observing the opening. Provide a finite, authored close-range teaching opportunity and adjust only the necessary supply. Do not add a new weapon, inflate every ammo pickup, or retune all six damage profiles at once.

Changing checkpoint prerequisites or pickup locations can intentionally change exact flow assertions. Update those assertions with the approved new encounter contract; never delete them because they fail. Do not casually reuse shipped IDs, since removed sets, strict actor validation, and old continuation saves depend on them.

### Balance and pacing records

Record entry/exit HP, armor, owned weapons, per-weapon ammo, misses, resource grants, deaths, checkpoints, and time spent lost versus fighting. Use actual earned inventory when entering later levels and bosses. Existing perfect-aim or staged boss fixtures remain useful integration coverage but do not prove human affordability or whole-campaign pacing.

Keep three fixed difficulties and no adaptive spawn/difficulty system. Valve's published pacing work supports testing pressure and relief as authored rhythm; it does not justify importing an adaptive Director into this game. Keep relief intervals purposeful through route recognition, supply, optional story, and landmark reveals rather than forced waiting. [Pacing research][S-pacing] [Playtest method][S-playtesting]

## 11. NC-08: Give every interactive purpose a distinct original shape

### Current runtime and existing unfinished work

`level.gd` constructs pickups and interactions using the same scaled `containment_capsule` and a colored core. Health, armor, and blood get some distinct colors, while multiple other functions share amber. Ammo, weapon, story, checkpoint, and exit cannot depend on color alone for recognition. [Marker construction][C-markers]

There is already an eight-marker producer in `tools/build_marker_art.py` and `source/art/marker-inputs.json`. It describes different ammunition, health, armor, key, weapon, story, checkpoint, and exit forms. The prepared pack is not adopted in the authoritative 103-asset manifest. Its validator currently fails before production because immutable helper pins no longer match the pinned source. [Producer][C-marker-builder] [Validator][C-marker-validator] [Manifest][C-art-manifest]

| Helper | Recorded SHA-256 | Actual SHA-256 at audited commit |
|---|---|---|
| `tools/build_art.py` | `25c9dca4239b0de3929baaa53a4efee7ee7fbedfe0d0085bf6f1d30b158c2d95` | `285c99ece27a834e912e90f9c5d07ca4b2f8392a1045a1c089c7aa4fb5b8f581` |
| `tests/test_art.py` | `8822098e8dc522536c594ed96784be6ef1b2ed5a3936aa2f727ab79b001c2d2f` | `0922073a2c13921167ebae6492264d00c56ab67f6fa1544bc3d42a37a94539de` |

Reconcile the actual helper changes and original lineage. Either reproduce the legitimate archived recipe in an isolated root or create a reviewed new recipe and regenerate fresh outputs. Updating pins to bless existing old outputs is not sufficient. Preserve selected references, editable sources, and failed-candidate evidence.

### Adoption contract

Add a small level-owned visual factory mapping purpose to stable art ID. Retain existing gameplay IDs, positions, collection thresholds, removal rules, and save semantics. Marker children remain visual-only; no new cosmetic collider or hidden collection state. Existing `remove_marker(id)` remains the visual-removal boundary.

| Purpose | Proposed shape emphasis | Runtime distinction |
|---|---|---|
| Ammo | Narrow stacked cartridge/tower form | Weapon-family emblem or unmistakable ammunition motif |
| Health | Asymmetric basin/recovery vessel | Open receiving shape, separate from armor |
| Armor | Protective crescent/plate arrangement | Broad shield mass |
| Seal/key | Forked carrier with inserted seal | Blood and ivory use different emblems as well as color |
| Weapon | Low cradle presenting the weapon identity | Exact weapon label on acquisition |
| Story | Codex/record apparatus | Readable record motif shared with survey |
| Checkpoint | Anchored tripod or station | Recognizable safe interaction structure |
| Exit | Large descending coil/gate form | Clearly different scale and silhouette from supplies |

Use the existing producer as the starting candidate and preserve its original design provenance; the table is a functional design brief, not a substitute for reference inspection. Create HUD/survey glyph variants that share these meanings without shrinking detailed 3D renders into illegible tiny icons.

### Acceptance

Compare each marker at actual authored distances and, initially, 4/8/16 m on dark and bright backgrounds. Inspect grayscale and color-deficiency diagnostic transforms; those images supplement human recognition rather than certifying accessibility. Full/over-cap pickups must remain present when no grant occurs. Collection, Continue, checkpoint rewind, consumed-marker absence, collision clearance, scene ownership, and load/memory must remain correct.

Update `test_scenery.gd` and `test_marker_mesh_sharing.gd` deliberately because they encode the old capsule choice. Keep sharing and teardown coverage; replace the shape contract, not the underlying correctness checks.

## 12. NC-09: Build a coherent weapon and actor art system

### Current visual evidence

The inspected rivet pistol v2 is angled, darker, and more clearly layered than the five older centered viewmodels. Among opaque idle pixels, approximately 19-to-33% of those older sheets have all RGB channels at least 232; the current rivet sheet has none under that threshold. This is an image diagnostic, not an objective quality score or proof of current scene clipping. [Weapon sheets][C-weapon-assets]

The Choir Avatar's idle alpha widths across eight direction cells are `184, 135, 39, 135, 184, 135, 39, 135` pixels in 256-pixel cells. Its front is about 4.7 times wider than its side. That is a measured silhouette property, not a claim of invisibility or a proven hitbox error. The real aim point, visible body, world scale, and collision capsule must be reviewed together. [Actor sheets][C-actor-assets] [Sprite/body setup][C-enemy-body]

### Production direction

Use the new pistol's material separation and authored volume as a quality benchmark, while keeping each weapon identifiable. The lineup should progress from industrial hand tool through mechanical firearms into biological pressure instruments. Distinguish major masses, grip, barrel or emitter, silhouette, and negative space before adding tubes and scratches. Keep worn ivory as a selected highlight/material, supported by dark mass and restrained metal/tissue colors.

Start with one older weapon, preferably scattergun because it is the next introduced firearm and has a clear close-range teaching role. Compare the replacement at its actual 320×200 frame size and in the current HUD placement. If the new approach works, apply the shared material and posing rules to the remaining weapons without making their silhouettes interchangeable.

For actors, preserve directional sprites and author recognizable side forms. Give workers and summoners distinct major masses. Make the crawler readable at low view angles. Explore thicker lateral structures or explicitly authored side poses for the Avatar while leaving its gameplay collision unchanged until an actual mismatch is demonstrated. Inspect eight directions on both dark and light backgrounds, with development overlays for capsule, aim points, and floor contact.

Valve's published illustrative-rendering work supports using silhouettes, value organization, and controlled detail to separate characters from environments. Apply those principles to NULL CHOIR's original horror language. Do not copy Team Fortress character shapes, palettes, or assets. [Silhouette and value research][S-art]

### Explicit atlas and socket metadata

Introduce a minimal per-asset metadata record consumed by the real renderer: columns, rows, cell size, semantic pose IDs, origin/foot point, world scale, and optional per-pose muzzle/effect sockets. Existing five-row actor sheets and three-frame weapon sheets need a compatible fallback while assets migrate. Avoid a single global row-count change that breaks all old exports.

Current ammunition weapon flashes use one shared effect row and a fixed rectangle. The rivet metadata's local muzzle `[140, 62]` happens to match that fixed position before recoil. The weapon receives a recoil offset that the flash omits. Resolve one weapon pose transform and apply it to both the viewmodel and its socket. Select an appropriate effect family for each weapon; the impact tool gets no firearm flash. [HUD weapon drawing][C-hud-weapon] [Rivet producer][C-rivet-builder]

Combine this with NC-02's accepted-shot age. Check every weapon's idle/fire/recover state, immediate post-shot flash, recoil, switching, sustained repeater fire, pause, and map teardown. More flash area must not hide the enemy the player is trying to track.

### Art-production receipt

Every adopted asset batch must record stable asset ID; selected reference path and hash; actual-pixel inspection notes; Blender source/collection and named editable assemblies; recipe/helper hashes; output hashes; axis/origin; mesh/material/triangle bounds; atlas metadata; import settings; and affected runtime placements. Verify that a meaningful source edit can be exported and reverted, rather than shipping a flattened scene that is nominally a `.blend` file.

Inspect reference, Blender preview, current in-game frame, candidate in-game frame, and diagnostic value view at matched sizes. An attractive reference or Blender render cannot approve in-game hit expectation or legibility. Preserve originals and integrate only owned, reviewed paths.

## 13. NC-10: Make the architecture, light, and surfaces support the game

### Current composition boundaries

The source already includes sixteen unique loop heroes, the required tradition-derived set pieces, and substantial current Intake cathedral work. Intake has a 26 m central nave and 14 m adjacent ceilings; older low-ceiling screenshots do not describe that current geometry. Four later levels also have specialized overhead families. Preserve these assets and their staging intent.

The remaining shared construction still applies the same floor/wall/grate family, ribbed boundary wall and conduit pattern, and one global environment setup. Unique props alone cannot make every corridor, approach, and return view distinctive. [Surfaces and normals][C-surfaces] [Boundary dressing/environment][C-environment] [Current Intake][C-intake]

### 13.1 Correct ramp normals as a separate patch

Floor vertices use varying elevation heights, but emitted normals remain `Vector3.UP`; ceilings use `Vector3.DOWN`. These are not geometric normals on a slope. Derive triangle normals from the unchanged vertices with the correct Godot winding/sign, or use the native mesh normal-generation path after verifying its result. Keep positions, UVs, indices, collision, local chunk boundaries, and Intake exact geometry unchanged.

Assert that a nonflat triangle's normal is finite, normalized, and perpendicular to both edges; verify the intended front direction. Then compare actual ramp lighting and retain native floor winding, capsule placement, traversal, and ceiling checks. Do not combine this deterministic correction with tonemapping or material changes that obscure its effect.

### 13.2 Optional level profiles and authored room modules

Add an optional validated level visual profile whose absence reproduces today's settings exactly. Begin with fields the runtime needs: surface family, selected boundary module IDs, trim material, ambient color/energy, depth-fog parameters, and tone/glow choices. Define numeric bounds and known identifiers before construction. Keep profile defaults centralized; avoid a hundred loosely interpreted per-room flags.

Use explicit authored bay/region records to choose solid walls, deep recesses, lancets, service openings, and low-detail surfaces. Associate them with recognizable room or loop regions. Preserve clear aisles, native collision, ceiling clearance, local light coverage, and conservative occlusion. Do not randomize clutter at runtime or repeat Intake's cathedral kit everywhere.

| Level | Proposed traveled-space identity | Existing content to retain |
|---|---|---|
| Intake | Tall restrained nave, deep side aisles, pale structural mass, cold recesses; first inspect the current 26 m composition | Skin Bell, Siphon, cathedral sources, both loops and religious machines |
| Foundry | Heavy pressure bays opening into furnace height; angled exhausts, dark heat shields, broad ember recesses | Vertebral Furnace, Marrow Crucible, authored non-jumping routes |
| Processional | Long acoustic spaces interrupted by pipe crossings and turning chambers | Walking Organ, Palanquin, acoustic/reed structures |
| Reliquary | Deep stacked face niches and radial restraint geometry surrounding quiet dark recesses | Face Halo, Memory Wheel, unique archive structures |
| Nursery | Broad shell chambers, contained translucency, opaque ribs, asymmetrical umbilical routes | Gestation machinery and protected boss arena |
| Ossuary | Sorting terraces, bone-bin negative space, spiral trusses and readable ramp depth | Rib Bridge, Bone Mandala, original traversal |
| Inversion | Stable playable floor framing recessed cosmic cavities, fractured suspended anatomy, surgical containment lines | Existing membrane and impossible-sky identity |
| Heart | Nested jaw vaults and arterial pressure chambers, with small human service details establishing colossal scale | Mouth restraint, Pulse Mandala, Avatar arena and both revelations |

These are proposed composition directions, not claims that the named pieces are absent. Retain at least two authored loops per map, unique loop heroes, and the approved seven distinct tradition-derived structures per level. Recoloring shared tiles does not satisfy those requirements.

### 13.3 Vividness through hierarchy

Give each important arrival one dominant landmark, supporting route cues, and quiet surfaces behind likely threats. Use broad dark/pale masses and selected saturated light or tissue accents. Let the world become more biologically saturated and structurally impossible across the campaign while preserving combat readability. Avoid making every surface emissive, every edge equally bright, or the whole screen bloom.

Compare lamp aim, material/value grouping, room silhouette, fog range, and tone curve separately. A Filmic/ACES trial may preserve highlights differently from current linear tonemapping, but only actual captures can establish whether this scene clips or improves. Test bone, metal, tissue, colored fixtures, shadow detail, and enemy separation at the intended pixel size.

The selected Mobile renderer supports depth fog, tone mapping, glow, decals, and reflection probes. It does not provide volumetric fog, SSAO, SSIL, or SDFGI. It also has per-mesh light limits, including eight omni and eight spot lights in the documented matrix. Keep local floor/ceiling chunks and measure light coverage. A Forward+ conversion is not required to establish stronger composition. [Godot renderer capabilities][S-renderers]

### 13.4 Measure asset cost without destroying pixel clarity

Each 2048×1280 boss atlas represents about 10 MiB of raw RGBA pixels before actual runtime allocation and mip overhead; PNG disk size is not VRAM usage. Trial texture compression on one boss and inspect alpha edges/material values. Trial mipmaps separately because atlas-frame bleed and pixel crispness are different problems. Add gutters or a different atlas representation only after demonstrating the artifact.

Keep nearest sampling for HUD/viewmodels. Compare world texture minification in motion as well as still images. Preserve the level-owned PackedScene references, static wall occluders, current local chunks, and bounded effects. Prior rejected batching experiments are evidence to consult; a new batching patch needs a new measured cause and unchanged lighting/occlusion behavior.

## 14. NC-11: A readable HUD and safe comfort-setting migration

### Retain the current instrument's information

The current HUD already derives HP, armor, ammo, owned weapons, seals, objective, discovery state, boss health/phase, and interaction prompts. It supports unusual legacy ammo values and a compact 38-pixel bottom instrument. Several captions are only 7-to-8 logical pixels; elaborate icons shrink from 64-pixel cells to 20-pixel weapon slots and 8-pixel record sockets. Large prompt backplates occupy a significant lower-world strip. The arsenal labels still hardcode 1-to-6 even when actions are rebound. [HUD layout][C-hud-layout] [Binding text][C-preferences]

### Proposed layout hierarchy

| Layer | Always visible in combat | Contextual or requested view |
|---|---|---|
| Critical | HP, current ammo, selected weapon, legible reticle, immediate damage/threat feedback | Death/recovery choice replaces combat state when needed |
| Supporting | Armor, compact owned/selected weapon state, seal progress | Full arsenal bindings and capacities in survey/controls |
| Objective | Short current action or gate requirement | Expanded route/survey information |
| Narrative | Brief prioritized record acquisition cue | Full recovered text in a read-only records view |
| Boss | Name, truthful health/phase, necessary tell | No unnecessary decorative panel over the aiming region |

Retain exact values and important empty/locked/low states. Design a legible baseline within the current 38-pixel instrument before introducing a larger readability preset. The preset must have explicit layout rules; a blanket font multiplier will clip text and obscure the world.

Use a redistributable font with provenance and suitable glyph coverage. Inspect numerals, punctuation, and action names at actual logical resolution. Author small 16/20/24-pixel icon variants with corrected silhouettes instead of simply downscaling detailed cells. Keep longer binding descriptions in controls; the live HUD can use a valid compact device glyph and a clear fallback.

Use most recently active input device to choose keyboard/mouse versus gamepad hints. Standardized button/trigger names improve the current raw `Pad N`/`Axis N` labels; unknown hardware retains an honest fallback. Do not infer device changes from constant held movement every frame or mutate saved bindings while changing glyphs.

### Reticle, flashes, FOV, and devices

Add a clear contrast treatment to the central reticle so it survives both pale bone and dark backgrounds. Keep assistance acquisition distinct from confirmed damage. Offer a restrained reticle style/size/contrast choice only with real layout and state tests.

Separate reduced damage flashes from camera shake. Current flash strength depends on the camera-shake option, coupling two different comfort needs. Preserve independent head bob, camera shake, invert-Y, and audio options. [HUD reticle/flash][C-hud-weapon]

Godot's current default `KEEP_HEIGHT` makes `fov = 85` vertical; at 16:9 it is approximately **116.91 degrees horizontal**. That can be intentional, but the setting must state its axis. Expose a clearly labeled FOV or preserve vertical values with an equivalent horizontal readout. Compare 65/70/75/85 vertical candidates in fixed target-acquisition tasks before choosing a new default. Do not assert that one FOV is universally correct. [Camera semantics][S-camera]

Mouse displacement and stick rotation use different units but currently share sensitivity. Provide independent mouse/stick sensitivity with migration that initially reproduces existing settings. Calibrate stick deadzone and fine-aim response using physical hardware; preserve circular movement input and `screen_relative` mouse behavior. Motion and input accessibility guidance supports adjustable comfort and assist choices; native trials decide their useful defaults here. [Input documentation][S-input] [Mouse motion][S-mouse] [Input accessibility][S-input-access] [Motion comfort][S-motion]

### Migration is part of the feature

`preferences.from_dict()` currently expects a strict version/shape and exact option count. Adding keys to defaults alone can invalidate saved preferences. Implement explicit v1-to-new migration or a carefully validated additive reader: preserve all existing option values and desktop/gamepad bindings; provide defaults only for new absent fields; reject malformed/nonfinite/range-invalid data; keep atomic persistence and campaign files separate.

Test default, existing v1, new valid, malformed, unknown-field, partial-write, and rebound configurations. Exercise long chords, mouse/gamepad input, all six weapons, 0/1/2 seals, full/empty/low/legacy over-cap ammo, low/dead HP, armor extremes, all eight discoveries, boss plus message, missing-seal gate, survey, settings, title, pause, and ending. Inspect both 640×360 logical imagery and actual window scaling. Automated bounds/text assertions cannot certify readability or beauty. [Text guidance][S-text] [Contrast guidance][S-contrast]

## 15. NC-12: Keep interactions and messages consistent with the world

`nearest_interaction()` performs a native world ray query; current HUD state construction can reach it from the render/update path. Move the interaction query into the same physics-owned observation boundary used for aim. The displayed prompt and the accepted interaction should use the same current valid entity ID, range, requirements, and obstruction result. Revalidate on execution and clear the result on scene changes. [Interaction selection][C-interaction] [HUD state][C-hud-layout]

Passive pickup/checkpoint activation uses proximity without an intervening-world check. This creates a source-level possibility of collecting through a thin wall; incidence in current authored maps is not established. Add a narrow native blocked/clear fixture first. If it fails the intended contract, use bounded meaningful endpoints on the player/marker or volume, not a decorative model center. Retain effortless automatic collection when clear, and avoid making floor pickups fail because a ray terminates inside scenery. [Passive triggers][C-passive]

Current narrative and ordinary notifications share one message slot. Pickups can replace a longer discovery, and a consumed story object cannot then be reread through that object. Add a small bounded priority policy for critical objective/recovery information, acquired records, and routine supply. Derive a read-only recovered-record list from existing discovery IDs/text and expose it through survey/pause. Do not create a new quest database or serialize duplicate story content. [Story and message paths][C-story]

Replace generic `RECOVERED AMMO/WEAPON` text with the actual weapon name or actual granted amount. Calculate the difference before/after collection so full or over-cap inventory never claims a grant that did not occur. Keep visual/audio confirmation aligned with real state changes.

Check prompt/interaction agreement across competing nearby objects, a wall, elevation, missing seals, collection/removal, pause, and map retirement. Check pickup messages during story and boss cues, reacquired records after appropriate checkpoint rewind, no duplicate rewards, and unchanged alternate-ending conditions.

## 16. NC-13: Reduce code coupling where the repaired behavior needs it

The central script combines menus, lifecycle, combat queries, collection, story, recovery, and test hooks. That warrants smaller boundaries, but its approximately 877 lines are not grounds for a wholesale rewrite. Preserve its public facade and scene/cancellation ownership while moving only policies that have a demonstrated test or maintenance benefit. [Main orchestration][C-main]

Useful candidates are planar response, fire readiness/shot age, aim resolution, interaction observation, damage geometry, and HUD presentation data. Each needs one clear owner and small direct interfaces. Typed lightweight records or a narrowly validated dictionary are sufficient. Avoid a generic event bus, ECS, global resource cache, dependency-injection framework, second AI, or parallel state machine introduced solely to make the architecture look cleaner.

`level_data.gd` parses authored JSON with little explicit schema/reference validation before construction. Add a focused build/load validation pass for stable unique IDs, known actor/weapon/art IDs, finite transforms/elevations, encounter references, checkpoint prerequisites, loops, and optional visual profiles. Fail before constructing a partial map and show an actionable file/field error. Keep runtime data primitive and trusted by explicit validation; never accept executable objects from save/content JSON. [Level data][C-level-data]

Validate new optional art/room metadata at the same ownership boundary that consumes it. Keep combat persistence independent of visual-profile changes. Avoid converting all JSON into custom resources unless a measured editor/validation problem makes that worthwhile.

If lifecycle booleans are repeatedly causing invalid combinations, consider a small explicit phase enum as a separate reviewed patch after controls stabilize. First map existing pending-load, pause, dead, title, ending, and playing transitions and preserve cancellation identities. Changing names without preserving those guards is a regression.

## 17. NC-14: Measure rendering, loading, audio, and the actual release

### 17.1 Reconcile draft PR #35 before changing resolution

Audited main renders the world at the accepted 640×360 internal baseline with integer pixel scaling and Mobile/Metal. The existing draft PR separates sharper 3D content from the logical 640×360 HUD. Its reported 1280×720 window sample uses 1280×720 3D content; its 960×540 sample retains 640×360 content with integer letterboxing. These are that PR author's samples, not measurements reproduced here. [Rendering configuration][C-project] [PR #35][R-pr35]

Inspect the exact current PR head, discussion, changed tests, and newer receipts. If it is still the right implementation, reuse or integrate it through the actual branch workflow instead of duplicating it. If adopted, explicitly reconcile `DESIGN.md`, `ARCHITECTURE.md`, options, and rendering assertions with the chosen world/HUD contract. The user's visual-upgrade request supports evaluating this direction; it does not make an unmeasured candidate accepted.

Compare baseline and candidate at identical scene, camera, FOV, actors, preferences, window size, and Metal/Mobile backend. Raising both world dimensions by two multiplies shaded pixel count by four; actual frame cost depends on the scene and must be measured. Capture logical HUD sharpness, world silhouette detail, reticle alignment, projected target cues, settings/menu scale, letterboxing, mouse behavior, and all HUD corner cases.

Use actual frame-time percentiles, worst spikes, GPU/CPU time where available, memory residency, cold shader behavior, and startup/transition time. Report resolution and thermal/power context. A short empty-room FPS sample or average alone does not establish sustained normal-combat acceptance. Keep 60 FPS as the approved target; predeclare a reproducible sampling protocol and hitch/regression thresholds before comparison rather than inventing a favorable threshold afterward.

### 17.2 Profile startup and transitions before introducing concurrency

The music node parses the packaged SoundFont and builds its selected bank in `_ready()`. That is a concrete place to instrument if the menu/startup target is missed, not proof it currently exceeds three seconds. Measure application launch to **input-ready** menu, menu action to controllable level, and ordinary transitions, including audio readiness. [Music initialization][C-music]

Separate import cost, resource I/O, bank parse, scene instantiation, native physics registration, shader/pipeline preparation, and user-interface activation. Keep the existing level-owned scene retention. If resource loading is a demonstrated blocker, use Godot's threaded resource requests and status polling; calling the final getter before completion can still block. Do not instantiate scene nodes or manipulate native audio objects on arbitrary worker threads without documented safety. The custom SoundFont parser may need its own carefully bounded data-only preparation rather than being treated as a native threaded resource. [Background loading][S-loading]

A responsive title screen must not falsely claim readiness while Start enters an undefined state. Make loading explicit, cancellable, and consistent with current asynchronous placement ownership. Preserve failure UI, Retry/discard semantics where applicable, and clean cancellation on title/pause/replacement.

### 17.3 Preserve and audition live MIDI

Retain the eight original scores, packaged SoundFont, pinned synthesizer dependency, and public `play_level`, `set_paused`, and `stop` ownership. The bank is intentionally retained across level changes; do not reload it for each map or replace music with rendered recordings to make timing tests easier.

Audition actual standalone audio offline: all eight tracks, repeated loop boundaries, dense notes, tempo/pitch changes, percussion, volume/mute, pause/resume, death/restart, and rapid level transitions. Confirm no stuck notes, audible seams, missing instruments, or hidden host-library dependency. The existing expression-based pressure mix can remain, while fixed difficulty and authored spawns remain unchanged.

Run relevant MIDI timing/bank/reliability/pressure tests and actual listening. A simulated Python demand test, source score inspection, or silent render cannot approve musical quality. The one `/private/tmp` error in this audit must be reported accurately or rerun in its supported environment, not counted as a pass.

### 17.4 Reproducible builds and release state

Inventory and pin the actual Godot/export-template, Blender, Python, synth, SoundFont, and asset recipe versions used. The repository describes Godot 4.7.2 and a 4.7 project; verify the executable and templates rather than assuming that declaration identifies an installed toolchain. Reproduce imports from the intended source and preserve generated output lineage. Use the existing build and packed-test tools after inspecting their current arguments and profile behavior.

The draft PR records a useful warning: reimport/headless repacking can affect Metal shader/pipeline cache availability. Preserve the selected native renderer and verify the exact built package's imports, resources, and cache requirements. An export that starts from one fixture does not prove every level's resources are present.

Add modest repository checks if no equivalent external gate exists: pure data/recipe validation and syntax on a suitable host, targeted native Godot checks on a supported host, and separately retained Mac export/packed receipts. A shared headless CI machine cannot substitute for sustained GPU performance or physical-control evidence on the target M4. Keep credentials and large disposable captures out of Git.

Verify the intended private release target, executable architecture, bundled dependencies, missing-resource errors, signing status, and exact archive digest. For normal distribution outside the Mac App Store, Apple's Developer ID/notarization workflow supplies a separate distribution trust gate; an ad hoc local test does not establish it. Use only available authorized credentials and state the actual distribution status. The repository explicitly treats authentication/upload authority as release-boundary evidence, so a signing identity alone is not enough. [Apple distribution][S-apple]

Do not publish an archive built from a different commit than the one in its report. If any necessary platform or account gate is unavailable, preserve the complete candidate and give the exact next command/action and missing capability. Leave that acceptance item pending without weakening it.

## 18. Suggested implementation and PR sequence

This is one integration plan, with bounded commits that can be reviewed and rolled back independently. Do not parallel-edit shared player, main, HUD, or persistence paths. Asset workers can prepare disjoint candidates while a parent integrates runtime contracts; serialize heavy Blender/native jobs until resource headroom is known.

| Slice | Dependencies | Owned focus | Required evidence before promotion |
|---|---|---|---|
| 0. Freeze current reality | Current HEAD/PR inspection | Instruction reconciliation, isolated profile, native capture manifest, existing test inventory | Current main/native startup receipt; identified source/release differences; explicit unavailable gates |
| 1. Movement consistency | 0 | `player.gd` planar step and real movement fixture | Failing rotated response, passing isotropy, unchanged capsule/floor traversal |
| 2. Fire ownership/cadence | 1 | Player input, readiness, accepted-shot age; affected main/HUD callbacks | Real short-tap/held/lifecycle tests; cadence counts; preserved six-weapon flashes |
| 3. Aim and interaction observations | 2 | Current-map resolver, melee profile, HUD cue data | Close crawler/cover/range/occlusion tests; cue and actual contact agree |
| 4. Hit geometry and visible combat | 3 | Damage context, enemy derived phases, bounded feedback/audio interfaces | Guardian delayed-hit/infighting tests; variant/timer consistency; native/listening comparison |
| 5. Recovery/settings integrity | Stable control interfaces | Player facing, preferences migration, exact binding labels | Legacy/current/malformed fixtures and async cancellation; physical Resume checks |
| 6. Marker adoption and HUD readability | 3, 5; art lineage repaired | Marker producer/mapping, final-size symbols, explicit HUD layouts | Immutable input preflight, editable source proof, collection/restore and visual comparison |
| 7. Weapon/actor quality | 2, 4, 6 | Per-asset poses/sockets; one validated art family at a time | Eight-angle/phase captures, matched source/runtime images, no collider or timing drift |
| 8. Room and lighting identity | 0; independent ramp fix | Normals, optional profiles, authored modules, selected materials | Geometry regression; all loop/hero/route clearances; matched views and GPU cost |
| 9. Campaign pacing | Stable controls/tells/markers | One checkpoint/weapon/encounter variable per comparison | Earned inventory, both seal orders, measured replay cost and learning |
| 10. Rendering and performance | Stable scene/HUD contract; PR #35 reconciled | Selected sharper-world candidate, measured loading/audio changes | Target M4 frame/load results, pixel HUD correctness, resource residency |
| 11. Release candidate | All accepted slices and reviews | Exact standalone export and private PR/release evidence | Section 19 fully accounted for; no unsupported production-ready claim |

NC-05 pathfinding joins the earliest slice whose native evidence demonstrates it is needed. Message/record clarity and focused schema validation can accompany their owning HUD/data slices. Avoid bundling unrelated broad rewrites under the label of cleanup.

### Review and rollback contract

For each slice, report the problem, source evidence, intended behavior, changed paths, exact baseline failure or visual baseline, passing checks, human/native evidence, remaining risks, and rollback SHA. Use explicit staged paths, inspect the staged/committed path set, and preserve the materialized base index in sparse/no-checkout worktrees. A partial index must never publish unintended deletions.

Reviewers should particularly look for hidden trigger debt, input lost between ticks, switched-weapon cooldown bypass, shot-age/flash coupling, stale map callbacks, wrong incoming-vector sign, HUD rays outside physics, save-schema rejection, duplicate pickup grants, asynchronous continuation reactivation, and renderer-dependent coordinate assumptions. Fix actual findings before expanding the test radius.

### PR description template

```text
Problem
The current game [specific observed behavior and player consequence].
Baseline: [actual SHA], with this spec's audited SHA used only as historical evidence.

Changes
[Small coherent behavior changes and why they solve the problem.]
[Asset/data migrations and PR #35 dependency or reconciliation, if relevant.]

Preserved behavior
[Only the material invariants reviewers need to assess this patch.]

Validation
RED: [exact real production-path command/capture and result]
GREEN: [exact command/result and affected retained regressions]
Native/GPU/physical input/audio: [actual evidence by category]
Packed artifact: [commit, toolchain, archive SHA-256, actual checks]
Independent reviews: [findings and repairs, not only a reviewer name]

Remaining gates
[Concrete blocked or unrun items, with next action and required environment.]
Rollback: [known restoration commit/artifact and any save migration implications]
```

## 19. Production acceptance matrix

The term production ready requires the relevant rows below to be satisfied by the actual candidate. A source audit, a successful PR, and a launchable preview are distinct milestones. Track every row as passed, failed, or blocked with an exact receipt. Do not replace failed checks with easier surrogates.

| Area | Required coverage | Evidence and pass condition |
|---|---|---|
| Movement and input | Rotated headings, analog magnitude, stop/reverse, real short taps, trigger axes, rebinding, pause/focus/Resume | Production-path native checks plus physical mouse/gamepad session; consistent response and no leaked/lost eligible action |
| Targeting | Assistance on/off, low/tall/floating roles, direct-center priority, angle/range boundary, cover and intervening actor, all weapon types | Native collision assertions and matching visible cue; no damage beyond finite reach or through blocked geometry |
| Weapons | All six with earned/finite ammo, repeat rate, switch recovery, dry fallback, projectile/splash/piercing, pose/socket alignment | Accepted-shot/ammo agreement, preserved prior regressions, actual native weapon recordings |
| Enemy behavior | All six regular roles, approach clearance, windup/commit/recovery, counters, armor, infighting, summon lifecycle | Live AI fixtures, source-geometry damage tests, readable attacks under physical play |
| Bosses | Both phases/variants, player-directed attacks, vulnerability, adds, finite resources, death/retry | Actual active fight and human play with earned campaign inventory; staged perfect aim is supporting coverage only |
| Campaign structure | Eight levels, both branch orders, required seals/gates, two loops each, unique heroes/religious pieces, secrets | Authored validation plus native traversal; no softlock, unintended pickup duplication, or inaccessible objective |
| Pacing/economy | Opening lesson, weapon progression, branch death replay, all fixed difficulties | Measured completion/resource/death records; design targets evaluated honestly without adaptive difficulty |
| Persistence | Current/checkpoint/entry, living actors and summons, player facing, legacy/malformed saves, disk failure, cancellation | Existing trust/lifecycle/placement/save-failure suites plus real Continue/death/restart round trips; no unrelated-save damage |
| HUD and settings | Critical values, unusual counts, long rebindings, device hints, contrast/readability, boss+message, menu/ending states | Bounds/state assertions and matched native captures; human legibility; all old preferences migrate correctly |
| Art | Current selected references actually inspected, editable originals, runtime exports, all directions/poses, marker identities, room staging | Source edit/revert proof, manifest/hash provenance, final-size runtime review and approved comparisons |
| Audio | Eight offline live MIDI scores, all loop/transition states, effects bearing, volumes/mutes, dense combat | Actual standalone listening plus relevant timing/bank/reliability checks; no seams, stuck notes, missing instruments, or host dependency |
| Performance | Normal combat, dense representative scenes, all levels, both bosses, selected renderer/resolution | Sustained target M4 records meet the approved 60 FPS, input-ready cold menu within three seconds, and ordinary transitions within two seconds under a predeclared protocol; a measured miss remains failed |
| Rendering | Mobile/Metal, current and intended window sizes, integer scaling/letterboxing, HUD/world coordinates, import/cache behavior | Actual GPU/native and exact packed captures; no headless substitute for backend or visual quality |
| Distribution | Exact Apple Silicon standalone package, private target, dependencies, resources, signing/notarization status | Verified artifact digest and source commit, clean-machine/offline appropriate launch, honest release metadata |
| Review and operability | Independent correctness/complexity review, known failures retained, reproducible commands, scoped Git changes | Findings resolved or explicitly blocked; no unexplained untested changed subsystem |

### How to make the campaign matrix manageable without reducing scope

Automate deterministic data, collision, resource, and restoration combinations. Exercise all eight levels and all three fixed difficulty configurations, including both seal orders where they affect progression. Use representative native fixtures to stress shared mechanics, and retain at least a full physical-input campaign traversal with earned inventory plus targeted alternate-order/difficulty/boss sessions. If broad first-play pacing confidence is claimed, obtain enough independent first-time sessions to support it and report participant familiarity and sample size; one expert run cannot establish a universal experience.

Separate route automation from human readability. Existing `test_intake_combat.gd` and `test_active_boss_fights.gd` use synthetic movement/aim or staged conditions; keep their useful active behavior assertions and label their limits. Never substitute stationary high-ammo damage tests for those active fight contracts.

### Reusable native capture manifest

Each capture case should include `case_id`, source commit, exact packaged artifact if applicable, engine/export version, renderer/driver, window and internal render dimensions, logical HUD extent, level, camera position/yaw/pitch/FOV axis, fixture or earned resource state, actors and attack phases, weapon, preferences, frame/time, and image hash. Use isolated profiles and keep raw local receipts outside committed source unless the repository explicitly adopts a curated evidence image.

For each level capture entry, both loop arrivals, changed return junction, hero reveal, gate/checkpoint, dense combat, and optional story. Add both bosses' distinct tells and recoveries, all weapon phases, and the HUD state matrix. Distinguish image references, Blender previews, historical screenshots, current source-run frames, and exact packed frames in filenames/metadata.

### Completion statement the coding model should be able to make

```text
Implemented [specific slices] at [commit]. The attached PR contains [scope].
Verified [precise native, GPU, physical, listening, campaign, and packed evidence].
The shipped archive is [name, SHA-256], built from [commit/toolchain].
The remaining blocked acceptance items are [none, or an explicit list].
The evidence supports [source milestone / tested candidate / production release].
```

If the last line cannot truthfully say production release, report the narrower achieved milestone and preserve the exact remaining work. This document supplies a path to that result; it does not replace its execution.

## 20. Source map and primary research

Repository links below are pinned to the audited commit. Line anchors help locate the reviewed behavior, but current HEAD may differ. Read the whole relevant function before editing. External research informs the implementation principles; proposed art, tuning, and pacing decisions are this specification's recommendations and need the comparisons described above.

### Repository evidence map

| Topic | Primary files |
|---|---|
| Authority, accepted game, runtime boundaries | [AGENTS][C-agents], [DESIGN][C-design], [ARCHITECTURE][C-architecture], [CHECKPOINT][C-checkpoint] |
| Movement, input, weapons, aim | [Player][C-player-control], [fire path][C-player-fire], [main aim][C-autoaim], [weapon efficiency tests][C-weapon-tests] |
| AI, armor, projectile context | [Actor setup][C-enemy-body], [display][C-enemy-pose], [attacks][C-enemy-attack], [damage][C-enemy-damage], [pathfinding][C-path], [projectiles][C-projectile] |
| Persistence, interactions, story | [Campaign][C-recovery], [restoration][C-start], [passive triggers][C-passive], [interaction query][C-interaction], [story/messages][C-story] |
| HUD, devices, presentation | [HUD][C-hud-layout], [weapon/reticle drawing][C-hud-weapon], [preferences][C-preferences], [effects][C-effects], [bounded ammo visuals][C-ammo-visuals] |
| World and campaign | [Level data reader][C-level-data], [authored data][C-data], [Intake][C-intake], [surfaces][C-surfaces], [boundary/environment][C-environment] |
| Asset pipeline | [Manifest][C-art-manifest], [marker inputs][C-marker-inputs], [builder][C-marker-builder], [validator][C-marker-validator], [rivet builder][C-rivet-builder], [weapons][C-weapon-assets], [actors][C-actor-assets] |
| Runtime and release | [Project][C-project], [music][C-music], [game tests][C-tests], [build tools][C-tools], [release][R-release], [draft PR #35][R-pr35] |

### Primary-source research and its use

| Source | Applied principle | Limit of application |
|---|---|---|
| [Godot 4.7 CharacterBody3D][S-character] and [Vector2][S-vector] | Native velocity semantics and a vector-bounded planar step | Does not choose the best acceleration rate for this game |
| [Godot 4.7 ray casting][S-ray] | Physics-owned native queries | Establishes an API safety boundary, not a reproduced crash here |
| [Godot 4.7 Input][S-input] and [mouse motion][S-mouse] | Preserve analog input/deadzones and unscaled relative mouse motion | Hardware comfort still requires actual devices |
| [Godot 4.7 Camera3D][S-camera] | Explicit FOV axis/aspect conversion | A broad FOV is not automatically wrong |
| [Godot 4.7 renderers][S-renderers] | Stay within Mobile capabilities and measured light/resource limits | Feature support does not establish scene performance or quality |
| [Godot 4.7 background loading][S-loading] | Threaded requests, nonblocking status checks, careful final retrieval | Custom parser and scene/audio thread safety require separate analysis |
| [Valve illustrative rendering paper][S-art] | Silhouette, value organization, controlled detail | Principles only; no copied characters, artwork, or palette |
| [Valve AI Systems of Left 4 Dead][S-pacing] | Deliberate pressure/relief and readable encounter rhythm | No adaptive Director or copied encounter implementation |
| [Valve's Approach to Playtesting][S-playtesting] | Observable hypotheses and iterative player evidence | Does not certify this campaign without actual sessions |
| Xbox accessibility: [text][S-text], [contrast][S-contrast], [input][S-input-access], [motion][S-motion], [assistance][S-assist] | Readability, remapping, independent options, optional assistance | Guidance informs design; screenshots and options alone are not accessibility certification |
| [Apple Developer ID distribution guidance][S-apple] | Accurate signing/notarization and delivery evidence | Requires actual authorized toolchain/account execution |

The research also inspected id Software's published Quake III movement source as a historical design reference. It was not copied, decompiled, or incorporated. NULL CHOIR should implement its own small Godot movement policy and preserve license/provenance records for any supporting dependency. No commercial-game decompilation or extracted third-party assets were necessary for this audit. [Published source][S-quake]

## 21. Final handoff checklist for the implementing model

- Reconcile current HEAD, local instructions, active PR #35, and old evidence before editing.
- Start with NC-01 through NC-03 and the current native capture baseline.
- Keep accepted-shot age separate from readiness while preserving prior flash/pose repairs.
- Keep aim, interaction, and HUD observations on one current physics-owned truth.
- Keep damage geometry separate from attacker identity and save facing additive to existing recovery.
- Repair marker recipe lineage before adopting its distinct shapes.
- Require selected-image inspection, original editable sources, and final-size runtime comparisons for substantial art work.
- Promote pacing, FOV, lighting, and resolution candidates through measured comparisons, with targets unchanged.
- Retain the full eight-level, original-art, live-MIDI, fixed-difficulty brief and existing safeguards.
- Deliver the reviewed PR and exact native/packed receipts; make the completion claim match the evidence.

[C-agents]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/AGENTS.md
[C-design]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/DESIGN.md
[C-architecture]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/ARCHITECTURE.md
[C-checkpoint]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/CHECKPOINT.md
[C-player-control]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/player.gd#L4-L86
[C-player-fire]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/player.gd#L98-L178
[C-weapon-frames]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/player.gd#L94-L96
[C-autoaim]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/main.gd#L683-L695
[C-weapon-tests]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/tests/test_weapon_efficiency.gd
[C-enemy-body]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/enemy.gd#L4-L116
[C-enemy-pose]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/enemy.gd#L125-L132
[C-enemy-attack]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/enemy.gd#L214-L272
[C-enemy-damage]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/enemy.gd#L363-L376
[C-path]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/enemy.gd#L397-L417
[C-projectile]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/projectile.gd#L42-L93
[C-recovery]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/campaign.gd#L86-L135
[C-start]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/main.gd#L165-L289
[C-passive]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/main.gd#L295-L314
[C-interaction]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/main.gd#L407-L425
[C-story]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/main.gd#L378-L450
[C-hurt]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/main.gd#L464-L470
[C-main]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/main.gd
[C-hud-layout]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/hud.gd#L25-L181
[C-hud-weapon]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/hud.gd#L195-L228
[C-preferences]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/preferences.gd#L4-L150
[C-effects]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/audio/effects.gd#L20-L39
[C-ammo-visuals]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/ammo_visuals.gd
[C-level-data]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/level_data.gd#L7-L37
[C-data]: https://github.com/ihearttokyo/null-choir/tree/7229bce579d0188d03d93c14cb9cc2279355b167/game/data
[C-intake]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/data/01_intake.json
[C-markers]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/level.gd#L37-L54
[C-surfaces]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/level.gd#L91-L142
[C-environment]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/scripts/level.gd#L155-L198
[C-art-manifest]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/source/art/manifest.json
[C-marker-inputs]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/source/art/marker-inputs.json
[C-marker-builder]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/tools/build_marker_art.py
[C-marker-validator]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/tests/test_marker_art.py#L173-L180
[C-rivet-builder]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/tools/build_rivet_pistol_v2.py#L343-L350
[C-weapon-assets]: https://github.com/ihearttokyo/null-choir/tree/7229bce579d0188d03d93c14cb9cc2279355b167/game/assets/art/weapons
[C-actor-assets]: https://github.com/ihearttokyo/null-choir/tree/7229bce579d0188d03d93c14cb9cc2279355b167/game/assets/art/sprites
[C-project]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/project.godot
[C-music]: https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/game/audio/music.gd#L13-L32
[C-tests]: https://github.com/ihearttokyo/null-choir/tree/7229bce579d0188d03d93c14cb9cc2279355b167/game/tests
[C-tools]: https://github.com/ihearttokyo/null-choir/tree/7229bce579d0188d03d93c14cb9cc2279355b167/tools
[R-release]: https://github.com/ihearttokyo/null-choir/releases/tag/v0.2.2-art.4
[R-pr35]: https://github.com/ihearttokyo/null-choir/pull/35
[S-character]: https://docs.godotengine.org/en/4.7/classes/class_characterbody3d.html
[S-vector]: https://docs.godotengine.org/en/4.7/classes/class_vector2.html
[S-ray]: https://docs.godotengine.org/en/4.7/tutorials/physics/ray-casting.html
[S-input]: https://docs.godotengine.org/en/4.7/classes/class_input.html
[S-mouse]: https://docs.godotengine.org/en/4.7/classes/class_inputeventmousemotion.html
[S-camera]: https://docs.godotengine.org/en/4.7/classes/class_camera3d.html
[S-renderers]: https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html
[S-loading]: https://docs.godotengine.org/en/4.7/tutorials/io/background_loading.html
[S-art]: https://cdn.cloudflare.steamstatic.com/apps/valve/2007/NPAR07_IllustrativeRenderingInTeamFortress2.pdf
[S-pacing]: https://cdn.fastly.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf
[S-playtesting]: https://cdn.fastly.steamstatic.com/apps/valve/2009/GDC2009_ValvesApproachToPlaytesting.pdf
[S-text]: https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/101
[S-contrast]: https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/102
[S-input-access]: https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/107
[S-assist]: https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/108
[S-motion]: https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/117
[S-apple]: https://developer.apple.com/developer-id/
[S-quake]: https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/bg_pmove.c
