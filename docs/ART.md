# Blender art pipeline

The first Intake asset set is original geometry and authored pixel textures. No Doom, Alien, third-party character model or downloaded texture is included. `source/art/manifest.json` records editable sources, output hashes, origins, pose order, dimensions and loop identities. [DESIGN.md](../DESIGN.md) owns campaign-wide art acceptance; the present set covers Intake only.

Rebuild with the installed Blender:

```sh
blender -b -t 4 --python-exit-code 1 --python tools/build_art.py
```

For one asset, append `-- --asset worker` or another manifest identity. Freeze the recipe and stop other art writers before rendering. Python exceptions must produce a failed build; Blender's default exit behavior is insufficient. A rebuild replaces the generated scene/output for the selected identity, so preserve manual Blender edits before regenerating it.

Blender saves editable `.blend` scenes under `source/art/`. Enemy and weapon pose collections remain separate. Rendering uses Cycles CPU, four threads and native pixel resolution. The final PNG writer quantizes the palette and emits binary alpha with nearest filtering; the player never invokes Blender. GLB heroes and supporting kit combine geometry by material and embed their buffers/textures. Their tracked Godot import settings keep images embedded and uncompressed, avoiding duplicate extracted images and pixel-art compression. See [Godot import configuration](https://github.com/godotengine/godot-docs/blob/master/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.rst).

Enemy sheets have eight directional columns and five 128-pixel pose rows: idle, walk A, walk B, attack and dead. Column zero is the front; foot baseline is row 119, documented origin `(64,120)`. Weapon sheets have three horizontal 320×200 frames: idle, fire and recover. World exports use Godot's Y-up conversion and ground-centered origins. The manifest is authoritative for each model's dimensions and triangle count.

Run the direct contracts after rendering:

```sh
python3 tests/test_art.py
blender -b -t 4 --python-exit-code 1 --python tests/test_art_pose.py
```

The first verifies manifest/file parity, hashes, `.blend` provenance, self-contained GLB, PNG dimensions/alpha, distinct poses and foot baselines. The second proves that later authored poses cannot mutate earlier geometry. Neither check establishes visual quality. Contact renders in ignored `builds/art/` support inspection; in-game review and performance remain separate acceptance gates.
