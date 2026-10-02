"""Original finite gameplay cues: editable recipe, PCM safety and exact parity."""
import hashlib
import importlib.util
import io
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RECIPE = ROOT / 'tools/compose_effects.py'


def main():
    assert RECIPE.exists(), 'Original gameplay effects need an editable deterministic recipe'
    loader = importlib.util.spec_from_file_location('compose_effects', RECIPE)
    module = importlib.util.module_from_spec(loader)
    loader.loader.exec_module(module)
    required = {'tool', 'rivet', 'scatter', 'dry', 'flesh', 'impact',
                'crawler_charge', 'worker_charge', 'caster_charge',
                'stagger', 'death', 'seal_release'}
    assert set(module.EFFECTS) == required
    hashes = set()
    for name in sorted(required):
        data = module.compose(name)
        assert data == module.compose(name) == (ROOT / f'game/audio/effects/{name}.wav').read_bytes()
        with wave.open(io.BytesIO(data), 'rb') as sound:
            assert (sound.getnchannels(), sound.getsampwidth(), sound.getframerate()) == (1, 2, 22050)
            assert 0.04 <= sound.getnframes() / 22050 <= 0.8
            samples = struct.unpack('<' + 'h' * sound.getnframes(), sound.readframes(sound.getnframes()))
        assert abs(samples[0]) <= 100 and abs(samples[-1]) <= 100, 'Envelopes close without a hard seam'
        peak = max(abs(x) for x in samples) / 32768
        rms = math.sqrt(sum(x*x for x in samples) / len(samples)) / 32768
        assert 0.02 <= peak <= 0.8 and 0.005 <= rms <= 0.4, 'Non-silent cues retain mix headroom'
        hashes.add(hashlib.sha256(data).hexdigest())
    assert len(hashes) == len(required), 'Distinct event cues cannot share one placeholder waveform'
    print('PASS original gameplay cue recipe, finite mono PCM, closed envelopes, headroom and deterministic asset parity')


if __name__ == '__main__':
    main()
