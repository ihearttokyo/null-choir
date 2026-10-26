# NULL CHOIR — next major upgrade series

Date: 26 October 2026. Baseline: public Major Features Preview04; main `1db8b7c`. This plan preserves the full major-feature goal, distinguishes shipped work from working/prototype work, and prioritizes changes a player will actually notice.

## What is already established

- The eight-map campaign, two authored loops per map, seals, discoveries, checkpoint/Continue and two endings exist. Retained fresh earned runs cover a current default Blood-first recordless normal ending and a separate earlier Nightmare Ivory-first all-records revelation. This is not six current campaign combinations, human play or a performance certification. Do not reopen that matrix for cosmetic changes.
- The connected illustrated descent chart, unlocked chapter interludes, title/eight selected chapter paintings, eight offline Suno tracks and title/interlude selections are in Preview04. Originals are retained. The current paintings are **not** true native8K or editable Blender remakes; that source-master requirement is still open.
- Six differentiated weapons, enemy roles, bosses and difficulty logic exist. Visible-sprite alpha hit coverage is implemented; anatomical regions/headshots/boss weak points are not interchangeable with that feature.
- All six new production-directed weapon atlases have now passed independent intended-use review and normal-import/actual-HUD/cadence checks in the working tree. They are frozen and **not yet in public Preview04**. Retain the original Blender art lineage and truthful separate raster provenance.
- The stable SoundTest transport remains shipped. Its ambitious replacement is **not accepted**. Technical render passes and extra geometry are not artistic completion. Stop iterating little rooms on this release's critical path.

## Actual remaining gaps

1. **Repeated world presentation.** All eight interactive gates are the same burgundy box, despite some different gate-shaped scenery elsewhere. The scenery is not wired to the interactive doors. Foundry and Processional lack even those named gate scenery pieces.
2. **Environment identity and meaningful variation.** Seven tradition-associated catalog pieces and two hero IDs are present per chapter. DESIGN.md explicitly allows a hero to fulfill a tradition category when its actual design supports it; do not invent a requirement for seven additional pieces or ten extra assets. The remaining gap is demonstrated visual identity, purpose and staging—not another catalog-count exercise.
3. **Enemy/boss production art and explicit physiology.** The retained eight enemy concept sheets are not complete directional/animated runtime assets. Anatomical/weak-point work needs actual art/masks and intentional combat behavior—not bounding-box relabeling.
4. **Rich music-responsive artwork.** The audio/control foundation works; the procedural visual treatment still needs a coherent finished art direction. Preserve experiments without advertising them as shipped.
5. **Source/master deliverables.** Genuine native8K chapter masters and matching editable native/Blender sources remain unproved. Do not upscale current images and call that done.
6. **Human/performance evidence.** Physical controls, listening, first-human pacing and sustained FPS remain unrun under the existing holds. Label this honestly; do not turn it into another automatic blocker for independently accepted preview upgrades.

## Release05 — Arsenal Reborn (ship the ready major upgrade)

Deliver the six accepted native three-pose weapon atlases in the actual game: impact tool, rivet pistol, scattergun, sawtooth repeater, marrow launcher and choir disruptor.

- Keep the six `painted-v3` asset bindings and all numeric combat profiles, firing/hit logic, cooldowns and save schema unchanged.
- Finish the narrow raster-ledger ownership integration and retain genuinely matching editable Blender design sources; keep the legacy119-asset catalog and original atlases unchanged. Painted PNG approval does not by itself close the editable-model requirement. Do not substitute empty files, image planes, or unqualified old models.
- One coherent PR, affected native/art checks, exact packaged-resource/HUD binding, signed/notarized installable build, README + current Site update, preserved Preview04 rollback.
- Do not hold this accepted batch for the unaccepted visualizer or unfinished gates. No further art polish or full campaign rerun absent a demonstrated regression.

## Release06 — Eight Living Thresholds (next implementation priority)

Replace the eight repeated gate boxes with eight deliberately different working-looking restraint assemblies, plus a compact chapter-specific threshold/junction dressing kit.

| Chapter | New threshold identity |
|---|---|
| Intake | Taut pressure-suture membrane, asymmetric bell-yoke and siphon return |
| Foundry | Refractory vertebral portcullis and crucible-return manifold |
| Processional | Deep folded bellows shutter, organ-pipe comb and palanquin lintel |
| Reliquary | Indexed face/archive aperture with independently legible mechanical latches |
| Nursery | Vascular gestation/seed membrane with enclosing containment hardware |
| Ossuary | Rib-carrier transfer lattice with tendon-like locking ties |
| Inversion | Suspended surgical/cosmic alignment shutter with connected inverted supports |
| Heart | Mouth-restraint cardiac valve and restrained pulse manifold |

