"""Verify the selected recordings and their retained originals without host audio tools."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest = json.loads((ROOT / "source/music/suno/manifest.json").read_text())
tracks = manifest["tracks"]
levels = ["intake", "foundry", "processional", "reliquary", "nursery", "ossuary", "inversion", "heart"]
assert [track["level"] for track in tracks] == levels
assert len({track["song_id"] for track in tracks}) == 8
for track in tracks:
    assert track["take"] == 1 and 180 < track["duration_seconds"] < 310
    original = ROOT / track["source_path"]
    runtime = ROOT / "game" / track["runtime_path"]
    assert original.stat().st_size == track["download_bytes"]
    assert runtime.stat().st_size == track["runtime_bytes"]
    assert hashlib.sha256(original.read_bytes()).hexdigest() == track["download_sha256"]
    assert hashlib.sha256(runtime.read_bytes()).hexdigest() == track["runtime_sha256"]
    assert track["codec"] == "mp3" and track["channels"] == 2
    assert (ROOT / "game/audio" / (track["level"] + ".mid")).exists()
print("PASS eight unique selected Suno takes, source/runtime hashes, level mapping and preserved MIDI sources")
