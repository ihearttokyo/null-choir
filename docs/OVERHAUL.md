# Integrated gameplay overhaul

Jared requested a major improvement pass on 2026-10-02 across gameplay loops,
music, level design, ammunition use and HUD presentation. This pass continues through the eight-map campaign and private project/app delivery. The full eight-level scope in
[DESIGN.md](../DESIGN.md) remains required.

## Value and acceptance

All eight maps should reward reading an attack, interrupting or evading
it, choosing an appropriate weapon and using the return route. Their music
should develop recognizable original material rather than repeat an unchanged
arrangement. The recovery instrument should communicate survival, arsenal and
seal progress without obscuring the world.

More enemies, props, notes or tests do not establish improvement. Acceptance
combines deterministic contracts with actual native encounters, navigation,
audio captures and visual inspection. Musical taste, pacing and control feel
must be reported as observations, not inferred from structural counts.

## Image-first creative production

Jared's 2026-10-02 correction applies immediately to every owned section and
future model. Before creating or revising visual assets, level/character/weapon
design, UI, set dressing or procedural art/lighting, generate an ambitious GPT
Image reference, inspect and refine it, then give the actual pixels to the
implementing model. A prompt summary alone is not a handoff. Derive editable
Blender or native digital assets from the selected image and compare their
rendered result with it. Preserve source references and existing performance,
accessibility and mechanical contracts. Examples establish a minimum bar;
they neither prescribe the design nor limit ambition.

The selected [master reference](../source/art/references/overhaul-01.png) grounds
the organ, ossuary cover, cold/amber light hierarchy, enemy charge, scattergun
and thin recovery instrument. Request further actual views when a specific
asset needs them. Existing pre-reference drafts remain provisional and must
be reworked, not retroactively declared image-first. Images guide musical mood
but cannot prove heard quality or gameplay acceptance.

The separate visible Codex task `01a0fb9c-84ca-7612-8c0a-c72911770e50` owns
the global instruction update and evidence-backed stopping audit. Do not race
its source/install edits from this game task.

## Owned improvements

- **Gameplay:** anticipation, committed aim and recovery distinguish crawler
  rushes, worker firing lanes and caster artillery. Eligible counters cancel
  attacks; a refractory interval prevents pellet-driven permanent stagger.
  Preserve collision, infighting, fixed difficulty, pause and scene lifetime.
- **Ammunition:** one central scattergun assistance decision followed by
  distinct rays, close-range strength and distant falloff; weapon-local
  recovery; explicit empty-fire feedback and safe fallback. Bounded reserves
  make supplies useful. Full pickups remain available; valid older over-cap
  saves are never truncated.
- **Level design:** author landmark encounters, retreat/flank choices,
  seal-conditioned returns and purposeful resources in Intake, Foundry and
  Processional. Preserve two loops and both original Blender heroes per map,
  safe entries, no-jump traversal and optional stories. Extra loops require
  extra original heroes.
- **Music:** develop all eight original scores with melodic answers, changed
  bass routes, rests, harmonic variation and per-score mixes. A restrained
  combat-pressure mix uses one live MIDI player and the existing soundbank,
  without restarting transport or changing difficulty.
- **HUD/UI:** an original ivory-and-copper recovery instrument presents
  truthful vitals, armor, selected weapon, arsenal readiness, required seals,
  current objective and specific interaction prompts. Maintain the 640×360
  view, readable center, motion options, native focus and rebinding.

## Integration boundaries

Five named CLI tasks use gpt-6.1-sol, xhigh and requested default service tier.
The parent verifies actual headers and task IDs, starts read-only exploration,
then resumes each task with explicit nonoverlapping ownership. Actual service
tier and native parent linkage may remain unavailable; that is not an approval
blocker. Keep at most two active children during this pass and serialize native
jobs. Observe memory and swap before expanding work.

Gameplay owns `enemy.gd` and `projectile.gd`; ammunition owns `player.gd`;
level design owns map JSON and level scripts; HUD owns `hud.gd`; music owns
its runtime, editable scores and generated MIDI. Each owns its narrow new
acceptance test. The parent owns `main.gd`, campaign integration, feedback,
existing integration-test adaptations and delivery.

Weapon profiles remain authoritative for capacity and low-ammunition thresholds.
Campaign state remains authoritative for inventory and restoration. HUD derives
its presentation from those sources and never changes them. Enemy damage keeps
its existing two-argument boundary. Optional enemy events carry windup, attack,
stagger and death feedback; old test fixtures need not implement new callbacks.

Music adds `set_pressure(value: float)`, clamps finite values to zero through
one, smooths attack/release, freezes during pause and reapplies after repeat.
Only internal expression gains change; user Music bus volume and mute remain
independent. The parent derives pressure from nearby living, active, alerted
actors pursuing the player: a quarter per threat, capped at one. Actual damage
adds a bounded transient floor. Dormant, dead, distant, wrong-map and infighting
actors do not inflate the mix. This fixed sensor changes neither difficulty nor
the MIDI transport.

