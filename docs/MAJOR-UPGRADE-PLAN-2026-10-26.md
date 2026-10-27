# NULL CHOIR — next major upgrade series

Plan dated 26 October 2026; status updated 27 October 2026. Public baseline: Major Features Preview06.1; immediate rollback: Preview06. Preview06.1: the matching signed/notarized/stapled Apple Silicon archive is publicly available and locally installed; the broader major-feature goal remains in progress. This plan preserves the full major-feature goal, distinguishes shipped work from working/prototype work, and prioritizes changes a player will actually notice.

## Current goal update — 27 October 2026

These user-directed requirements supersede the old naming of future previews. They are major release requirements, not optional polish. The previously stated campaign, music, artwork/master-source, world-identity and delivery goals remain in scope.

### One release identity

- Name every **new** release **Null Choir v0.xxx** throughout the game display, macOS app/version metadata, archive, README and existing live Site. Do not add Alpha/Major Features/Preview suffixes to new release names.
- The retained Git audit establishes **93 distinct committed production-source states**, including branch development, through `3a3c353`. This is not a provable lifetime count of uncommitted work or 93 exported builds. Seed the reproducible iteration ledger at93; the next reserved candidate is **Null Choir v0.094**. `docs/build-iterations.json` governs subsequent allocation. Never use PR numbers, duplicated tags, test runs or identical-source packaging retries to inflate the number.
- Preserve old release names, URLs, source history and rollback packages. Preserve the internal save-data namespace and bundle identifier; display-name cleanup must not lose Continue progress.

### Seal-bearing wardens on every level

- Blood and Ivory seals must come from stronger characters, not unguarded floor pickups. Preserve independent seal-route choices with two identifiable seal bearers per chapter; every exit must also have an actual strong door guardian, using an existing suitable boss/actor where possible rather than adding unnecessary spawns.
- Give these fights names, clear attack preparation/recovery and visible seal identity. Strength must not mean only a large HP increase. Balance against the chapter's existing ammunition, health and difficulties.
- Defeating a bearer produces a reachable seal from its corpse. A living bearer cannot be bypassed through the old key interaction. Defeat, dropped-but-uncollected, one-seal and both-seal states must survive checkpoint/save/Continue without duplication or lost drops.
- Validate backward-compatible typed drop state/migration. Grandfather legitimate old collected seals and old legal exit clearance; do not reset campaigns or turn formerly valid saves into softlocks.

### Walls as architecture, not single planes

- Give all eight chapters genuine three-dimensional wall families: deep bays/niches, layered returns, buttresses/ribs, frames and distinct structural silhouettes appropriate to each place. Texture swaps or tint-only variants do not satisfy this requirement.
- Rendered volume, collision and occlusion must agree. Preserve door/gate openings, both loops, spawn/actor clearance and discoveries. Deep recesses must not create unsupported/out-of-mask standing or save positions, including falls from elevated Foundry/Ossuary surfaces and sloped edges. Use real visible structural barriers or an explicit supported geometry/migration change, never an invisible front wall.
- Batch/reuse geometry/materials where appropriate. Qualify actual player-height output at640×360 and relevant traversal/physics, not just static mesh counts.

### Arsenal, earned supplies, movement and horror lighting — user expansion, 27 October 2026

These are unfinished **major features**, not optional polish or claims about the currently shipped build. Carry them through the next v0.xxx increments without dropping the existing wardens/walls/campaign/art/music scope. Integrate coherent increments; do not hold an otherwise qualified release for endless unrelated bug checks.

#### Exciting, differentiated weapon behavior

- Author an explicit capability/ballistics matrix for every weapon: projectile or hitscan model, travel speed where applicable, effective range, spread growth with distance, bounded per-shot direction/velocity/pattern variation, cadence, impact/stagger, penetration or splash where intentionally supported, ammunition cost and tactical strengths/limitations. Do not make every gun the same ray with a different damage number or invent arbitrary travel time for intentional hitscan weapons.
- Make discharge and flight/impact artwork exciting and visibly different: varied muzzle frames, projectile silhouettes/trails, impact material responses and constrained per-shot visual variation. Maintain legible aiming, truthful collision/hit coverage, the corrected pistol alignment and accessible flash/reduced-effects settings. Cosmetic variation must not falsely advertise damage or hit coverage.
- Judge meaningful capabilities through actual encounters at near/mid/far distances, not only a numeric table or effect screenshots. Exercise deterministic seeded combat controls and bounded variability separately; save/reload must not reroll rewards or enable resource farming.

