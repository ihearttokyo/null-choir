# Blender art pipeline

The first Intake asset set is original geometry and authored pixel textures. No Doom, Alien, third-party character model or downloaded texture is included. `source/art/manifest.json` records editable sources, output hashes, origins, pose order, dimensions and loop identities. [DESIGN.md](../DESIGN.md) owns campaign-wide art acceptance; all eight level asset sets are installed; native map integration is still in progress.

Rebuild with the installed Blender:

```sh
blender -b -t 4 --python-exit-code 1 --python tools/build_art.py
```

For one original Intake identity, append `-- --asset worker` or another ID supported by `tools/build_art.py`. Later recipes use their own commands below. Freeze the recipe and stop other art writers before rendering. Python exceptions must produce a failed build; Blender's default exit behavior is insufficient. A rebuild replaces the generated scene/output for the selected identity, so preserve manual Blender edits before regenerating it.

The scenery correction rebuilds only `skin_bell`, `siphon_heart`, `vault_span`, `lumen_sconce`, `witness_relief`, `suspended_cadaver`, `containment_capsule` and `drain_altar`. Earlier enemy, weapon, architectural-kit and texture outputs remain unchanged. Each manifest entry records the recipe hash that produced it; `build.script_sha256` identifies the latest recipe, not a claim that every older asset was regenerated. Source and output hashes always describe the actual files.

