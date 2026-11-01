"""Makes the PCU Connect notification sound: an original, playful two-tone
chime of about one second (a short rising blip, then a brighter bell note).
Standard library only. Run from the repo root:
    python3 tool/sound/make_chime.py
Writes assets/sounds/notify.wav (22.05 kHz, mono, 16-bit).
"""
import math
import struct
import wave

RATE = 22050
LENGTH = 1.0  # seconds


def note(t, start, freq, glide, length, level):
    """A soft bell-like note: quick attack, exponential decay, a little
    upward glide and two gentle overtones."""
    x = t - start
    if x < 0 or x > length:
        return 0.0
    attack = min(1.0, x / 0.008)
    decay = math.exp(-x * 5.5 / length)
    f = freq * (1 + glide * min(1.0, x / 0.06))
    phase = 2 * math.pi * f * x
    tone = math.sin(phase) + 0.35 * math.sin(2 * phase) + 0.12 * math.sin(3.01 * phase)
    return level * attack * decay * tone / 1.47


def sample(t):
    # E6 then a bright A6, each sliding up a touch for a playful feel.
    s = note(t, 0.00, 1318.5, 0.03, 0.30, 0.55)
    s += note(t, 0.12, 1760.0, 0.02, 0.85, 0.70)
    # Fade out the very end so there is no click.
    tail = max(0.0, min(1.0, (LENGTH - t) / 0.05))
    return s * tail


frames = bytearray()
for i in range(int(RATE * LENGTH)):
    v = max(-1.0, min(1.0, sample(i / RATE)))
    frames += struct.pack('<h', int(v * 0.85 * 32767))

with wave.open('assets/sounds/notify.wav', 'wb') as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(bytes(frames))
print('assets/sounds/notify.wav', len(frames), 'bytes of audio')