#### Earned supplies and a deliberate ammunition economy

- Remove arbitrary freestanding ammunition, weapon and health pickups from authored levels. **Monsters are the source of dropped items**, including the existing seal bearers; no universal identical loot table. Use authored enemy-role/chapter/difficulty loot profiles with visibly plausible rewards. Not every kill must drop an item, and not every monster carries every ammunition type, weapon or healing item.
- Make available ammunition inversely related to effective weapon power: powerful weapons have rarer supplies and meaningful opportunity costs, while weaker/core tools remain sustainably useful. Measure expected effective damage/capability supplied per encounter and chapter, plus guaranteed critical-route minimums, rather than correlating raw bullet counts across incomparable weapons. Balance both seal-route orders, all difficulties, missed shots and checkpoint/Continue. Avoid an unlucky-drop ammunition softlock; guarantee necessary earned supplies on designated encounters and retain a viable fallback attack.
- Prefer **healing exclusively from identifiable in-world assets activated with Space** for the first implementation: clinical stations, organic reservoirs or other chapter-specific fixtures with an understandable source and depletion state. No routine health-potion confetti from monsters. Any exception must be explicit, narratively justified and evaluated rather than silently restoring random floor potions. Persist usage; checkpoint/save/load must not duplicate loot or refill depleted assets unexpectedly.
- Dropped items are collected by **walking over them, never requiring E or another use press**. Automatically collect useful available quantities, with clear feedback; do not consume an unusable full-capacity reward. Cover fast movement/swept contact, vertical floors, walls/closed gates, corpse reachability, inventory limits, duplicate events and save/Continue. Do not magnetically collect through walls or between stacked floors.
- Space operates contextual assets and other deliberate use actions, with controller/remapping equivalents and accurate prompts. Audit existing jump/use bindings before changing defaults so one Space press cannot both jump and drain a healing station; keep pickup collection wholly independent of contextual use. Existing input-provenance protections remain meaningful for deliberate use, not an excuse to retain press-to-pick-up loot.

#### Doom 1-inspired movement architecture

- Rework movement pace, acceleration, momentum, friction/deceleration, turning and collision/slide response to closely mirror Doom 1's feel, not merely increase top speed. Inspect the original released source as the reference and explicitly document world-unit/timestep conversion and any deliberate vertical-level adaptations; do not claim exact Doom parity from intuition.
- Establish reproducible start/stop, turn, strafe/diagonal, wall-slide and narrow-door traversal traces at several render rates with stable physics. Test both slow exploration and fast combat, stairs/slopes/upper decks, keyboard/controller input, safe save positions and the new volumetric walls. Distinguish automated traces from physical human feel evidence; do not claim human acceptance under a held input test.

#### Localized, moody horror illumination

- Remove global ambient/directional fill and uniformly lit enemies/rooms. Use non-ray-traced, chapter-authored local accents: practical lamps, emissive apertures with actual local illumination, machinery, ritual fixtures and restrained transient weapon/impact lights. Darkness and partial creature silhouettes must be intentional; not every space or monster should be perfectly revealed.
- Author light placement, falloff, color and shadow budgets together with routes/architecture. Preserve readable threats/telegraphs, required paths, seals, doors, healing fixtures and accessible brightness/contrast controls without restoring blanket global fill. Do not count an emissive texture alone as a light source or claim ray tracing.
- Validate actual player-height moving output in all eight chapters and combat at the intended low resolution, including dark enemies against dark backgrounds, muzzle flashes, reduced-effects settings and overlapping local lights. Measure bounded native resource use; sustained performance/listening/heavy-production holds remain separate and unclaimed.

#### Implementation order and acceptance evidence

Implementation packet: `docs/EARNED-ARSENAL-IMPLEMENTATION.md` records the measured current eight-chapter supply baseline, six-weapon matrix, proposed earned-supply budgets and explicit legacy-save migration. Proposed budgets are untested, not a balance acceptance claim.

