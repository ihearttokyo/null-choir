#!/usr/bin/env python3
"""Bounded, non-integrating ZIP intake. Technical candidacy is NOT visual approval."""
import argparse
import hashlib
import io
import json
import stat
import warnings
import zipfile
from pathlib import Path, PurePosixPath

from PIL import Image

REGULAR = ('crawler', 'worker', 'caster', 'brute', 'guardian', 'summoner')
BOSSES = ('nursery_warden', 'choir_avatar')
WEAPONS = ('impact_tool', 'rivet_pistol', 'scattergun', 'sawtooth_repeater', 'marrow_launcher', 'choir_disruptor')
CHAPTERS = ('title', 'the_intake', 'the_foundry', 'the_processional', 'the_reliquary', 'the_nursery', 'the_ossuary', 'the_inversion', 'the_heart')
ATLAS = {**{n: (1024, 640, 8, 5) for n in REGULAR},
         **{n: (2048, 1280, 8, 5) for n in BOSSES},
         **{n: (960, 200, 3, 1) for n in WEAPONS}}
MAX_FILES, MAX_ENTRY, MAX_TOTAL, MAX_RATIO = 256, 64 * 1024**2, 256 * 1024**2, 200
MAX_PIXELS = 40_000_000


class IntakeError(ValueError):
    pass


def sha(data):
    return hashlib.sha256(data).hexdigest()


def relative_label(value):
    p = PurePosixPath(value)
    if not value or '\\' in value or p.is_absolute() or ':' in value or any(x in ('', '.', '..') for x in value.split('/')):
        raise IntakeError('Expected a plain relative path label')
    return p.as_posix()


def classify(name):
    stem = PurePosixPath(name).stem.lower()
    if stem in ATLAS:
        return 'atlas', stem
    for index, chapter in enumerate(CHAPTERS):
        if stem == f'null_choir_{index:02d}_{chapter}':
            return 'painting', f'{index:02d}_{chapter}'
    return 'unclassified', None


def inspect_png(data, kind, asset):
    """Read pixels only: no resize, crop, conversion or generated replacement."""
    reasons = []
    try:
        with warnings.catch_warnings():
            warnings.simplefilter('error', Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data)) as im:
                if im.format != 'PNG':
                    return {'status': 'CONCEPT_ONLY', 'reasons': ['Payload is not PNG']}
                width, height = im.size
                if width * height > MAX_PIXELS:
                    raise IntakeError('Image exceeds pixel budget')
                im.verify()
            with Image.open(io.BytesIO(data)) as im:
                im.load()
                result = {'dimensions': list(im.size), 'mode': im.mode, 'native_8k': width >= 7680 and height >= 4320}
                if kind == 'painting':
                    if width < 640 or height < 360 or abs(width / height - 16 / 9) > .02:
                        reasons.append('Painting must be landscape approximately16:9 and at least640x360')
                    if im.getbbox() is None or im.getcolors(maxcolors=1) is not None:
                        reasons.append('Empty or uniform painting')
                elif kind == 'atlas':
                    w, h, columns, rows = ATLAS[asset]
                    result['contract'] = {'dimensions': [w, h], 'columns': columns, 'rows': rows, 'mode': 'RGBA'}
                    if im.size != (w, h):
                        reasons.append('Wrong atlas dimensions; resizing/cropping is not accepted')
                    if im.mode != 'RGBA' or data[24] != 8:
                        reasons.append('Atlas must have genuine RGBA alpha, not RGB/checkerboard')
                    if im.mode == 'RGBA' and im.size == (w, h):
                        alpha = im.getchannel('A')
                        low, high = alpha.getextrema()
                        if low != 0 or high != 255:
                            reasons.append('Atlas needs genuinely transparent and opaque pixels')
                        cell_w, cell_h = w // columns, h // rows
                        cells = []
                        for row in range(rows):
                            hashes = []
                            for col in range(columns):
                                box = (col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h)
                                cell = im.crop(box)  # inspection window only; never written as an asset
                                if cell.getchannel('A').getbbox() is None:
                                    reasons.append(f'Empty atlas cell row{row} column{col}')
                                hashes.append(sha(cell.tobytes()))
                            cells.append(hashes)
                            if columns == 8 and len(set(hashes)) == 1:
                                reasons.append(f'All eight directional views cloned in row{row}')
                        result['cell_pixel_sha256'] = cells
                else:
                    reasons.append('Unrecognized asset ID; no runtime contract assigned')
                result.update(status='TECHNICAL_CANDIDATE' if not reasons else 'CONCEPT_ONLY', reasons=reasons)
                return result
    except IntakeError:
        raise
    except (OSError, ValueError, SyntaxError, Image.DecompressionBombError, Image.DecompressionBombWarning):
        return {'status': 'CONCEPT_ONLY', 'reasons': ['PNG decode/integrity failure']}


