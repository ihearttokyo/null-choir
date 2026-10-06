"""Read-only, bounded source census; never read a GLB's BIN payload."""
from collections import Counter
from contextlib import ExitStack, contextmanager
import hashlib
import json
import math
import os
from pathlib import PurePosixPath
import re
import stat
import struct
import sys

MAPS = ("01_intake", "02_foundry", "03_processional", "04_reliquary",
        "05_nursery", "06_ossuary", "07_inversion", "08_heart")
SOURCE_PINS = {
    "game/scripts/level.gd": "fbeb3f64a587a999dd46b81d2b5b73cf8d477f82af500502810d97ca0d64dc35",
    "game/scripts/level_data.gd": "402f065c8b284b06b947aa4bedf1940e6f314538c3aa69f9fe4bfd2c08019758",
}
MAX_GLB = 4 * 1024 * 1024
MAX_JSON = 256 * 1024
MAX_MAP = 128 * 1024
MAX_MANIFEST = 1024 * 1024
MAX_SOURCE = 64 * 1024
MAX_NODES = 256
MAX_EXPORTS = 128
MAX_TILES = 4096
MAX_RECT_WORK = 65536
MAX_RECORDS = 2048
EXPANDED = ("mesh_node_references", "primitive_references",
            "position_element_references", "index_element_references", "triangle_slots")
CATEGORIES = ("hero", "scenery", "boundary_kit", "light_fixture", "fresh_marker")
ALLOWED_EXTENSION = "KHR_materials_emissive_strength"
ID = re.compile(r"[a-z][a-z0-9_]*\Z")


class CensusError(ValueError):
    """Unsupported, unsafe, malformed, changing or mismatched evidence."""


def require(condition, message):
    if not condition:
        raise CensusError(message)


def integer(value, label, minimum=0, maximum=2**32 - 1):
    require(type(value) is int and minimum <= value <= maximum, f"invalid integer: {label}")
    return value


def object_(value, label):
    require(type(value) is dict, f"object required: {label}")
    return value


def array(value, label, cap=MAX_RECORDS):
    require(type(value) is list and len(value) <= cap, f"array/cap: {label}")
    return value


def reference(value, records, label):
    return integer(value, label, maximum=len(records) - 1)


def identifier(value):
    require(type(value) is str and ID.fullmatch(value), "invalid asset/placement identifier")
    return value


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, f"duplicate JSON key: {key}")
        result[key] = value
    return result


def finite_float(value):
    result = float(value)
    require(math.isfinite(result), "nonfinite JSON number")
    return result


def parse_json(raw):
    def reject_constant(value):
        raise CensusError(f"nonfinite JSON constant: {value}")
    try:
        return json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object,
                          parse_constant=reject_constant, parse_float=finite_float)
    except (UnicodeError, ValueError, RecursionError) as exc:
        raise CensusError(f"invalid/deep JSON: {exc}") from exc


def path_parts(value, absolute=False):
    require(type(value) is str and value and "\\" not in value and "\0" not in value,
            "invalid path")
    path = PurePosixPath(value)
    require(path.is_absolute() == absolute and str(path) == value
            and ".." not in path.parts and "." not in path.parts
            and not value.startswith("//"), "noncanonical/traversing path")
    return path.parts[1:] if absolute else path.parts


def resident(info):
    require(not (getattr(info, "st_flags", 0) & getattr(stat, "SF_DATALESS", 0x40000000)),
            "resident evidence required; hydration forbidden")


def stamp(info):
    return (info.st_dev, info.st_ino, info.st_mode, info.st_uid, info.st_nlink,
            info.st_size, info.st_mtime_ns, info.st_ctime_ns, getattr(info, "st_flags", 0))


def open_directory(parent, name, stack, links):
    before = os.stat(name, dir_fd=parent, follow_symlinks=False)
    resident(before)
    require(stat.S_ISDIR(before.st_mode), "nonsymlink directory required")
    child = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_NONBLOCK,
                    dir_fd=parent)
    stack.callback(os.close, child)
    info = os.fstat(child)
    resident(info)
    require(stamp(before) == stamp(info), "directory changed before open")
    links.append((parent, name, child))
    return child


def check_directories(links):
    for parent, name, child in links:
        current = os.stat(name, dir_fd=parent, follow_symlinks=False)
        resident(current)
        held = os.fstat(child)
        require(stat.S_ISDIR(current.st_mode)
                and (current.st_dev, current.st_ino) == (held.st_dev, held.st_ino),
                "directory path replaced")


