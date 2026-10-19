"""Check actual candidate bytes; geometry and game appearance need separate native evidence."""
import hashlib
import json
from pathlib import Path
from PIL import Image
from test_art import validate_forward_recipe

ROOT = Path(__file__).resolve().parents[1]
CANDIDATE = ROOT
NAMES = ('heart','shield','impact_tool','rivet_pistol','scattergun','sawtooth_repeater',
         'marrow_launcher','choir_disruptor','seal_blood','seal_ivory','seal_empty',
         'story_empty','story_filled','ammo','frame_corner','frame_tile',
         'slot_base','slot_selected','lock','dry','low_health','divider')


def check(candidate=CANDIDATE):
    runtime = candidate/'game/assets/art/hud'
    metadata = json.loads((runtime/'hud_kit.json').read_bytes())
    image = Image.open(runtime/'hud_kit.png').convert('RGBA')
    assert image.size == (512,192)
    assert sum(p.stat().st_size for p in runtime.iterdir() if p.is_file()) <= 1024*1024
    assert set(metadata['sprites']) == set(NAMES)
    assert metadata['filter'] == 'nearest' and metadata['clear_border'] == 4
    for name, spec in metadata['sprites'].items():
        x,y,w,h = spec['region']
        assert w == h == 64 and x % 64 == y % 64 == 0
        assert 0 <= x <= 448 and 0 <= y <= 128
        cell = image.crop((x,y,x+w,y+h))
        alpha = cell.getchannel('A')
        assert set(alpha.getdata()) == {0,255}, name
        box = alpha.getbbox()
        assert box and box[0] >= 4 and box[1] >= 4 and box[2] <= 60 and box[3] <= 60, (name,box)
        assert [box[0],box[1],box[2]-box[0],box[3]-box[1]] == spec['content_rect']
        assert sum(a > 0 for a in alpha.getdata()) == spec['alpha_pixels']
    silhouettes = []
    for name in NAMES[2:8]:
        x,y,w,h = metadata['sprites'][name]['region']
        silhouettes.append(image.crop((x,y,x+w,y+h)).getchannel('A').tobytes())
    assert len(set(silhouettes)) == 6
    entry, = [a for a in json.loads((candidate/'source/art/manifest.json').read_bytes())['assets'] if a['id']=='hud_kit']
    validate_forward_recipe(candidate, entry)
    assert hashlib.sha256((candidate/entry['source']).read_bytes()).hexdigest() == entry['source_sha256']
    assert (candidate/entry['source']).read_bytes()[:7] == b'BLENDER'
    for output in entry['outputs']:
        path = candidate/output['path']
        assert path.stat().st_size == output['bytes']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == output['sha256']
    for ref in entry['reference_images']:
        assert hashlib.sha256((candidate/ref['path']).read_bytes()).hexdigest() == ref['sha256']
    assert metadata['native_render'] is True and metadata['render_threads'] == 2
    assert metadata['scene_collection_names'] == list(NAMES)
    print('PASS actual HUD atlas/source/recipe/reference hashes, 22 sprites, native alpha/gutters, six different silhouettes and <=1MiB runtime')


if __name__ == '__main__':
    check()