1. Finish the already implemented wardens/walls candidate's affected native validation; retain exact accepted art and source history. Do not silently call its old pickup or lighting behavior compliant with this expansion.
2. Inspect current weapon, pickup, input, movement, save and lighting seams; establish the existing behavior and a concrete capability/economy matrix. Batch ownership around these coupled systems rather than competing writers in Main/Player/level data.
3. Implement weapons plus monster loot/walk-over collection/contextual healing as a coherent gameplay increment with backward-compatible persistence. Follow with movement and authored local lighting, or combine when evidence and ownership make that more efficient. Allocate v0.xxx numbers through the existing ledger; no speculative release numbering.
4. Independent adversarial review uses the existing private unrounded9.2 stopping bar, with concrete intended-use evidence for combat distinction, supply sustainability, collection/recovery, movement and horror/readability. Authors receive defects/PASS only. A score cannot average away a softlock or false hit/lighting claim. Freeze passing features; publish matching qualified build, README and current Site per delivered major upgrade.

### Acceptance and delivery

The accepted Bodies artwork and corrected pistol are retained foundations, not reasons to reopen art polish. Their old source-context receipts remain historical when gameplay/level sources change; qualify the affected new composite honestly. Independent adversarial intended-use review retains the9.2/10 unrounded stopping rule, with scores hidden from authors. Merge coherent source increments with required checks, then deliver the matching signed/notarized **v0.xxx** app/archive and update README/live Site. The old unpublished Preview07 packaging attempts are held as history, not the new release target. Heavy-work holds and established cost/storage safeguards remain in force.

## What is already established

- The eight-map campaign, two authored loops per map, seals, discoveries, checkpoint/Continue and two endings exist. Retained fresh earned runs cover a current default Blood-first recordless normal ending and a separate earlier Nightmare Ivory-first all-records revelation. This is not six current campaign combinations, human play or a performance certification. Do not reopen that matrix for cosmetic changes.
- The connected illustrated descent chart, unlocked chapter interludes, title/eight selected chapter paintings, eight offline Suno tracks and title/interlude selections are in Preview04. Originals are retained. The current paintings are **not** true native8K or editable Blender remakes; that source-master requirement is still open.
- Six differentiated weapons, six regular enemy roles, two bosses and difficulty logic exist. Current runtime atlases already have eight directions and five poses; committed telegraphs, a combat-visual-state seam and ordinary-hit interruption also exist. The upgrade is production-quality runtime artwork, richer readable state expression and deliberately authored physiology—not rebuilding missing direction/state systems. Visible-sprite alpha hit coverage is implemented; anatomical regions/headshots/boss weak points are not interchangeable with that feature.
- All six production-directed raster weapon atlases shipped in Preview05 with matching editable Blender design companions and remain retained. Preview06.1 makes one narrow, accepted exception: a genuine native-rendered forward-aiming Rivet Pistol replaces only the index1 runtime asset binding. The other five weapon designs remain frozen; numeric combat profiles, cadence and original lineage are unchanged.
- Retained Preview06 keeps the earlier SoundTest. Preview06.1 ships an original live, cute 16-color pixel garden on the same transport with real owned-playback motion and measured Music bands. Earlier cathedral-room experiments remain separate rejected history, not the shipped pixel artwork. Standalone qualification/publication must still match the frozen candidate.

## Preview07 source candidate — Bodies and Consequences

The next source candidate now contains eight independently accepted production atlases: eight directions, five base poses per role, plus an authored sixth pressure-vent pose for Worker (328 cells total). The final Enemy constructor selects these normal imported resources; legacy artwork and editable originals remain retained. The Worker pressure clutch uses visible geometry-authored hit regions: a qualifying direct hit opens a once-per-life vent/interruption, without a damage bonus or shortened attack cooldown. This is not a general anatomical/headshot system for every enemy.

Qualification includes all-frame source/import identity, the existing full static-art matrices, 555 functional checks with real Worker contacts, and eight visible final-source idle contexts with independently verified hidden/visible pixel contribution. The first added eight-camera fixture produced wall-only images and was rejected; its functional results are retained separately, not relabeled as visible-context evidence. These checks do not establish a packed release, human gameplay/listening, new campaign balance or sustained performance. The Bodies source and release self-test corrections are merged through PR112. Matching signed/notarized Preview07 packaging and public delivery remain pending.

The subsequent pistol-angle report remains open in the installed build. The corrected native assembly has now completed its three-pose CPU PBR renders, normal import and a real full-HUD/world fixture (65 functional checks; all three poses). Independent intended-use review has passed on the actual imported full-HUD/world output. Canonical integration is merged in PR113; matching release delivery remains pending. It is not yet shipped. Preview06.1 remains the public build until a matching successor is verified.

