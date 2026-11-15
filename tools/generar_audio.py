# Sonidos y música de NaSA-GAME, sintetizados desde cero (sin muestras de terceros).
import numpy as np, wave, os, subprocess
SR = 22050
OUT = 'out'; os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(42)

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, r=0.1, total=None):
    """Envolvente ataque/caída exponencial."""
    x = np.ones(n)
    na = max(1, int(SR * a)); x[:na] = np.linspace(0, 1, na)
    nr = max(1, int(SR * r)); x[-nr:] *= np.linspace(1, 0, nr) ** 2
    return x
def sine(f, d, ph=0): return np.sin(2 * np.pi * f * t(d) + ph)
def sweep(f0, f1, d):
    ff = np.linspace(f0, f1, int(SR * d)); return np.sin(2 * np.pi * np.cumsum(ff) / SR)
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def lowpass(x, cut):
    # Filtro de un polo (suave).
    a = np.exp(-2 * np.pi * cut / SR); y = np.zeros_like(x); acc = 0.0
    for i, v in enumerate(x): acc = (1 - a) * v + a * acc; y[i] = acc
    return y
def highpass(x, cut): return x - lowpass(x, cut)
def echo(x, delay=0.12, fb=0.35, n=4):
    y = np.concatenate([x, np.zeros(int(SR * delay * n))]); d = int(SR * delay)
    for k in range(1, n + 1): y[d * k:d * k + len(x)] += x * (fb ** k)
    return y
