# Native forward-view Rivet pistol

This family contains actual native Blender-rendered pixels and their matching editable source. It is **not** the independently image-generated painted-v3 raster, and does not claim that the old painted-v3 images came from this source. All original v2 and painted-v3 art and provenance remain retained separately.

## Authoritative files

- `rivet_pistol.blend`: exact accepted editable source, SHA256 `99b0882a1b1b9bd1952668cfe645ad3c3a46327fe3d0fb4664341bf683420b56`.
- Runtime `game/assets/art/weapons/native-v4/rivet_pistol.png`: exact960x200atlas, SHA256 `9470e33b6c9a33127afb554a1848310c42d0cfd4bab1e05cbbe33a0495524618`.
- `frames/`: exact320x200idle/fire/recover native-pipeline pixels.
- `masters/`: uncompiled PNGs from the same three native draws, before the retained helper's quantized readback. These are not runtime bytes or independent generated illustrations.
- `registration.json` and `qualification.json`: source/atlas/pose/HUD bindings and honest evidence scope.
- `proof/`: actual static native HUD screenshots, source privacy/editability and actual saved-pose evidence. These are not gameplay screenshots.

The neutral actual barrel axis converges on atlas-local140,37 (logical screen reticle320,180). The finite muzzle/flash anchor remains local140,62 (screen320,205), with the existing320x200HUD destination at180,143. All three source poses retain the original recoil transforms and common finite muzzle pivot. No weapon damage, intervals, firing logic, head-bob or gameplay recoil code changes belong to this family.

The genuine detailed v2 mesh/material lineage is retained in `source/art/rivet_pistol_v2.blend` and `tools/build_rivet_pistol_v2.py`. The native-v4 source adds proper forward-axis camera alignment, a closed mechanical breech and connected sight line, plus scoped material finish. Original cage/glove fold/bore geometry remains editable. All source meshes are volumetric; there are no image-plane substitutes or current raster image textures.

## Portable export

Use Blender5.2.2 and the repository's exact `tools/build_art.py`, SHA256 `07c35732461226ee786f7f3f50b0617c5acf90368b8cd8668b6c996e13b45c5a`. The saved blend is sufficient authoring source for current art. Rebuilding every historical intermediate blend is not required.

The exporter defaults to source verification only. It checks the accepted source/helper hashes, actual reopened camera, three real mesh poses, neutral vanishing point and finite muzzle pivots. It writes only to a fresh explicit owned output directory. It never saves or edits the authoritative blend.

Example from a repository checkout, with an existing owned scratch directory:

```sh
blender --background --threads 2 --python-exit-code 1 \
  --python source/art/rivet-forward-v4/export_native.py -- \
  --repo . --source source/art/rivet-forward-v4/rivet_pistol.blend \
  --owned-output-root "$SCRATCH" --output "$SCRATCH/rivet-verify"
```

Add `--render` explicitly to authorize three native CPU renders. Rendering uses64samples,2threads, noGPU/denoising/bake and the exact retained31-step native-pixel quantization/hardalpha pipeline. Lights, world, scene color and original seed remain unchanged. The exporter retains raw same-draw images and compares the compiled atlas SHA to the exact accepted value. A mismatch stops acceptance; it is not silently substituted or rerendered. Run native jobs under an externally approved process/resource limit (the qualified runs used10seconds per frame and a40second process cap).

**Portable exporter native validation now PASS.** The first actual invocation of this same public `export_native.py --render` rendered all three64sample CPU poses and reproduced the accepted atlas byte-for-byte: SHA256 `9470e33b6c9a33127afb554a1848310c42d0cfd4bab1e05cbbe33a0495524618`. The accepted source remained unchanged. Actual camera/pose/muzzle/neutral-vanishing-point checks, frame hashes, public-relative command, timings and resource bounds are retained in `qualification.json` under `portable_export`. The earlier static-only/native-unrun statement was correct at packet preparation and is now superseded by this actual first-run result; the eight static/compiler tests remain separate evidence.

## Construction history and privacy

`construction/` retains the actual camera, solid repair, scoped material-stage code and before/after material graphs. Those historical utilities describe the original construction stages; some refer to intermediate relative job directories. Use the direct saved-source exporter above for present editing/export rather than treating byte-identical intermediate rebuilds as a prerequisite.

One read-only native open audited the exact accepted blend: no private absolute dependency/custom-string paths, external libraries, images or used image-texture nodes were found. Its own currently opened absolute `bpy.data.filepath` is explicitly excluded as necessary file identity, not an embedded dependency. The blend bytes were not modified for packaging.

Static HUD evidence used actual production `Hud._draw` and Player pose-clock methods with an injected texture, mock host, frozen head-bob/recoil and no Player scene-tree lifecycle. The retained fixture suppresses instrument chrome. It proves actual weapon/crosshair/separate-flash consumption, not physical input, gameplay, audio, full HUD/world appearance, performance or a packed application.

`ledger.json`, actual native import UID/sidecar and `native-import.json` are integration-owner outputs, deliberately absent from this source packet. Production import, current app/release and public delivery require their separate exact-file validation.
