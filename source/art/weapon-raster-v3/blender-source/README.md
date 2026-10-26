# Editable weapon design companions — matching-design review passed

These six Blender files contain original editable volumetric geometry authored against the six actual `../{weapon}/production-source-v1.png` references. They are **not** the source of the approved raster atlases. The runtime PNGs remain builtin-image-generator raster artwork, manually registered and extracted with native Godot. Neither their provenance nor their hashes changed.

`build_companions.py` retains editable glove/forearm/finger meshes from the preserved legacy `source/art/impact_tool.blend` as the coherent hand template for all six companions, rematerializes and re-poses those meshes onto each new grip, and authors the new weapon bodies. The other five original legacy models remain unchanged lineage references, not a claim of reused matching weapon bodies. It writes only this folder, performs no rendering/baking/simulation, and reopens each saved `.blend` to check actual meshes and the three named `V3_idle`, `V3_fire`, `V3_recover` collections. Legacy sources are never overwritten. Original hand-pose collections retain their original names and are independently editable; switch both the matching original hand collection and new V3 mechanism collection when inspecting a pose. New broad sleeve extensions and wrist wraps are in each matching V3 collection. Hand template transforms use the authored local matrix basis, not the identity evaluated world matrix of hidden legacy pose collections; every saved hand component is guarded against accidental enlargement.

## Explicit design correspondences

- Impact: broad dark strike anvil, two curved ivory side jaws, brass telescoping ram with pose-dependent compression, paired red return hoses and amber pressure slits.
- Rivet: long faceted steel barrel, three heat collars, twin curved ivory receiver straps, open brass bolt cage and a telescoping three-position bolt, rear cap and trigger guard.
- Scattergun: two distinct long barrels, open bronze barrel collars, translating paired breech pistons, central clasp, ivory cheeks and red hydraulic hoses.
- Sawtooth: asymmetric receiver, actual open slots between ivory spine rails/crossbars, seven individually modelled pointed cartridges on the right feed comb, two guide rails and translating bolt cylinder/carrier.
- Launcher: thick curved ivory shell petals with independently editable vertices, opening hinge actuators, genuinely hollow annular launch chamber, loaded idle sphere versus discharged chamber, ejection rod and recoil sled.
- Disruptor: three six-segment ivory resonator spines, two curved tapering bronze horns, diagonal braces, paired tuning eyes, violet core and pose-dependent compression rings.

## What this does not prove

Reopening and mesh counts establish substantive editability, not faithful final appearance. Actual selected-pose GLB export and native Godot 320×200 source views have now run (18 views; source files unchanged). Independent reference appearance acceptance and texture-match have not run. Source views use simple native lights and geometric PBR materials, not the approved raster as texture. These are structural design companions awaiting that review, **not a claim that the DESIGN editable-source requirement is fully closed**. Procedural materials encode steel/bronze/ivory/charcoal/hoses and small surface roughness; they do not reproduce all generated paint detail or gloves. They contain no reference-image plane, billboard, or raster-textured substitute for weapon geometry.

Run source-only from the canonical checkout with background Blender and one thread:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --threads 1 --python-exit-code 1 --python source/art/weapon-raster-v3/blender-source/build_companions.py
```

`source-validation.json` binds legacy model, actual reference and output hashes and actual reopen results. Initial validation found orphan legacy image materials; the corrected version rematerializes every retained hand and validates all **used** materials have no image nodes. Original failed logs/sources are retained outside the package in task-local review evidence. Runtime PNGs/PCK/accepted registration were untouched.

`export_source_views.py` reopens these actual saved blends and exports precisely the matching original pose collection recursively (including nested hand components) plus `V3_{pose}`. It emits only source-inspection GLBs, never runtime PNGs, and verifies original blend hashes unchanged. The initial direct-collection selector omitted nested hands; that preview batch is retained as invalid fixture evidence outside this package. Current technical preview batch passes without engine diagnostics; appearance remains unqualified.

## Source connection repair

The independent first source review rejected detached legacy hand coordinates, discontinuous receiver/grip junctions, and edge-on launcher petals. The repaired source re-seats inward-curled editable fingers on weapon-specific grips and adds continuous broad forearms; Rivet/Saw/Scatter have explicit downward/rear grip sockets continuous with their receivers. Launcher petals are thick broad curved shells around a real hollow chamber, with pose-dependent hinge rotation and actuator connections. Saved sources are sanitized using the approved `tools/build_art.py:sanitize_source_paths` RNA-buffer helper. All legacy image datablocks are removed; actual reopened image/packed-file/browser/render paths and custom string properties have zero private absolute paths.

The repaired actual-source previews pass technical native rendering checks, but independent matching-design review is still required. No runtime atlas, registration, extraction recipe, or PCK was changed by this repair.

## Matching-design verification
Six actual saved sources were reopened, exported as selected-pose geometry and viewed in an isolated native renderer (three poses each). Independent review confirmed connected grips/receivers and recognizable mechanism/pose correspondence to the retained production references. Source polish is frozen. Runtime PNGs and their original extraction provenance are unchanged. The source-only authoring/privacy checks are recorded in `source-validation.json`; the overview image and `matching-review.json` bind the final reviewed sources.