def save(name, x, gain=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    with wave.open(f'{OUT}/{name}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
def cat(*xs): return np.concatenate(xs)
def pad(x, d): return cat(x, np.zeros(int(SR * d)))
def note(f, d, a=0.005, r=None, harm=(1, 0.3, 0.1)):
    s = sum(h * sine(f * (i + 1), d) for i, h in enumerate(harm)); return s * env(len(s), a, r or d * 0.9)

# --- Interfaz ---
save('ui_click', note(1400, 0.05, 0.001, 0.045, (1, 0.2)), 0.5)
save('ui_open', cat(note(660, 0.07, r=0.06), note(990, 0.12, r=0.11)), 0.5)
save('ui_close', cat(note(990, 0.07, r=0.06), note(660, 0.12, r=0.11)), 0.5)
# --- Base ---
w = lowpass(noise(0.7), 900) * env(int(SR * 0.7), 0.05, 0.5); w += 0.4 * sweep(220, 120, 0.7) * env(int(SR * 0.7), 0.02, 0.6)
save('door', w, 0.6)
save('console', echo(cat(note(880, 0.08), note(1320, 0.14)), 0.09, 0.3, 3), 0.55)
a = cat(*[sweep(700, 950, 0.25) * env(int(SR * 0.25), 0.01, 0.05) for _ in range(2)], *[sweep(950, 700, 0.25) * env(int(SR * 0.25), 0.01, 0.05) for _ in range(2)])
save('alarm', a + 0.3 * np.sign(a) * 0.3, 0.6)
# --- Minijuegos ---
save('hit', echo(cat(note(1047, 0.07), note(1568, 0.18)), 0.08, 0.3, 3), 0.6)
save('miss', (sweep(220, 140, 0.3) + 0.5 * np.sign(sine(110, 0.3))) * env(int(SR * 0.3), 0.005, 0.15), 0.55)
save('success', echo(cat(*[note(f, 0.11) for f in (523, 659, 784)], note(1047, 0.45)), 0.11, 0.3, 4), 0.65)
save('fail', cat(*[note(f, 0.16, harm=(1, 0.5, 0.3)) for f in (392, 330)], note(262, 0.5, harm=(1, 0.5, 0.3))), 0.6)
sp = np.zeros(int(SR * 0.45))
for _ in range(40):
    i = rng.integers(0, len(sp) - 400); sp[i:i + 300] += rng.uniform(-1, 1, 300) * np.linspace(1, 0, 300) * rng.uniform(0.3, 1)
save('spark', highpass(sp, 1500), 0.7)
save('steam', highpass(noise(0.9), 2500) * env(int(SR * 0.9), 0.03, 0.7), 0.5)
pl = lowpass(noise(0.06), 3000) * env(int(SR * 0.06), 0.001, 0.05) + 0.6 * sine(180, 0.06) * env(int(SR * 0.06), 0.001, 0.05)
save('plug', pad(pl, 0.05), 0.7)
save('water', sum(sweep(rng.uniform(300, 700), rng.uniform(900, 1500), 0.08) * env(int(SR * 0.08), 0.005, 0.06) * 0.0 + 0 for _ in range(1)) + cat(*[pad(sweep(rng.uniform(300, 600), rng.uniform(900, 1400), 0.06) * env(int(SR * 0.06), 0.004, 0.05), rng.uniform(0.02, 0.08)) for _ in range(7)])[:int(SR * 0.6)] if False else cat(*[pad(sweep(rng.uniform(300, 600), rng.uniform(900, 1400), 0.06) * env(int(SR * 0.06), 0.004, 0.05), rng.uniform(0.02, 0.08)) for _ in range(7)]), 0.5)
# --- Taller del rover ---
cl = lowpass(noise(0.12), 2500) * env(int(SR * 0.12), 0.001, 0.1) + 0.8 * note(140, 0.12, 0.001, 0.11, (1, 0.6, 0.4))
save('snap', cat(cl, note(1760, 0.08, r=0.07) * 0.3), 0.7)
save('wrong', cat(*[pad((sine(150, 0.12) + 0.6 * np.sign(sine(75, 0.12))) * env(int(SR * 0.12), 0.003, 0.04), 0.05) for _ in range(2)]), 0.55)
# --- Despegue ---
save('countdown', note(1000, 0.12, 0.002, 0.1, (1, 0.1)), 0.55)
d = 5.0; ru = lowpass(noise(d), 160) * 3 + lowpass(noise(d), 600) * 0.6
ru *= np.minimum(1, t(d) / 1.2) * np.linspace(1, 0.85, len(ru)); ru *= env(len(ru), 0.01, 0.5)
save('liftoff', ru, 0.85)
lp = lowpass(noise(4.0), 220) * 3 + lowpass(noise(4.0), 700) * 0.5
xf = int(SR * 0.4); lp[:xf] *= np.linspace(0, 1, xf); lp[-xf:] *= np.linspace(1, 0, xf)
save('rumble_loop', lp, 0.6)
bang = lowpass(noise(0.8), 400) * env(int(SR * 0.8), 0.001, 0.75) * 2 + note(60, 0.8, 0.001, 0.7, (1, 0.5))
save('staging', bang, 0.85)
# --- Biblioteca, carnet y logros ---
save('page', lowpass(highpass(noise(0.3), 800), 5000) * np.sin(np.pi * t(0.3) / 0.3) ** 2, 0.45)
sh = cat(lowpass(noise(0.03), 4000) * env(int(SR * 0.03), 0.001, 0.025), np.zeros(int(SR * 0.05)), lowpass(noise(0.05), 3000) * env(int(SR * 0.05), 0.001, 0.045))
save('shutter', sh, 0.6)
fan = cat(note(523, 0.14), note(659, 0.14), note(784, 0.14), note(1047, 0.3), pad(np.zeros(1), 0.04), note(784, 0.12), note(1047, 0.7))
save('medal', echo(fan, 0.13, 0.3, 4), 0.7)

# --- Música (bucles) ---
def pad_chord(freqs, d, det=0.7):
    x = sum(sine(f, d) + sine(f + det, d, 1.0) + 0.3 * sine(2 * f + det, d) for f in freqs)
    return x * env(len(x), d * 0.35, d * 0.45)
def music(chords, step, arp_notes, bass=True, arp_gain=0.18, name='m'):
    total = step * len(chords); out = np.zeros(int(SR * total) + SR * 2)
    for i, ch in enumerate(chords):
        s = int(SR * i * step); c = pad_chord(ch, step * 1.25)
        out[s:s + len(c)] += c * 0.22
        if bass:
            b = sine(ch[0] / 2, step) * env(int(SR * step), 0.3, step * 0.5); out[s:s + len(b)] += b * 0.25
        for k, mult in enumerate(arp_notes):
            ts = s + int(SR * k * step / len(arp_notes)); f = ch[k % len(ch)] * mult
            n = note(f, 0.5, 0.003, 0.48, (1, 0.15)); out[ts:ts + len(n)] += n * arp_gain
    out = echo(out, 0.375, 0.33, 4)
    loop = out[:int(SR * total)].copy(); tail = out[int(SR * total):]
    loop[:len(tail)] += tail[:len(loop)]  # la cola vuelve al inicio: el bucle no se corta
    loop = lowpass(loop, 3800)
    return loop
A3, C4, D4, E4, F4, G4, A4, B3, G3 = 220.0, 261.63, 293.66, 329.63, 349.23, 392.0, 440.0, 246.94, 196.0
menu = music([(A3, C4, E4), (F4 / 2 * 2 / 2 * 2, A4 / 2 * 2, C4 * 2), (C4, E4, G4), (G3, B3, D4)] * 3, 4.0, [2, 2, 4, 2, 3, 2, 4, 2], name='menu')
base = music([(A3, E4, A4 / 2 * 2 / 2), (F4 / 2, C4, A3 * 2 / 2 * 1.5), (D4 / 2, A3, F4 / 2 * 2 / 2), (E4 / 2, B3, G3 * 2)] * 3, 5.0, [4, 0, 0, 3, 0, 0, 0, 0], bass=True, arp_gain=0.1, name='base')
for nm, x in (('music_menu', menu), ('music_base', base)):
    save(nm, x, 0.55)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', f'{OUT}/{nm}.wav', '-c:a', 'libvorbis', '-q:a', '4', f'{OUT}/{nm}.ogg'], check=True)
    os.remove(f'{OUT}/{nm}.wav')
print(sorted(os.listdir(OUT)))
