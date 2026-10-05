# Scenery source census

Run with an explicitly authorized, resident project root:

```sh
python3 -B tools/scenery_cost.py --project-root /absolute/resident/project
python3 -B -m unittest discover -s tests -p test_scenery_cost.py -v
```

JSON goes to stdout: exit 0 means complete source evidence;
exit 2 returns an error object without partial totals. It never saves files,
imports art, runs an engine, or discovers a fallback root. Tests generate tiny
fixtures beside the test module's project root; importing tests runs no tests.

Eight fixed maps use pinned builder semantics with `removed=[]`:
heroes use `id`, scenery uses `art`, every union-tile boundary places a ribbed
wall and conduit, `fixture_yaw` presence adds a sconce, and every pickup or
interaction adds a capsule. Loop/religion metadata adds no placement. Other
map behavior and procedural geometry are outside this adapter.

Stored POSITION/index accessor elements are deduplicated by accessor index.
Scene counts preserve mesh-bearing node and primitive occurrences. Level
totals expand scene counts by placement while counting export file bytes once.
`runtime_mesh_nodes` retains the manifest's mesh-definition meaning. Numeric
manifest parity is required; claimed full-file hashes remain unverified.

Unbuffered GLB header/JSON/BIN-header reads occur. The metadata digest
identifies those bytes, excluding BIN payload. The supported profile is one
static scene with indexed triangle lists and embedded buffers/images; only
the retained emissive-strength material extension is accepted. Unsupported
features, unsafe paths, changing evidence, duplicate keys and bounds errors
fail closed. Source-pin drift requires reviewed counting rules and tests.

This is not a general glTF validator or performance measurement. Counts cannot
prove BIN contents, rendered triangles, LOD, draw calls, sharing, load time,
RSS, VRAM, texture dimensions, visual quality or resource lifetime. Nothing
here authorizes asset, import, gameplay or native-runtime changes.