## Actual remaining gaps

1. **World presentation beyond the delivered gates.** Preview06 replaced all eight interactive burgundy-box gates with distinct authored assemblies. Wider room construction, identity and meaningful return-route variation remain; gate delivery does not complete the surrounding maps.
2. **Environment identity and meaningful variation.** Seven tradition-associated catalog pieces and two hero IDs are present per chapter. DESIGN.md explicitly allows a hero to fulfill a tradition category when its actual design supports it; do not invent a requirement for seven additional pieces or ten extra assets. The remaining gap is demonstrated visual identity, purpose and staging—not another catalog-count exercise.
3. **Enemy/boss production art and explicit physiology.** The retained eight enemy concept sheets are not complete directional/animated runtime assets. Anatomical/weak-point work needs actual art/masks and intentional combat behavior—not bounding-box relabeling.
4. **Music-responsive presentation.** The first live pixel-garden slice ships in Preview06.1, including real signal/lifecycle checks and actual moving UI output. Any broader Resonance Journey work must add useful accepted variety rather than reopen frozen artwork or manufacture a scene-count requirement.
5. **Source/master deliverables.** Genuine native8K chapter masters and matching editable native/Blender sources remain unproved. Do not upscale current images and call that done.
6. **Human/performance evidence.** Physical controls, listening, first-human pacing and sustained FPS remain unrun under the existing holds. Label this honestly; do not turn it into another automatic blocker for independently accepted preview upgrades.

## Release05 — Arsenal Reborn (delivered)

Preview05 delivered the six accepted native three-pose weapon atlases in the actual game: impact tool, rivet pistol, scattergun, sawtooth repeater, marrow launcher and choir disruptor.

- The six `painted-v3` bindings shipped with numeric combat profiles, firing/hit logic, cooldowns and save schema unchanged.
- The raster ledger and genuinely matching editable Blender design companions are retained; the legacy119-asset catalog and original atlases remain unchanged. The paintings are not described as Blender renders.
- PR105 and the matching release-documentation PR106 are merged. The actual Apple Silicon build is signed/notarized, packaged-resource checked, installed and publicly downloadable; README and Site match it.
- Preview04 remains available for rollback. Unaccepted gate and SoundTest prototypes are not in Preview05.

## Release06 — Eight Living Thresholds (delivered)

All eight authored gate assemblies now pass independent intended-use review and targeted native service/context checks. Their exact source/runtime bytes are frozen. PR107 is merged; the exact Preview06 Apple Silicon archive is signed/notarized, packaged-resource checked and publicly downloadable. Matching release details are recorded in `docs/releases/major-features-preview-06.md`. Chapter-specific fixed surrounds and integrated material/construction identities are part of these assemblies; this is not a claim that the surrounding maps have been rebuilt.

| Chapter | New threshold identity |
|---|---|
| Intake | Taut pressure-suture membrane, asymmetric bell-yoke and siphon return |
| Foundry | Unequal refractory pressure lobes with continuous mineral scar/rim channels |
| Processional | Nested ivory/claret pressure chambers and a connected cast-bronze web |
| Reliquary | Five unequal mineral archive receptacles with an indexed stepped register |
| Nursery | Paired clinical pressure packs, vascular Y channel and enclosing cradle |
| Ossuary | Broad forked bone-ceramic transfer carrier over opaque load compartments |
| Inversion | Opposed swept S membranes with connected counter-tension returns |
| Heart | Quiet opposed diaphragm plates and a continuous offset compression channel |

**Not eight recolors:** vary aperture construction, frame silhouette, layered surfaces, restraint connections and chapter story. Produce actual portable runtime assets and editable authoring sources; reference pictures alone do not qualify. Use the existing palette/art bible, not generic sci-fi runes or caricatures of real religions.

### Implementation seam and hard boundaries

