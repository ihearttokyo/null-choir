# Editable descent illustration sources

Seven chapter illustrations use `prototype09/native/build01/descent.blend`; the Heart uses `heart74/native/build01/descent.blend`. Both are editable packed Blender library scenes named **NULL CHOIR descent**. Open the named scene when Blender reports a library-only file. Original native source blobs, recipes and their hash-bound build receipts are retained unchanged. `intro-architecture-inputs02/` supplies the exact pinned original GLB/texture dependencies, not substituted current exports. `heart74/DEPENDENCIES.json` records its Python import closure.

The runtime uses only eight compact JPEGs in `game/assets/art/descent/`; no Blender, source GLBs or 8K masters load during play. The source is project-owned under the repository LICENSE; existing asset and third-party notices remain applicable.

## Reproduce

From the repository root, with Blender installed, render one chapter at a time. Rendering is CPU2 at true7680×4320/64samples and refuses existing output files. Example:

```sh
blender --background --factory-startup --disable-autoexec --threads 2 --python-exit-code 1 --python source/art/descent/prototype09/producer.py -- render --bundle build01 --view intake --parent-released
```

Use views `intake`, `foundry`, `processional`, `reliquary`, `nursery`, `ossuary`, `inversion` on prototype09. The later Heart master used the heart74 scene and documented Metal/MetalRT-off authoring settings; CPU rerendering preserves editable geometry but is not promised byte-identical to that earlier GPU render. `MASTER-PINS.json` identifies the actual master candidates used for the shipped derivatives, rather than claiming cross-device render determinism.

To reproduce the runtime JPEGs, use Python with Pillow12.2.0 and an authoring-only JSON dictionary mapping each of the eight chapter IDs to its original master PNG path:

```sh
python3 tools/build_descent_runtime.py --masters /path/to/masters.json --output /path/to/fresh-output
```

This checks all master dimensions and SHA256 pins before encoding, then requires exact output SHA256 matches. It never overwrites existing output or modifies the masters. No private authoring paths belong in the repository manifest.

## Evidence limits

Native source reopen/edit/revert/privacy checks and isolated Mobile/Metal chart renders validate concrete technical properties only. The map retains accessible text and earned-only reveals. The artwork is a conceptual chapter descent, not a navigation floor plan. This candidate is not part of the already-published Alpha4 archive and does not close campaign, listening, physical-input, performance or final art acceptance.


## Authored title background (local candidate)

`render_title.py` renders the existing Heart74 **title** camera and its original visibility policy at1280×720/64samples/CPU2. This is a compact authoring render, not an8Kmaster. Run through background Blender with `-- --output /fresh/title.png`. Original packed source is checked before/after and never saved. `title-native.png` retains the actual resulting raster; `TITLE-PINS.json` binds its source blend, dimensions, render settings and640×360 runtime JPEG. The JPEG uses Pillow12.2.0/LANCZOS, quality90, optimizeTrue, without inherited metadata.

The HUD lazily owns that compact native texture for no-level menus, with a dark readability veil; original line art remains the fallback. Gameplay/HUD rendering and the existing title-music ownership are unchanged. Actual Mobile/Metal title/settings renders and native HUD/menu/title-audio checks cover the candidate; they do not establish final art approval or the cold-launch deadline. This does not add the remaining per-level intro flow or close campaign/performance/physical/listening acceptance.
