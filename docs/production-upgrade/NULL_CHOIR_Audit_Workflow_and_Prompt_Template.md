# NULL CHOIR: audit workflow and reusable prompt templates

Prepared 11 October 2026 for Jared. The companion [Production Upgrade Spec](NULL_CHOIR_Production_Upgrade_Spec.md) contains the recommendations and implementation contracts. This document explains how to reproduce the review, carry one recommendation into a bounded coding task, and collect evidence sufficient to accept the resulting game.

The requested work this turn was an audit and two documents. No repository source change, PR creation, asset generation, decompilation or release execution occurred. Future implementation and delivery remain separate work, even where existing project authority permits them.

## 1. Freeze the identity of the work

The review used the private repository [ihearttokyo/null-choir](https://github.com/ihearttokyo/null-choir) at main commit **`7229bce579d0188d03d93c14cb9cc2279355b167`**, tree **`20e41b9988facbc70dfd7d273c1ec5b19a432256`**. The returned recursive tree contained 743 entries, including 710 blobs. A total of 443 text files were materialized and checked against their Git blob identities. This established the integrity of the source copy. The substantive review concentrated on gameplay, targeting, controls, combat, persistence, campaign data, assets, HUD, authoring and relevant tests; it did not deeply audit every materialized file.

Release `v0.2.2-art.4` was a prerelease whose reported target matched this commit. Only metadata was inspected. Its ZIP was not downloaded, unpacked or run, so the review does not establish the archive's contents, signature or standalone behavior. [Release metadata location](https://github.com/ihearttokyo/null-choir/releases/tag/v0.2.2-art.4).

An open draft [PR35](https://github.com/ihearttokyo/null-choir/pull/35), head **`b1203c859b816e20feddcd349063f8b1d3e1ff95`**, proposed sharper 3D rendering while retaining the logical pixel HUD. It was not merged into the reviewed main. Its author reported native checks, but sustained performance acceptance remained open. Any later implementation must inspect its current state before duplicating or conflicting with that work.

These identities are historical anchors. A new task must obtain actual current HEAD, open PR state and release target again. It must not assume these values remain current.

## 2. What was actually inspected or executed

| Evidence | Result from this audit | What it establishes |
|---|---|---|
| Committed text | 443 files materialized and Git blob SHA verified | Integrity of the reviewed source copy |
| Committed images | 19 PNGs total: 16 current asset images and three historical captures decoded, inspected and hash verified | Actual asset pixels and historical capture content |
| Selected large references | Some references larger than 1 MiB could not be retrieved through the available reader | Existence/provenance only; their pixels were not inspected |
| Python syntax | 82 Python files compiled successfully | Python syntax acceptance in this environment |
| `test_art_recipe.py` | 4 passed | Focused recipe helper behavior |
| `test_playtest_protocol.py` | 33 passed | Focused simulated playtest protocol behavior |
| `test_music_demand.py` | 17 passed; one environmental error | Partial helper coverage; the suite did not pass completely |
| Marker input validation | Actual `load_inputs()` rejected immutable helper drift | A reproducible prepared-marker pipeline blocker |
| Controls and campaign calculations | Source algebra and static JSON analysis | Predicted behavior and authored counts, without native measurement |
| Primary documentation | Official engine and related primary sources researched | External technical support for recommendations |
| Independent work | Gameplay, visual/HUD, research, correctness and complexity reviews integrated | Independent source review, not additional native execution |

The music-demand error occurred because a fixture requested a temporary directory under macOS `/private/tmp`, which was absent on this Linux host. Keep that result as an environmental error. Do not silently mark the suite green, alter its acceptance or create host directories to conceal the mismatch.

Godot, Blender, macOS, an M4 GPU, native rendering, live audio and physical gamepad input were unavailable. No engine run, native playtest, heard MIDI audition or packed Mac execution was performed. Deep Research was not exposed in this session; the available search capability supplied primary-source research. User-global instruction files were unavailable, so there was no account-wide instruction read. Access to unrelated user files was restricted and was not used.

Use explicit evidence labels in every finding:

| Label | Meaning | Example of an invalid substitution |
|---|---|---|
| Source observation | A traced committed code/data path | Treating a code path as a reproduced native crash |
| Source-derived calculation | Algebra or simulation from source constants | Calling Python movement math a Godot measurement |
| Inspected asset pixels | Decoded current PNG/texture data | Calling an atlas a current gameplay screenshot |
| Historical capture | A recorded older game view | Reporting its old HUD or ceiling as current main |
| Source-native check | Production GDScript exercised by the engine | Calling synthetic perfect aim human playability |
| GPU/physical/listening trial | The named live system was actually observed | Treating headless PASS as visual or musical quality |
| Packed application check | The exact exported artifact was tested | Certifying a release ZIP from its metadata |

## 3. Reproduce an audit in ten steps

### Step 1: establish scope and authority

Write one sentence identifying the deliverable: audit only, implementation of named findings, or standalone release acceptance. State the authorized repository, intended base, owned outputs and permitted writes. For an audit, keep source and release unchanged. For implementation, name the exact production/test paths and integration owner.

Read current project [`AGENTS.md`](https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/AGENTS.md), [`DESIGN.md`](https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/DESIGN.md) and [`ARCHITECTURE.md`](https://github.com/ihearttokyo/null-choir/blob/7229bce579d0188d03d93c14cb9cc2279355b167/ARCHITECTURE.md) completely; consult current `CHECKPOINT.md`. Treat dated restrictions as history where current authority supersedes them, while retaining their failure cases as regressions. Record unavailable instruction sources accurately. Never claim an inaccessible global instruction file was read.

Preserve the approved eight levels, original editable artwork, eight offline live MIDI songs, fixed difficulties and standalone Apple Silicon goal. These requirements are not bargaining chips for making a test pass.

### Step 2: obtain and verify the exact committed source

Use the authenticated GitHub connector or an already authorized local Git checkout. Avoid credentials in commands or logs. In a normal development environment, an optional local clone and identity check can be performed as follows. These commands are future examples, not commands executed by this audit:

```sh
NC_REPO_DIR="$PWD/null-choir-audit"
gh repo clone ihearttokyo/null-choir "$NC_REPO_DIR"
git -C "$NC_REPO_DIR" status --short
git -C "$NC_REPO_DIR" rev-parse HEAD
git -C "$NC_REPO_DIR" rev-parse 'HEAD^{tree}'
git -C "$NC_REPO_DIR" ls-tree -r -t --full-tree HEAD
```

Choose the requested commit deliberately. Keep any existing dirty work separate. For a detached read-only inspection, use a separate worktree after verifying it is safe to create; do not reset the user's working tree. Git verifies objects during normal transport, but connector materialization needs explicit byte verification: compare each file's computed Git blob identity with its returned tree entry. Git blob identity is SHA-1 over `blob <byte_length>`, a zero byte, then the original file bytes. A content SHA-256 is useful for receipts but is a different identity.

Record source SHA, tree SHA, paths obtained, unreadable paths and the retrieval method. An unavailable binary is not evidence that the asset is absent. Do not reconstruct private code through public web search.

### Step 3: inspect in-flight work and stale documentation

Read open PR titles, changed paths, base/head SHAs, draft state and relevant checks. Compare the proposed renderer/HUD changes with PR35 before creating a competing branch. Evaluate a draft's evidence as a candidate; do not report it as shipped.

Reconcile old ledgers against actual code. At this reviewed commit, actor snapshots, selected-weapon flash timing, interval-relative repeater animation, focus-loss pause and several stale-map guards already existed, despite older documentation describing missing behavior. Mark each historical issue as present, repaired, superseded or unverified, with a current source link. README summaries and earlier screenshots are secondary to the exact inspected implementation.

### Step 4: preflight the tools and platform

Check the runtime without assuming availability:

```sh
python3 --version
git --version
command -v godot
command -v blender
uname -m
```

On the intended Mac, also inspect Godot's exact version, installed matching export templates, macOS version, Xcode/Metal tooling and available space. Current README specifies Godot 4.7.2 for this source; verify the actual project and dependency pins before changing versions. Record absent tools and continue useful read-only analysis. A Linux host cannot certify CoreAudio, Metal, signing or Apple Silicon behavior.

Before native execution inspect each fixture's paths, profile isolation, process ownership and finite timeout. The current `tools/check_game.py` invokes CoreAudio and requires clean exit plus a PASS receipt; it is a Mac-oriented runner and does not itself create an isolated user profile. Some fixtures provide unique save/settings names. Verify those paths before execution and use the project's isolated validation setup for tests that do not. Preserve primary user saves and unrelated windows.

### Step 5: trace complete behavior paths

For each complaint, follow input through state, physics, collision, damage, feedback and persistence. For targeting, inspect `player.gd` and `main.gd` together with collision layers, enemy capsules and the HUD. For acceleration, preserve `Input.get_vector` magnitude and distinguish terminal speed from acceleration. For combat, inspect enemy windup, committed target, release, recovery, counter lock, infighting and projectile lifetime. For art, inspect authoring recipes, manifests, generated pixels, runtime consumption and native placement.

Name a concrete finding and its strongest alternative interpretation. “The aim ranking chooses shortest range after a missed center ray” is established. “This frustrates every player” requires observation. “The direct center ray preserves the manually aimed enemy” is an existing safeguard and must remain part of the contract.

### Step 6: reproduce the smallest meaningful defect

Use algebra where it answers a deterministic question, then create a production-path native RED when the engine is available. This audit calculated yaw-dependent 180 versus 127 ms acceleration examples, the 12.8386° assistance half-angle, close-crawler reach exclusion and ideal repeater cadence. These calculations direct the fixture; they do not replace it.

The prepared marker blocker was reproduced by actual input validation, which rejected pinned helper drift. A proper repair reviews the helper changes and regenerates affected outputs with lineage. Updating hashes to endorse old outputs would not establish that the outputs came from the new helper.

For a verified copy of this repository, the narrow read-only preflight can be repeated from its root:

```sh
python3 - <<'PY'
import sys
sys.path.insert(0, "tests")
from test_marker_art import load_inputs
load_inputs()
PY
```

At the audited commit, this raises `AssertionError: immutable helper drift`. Inspect the imported validator before using this recipe on another project or revision. A compact reproduction of the source-derived control calculations is:

```sh
python3 - <<'PY'
import math
speed, acceleration, ticks = 9.0, 50.0, 60.0
half_angle = math.acos(0.975)
interval = 0.085
print("Axis start, seconds:", speed / acceleration)
print("Diagonal start, seconds:", speed / math.sqrt(2) / acceleration)
print("Aim half-angle, degrees:", math.degrees(half_angle))
print("Equal-floor anchor threshold, metres:", 0.70 / math.tan(half_angle))
print("Construction-offset threshold, metres:", 0.71 / math.tan(half_angle))
print("Nominal repeater shots/second:", 1 / interval)
print("Whole-tick repeat seconds:", math.ceil(interval * ticks) / ticks)
PY
```

The two anchor examples use equal floor origins or authored construction offsets, respectively. Neither measures native settling or bob. The next fixture must run the actual production player/enemy code.

Keep defect reproductions narrow. Do not use a full eight-map export to establish a two-capsule aim-selection failure. Conversely, do not substitute a copied Python integrator for production `player.gd` when claiming native movement acceptance.

### Step 7: inspect actual pixels and define matched captures

Decode current atlases and inspect their pixels at intended sizes. Record asset path, Git identity, dimensions, alpha bounds and runtime scale. Inspect all six weapons and all eight actor roles, including directions and attack/death poses. Distinguish an alpha-bound statistic from collision shape or quality acceptance.

Current captures must carry a case ID, commit, engine/driver, renderer, window/internal sizes, level, camera pose/FOV, campaign fixture, actor phase, weapon/resources, relevant preferences, frame and image hash. Use fixed cases: entry, each loop arrival/return, landmark reveal, gate, dense fight, boss tell, story, pause and transition. Source-run, editor and exact packed-app captures are separate classes.

Obtain and actually inspect selected reference pixels before substantial asset redesign. This audit could not inspect some large selected references, so a future worker must resolve that access before creative implementation. Preserve original `.blend` sources. The project's image-first reference requirement is a production instruction, not proof that a reference alone approves the game.

### Step 8: run focused checks and keep failures honest

These Python commands reproduce the narrow suites executed here when run from the repository root:

```sh
python3 tests/test_art_recipe.py
python3 tests/test_playtest_protocol.py
python3 tests/test_music_demand.py
```

Expect the documented music-demand environment error on a host without `/private/tmp`. On a suitable Mac, rerun the unchanged suite and report its actual result. Do not assume Linux's 17 passed cases mean the remaining Mac case passes.

After reading fixture isolation and on a matching Mac, example focused native gates are:

```sh
python3 tools/check_game.py tests/test_player.gd tests/test_controls.gd
python3 tools/check_game.py tests/test_weapon_efficiency.gd tests/test_combat_loop.gd
python3 tools/check_game.py --timeout 180 tests/test_late_weapons.gd
```

These were not executed here. Extend existing tests for new contracts instead of replacing real collision, pause, recovery and infighting coverage with simpler mocks. A timeout change needs a measured explanation; it must not weaken PASS/error/leak acceptance.

### Step 9: collect independent review before broad promotion

Give separate reviewers explicit paths and the same pinned evidence. A gameplay reviewer checks input/physics/aim/combat contracts. A visual reviewer inspects actual images and runtime consumption. A researcher verifies primary technical sources. A correctness reviewer traces lifetimes, schema migration and edge cases. A complexity reviewer asks what can be deleted or kept local.

If native Codex CLI workers are used, follow current `AGENTS.md`: request `gpt-6.1-sol`, `xhigh` and priority, never Max; verify actual telemetry before claiming the profile. Partition ownership, identify the integration owner and tell workers they are not alone. Serialize heavy jobs after a resource preflight. More workers do not turn unavailable native evidence into available evidence.

### Step 10: produce a reviewable handoff

Each recommendation needs current file/function links, evidence class, user-visible consequence, smallest proposed change, preserved invariants, decisive tests, measurable acceptance and remaining uncertainty. Group related contracts, but assign one coherent implementation slice per ticket.

The handoff should include exact source identity, executed checks/results, inaccessible evidence, in-flight collisions, a ranked plan and next resume step. Keep private captures local and public research queries free of private source. Deliver the documents without claiming the implementation or release is complete.

## 4. Future implementation and production gates

Start in an isolated branch/worktree from a verified accepted SHA. Freeze the regression/measurement contract and retain rollback source/assets. Reproduce RED, make the smallest shared-cause change, prove GREEN, obtain independent correctness and Ponytail review, repair their findings, then run affected broader/native/app gates. Use explicit staged paths and inspect the staged diff. Sparse worktrees need a materialized base index before staging so untouched files cannot become accidental deletions.

For controller work, change planar acceleration first while preserving speed and analog magnitude. Fire intent needs a complete lifecycle: quick taps survive until their first physics commit; unavailable taps follow an explicit reject/buffer policy; held Resume does not create a new press; death/focus/map changes cancel intent. Cadence remainder belongs only to uninterrupted repeated fire. Cancel that phase on release/switch/dry fallback/pause while preserving each weapon's recovery, and cap catch-up after a hitch. The companion spec deliberately permits quantized shorter gaps during a continuous hold, then normalizes a released/switched weapon's readiness to at least its last accepted shot plus its interval, retaining any later nominal deadline. This prevents a fresh tap or switch from bypassing recovery. Readiness and accepted-shot age share one authoritative playing-time clock but are different values; changing cooldown arithmetic must not start muzzle flash halfway through its animation.

For aim, preserve center-ray truth, finite reach, actor/world occlusion and map ownership. HUD acquisition must describe the actual initial ray without promising that moving targets, every scatter pellet or future launcher impact will hit. For damage, separate shooter identity from incoming direction and explosion origin. For saves/preferences, migrate existing files explicitly and validate complete documents before mutation. Preserve actor completeness, summon ledger, two-frame registration, cancellation and no resource refund during safe-position repair.

For visuals, change one variable per comparison. Preserve current source art and register outputs with reference/recipe/helper hashes. Evaluate marker recognition, attack state recognition, side silhouettes, viewmodel sockets and HUD text in matched native images. Do not adopt a renderer, tone curve or atlas compression change without exact target-GPU evidence. PR35 is a separate candidate whose adoption changes the visual comparison baseline.

The full production goal retains these gates from `DESIGN.md`:

| Gate | Required evidence |
|---|---|
| Eight-level campaign | Both seal orders, authored loops, secrets/story, all roles/weapons, both bosses, both revelations and earned finite resources |
| Persistence and agency | Continue, death/checkpoint restore, restart, save failures, focus pause, keyboard/mouse and physical gamepad |
| Original assets | Editable sources, traceable generated outputs, unique loop heroes and required level-specific set pieces |
| Eight live MIDI songs | Actual offline application synthesis, instrument audition, dense notes, tempo/bend/percussion, repeat seams, mute/volume, pause and switching |
| M4 performance | 60 FPS normal combat, usable menu within three seconds cold launch, ordinary transitions within two seconds; exact conditions and variance |
| Standalone Apple Silicon app | Exact archive downloaded/extracted, arm64/dependencies/signature checked, isolated packed workflow plus GUI/audio/control exercise |

Build/packaged examples below are future Mac work and were not run by this audit:

```sh
python3 tests/test_build_deadline.py
python3 tests/test_build_source.py --allow-window
python3 tests/test_macos.py
```

The source-preservation/build path uses a native graphics window for Metal baking; use `--allow-window` only when that foreground behavior is intended and authorized. `test_macos.py` uses an isolated profile and the exported binary's verification path. Its PASS does not establish physical controls, heard timbre, sustained FPS or a complete playthrough. Developer ID signing/notarization and upload retain their applicable release-boundary requirements. Report the exact artifact hash and current private target before delivery.

## 5. Reusable audit-only prompt

Replace brackets with concrete values. Attach the companion specification when continuing this audit.

```text
Audit [PRIVATE_REPOSITORY] at [REQUESTED_COMMIT_OR_BRANCH] for
[USER_COMPLAINTS / DECISIONS]. Deliver [DOCUMENT_PATHS_AND_FORMAT].
This task is audit-only. Do not change source, create PRs, generate assets,
publish builds or execute releases. Permitted writes are [AUDIT_OUTPUT_PATHS].

Read current AGENTS.md, DESIGN.md, ARCHITECTURE.md and relevant CHECKPOINT.md.
Apply available project instructions and current session authority. Report
instruction sources that are unavailable; do not claim global/account reads.
Keep eight levels, original editable assets, eight live MIDI songs and the
standalone Apple Silicon acceptance intact.

Resolve actual HEAD/tree, repository identity, open PR base/head/draft states
and current release target before analysis. Freeze source identity and verify
materialized bytes against returned Git blobs. Record unreadable evidence.
Do not infer absence from retrieval failure or inspect unrelated user files.

Trace production paths for input, movement, aim, collision, combat feedback,
enemy states, projectile lifetime, infighting, recovery, campaign loops,
HUD and asset authoring/runtime consumption. Read relevant existing tests.
Reconcile old docs and screenshots against current code. Preserve features
already present and identify repaired historical findings accurately.

Inspect actual available PNGs/references and label historical captures.
Research technical questions using primary documentation; keep private code
out of public queries. [AVAILABLE_RESEARCH_CAPABILITY] is available;
[UNAVAILABLE_PLUGIN_OR_PLATFORM] is not. Do not imply it was used.

Run only meaningful read-only or isolated checks supported by the environment.
Record exact commands, versions, exits, counts and environmental errors.
Label source, algebra, asset pixels, native source tests, GPU measurements,
physical input, heard audio and packed-app evidence separately.

If delegation is available and authorized, partition [REVIEW_TRACKS] and
[OUTPUT_OWNERSHIP]. Follow current worker profile/resource requirements.
Parent owns integration. Obtain independent correctness/complexity review.

For each prioritized finding provide: evidence/permalink, current behavior,
practical consequence, alternatives/uncertainty, bounded code/data change,
invariants, first real failing check, decisive acceptance and next gate.
Recommend incremental changes, not a speculative framework rewrite.

Finish the requested documents and summarize strongest findings, executed
evidence, blocked gates and exact next step. Audit completion is not game
implementation, human playability or standalone release acceptance.
```

## 6. Reusable implement-from-spec prompt

```text
Implement only [FINDING_IDS_AND_COHERENT_SLICE] from
[SPEC_PATH_AND_VERSION] in [PRIVATE_REPOSITORY].
Authorization/scope: [CURRENT_SESSION_AUTHORITY_AND_ALLOWED_DELIVERY].
Production ownership: [EXACT_FILES]. Test ownership: [EXACT_FILES].
Other active work: [PR_OR_BRANCH_IDS_AND_OWNERS]. Parent integration owner:
[NAME]. Do not edit overlapping/unrelated work or user saves.

Verify current HEAD/tree and compare with [ACCEPTED_BASE_SHA]. Read current
AGENTS.md, DESIGN.md, ARCHITECTURE.md and CHECKPOINT.md. Reconcile old
findings with actual code and inspect in-flight PRs, especially renderer/HUD
work, before editing. If the contract changed, identify the exact mismatch
and preserve completed useful work rather than blindly replaying old fixes.

Use an isolated branch/worktree and preserve rollback [SHA/ASSET_OUTPUTS].
Freeze desired behavior and measurement configuration before implementation.
First demonstrate [PRODUCTION_PATH_RED_ASSERTION] on unchanged source.
Retain exact failure evidence. Repair the smallest shared cause.

Desired contract: [USER_VISIBLE_BEHAVIOR_AND_BOUNDARIES].
Proposed functions/data: [LOCAL_INTERFACES_AND_SCHEMA].
Preserve: [DAMAGE/RANGE/COLLISION/INPUT/SAVE/ASSET/AUDIO_INVARIANTS].
Explicit non-goals: [SEPARATE_TUNING_AND_FEATURES].

For fire/controller changes define press/release/repeat ownership, commit
order, cooldown-unavailable taps, weapon choice, cached aim invalidation,
pause/focus/death/map cancellation and Resume release gates. Keep native
queries in physics. Preserve analog magnitude and immediate mouse look.
Cadence residual applies only during uninterrupted active repeat, never
idle/switch/pause debt. Bound hitch catch-up and keep weapon-local recovery.
Derive accepted-shot presentation age and readiness from one playing clock.

For aim/damage changes preserve direct center hits, finite reach, native
world/actor collision and truthful weapon-specific preview. Keep attacker
identity for infighting separate from actual hit/explosion geometry.
For persistence/preferences provide explicit backward-compatible migration,
strict finite validation and atomic acceptance across relevant envelopes.

For substantial visual changes obtain and inspect selected GPT Image
references first, retain originals and ensure each implementing worker
inspected the selected pixels. Derive editable Blender sources and compact
runtime assets with verified lineage. Do not bless helper drift by updating
pins without reviewed regeneration. Compare one visual variable at a time.

Required GREEN: [FOCUSED_TESTS]. Edge cases: [BOUNDARIES_AND_LIFECYCLES].
Required measured comparison: [FIXED_CASES_AND_SUCCESS_CRITERIA].
Retain [EXISTING_TESTS_AND_REASON]. Do not lower assertions, remove real
collision or substitute perfect-aim fixtures for human acceptance.

Obtain independent correctness and Ponytail review after the first passing
nontrivial change. Repair findings before broader tests. Follow current
worker profile/ownership/resource rules; verify actual telemetry claims.
Run affected native, GPU, physical-input, live-audio and packed-app paths
only where available. Label skipped gates and their exact resume step.

Inspect diff, explicit staged paths, whitespace, secrets and unaffected
assets before [AUTHORIZED_COMMIT/PR/DELIVERY_ACTION]. Sparse worktrees need
a full base index. Preserve eight maps, original art, eight offline live
MIDI scores, M4 targets and standalone app acceptance. A source milestone
does not complete those goals.

Report exact base/head, files changed, RED/GREEN commands/results,
independent review resolutions, measured benefits/tradeoffs, artifact hashes,
remaining limitations and next concrete gate. If blocked, checkpoint the
completed work and a precise reproducible resume action.
```

## 7. Independent review and resume prompts

### Review one candidate

```text
Review [CANDIDATE_SHA / DIFF] against [BASE_SHA] and [SPEC_CONTRACT].
Read current project instructions. This is independent review; edit only
[REVIEW_NOTES_PATH], with no source/PR/release mutation.

Trace actual production paths and relevant test fixtures. Check input
lifecycle, physics ownership, direct-center aim truth, actor/world masks,
finite reach, delayed-hit geometry, pause/map/callback guards, migration,
resource ownership and native/packed evidence boundaries. Inspect actual
pixels for any visual claims. Reconcile existing repaired safeguards.

Try to falsify each acceptance claim. Distinguish deterministic defects,
missing evidence, tuning hypotheses and deliberate tradeoffs. For each issue
give severity, permalink, concrete reproduction and smallest repair.

Perform a complexity pass: identify unnecessary state, duplicate queries,
frameworks/caches/timers and tests that merely mirror implementation.
Prefer existing local ownership and shared production paths. Do not propose
a broad rewrite without a demonstrated need.

Finish with blocking findings, nonblocking suggestions, tests actually
performed and exact evidence still needed. A clean source review is not
human playability, GPU quality, live-audio quality or release certification.
```

### Resume sustained work

```text
Resume NULL CHOIR from [CHECKPOINT_DOCUMENT] and [LAST_ACCEPTED_SHA].
Original goal: [GOAL]. Current authorized scope: [SCOPE].
Completed: [IMPLEMENTED_AND_VERIFIED_ITEMS].
Current candidate/in-flight work: [SHA/PRS/OWNERS].
Evidence achieved: [EXACT_TYPES_AND_RECEIPTS].
Remaining blocker: [MISSING_TOOL/PLATFORM/ACCESS_OR_FAILED_ASSERTION].
Next action: [ONE_CONCRETE_COMMAND_OR_TEST_AND_EXPECTED_RESULT].

Read current instructions, verify actual HEAD and preserve user work/saves.
Treat this as continuation. Do not restart completed analysis or infer new
release acceptance from old source receipts. Recheck only dependencies that
changed or a concrete remaining risk requires. Continue the authorized work
until the requested outcome is fulfilled or a precise blocker remains.
```

Keep these templates attached to the current specification, source identity and evidence receipts. A prompt cannot substitute for an actual selected image, a native failing assertion or an exact app artifact. Its purpose is to make the next coding task bounded, reviewable and reproducible.
