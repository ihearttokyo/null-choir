# NULL CHOIR — Major Feature Priorities

Updated: 29 October 2026 (JST)

This is the working checklist for the native Goal. Read it first, execute the highest-priority unfinished major block, and update its status and evidence as work progresses. Preserve accepted work; do not restart completed features or replace implementation with repeated planning.

## Goal

Deliver NULL CHOIR's remaining major upgrades through coherent v0.xxx releases: high-quality coherent title/chapter/runtime artwork with genuine native8K/editable masters; eight distinctive vertical levels with two exploration loops, seven tradition-inspired structures and two unique hero set pieces per level, meaningful routes/hazards/discoveries/revelations; in-game illustrated connected progression/interludes; rich live 1995-era pixel music artwork and accessible controls; the selected offline Suno soundtrack in its intended campaign/title/progression roles; differentiated weapon/projectile capabilities and scarcity, enemy/boss/difficulty/anatomical consequences and responsive combat; complete campaign continuity, checkpoints/save/Continue/lore/endings; and matching README/existing Site/released builds for every major upgrade. Reconcile delivered/partial/missing, preserve accepted work, prioritize genuinely major improvements, independently accept each feature at at least 9.2/10 unrounded, freeze it and deliver.

## How to check off work

- A checked **foundation** means that bounded existing scope is delivered; it does not complete its larger priority.
- A checked **major priority** requires intended-use evidence, independent acceptance and the matching delivered release. Source code, a merged PR, a concept image or an automated test alone is insufficient.
- Track evidence as **source/static**, **arranged native**, **rendered**, **packed/installed**, or **human**. A result in one category cannot substitute for another.
- Before a new feature's results, freeze its scope, weighted rubric, dimension floors, material-failure veto and required evidence. Independent acceptance must be at least **9.2/10 without rounding**. Keep numerical assessments private to reviewer/integrator; authors receive concrete findings or scoped PASS. No self-grading.
- Freeze accepted source/artifact/evidence identities. Reopen only for demonstrated material regression or a changed user requirement. Nonblocking polish goes to backlog.
- Do not mark the whole Goal complete while any required major priority remains unfinished.

## Where work lives

