"""Validate the actual ammo source, selected image, atlas and manifest ownership."""
import hashlib
import json
from pathlib import Path
from test_art import EXPECTED, png, validate_forward_recipe

ROOT = Path(__file__).resolve().parents[1]

def check():
    manifest = json.loads((ROOT / 'source/art/manifest.json').read_bytes())
    assert {entry['id'] for entry in manifest['assets']} == EXPECTED
    entries = [entry for entry in manifest['assets'] if entry['id'] == 'ammo_vfx']
    assert len(entries) == 1
    entry = entries[0]
    validate_forward_recipe(ROOT, entry)
    assert hashlib.sha256((ROOT / entry['source']).read_bytes()).hexdigest() == entry['source_sha256']
    assert (ROOT / entry['source']).read_bytes()[:7] == b'BLENDER'
    for reference in entry['reference_images']:
        assert hashlib.sha256((ROOT / reference['path']).read_bytes()).hexdigest() == reference['sha256']
    output, = entry['outputs']
    path = ROOT / output['path']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == output['sha256']
    assert path.stat().st_size == output['bytes'] <= 512 * 1024
    size, pixels = png(path)
    assert size == (256, 256) and output['dimensions'] == [256, 256]
    assert entry['cell_size'] == [64, 64] and entry['columns'] == 4 and entry['filter'] == 'nearest'
    assert set(pixels[3::4]) == {0, 255}
    coverage = []
    for row in range(4):
        for column in range(4):
            occupied = [(x, y) for y in range(64) for x in range(64)
                        if pixels[((row * 64 + y) * 256 + column * 64 + x) * 4 + 3]]
            assert occupied and all(4 <= x < 60 and 4 <= y < 60 for x, y in occupied)
            coverage.append(len(occupied))
    assert coverage == entry['frame_alpha_pixels']
    assert all(actual >= floor for actual, floor in zip(coverage[12:], [133, 152, 169, 185]))
    print('PASS actual ammo art: source/reference/recipe pins, manifest ownership, 16 frames and gutters')

if __name__ == '__main__':
    check()
