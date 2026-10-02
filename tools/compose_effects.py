#!/usr/bin/env python3
"""Bake original industrial/organic gameplay cues with Python's standard library."""
import io
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# Duration, starting/ending pitch, filtered-noise share, peak scale.
EFFECTS = {
    'tool': (0.18, 170, 38, 0.45, 0.62),
    'rivet': (0.11, 560, 90, 0.36, 0.60),
    'scatter': (0.28, 135, 38, 0.80, 0.74),
    'dry': (0.06, 1800, 800, 0.80, 0.32),
    'flesh': (0.15, 185, 52, 0.70, 0.54),
    'impact': (0.12, 2400, 780, 0.32, 0.48),
    'crawler_charge': (0.25, 65, 165, 0.60, 0.45),
    'worker_charge': (0.45, 210, 850, 0.18, 0.38),
    'caster_charge': (0.70, 105, 420, 0.08, 0.42),
    'stagger': (0.10, 330, 45, 0.66, 0.46),
    'death': (0.32, 145, 24, 0.64, 0.56),
    'seal_release': (0.60, 190, 570, 0.18, 0.45),
}


def compose(name):
    duration, first, last, noise_share, scale = EFFECTS[name]
    count = round(duration * 22050)
    rng = random.Random(name)
    phase = noise = 0.0
    samples = []
    for i in range(count):
        progress = i / (count - 1)
        phase += 2 * math.pi * (first * (last / first) ** progress) / 22050
        noise += (rng.uniform(-1, 1) - noise) * 0.48
        tone = (math.sin(phase) + 0.35 * math.sin(phase * 1.4142)) / 1.35
        envelope = min(1, i / 66) * (1 - progress) ** 1.8
        value = ((1 - noise_share) * tone + noise_share * noise) * envelope * scale
        samples.append(round(value * 32767))
    output = io.BytesIO()
    with wave.open(output, 'wb') as sound:
        sound.setparams((1, 2, 22050, count, 'NONE', 'not compressed'))
        sound.writeframes(struct.pack('<' + 'h' * count, *samples))
    return output.getvalue()


if __name__ == '__main__':
    destination = ROOT / 'game/audio/effects'
    destination.mkdir(exist_ok=True)
    for name in EFFECTS:
        path = destination / (name + '.wav')
        path.write_bytes(compose(name))
        print(f'COMPOSE_EFFECT_GREEN: {name}: {path.stat().st_size} bytes')