This tracked Markdown file is the source of truth for **what to do next and what counts as finished**. [AGENTS.md](../AGENTS.md) instructs agents to read it first; the [README](../README.md#development-status) exposes it to people browsing the repository. The native Goal points here rather than owning a separate backlog.

- **Requirements:** [DESIGN.md](../DESIGN.md), with current approved additions reconciled here. Do not silently weaken either; resolve material conflicts from the latest user instruction.
- **Implementation boundaries:** [ARCHITECTURE.md](../ARCHITECTURE.md) and linked feature contracts.
- **Current work, priorities and acceptance/release state:** this document. Keep the current work item below usable without chat history.
- **Historical reasoning and measurements:** dated plans, checkpoints and release notes. Read the relevant evidence, but do not revive stale status or restrictions.
- **PRs:** a review/delivery container for a coherent implementation, linked back to its priority ID. Use a draft PR once useful implementation/review work exists, not one placeholder PR per idea. Issues or project boards may later be views of this roadmap, not competing sources of truth.

### Maintenance during agentic loops

1. Read this file and reconcile actual source, branch, uncommitted work and evidence before choosing the next block.
2. Select the highest-priority meaningful unfinished scope; record its owner, candidate, required gates and next action. Delegate only bounded nonoverlapping work with this file and the priority ID in the packet.
3. Fold approved new ideas/requirements into the relevant stable item. Preserve the full scope; record unresolved decisions instead of quietly dropping them.
4. Update the current work item and acceptance/release row when implementation, evidence, blockers or delivery changes. Retain failed evidence and distinguish unrun checks.
5. Independently accept, freeze and deliver the coherent increment; only then check off its delivered scope and move forward. Do not create a new planning document as a substitute for implementation.

## Current baseline

- Public qualified release: [Null Choir v0.096](https://github.com/ihearttokyo/null-choir/releases/tag/v0.096), Developer ID signed, notarized, stapled and packed-resource tested. This is not full-goal completion.
- GitHub baseline: `a9679651df223dbe34465f27319bc59e2704326c`.
- Canonical working repository: `/Volumes/Backup (Biz)/Null Choir/repository`.
- Current branch: `feature/v0097-readable-pursuit-autorun`.
- Local candidate: **v0.097**, gameplay/test candidate commit `c5d2d62130e376bc0d2cf1d002d244e7ce1dfced`. Implemented but **not accepted, pushed, merged or released**.
- [Existing live Site](https://null-choir.jaymoney.chatgpt.site/) remains version14 matching v0.096. Do not recreate retired GitHub Pages or publish a duplicate Site.
- Historical project work, originals and temporary fixtures are preserved on the external drive with compatibility links. Installed user apps and saves remain untouched.

## Current work item — P01 / v0.097

- **Outcome:** readable ordinary creatures, faster role-specific pursuit/dodgeable lunges, automatic fast movement with **no slow-walk modifier**.
- **Owner:** lead/integrator; no implementation worker is currently active. Reconcile live worker state before delegating.
- **Candidate:** local branch `feature/v0097-readable-pursuit-autorun`, gameplay/test commit `c5d2d62130e376bc0d2cf1d002d244e7ce1dfced`. It has not been pushed or released; a fresh GitHub-main checkout does not contain these local fixes yet.
- **Evidence obtained:**270 arranged native movement cases, native collision/charge/dodge/pose checks,32 direction selections and local-light configuration checks. See the candidate notes and evidence locations below; these are not current rendered visibility acceptance.
- **Next action:** obtain current-source640×360 moving ordinary-threat visibility evidence in all eight chapters, including dark-pool transitions, near/mid views, occluded negatives, reduced effects and aggregate Mobile light cost. Preserve user window/input state and use isolated test profiles.
- **Remaining delivery gates:** affected recovery/save/art-consumer qualification, independent intended-use acceptance, coherent PR/required checks, actual signed/notarized package and matching README/same Site.
- **Known workspace detail:** nine normal editor-generated healing-machine `.import` sidecars are uncommitted. Preserve them and their recovery records; do not stage them accidentally or restore minimal descriptors and run without reimport.
- **Blocked?** No verified external blocker is recorded. Required rendered/build checks are unfinished work, not a PASS and not automatically a blocker.

## Execution order

1. Finish **P01**: the player-reported v0.096 visibility, pursuit/lunge and automatic-fast-movement fixes; qualify and deliver v0.097 before calling them shipped.
2. Advance **P02 and P03** as the next coherent major art/world block. Choose from actual source and rendered evidence, not catalog counts. Preserve the staged machinery work until it can meet its own contract.
3. Close substantive gaps in **P04–P08**, reusing delivered foundations and unaffected evidence.
4. Apply **P09 and P10** to every affected increment. Deliver each accepted major block, then continue to the next; do not endlessly polish a passing feature.

---

## [ ] P01 — Readable threats, frightening pursuit and automatic fast movement

**Status: implemented locally; qualification and delivery open. Highest immediate priority.**

- [x] v0.096 provides eight directional enemy/boss runtime bodies, role-specific attack tells, earned seal bearers and exit wardens.
- [x] v0.096 provides Doom-inspired acceleration, friction, momentum and native collision/slide foundations.
- [ ] Deliver automatic fast movement with **no slow-walk modifier**. Shift, the legacy run binding and its controller equivalent must not slow the player. Preserve analog strength and existing input/pause safety; keep old serialized preferences compatible without advertising an obsolete control.
- [ ] Keep ordinary creatures readable when they leave fixed light pools. Preserve shaded original artwork, alpha/hit coverage, local darkness and depth/occlusion; no global fill or fullbright replacement.
- [ ] Deliver faster role-specific pursuit and genuinely fast, readable, dodgeable lunges. Preserve locked aim, wall/ground collision, finite reach, one contact per charge, recovery and distinct ranged/summoning roles.
- [ ] Inspect moving current-source output at640×360 across all eight chapters, near/mid distance, dark-pool transitions, occluded negatives and reduced effects. Measure aggregate Mobile lighting cost; do not infer sustained FPS.
- [ ] Qualify affected recovery, saves, combat/art-consumer contracts and the actual portable build; independently accept and deliver through P10.

**Evidence already obtained, not final acceptance:**270 arranged native movement cases with legacy modifier held/released; native slide/corner checks; real crawler AI contact/dodge/wall-stop/full-charge-pose checks; brute/Warden grounding and shared finite charge-lane checks; ordinary enemy telegraphs; enemy damage/infighting/death;32 atlas-direction selections. Headless fixed-clock evidence is not rendered visibility or human feel. Light configuration/ownership checks are not pixel acceptance. Failed attempts and their diagnoses remain retained.

See [player-fix candidate notes](POST-V0096-PLAYER-FIXES.md).

## [ ] P02 — Coherent title, chapter and runtime art with true native8K/editable masters

**Status: runtime foundations delivered; native8K/master-source requirement unproved.**

- [x] Title and eight chapter paintings are consumed in-game at their actual delivered resolutions.
- [x] Directional runtime bodies, the corrected forward Rivet Pistol, eight living thresholds, dimensional wall families and healing-machine families are delivered in their accepted scopes.
- [ ] Reconcile genuinely sub-rubric title/chapter/runtime artwork into a coherent production direction without regenerating accepted assets unnecessarily.
- [ ] Deliver genuine native8K chapter masters and matching editable/native or Blender authoring sources. A small raster upscale, concept sheet or loosely matching design companion does not satisfy this requirement.
- [ ] Generate and inspect selected references before substantial new art authoring. Retain actual outputs, originals, provenance, editable scenes, textures and export recipes.
- [ ] Verify compact runtime derivatives against their actual consumed pixels, framing, animation and gameplay size. Never ship authoring masters as runtime textures unnecessarily.
- [ ] Independently accept the art in actual use and deliver the matching package and public presentation.

## [ ] P03 — Eight distinctive vertical worlds with meaningful machinery and route consequences

**Status: topology and asset-count foundations delivered; deeper purpose, staging and consequences partial.**

- [x] All eight chapters already have two authored closed exploration loops, two unique hero IDs and seven tradition-associated constructions; elevation, seals, discoveries and return encounters exist.
- [x] Eight volumetric wall families and living gates are delivered. They are not eight wholly rebuilt maps.
- [ ] Qualify each chapter's distinctive visual identity and purposeful staging, not merely its asset count or recolored props.
- [ ] Give each loop a memorable, genuinely unique hero experience; retain/edit actual Blender sources where new articulation or geometry is required. Do not animate material-merged runtime meshes as though they were semantic mechanical parts.
- [ ] Add meaningful route choices, readable hazards, safe alternatives, discoveries and revelations tied to the restraint machinery. Avoid unavoidable damage, seal-order dependencies and supply softlocks.
- [ ] Preserve both Blood→Ivory and Ivory→Blood routes, real floor/roof support, navigation, collision, checkpoints, discoveries and finite recovery resources.
- [ ] Demonstrate both loops and their consequences in actual player-height moving output, then independently accept and deliver.

Seven aesthetic directions: Christian, Buddhist, Shinto, Islamic, Hindu, Jewish and ancient Egyptian. Model recognizable structure, chapter-specific purpose and intentional staging. A hero may fulfill a tradition category when its actual design supports it; seven additional unrelated assets are not required. The fictional manipulation is the antagonist, not a real religious community.

| Chapter | Existing hero anchors to preserve/deepen | Major world acceptance |
|---|---|---|
| Intake | Skin bell; siphon heart | [ ] |
| Foundry | Vertebral furnace; marrow crucible | [ ] |
| Processional | Walking bone organ; ossified palanquin | [ ] |
| Reliquary | Face halo; memory wheel | [ ] |
| Nursery | Gestation engine; seed orrery | [ ] |
| Ossuary | Rib bridge; bone mandala | [ ] |
| Inversion | Surgical cradle; tilted gyroscope | [ ] |
| Heart | Mouth restraint; pulse mandala | [ ] |

**Preserved candidate:** the16-apparatus “The Restraint Answers” machinery tranche has source, pure-logic and arranged-physics work. It is **unaccepted, not integrated and not part of v0.097**. Reuse it only after current-source recheck and actual world/readability/recovery evidence. Do not mistake four hazard templates or a static placement test for completed world identity.

## [ ] P04 — Illustrated connected progression and interludes inside the game

**Status: delivered foundation; full journey/completion qualification partial.**

- [x] An illustrated connected descent chart and unlocked chapter interludes exist in-game, not only on the website.
- [ ] Reconcile any remaining major gaps in connection, chapter identity, unlock/completion states and ending presentation.
- [ ] Exercise progression through real transitions, Continue and checkpoint recovery, including accessibility/focus and retained lore states.
- [ ] Independently qualify the full intended journey and deliver any required substantive improvement. Do not rebuild the existing chart merely to add illustration counts.

## [ ] P05 — Rich live1995-era pixel music artwork and accessible controls

**Status: accepted Pixel Music Garden delivered; broader major gaps must be demonstrated.**

- [x] The original cute, crisp16-color live Pixel Music Garden, transport, variants and real Music-bus band response are delivered.
- [ ] Reconcile any genuinely missing major music-responsive experience without replacing accepted art with a smooth generic visualizer or inventing a scene-count requirement.
- [ ] Preserve accurate playback ownership, transport, volume, focus, pause, settings and reduced-motion/reduced-effects behavior.
- [ ] Verify accessible keyboard/controller/remapped controls and readable HUD/settings in intended use. Include P01's removal of any movement modifier.
- [ ] Independently accept and deliver any substantive extension; otherwise retain the frozen foundation rather than polish it indefinitely.

## [ ] P06 — Selected offline Suno soundtrack in the intended campaign roles

**Status: eight selections and role playback delivered; listening/perceptual fit incomplete.**

- [x] Eight selected recordings play offline; title uses the selected Processional recording and interlude/completion uses Heart. Original recordings, MIDI and editable composition sources are preserved.
- [ ] Reconcile the actual title, eight campaign, interlude and completion roles, switching, repeat boundaries, pause/resume, restart, volume/mute and ownership in the current build.
- [ ] Audition the recordings and transitions for actual musical fit and audible seams. Technical playback checks cannot establish unheard music quality.
- [ ] Verify the standalone package needs no host conversion tools or online playback dependency. Do not generate redundant songs merely to increase counts.
- [ ] Independently accept the remaining role/fit work and deliver; keep human listening distinct where still unrun.

## [ ] P07 — Differentiated arsenal, scarcity and authored combat consequences

**Status: substantial v0.096 systems delivered; encounter-level qualification and broader consequences partial.**

- [x] Six weapon/effect families, finite carrier-earned equipment, partial-capacity pending drops, walk-over loot/seals and32 finite Space-operated healing points are delivered.
- [x] Worker pressure-clutch and Nursery Warden front pressure-node mechanics are delivered within their authored scopes. They are not universal headshots or general anatomical hitboxes.
- [ ] Reconcile meaningful projectile/hitscan speed, range, spread, bounded per-shot variation, cadence, penetration/splash/stagger and tactical capability differences through real near/mid/far encounters.
- [ ] Validate inverse-power ammunition scarcity and sustainable guaranteed prefixes across both seal orders, all difficulties, low carryover, misses and zero optional supplies. Do not count a victim's own drop as ammunition available to defeat it.
- [ ] Extend enemy/boss/difficulty/anatomical consequences only where authored visible anatomy, collision and readable state support them. Preserve directional coverage, meaningful seal/miniboss fights, fairness and responsive feedback.
- [ ] Preserve finite partial/pending stock, save/Continue/checkpoint semantics, one-shot grants, useful-only automatic collection and deliberate finite environmental healing. No arbitrary floor supplies, farming, regeneration or reloading.
- [ ] Exercise current actual encounters and affected recovery/accessibility; independently accept and deliver without reopening frozen artwork absent a demonstrated regression.

## [ ] P08 — Complete campaign continuity, recovery, lore and endings

**Status: campaign systems and retained completion runs exist; complete current-context qualification partial.**

- [x] Eight maps, progression, checkpoint/save/Continue, optional records and two endings exist. Retained earned runs cover bounded earlier campaign combinations, not every current route/difficulty.
- [ ] Reconcile real current route continuity, including old Blood/Return concerns only if current evidence still reproduces them.
- [ ] Validate earned campaign traversal, checkpoint restoration, death/restart, save failure, Continue, lore ownership and ending selection on the current release composite.
- [ ] Preserve existing saves, all resource envelopes, finite grants/depletion and legacy migration. Reject malformed state atomically without corrupting current progress or user files.
- [ ] Evaluate actual pacing and balance against the intended first-play experience; keep the75–100minute campaign and8–12minute chapter targets labeled targets until measured.
- [ ] Independently qualify and deliver the complete intended campaign. Arranged fixtures cannot be relabeled earned full-campaign success.

## [ ] P09 — Moody local illumination, performance and intended-use evidence

**Status: local lighting delivered in scoped v0.096 contexts; reported visibility regression and broader performance evidence open.**

- [x] Local non-ray-traced practical illumination and dark negative space are delivered foundations.
- [ ] Keep threats, navigation, machinery, loot, healing and attack tells readable without blanket ambient fill. Qualify P01's ordinary-actor fix and overlapping lights at actual640×360.
- [ ] Measure relevant frame cadence, memory and load behavior on native hardware after affected changes. Do not infer sustained FPS from headless, fixed-clock, static or screenshot checks.
- [ ] Keep human physical-input feel, listening and first-play pacing explicitly separate from automated evidence. Seek/record human evidence where needed without blocking unrelated qualified increments.
- [ ] Preserve fresh memory/disk admission, serialized heavy native/render/build jobs and unrelated app/window states. Blender runs background CLI only. No paid/account/runner fallback or resumed unrelated retrieval holds.

## [ ] P10 — Coherent releases, actual builds and matching README/Site

**Status: v0.096 complete; v0.097 and subsequent upgrades not delivered. Applies to every accepted major increment.**

For each major release:

- [ ] Allocate the next identity through `docs/build-iterations.json`; use **Null Choir v0.xxx** consistently. Never reuse a failed issued ordinal or advance for packaging/test-only retries.
- [ ] Bind the accepted scope to exact source, runtime assets and evidence. Finish independent review and material findings; retain rejected attempts honestly.
- [ ] Batch a coherent PR. Before a CI trigger inspect scope, exact-SHA results and expected cost; preserve protections, resolve substantive review findings and merge SHA-bound. No skip/status tricks, unchanged-failure reruns without diagnosis or paid fallback.
- [ ] Produce and test the actual self-contained Apple Silicon package, including all affected chapter/art/audio/save contracts and offline resource consumption.
- [ ] Verify Developer ID signing, notarization, stapling, system checks, archive identity and actual downloadable bytes. A source merge or signing-only milestone is not a delivered build.
- [ ] Update the repository README, release notes and **same existing Site** with truthful player-facing copy and actual captures matching the qualified package. Preserve its public audience and rollback URLs.
- [ ] Retain originals, editable masters, audio, user saves, recovery history and previous releases. External notifications require their own exact authorization; do not resend the completed v0.096 Angus notification.
- [ ] Freeze the passing increment, update this checklist and continue the next major priority.

## Working acceptance and release register

Add one row per coherent major block; retain links to exact evidence. Mark a parent priority complete only when all its required scope is delivered.

| Block | State | Exact source / evidence | Next action |
|---|---|---|---|
| v0.096 accepted foundations | Delivered; scoped, not whole Goal | [Release notes](releases/v0.096.md); public release above | Preserve; reopen only demonstrated affected regressions |
| v0.097 readable pursuit / automatic fast movement | Implemented, partially native-tested; not accepted/released | `c5d2d62130e376bc0d2cf1d002d244e7ce1dfced`; external `work/behavior-checks/`; [candidate notes](POST-V0096-PLAYER-FIXES.md) | Current rendered all-chapter visibility/resource checks, recovery/compatibility review, independent acceptance and matching release |
|16-apparatus machinery tranche | Staged; unaccepted, not integrated | External `work/local-lead-20261029/chapter-consequences/` | Recheck exact candidate and qualify real world/route consequences before promotion |
| Native8K/editable chapter masters | Unproved | Existing paintings and originals retained | Inspect selected references; author true masters and consumed derivatives |

## Resume notes and source references

- [Design requirements](../DESIGN.md), [architecture](../ARCHITECTURE.md), [historical major-upgrade plan](MAJOR-UPGRADE-PLAN-2026-10-26.md), [earned-arsenal contracts](EARNED-ARSENAL-IMPLEMENTATION.md).
- Current operational checkpoint: `/Volumes/Backup (Biz)/Null Choir/work/CURRENT-STATE.md`. Raw private evidence and numerical reviews stay outside public Git.
- The native import currently has nine generated healing-machine `.import` sidecars uncommitted. They are known derived editor remaps, not permission to stage unrelated changes. Restoring minimal authoring sidecars requires normal reimport before native game loading; preserve the diagnosed failure and generated-sidecar records.
- Full access is active for the lead; no additional access setup is requested. Respect actual tool/security boundaries, and do not revive aborted stale child approval calls. Preserve the selected lead model/tier and current permissions; no silent capacity/model/billing substitution.
- The old plan contains superseded time-of-day/model/status text. Current user authority and verified release facts take precedence; do not resurrect retired holds, old one-shot grants or already-completed consultations.