@contextmanager
def root_directory(path):
    parts = path_parts(path, absolute=True)
    with ExitStack() as stack:
        fd = os.open("/", os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        stack.callback(os.close, fd)
        links = []
        for name in parts:
            fd = open_directory(fd, name, stack, links)
        before = os.fstat(fd)
        resident(before)
        yield fd, {"path": path, "device": before.st_dev, "inode": before.st_ino}
        check_directories(links)
        require(stamp(os.fstat(fd)) == stamp(before), "root changed during census")


@contextmanager
def source_file(root, path, limit):
    parts = path_parts(path)
    with ExitStack() as stack:
        directory, links = root, []
        for name in parts[:-1]:
            directory = open_directory(directory, name, stack, links)
        before = os.stat(parts[-1], dir_fd=directory, follow_symlinks=False)
        resident(before)
        require(stat.S_ISREG(before.st_mode) and before.st_nlink == 1,
                "regular nonsymlink, nonaliased file required")
        require(0 < before.st_size <= limit, f"file byte cap: {path}")
        fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
        stream = stack.enter_context(os.fdopen(fd, "rb", buffering=0))
        info = os.fstat(fd)
        resident(info)
        require(stamp(info) == stamp(before), f"file changed before read: {path}")
        yield stream, info
        current = os.stat(parts[-1], dir_fd=directory, follow_symlinks=False)
        resident(current)
        require(stamp(os.fstat(fd)) == stamp(info) == stamp(current),
                f"file changed during read: {path}")
        check_directories(links)


def exact_read(stream, size):
    data = stream.read(size)
    require(len(data) == size, "truncated metadata read")
    return data


def read_glb(stream, file_bytes):
    integer(file_bytes, "GLB bytes", 28, MAX_GLB)
    require(stream.tell() == 0, "GLB reader must start at offset zero")
    header = exact_read(stream, 12)
    magic, version, length = struct.unpack("<4sII", header)
    require((magic, version, length) == (b"glTF", 2, file_bytes), "GLB header/length mismatch")
    json_header = exact_read(stream, 8)
    size, kind = struct.unpack("<I4s", json_header)
    require(kind == b"JSON" and 0 < size <= MAX_JSON and size % 4 == 0
            and 28 + size <= file_bytes, "unsupported JSON chunk layout/cap")
    raw = exact_read(stream, size)
    bin_header = exact_read(stream, 8)
    bin_bytes, kind = struct.unpack("<I4s", bin_header)
    require(kind == b"BIN\0" and bin_bytes % 4 == 0 and 28 + size + bin_bytes == file_bytes,
            "unsupported BIN chunk layout/length")
    report = analyze_glb(parse_json(raw), bin_bytes)
    report.update(file_bytes=file_bytes, json_chunk_bytes=size, bin_chunk_bytes=bin_bytes,
                  metadata_sha256=hashlib.sha256(header + json_header + raw + bin_header).hexdigest(),
                  metadata_digest_scope="header+JSON-header+JSON-payload+BIN-header",
                  full_binary_verified=False)
    return report


def check_profile(g, materials):
    require(object_(g.get("asset"), "asset").get("version") == "2.0", "glTF 2.0 required")
    require(not any(key in g for key in ("animations", "skins", "cameras")),
            "unsupported animation/skin/camera records")
    for key in ("extensionsUsed", "extensionsRequired"):
        for name in array(g.get(key, []), key):
            require(name == ALLOWED_EXTENSION, f"unsupported extension: {name}")
    material_ids = {id(material) for material in materials}
    pending = [(g, 0)]
    while pending:
        value, depth = pending.pop()
        require(depth <= 32, "JSON nesting cap")
        if type(value) is dict:
            require("uri" not in value, "external/URI resources unsupported")
            if "extensions" in value:
                ext = object_(value["extensions"], "extensions")
                require(id(value) in material_ids and set(ext) <= {ALLOWED_EXTENSION},
                        "unsupported extension location/name")
            pending.extend((v, depth + 1) for v in value.values())
        elif type(value) is list:
            pending.extend((v, depth + 1) for v in value)


def analyze_glb(g, bin_bytes):
    object_(g, "GLB JSON")
    nodes = array(g.get("nodes"), "nodes", MAX_NODES)
    meshes = array(g.get("meshes"), "meshes", MAX_EXPORTS)
    materials = array(g.get("materials"), "materials")
    require(nodes and meshes and materials, "nonempty nodes/meshes/materials required")
    for material in materials:
        object_(material, "material")
    check_profile(g, materials)
    buffers = array(g.get("buffers"), "buffers", 1)
    require(len(buffers) == 1, "one embedded buffer required")
    buffer_bytes = integer(object_(buffers[0], "buffer").get("byteLength"), "buffer length", 1)
    require(buffer_bytes <= bin_bytes <= buffer_bytes + 3, "buffer/BIN length mismatch")
    views = array(g.get("bufferViews"), "bufferViews")
    accessors = array(g.get("accessors"), "accessors")
    for view in views:
        object_(view, "bufferView")
        require(integer(view.get("buffer"), "view buffer") == 0, "invalid buffer reference")
        offset = integer(view.get("byteOffset", 0), "view offset")
        length = integer(view.get("byteLength"), "view length", 1)
        require(offset + length <= buffer_bytes, "bufferView span exceeds buffer")
        if "byteStride" in view:
            stride = integer(view["byteStride"], "stride", 4, 252)
            require(stride % 4 == 0, "unaligned stride")
    widths = {5121: 1, 5123: 2, 5125: 4, 5126: 4}
    arities = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
    for accessor in accessors:
        object_(accessor, "accessor")
        require("sparse" not in accessor, "sparse accessors unsupported")
        view = views[reference(accessor.get("bufferView"), views, "accessor view")]
        component = integer(accessor.get("componentType"), "component type")
        kind = accessor.get("type")
        require(component in widths and type(kind) is str and kind in arities,
                "unsupported accessor layout")
        count = integer(accessor.get("count"), "accessor count", 1)
        offset = integer(accessor.get("byteOffset", 0), "accessor offset")
        width = widths[component]
        size = width * arities[kind]
        stride = view.get("byteStride", size)
        require(stride >= size and stride % width == 0 and offset % width == 0
                and (view.get("byteOffset", 0) + offset) % width == 0,
                "invalid accessor stride/alignment")
        require(offset + (count - 1) * stride + size <= view["byteLength"],
                "accessor span exceeds bufferView")
    position_ids, index_ids, primitive_total, mesh_stats = set(), set(), 0, []
    attribute_types = {"POSITION": "VEC3", "NORMAL": "VEC3", "TANGENT": "VEC4",
                       "TEXCOORD_0": "VEC2", "TEXCOORD_1": "VEC2"}
    for mesh in meshes:
        object_(mesh, "mesh")
        require("weights" not in mesh, "morph weights unsupported")
        primitives = array(mesh.get("primitives"), "primitives")
        require(primitives, "nonempty primitives required")
        primitive_total += len(primitives)
        require(primitive_total <= MAX_RECORDS, "primitive cap")
        row = {key: 0 for key in EXPANDED}
        used = set()
        for primitive in primitives:
            object_(primitive, "primitive")
            require("targets" not in primitive, "morph targets unsupported")
            require(integer(primitive.get("mode", 4), "primitive mode") == 4,
                    "only indexed triangle lists supported")
            attrs = object_(primitive.get("attributes"), "attributes")
            require("POSITION" in attrs, "POSITION required")
            for semantic, value in attrs.items():
                require(semantic in attribute_types, f"unsupported attribute: {semantic}")
                a = accessors[reference(value, accessors, "attribute accessor")]
                require(a["componentType"] == 5126 and a["type"] == attribute_types[semantic]
                        and not a.get("normalized", False), "unsupported attribute format")
            p = reference(attrs["POSITION"], accessors, "POSITION accessor")
            i = reference(primitive.get("indices"), accessors, "index accessor")
            a = accessors[i]
            require(a["type"] == "SCALAR" and a["componentType"] in (5121, 5123, 5125)
                    and not a.get("normalized", False)
                    and "byteStride" not in views[a["bufferView"]], "unsupported index format")
            require(a["count"] % 3 == 0, "index count not divisible by three")
            require(all(accessors[value]["count"] == accessors[p]["count"] for value in attrs.values()),
                    "attribute count mismatch")
            m = reference(primitive.get("material"), materials, "primitive material")
            position_ids.add(p)
            index_ids.add(i)
            used.add(m)
            row["primitive_references"] += 1
            row["position_element_references"] += accessors[p]["count"]
            row["index_element_references"] += a["count"]
            row["triangle_slots"] += a["count"] // 3
        mesh_stats.append((row, used))
    parents, children = set(), []
    for node in nodes:
        object_(node, "node")
        require("skin" not in node and "weights" not in node, "skin/morph node unsupported")
        if "mesh" in node:
            reference(node["mesh"], meshes, "node mesh")
        child_ids = array(node.get("children", []), "children", MAX_NODES)
        for value in child_ids:
            child = reference(value, nodes, "child node")
            require(child not in parents, "repeated child/multiple parents")
            parents.add(child)
        children.append(child_ids)
    reached = 0
    pending = [n for n in range(len(nodes)) if n not in parents]
    while pending:
        n = pending.pop()
        reached += 1
        pending.extend(children[n])
    require(reached == len(nodes), "node cycle")
    scenes = array(g.get("scenes"), "scenes", 1)
    require(len(scenes) == 1 and integer(g.get("scene", 0), "default scene") == 0,
            "one default scene required")
    roots = array(object_(scenes[0], "scene").get("nodes"), "scene roots", MAX_NODES)
    seen, pending, used_materials = set(), list(roots), set()
    for value in roots:
        n = reference(value, nodes, "scene root")
        require(n not in parents, "scene root also has a parent")
    require(len(set(roots)) == len(roots), "repeated scene roots")
    scene = {key: 0 for key in EXPANDED}
    while pending:
        n = pending.pop()
        require(n not in seen, "repeated reachable node")
        seen.add(n)
        pending.extend(children[n])
        if "mesh" in nodes[n]:
            row, used = mesh_stats[nodes[n]["mesh"]]
            scene["mesh_node_references"] += 1
            for key in EXPANDED[1:]:
                scene[key] += row[key]
            used_materials.update(used)
    scene.update(reachable_nodes=len(seen), used_materials=len(used_materials))
    images = array(g.get("images", []), "images")
    intervals = []
    for image in images:
        object_(image, "image")
        view = views[reference(image.get("bufferView"), views, "image view")]
        require(image.get("mimeType") in ("image/png", "image/jpeg"), "unsupported image MIME")
        start = view.get("byteOffset", 0)
        intervals.append((start, start + view["byteLength"]))
    encoded, end = 0, 0
    for start, stop in sorted(intervals):
        encoded += max(0, stop - max(start, end))
        end = max(end, stop)
    return {"declared_buffer_bytes": buffer_bytes, "encoded_image_view_bytes": encoded,
            "stored": {"mesh_definitions": len(meshes), "primitive_definitions": primitive_total,
                       "material_definitions": len(materials), "image_definitions": len(images),
                       "position_accessor_elements": sum(accessors[i]["count"] for i in position_ids),
                       "index_accessor_elements": sum(accessors[i]["count"] for i in index_ids)},
            "scene": scene}


def placements(data):
    object_(data, "map")
    records = {key: array(data.get(key), key) for key in
               ("rects", "heroes", "scenery", "lights", "pickups", "interactions")}
    require(len(records["rects"]) <= MAX_NODES, "rectangle cap")
    work, rectangles = 0, []
    for rect in records["rects"]:
        require(type(rect) is list and len(rect) == 4, "four-coordinate rectangle required")
        x0, z0, x1, z1 = [integer(v, "rectangle coordinate", -1000000, 1000000) for v in rect]
        require(x0 <= x1 and z0 <= z1, "reversed rectangle")
        area = (x1 - x0 + 1) * (z1 - z0 + 1)
        work += area
        require(area <= MAX_TILES and work <= MAX_RECT_WORK, "rectangle expansion cap")
        rectangles.append((x0, z0, x1, z1))
    tiles = set()
    for x0, z0, x1, z1 in rectangles:
        for x in range(x0, x1 + 1):
            for z in range(z0, z1 + 1):
                tiles.add((x, z))
                require(len(tiles) <= MAX_TILES, "union tile cap")
    boundary = sum((x + dx, z + dz) not in tiles for x, z in tiles
                   for dx, dz in ((-1, 0), (1, 0), (0, -1), (0, 1)))
    counts = {}
    def add(asset, category, count=1):
        identifier(asset)
        if count:
            counts.setdefault(asset, Counter())[category] += count
    add("ribbed_wall", "boundary_kit", boundary)
    add("conduit", "boundary_kit", boundary)
    for spec in records["heroes"]:
        add(object_(spec, "hero").get("id"), "hero")
    for spec in records["scenery"]:
        add(object_(spec, "scenery").get("art"), "scenery")
    for spec in records["lights"]:
        if "fixture_yaw" in object_(spec, "light"):
            add("lumen_sconce", "light_fixture")
    for spec in records["pickups"] + records["interactions"]:
        identifier(object_(spec, "marker").get("id"))
        add("containment_capsule", "fresh_marker")
    require(len(counts) <= MAX_EXPORTS, "referenced export cap")
    return {"tile_count": len(tiles), "boundary_edges": boundary,
            "assets": {asset: {key: value.get(key, 0) for key in CATEGORIES}
                       for asset, value in sorted(counts.items())}}


def census(project_root):
    verified, hashes = {}, {}
    with root_directory(project_root) as (root, identity):
        def read_text(path, limit):
            with source_file(root, path, limit) as (stream, info):
                raw = exact_read(stream, info.st_size)
                verified[path] = (stamp(info), limit)
                hashes[path] = {"sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw)}
                return raw
        for path, pin in SOURCE_PINS.items():
            read_text(path, MAX_SOURCE)
            require(hashes[path]["sha256"] == pin, f"placement source pin drift: {path}")
        manifest = object_(parse_json(read_text("source/art/manifest.json", MAX_MANIFEST)), "manifest")
        require(type(manifest.get("schema_version")) is int and manifest["schema_version"] == 1,
                "manifest schema 1 required")
        assets, outputs = {}, set()
        for entry in array(manifest.get("assets"), "manifest assets"):
            object_(entry, "manifest asset")
            asset = identifier(entry.get("id"))
            require(asset not in assets, "duplicate manifest ID")
            for output in array(entry.get("outputs"), "outputs"):
                object_(output, "output")
                path = output.get("path")
                path_parts(path)
                require(path.startswith("game/assets/art/") and path not in outputs,
                        "escaping/duplicate output ownership")
                outputs.add(path)
            assets[asset] = entry
        levels, referenced = [], set()
        for name in MAPS:
            path = f"game/data/{name}.json"
            data = object_(parse_json(read_text(path, MAX_MAP)), "map")
            require(data.get("id") == name.split("_", 1)[1], f"map identity mismatch: {path}")
            level = placements(data)
            level.update(id=data["id"], path=path)
            levels.append(level)
            referenced.update(level["assets"])
        require(len(referenced) <= MAX_EXPORTS, "campaign referenced export cap")
        measured = {}
        for asset in sorted(referenced):
            require(asset in assets, f"missing manifest asset: {asset}")
            entry = assets[asset]
            path = f"game/assets/art/world/{asset}.glb"
            exports = [o for o in entry["outputs"] if o["path"].endswith(".glb")]
            require(len(exports) == 1 and exports[0]["path"] == path,
                    f"exact single GLB output required: {asset}")
            output = exports[0]
            with source_file(root, path, MAX_GLB) as (stream, info):
                report = read_glb(stream, info.st_size)
                verified[path] = (stamp(info), MAX_GLB)
            for declared, actual in ((output.get("bytes"), report["file_bytes"]),
                                     (entry.get("triangles"), report["scene"]["triangle_slots"]),
                                     (entry.get("runtime_mesh_nodes"), report["stored"]["mesh_definitions"]),
                                     (entry.get("material_count"), report["stored"]["material_definitions"])):
                require(integer(declared, f"manifest numeric parity: {asset}") == actual,
                        f"manifest numeric mismatch: {asset}")
            claimed = output.get("sha256")
            require(type(claimed) is str and re.fullmatch(r"[0-9a-f]{64}", claimed),
                    "invalid claimed full-file hash")
            report.update(path=path, manifest_claimed_full_sha256=claimed, manifest_numeric_parity=True)
            measured[asset] = report
        for level in levels:
            total = {key: 0 for key in EXPANDED}
            storage, placement_count = 0, 0
            for asset, categories in level["assets"].items():
                count = sum(categories.values())
                expanded = {key: measured[asset]["scene"][key] * count for key in EXPANDED}
                level["assets"][asset] = {"placements_by_source": categories, "placements": count,
                                          "expanded_scene": expanded}
                placement_count += count
                storage += measured[asset]["file_bytes"]
                for key in EXPANDED:
                    total[key] += expanded[key]
            level["totals"] = {"distinct_exports": len(level["assets"]),
                               "unique_file_bytes": storage, "placements": placement_count,
                               "expanded_scene": total}
        for path, (initial, limit) in verified.items():
            with source_file(root, path, limit) as (_, info):
                require(stamp(info) == initial, f"evidence changed after read: {path}")
        result = {"schema_version": 1, "status": "complete", "evidence_kind": "source_metadata_only",
                  "placement_semantics": "pinned_level_fresh_removed_empty_v1", "root": identity,
                  "source_evidence": hashes, "assets": measured, "levels": levels,
                  "full_binary_verified": False, "runtime_measured": False}
    return result


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    try:
        require(len(argv) == 2 and argv[0] == "--project-root",
                "usage: scenery_cost.py --project-root /absolute/resident/project")
        report = census(argv[1])
        code = 0
    except (CensusError, OSError, RecursionError) as exc:
        report = {"schema_version": 1, "status": "error", "error": str(exc)}
        code = 2
    print(json.dumps(report, sort_keys=True, indent=2, allow_nan=False))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
