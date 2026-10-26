"""Validate explicit same-camera geometry-ID raster; never infer IDs from alpha.

Code preparation only: this module ships no mask and never invokes Blender.
ID PNG must encode opaque (0,0,0,255) ordinary or (1,0,0,255) clutch.
Do not feed this a beauty image, silhouette, headbox or recolored concept.
"""
import argparse
import hashlib
import json
from pathlib import Path

WIDTH, HEIGHT, CELL = 1024, 768, 128
SCHEMA = 'null-choir-worker-regions-v1'
BEAUTY_PATH = 'res://assets/art/sprites/worker.png'
ALLOWED_BEAUTY_PATHS = frozenset((BEAUTY_PATH, 'res://assets/art/sprites/bodies-v1/worker.png'))
MASK_PATH = 'res://assets/art/regions/worker-clutch-v1.regions'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def frame_bytes(data, channels, frame):
    return b''.join(data[(y*WIDTH+frame % 8*CELL)*channels:
                         (y*WIDTH+frame % 8*CELL+CELL)*channels]
                    for y in range(frame//8*CELL, (frame//8+1)*CELL))


def validate(beauty, mask, manifest, beauty_resource_path=BEAUTY_PATH):
    """Pure RGBA/ID validator, also used for honest synthetic negative tests."""
    def require(condition, detail):
        if not condition:
            raise ValueError(detail)

    require(manifest.get('schema') == SCHEMA and manifest.get('kind') == 'worker', 'schema/kind')
    require((manifest.get('width'), manifest.get('height')) == (WIDTH, HEIGHT), 'dimensions')
    require((manifest.get('hframes'), manifest.get('vframes'), manifest.get('cell_size')) == (8, 6, [CELL, CELL]), 'atlas layout')
    require(manifest.get('vent_pose') == 5, 'explicit vent row')
    require(manifest.get('alpha_min_byte') == 128, 'alpha cutoff')
    require(manifest.get('regions') == {'0': 'ordinary', '1': 'pressure_clutch'}, 'region dictionary')
    require(beauty_resource_path in ALLOWED_BEAUTY_PATHS, 'unapproved beauty resource path')
    require(manifest.get('beauty_path') == beauty_resource_path and manifest.get('mask_path') == MASK_PATH, 'asset paths')
    for key in ['beauty_source_sha256', 'source_blend_sha256']:
        value = manifest.get(key)
        require(isinstance(value, str) and len(value) == 64 and all(c in '0123456789abcdef' for c in value), key)
    objects = manifest.get('authored_objects')
    require(isinstance(objects, list) and objects and all(isinstance(n, str) and n for n in objects), 'explicit authored object names')
    require(len(beauty) == WIDTH*HEIGHT*4 and len(mask) == WIDTH*HEIGHT, 'byte count')
    require(digest(beauty) == manifest.get('beauty_rgba_sha256'), 'beauty RGBA hash')
    require(digest(mask) == manifest.get('mask_sha256'), 'mask hash')
    frames = manifest.get('frames')
    require(isinstance(frames, list) and len(frames) == 48, '48 exact frame records')
    total = 0
    for frame, record in enumerate(frames):
        require(isinstance(record, dict) and (record.get('frame'), record.get('pose'), record.get('direction')) == (frame, frame//8, frame % 8), 'frame address')
        rgba = frame_bytes(beauty, 4, frame)
        ids = frame_bytes(mask, 1, frame)
        require(not set(ids)-{0, 1}, 'unknown material ID')
        accepted = sum(alpha >= 128 for alpha in rgba[3::4])
        labels = sum(ids)
        require(not labels or labels < accepted, 'strict per-frame subset')
        require(not any(region and alpha < 128 for region, alpha in zip(ids, rgba[3::4])), 'label outside exact accepted beauty alpha')
        require(frame < 32 or labels == 0, 'dead and vent poses must be ordinary')
        require(record.get('labels') == labels, 'frame label count')
        require(record.get('mask_sha256') == digest(ids) and record.get('beauty_rgba_sha256') == digest(rgba), 'frame content hash')
        total += labels
    require(total > 0, 'empty anatomy is disabled, not a shipping mask')
    return total


def make_manifest(beauty, mask, source_png, source_blend, authored_objects, beauty_resource_path=BEAUTY_PATH):
    manifest = dict(schema=SCHEMA, kind='worker', width=WIDTH, height=HEIGHT,
                    hframes=8, vframes=6, vent_pose=5, cell_size=[CELL, CELL], alpha_min_byte=128,
                    regions={'0': 'ordinary', '1': 'pressure_clutch'},
                    beauty_path=beauty_resource_path, mask_path=MASK_PATH,
                    beauty_source_sha256=digest(source_png), source_blend_sha256=digest(source_blend),
                    beauty_rgba_sha256=digest(beauty), mask_sha256=digest(mask),
                    authored_objects=authored_objects, frames=[])
    for frame in range(48):
        ids = frame_bytes(mask, 1, frame)
        manifest['frames'].append(dict(frame=frame, pose=frame//8, direction=frame % 8,
                                       labels=sum(ids), mask_sha256=digest(ids),
                                       beauty_rgba_sha256=digest(frame_bytes(beauty, 4, frame))))
    validate(beauty, mask, manifest, beauty_resource_path)
    return manifest


def ids_from_rgba(rgba):
    if len(rgba) != WIDTH*HEIGHT*4:
        raise ValueError('ID raster dimensions/byte count')
    mask = bytearray()
    for r, g, b, a in zip(rgba[0::4], rgba[1::4], rgba[2::4], rgba[3::4]):
        if r not in [0, 1] or (g, b, a) != (0, 0, 255):
            raise ValueError('ID raster must be exact opaque region bytes, no interpolation/AA/color guessing')
        mask.append(r)
    return bytes(mask)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--beauty', type=Path, required=True)
    parser.add_argument('--geometry-ids', type=Path, required=True)
    parser.add_argument('--source-blend', type=Path, required=True)
    parser.add_argument('--authored-object', action='append', required=True)
    parser.add_argument('--beauty-resource-path', choices=sorted(ALLOWED_BEAUTY_PATHS), default=BEAUTY_PATH,
                        help='Explicit allowed runtime resource; default retains legacy synthetic-test compatibility')
    parser.add_argument('--output-dir', type=Path, required=True,
                        help='Fresh staging directory only, never active runtime overwrite')
    args = parser.parse_args()
    if args.output_dir.exists():
        parser.error('output directory must be fresh (preserve originals)')
    from PIL import Image
    with Image.open(args.beauty) as image:
        if image.size != (WIDTH, HEIGHT):
            parser.error('beauty must be exact accepted 1024x768 atlas')
        beauty = image.convert('RGBA').tobytes()
    with Image.open(args.geometry_ids) as image:
        if image.size != (WIDTH, HEIGHT):
            parser.error('geometry-ID atlas must match beauty registration')
        mask = ids_from_rgba(image.convert('RGBA').tobytes())
    manifest = make_manifest(beauty, mask, args.beauty.read_bytes(),
                             args.source_blend.read_bytes(), args.authored_object, args.beauty_resource_path)
    # Source paths are deliberately omitted from the portable manifest.
    args.output_dir.mkdir(parents=True)
    (args.output_dir/'worker-clutch-v1.regions').write_bytes(mask)
    (args.output_dir/'worker-clutch-v1.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(json.dumps({'status': 'validated_explicit_ids_not_runtime_qualified',
                      'labels': sum(mask), 'mask_sha256': digest(mask)}))


if __name__ == '__main__':
    main()