def read_archive(archive):
    if Path(archive).stat().st_size > MAX_TOTAL + 16 * 1024**2:
        raise IntakeError('ZIP input exceeds bounded input budget')
    entries, names, total = [], set(), 0
    try:
        with zipfile.ZipFile(archive) as zf:
            if len(zf.infolist()) > MAX_FILES:
                raise IntakeError('Archive exceeds entry budget')
            for info in zf.infolist():
                raw = info.filename.rstrip('/') if info.is_dir() else info.filename
                name = relative_label(raw)
                folded = name.casefold()
                if folded in names:
                    raise IntakeError('Duplicate/case-colliding archive path')
                names.add(folded)
                mode = info.external_attr >> 16
                file_type = stat.S_IFMT(mode)
                if file_type not in (0, stat.S_IFREG, stat.S_IFDIR) or (file_type == stat.S_IFDIR and not info.is_dir()):
                    raise IntakeError('Symlinks and special archive entries are forbidden')
                if info.flag_bits & 1:
                    raise IntakeError('Encrypted ZIP unsupported')
                if info.is_dir():
                    continue
                total += info.file_size
                if info.file_size > MAX_ENTRY or total > MAX_TOTAL or info.file_size > max(1, info.compress_size) * MAX_RATIO:
                    raise IntakeError('Archive exceeds decompression budget')
                with zf.open(info) as stream:
                    data = stream.read(MAX_ENTRY + 1)  # ZIP reader checks CRC before EOF
                    if len(data) != info.file_size or len(data) > MAX_ENTRY or stream.read(1):
                        raise IntakeError('Archive size mismatch')
                entries.append((name, data))
    except (zipfile.BadZipFile, RuntimeError, NotImplementedError, EOFError) as exc:
        raise IntakeError('Invalid ZIP, unsupported compression, or CRC failure') from exc
    # A regular file cannot also be another member's parent.
    files = {name.casefold() for name, _ in entries}
    for name in files:
        if any(parent.as_posix() in files for parent in PurePosixPath(name).parents if parent.as_posix() != '.'):
            raise IntakeError('Archive file/directory collision')
    return entries


def ingest(archive, destination, repo_root, source_label=None):
    root = Path(repo_root).resolve(strict=True)
    destination = Path(destination)
    if not destination.is_absolute():
        destination = root / destination
    # Refuse symlink ancestors even if they happen to resolve inside the repo.
    cursor = destination
    while cursor != cursor.parent:
        if cursor.is_symlink():
            raise IntakeError('Destination has a symlink ancestor')
        cursor = cursor.parent
    destination = destination.resolve()
    if not destination.is_relative_to(root) or destination == root or destination.exists():
        raise IntakeError('Destination must be fresh and below repository root')
    archive = Path(archive)
    label = relative_label(source_label or ('external-input/' + archive.name))
    entries = read_archive(archive)
    records, seen_ids = [], set()
    for name, data in entries:
        kind, asset = classify(name)
        record = {'archive_member': name, 'retained_path': (destination.relative_to(root) / 'originals' / name).as_posix(),
                  'bytes': len(data), 'sha256': sha(data), 'kind': kind, 'asset_id': asset}
        if name.lower().endswith('.png'):
            record.update(inspect_png(data, kind, asset))
        else:
            record.update(status='CONCEPT_ONLY', reasons=['Retained supporting file, not validated runtime PNG'])
        if asset:
            if asset in seen_ids:
                raise IntakeError('Duplicate logical asset ID')
            seen_ids.add(asset)
        records.append(record)
    manifest = {'schema': 1, 'source': {'label': label, 'sha256': sha(archive.read_bytes())},
                'destination': destination.relative_to(root).as_posix(), 'records': records,
                'missing_atlas_ids': sorted(set(ATLAS) - seen_ids),
                'missing_painting_ids': [f'{i:02d}_{n}' for i, n in enumerate(CHAPTERS) if f'{i:02d}_{n}' not in seen_ids],
                'visual_9_plus': 'NOT_ASSESSED', 'integration': 'NONE; candidates retained only, no game files overwritten',
                'limitations': 'Technical checks cannot establish anatomy, animation correctness, physics/masks, false painted transparency, coherent views, runtime readability or visual9+ approval.'}
    # Nothing is written until archive/CRC/image checks and all target checks finish.
    destination.mkdir(parents=True, exist_ok=False)
    for name, data in entries:
        target = destination / 'originals' / name
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open('xb') as stream:
            stream.write(data)
    with (destination / 'manifest.json').open('x') as stream:
        json.dump(manifest, stream, indent=2)
        stream.write('\n')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('destination', help='Fresh repository-relative intake directory')
    parser.add_argument('--repo-root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--source-label', help='Public relative provenance label, never a private host path')
    args = parser.parse_args()
    try:
        manifest = ingest(args.archive, args.destination, args.repo_root, args.source_label)
    except (IntakeError, OSError) as exc:
        parser.exit(2, f'Intake rejected: {exc}\n')
    print(json.dumps({'manifest': manifest['destination'] + '/manifest.json',
                      'technical_candidates': sum(r['status'] == 'TECHNICAL_CANDIDATE' for r in manifest['records']),
                      'visual_9_plus': 'NOT_ASSESSED', 'integrated': False}))


if __name__ == '__main__':
    main()