Authored encounters use stable `id`, cell-space rectangular `region`,
`enemy_ids`, optional required seals and a cue containing text/light IDs/sound.
This array is the sole authored group-membership source. The parent derives
each enemy's optional `encounter` configuration from it. Activation persists
as `encounter:<id>` in existing removal strings; it means activated, not cleared.
Dormant enemies remain vulnerable, and damage can activate their whole group
independently of region requirements. Required seals gate region activation.
Level `apply_encounter_cue(spec, restoring)` restores lighting without replaying
transients. Hero seal/light associations support a persistent machine-state
change after recovery, without new save fields or collision approximations.

## Evidence and rollout

Verified starting point is `main@c25d0bc`; the private 0.1.3 application remains
the unchanged rollback build. First prove each intended failing behavior before
production changes. Review correctness and Ponytail after first GREEN, then
rerun affected checks and representative real paths. Keep failed evidence.

Parent menu wrapping, authored focus treatment, bounded rows and related native
preference/control/save-error contracts already pass. The ammunition-capacity
test has proved the intended RED. These do not constitute completed overhaul
acceptance. [CHECKPOINT.md](../CHECKPOINT.md) owns current process and Git state;
raw receipts remain outside Git under the parent task's `overhaul-01` directory.

Deliver the integrated editable project and exact tested Apple Silicon app to
the verified private repository only after all five areas are integrated. Do
not publish isolated untested worker outputs or ask for routine reapproval.
Physical-controller, listening, full playthrough, precise packaged performance
and notarization gates remain open until their own evidence exists.

## Current integrated evidence

All eight maps are registered, and native set/scenery/traversal checks pass.
Fifty-six religious-inspired Blender pieces are installed, seven per level;
92 assets and 93 exports have verified native provenance and editability.
Actual late-level input checks cover clues, seals, gates, resources, checkpoints,
death, exact Continue/restart and live CoreAudio PCM. Eight new weapon/role/boss
assets and behavior fixtures supplement the original arsenal and actors.
The five late roles pass six bounded-ammunition boss fights and 15 old gameplay
regressions. Actual boss descent gates, standard/alternate endings and completed
Continue pass. The selected boss-hud-01.png reference now drives a native HP/phase
instrument, with ten regressions and six inspected M4 state images.

Sixteen actual late-map images still expose generic ceilings and underfilled
vertical space. The selected world-polish-late-01.png reference drives four
bounded editable atmosphere modules. Native sources/exports, reopen/edit checks,
embedded Godot imports and thirty-two central overhead mounts pass. Sixteen new M4
views were inspected after rejecting a sparse peripheral arrangement. A spatial
wall-kit batching candidate passed geometry and image safeguards but failed paired
frame-rate gates, so the original renderer is restored. Twelve authored regular-role
replacements preserve IDs, positions and resources; all 24 native difficulty/seal-order
cases and conservative source budgets pass. Final visual acceptance, full playthrough,
heard music, physical controls and final packaged performance remain open. A fresh
0.2.0 arm64 ZIP passes all eight packed scenes/live MIDI/late weapons/actors and
strict development-signature checks. Isolated live menus/rebinding/mouse fire and
checkpoint recovery pass without changing primary user data. Dense all-cohort
M4 stress samples expose sub-60 FPS late views; warm transitions stay below 288 ms.
The older private v0.1.3 app is rollback evidence and cannot stand in for current
delivery. The private v0.2.0-dev eight-level preview is published at implementation commit 88a5faa; its downloaded ZIP passes native checks. Final overhaul acceptance remains open.

The OpenGL stress failure prompted an installed native renderer comparison, not
reduced scenery or shadows. Six serial C/T runs pass all thirty Metal samples at
141–181 FPS, with all ten cases above the noise-aware improvement gate. Sixty-four
matched native images preserve the authored look, and seventeen native safeguards
pass. Three project selection/metadata lines now use Mobile/native Metal; the
rebuilt standalone passes all packed checks and live current-app menu/settings, stock Escape pause, fire, death, recovery and persisted Continue. Primary user data stays unchanged. Initial first-frame timing still fails at 5.94 seconds. Partial native shader baking also misses the three-second target; no export change is promoted. Full Metal compilation requires Xcode and its Metal Toolchain, and installation needs administrator authentication. Independent delivery preparation continues. A fresh source review also reproduced
zero damage on a direct marrow hit to a tall boss cap. Splash-only filtering now
excludes direct colliders; six real cap impacts across all difficulties deal
110 once. Original covered-splash, self-damage and lifetime assertions stay intact.

Eight complete native MIDI-loop recordings, each including six seconds of the
repeated intro, now pass real CoreAudio/nonzero/repeat/zero-discard/zero-clipping
checks. They do not establish heard musical quality. The exact published app
also passes one controlled live Heart stress case at production vsync: six whole
one-second samples at 60 FPS, real active enemies, inspected images, stock Escape
pause and a surviving isolated save. Cold startup, full campaign playthrough,
held physical controls, gamepad and listening acceptance remain open.
