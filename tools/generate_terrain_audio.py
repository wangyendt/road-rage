"""Reproducible original airflow and suspension/tyre landing sounds (stdlib only)."""
import math
import random
import struct
import wave
from pathlib import Path

out = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
sample_rate = 22050
for name, seconds in [('airflow', 3.0), ('landing', 0.58)]:
    rng = random.Random(401)
    filtered = 0.0
    frames = bytearray()
    for i in range(int(seconds * sample_rate)):
        t = i / sample_rate
        filtered = filtered * .91 + rng.uniform(-1, 1) * .09
        if name == 'airflow':
            envelope = .78 + .16 * math.sin(t * math.tau / seconds)
            value = filtered * 1.4 * envelope
        else:
            thud = math.sin(math.tau * (68 * t - 22 * t * t)) * math.exp(-t * 17)
            suspension = math.sin(math.tau * 115 * t) * math.exp(-t * 25)
            value = .38 * thud + .12 * suspension + filtered * .9 * math.exp(-t * 10)
        edge = min(1, t / .008, (seconds-t) / .008)
        frames += struct.pack('<h', int(max(-1, min(1, value * edge)) * 32767))
    with wave.open(str(out / (name + '.wav')), 'wb') as f:
        f.setparams((1, 2, sample_rate, 0, 'NONE', 'not compressed'))
        f.writeframes(frames)
