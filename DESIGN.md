# NULL CHOIR — implementation brief

Status: Jared approved this brief and implementation start on 2026-09-30. The eight-level expansion, unique-art requirement, and performance targets are accepted. Performance has not yet been measured.

## Outcome and value

Build an original, offline, single-player Doom-inspired campaign in Godot, with pixel-art sprites in 3D environments and Blender-authored character and world assets. Deliver the editable project and an Apple Silicon Mac application in a new private repository at `ihearttokyo/null-choir`, with private downloadable releases.

The value hypothesis is that fast, readable combat, distinct level architecture, memorable live MIDI compositions, and discoverable environmental storytelling make a replayable eight-level game. Acceptance requires the full campaign, its original assets and music, actual Mac playability, and measured load-speed evidence—not merely a working first level.

## World and story

An industrial cathedral surrounds a buried organism. Lovecraftian cosmic horror and H. R. Giger-inspired body horror guide original designs. Extreme fictional body horror is encouraged; do not copy existing game characters, artwork, maps, or songs.

The silent player is a recovery technician assigned to restart containment systems. Visible hands and equipment gradually become less human. The cathedral is a restraint mistaken for a shrine; the assigned repairs are releasing its occupant. One optional environmental story discovery per level contradicts the mission. Finding all eight changes the final revelation and identifies who supplied the orders without fully explaining the entity. Keep exposition minimal.

## Campaign and unique set design

Eight hand-authored exploratory maps contain keys, elevation changes, ambushes, secrets, and routes returning to recognizable junctions. Each map has at least two deliberately authored traversal loops. Every authored loop contains a bespoke Blender-authored hero set piece, unique across the campaign. A recolored texture, sign, or reused prop does not satisfy this requirement. There must be at least sixteen distinct pieces; additional authored loops require additional pieces.

| Level | Location | Signature piece for one loop |
|---|---|---|
| 1 | The Intake | Suspended skin bell |
| 2 | The Foundry | Vertebral furnace |
| 3 | The Processional | Walking bone organ |
| 4 | The Reliquary | Rotating halo of preserved faces |
| 5 | The Nursery | Transparent gestation engine |
| 6 | The Ossuary | Spiral rib bridge |
| 7 | The Inversion | Surgical chamber beneath an impossible sky |
| 8 | The Heart | The buried organism's colossal mouth |

Target roughly 8–12 minutes per level and 75–100 minutes for a first playthrough. These remain design targets until playthrough evidence exists. Record authored loops and their art-piece identities so they can be checked alongside actual traversal and visual inspection.

## Combat and controls

- Fast strafing and modern mouse look; optional classic auto-aim; no mandatory jumping or platforming.
- Pickup-based health, armor, and ammunition; no health regeneration or reloading. Strong impact feedback and enemy infighting.
- Six weapons, introduced gradually: impact tool, rivet pistol, scattergun, sawtooth repeater, marrow launcher, choir disruptor. Industrial designs become increasingly biological.
- Six regular enemy roles with distinct silhouettes: rushing crawler, ranged worker, floating projectile caster, charging brute, armored guardian, summoner.
- Two bosses represent manifestations of the buried organism, not its entirety.
- Three difficulty settings; no adaptive difficulty.
- Persistent campaign progress, mid-level checkpoints before major encounters, checkpoint resource restoration on death, and level restart.
- Rebindable keyboard/mouse and gamepad controls; sensitivity and invert-Y; optional head bob and camera shake; separate music/effects volume.

## Art and music

Use 640×360 internal rendering with crisp scaling, directional sprites, atmospheric lighting, and restrained post-processing. Preserve readable silhouettes during combat. Character, weapon, and hero-piece models must be original Blender work with editable `.blend` sources. Redistribution-compatible supporting textures and instrument banks are permitted with provenance recorded.

Create eight original `.mid` compositions, one per level. Synthesize them live in the application, offline; rendered recordings are not an acceptable replacement. Use distinct MIDI-metal riffs, bass/drums, organ and synth passages, explicit loop lengths, and appropriate musical variation. Audition the actual instruments and repeated transitions rather than approving music from MIDI files alone.

Keep authoring sources outside the Godot runtime project. Generate sprite atlases and world GLB/textures before shipping; include only needed runtime assets in the application. Load one level at a time and reuse native Godot resource/import facilities, without a speculative custom cache. See [technical research](RESEARCH.md) for evidence and the provisional synth choice.

## Implementation and evidence gates

1. Prove the intended failing assertion before deterministic logic changes, then implement the smallest passing change. Keep relevant unit/integration checks and representative end-to-end campaign coverage.
2. After the first passing nontrivial code change, run correctness and Ponytail reviews before broader validation. Fix findings and rerun affected checks.
3. First evaluate one self-contained offline Mac export playing representative live MIDI. Exercise dense notes, tempo changes, pitch bend, percussion, repeat boundaries, volume/mute, pause/resume, and level switching. Reject audible seams, stuck notes, or dependence on host-installed audio libraries.
4. Deliver a finished first level with original art and music, then the full playable campaign, then the final art/music pass and optimized release. Continue autonomously after brief approval; report milestones and ask only for material decisions or blockers.
5. Accepted performance targets on the verified M4 Mac: 60 FPS during normal combat at the chosen internal resolution, a usable main menu within three seconds of cold application launch, and ordinary level transitions within two seconds. Measure and profile before claiming these pass or changing the targets.
6. Exercise all eight levels, combat roles, both bosses, all story discoveries, alternate revelation, difficulty choices, checkpoint/death/restart, persisted continuation, keyboard/mouse, and gamepad. Validate primary/secondary GUI paths, an edge state, and post-action feedback when nondisruptive computer use is feasible. Label skipped checks and their limits.
7. Before release, verify the actual standalone Apple Silicon application, asset/music completeness, dependencies, signing, and private repository/release state. Apple notarization authentication and any upload authorization remain release-boundary gates; an existing signing identity alone does not establish them.

## Authority, ownership, and rollback

Jared permits necessary tools, unlimited spending, incremental autonomous work after confirmation, and useful named CLI child tasks. All testing and child work must use `gpt-6.1-sol`, `xhigh`, Fast off, and explicitly pinned `service_tier="default"`. Inspect available runtime evidence; missing telemetry is a reporting limitation, not a blocker. Follow the successful bundled-CLI runtime receipt in [RESEARCH.md](RESEARCH.md). Bound concurrency and preserve other work; serialize heavy jobs until observed headroom supports more.

The parent owns integration. Give children bounded missions and nonoverlapping files, verify task identity/tool state, preserve receipts, and archive unneeded finished children. Exact encounter layouts, animation details, palettes, composition structure, clue wording, and balancing may be authored within this agreed brief; material scope or authority changes require Jared.

Preserve unrelated projects, apps, credentials, global settings, and existing repositories. Prepare and verify concrete external targets/payloads before mutation. Keep secrets and disposable validation output out of Git. Use explicit staged paths, inspect diffs, check whitespace, and scan for secrets before authorized commits.

Keep source assets and generated runtime assets traceable. Pin selected runtime dependencies for reproducibility. Record a verified commit/asset restoration point before subsequent changes; restore the last verified state if a change regresses accepted behavior, without resetting unrelated work. Do not reduce the eight-level scope or replace live MIDI to make checks easier.
