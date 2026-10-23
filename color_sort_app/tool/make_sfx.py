"""効果音(assets/sfx/*.wav)を合成して作る。外部の素材は使わない。
使い方: cd color_sort_app && python3 tool/make_sfx.py
"""
import math
import struct
import wave

SR = 22050


def tone(freqs, dur, vol=0.35, attack=0.005, decay=None, partial=0.0):
    n = int(SR * dur)
    decay = decay if decay is not None else dur / 3
    out = []
    for i in range(n):
        t = i / SR
        env = min(1, t / attack) * math.exp(-t / decay)
        s = 0
        for f in freqs:
            s += math.sin(2 * math.pi * f * t) + partial * math.sin(2 * math.pi * 2 * f * t)
        out.append(s / len(freqs) * env * vol)
    return out


def seq(parts):
    out = []
    for start, samples in parts:
        a = int(start * SR)
        if len(out) < a + len(samples):
            out += [0.0] * (a + len(samples) - len(out))
        for i, v in enumerate(samples):
            out[a + i] += v
    return out


def save(name, samples):
    f = int(0.01 * SR)  # 終わりは短くフェードして、プチ音を防ぐ
    for i in range(f):
        samples[-1 - i] *= i / f
    with wave.open(f'assets/sfx/{name}.wav', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, v)) * 32767)) for v in samples))


save('select', tone([660], 0.09, 0.3, decay=0.03))
pour = []
for i in range(int(SR * 0.16)):
    t = i / SR
    f = 720 - 1200 * t
    pour.append(math.sin(2 * math.pi * f * t) * math.exp(-t / 0.06) * 0.3 * min(1, t / 0.004))
save('pour', pour)
save('error', seq([(0, tone([196], 0.14, 0.3, decay=0.05)), (0.09, tone([175], 0.18, 0.28, decay=0.07))]))
save('win', seq([
    (0, tone([523.25], 0.5, 0.3, decay=0.18, partial=0.2)),
    (0.12, tone([659.25], 0.5, 0.3, decay=0.18, partial=0.2)),
    (0.24, tone([783.99], 0.55, 0.3, decay=0.2, partial=0.2)),
    (0.38, tone([1046.5], 0.9, 0.32, decay=0.35, partial=0.2)),
]))
save('place', seq([(0, tone([330], 0.1, 0.35, decay=0.03)), (0.06, tone([784, 988], 0.5, 0.22, decay=0.18, partial=0.15))]))
save('coin', seq([(0, tone([988], 0.2, 0.28, decay=0.07, partial=0.2)), (0.07, tone([1319], 0.4, 0.28, decay=0.16, partial=0.2))]))