- Add a mesh-only visual rig at `Level.build`'s existing door loop, selected by an explicit eight-entry stable-door-ID map. Preserve the original `StaticBody3D`, box dimensions, position/yaw, sole collider, registry and navigation authority.
- All eight doors still require the existing Blood and Ivory seals. Preserve key collection, interaction cone/range, missing-key prompt, removed-ID ownership and existing checkpoint rollback semantics. No new save fields or puzzles.
- Preserve the existing opening contract: collision disabled, original body lifted6units over0.65s, freed, route invalidated immediately. Level directly hides the entire unscripted aperture-cover root (leaf plus crossing latches/backing) in the collision-clear transaction before optional art callbacks. Keep exactly one original body tween; no extra clock or delayed clearance.
- Author a credible released/stowed closure configuration outside the usable aperture. Hydrate it directly for saved removed IDs; do not replay an opening or persist its animation. Avoid a rigid slab that simply deletes itself. The precise take-up mechanism is an artistic design choice, not a mandatory generic pocket framework.
- Four-state presentation: neither seal / Blood only / Ivory only / both. Show distinct mechanical engagement, not color alone. Derive it from existing keys; derive already-open state from removed IDs.
- Do not attach the six old gate GLBs blindly: their bounds/origins are inconsistent and they are currently separate scenery. Normalize a proper rig or author new geometry. Keep added dressing out of walkable/support/cover space; decorative art must not falsely occlude shootable targets.
- Use the normalized Intake/Foundry pair to prove the source-to-runtime contract, then author the remaining six independently in parallel code-preparation lanes, with serialized lightweight source export and native qualification. All eight still need individual intended-use acceptance before the coordinated release. No serial tiny art PRs.
- Actual placement survey: each blocker spans an8m/12m walkable run, with lateral wall returns as supports. Nonwalkable height-field samples are not floor support. Inspect native floor, wall, roof mesh and nearby authored geometry. Keep actual maps/colliders unchanged; seat or recess the new art when a known overlap is found.
- The procedural bar/spoke and later thin-overlay approaches are capped. The accepted route uses genuine editable sculpted Blender sources, used packed painted surfaces and normal imported GLBs. Intake/Foundry retain their accepted constructions; the remaining six use chapter-specific art-led continuous relief and actual keyed pressure shoes/receiver jaws, not flat concept-image planes. All eight passed at actual640×360 in their unchanged Level lighting, with independent seal states, front/back/oblique and released views.
- Source-to-consumer lessons: valid added meshes may still be buried under opaque surfaces, and mirrored cap winding may hide visible faces. Correct actual substrate/contact and closed-volume winding before commissioning more art. Current accepted source proofs retain those checks. Do not reopen frozen assets for optional polish.
- A separate strict eight-entry source/runtime/import/native/independent-evidence ledger owns the new outputs; retain every legacy119-catalog and existing ownership guard.

## Release06.1 — Forward Aim and Pixel Music Garden (released)

These urgent user priorities sit between delivered Preview06 and the broader Preview07 Bodies and Consequences tranche. They do not replace, shrink or reorder the complete major-feature goal.

- Correct the reported Rivet inspection angle with the accepted native forward-firing pose. All three genuine Blender poses retain the existing muzzle/crosshair/HUD registration. The editable saved master and portable exporter reproduce the exact accepted atlas. Only the index1 asset binding changes; stats, timing, hit logic, the other five weapon designs and all eight gate assemblies remain frozen.
- Deliver the clarified SoundTest direction: original cute/fun 1995-era stepped pixel animation, a fixed 16-color garden with beetle/blob/bird, not a static concept illustration or copied Tyrian assets/code. Decorative motion follows real owned Music playback; measured low/mid/high FFT supplies actual signal response. Preserve transport, no autoplay, focus, volume, ownership and reduced-motion controls.
- Qualification includes55unit tests, the119-asset/140-export art contract, five affected native host tests, actual16-frame combined UI output and real imported Texture2D pixel equality. This does not establish human input/listening/music fit, sustained FPS, played pacing or whole-campaign completion.
- Export source `4a5268e5b80bf937f5e2b0a0f8ce4ac6363ced4a` and merged source `5e3032b0204809e994281ce7ede09f44424b6ee2` share exact tree `088208959db676bfcb021df572a83ccc435e88d5`. the matching signed/notarized/stapled Apple Silicon archive is publicly available and locally installed; the broader major-feature goal remains in progress. Matching README/Site and exact package identity remain mandatory.
- Keep the verified Preview06 download as the immediate rollback. Preserve Preview05/04/03 and earlier packages. No prior source, asset or release is replaced or deleted.

## Major orthogonal variation — choose one bounded pilot

### Selected: the cathedral remembers

