"""Optional untextured GLB UV-pruning candidate; not wired into production."""
import argparse
import json
from pathlib import Path
import struct

MAX_BYTES = 8 * 1024 * 1024


def require(condition, message):
    if not condition:
        raise ValueError(message)


def keys(item, allowed):
    require(isinstance(item, dict) and not item.keys() - set(allowed.split()),
            'Unsupported property, extension or reference')


def index(value, sequence):
    require(type(value) is int and 0 <= value < len(sequence), 'Invalid reference index')
    return sequence[value]


def object_pairs(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'Duplicate JSON property')
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError('Nonfinite JSON value: ' + value)


def prune_glb(data):
    """Drop UV streams only from the supported untextured, static mesh profile."""
    try:
        return _prune(data)
    except (KeyError, IndexError, TypeError, struct.error) as error:
        raise ValueError('Malformed or unsupported GLB') from error


def _prune(data):
    require(28 <= len(data) <= MAX_BYTES, 'GLB outside candidate size limit')
    require(struct.unpack_from('<4sII', data) == (b'glTF', 2, len(data)), 'Invalid GLB header')
    json_length, kind = struct.unpack_from('<I4s', data, 12)
    require(kind == b'JSON' and json_length % 4 == 0, 'Invalid JSON chunk')
    offset = 20 + json_length
    bin_length, kind = struct.unpack_from('<I4s', data, offset)
    require(kind == b'BIN\0' and bin_length % 4 == 0 and offset + 8 + bin_length == len(data),
            'Require exactly JSON and BIN chunks')
    document = json.loads(data[20:offset], object_pairs_hook=object_pairs, parse_constant=reject_constant)
    keys(document, 'asset scene scenes nodes materials meshes accessors bufferViews buffers')
    keys(document['asset'], 'version generator copyright')
    require(document['asset']['version'] == '2.0', 'Require glTF 2.0')
    binary = data[offset + 8:]
    require(len(document['buffers']) == 1, 'Require one embedded buffer')
    keys(document['buffers'][0], 'byteLength')
    size = document['buffers'][0]['byteLength']
    require(type(size) is int and 0 < size <= bin_length and bin_length - size < 4,
            'Invalid embedded buffer length')
    views, accessors = document['bufferViews'], document['accessors']
    require(views and len(views) == len(accessors), 'Require exclusive accessor views')
    spans = []
    for view in views:
        keys(view, 'buffer byteOffset byteLength target name')
        start, length = view.get('byteOffset', 0), view['byteLength']
        require(view['buffer'] == 0 and type(start) is int and type(length) is int and
                start >= 0 and start % 4 == 0 and length > 0 and start + length <= size,
                'Invalid buffer view range/alignment')
        spans.append((start, start + length))
    ordered = sorted(spans)
    require(all(a[1] <= b[0] for a, b in zip(ordered, ordered[1:])), 'Overlapping views')
    seen_views = set()
    for accessor in accessors:
        keys(accessor, 'bufferView byteOffset componentType count type min max normalized name')
        view = index(accessor['bufferView'], views)
        require(accessor['bufferView'] not in seen_views, 'Shared accessor view')
        seen_views.add(accessor['bufferView'])
        count = accessor['count']
        components = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3}.get(accessor['type'])
        width = {5121: 1, 5123: 2, 5125: 4, 5126: 4}.get(accessor['componentType'])
        require(components and width and type(count) is int and count > 0 and
                accessor.get('byteOffset', 0) == 0 and not accessor.get('normalized', False) and
                count * components * width == view['byteLength'], 'Unsupported accessor layout')
    for material in document['materials']:
        keys(material, 'name doubleSided alphaMode alphaCutoff emissiveFactor pbrMetallicRoughness')
        keys(material.get('pbrMetallicRoughness', {}), 'baseColorFactor metallicFactor roughnessFactor')
    meshes, nodes = document['meshes'], document['nodes']
    index(document.get('scene', 0), document['scenes'])
    for scene in document['scenes']:
        keys(scene, 'name nodes')
        for value in scene.get('nodes', []):
            index(value, nodes)
    for node in nodes:
        keys(node, 'name mesh children translation rotation scale matrix')
        if 'mesh' in node:
            index(node['mesh'], meshes)
        for value in node.get('children', []):
            index(value, nodes)
    removed, retained = set(), set()
    for mesh in meshes:
        keys(mesh, 'name primitives')
        for primitive in mesh['primitives']:
            keys(primitive, 'attributes indices material mode')
            require(primitive.get('mode', 4) == 4, 'Require triangles')
            index(primitive['material'], document['materials'])
            attributes = primitive['attributes']
            keys(attributes, 'POSITION NORMAL TEXCOORD_0 TEXCOORD_1')
            positions = index(attributes['POSITION'], accessors)
            indices = index(primitive['indices'], accessors)
            require(indices['type'] == 'SCALAR' and indices['componentType'] in (5121, 5123, 5125) and
                    indices['count'] % 3 == 0, 'Invalid triangle index stream')
            retained.add(primitive['indices'])
            for semantic, value in attributes.items():
                accessor = index(value, accessors)
                uv = semantic.startswith('TEXCOORD_')
                require(accessor['type'] == ('VEC2' if uv else 'VEC3') and
                        accessor['componentType'] == 5126 and accessor['count'] == positions['count'],
                        'Unsupported vertex stream')
                (removed if uv else retained).add(value)
    require(not removed & retained and removed | retained == set(range(len(accessors))),
            'Shared UV or unreferenced accessor')
    if not removed:
        return data
    kept = [i for i in range(len(accessors)) if i not in removed]
    mapping = {old: new for new, old in enumerate(kept)}
    packed, new_views, new_accessors = bytearray(), [], []
    for old in kept:
        accessor = dict(accessors[old])
        view = dict(views[accessor['bufferView']])
        start = view.get('byteOffset', 0)
        packed.extend(b'\0' * (-len(packed) % 4))
        view['byteOffset'] = len(packed)
        packed.extend(binary[start:start + view['byteLength']])
        accessor['bufferView'] = len(new_views)
        new_views.append(view)
        new_accessors.append(accessor)
    for mesh in meshes:
        for primitive in mesh['primitives']:
            primitive['indices'] = mapping[primitive['indices']]
            primitive['attributes'] = {k: mapping[v] for k, v in primitive['attributes'].items()
                                       if not k.startswith('TEXCOORD_')}
    document['accessors'], document['bufferViews'] = new_accessors, new_views
    document['buffers'][0]['byteLength'] = len(packed)
    encoded = json.dumps(document, separators=(',', ':'), ensure_ascii=False, allow_nan=False).encode()
    encoded += b' ' * (-len(encoded) % 4)
    packed.extend(b'\0' * (-len(packed) % 4))
    result = (struct.pack('<4sII', b'glTF', 2, 28 + len(encoded) + len(packed)) +
              struct.pack('<I4s', len(encoded), b'JSON') + encoded +
              struct.pack('<I4s', len(packed), b'BIN\0') + packed)
    require(len(result) < len(data), 'Candidate did not reduce size')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    target = args.output.absolute()
    require(not any(p.is_symlink() for p in (target, *target.parents)), 'Symlink output path')
    target = target.resolve()
    for path in (args.input.resolve(), Path(__file__).resolve()):
        for root in path.parents:
            if (root / '.git').exists() or (root / 'game/project.godot').is_file():
                require(not target.is_relative_to(root), 'Output must be outside the project')
                break
    with args.input.open('rb') as source:
        original = source.read(MAX_BYTES + 1)
    result = prune_glb(original)
    with target.open('xb') as output:
        output.write(result)
    print(f'Candidate bytes: {len(original)} -> {len(result)}; native acceptance pending')


if __name__ == '__main__':
    main()
