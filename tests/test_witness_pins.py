"""Keep explicit native-witness source dependencies bound to current files."""
from pathlib import Path
import hashlib
import re
import tempfile


def check(game):
    for source in game.rglob('*.gd'):
        if '.godot' in source.parts:
            continue
        text = source.read_text()
        constants = dict(re.findall(r'const\s+(\w+)\s*=\s*"([0-9a-f]{64})"', text))
        pins = re.findall(r'"(res://[^"\n]+)"\s*:\s*"([0-9a-f]{64})"', text)
        for target, name in re.findall(r'FileAccess\.get_sha256\("(res://[^"\n]+)"\)\s*==\s*(\w+)', text):
            if name in constants:
                pins.append((target, constants[name]))
        for target, expected in pins:
            actual = hashlib.sha256((game / target.removeprefix('res://')).read_bytes()).hexdigest()
            assert actual == expected, f'{source.name}: stale witness pin for {target}'


def main():
    with tempfile.TemporaryDirectory() as temporary:
        game = Path(temporary)
        (game / 'target.gd').write_text('original')
        sha = hashlib.sha256(b'original').hexdigest()
        for binding in [f'const PINS = {{"res://target.gd":"{sha}"}}',
                        f'const SHA = "{sha}"\nfunc guard(): return FileAccess.get_sha256("res://target.gd") == SHA']:
            (game / 'witness.gd').write_text(binding)
            check(game)
            (game / 'target.gd').write_text('changed')
            try:
                check(game)
            except AssertionError as error:
                assert 'stale witness pin for res://target.gd' in str(error)
            else:
                raise AssertionError('Changed dependency must fail the pin check')
            (game / 'target.gd').write_text('original')
    check(Path(__file__).resolve().parents[1] / 'game')
    print('PASS explicit witness dictionary/positive-constant source pins; no dynamic GDScript or earned-route claim')


if __name__ == '__main__':
    main()
