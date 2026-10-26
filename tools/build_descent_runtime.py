"""Reproduce compact chapter illustrations from the exact retained master candidates."""
import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image, __version__

ROOT = Path(__file__).resolve().parents[1]


def encode(masters, manifest):
    if __version__ != "12.2.0":
        raise ValueError("Exact JPEG reproduction requires Pillow12.2.0")
    rows = manifest["masters"]
    if set(masters) != {row["view"] for row in rows}:
        raise ValueError("Supply exactly the eight named chapter masters")
    outputs = {}
    for row in rows:
        raw = Path(masters[row["view"]]).read_bytes()
        if hashlib.sha256(raw).hexdigest() != row["master_sha256"]:
            raise ValueError("Changed master: " + row["view"])
        with Image.open(io.BytesIO(raw)) as image:
            if image.format != "PNG" or image.size != tuple(manifest["master_size"]):
                raise ValueError("Expected true8K PNG: " + row["view"])
            output = io.BytesIO()
            image.convert("RGB").resize(tuple(manifest["runtime_size"]), Image.Resampling.LANCZOS).save(
                output, format="JPEG", quality=88, optimize=True)
        data = output.getvalue()
        if hashlib.sha256(data).hexdigest() != row["runtime_sha256"]:
            raise ValueError("JPEG encoder mismatch: " + row["view"])
        outputs[row["view"] + ".jpg"] = data
    return outputs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--masters", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads((ROOT / "source/art/descent/MASTER-PINS.json").read_text())
    masters = json.loads(args.masters.read_text())
    masters = {name: (args.masters.parent / path).resolve() for name, path in masters.items()}
    outputs = encode(masters, manifest) # Validate everything before creating output.
    args.output.mkdir(parents=True, exist_ok=False)
    for name, data in outputs.items():
        with (args.output / name).open("xb") as target:
            target.write(data)
    print("PASS eight exact compact chapter derivatives; original masters unchanged")


if __name__ == "__main__":
    main()
