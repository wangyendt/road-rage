"""Original synthesized nonverbal rider grunts and flexible-weapon swish.
No speech recordings or external audio assets. Standard library only.
"""
import math
import random
import struct
import wave
from pathlib import Path

out = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
sr = 22050
for index in range(4):
    rng = random.Random(410 + index)
    name = f'pain{index}' if index < 3 else 'whip'
    duration = [.32, .28, .36, .38][index]
    frames = bytearray()
    low_noise = 0.0
    phase = 0.0
    for i in range(int(duration * sr)):
        t = i / sr
        u = t / duration
        noise = rng.uniform(-1, 1)
        low_noise = .82 * low_noise + .18 * noise
        if index < 3:
            # Harmonic glottal source filtered by broad vowel-formant weights.
            f0 = [119, 146, 101][index] * (1.13 - .35 * u)
            phase += math.tau * f0 / sr
            formants = [(550, 1100), (670, 1330), (470, 950)][index]
            value = 0.0
            for harmonic in range(1, 18):
                f = harmonic * f0
                gain = (.22 / harmonic + .24 * math.exp(-((f-formants[0])/260)**2)
                        + .10 * math.exp(-((f-formants[1])/360)**2))
                value += gain * math.sin(phase * harmonic)
            envelope = (1-math.exp(-t*95)) * math.exp(-u*4.5)
            value = (value + low_noise * .5) * envelope * .68
        else:
            value = (noise-low_noise) * (math.sin(math.pi*u)**3) * .16
            value += noise * .35 * math.exp(-((u-.65)/.025)**2)
        edge = min(1, t/.005, (duration-t)/.01)
        frames += struct.pack('<h', int(max(-.95, min(.95, value * edge)) * 32767))
    with wave.open(str(out/(name+'.wav')), 'wb') as f:
        f.setparams((1, 2, sr, 0, 'NONE', 'not compressed'))
        f.writeframes(frames)
