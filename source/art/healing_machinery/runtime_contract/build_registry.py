#!/usr/bin/env python3
"""Portable healing registry recipe. Default --check is read-only.

Run from any directory. --stdout emits the exact frozen JSON; --output PATH
creates a fresh file only, never overwrites. Requires existing Pillow for PNG
RGBA8 decoding; no install, renderer, game engine or asset mutation is performed.
This reproduces a SOURCE contract, not native importer or visual acceptance.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

from PIL import Image

if __package__:
    from .render_contract import render_hash, quant
else:
    from render_contract import render_hash, quant

# Historical private-kit provenance anchor retained in the already reviewed
# runtime registry. It is NOT the public source tree's current SHA manifest.
HISTORICAL_KIT_MANIFEST_SHA256 = "9efc3cb43fa47d65b3666b4b924a26e034e617b0dd086afc5de635207ddf853f"
MATERIALS = ["dark_iron", "ivory", "brass", "crimson_glass", "blue_glass",
             "green_glass", "amber_glass", "dark_cavity", "oxidized_steel",
             "parchment", "control_markings", "bone", "red_fluid", "pale_fluid",
             "gasket", "hazard_stripe"]
RUNTIME_ROOT = "res://assets/art/healing_machinery/"
RENDER_CONVENTION = "position/UV signed-half-away1e-4; normal float32octUNORM16; colorRGBA8trunc; sourceCCWtoCW; trianglecyclic+ordercanonical"


def repository_root():
    return Path(__file__).resolve().parents[4]


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def read_accessor(document, buffer, index):
    accessor = document["accessors"][index]
    view = document["bufferViews"][accessor["bufferView"]]
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    code = {5126: "f", 5125: "I"}[accessor["componentType"]]
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    if view.get("byteStride") or accessor.get("sparse"):
        raise ValueError("Frozen source recipe requires its authored packed accessors")
    values = struct.unpack_from("<" + code * accessor["count"] * width, buffer, offset)
    return ([values[i:i + width] for i in range(0, len(values), width)]
            if width > 1 else list(values))


def shape_hash(positions, indices):
    rows = []
    for i in range(0, len(indices), 3):
        triangle = sorted(",".join(str(quant(v)) for v in positions[j])
                          for j in indices[i:i + 3])
        rows.append("|".join(triangle))
    return sha256("\n".join(sorted(rows)).encode())


def source_scene(path):
    document = json.loads(path.read_text())
    if document["buffers"][0]["uri"] != path.stem + ".bin":
        raise ValueError("Unexpected source buffer URI")
    return document, path.with_suffix(".bin").read_bytes()


def build_registry(repo=None):
    repo = Path(repo) if repo is not None else repository_root()
    source = repo / "source/art/healing_machinery"
    runtime = repo / "game/assets/art/healing_machinery"
    atlas = (source / "raw/texture-atlas.png").read_bytes()
    if atlas != (runtime / "raw/texture-atlas.png").read_bytes():
        raise ValueError("Editable/runtime atlas identities differ")
    registry = {
        "schema": "null-choir-healing-machinery-v1",
        "kitManifestSHA256": HISTORICAL_KIT_MANIFEST_SHA256,
        "atlasPath": RUNTIME_ROOT + "raw/texture-atlas.png",
        "atlasSHA256": sha256(atlas),
        "materials": MATERIALS,
        "families": {},
    }
    with Image.open(source / "raw/texture-atlas.png") as image:
        rgba = image.convert("RGBA")
        registry["atlasPixels"] = {
            "width": rgba.width, "height": rgba.height, "format": "RGBA8",
            "baseLevelSHA256": sha256(rgba.tobytes()),
        }
    registry["renderConvention"] = RENDER_CONVENTION
    paths = sorted((source / "models").glob("*.gltf"))
    if len(paths) != 8:
        raise ValueError("Exactly eight editable source families are required")
    for path in paths:
        document, buffer = source_scene(path)
        glb = path.with_suffix(".glb").read_bytes()
        if glb != (runtime / "models" / (path.stem + ".glb")).read_bytes():
            raise ValueError("Editable/runtime GLB identity differs: " + path.stem)
        spec = {"path": RUNTIME_ROOT + "models/" + path.stem + ".glb",
                "sourceGLBSHA256": sha256(glb), "nodes": {}}
        fixed_positions, fixed_indices = [], []
        for node in document["nodes"]:
            pin = ["", 0, -1]
            if "mesh" in node:
                primitive = document["meshes"][node["mesh"]]["primitives"][0]
                attributes = primitive["attributes"]
                positions = read_accessor(document, buffer, attributes["POSITION"])
                indices = read_accessor(document, buffer, primitive["indices"])
                normals = read_accessor(document, buffer, attributes["NORMAL"])
                uvs = read_accessor(document, buffer, attributes["TEXCOORD_0"])
                colors = read_accessor(document, buffer, attributes["COLOR_0"])
                pin = [render_hash(positions, normals, uvs, colors, indices),
                       len(indices) // 3, primitive["material"]]
                if node["name"] not in ["StockVolume", "StockNeedle"]:
                    offset = len(fixed_positions)
                    translation = node.get("translation", [0, 0, 0])
                    scale = node.get("scale", [1, 1, 1])
                    fixed_positions.extend(tuple(v[j] * scale[j] + translation[j]
                                                 for j in range(3)) for v in positions)
                    fixed_indices.extend(index + offset for index in indices)
            if "translation" in node or "scale" in node:
                pin.append(node.get("translation", [0, 0, 0]))
            if "scale" in node:
                pin.append(node["scale"])
            if node["name"] == "StockVolume":
                spec["stock"] = node["extras"]["stockBounds"]
            spec["nodes"][node["name"]] = pin
        spec["fixedSHA256"] = shape_hash(fixed_positions, fixed_indices)
        spec["fixedTriangles"] = len(fixed_indices) // 3
        registry["families"][path.stem] = spec
    return registry


def registry_bytes(repo=None):
    return (json.dumps(build_registry(repo), separators=(",", ":")) + "\n").encode()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--check", action="store_true", help="read-only exact check (default)")
    modes.add_argument("--stdout", action="store_true", help="emit exact registry bytes")
    modes.add_argument("--output", type=Path, help="write a fresh file only; never overwrite")
    args = parser.parse_args(argv)
    expected = registry_bytes()
    if args.stdout:
        sys.stdout.buffer.write(expected)
    elif args.output:
        # Exclusive creation is intentional; an existing output is never truncated.
        with args.output.open("xb") as stream:
            stream.write(expected)
    else:
        actual = (repository_root() / "game/data/healing_machinery_registry.json").read_bytes()
        if actual != expected:
            raise ValueError("Runtime registry differs from the portable source recipe")
        print("HEALING_MACHINERY_SOURCES exact source registry PASS (native unrun)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