**Not eight recolors:** vary aperture construction, frame silhouette, layered surfaces, restraint connections and chapter story. Produce actual portable runtime assets and editable authoring sources; reference pictures alone do not qualify. Use the existing palette/art bible, not generic sci-fi runes or caricatures of real religions.

### Implementation seam and hard boundaries

- Add a mesh-only visual rig at `Level.build`'s existing door loop, selected by an explicit eight-entry stable-door-ID map. Preserve the original `StaticBody3D`, box dimensions, position/yaw, sole collider, registry and navigation authority.
- All eight doors still require the existing Blood and Ivory seals. Preserve key collection, interaction cone/range, missing-key prompt, removed-ID ownership and existing checkpoint rollback semantics. No new save fields or puzzles.
- Preserve the existing opening contract: collision disabled, parent lifted6units over0.65s, freed, route invalidated. Visuals must not depict an open hole while the old solid blocker remains, or a solid closed leaf after collision disappears.
- Four-state presentation: neither seal / Blood only / Ivory only / both. Show distinct mechanical engagement, not color alone. Derive it from existing keys; derive already-open state from removed IDs.
- Do not attach the six old gate GLBs blindly: their bounds/origins are inconsistent and they are currently separate scenery. Normalize a proper rig or author new geometry. Keep added dressing out of walkable/support/cover space; decorative art must not falsely occlude shootable targets.
- Start with one complete normalized Intake/Foundry pair to prove source-to-runtime quality, then complete the eight as one coordinated batch. No serial tiny art PRs.

## Major orthogonal variation — choose one bounded pilot

### Selected: the cathedral remembers

After the player obtains a seal or reads a chapter record, two selected return-route rooms reveal a second layer of construction: relaxed sutures, exposed service channels, an exhausted rather than threatening mechanism, or a fossil/afterimage of the earlier room. Derive this from existing keys/discoveries/removed IDs; no new collectible or save state. Geometry relevant to traversal and combat stays unchanged. This makes the return journey visibly different and gives discoveries an environmental consequence.

### Next alternatives, not extra release prerequisites

- **Machinery as navigation:** a small number of authored pressure conduits and mechanical indicators align toward the existing return junction after a seal is earned. No floating waypoint or invented route.
- **Orientation debt:** Inversion/Heart service structures continuously connect across apparently impossible orientations. Architectural perspective/parallax only—not portals, gravity changes or a second physics world.

Do not accumulate all three into an endless release. The two-room afterimage pilot ships only if coherent and accepted; otherwise gates ship independently.

## Following major releases

1. **Bodies and Consequences:** actual directional/animated enemy and boss art, differentiated readable threat silhouettes/telegraphs, then explicitly designed anatomical/weak-point regions where the artwork and gameplay support them. Add visible hand/equipment evolution only as a real authored feature, not a tint masquerading as transformation.
2. **Resonance Journey:** rebuild the music artwork around one deliberate generative-art direction and finished compositions. Reuse the already working real-spectrum/transport/accessibility foundation. Do not spend another release chasing primitive-room detail or treating technical tests as art scores.
3. **World identity + master completion:** fill distinct structure/staging gaps, strengthen hazards/discoveries where meaningful, and deliver genuine native8K/editable masters when the held production route is available. Preserve all existing originals and describe the actual generator/source format honestly.

## Acceptance and stopping rule

- Independent adversarial feature review at the declared9.2/10 rubric. The orchestrator sees ratings; implementers receive only defects/reproductions or PASS. Freeze exact accepted artifacts immediately.
- Use actual intended-use views, not concept sheets or model counts. New gates need both sides, low light, seal states and opening/removed-save behavior. Reuse one bounded fixture and affected native checks; preserve all existing collision/save/finite-resource protections.
- New weapon assets need actual normal-import/package consumption and unchanged cadence, not another complete campaign matrix.
- Every released tranche gets a matching verified build, README, current Site and rollback. Nonblocking bugs enter the backlog; unrelated unfinished features do not prevent deployment.
- Mac heavy-work/physical-input/listening/gameplay-capture and cloud/Ponytail holds remain. No paid/API/account fallback, extra cloud environment, or security/protection changes.

## Explicitly not planned

No campaign rewrite, new save format, weapon-stat rebalance, procedural level generator, destructible-door system, new key puzzle, portal renderer, new soundtrack subscription, or repeated polishing of accepted paintings/combat/Continue/scaling.
