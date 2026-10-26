# NULL CHOIR — next major upgrade series

Date: 26 October 2026. Baseline: public Major Features Preview05; main `b8aaa3f`. This plan preserves the full major-feature goal, distinguishes shipped work from working/prototype work, and prioritizes changes a player will actually notice.

## What is already established

- The eight-map campaign, two authored loops per map, seals, discoveries, checkpoint/Continue and two endings exist. Retained fresh earned runs cover a current default Blood-first recordless normal ending and a separate earlier Nightmare Ivory-first all-records revelation. This is not six current campaign combinations, human play or a performance certification. Do not reopen that matrix for cosmetic changes.
- The connected illustrated descent chart, unlocked chapter interludes, title/eight selected chapter paintings, eight offline Suno tracks and title/interlude selections are in Preview04. Originals are retained. The current paintings are **not** true native8K or editable Blender remakes; that source-master requirement is still open.
- Six differentiated weapons, six regular enemy roles, two bosses and difficulty logic exist. Current runtime atlases already have eight directions and five poses; committed telegraphs, a combat-visual-state seam and ordinary-hit interruption also exist. The upgrade is production-quality runtime artwork, richer readable state expression and deliberately authored physiology—not rebuilding missing direction/state systems. Visible-sprite alpha hit coverage is implemented; anatomical regions/headshots/boss weak points are not interchangeable with that feature.
- All six new production-directed weapon atlases passed independent intended-use review and normal-import/actual-HUD/cadence checks and are **shipped in Preview05**, with matching editable Blender design companions. They are frozen. Retain the original Blender art lineage and truthful separate raster provenance.
- The stable SoundTest transport remains shipped. Its ambitious replacement is **not accepted**. Technical render passes and extra geometry are not artistic completion. Stop iterating little rooms on this release's critical path.

## Actual remaining gaps

1. **Repeated world presentation.** All eight interactive gates are the same burgundy box, despite some different gate-shaped scenery elsewhere. The scenery is not wired to the interactive doors. Foundry and Processional lack even those named gate scenery pieces.
2. **Environment identity and meaningful variation.** Seven tradition-associated catalog pieces and two hero IDs are present per chapter. DESIGN.md explicitly allows a hero to fulfill a tradition category when its actual design supports it; do not invent a requirement for seven additional pieces or ten extra assets. The remaining gap is demonstrated visual identity, purpose and staging—not another catalog-count exercise.
3. **Enemy/boss production art and explicit physiology.** The retained eight enemy concept sheets are not complete directional/animated runtime assets. Anatomical/weak-point work needs actual art/masks and intentional combat behavior—not bounding-box relabeling.
4. **Rich music-responsive artwork.** The audio/control foundation works; the procedural visual treatment still needs a coherent finished art direction. Preserve experiments without advertising them as shipped.
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

## Major orthogonal variation — choose one bounded pilot

### Selected: the cathedral remembers

After the player obtains a seal or reads a chapter record, two selected return-route rooms reveal a second layer of construction: relaxed sutures, exposed service channels, an exhausted rather than threatening mechanism, or a fossil/afterimage of the earlier room. Derive this from existing keys/discoveries/removed IDs; no new collectible or save state. Geometry relevant to traversal and combat stays unchanged. This makes the return journey visibly different and gives discoveries an environmental consequence.

### Next alternatives, not extra release prerequisites

- **Machinery as navigation:** a small number of authored pressure conduits and mechanical indicators align toward the existing return junction after a seal is earned. No floating waypoint or invented route.
- **Orientation debt:** Inversion/Heart service structures continuously connect across apparently impossible orientations. Architectural perspective/parallax only—not portals, gravity changes or a second physics world.

Do not accumulate all three into an endless release. The two-room afterimage pilot ships only if coherent and accepted; otherwise gates ship independently.

## Following major releases

1. **Preview07 — Bodies and Consequences:** actual directional/animated enemy and boss art, differentiated readable threat silhouettes/telegraphs, then explicitly designed anatomical/weak-point regions where the artwork and gameplay support them. Add visible hand/equipment evolution only as a real authored feature, not a tint masquerading as transformation.
2. **Preview08 — Resonance Journey:** rebuild the music artwork around one deliberate generative-art direction and finished compositions. Reuse the working playback-time/Music-bus-peak, transport and accessibility foundation. Genuine frequency analysis, if added, is a distinct implementation change; archived FFT prototypes are not shipping evidence. Do not spend another release chasing primitive-room detail or treating technical tests as art scores.
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

Corrections from current source: ordinary worker hits already interrupt its committed attack, and the current hit helper already returns accepted frame/atlas/local-pixel data. Do not replace ordinary interruption with weak-point-only interruption or rebuild the helper as a supposed missing feature. Add anatomical consequences only where the new art and actual gameplay justify them. The current SoundTest uses restored playback time and Music-bus peak; archived FFT experiments are not the shipping foundation. Three existing styles and eight tracks do not automatically require24 separately authored compositions or another exhaustive campaign matrix. Preserve the complete major-feature goal without accepting consultation-driven scope inflation.
