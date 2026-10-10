"""Isolated combat dispatch; optional parent-only real PNG/source acceptance."""
import argparse
import hashlib
import json
from pathlib import Path
import runpy
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
validate_recipe = runpy.run_path(str(ROOT / 'tools/art_recipe.py'))['validate_recipe']
recipe = runpy.run_path(str(ROOT / 'tools/build_late_combat_art.py'))
IDS = ('sawtooth_repeater', 'marrow_launcher', 'choir_disruptor',
       'brute', 'guardian', 'summoner', 'nursery_warden', 'choir_avatar')
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def check():
    with tempfile.TemporaryDirectory(prefix='combat-preservation-') as temp:
        receipt = Path(temp).resolve()
        output = receipt / 'native'
        target = output / 'game/assets/art/weapons/sawtooth_repeater.png'
        target.parent.mkdir(parents=True)
        target.write_bytes(b'accepted output must remain unchanged')
        before = sha(target)
        try:
            recipe['preflight'](IDS[0], output, receipt, ROOT)
        except FileExistsError:
            pass
        else:
            raise AssertionError('intended RED: existing candidate weapon output must be rejected before any write')
        assert sha(target) == before
    assert recipe['IDS'] == IDS
    for asset in IDS:
        opts = recipe['arguments'](['--asset', asset, '--output-root', '/private/tmp/combat/native',
                                    '--receipt-root', '/private/tmp/combat'])
        assert opts.asset == asset
    with tempfile.TemporaryDirectory(prefix='combat-roots-') as temp:
        receipt = Path(temp).resolve()
        output = receipt / 'native'
        assert recipe['preflight']('brute', output, receipt, ROOT) == (output, receipt)
        assert not output.exists(), 'preflight must not create files or directories'
        for out, rec in ((ROOT / 'builds/combat', ROOT / 'builds'), (output, output / 'receipts')):
            try:
                recipe['preflight']('brute', out, rec, ROOT)
            except ValueError:
                pass
            else:
                raise AssertionError('Reject production overlap and receipts nested beneath output')
        (output / 'game/assets/art').mkdir(parents=True)
        (output / 'alternate').mkdir()
        (output / 'game/assets/art/sprites').symlink_to(output / 'alternate', target_is_directory=True)
        try:
            recipe['preflight']('brute', output, receipt, ROOT)
        except ValueError:
            pass
        else:
            raise AssertionError('Reject internal candidate symlinks even when they remain within output')
    for target_path in ('source/art/brute.blend', 'previews/brute_contact.png',
                        'previews/frames/brute_0_0.png', 'game/assets/art/sprites/brute.png'):
        with tempfile.TemporaryDirectory(prefix='combat-target-') as temp:
            receipt = Path(temp).resolve()
            output = receipt / 'native'
            target = output / target_path
            target.parent.mkdir(parents=True)
            target.write_bytes(b'preserve')
            try:
                recipe['preflight']('brute', output, receipt, ROOT)
            except FileExistsError:
                pass
            else:
                raise AssertionError('Preserve every source, export and preview target')
            assert target.read_bytes() == b'preserve'
    print('PASS isolated eight-ID dispatch, fresh roots, symlink rejection and exact output preservation')


def check_candidates(receipt, assets):
    """Read actual outputs; this path never synthesizes art or invokes Blender."""
    read_png = runpy.run_path(str(ROOT / 'tests/test_art.py'))['png']
    digests = set()
    for asset in assets:
        candidate = json.loads((receipt / (asset + '_candidate.json')).read_text())
        entry = candidate['asset']
        output = Path(candidate['output_root']).resolve()
        assert output.is_relative_to(receipt.resolve()) and not output.is_relative_to(ROOT)
        assert entry['id'] == asset
        validate_recipe(ROOT, entry, 'tools/build_late_combat_art.py', recipe['DEPENDENCIES'])
        assert entry['provenance']['authoring_script'] == 'tools/build_late_combat_art.py'
        assert entry['reference_images'] == [recipe['reference'](asset)]
        assert sha(ROOT / entry['reference_images'][0]['path']) == entry['reference_images'][0]['sha256']
        source = output / entry['source']
        assert source.resolve().is_relative_to(output / 'source/art') and source.suffix == '.blend'
        assert source.read_bytes()[:7] == b'BLENDER' and sha(source) == entry['source_sha256']
        spec = recipe['SPECS'][asset]
        cw, ch = entry['cell_size']
        assert cw == ch == spec['cell'] if asset not in IDS[:3] else (cw, ch) == (320, 200)
        assert entry['columns'] == (3 if asset in IDS[:3] else 8)
        assert entry['frames'] == (['idle', 'fire', 'recover'] if asset in IDS[:3] else ['idle', 'walk_a', 'walk_b', 'attack', 'dead'])
        assert entry['pose_collections'] == entry['frames'] and entry['filter'] == 'nearest'
        assert entry['origin_px'] == ([160, 200] if asset in IDS[:3] else [cw // 2, ch - 8])
        assert set(candidate['poses']) == set(entry['frames'])
        assert candidate['pose_independence_verified'] is True
        for pose in candidate['poses'].values():
            assert 0 < pose['triangles'] <= spec['triangle_budget']
            assert len(pose['assemblies']) >= 4 and len(pose['meshes']) >= 50
        assert len(set(p['geometry_sha256'] for p in candidate['poses'].values())) == len(entry['frames'])
        assert len(entry['outputs']) == 1, 'runtime must contain only the sprite atlas, no author camera/light/collision'
        export = entry['outputs'][0]
        path = output / export['path']
        folder = 'weapons' if asset in IDS[:3] else 'sprites'
        assert path.resolve() == output / 'game/assets/art' / folder / (asset + '.png')
        assert sha(path) == export['sha256'] and path.stat().st_size == export['bytes'] <= spec['byte_budget']
        assert export['sha256'] not in digests, 'asset atlases must not be recolor copies'
        digests.add(export['sha256'])
        size, pixels = read_png(path)
        rows, columns = (1, 3) if asset in IDS[:3] else (5, 8)
        assert size == (columns * cw, rows * ch) == tuple(export['dimensions'])
        assert set(pixels[3::4]) == {0, 255}, 'unchanged crisp binary-alpha contract'
        cells = []
        for row in range(rows):
            for column in range(columns):
                cell = b''.join(pixels[((row * ch + y) * size[0] + column * cw) * 4:
                                      ((row * ch + y) * size[0] + (column + 1) * cw) * 4] for y in range(ch))
                assert sum(v != 0 for v in cell[3::4]) >= 80
                if asset in IDS[:3]:
                    assert not any(cell[3:24 * cw * 4:4]), 'weapons must leave the top24 pixels clear'
                else:
                    occupied = [y for y in range(ch) if any(cell[(y * cw + x) * 4 + 3] for x in range(cw))]
                    assert max(occupied) == ch - 9
                    assert min(occupied) > 0, 'native atlas may not clip the top of a pose'
                    if row == 4:
                        assert min(occupied) >= ch // 2, 'death must visibly collapse'
                cells.append(cell)
        assert len(set(cells)) == rows * columns, 'every actual directional pose/frame must be unique'
    print('PASS actual combat PNG/source/hash/pose/baseline/byte contracts; appearance remains a native inspection gate')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate-root', type=Path)
    parser.add_argument('--assets', nargs='+', choices=IDS, default=IDS)
    opts = parser.parse_args()
    check_candidates(opts.candidate_root, opts.assets) if opts.candidate_root else check()