Blender saves editable `.blend` scenes under `source/art/`. Enemy and weapon pose collections remain separate. Rendering uses Cycles CPU, four threads and native pixel resolution. The final PNG writer quantizes the palette and emits binary alpha with nearest filtering; the player never invokes Blender. GLB heroes and supporting kit combine geometry by material and embed their buffers/textures. Their tracked Godot import settings keep images embedded and uncompressed, avoiding duplicate extracted images and pixel-art compression. See [Godot import configuration](https://github.com/godotengine/godot-docs/blob/master/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.rst).

Regular enemy sheets have eight directional columns and five 128-pixel pose rows: idle, walk A, walk B, attack and dead. Column zero is the front; foot baseline is row 119, documented origin `(64,120)`. Weapon sheets have three horizontal 320×200 frames: idle, fire and recover. World exports use Godot's Y-up conversion and ground-centered origins. The manifest is authoritative for each model's dimensions and triangle count.

## Intake scenery

| Identity | Authored form and placement |
|---|---|
| `vault_span` | Paired fluted bone ogives, transverse vertebrae and an amber keystone. Spans an eight-meter corridor; low supports stay outside the central seven-meter opening. No central hanging detail below four meters. |
| `lumen_sconce` | Wall-fastened ivory cage around an incised amber tissue tube. Front is Blender -Y; backing is +Y. Parent supplies the local light, mounted above player height. |
| `witness_relief` | Asymmetric flayed wall shell with layered costal wings, an excised face and pinned spine. Front is Blender -Y; it is wall sculpture, not an enemy model. |
| `suspended_cadaver` | Split burial membranes expose a technician's spinal locks beneath braided tethers and a steel isolation ring. Base origin is the lowest ankle restraint; parent suspends the whole apparatus overhead. |
| `containment_capsule` | Ribbed surgical reliquary with an open lancet front, inset preserved branching anatomy and arterial feeds. Foundation rests at zero. Keep it peripheral and collide its envelope when floor-mounted. |
| `drain_altar` | Open annular swallowing funnel, hooked radial teeth, recessed throat and paired pressure gauges. Foundation rests at zero; keep its footprint clear of traversal. |
| `skin_bell` | Original open tissue bell and tongue retained; bolted radial dais, comb restraints, paired suspension tendons and flying crown buttresses add ground contact and a tall silhouette. |
| `siphon_heart` | Original suspended heart/manifold retained; bolted pedestals, costal cradle fins, posterior arterial loops and pressure dials distinguish its low spreading silhouette from the Bell. |

The fixed maximum envelopes, real GLB bounds, vault clearance and runtime budgets are checked in [the art contract](../tests/test_art.py). Blender -Y fronts export as Godot +Z; +Y backing exports as -Z. Editable sources retain separately named anatomical and mechanical parts. Runtime exports apply transforms and combine those parts by material; lights and cameras stay in the authoring scene, not the GLB. Emissive tissue marks fixtures but does not replace the parent's native scene lights. Imported geometry has no baked collision; the level owns placement and collision.

Run the direct contracts after rendering:

```sh
python3 tests/test_art.py
blender -b -t 4 --python-exit-code 1 --python tests/test_art_pose.py
```

The first verifies manifest/file parity, hashes, `.blend` provenance, self-contained GLB, PNG dimensions/alpha, distinct poses and foot baselines. For the eight scenery assets it also reads actual exported vertices, compares axis-converted bounds, checks material merging and vault clearance, and enforces triangle and combined file-size budgets. The second proves that later authored poses cannot mutate earlier geometry. Neither check establishes visual quality. Native Blender previews in ignored `builds/art/<identity>_preview.png` support inspection; in-game review and performance remain separate parent-owned acceptance gates.

## Foundry heroes

`tools/build_foundry_art.py` reuses the original Blender source/render/material-merging/export helpers. It adds independent `vertebral_furnace` and `marrow_crucible` recipes without regenerating Intake assets. Each new manifest entry records its recipe hash and the unchanged helper dependency. The furnace has 296 editable meshes and 24,584 triangles; the crucible has 194 and 23,076. Their distinct vertical spinal and broad pelvic silhouettes are covered by real exported geometry checks. [FOUNDRY.md](FOUNDRY.md) owns in-level views and native traversal evidence.

```sh
blender -b -t 4 --python-exit-code 1 --python tools/build_foundry_art.py
python3 tests/test_art.py
```

A native build initially exceeded the unchanged combined four-MiB budget by 31,092 bytes. Reducing only small gauge-ring tessellation retained all named features and passed at 4,093,296 bytes. At the Foundry delivery, all 35 original source/output hashes and 18 prior manifest entries remained unchanged. Preview outputs are ignored under `builds/art/`; raw validation receipts remain outside Git.


## Processional assets

`tools/build_processional_art.py` adds the walking bone organ, ossified palanquin, floating caster and scattergun. It reuses both unchanged authoring helpers and records their hashes. The organ has 370 editable meshes, six walking legs, fifteen hollow pipes and 22,384 triangles; the palanquin has 339 meshes, six carrying limbs, a split casket and 21,788 triangles. Both hero sources retain named editable assemblies. Runtime geometry merges into seven material groups per hero; their combined GLBs are 3,711,980 bytes, below the unchanged four-MiB budget.

Caster sources retain five pose collections and 40 distinct directional cells, including a visibly collapsed death row. The scattergun retains three poses with two hollow barrels and visible biological hands. At Processional delivery, native CPU builds/rendering passed with 24 assets and 25 exports. All 41 prior source/output/helper hashes and 20 prior manifest entries remained unchanged. [PROCESSIONAL.md](PROCESSIONAL.md) owns scene and combat evidence.

```sh
blender -b -t 4 --python-exit-code 1 --python tools/build_processional_art.py -- --asset walking_bone_organ --receipt-dir builds/art/processional
blender -b -t 4 --python-exit-code 1 --python tools/build_processional_art.py -- --asset ossified_palanquin --receipt-dir builds/art/processional
blender -b -t 4 --python-exit-code 1 --python tools/build_processional_art.py -- --asset caster --receipt-dir builds/art/processional
blender -b -t 4 --python-exit-code 1 --python tools/build_processional_art.py -- --asset scattergun --receipt-dir builds/art/processional
python3 tests/test_art.py
```

## Image-derived religious machinery

Actual GPT Image construction sheets and exact prompts for all eight levels are retained under `source/art/references/`. Inspect the selected pixels before designing an asset and deliver actual images to each implementing child; verify inspection. The images guide editable Blender geometry and staging. They do not establish rendered fidelity, audio quality or gameplay acceptance.

Intake has seven new machines from `tools/build_religious_art.py`. Foundry has seven from `tools/build_religious_foundry_art.py`; Processional has seven from `tools/build_religious_processional_art.py`. They represent Christian, Buddhist, Shinto, Islamic, Hindu, Jewish and ancient Egyptian aesthetics redirected by a fictional controller. Existing unique loop heroes remain intact. All three sets retain named editable assemblies and compact consumed pixel textures, saved before runtime merging. Every GLB stays at most 30,000 triangles and seven material meshes; each seven-piece set stays below eight MiB. Intake totals 8,313,560 bytes; Foundry totals 7,606,444; Processional totals 7,432,096. Reliquary adds seven installed assets from `tools/build_religious_late_art.py`, totalling 7,514,360 bytes. Current strict inventory checks cover 92 assets and 93 exports, including all 56 religious pieces and eight late combat identities. Native editability, staging, local-base/ceiling, traversal, scenery and authored encounter checks pass for all three sets; third-map checkpoint/Continue/progression also passes. These controlled fixtures do not establish heard or GUI/GPU quality.

The late recipe has produced all 35 pieces for Reliquary, Nursery, Ossuary, Inversion and Heart in fresh candidate roots. All actual GLBs pass unchanged geometry, embedded-texture and per-level budgets; all saved sources were reopened and edited/restored in memory without changing disk hashes. Parent inspected all 35 native previews. All 35 are installed after exact candidate/source/import verification; Nursery staging and scenery pass, and all eight maps now pass native religious staging, scenery and capsule-loop checks. Two native failures were repaired at the recipe owner: Memory Wheel uses the existing amber dial helper, and source-mesh transforms are applied before bounds reporting so rotated geometry agrees with real exported vertices. Failed candidates and raw checks remain outside Git.

These recipes require one exact asset ID, explicit fresh candidate output and receipt roots outside the project, and refuse existing targets, production overlap and escaping symlinks. Use the installed Blender with `--python-exit-code 1`. For example, after choosing a fresh receipt directory:

```sh
blender -b -t 4 --python-exit-code 1 --python tools/build_religious_foundry_art.py -- \
  --asset foundry_cross_spine --output-root /private/tmp/null-choir-foundry-candidate/native \
  --receipt-root /private/tmp/null-choir-foundry-candidate
```

Build all seven before running the corresponding real-output validator with `--candidate-root`. Inspect actual native previews against the selected image, reopen sources to verify editability and packed textures, then integrate accepted records into the existing authoritative manifest. Keep Godot images embedded with `gltf/embedded_image_handling=3`; validate the actual import. Source assertions and bright 384-pixel authoring previews do not certify spooky in-game lighting. Parent-owned native scene, collision, traversal, visual and performance checks follow.

Every model must consume its required texture. Merely creating an unused textured material does not embed an image in GLB. The Foundry repair connects the existing packed surface atlas to local iron with nearest sampling; no geometry or budget assertion changed. Its original failed native outputs remain outside Git.

## Late combat assets

`tools/build_late_combat_art.py` derives three weapons, three regular roles and two bosses from the retained weapon/role/boss construction sheets. Actual native builds and unchanged candidate validators pass for all eight. Every saved posed assembly was reopened and edited/restored in memory; each pose has independent mesh data and exact geometry fingerprints, with portable packed textures. All actual directional/contact sheets were inspected before installation.

Weapons retain three 320x200 cells; regular roles retain eight directions and five 128x128 rows with baseline 119/origin `(64,120)`. Bosses use five 256x256 rows, baseline 247/origin `(128,248)`: the same eight-pixel bottom margin, not the erroneous 239/240 handoff prose. All 40 character cells are distinct and deaths collapse below the midpoint. Per-pose triangle ceilings are 18,000 weapons, 16,000 regular roles and 24,000 bosses. PNG limits are 256 KiB, 512 KiB and two MiB, respectively. The existing strict inventory enforces these actual outputs and provenance without lowering older contracts.

Pose collections open with idle visible. Reveal a chosen collection and update Blender's view layer before reading its evaluated transforms; hidden collections otherwise report stale matrices. The corrected read-only reopening check retains the exact geometry assertion. Native silhouettes and compact atlases are accepted for integration staging. Distinct live weapon/role/boss mechanics, in-game scale and final visual quality remain separate work.

## Image-derived overhead apparatus

`tools/build_world_atmosphere_art.py` derives four editable modules from the retained
`source/art/references/world-polish-late-01.png` construction direction: Nursery
umbilical growth vessels, Ossuary suspended bone sorting, Inversion layered cosmic
fractures and Heart arterial ribs. Native Blender sources retain four named
assemblies and 92–134 independent meshes. Reopening, an actual vertex edit/revert,
packed textures and unchanged disk hashes pass. Native exports contain 5,948–19,980
triangles and four or five material meshes each; all four total 4,044,984 bytes.
Their independent ceilings are 22,000 triangles, five meshes, two MiB per asset
and six MiB combined. The strict inventory preserves all 88 prior records and
source/output hashes; religious and original scenery budgets remain separate.

Godot imports retain embedded images with mode 3. Actual material-resource and
vertex checks pass after correcting the initial default-mode extraction. Four
central overhead instances per loop chamber frame each protected hero without
intersecting its envelope, roof, actor clearance or reserved boss arenas. Four
nonshadow supporting lights per map preserve the four original shadowed spots.
All sixteen actual 640x360 M4 views were inspected; the first sparse peripheral
arrangement was rejected. Warm source builds measured 171–242 ms and default-vsync
samples 59–108 FPS. Full combat, packaged cold start and final visual acceptance
remain separate checks; the generated reference is not a game screenshot.

## Safe regeneration

The original recipe now retains later manifest entries in stable order during geometry and texture rebuilds. `tests/test_art_manifest.py` exercises the real metadata path with simulated render callbacks; it is not art evidence. A helper change requires actual regeneration of dependent assets before updating their provenance. Preserve manual source edits and stop overlapping native writers first. The sorting repair rebuilt 21 identities in isolation, retained ten historical identities and passed strict parity plus actual game reimport/staging checks. Native export triangle order and tiny UV rounding can vary; always record actual produced bytes rather than invent new hashes for old files.

Scenery scales use the existing JSON `[x, y, z]` array schema. Low collision bases use model-local dimensions and receive yaw once in the level builder. Do not pre-rotate their width/depth. Native staging verifies both the imported model and base dimensions/orientation. Lights and collision remain level-owned; authoring cameras and lights never ship inside the GLB.
