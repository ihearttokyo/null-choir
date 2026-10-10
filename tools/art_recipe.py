"""Resolve recorded authoring generations offline; never execute archive files."""
import hashlib
from pathlib import Path, PurePosixPath
import re


def resolve_recipe(root, logical, digest):
    if not isinstance(logical, str) or not isinstance(digest, str):
        raise ValueError('Recipe path and SHA-256 must be strings')
    relative = PurePosixPath(logical)
    if (relative.as_posix() != logical or len(relative.parts) != 2 or relative.parts[0] != 'tools'
            or relative.suffix != '.py' or '\\' in logical or not re.fullmatch('[0-9a-f]{64}', digest)):
        raise ValueError('Require a logical tools/*.py path and lowercase SHA-256')
    root = Path(root).absolute()
    if any(p.is_symlink() for p in (root, *root.parents)):
        raise ValueError('Symlinked recipe root')
    current = root / logical
    archived = root / 'source/art/recipe_history' / digest / (logical + '.txt')
    for path in (current, archived):
        if any(p.is_symlink() for p in (path, *path.parents)):
            raise ValueError('Symlinked recipe path: ' + str(path))
        if path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == digest:
            return path
    raise ValueError('Missing or modified recipe generation: ' + logical + ' @ ' + digest)


def validate_recipe(root, entry, script, dependencies=()):
    assert entry['provenance']['authoring_script'] == script
    resolve_recipe(root, script, entry['recipe_sha256'])
    recorded = entry.get('recipe_dependencies', {})
    assert set(recorded) == set(dependencies), 'recipe dependency inventory'
    for logical, digest in recorded.items():
        resolve_recipe(root, logical, digest)