After the player obtains a seal or reads a chapter record, two selected return-route rooms reveal a second layer of construction: relaxed sutures, exposed service channels, an exhausted rather than threatening mechanism, or a fossil/afterimage of the earlier room. Derive this from existing keys/discoveries/removed IDs; no new collectible or save state. Geometry relevant to traversal and combat stays unchanged. This makes the return journey visibly different and gives discoveries an environmental consequence.

### Next alternatives, not extra release prerequisites

- **Machinery as navigation:** a small number of authored pressure conduits and mechanical indicators align toward the existing return junction after a seal is earned. No floating waypoint or invented route.
- **Orientation debt:** Inversion/Heart service structures continuously connect across apparently impossible orientations. Architectural perspective/parallax only—not portals, gravity changes or a second physics world.

Do not accumulate all three into an endless release. The two-room afterimage pilot ships only if coherent and accepted; otherwise gates ship independently.

## Following major releases

1. **Preview07 — Bodies and Consequences:** actual directional/animated enemy and boss art, differentiated readable threat silhouettes/telegraphs, then explicitly designed anatomical/weak-point regions where the artwork and gameplay support them. Add visible hand/equipment evolution only as a real authored feature, not a tint masquerading as transformation.
2. **Preview08 — Resonance Journey continuation:** Preview06.1 supplies the delivered first pixel-garden slice; retain it and continue only useful broader work after Preview07. Follow the 2026-10-27 clarification: procedurally generated **live, cute and fun, 1995-era pixel animation**, inspired by the spirit of Tyrian’s Sound Test, not smooth modern graphics or a static cathedral illustration. Build original chunky palette-limited creatures/patterns and playful stepped motion; do not copy Tyrian art or code. Preserve the working transport, focus, volume, ownership and reduced-motion controls. Separate decorative playback-time animation from genuine Music-bus peak/frequency response. Preview06.1 has its own actual host/import/UI qualification; archived FFT prototypes alone are not shipping evidence. Qualify actual moving output as well as readable stills before release; neither an attractive concept image nor assertion counts establish animation quality.
3. **World identity + master completion:** fill distinct structure/staging gaps, strengthen hazards/discoveries where meaningful, and deliver genuine native8K/editable masters when the held production route is available. Preserve all existing originals and describe the actual generator/source format honestly.

## Acceptance and stopping rule

- Independent adversarial feature review at the declared9.2/10 rubric. The orchestrator sees ratings; implementers receive only defects/reproductions or PASS. Freeze exact accepted artifacts immediately.
- Use actual intended-use views at the game’s640×360 internal resolution, not concept sheets or model counts.320×200 samples are additional stress evidence, not a substituted final quality target. New gates need both sides, low light, seal states and opening/removed-save behavior. Reuse one bounded fixture and affected native checks; preserve all existing collision/save/finite-resource protections.
- New weapon assets need actual normal-import/package consumption and unchanged cadence, not another complete campaign matrix.
- Every released tranche gets a matching verified build, README, current Site and rollback. Nonblocking bugs enter the backlog; unrelated unfinished features do not prevent deployment.
- Mac heavy-work/physical-input/listening/gameplay-capture and cloud/Ponytail holds remain. No paid/API/account fallback, extra cloud environment, or security/protection changes.

## Explicitly not planned

No campaign rewrite, new save format, weapon-stat rebalance, procedural level generator, destructible-door system, new key puzzle, portal renderer, new soundtrack subscription, or repeated polishing of accepted paintings/combat/Continue/scaling.

## Consultation integration and scope discipline

The authorized deep Pro consultation is captured locally with source identities and independent dispositions. Its recommendations are proposals, not new requirements or proof. Accepted priorities: eight authored constructions behind one narrow native contract; Level-owned complete-cover clearance; credible released material; real mounts and restoration; genuine runtime enemy art; a coherent music-art direction using existing controls.

Corrections from current source: ordinary worker hits already interrupt its committed attack, and the current hit helper already returns accepted frame/atlas/local-pixel data. Do not replace ordinary interruption with weak-point-only interruption or rebuild the helper as a supposed missing feature. Add anatomical consequences only where the new art and actual gameplay justify them. Public Preview06 uses restored playback time and Music-bus peak; qualified Preview06.1 adds real FFT bands under the same owned transport. Its actual new qualification, not archived experiments alone, supports that change. Three existing styles and eight tracks do not automatically require24 separately authored compositions or another exhaustive campaign matrix. Preserve the complete major-feature goal without accepting consultation-driven scope inflation.
