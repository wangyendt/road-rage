#!/usr/bin/env python3
"""Original synthetic start transponder and two phase-continuous emergency sirens.
No recordings/samples. Siren sweeps integrate instantaneous frequency; both 4 s
loops contain integer carrier/modulator periods, without a silence at the seam.
"""
import math
import wave
import struct
from pathlib import Path

RATE = 48000
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
TAU = math.tau

def save(name, length, sample):
    data = [max(-.95, min(.95, sample(i / RATE))) for i in range(round(length * RATE))]
    with wave.open(str(OUT / (name + '.wav')), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(struct.pack('<%dh' % len(data), *(round(x * 32767) for x in data)))
    print(name, 'peak', round(max(abs(x) for x in data), 3))

def siren(t, rate):
    # Horn diaphragm harmonics; carrier 980 Hz, 540–1420 Hz sweep.
    phase = TAU * 980 * t - (440 / rate) * math.cos(TAU * rate * t)
    horn = math.sin(phase) + .28 * math.sin(2 * phase) + .13 * math.sin(3 * phase)
    return .26 * horn * (.92 + .08 * math.cos(TAU * rate * t))

def cue(t, length, frequency):
    def dry(x):
        if x < 0 or x >= length - .08:
            return 0
        attack = min(1, x / .006)
        release = min(1, (length - .08 - x) / .06)
        return .30 * attack * release * (math.sin(TAU * frequency * x) + .18 * math.sin(TAU * frequency * 2 * x))
    return dry(t) + .13 * dry(t - .041) + .055 * dry(t - .073)

if __name__ == '__main__':
    save('siren', 4, lambda t: siren(t, .5))
    save('siren_yelp', 4, lambda t: siren(t, 4))
    save('count', .27, lambda t: cue(t, .27, 840))
    save('go', .65, lambda t: cue(t, .65, 1260))
    # Closing latch + two descending radio tones, distinct from a wreck sting.
    save('busted', 1.1, lambda t: .24 * math.sin(TAU * 160 * t) * math.exp(-t * 25)
         + (.14 * math.sin(TAU * (620 * min(t, .48) + 410 * max(0, t - .48)))
            * min(1, max(0, t - .18) * 40) * min(1, max(0, .88 - t) * 25)))
