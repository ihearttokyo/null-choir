# Blender art pipeline

The first Intake asset set is original geometry and authored pixel textures. No Doom, Alien, third-party character model or downloaded texture is included. `source/art/manifest.json` records editable sources, output hashes, origins, pose order, dimensions and loop identities. [DESIGN.md](../DESIGN.md) owns campaign-wide art acceptance; the present set covers Intake only.

Rebuild with the installed Blender:

```sh
blender -b -t 4 --python-exit-code 1 --python tools/build_art.py
```

For one asset, append `-- --asset worker` or another manifest identity. Freeze the recipe and stop other art writers before rendering. Python exceptions must produce a failed build; Blender's default exit behavior is insufficient. A rebuild replaces the generated scene/output for the selected identity, so preserve manual Blender edits before regenerating it.

The scenery correction rebuilds only `skin_bell`, `siphon_heart`, `vault_span`, `lumen_sconce`, `witness_relief`, `suspended_cadaver`, `containment_capsule` and `drain_altar`. Earlier enemy, weapon, architectural-kit and texture outputs remain unchanged. Each manifest entry records the recipe hash that produced it; `build.script_sha256` identifies the latest recipe, not a claim that every older asset was regenerated. Source and output hashes always describe the actual files.

Blender saves editable `.blend` scenes under `source/art/`. Enemy and weapon pose collections remain separate. Rendering uses Cycles CPU, four threads and native pixel resolution. The final PNG writer quantizes the palette and emits binary alpha with nearest filtering; the player never invokes Blender. GLB heroes and supporting kit combine geometry by material and embed their buffers/textures. Their tracked Godot import settings keep images embedded and uncompressed, avoiding duplicate extracted images and pixel-art compression. See [Godot import configuration](https://github.com/godotengine/godot-docs/blob/master/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.rst).

Enemy sheets have eight directional columns and five 128-pixel pose rows: idle, walk A, walk B, attack and dead. Column zero is the front; foot baseline is row 119, documented origin `(64,120)`. Weapon sheets have three horizontal 320×200 frames: idle, fire and recover. World exports use Godot's Y-up conversion and ground-centered origins. The manifest is authoritative for each model's dimensions and triangle count.

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
