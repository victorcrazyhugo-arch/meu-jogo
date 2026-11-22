#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_audio.py - procedural sound synthesis for the game (no samples, numpy only).

Every sound is synthesized from scratch (filtered noise, damped modes, pitch
sweeps, a small formant voice model, convolution with decaying-noise impulses)
and written to ../audio/<name>.wav as PCM 16-bit mono 22050 Hz.

    python3 tools/gen_audio.py            # generate everything, then verify
    python3 tools/gen_audio.py --check    # only verify the existing files
    python3 tools/gen_audio.py name ...   # regenerate only the given names

Output is reproducible: each sound has its own RNG seeded from SEED + its name.
Files flagged loop=True are built from periodic / wrap-around components so the
whole file loops seamlessly.
"""
import os
import sys
import wave
import zlib

import numpy as np

SR = 22050
SEED = 20261122
TAU = 2.0 * np.pi
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "audio"))


# =============================================================================
# DSP helpers
# =============================================================================
def ns(sec):
    return int(round(sec * SR))


def tt(n):
    return np.arange(n) / SR


def white(rng, n):
    return rng.standard_normal(n)


def norm(x, peak=1.0):
    m = np.max(np.abs(x)) if len(x) else 0.0
    return x * (peak / m) if m > 0 else x


def unit(x):
    s = np.std(x)
    return x / s if s > 0 else x


def midi(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def _apply_gain(x, gain_fn, circ=False):
    """Zero-phase FFT-domain filter. circ=True -> wrap-around (for loops)."""
    n = len(x)
    if circ:
        f = np.fft.rfftfreq(n, 1.0 / SR)
        return np.fft.irfft(np.fft.rfft(x) * gain_fn(f), n)
    m = 1 << int(np.ceil(np.log2(n + max(n // 2, 2048))))
    f = np.fft.rfftfreq(m, 1.0 / SR)
    return np.fft.irfft(np.fft.rfft(x, m) * gain_fn(f), m)[:n]


def g_lp(f, fc, order=2):
    return 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))


def g_hp(f, fc, order=2):
    r = np.zeros_like(f)
    nz = f > 0
    r[nz] = 1.0 / np.sqrt(1.0 + (fc / f[nz]) ** (2 * order))
    return r


def lp(x, fc, order=2, circ=False):
    return _apply_gain(x, lambda f: g_lp(f, fc, order), circ)


def hp(x, fc, order=2, circ=False):
    return _apply_gain(x, lambda f: g_hp(f, fc, order), circ)


def bp(x, lo, hi, order=2, circ=False):
    return _apply_gain(x, lambda f: g_hp(f, lo, order) * g_lp(f, hi, order), circ)


def reson(x, peaks, circ=False, floor=0.0):
    """Parallel bank of resonant peaks: [(fc, bandwidth, gain), ...]."""
    def g(f):
        h = np.full_like(f, floor)
        for fc, bw, ga in peaks:
            h += ga / np.sqrt(1.0 + ((f - fc) / (0.5 * bw)) ** 2)
        return h * g_hp(f, 40.0, 2)
    return _apply_gain(x, g, circ)


def narrow(x, fc, rel_bw, circ=False):
    """Narrow gaussian band around fc (whistles etc.)."""
    return _apply_gain(x, lambda f: np.exp(-0.5 * ((f - fc) / (fc * rel_bw)) ** 2), circ)


def svf(x, fc, q, mode="bp"):
    """Time-varying state-variable filter (trapezoidal, stable up to Nyquist)."""
    n = len(x)
    fc = np.clip(np.broadcast_to(np.asarray(fc, float), (n,)), 20.0, SR * 0.45)
    g = np.tan(np.pi * fc / SR)
    k = 1.0 / q
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    a1l, a2l, a3l, xl = a1.tolist(), a2.tolist(), a3.tolist(), np.asarray(x, float).tolist()
    out = [0.0] * n
    ic1 = ic2 = 0.0
    for i in range(n):
        v3 = xl[i] - ic2
        v1 = a1l[i] * ic1 + a2l[i] * v3
        v2 = ic2 + a2l[i] * ic1 + a3l[i] * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        if mode == "bp":
            out[i] = v1
        elif mode == "lp":
            out[i] = v2
        else:
            out[i] = xl[i] - k * v1 - v2
    return np.array(out)


def smooth(x, sec):
    k = max(3, ns(sec) | 1)
    w = np.hanning(k + 2)[1:-1]
    w /= w.sum()
    return np.convolve(np.pad(x, k // 2, mode="edge"), w, mode="valid")[: len(x)]


def env_ad(n, a, d, t0=0.0):
    """Linear attack (a seconds) then exponential decay (time constant d)."""
    t = tt(n) - t0
    a = max(a, 1e-6)
    return np.where(t < 0, 0.0, np.where(t < a, t / a, np.exp(-np.maximum(t - a, 0.0) / d)))


def bump(n, t0, t1, skew=0.4, p=1.0):
    """Raised-cosine swell from t0 to t1 with the peak at t0 + skew*(t1-t0)."""
    t = tt(n)
    tp = t0 + skew * (t1 - t0)
    up = 0.5 - 0.5 * np.cos(np.pi * np.clip((t - t0) / max(tp - t0, 1e-6), 0, 1))
    dn = 0.5 + 0.5 * np.cos(np.pi * np.clip((t - tp) / max(t1 - tp, 1e-6), 0, 1))
    return np.where(t < tp, up, dn) ** p


def pts_env(n, pts):
    xs = [a for a, _ in pts]
    ys = [b for _, b in pts]
    return np.interp(tt(n), xs, ys)


def grain_env(rng, n, rate, tau, heavy=1.0):
    """Random 'grainy' amplitude envelope (0..1): Poisson impulses with decay."""
    imp = np.zeros(n)
    k = max(2, int(rng.poisson(rate * n / SR)))
    np.add.at(imp, rng.integers(0, n, k), rng.random(k) ** heavy)
    kern = np.exp(-np.arange(ns(tau * 6) + 2) / (tau * SR))
    e = np.convolve(imp, kern)[:n]
    m = e.max()
    return e / m if m > 0 else e


def slow_noise(rng, n, fc, circ=True):
    """Low-passed noise normalised to 0..1 (LFO / gust / flutter source)."""
    x = lp(white(rng, n), fc, 2, circ=circ)
    x = x - x.min()
    m = x.max()
    return x / m if m > 0 else x


def modes(n, freqs, taus, amps, t0=0.0):
    """Sum of exponentially damped sinusoids starting at t0 (struck body)."""
    t = tt(n) - t0
    on = t >= 0
    tp = np.where(on, t, 0.0)
    out = np.zeros(n)
    for f, d, a in zip(freqs, taus, amps):
        out += a * np.exp(-tp / d) * np.sin(TAU * f * tp)
    return out * on


def sweep_sine(n, f_start, f_end, tau_f):
    t = tt(n)
    f = f_end + (f_start - f_end) * np.exp(-t / tau_f)
    return np.sin(TAU * np.cumsum(f) / SR)


def ping(n, f, tau):
    t = tt(n)
    return (np.sin(TAU * f * t) * np.exp(-t / tau)
            + 0.4 * np.sin(TAU * f * 2.71 * t) * np.exp(-t / (tau * 0.5)) * (f * 2.71 < 10000))


def bubble(f, dur):
    m = ns(dur)
    tm = tt(m)
    fr = f * (1.0 + 0.35 * tm / dur)
    return np.sin(TAU * np.cumsum(fr) / SR) * np.exp(-tm / (dur * 0.3)) * (1 - np.exp(-tm / 0.0008))


def place(buf, snd, at, gain=1.0):
    i = max(0, int(round(at * SR)))
    m = min(len(snd), len(buf) - i)
    if m > 0:
        buf[i:i + m] += gain * snd[:m]


def place_wrap(buf, snd, at, gain=1.0):
    n = len(buf)
    i = int(round(at * SR)) % n
    m = len(snd)
    pos = 0
    while pos < m:
        k = min(n - i, m - pos)
        buf[i:i + k] += gain * snd[pos:pos + k]
        pos += k
        i = 0


def fftconv(a, b):
    n = len(a) + len(b) - 1
    nf = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(a, nf) * np.fft.rfft(b, nf), nf)[:n]


def _noise_ir(rng, length, decay, lo, hi):
    m = ns(length)
    ir = white(rng, m) * np.exp(-tt(m) / decay)
    ir = bp(ir, lo, hi)
    return ir / (np.sqrt(np.sum(ir ** 2)) + 1e-12)


def reverb(x, rng, length=0.2, decay=0.06, mix=0.3, lo=200.0, hi=5000.0, pre=0.006):
    """Body/room: convolve with a decaying-noise impulse (same output length).
    mix ~ wet/dry energy ratio (the impulse has unit energy)."""
    ir = _noise_ir(rng, length, decay, lo, hi)
    wet = fftconv(x, ir)
    d = ns(pre)
    out = np.array(x, float)
    k = len(x) - d
    if k > 0:
        out[d:] += mix * wet[:k]
    return out


def reverb_circ(x, rng, length, decay, mix, lo, hi):
    """Wrap-around reverb for loops (the tail folds back into the start)."""
    n = len(x)
    ir = _noise_ir(rng, min(length, n / SR), decay, lo, hi)
    wet = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir, n), n)
    return x + mix * wet


def soft(x, drive):
    """Gentle tanh saturation, peak stays at 1."""
    x = norm(x)
    return np.tanh(drive * x) / np.tanh(drive)


def clang(rng, n, base, tau, t0=0.0):
    """Struck metal: inharmonic partials with a slightly detuned (beating) copy."""
    ratios = np.array([1.0, 1.52, 2.76, 3.41, 5.40, 6.73, 8.93]) * rng.uniform(0.96, 1.04, 7)
    fr = base * ratios
    keep = fr < 9800
    taus = tau / (1.0 + 0.4 * np.arange(7))
    amps = rng.uniform(0.5, 1.0, 7) / (1.0 + 0.25 * np.arange(7))
    a = modes(n, fr[keep], taus[keep], amps[keep], t0)
    b = modes(n, fr[keep] * 1.006, taus[keep] * 0.9, amps[keep] * 0.5, t0)
    return a + b


def metal_click(rng, n, base, tau=0.008, t0=0.0):
    """Small metallic click (latches, magazines, hammers)."""
    ratios = np.array([1.0, 1.59, 2.31, 3.17, 4.43]) * rng.uniform(0.96, 1.04, 5)
    fr = base * ratios
    keep = fr < 10000
    taus = tau / (1.0 + 0.5 * np.arange(5))
    amps = np.array([1.0, 0.8, 0.6, 0.45, 0.3])
    ring = modes(n, fr[keep], taus[keep], amps[keep], t0)
    tick = hp(white(rng, n), 2000) * env_ad(n, 0.0002, 0.0015, t0)
    return norm(ring) + 0.6 * norm(tick)


def wood_crack(rng, m, f, tau):
    """Tiny splinter / fibre crack."""
    c = modes(m, [f, f * rng.uniform(1.9, 2.4), f * rng.uniform(3.3, 4.5)],
              [tau, tau * 0.6, tau * 0.35], [1.0, 0.6, 0.35])
    return norm(c) + 0.5 * norm(hp(white(rng, m), 2000) * env_ad(m, 0.0002, 0.002))


# =============================================================================
# Voice model (glottal pulses -> cascade formant filter), used for the undead
# and for the player's grunts. Purely human-like vowel formants.
# =============================================================================
VOWELS = {
    "a":  [(730, 90), (1090, 110), (2440, 170), (3300, 250), (4200, 300)],
    "o":  [(570, 80), (840, 100), (2410, 170), (3300, 250), (4200, 300)],
    "u":  [(320, 70), (800, 100), (2240, 170), (3300, 250), (4200, 300)],
    "uh": [(640, 90), (1190, 110), (2390, 170), (3300, 250), (4200, 300)],
    "e":  [(530, 80), (1840, 130), (2480, 170), (3300, 250), (4200, 300)],
    "er": [(490, 80), (1350, 110), (1690, 150), (3300, 250), (4200, 300)],
    "m":  [(260, 70), (1000, 200), (2200, 300), (3300, 400), (4200, 500)],
}
VOWEL_GAIN = {"a": 1.0, "o": 0.9, "u": 0.6, "uh": 0.95, "e": 0.9, "er": 0.85, "m": 0.4}


def tract(x, vowel, scale=1.0, wide=1.0, circ=False, presence=0.0, lowcut=70.0):
    """Cascade formant filter. presence = dB of high shelf above ~600 Hz (a
    pressed / raspy voice has a much flatter spectrum than the textbook one)."""
    fm = VOWELS[vowel]
    f2 = 600.0 * 10.0 ** (presence / 20.0)

    def g(f):
        h = np.ones_like(f)
        for fc, bw in fm:
            fc = fc * scale
            b = bw * wide
            h *= fc ** 2 / np.sqrt((fc ** 2 - f ** 2) ** 2 + (f * b) ** 2)
        if vowel == "m":
            h *= g_lp(f, 900.0, 1)
        h *= np.sqrt((1.0 + (f / 600.0) ** 2) / (1.0 + (f / f2) ** 2))
        return h * g_hp(f, lowcut, 2)
    return _apply_gain(x, g, circ)


def glottal(rng, f0, jitter=0.02, shimmer=0.25, subh=0.0, oq=0.6):
    """Rosenberg-style glottal pulse train (returns derivative and flow).
    jitter: pitch instability, shimmer: per-cycle loudness instability,
    subh: period-doubling depth (vocal-fry / rasp)."""
    n = len(f0)
    jn = unit(lp(white(rng, n), 25.0))
    ph = np.cumsum(f0 * (1.0 + jitter * jn)) / SR
    cyc = np.floor(ph).astype(int)
    p = ph - cyc
    nc = int(cyc[-1]) + 2
    amp = 1.0 - shimmer * rng.random(nc)
    if subh > 0:
        amp *= 1.0 - subh * (np.arange(nc) % 2)
    tp = oq * 0.67
    tn = oq - tp
    g = np.where(p < tp, 0.5 * (1.0 - np.cos(np.pi * p / tp)),
                 np.where(p < oq, np.cos(0.5 * np.pi * (p - tp) / tn), 0.0))
    g = g * amp[cyc]
    d = np.diff(g, prepend=g[0])
    return d, g


def voice(rng, dur, f0_pts, vowels, env_pts, scale=1.0, jitter=0.03, shimmer=0.3,
          subh=0.0, breath=0.25, rough=(0.0, 0.0), drive=1.0, vib=0.0, lpf=4200.0,
          wide=1.0, presence=8.0, lowcut=70.0, rasp=0.0, bright=0.0):
    """f0_pts / vowels / env_pts use fractional time 0..1."""
    n = ns(dur)
    t = tt(n)
    f0 = np.interp(t, [a * dur for a, _ in f0_pts], [b for _, b in f0_pts])
    f0 = smooth(f0, 0.03)
    if vib > 0:
        f0 = f0 * (1.0 + vib * np.sin(TAU * rng.uniform(4.5, 6.0) * t + rng.uniform(0, TAU)))
    d, g = glottal(rng, f0, jitter, shimmer, subh)
    d = unit(d)
    gm = g / (np.max(g) + 1e-12)
    asp = unit(bp(white(rng, n), 500, 5000)) * (0.35 + 0.65 * gm)
    src = d + breath * asp
    rr, rd = rough
    am = np.ones(n)
    if rd > 0:
        rj = slow_noise(rng, n, 6.0, circ=False)
        rph = np.cumsum(rr * (0.8 + 0.4 * rj)) / SR
        am = 1.0 - rd * (0.5 + 0.5 * np.sin(TAU * rph)) ** 1.5
        src = src * am
    xs = [a * dur for a, _ in vowels]
    y = np.zeros(n)
    cache = {}
    for i, (_, nm) in enumerate(vowels):
        if nm not in cache:
            cache[nm] = unit(tract(src, nm, scale, wide, presence=presence, lowcut=lowcut)) * VOWEL_GAIN[nm]
        w = np.interp(t, xs, [1.0 if j == i else 0.0 for j in range(len(vowels))])
        y += w * cache[nm]
    if bright > 0:
        # parallel upper-formant branch (keeps voiced energy in the 1.5-3.5 kHz
        # presence region, which the pure cascade loses on dark back vowels)
        hsrc = np.diff(src, prepend=src[0])
        hb = reson(hsrc, [(1500 * scale, 250, 0.5), (2450 * scale, 220, 1.0), (3300 * scale, 300, 0.5)])
        y += bright * unit(hb)
    if rasp > 0:
        # gritty noise released in step with the glottal pulses (hoarse throat)
        rz = reson(white(rng, n), [(1300 * scale, 350, 1.0), (2500 * scale, 500, 0.7), (3500 * scale, 700, 0.35)])
        y += rasp * unit(unit(rz) * gm ** 1.5 * am)
    env = np.interp(t, [a * dur for a, _ in env_pts], [b for _, b in env_pts])
    y = y * smooth(env, 0.012)
    if drive > 1.0:
        y = soft(y, drive)
    return lp(y, lpf)


# =============================================================================
# Registry
# =============================================================================
REG = []


def reg(name, fn, *args, loop=False, peak=-3.0, perc=False):
    REG.append((name, fn, args, dict(loop=loop, peak=peak, perc=perc)))


# =============================================================================
# Footsteps
# =============================================================================
def step_asphalt(rng, v):
    n = ns(rng.uniform(0.19, 0.24))
    t = tt(n)
    thud = lp(white(rng, n), rng.uniform(240, 340)) * env_ad(n, 0.0015, rng.uniform(0.016, 0.026))
    thump = np.sin(TAU * rng.uniform(75, 100) * t) * np.exp(-t / 0.028)
    grit = bp(white(rng, n), rng.uniform(1300, 1900), rng.uniform(4500, 6500))
    g = grain_env(rng, n, 700, 0.0012)
    scuff = grit * (0.35 + 0.65 * g) * env_ad(n, 0.012, rng.uniform(0.035, 0.06), t0=0.006)
    tick = hp(white(rng, n), 2500) * env_ad(n, 0.0004, 0.003)
    t2 = rng.uniform(0.07, 0.10)
    toe = (norm(lp(white(rng, n), 500) * env_ad(n, 0.003, 0.02, t0=t2))
           + 0.5 * norm(grit * g * env_ad(n, 0.004, 0.025, t0=t2)))
    return norm(thud) + 0.5 * thump + 0.5 * norm(scuff) + 0.22 * norm(tick) + 0.3 * toe


def step_grass(rng, v):
    n = ns(rng.uniform(0.22, 0.27))
    end = n / SR
    rust = bp(white(rng, n), rng.uniform(1800, 2600), rng.uniform(6500, 8500))
    g = grain_env(rng, n, 1200, 0.002)
    rustle = rust * (0.25 + 0.75 * g) * bump(n, 0.0, end * rng.uniform(0.8, 0.95), 0.25, 1.3)
    mid = (bp(white(rng, n), 500, 1800) * (0.3 + 0.7 * grain_env(rng, n, 500, 0.004))
           * bump(n, 0.004, end * 0.65, 0.2))
    thud = lp(white(rng, n), 180) * env_ad(n, 0.006, 0.03)
    # second, softer brush as the foot rolls off
    t2 = rng.uniform(0.09, 0.12)
    roll = rust * grain_env(rng, n, 900, 0.002) * bump(n, t2, end, 0.3, 1.5)
    return norm(rustle) + 0.45 * norm(mid) + 0.4 * norm(thud) + 0.35 * norm(roll)


def step_wood(rng, v):
    n = ns(rng.uniform(0.21, 0.27))
    base = rng.uniform(150, 195)
    ratios = np.array([1.0, 1.78, 2.9, 4.3])

    def knock(t0, gain, b):
        fr = b * ratios * rng.uniform(0.96, 1.04, 4)
        k = modes(n, fr, [0.05, 0.035, 0.02, 0.011], [1.0, 0.7, 0.4, 0.2], t0=t0)
        body = bp(white(rng, n), 170, 900) * env_ad(n, 0.001, 0.018, t0)
        tick = bp(white(rng, n), 1500, 5000) * env_ad(n, 0.0004, 0.0035, t0)
        return gain * (norm(k) + 0.5 * norm(body) + 0.3 * norm(tick))

    out = knock(0.0, 1.0, base) + knock(rng.uniform(0.075, 0.105), 0.4, base * rng.uniform(1.08, 1.2))
    return reverb(out, rng, 0.08, 0.025, 0.3, 150, 3000)


def step_tile(rng, v):
    n = ns(rng.uniform(0.18, 0.23))

    def tap(t0, gain, f):
        click = hp(white(rng, n), 2200) * env_ad(n, 0.0003, 0.0035, t0)
        ring = modes(n, [f, f * 1.63, f * 2.41], [0.012, 0.008, 0.005], [1.0, 0.6, 0.4], t0=t0)
        low = modes(n, [rng.uniform(260, 340)], [0.012], [1.0], t0=t0)
        return gain * (0.9 * norm(click) + 0.6 * norm(ring) + 0.35 * low)

    out = tap(0.0, 1.0, rng.uniform(2100, 2700)) + tap(rng.uniform(0.06, 0.09), 0.5, rng.uniform(2600, 3300))
    return reverb(out, rng, 0.1, 0.03, 0.3, 600, 8000)


for _s, _f in (("asphalt", step_asphalt), ("grass", step_grass), ("wood", step_wood), ("tile", step_tile)):
    for _i in range(1, 5):
        reg("step_%s_%d" % (_s, _i), _f, _i, perc=(_s != "grass"))


# =============================================================================
# Melee
# =============================================================================
def swing(rng, v):
    dur = [0.27, 0.31, 0.34][v - 1]
    n = ns(dur)
    t = tt(n)
    pk = rng.uniform(0.45, 0.6)
    b = bump(n, 0.0, dur, pk)
    fc = rng.uniform(420, 560) + rng.uniform(1300, 1900) * b ** 1.2
    a = svf(white(rng, n), fc, 2.2, "bp")
    c = svf(white(rng, n), fc * 2.3, 1.5, "bp")
    air = unit(hp(white(rng, n), 3000)) * b ** 3
    flutter = 1.0 + 0.12 * np.sin(TAU * rng.uniform(26, 40) * t + rng.uniform(0, TAU))
    return (unit(a) + 0.35 * unit(c)) * b ** 1.6 * flutter + 0.12 * air


def hit_blunt(rng, v):
    n = ns(rng.uniform(0.28, 0.32))
    t = tt(n)
    thump = sweep_sine(n, rng.uniform(130, 160), rng.uniform(55, 68), 0.03) * np.exp(-t / rng.uniform(0.05, 0.065))
    mid = bp(white(rng, n), 120, rng.uniform(600, 800)) * env_ad(n, 0.001, rng.uniform(0.03, 0.045))
    b = rng.uniform(175, 225)
    body = modes(n, [b, b * 1.7, b * 2.6], [0.035, 0.024, 0.015], [1.0, 0.8, 0.5])
    smack = bp(white(rng, n), 800, 3200) * env_ad(n, 0.0005, 0.012)
    flesh = (bp(white(rng, n), 250, 1100) * (0.4 + 0.6 * grain_env(rng, n, 200, 0.005))
             * env_ad(n, 0.004, 0.05, t0=0.008))
    x = 0.65 * thump + norm(mid) + 0.7 * norm(body) + 0.5 * norm(smack) + 0.5 * norm(flesh)
    return reverb(soft(x, 1.8), rng, 0.08, 0.03, 0.25, 150, 3000)


def hit_blade(rng, v):
    n = ns(rng.uniform(0.27, 0.32))
    t = tt(n)
    fc = 6500 * np.exp(-t / 0.05) + rng.uniform(2000, 2500)
    sl = svf(white(rng, n), fc, 1.8, "bp") * env_ad(n, 0.003, rng.uniform(0.03, 0.045))
    ring = modes(n, [rng.uniform(3200, 4200), rng.uniform(5600, 6800)], [0.02, 0.012], [1.0, 0.6])
    wet = (bp(white(rng, n), 350, 1600) * (0.3 + 0.7 * grain_env(rng, n, 260, 0.004))
           * env_ad(n, 0.01, 0.06, t0=0.015))
    m = n - ns(0.02)
    thud = (sweep_sine(m, 170, 80, 0.025) * np.exp(-tt(m) / 0.04)
            + 0.8 * norm(bp(white(rng, m), 150, 800) * env_ad(m, 0.001, 0.025)))
    out = 0.9 * norm(sl) + 0.1 * norm(ring) + 0.65 * norm(wet)
    place(out, thud, 0.02, 0.4)
    return out


def hit_wood(rng, v):
    n = ns(rng.uniform(0.28, 0.33))
    t = tt(n)
    base = rng.uniform(230, 290)
    fr = base * np.array([1.0, 1.71, 2.83, 4.4, 6.1]) * rng.uniform(0.96, 1.04, 5)
    knock = modes(n, fr, [0.045, 0.03, 0.02, 0.012, 0.007], [1.0, 0.8, 0.55, 0.35, 0.2])
    crack = hp(white(rng, n), 1800) * env_ad(n, 0.0003, 0.004)
    body = bp(white(rng, n), 200, 1200) * env_ad(n, 0.0008, 0.02)
    out = norm(knock) + 0.55 * norm(crack) + 0.5 * norm(body)
    out += 0.6 * sweep_sine(n, 120, 70, 0.02) * np.exp(-t / 0.04)
    for _ in range(int(rng.integers(4, 7))):
        m = ns(0.03)
        place(out, wood_crack(rng, m, rng.uniform(1300, 3800), rng.uniform(0.002, 0.005)),
              rng.uniform(0.006, 0.07), rng.uniform(0.15, 0.4))
    return reverb(out, rng, 0.1, 0.035, 0.3, 150, 4000)


def hit_metal(rng, v):
    n = ns([0.5, 0.54][v - 1])
    base = rng.uniform(430, 520) if v == 1 else rng.uniform(610, 720)
    ring = clang(rng, n, base, rng.uniform(0.13, 0.17))
    strike = (norm(hp(white(rng, n), 1500) * env_ad(n, 0.0003, 0.005))
              + 0.7 * norm(bp(white(rng, n), 300, 1500) * env_ad(n, 0.0005, 0.012)))
    thud = modes(n, [rng.uniform(120, 160)], [0.03], [1.0])
    x = soft(norm(ring) + 0.6 * norm(strike) + 0.4 * thud, 1.3)
    return reverb(x, rng, 0.15, 0.05, 0.25, 300, 7000)


for _i in range(1, 4):
    reg("swing_%d" % _i, swing, _i)
    reg("hit_blunt_%d" % _i, hit_blunt, _i, perc=True)
    reg("hit_blade_%d" % _i, hit_blade, _i, perc=True)
    reg("hit_wood_%d" % _i, hit_wood, _i, perc=True)
for _i in range(1, 3):
    reg("hit_metal_%d" % _i, hit_metal, _i, perc=True)


# =============================================================================
# Guns
# =============================================================================
def gunshot(rng, dur, crack, bands, thump, drive, rev, echo=None):
    """crack=(hp_hz, tau, gain); bands=[(lo, hi, tau, gain)];
    thump=(f0, f1, tau, gain); rev=(len, decay, mix, lo, hi)."""
    n = ns(dur)
    t = tt(n)
    c_hp, c_tau, c_g = crack
    crk = norm(hp(white(rng, n), c_hp) * env_ad(n, 0.0003, c_tau))
    x = 0.6 * c_g * crk
    for lo, hi, tau, g in bands:
        x += g * norm(bp(white(rng, n), lo, hi) * env_ad(n, 0.0006, tau))
    f0, f1, tau, g = thump
    x += g * sweep_sine(n, f0, f1, 0.02) * np.exp(-t / tau)
    # saturate the body (muzzle blast overloads everything), keep the crack on top
    x = 0.8 * soft(x, drive) + 0.45 * c_g * crk
    length, decay, mix, lo, hi = rev
    x = reverb(x, rng, length, decay, mix, lo, hi, pre=0.004)
    if echo:
        delay, gain, cut = echo
        e = np.zeros(n)
        place(e, lp(x, cut), delay, gain)
        x = x + e
    return x * np.minimum(1.0, (dur - t) / 0.06)


def gun_pistol(rng):
    return gunshot(rng, 0.6, (1500, 0.004, 1.0),
                   [(200, 900, 0.035, 1.0), (900, 3000, 0.02, 0.8), (3000, 9000, 0.010, 0.6)],
                   (220, 80, 0.035, 0.8), 2.2, (0.5, 0.085, 0.75, 180, 5000))


def gun_revolver(rng):
    return gunshot(rng, 0.7, (1200, 0.005, 0.9),
                   [(120, 700, 0.055, 1.2), (700, 2500, 0.03, 0.9), (2500, 8000, 0.012, 0.5)],
                   (170, 62, 0.055, 0.85), 2.6, (0.6, 0.11, 0.8, 140, 4000))


def gun_shotgun(rng):
    return gunshot(rng, 1.0, (900, 0.007, 0.8),
                   [(70, 500, 0.10, 1.3), (500, 2000, 0.06, 1.0), (2000, 7000, 0.02, 0.5)],
                   (120, 45, 0.10, 1.05), 3.2, (0.9, 0.17, 0.9, 110, 3400))


def gun_rifle(rng):
    return gunshot(rng, 1.1, (2500, 0.003, 1.2),
                   [(150, 900, 0.04, 1.0), (900, 3500, 0.025, 0.9), (3500, 10000, 0.012, 0.8)],
                   (200, 70, 0.04, 0.8), 2.4, (1.0, 0.24, 1.0, 150, 4500),
                   echo=(0.17, 0.22, 1800))


def gun_empty(rng):
    n = ns(0.08)
    t = tt(n)
    out = metal_click(rng, n, 2600, 0.004)
    out += 0.45 * metal_click(rng, n, 1750, 0.005, t0=0.013)
    out += 0.5 * np.sin(TAU * 620 * t) * np.exp(-t / 0.004)
    out += 0.25 * norm(bp(white(rng, n), 300, 1500) * env_ad(n, 0.0005, 0.006))
    return out


def reload_mag(rng):
    n = ns(0.6)
    out = np.zeros(n)
    place(out, metal_click(rng, ns(0.05), 2300, 0.004), 0.0, 0.45)                 # release catch
    sc = bp(white(rng, n), 1200, 4200) * (0.4 + 0.6 * grain_env(rng, n, 500, 0.002))
    out += 0.22 * norm(sc * bump(n, 0.03, 0.17, 0.8, 1.5))                         # mag sliding out
    m = ns(0.12)
    clack1 = metal_click(rng, m, 1250, 0.009) + 0.7 * modes(m, [420, 760], [0.02, 0.012], [1.0, 0.6])
    place(out, clack1, 0.165, 0.75)
    out += 0.2 * norm(sc * bump(n, 0.34, 0.435, 0.85, 1.5))                        # new mag sliding in
    clack2 = (metal_click(rng, m, 980, 0.011) + 0.9 * modes(m, [190, 330, 610], [0.03, 0.02, 0.012], [1.0, 0.7, 0.5])
              + 0.4 * norm(bp(white(rng, m), 300, 2000) * env_ad(m, 0.0005, 0.01)))
    place(out, clack2, 0.43, 1.0)
    place(out, metal_click(rng, ns(0.04), 2700, 0.003), 0.462, 0.25)               # latch settles
    return reverb(out, rng, 0.06, 0.02, 0.2, 400, 7000)


def reload_shell(rng):
    n = ns(0.25)
    out = np.zeros(n)
    sc = bp(white(rng, n), 1500, 4800) * (0.4 + 0.6 * grain_env(rng, n, 600, 0.002))
    out += 0.2 * norm(sc * bump(n, 0.0, 0.115, 0.8, 1.3))
    m = ns(0.1)
    click = (metal_click(rng, m, 1500, 0.007) + 0.8 * modes(m, [300, 520], [0.014, 0.009], [1.0, 0.6])
             + 0.3 * norm(bp(white(rng, m), 400, 2200) * env_ad(m, 0.0005, 0.008)))
    place(out, click, 0.108, 1.0)
    place(out, metal_click(rng, ns(0.04), 2500, 0.003), 0.152, 0.3)
    return out


def rack(rng):
    n = ns(0.45)
    out = np.zeros(n)

    def shk(t0, dur, f_a, f_b, gain, click_base):
        m = ns(dur)
        x = tt(m) / dur
        fc = f_a + (f_b - f_a) * x
        s = svf(white(rng, m), fc, 1.6, "bp") * (0.35 + 0.65 * grain_env(rng, m, 700, 0.0015))
        s = norm(s * bump(m, 0.0, dur, 0.7, 0.8))
        place(out, s, t0, 0.5 * gain)
        k = ns(0.1)
        c = (metal_click(rng, k, click_base, 0.008)
             + 0.8 * modes(k, [rng.uniform(210, 260), rng.uniform(430, 520)], [0.022, 0.014], [1.0, 0.7])
             + 0.4 * norm(bp(white(rng, k), 500, 3000) * env_ad(k, 0.0004, 0.008)))
        place(out, c, t0 + dur * 0.9, gain)

    shk(0.005, 0.13, 3600, 1500, 0.85, 1400)   # pull back
    shk(0.215, 0.12, 1500, 3800, 1.0, 1100)    # shove forward
    return reverb(out, rng, 0.06, 0.02, 0.2, 400, 7000)


def casing(rng):
    n = ns(0.3)
    out = np.zeros(n)
    t0, gap, g = 0.0, 0.088, 1.0
    base = rng.uniform(3900, 4500)
    while t0 < 0.27:
        b = base * rng.uniform(0.9, 1.1)
        m = ns(0.09)
        tm = tt(m)
        tau = 0.022 * (0.6 + 0.4 * g)
        p = (np.sin(TAU * b * tm) * np.exp(-tm / tau)
             + 0.6 * np.sin(TAU * b * 1.47 * tm) * np.exp(-tm / (tau * 0.7))
             + 0.35 * np.sin(TAU * b * 2.09 * tm) * np.exp(-tm / (tau * 0.5)))
        p += 0.5 * norm(hp(white(rng, m), 3000) * env_ad(m, 0.0002, 0.001))
        place(out, p, t0, g)
        t0 += gap
        gap *= 0.68
        g *= 0.66
        if gap < 0.012:
            break
    return out


reg("gun_pistol", gun_pistol, perc=True)
reg("gun_revolver", gun_revolver, perc=True)
reg("gun_shotgun", gun_shotgun, perc=True)
reg("gun_rifle", gun_rifle, perc=True)
reg("gun_empty", gun_empty, perc=True)
reg("reload_mag", reload_mag, perc=True)
reg("reload_shell", reload_shell)
reg("rack", rack)
reg("casing", casing, perc=True)


# =============================================================================
# Zombies (human-undead voices)
# =============================================================================
ENV_SWELL = [(0, 0), (0.18, 0.8), (0.5, 1.0), (0.8, 0.6), (1, 0)]
GROANS = [
    dict(dur=1.40, f0=[(0, 78), (0.35, 94), (0.7, 84), (1, 68)],
         vow=[(0, "u"), (0.4, "o"), (1, "uh")], env=ENV_SWELL,
         shimmer=0.40, subh=0.25, breath=0.30, rough=(22, 0.25)),
    dict(dur=1.80, f0=[(0, 98), (0.2, 90), (0.6, 70), (1, 48)],
         vow=[(0, "a"), (0.5, "o"), (1, "u")], env=[(0, 0), (0.1, 1), (0.5, 0.8), (0.85, 0.45), (1, 0)],
         shimmer=0.45, subh=0.35, breath=0.35, rough=(18, 0.30)),
    dict(dur=1.10, f0=[(0, 66), (0.4, 80), (0.75, 76), (1, 60)],
         vow=[(0, "m"), (0.45, "uh"), (1, "m")], env=[(0, 0), (0.25, 0.7), (0.5, 1), (1, 0)],
         shimmer=0.35, subh=0.20, breath=0.20, rough=(26, 0.20)),
    dict(dur=1.60, f0=[(0, 86), (0.25, 112), (0.5, 92), (0.75, 100), (1, 72)],
         vow=[(0, "e"), (0.45, "uh"), (1, "o")], env=[(0, 0), (0.15, 0.9), (0.4, 0.7), (0.65, 1), (1, 0)],
         shimmer=0.40, subh=0.30, breath=0.30, rough=(24, 0.30), vib=0.02),
    dict(dur=1.25, f0=[(0, 60), (0.3, 57), (0.6, 66), (1, 46)],
         vow=[(0, "o"), (0.5, "a"), (1, "uh")], env=[(0, 0), (0.12, 1), (0.6, 0.85), (1, 0)],
         shimmer=0.55, subh=0.50, breath=0.40, rough=(16, 0.40)),
]
ENV_GROWL = [(0, 0), (0.08, 1), (0.7, 0.9), (1, 0)]
GROWLS = [
    dict(dur=0.90, f0=[(0, 62), (0.3, 74), (1, 58)], vow=[(0, "er"), (0.5, "a"), (1, "er")],
         env=ENV_GROWL, shimmer=0.55, subh=0.50, breath=0.50, rough=(30, 0.60), drive=2.5),
    dict(dur=0.72, f0=[(0, 70), (0.5, 84), (1, 66)], vow=[(0, "uh"), (0.5, "a"), (1, "o")],
         env=ENV_GROWL, shimmer=0.50, subh=0.45, breath=0.55, rough=(34, 0.55), drive=2.5),
    dict(dur=1.10, f0=[(0, 56), (0.4, 64), (0.8, 70), (1, 54)], vow=[(0, "er"), (0.6, "e"), (1, "er")],
         env=[(0, 0), (0.1, 0.8), (0.6, 1), (0.85, 0.8), (1, 0)],
         shimmer=0.55, subh=0.55, breath=0.50, rough=(27, 0.65), drive=2.8),
]
ENV_LUNGE = [(0, 0), (0.07, 1), (0.4, 0.9), (1, 0)]
ATTACKS = [
    dict(dur=0.50, f0=[(0, 95), (0.25, 165), (0.6, 140), (1, 100)], vow=[(0, "uh"), (0.3, "a"), (1, "e")],
         env=ENV_LUNGE, shimmer=0.45, subh=0.35, breath=0.60, rough=(40, 0.45), drive=3.0),
    dict(dur=0.42, f0=[(0, 110), (0.2, 180), (1, 105)], vow=[(0, "a"), (0.6, "a"), (1, "uh")],
         env=ENV_LUNGE, shimmer=0.45, subh=0.30, breath=0.65, rough=(44, 0.40), drive=3.0),
    dict(dur=0.58, f0=[(0, 85), (0.35, 150), (0.7, 160), (1, 95)], vow=[(0, "er"), (0.4, "a"), (1, "o")],
         env=[(0, 0), (0.1, 0.8), (0.45, 1), (1, 0)],
         shimmer=0.50, subh=0.40, breath=0.60, rough=(36, 0.50), drive=3.0),
]
DEATHS = [
    dict(dur=0.92, f0=[(0, 118), (0.3, 96), (0.7, 64), (1, 42)], vow=[(0, "a"), (0.5, "uh"), (1, "u")],
         env=[(0, 0), (0.05, 1), (0.4, 0.75), (0.8, 0.35), (1, 0)],
         shimmer=0.50, subh=0.40, breath=0.50, rough=(20, 0.20), drive=2.0),
    dict(dur=0.88, f0=[(0, 100), (0.2, 110), (0.6, 70), (1, 45)], vow=[(0, "e"), (0.4, "o"), (1, "m")],
         env=[(0, 0), (0.06, 1), (0.45, 0.8), (0.8, 0.4), (1, 0)],
         shimmer=0.50, subh=0.45, breath=0.55, rough=(18, 0.20), drive=2.0),
]


def _zvoice(rng, p):
    y = voice(rng, p["dur"], p["f0"], p["vow"], p["env"],
              scale=0.88 * rng.uniform(0.97, 1.03), jitter=0.045,
              shimmer=p["shimmer"], subh=p["subh"], breath=p["breath"],
              rough=p["rough"], drive=p.get("drive", 1.6), vib=p.get("vib", 0.0), lpf=4600.0,
              presence=11.0, lowcut=95.0, rasp=p.get("rasp", 0.24), bright=0.24)
    n = len(y)
    follow = smooth(np.abs(y), 0.04)
    rum = unit(bp(white(rng, n), 110, 420)) * (0.3 + 0.7 * slow_noise(rng, n, 28.0, circ=False)) * follow
    return y + 0.25 * rum


def zombie_groan(rng, v):
    return reverb(_zvoice(rng, GROANS[v - 1]), rng, 0.15, 0.04, 0.25, 150, 3000)


def zombie_growl(rng, v):
    return reverb(_zvoice(rng, GROWLS[v - 1]), rng, 0.12, 0.035, 0.2, 150, 3200)


def zombie_attack(rng, v):
    p = ATTACKS[v - 1]
    y = _zvoice(rng, p)
    n = len(y)
    # breathy hiss on the lunge onset
    hiss = unit(tract(bp(white(rng, n), 600, 5000), "a", 0.88, 2.5)) * bump(n, 0.0, p["dur"] * 0.55, 0.3, 1.5)
    return reverb(norm(y) + 0.12 * hiss, rng, 0.12, 0.035, 0.2, 150, 3500)


def zombie_death(rng, v):
    p = DEATHS[v - 1]
    y = _zvoice(rng, p)
    n = len(y)
    x = tt(n) / p["dur"]
    # gurgle: irregular wet amplitude modulation that deepens as the voice collapses
    gph = np.cumsum(13.0 + 6.0 * slow_noise(rng, n, 5.0, circ=False)) / SR
    depth = 0.1 + 0.75 * x ** 0.8
    y = y * (1.0 - depth * (0.5 + 0.5 * np.sin(TAU * gph)) ** 2)
    bub = (bp(white(rng, n), 250, 1100) * grain_env(rng, n, 24, 0.012)
           * np.interp(x, [0, 0.25, 0.8, 1.0], [0, 0.6, 1.0, 0]))
    return reverb(norm(y) + 0.45 * norm(bub), rng, 0.12, 0.035, 0.2, 150, 3000)


def zombie_thump(rng, v):
    n = ns(rng.uniform(0.29, 0.32))
    t = tt(n)
    thump = sweep_sine(n, rng.uniform(110, 135), rng.uniform(62, 75), 0.03) * np.exp(-t / rng.uniform(0.05, 0.065))
    base = rng.uniform(160, 200)
    fr = base * np.array([1.0, 1.62, 2.5, 3.7, 5.2, 7.1]) * rng.uniform(0.96, 1.04, 6)
    panel = modes(n, fr, [0.075, 0.055, 0.035, 0.022, 0.014, 0.009], [1.0, 0.85, 0.6, 0.4, 0.28, 0.18])
    slap = bp(white(rng, n), 200, 2200) * env_ad(n, 0.002, 0.014)
    x = soft(0.55 * thump + norm(panel) + 0.75 * norm(slap), 1.6)
    for _ in range(3):  # loose latch / hinge rattling in the frame
        place(x, metal_click(rng, ns(0.03), rng.uniform(1600, 2400), 0.004),
              rng.uniform(0.02, 0.09), rng.uniform(0.04, 0.09))
    return reverb(x, rng, 0.14, 0.05, 0.4, 150, 3000)


for _i in range(1, 6):
    reg("zombie_groan_%d" % _i, zombie_groan, _i)
for _i in range(1, 4):
    reg("zombie_growl_%d" % _i, zombie_growl, _i)
    reg("zombie_attack_%d" % _i, zombie_attack, _i)
    reg("zombie_thump_%d" % _i, zombie_thump, _i, perc=True)
for _i in range(1, 3):
    reg("zombie_death_%d" % _i, zombie_death, _i)


# =============================================================================
# Player
# =============================================================================
HURTS = [
    dict(dur=0.30, f0=[(0, 172), (0.3, 158), (1, 118)], vow=[(0, "uh"), (1, "a")]),
    dict(dur=0.37, f0=[(0, 146), (0.25, 182), (1, 122)], vow=[(0, "a"), (1, "uh")]),
    dict(dur=0.26, f0=[(0, 192), (1, 136)], vow=[(0, "e"), (1, "uh")]),
]


def hurt(rng, v):
    p = HURTS[v - 1]
    y = voice(rng, p["dur"], p["f0"], p["vow"], [(0, 0), (0.07, 1), (0.5, 0.7), (1, 0)],
              scale=1.0, jitter=0.02, shimmer=0.18, subh=0.0, breath=0.35,
              rough=(0.0, 0.0), drive=1.6, lpf=5200.0, presence=9.0, lowcut=90.0, rasp=0.10, bright=0.25)
    n = len(y)
    # glottal-stop style burst of air at the onset
    puff = unit(tract(bp(white(rng, n), 400, 5000), "uh", 1.0, 2.0)) * env_ad(n, 0.004, 0.02)
    return reverb(norm(y) + 0.1 * puff, rng, 0.08, 0.025, 0.15, 200, 4000)


def breath_heavy(rng):
    T = 2.4
    n = ns(T)
    t = tt(n)
    w1 = white(rng, n)
    w2 = white(rng, n)
    inh_lo = unit(bp(w1, 700, 1800, circ=True))
    inh_hi = unit(bp(w1, 1500, 4200, circ=True))
    exh = unit(reson(w2, [(550, 400, 1.0), (1350, 500, 0.7), (2500, 700, 0.3)], circ=True))
    exh_hi = unit(bp(w2, 2000, 5000, circ=True))
    out = np.zeros(n)
    for a, b, kind, g in ((0.04, 0.60, "in", 0.85), (0.66, 1.20, "out", 1.0),
                          (1.24, 1.80, "in", 0.80), (1.86, 2.37, "out", 0.92)):
        if kind == "in":
            e = bump(n, a, b, 0.55, 1.4)
            br = np.clip((t - a) / (b - a), 0, 1)
            out += g * 0.8 * e * ((1.0 - 0.6 * br) * inh_lo + (0.3 + 0.7 * br) * 0.8 * inh_hi)
        else:
            e = bump(n, a, b, 0.22, 1.2)
            out += g * e * (exh + 0.25 * exh_hi)
    out *= 0.8 + 0.2 * slow_noise(rng, n, 18.0, circ=True)
    out += 0.004 * unit(bp(white(rng, n), 300, 3000, circ=True))
    return out


def eat(rng):
    n = ns(0.9)
    out = np.zeros(n)
    for t0 in (0.03, 0.32, 0.61):
        m = ns(0.24)
        tm = tt(m)
        p = (1500.0 / SR) * np.exp(-tm / 0.065) * rng.uniform(0.7, 1.2)
        imp = (rng.random(m) < p) * (0.25 + rng.random(m)) * rng.choice([-1.0, 1.0], m)
        cr = norm(bp(imp, 1100, 6500))
        cr2 = norm(reson(imp, [(rng.uniform(1800, 2600), 600, 1.0), (rng.uniform(3500, 4500), 900, 0.7)]))
        mouth = (bp(white(rng, m), 250, 900) * bump(m, 0.0, 0.2, 0.3)
                 * (0.4 + 0.6 * grain_env(rng, m, 120, 0.006)))
        jaw = modes(m, [rng.uniform(140, 180)], [0.02], [1.0])
        chew = soft(cr + 0.6 * cr2, 2.5) + 0.45 * norm(mouth) + 0.25 * jaw
        place(out, chew, t0 + rng.uniform(-0.01, 0.01), rng.uniform(0.8, 1.0))
    return out


def drink(rng):
    n = ns(0.9)
    out = np.zeros(n)
    for t0 in (0.04, 0.33, 0.62):
        m = ns(0.25)
        tm = tt(m)
        f_a = rng.uniform(170, 220)
        f_b = rng.uniform(420, 520)
        f = f_a + (f_b - f_a) * np.clip(tm / 0.11, 0, 1) ** 1.5
        ph = TAU * np.cumsum(f) / SR
        e = bump(m, 0.0, 0.13, 0.25)
        glug = (np.sin(ph) + 0.3 * np.sin(2 * ph + 0.5)) * e
        click = bp(white(rng, m), 600, 2500) * env_ad(m, 0.001, 0.006, t0=0.005)
        liquid = (bp(white(rng, m), 700, 3000) * (0.3 + 0.7 * grain_env(rng, m, 150, 0.004))
                  * bump(m, 0.02, 0.2, 0.3))
        swallow = modes(m, [rng.uniform(95, 115)], [0.035], [1.0], t0=0.1)
        g = norm(glug) + 0.3 * norm(click) + 0.22 * norm(liquid) + 0.5 * swallow
        place(out, g, t0 + rng.uniform(-0.01, 0.01), rng.uniform(0.8, 1.0))
    return out


def cough(rng):
    n = ns(0.7)
    out = np.zeros(n)
    for t0, g, f_hi in ((0.01, 1.0, 128), (0.36, 0.78, 112)):
        m = ns(0.32)
        burst = unit(reson(white(rng, m), [(700, 500, 1.0), (1400, 700, 0.8), (2600, 1000, 0.55),
                                           (3900, 1500, 0.35)])) * env_ad(m, 0.004, 0.045)
        tail = unit(bp(white(rng, m), 500, 3500)) * env_ad(m, 0.02, 0.07, t0=0.03)
        vo = voice(rng, 0.22, [(0, f_hi), (1, 82)], [(0, "a"), (1, "uh")],
                   [(0, 0), (0.08, 1), (0.4, 0.5), (1, 0)], scale=1.0, jitter=0.05,
                   shimmer=0.6, subh=0.4, breath=1.0, drive=2.0, lpf=5000.0, presence=10.0, rasp=0.4, bright=0.25)
        c = norm(burst) + 0.2 * norm(tail)
        place(c, norm(vo), 0.012, 0.55)
        place(out, c, t0, g)
    return reverb(out, rng, 0.08, 0.025, 0.15, 200, 4000)


def bandage(rng):
    n = ns(0.6)
    t = tt(n)
    # rip: fast irregular ticks through bright cloth-like noise
    rate = 70.0 + 190.0 * np.clip(t / 0.3, 0, 1) ** 1.3
    rate = rate * (0.85 + 0.3 * slow_noise(rng, n, 20.0, circ=False))
    ph = np.cumsum(rate) / SR
    cyc = np.floor(ph).astype(int)
    p = ph - cyc
    amp = rng.uniform(0.4, 1.0, int(cyc[-1]) + 2)
    ticks = np.exp(-p / 0.18) * amp[cyc]
    rip = (unit(bp(white(rng, n), 1800, 7000)) + 0.4 * unit(bp(white(rng, n), 500, 1500))) * ticks
    rip *= pts_env(n, [(0, 0), (0.015, 0.8), (0.25, 1.0), (0.31, 0.9), (0.33, 0)])
    # wrap: soft rustle of gauze
    wrap = (bp(white(rng, n), 800, 3500) * (0.5 + 0.5 * grain_env(rng, n, 500, 0.003))
            * bump(n, 0.34, 0.6, 0.4))
    return norm(rip) + 0.35 * norm(wrap)


for _i in range(1, 4):
    reg("hurt_%d" % _i, hurt, _i)
reg("breath_heavy", breath_heavy, loop=True)
reg("eat", eat)
reg("drink", drink)
reg("cough", cough)
reg("bandage", bandage)


# =============================================================================
# World
# =============================================================================
def door_open(rng):
    n = ns(0.5)
    out = np.zeros(n)
    place(out, metal_click(rng, ns(0.06), 1700, 0.006), 0.0, 0.35)                 # handle
    m = ns(0.08)
    latch = metal_click(rng, m, 1050, 0.009) + 0.8 * modes(m, [210, 340], [0.02, 0.012], [1.0, 0.5])
    place(out, latch, 0.065, 0.55)
    # hinge creak: stick-slip pulses exciting narrow resonances
    dur = 0.37
    m = ns(dur)
    x = tt(m) / dur
    f0 = 95.0 + 120.0 * np.sin(np.pi * x * 0.8) ** 1.2 + 25.0 * x
    d, _ = glottal(rng, f0, jitter=0.03, shimmer=0.3, oq=0.3)
    d = np.diff(d, prepend=d[0])
    cr = reson(d, [(rng.uniform(800, 950), 60, 1.0), (rng.uniform(1500, 1800), 90, 0.8),
                   (2850, 160, 0.5), (4100, 300, 0.25)])
    cr = cr * bump(m, 0.0, dur, 0.45, 0.8) * (0.7 + 0.3 * slow_noise(rng, m, 12.0, circ=False))
    place(out, norm(cr), 0.11, 0.9)
    out += 0.025 * unit(bp(white(rng, n), 300, 1500)) * bump(n, 0.1, 0.5, 0.4)
    return reverb(out, rng, 0.1, 0.03, 0.15, 200, 4000)


def door_close(rng):
    n = ns(0.35)
    t = tt(n)
    thump = sweep_sine(n, 110, 68, 0.03) * np.exp(-t / 0.045)
    panel = modes(n, np.array([165, 255, 390, 560, 830, 1180]) * rng.uniform(0.96, 1.04, 6),
                  [0.065, 0.05, 0.035, 0.024, 0.015, 0.01], [1.0, 0.9, 0.65, 0.45, 0.3, 0.2])
    slap = bp(white(rng, n), 200, 2600) * env_ad(n, 0.0008, 0.014)
    x = soft(0.5 * thump + norm(panel) + 0.85 * norm(slap), 1.6)
    place(x, metal_click(rng, ns(0.05), 1400, 0.006), 0.014, 0.32)
    place(x, metal_click(rng, ns(0.03), 2100, 0.004), 0.05, 0.12)
    return reverb(x, rng, 0.18, 0.06, 0.4, 180, 3800)


def door_locked(rng):
    n = ns(0.35)
    out = np.zeros(n)
    times = [0.0, 0.055, 0.115, 0.17, 0.235]
    for i, t0 in enumerate(times):
        m = ns(0.1)
        g = (1.0 if i % 2 == 0 else 0.7) * rng.uniform(0.8, 1.0)
        c = (metal_click(rng, m, rng.uniform(1200, 1650), 0.006)
             + 0.8 * modes(m, [rng.uniform(380, 460)], [0.015], [1.0])
             + 0.7 * modes(m, [rng.uniform(140, 165), rng.uniform(240, 280)], [0.03, 0.02], [1.0, 0.6]))
        place(out, c, t0 + rng.uniform(0, 0.006), g)
    return reverb(out, rng, 0.1, 0.035, 0.25, 150, 5000)


def door_break(rng):
    n = ns(0.9)
    t = tt(n)
    thump = sweep_sine(n, 105, 45, 0.04) * np.exp(-t / 0.09)
    panel = modes(n, np.array([130, 215, 340, 560, 820]) * rng.uniform(0.95, 1.05, 5),
                  [0.09, 0.07, 0.05, 0.03, 0.02], [1.0, 0.8, 0.6, 0.4, 0.3])
    burst = bp(white(rng, n), 300, 6000) * env_ad(n, 0.0005, 0.02)
    x = soft(0.6 * thump + norm(panel) + 1.1 * norm(burst), 2.0)
    cracks = np.zeros(n)
    for _ in range(34):
        t0 = min(rng.exponential(0.13), 0.75)
        m = ns(0.06)
        c = wood_crack(rng, m, rng.uniform(500, 3200), rng.uniform(0.003, 0.012))
        place(cracks, c, t0, rng.uniform(0.25, 1.0) * np.exp(-t0 / 0.3))
    debris = (bp(white(rng, n), 300, 3200) * (0.2 + 0.8 * grain_env(rng, n, 260, 0.004))
              * env_ad(n, 0.01, 0.18))
    # planks landing
    for t0, g in ((rng.uniform(0.36, 0.42), 0.5), (rng.uniform(0.55, 0.63), 0.35)):
        m = ns(0.2)
        b = rng.uniform(200, 320)
        pl = modes(m, [b, b * 1.8, b * 2.9], [0.04, 0.025, 0.015], [1.0, 0.7, 0.4])
        place(x, norm(pl) + 0.4 * norm(bp(white(rng, m), 400, 3000) * env_ad(m, 0.0005, 0.01)), t0, g)
    out = x + 0.75 * norm(cracks) + 0.55 * norm(debris)
    return reverb(out, rng, 0.3, 0.1, 0.4, 150, 4500)


def window_open(rng):
    n = ns(0.4)
    t = tt(n)
    chat = 1.0 + 0.45 * np.sin(TAU * np.cumsum(34.0 + 10.0 * slow_noise(rng, n, 8.0, circ=False)) / SR)
    fr = svf(white(rng, n), 600.0 + 600.0 * t / 0.4, 1.2, "bp") * chat
    rumble = unit(lp(white(rng, n), 260)) * chat
    e = pts_env(n, [(0, 0), (0.03, 1), (0.28, 0.9), (0.335, 0.5), (0.36, 0.0), (0.4, 0)])
    out = (unit(fr) + 0.5 * rumble + 0.25 * unit(bp(white(rng, n), 2000, 5000))) * smooth(e, 0.01)
    out = norm(out) * 0.7
    m = ns(0.07)
    stop = norm(modes(m, [185, 310, 540], [0.03, 0.02, 0.01], [1.0, 0.7, 0.4])) + 0.4 * metal_click(rng, m, 1500, 0.004)
    place(out, stop, 0.33, 0.9)
    return reverb(out, rng, 0.06, 0.02, 0.2, 200, 4000)


def glass_break(rng, v):
    n = ns([0.9, 0.94][v - 1])
    impact = (norm(hp(white(rng, n), 1500) * env_ad(n, 0.0003, 0.01))
              + 0.6 * norm(bp(white(rng, n), 300, 1500) * env_ad(n, 0.0005, 0.02)))
    sh = (hp(white(rng, n), 2800) * (0.2 + 0.8 * grain_env(rng, n, 500, 0.002))
          * env_ad(n, 0.004, rng.uniform(0.06, 0.09)))
    tink = np.zeros(n)
    for _ in range(int(rng.integers(75, 95))):
        t0 = min(rng.exponential(0.17) + 0.01, 0.82)
        f = np.exp(rng.uniform(np.log(2200), np.log(9500)))
        tau = rng.uniform(0.008, 0.04)
        place(tink, ping(ns(tau * 6), f, tau), t0, rng.uniform(0.2, 1.0) * np.exp(-t0 / 0.35))
    for _ in range(4):  # late shards hitting the floor and skittering
        t0 = rng.uniform(0.4, 0.74)
        f = rng.uniform(3000, 7000)
        for j in range(3):
            place(tink, ping(ns(0.08), f * rng.uniform(0.9, 1.1), 0.012), t0 + j * rng.uniform(0.018, 0.03),
                  0.35 * 0.6 ** j)
    big = np.zeros(n)
    for _ in range(5):
        tau = rng.uniform(0.04, 0.08)
        place(big, ping(ns(tau * 6), rng.uniform(1300, 2600), tau), rng.uniform(0.0, 0.25), rng.uniform(0.4, 1.0))
    out = impact + 0.8 * norm(sh) + 0.9 * norm(tink) + 0.5 * norm(big)
    return reverb(out, rng, 0.2, 0.07, 0.3, 800, 9000)


def tree_fall(rng):
    n = ns(2.2)
    t = tt(n)
    out = np.zeros(n)
    T1 = 1.38
    # fibres tearing: accelerating series of cracks
    rate = np.where(t < T1, 8.0 * np.exp(t / T1 * np.log(80.0 / 8.0)), 0.0)
    ph = np.cumsum(rate) / SR
    for i in np.nonzero(np.diff(np.floor(ph)) > 0)[0]:
        t0 = max(0.0, i / SR + rng.uniform(-0.004, 0.004))
        x = t0 / T1
        f = rng.uniform(280, 520) * (1.0 + 0.8 * x)
        place(out, wood_crack(rng, ns(0.05), f, rng.uniform(0.006, 0.014)), t0,
              (0.2 + 0.8 * x ** 1.5) * rng.uniform(0.5, 1.0))
    # trunk groaning under load
    m = ns(T1)
    f0 = 58.0 + 75.0 * (tt(m) / T1) ** 2
    d, _ = glottal(rng, f0, jitter=0.08, shimmer=0.6, oq=0.4)
    groan = reson(d, [(420, 120, 1.0), (880, 160, 0.7), (1500, 250, 0.4), (2300, 400, 0.2)])
    place(out, norm(groan * bump(m, 0.05, T1, 0.8)), 0.0, 0.45)
    # big snaps as it lets go
    for t0, g in ((0.95, 0.7), (1.2, 0.85), (1.36, 1.0)):
        m = ns(0.15)
        b = rng.uniform(290, 380)
        snap = (norm(bp(white(rng, m), 500, 6000) * env_ad(m, 0.0003, 0.012))
                + norm(modes(m, [b, b * 2.1, b * 3.9], [0.03, 0.02, 0.01], [1.0, 0.7, 0.5])))
        place(out, snap, t0 + rng.uniform(-0.02, 0.02), g)
    # canopy rushing through the air
    wh = (bp(white(rng, n), 1400, 6500) * (0.4 + 0.6 * grain_env(rng, n, 900, 0.003))
          * bump(n, 1.0, 1.75, 0.78, 1.5))
    out += 0.4 * norm(wh)
    # ground impact
    tc = 1.6
    m = n - ns(tc)
    tm = tt(m)
    thump = sweep_sine(m, 85, 36, 0.05) * np.exp(-tm / 0.16)
    body = lp(white(rng, m), 700) * env_ad(m, 0.002, 0.07)
    leaves = (bp(white(rng, m), 1200, 7000) * (0.25 + 0.75 * grain_env(rng, m, 700, 0.003))
              * env_ad(m, 0.01, 0.2))
    br = np.zeros(m)
    for _ in range(24):
        t0 = min(rng.exponential(0.12), 0.5)
        place(br, wood_crack(rng, ns(0.05), rng.uniform(400, 2600), rng.uniform(0.004, 0.012)), t0,
              rng.uniform(0.3, 1.0) * np.exp(-t0 / 0.25))
    crash_ = soft(0.7 * thump + norm(bp(body, 120, 2000)), 1.6) + 0.75 * norm(leaves) + 0.65 * norm(br)
    place(out, crash_, tc, 1.4)
    k = ns(0.3)
    place(out, sweep_sine(k, 70, 38, 0.04) * np.exp(-tt(k) / 0.1), tc + 0.23, 0.5)   # trunk bounce
    out = reverb(out, rng, 0.4, 0.14, 0.35, 150, 4500)
    return out * np.minimum(1.0, (2.2 - t) / 0.08)


def chop(rng, v):
    n = ns(rng.uniform(0.28, 0.32))
    t = tt(n)
    base = rng.uniform(190, 235)
    fr = base * np.array([1.0, 1.81, 3.05, 5.4]) * rng.uniform(0.96, 1.04, 4)
    thock = modes(n, fr, [0.05, 0.035, 0.02, 0.01], [1.0, 0.75, 0.45, 0.25])
    bite = (norm(hp(white(rng, n), 2500) * env_ad(n, 0.0003, 0.003))
            + 0.8 * norm(bp(white(rng, n), 1000, 3000) * env_ad(n, 0.0005, 0.012)))
    ring = modes(n, [rng.uniform(2900, 3500)], [0.025], [1.0])      # axe head
    out = norm(thock) + 0.6 * bite + 0.06 * ring
    out += 0.7 * sweep_sine(n, 110, 70, 0.02) * np.exp(-t / 0.04)
    for _ in range(int(rng.integers(3, 6))):                         # chips flying
        place(out, wood_crack(rng, ns(0.03), rng.uniform(1500, 4200), rng.uniform(0.002, 0.004)),
              rng.uniform(0.03, 0.14), rng.uniform(0.08, 0.22))
    return reverb(out, rng, 0.2, 0.06, 0.25, 200, 4000)


def pickup(rng):
    n = ns(0.15)
    g = grain_env(rng, n, 900, 0.002)
    e = bump(n, 0.0, 0.085, 0.35) + 0.7 * bump(n, 0.055, 0.15, 0.4)
    rust = bp(white(rng, n), 1200, 5000) * (0.35 + 0.65 * g) * e
    low = bp(white(rng, n), 200, 600) * env_ad(n, 0.004, 0.02)
    return norm(rust) + 0.3 * norm(low)


def drop(rng):
    n = ns(0.2)
    t = tt(n)
    x = 0.6 * sweep_sine(n, 130, 80, 0.02) * np.exp(-t / 0.03)
    x += norm(bp(white(rng, n), 200, 1500) * env_ad(n, 0.001, 0.014))
    x += 0.7 * norm(modes(n, [rng.uniform(260, 300), rng.uniform(440, 500), rng.uniform(760, 860)],
                          [0.022, 0.014, 0.008], [1.0, 0.7, 0.4]))
    m = ns(0.1)
    b2 = (0.5 * sweep_sine(m, 150, 100, 0.015) * np.exp(-tt(m) / 0.018)
          + norm(bp(white(rng, m), 250, 1800) * env_ad(m, 0.001, 0.008)))
    place(x, b2, 0.09, 0.3)
    return x


def craft(rng):
    n = ns(0.9)
    out = np.zeros(n)
    for i, t0 in enumerate((0.03, 0.33, 0.62)):
        m = ns(0.26)
        tm = tt(m)
        b = rng.uniform(250, 280)
        knock = modes(m, [b, b * 1.74, b * 3.0], [0.04, 0.03, 0.015], [1.0, 0.7, 0.4])
        head = metal_click(rng, m, rng.uniform(2000, 2250), 0.012)
        nail = modes(m, [3150 + 260 * i], [0.03], [1.0])          # nail pitch rises as it sinks
        thump = np.sin(TAU * 100 * tm) * np.exp(-tm / 0.03)
        tap = norm(knock) + 0.6 * head + 0.12 * nail + 0.5 * thump
        place(out, tap, t0 + rng.uniform(-0.008, 0.008), (0.8, 1.0, 0.92)[i])
    return reverb(out, rng, 0.15, 0.05, 0.25, 200, 5000)


def saw(rng):
    n = ns(1.2)
    out = np.zeros(n)
    sd = 0.3
    for i in range(4):
        d = sd - 0.012
        m = ns(d)
        x = tt(m) / d
        push = (i % 2 == 0)
        speed = np.sin(np.pi * x) ** 0.8
        tf = (70.0 + rng.uniform(150, 190) * speed) * (1.0 if push else 0.85)
        ph = np.cumsum(tf) / SR
        teeth = (1.0 - (ph % 1.0)) ** 2
        lo, hi = (1300, 5200) if push else (1000, 4000)
        rasp = bp(white(rng, m), lo, hi) * (0.2 + 0.8 * teeth)
        wood = bp(white(rng, m), 350, 950) * (0.3 + 0.7 * teeth)
        s = (norm(rasp) + 0.45 * norm(wood)) * speed * (1.0 if push else 0.62)
        place(out, s, i * sd + 0.006)
    return out


def zipper(rng):
    n = ns(0.4)
    t = tt(n)
    x = t / 0.4
    rate = (170.0 + 380.0 * np.sin(0.5 * np.pi * np.clip(x / 0.85, 0, 1))) * (0.95 + 0.1 * slow_noise(rng, n, 15.0, circ=False))
    ph = np.cumsum(rate) / SR
    cyc = np.floor(ph).astype(int)
    p = ph - cyc
    amp = rng.uniform(0.5, 1.0, int(cyc[-1]) + 2)
    src = white(rng, n) * np.exp(-p / 0.12) * amp[cyc]
    y = unit(bp(src, 1800, 7500)) + 0.5 * unit(reson(src, [(3100, 500, 1.0), (5200, 800, 0.6)]))
    y *= smooth(pts_env(n, [(0, 0), (0.02, 0.8), (0.3, 1.0), (0.345, 0.7), (0.36, 0.0), (0.4, 0)]), 0.006)
    y = norm(y)
    place(y, metal_click(rng, ns(0.035), 2400, 0.004), 0.352, 0.45)
    return y


def plant(rng):
    n = ns(0.5)
    out = np.zeros(n)
    stab = norm(lp(white(rng, n), 500) * env_ad(n, 0.002, 0.02)) + 0.5 * norm(bp(white(rng, n), 800, 3500) * env_ad(n, 0.001, 0.01))
    out += 0.7 * stab
    soil = _apply_gain(white(rng, n), lambda f: g_hp(f, 250, 2) * g_lp(f, 3500, 2) * (np.maximum(f, 50.0) / 800.0) ** -0.4)
    gr = grain_env(rng, n, 420, 0.003)
    scrape = soil * (0.15 + 0.85 * gr) * bump(n, 0.04, 0.4, 0.4, 1.2)
    out += norm(scrape)
    for _ in range(6):   # pebbles ticking against the trowel
        place(out, norm(bp(white(rng, ns(0.02)), 2000, 6000) * env_ad(ns(0.02), 0.0003, 0.002)),
              rng.uniform(0.07, 0.36), rng.uniform(0.1, 0.3))
    toss = bp(white(rng, n), 300, 2200) * (0.3 + 0.7 * grain_env(rng, n, 300, 0.004)) * bump(n, 0.37, 0.5, 0.3)
    out += 0.4 * norm(toss)
    return out


def water_pour(rng):
    n = ns(1.0)
    t = tt(n)
    out = np.zeros(n)
    for _ in range(260):
        t0 = rng.uniform(0.0, 0.93)
        centre = 650.0 + 550.0 * t0                      # vessel filling up -> resonance rises
        f = centre * np.exp(rng.normal(0.0, 0.45))
        place(out, bubble(min(f, 5000.0), rng.uniform(0.008, 0.03)), t0, rng.uniform(0.2, 1.0) ** 1.5)
    hiss = unit(bp(white(rng, n), 1500, 7000)) * (0.6 + 0.4 * slow_noise(rng, n, 25.0, circ=False))
    glug = unit(bp(white(rng, n), 250, 650)) * (0.3 + 0.7 * slow_noise(rng, n, 9.0, circ=False))
    y = norm(out) + 0.1 * hiss + 0.12 * glug
    return y * smooth(pts_env(n, [(0, 0), (0.07, 1), (0.82, 1), (1.0, 0)]), 0.02)


def ui_click(rng):
    n = ns(0.05)
    t = tt(n)
    x = np.sin(TAU * 1500 * t) * np.exp(-t / 0.006) + 0.4 * np.sin(TAU * 2800 * t) * np.exp(-t / 0.003)
    x += 0.3 * norm(lp(white(rng, n), 3000) * env_ad(n, 0.0003, 0.001))
    return x * (1.0 - np.exp(-t / 0.0004))


def ui_open(rng):
    n = ns(0.12)
    t = tt(n)
    f = 280.0 + 340.0 * (1.0 - np.exp(-t / 0.03))
    pop = np.sin(TAU * np.cumsum(f) / SR) * env_ad(n, 0.006, 0.03)
    wh = svf(white(rng, n), 800.0 + 2200.0 * t / 0.12, 1.5, "bp") * bump(n, 0.0, 0.12, 0.45, 1.5)
    return pop + 0.35 * norm(wh)


def ui_error(rng):
    n = ns(0.2)
    out = np.zeros(n)
    for t0, f in ((0.0, 233.0), (0.095, 196.0)):
        m = ns(0.1)
        tm = tt(m)
        tick = np.zeros(m)
        for h, a, d in ((1, 1.0, 0.024), (2, 0.6, 0.02), (3, 0.42, 0.016), (4, 0.25, 0.012), (5, 0.15, 0.009)):
            tick += a * np.sin(TAU * h * f * tm) * np.exp(-tm / d)
        tick *= 1.0 - np.exp(-tm / 0.0015)
        tick += 0.25 * norm(lp(white(rng, m), 900) * env_ad(m, 0.0008, 0.004))
        place(out, tick, t0)
    return out


reg("door_open", door_open, perc=True)
reg("door_close", door_close, perc=True)
reg("door_locked", door_locked, perc=True)
reg("door_break", door_break, perc=True)
reg("window_open", window_open)
for _i in range(1, 3):
    reg("glass_break_%d" % _i, glass_break, _i, perc=True)
reg("tree_fall", tree_fall)
for _i in range(1, 4):
    reg("chop_%d" % _i, chop, _i, perc=True)
reg("pickup", pickup)
reg("drop", drop, perc=True)
reg("craft", craft)
reg("saw", saw)
reg("zipper", zipper)
reg("plant", plant, perc=True)
reg("water_pour", water_pour)
reg("ui_click", ui_click)
reg("ui_open", ui_open)
reg("ui_error", ui_error)


# =============================================================================
# Vehicle
# =============================================================================
def engine(rng, n, rate, cyl, fres, tau, noise=0.5, rattle=0.15, firings=None):
    """Combustion-pulse engine model. firings=<int> -> exactly periodic buffer
    (loop mode) with that many firing pulses; otherwise `rate` is the firing
    frequency in Hz (array)."""
    circ = firings is not None
    cyl = np.asarray(cyl, float)
    nc = len(cyl)
    if circ:
        ph = np.arange(n) * (float(firings) / n)
        rate = np.full(n, firings * SR / float(n))
        var = 1.0 + 0.10 * rng.standard_normal(firings)
    else:
        rate = np.maximum(np.broadcast_to(np.asarray(rate, float), (n,)), 1.0)
        ph = np.cumsum(rate) / SR
        var = 1.0 + 0.10 * rng.standard_normal(int(ph[-1]) + 8)
    k = np.floor(ph).astype(int)
    fr = ph - k
    tone = np.zeros(n)
    fenv = np.zeros(n)
    for back in range(4):
        ts = (fr + back) / rate
        kk = k - back
        a = cyl[kk % nc] * var[kk % len(var)]
        if not circ:
            a = np.where(kk >= 0, a, 0.0)
        w = np.exp(-ts / tau) * (1.0 - np.exp(-ts / 0.0007))
        s = np.zeros(n)
        for f, g in fres:
            s += g * np.sin(TAU * f * ts)
        tone += a * w * s
        fenv += a * np.exp(-ts / (tau * 1.6))
    fenv /= fenv.max() + 1e-12
    nz = unit(bp(white(rng, n), 140, 1700, circ=circ))
    rt = unit(bp(white(rng, n), 1400, 5000, circ=circ))
    out = norm(tone) + noise * 0.35 * nz * fenv + rattle * 0.3 * rt * fenv ** 2
    return out, ph, fenv


def engine_idle(rng):
    n = ns(1.5)
    core, ph, _ = engine(rng, n, None, [1.0, 0.75, 0.93, 0.68],
                         [(96, 0.7), (190, 1.0), (385, 0.7), (760, 0.35)], 0.014, noise=1.3, rattle=0.3, firings=40)
    out = core + 0.12 * np.sin(TAU * 2 * ph) + 0.12 * np.sin(TAU * 3 * ph + 0.5) + 0.1 * np.sin(TAU * 4 * ph + 1.0)
    return hp(lp(out, 3200, circ=True), 45, circ=True)


def engine_run(rng):
    n = ns(1.5)
    core, ph, fenv = engine(rng, n, None, [1.0, 0.9, 0.96, 0.87],
                            [(150, 0.7), (300, 1.0), (600, 0.7), (1200, 0.35)], 0.006, noise=1.0, rattle=0.35, firings=104)
    out = core + 0.1 * np.sin(TAU * 0.5 * ph + 0.9)                 # half-order lump
    for h, a in ((1, 0.22), (2, 0.3), (3, 0.26), (4, 0.2), (5, 0.15), (6, 0.11), (8, 0.08), (10, 0.05)):
        out += a * np.sin(TAU * h * ph + rng.uniform(0, TAU))       # firing-order drone (carries the rpm)
    out += 0.12 * unit(bp(white(rng, n), 800, 3500, circ=True)) * (0.6 + 0.4 * fenv)
    return hp(lp(out, 4200, circ=True), 45, circ=True)


def _starter(rng, n, crank_rate, whine_f):
    """Starter motor: gear whine that sags on every compression stroke."""
    t = tt(n)
    cph = np.cumsum(crank_rate) / SR
    load = (0.5 - 0.5 * np.cos(TAU * cph)) ** 2
    f = whine_f * (1.0 - 0.16 * load)
    ph = np.cumsum(f) / SR
    whine = np.zeros(n)
    for h in range(1, 9):
        whine += (1.0 / h ** 1.1) * np.sin(TAU * h * ph + rng.uniform(0, TAU)) * (h * f < 9500)
    gear = unit(bp(white(rng, n), 900, 3800)) * (0.4 + 0.6 * (1.0 - load))
    chug = (unit(lp(white(rng, n), 220)) * 0.6 + np.sin(TAU * 68 * t)) * load ** 2
    return 0.6 * unit(whine) * (0.55 + 0.45 * (1.0 - load)) + 0.3 * gear + 0.9 * chug


def engine_start(rng):
    n = ns(1.4)
    t = tt(n)
    crank = np.interp(t, [0, 0.7, 1.4], [6.5, 8.2, 8.2])
    wf = 150.0 + 290.0 * (1.0 - np.exp(-t / 0.05))
    wf = wf * np.interp(t, [0, 0.76, 0.92, 1.4], [1.0, 1.0, 0.45, 0.45])
    st = _starter(rng, n, crank, wf) * smooth(pts_env(n, [(0, 0), (0.02, 1), (0.76, 1), (0.92, 0), (1.4, 0)]), 0.01)
    rate = np.interp(t, [0, 0.70, 0.78, 0.98, 1.15, 1.4], [12, 12, 18, 54, 40, 29])
    core, ph, _ = engine(rng, n, rate, [1.0, 0.75, 0.93, 0.68],
                         [(100, 0.7), (200, 1.0), (400, 0.7), (780, 0.35)], 0.013, noise=1.3, rattle=0.3)
    eng = (core + 0.15 * np.sin(TAU * 2 * ph) + 0.12 * np.sin(TAU * 3 * ph)) * smooth(pts_env(n, [(0, 0), (0.70, 0), (0.77, 0.8), (0.97, 1.0), (1.4, 0.8)]), 0.01)
    out = 0.75 * norm(st) + norm(lp(eng, 3200))
    place(out, metal_click(rng, ns(0.04), 1300, 0.006), 0.0, 0.4)      # solenoid
    return out * np.minimum(1.0, (1.4 - t) / 0.08)


def engine_fail(rng):
    n = ns(1.2)
    t = tt(n)
    crank = np.interp(t, [0, 0.9, 1.2], [6.4, 4.8, 2.0])
    wf = (140.0 + 260.0 * (1.0 - np.exp(-t / 0.05))) * np.interp(t, [0, 0.3, 0.9, 1.2], [1.0, 0.97, 0.84, 0.25])
    st = _starter(rng, n, crank, wf) * smooth(pts_env(n, [(0, 0), (0.02, 1), (0.9, 0.95), (1.17, 0.0), (1.2, 0)]), 0.012)
    out = norm(st)
    place(out, metal_click(rng, ns(0.04), 1300, 0.006), 0.0, 0.4)
    place(out, metal_click(rng, ns(0.04), 1100, 0.006), 0.9, 0.3)
    # one weak cough that never catches
    m = ns(0.12)
    cough_ = sweep_sine(m, 90, 55, 0.03) * np.exp(-tt(m) / 0.03) + 0.5 * norm(lp(white(rng, m), 500) * env_ad(m, 0.002, 0.03))
    place(out, cough_, 0.56, 0.35)
    return out


def car_door(rng):
    n = ns(0.4)
    t = tt(n)
    thump = sweep_sine(n, 92, 58, 0.03) * np.exp(-t / 0.05)
    panel = modes(n, np.array([180, 290, 440, 690, 1050]) * rng.uniform(0.96, 1.04, 5),
                  [0.05, 0.038, 0.026, 0.016, 0.01], [1.0, 0.85, 0.6, 0.4, 0.25])
    air = bp(white(rng, n), 150, 900) * env_ad(n, 0.002, 0.028)
    x = soft(0.6 * thump + norm(panel) + 0.8 * norm(air), 1.7)
    place(x, metal_click(rng, ns(0.05), 900, 0.008), 0.0, 0.4)
    place(x, metal_click(rng, ns(0.05), 1300, 0.006), 0.022, 0.3)
    x += 0.08 * norm(bp(white(rng, n), 2000, 4000) * env_ad(n, 0.001, 0.02))
    return lp(reverb(x, rng, 0.12, 0.04, 0.3, 160, 3200), 5500)


def horn(rng):
    n = ns(0.8)
    t = tt(n)
    out = np.zeros(n)
    for f0, g in ((415.3, 1.0), (523.3, 0.9)):
        f = f0 * (1.0 - 0.03 * np.exp(-t / 0.012)) * (1.0 + 0.002 * np.sin(TAU * 6.0 * t + rng.uniform(0, TAU)))
        ph = np.cumsum(f) / SR
        for h in range(1, int(9000 / f0) + 1):
            fh = f0 * h
            a = (1.0 / h ** 0.7) * (1.0 + 2.5 * np.exp(-((fh - 2600.0) / 900.0) ** 2)) \
                * (1.0 + 1.2 * np.exp(-((fh - 1100.0) / 400.0) ** 2))
            out += g * a * np.sin(TAU * h * ph)
    env = smooth(pts_env(n, [(0, 0), (0.012, 1), (0.74, 1), (0.795, 0), (0.8, 0)]), 0.006)
    return reverb(soft(out, 1.8) * env, rng, 0.06, 0.02, 0.15, 300, 5000)


def crash(rng):
    n = ns(0.9)
    t = tt(n)
    thump = sweep_sine(n, 95, 42, 0.04) * np.exp(-t / 0.11)
    burst = lp(white(rng, n), 5500) * env_ad(n, 0.0005, 0.03)
    crunch = bp(white(rng, n), 400, 5000) * (0.15 + 0.85 * grain_env(rng, n, 220, 0.004)) * env_ad(n, 0.002, 0.16)
    metal = np.zeros(n)
    for _ in range(8):
        t0 = min(abs(rng.normal(0.0, 0.13)), 0.45)
        m = ns(0.4)
        place(metal, clang(rng, m, rng.uniform(220, 900), rng.uniform(0.04, 0.12)), t0,
              rng.uniform(0.3, 1.0) * np.exp(-t0 / 0.25))
    x = soft(thump + 0.9 * norm(burst) + 0.9 * norm(crunch) + 0.7 * norm(metal), 2.0)
    glass = np.zeros(n)
    for _ in range(22):
        t0 = min(rng.exponential(0.15) + 0.03, 0.75)
        tau = rng.uniform(0.008, 0.03)
        place(glass, ping(ns(tau * 6), np.exp(rng.uniform(np.log(2500), np.log(9000))), tau), t0,
              rng.uniform(0.2, 1.0) * np.exp(-t0 / 0.3))
    scrape = bp(white(rng, n), 700, 2600) * (0.3 + 0.7 * grain_env(rng, n, 400, 0.003)) * bump(n, 0.1, 0.7, 0.2)
    out = x + 0.22 * norm(glass) + 0.25 * norm(scrape)
    return reverb(out, rng, 0.35, 0.12, 0.5, 150, 5000)


def skid(rng):
    n = ns(0.8)
    t = tt(n)
    x = t / 0.8
    out = np.zeros(n)
    for base, g in ((rng.uniform(1150, 1300), 1.0), (rng.uniform(1650, 1850), 0.55)):
        wob = slow_noise(rng, n, 9.0, circ=False) - 0.5
        f = base * (1.0 - 0.10 * x ** 2) * (1.0 + 0.05 * wob)
        ph = np.cumsum(f) / SR
        s = np.zeros(n)
        for h, a in ((1, 1.0), (2, 0.45), (3, 0.3), (4, 0.12)):
            s += a * np.sin(TAU * h * ph + rng.uniform(0, TAU))
        out += g * s * (0.55 + 0.45 * slow_noise(rng, n, 60.0, circ=False))
    rub = unit(bp(white(rng, n), 500, 3200)) * (0.5 + 0.5 * slow_noise(rng, n, 40.0, circ=False))
    env = smooth(pts_env(n, [(0, 0), (0.04, 1), (0.5, 0.9), (0.8, 0)]), 0.01)
    return (norm(out) + 0.12 * rub) * env


reg("engine_idle", engine_idle, loop=True)
reg("engine_run", engine_run, loop=True)
reg("engine_start", engine_start, perc=True)
reg("engine_fail", engine_fail, perc=True)
reg("car_door", car_door, perc=True)
reg("horn", horn)
reg("crash", crash, perc=True)
reg("skid", skid)


# =============================================================================
# Ambience loops (no animals anywhere: only weather, water, fire, machines)
# =============================================================================
def rain_loop(rng):
    T = 6.0
    n = ns(T)
    t = tt(n)
    base = unit(_apply_gain(white(rng, n), lambda f: g_hp(f, 500, 2) * g_lp(f, 8500, 2)
                            * (np.maximum(f, 50.0) / 1000.0) ** -0.25, circ=True))
    slow = (1.0 + 0.08 * np.sin(TAU * t / T + rng.uniform(0, TAU))
            + 0.05 * np.sin(TAU * 3 * t / T + rng.uniform(0, TAU)))
    imp = np.zeros(n)
    k = int(1400 * T)
    np.add.at(imp, rng.integers(0, n, k), (0.25 + 0.75 * rng.random(k) ** 2) * rng.choice([-1.0, 1.0], k))
    patter = unit(bp(imp, 1800, 7500, circ=True))
    patter = 3.0 * np.tanh(patter / 3.0)
    drops = np.zeros(n)
    for _ in range(int(22 * T)):
        f = np.exp(rng.uniform(np.log(900), np.log(3200)))
        tau = rng.uniform(0.003, 0.009)
        m = ns(tau * 7)
        tm = tt(m)
        d = np.sin(TAU * f * tm * (1.0 + 4.0 * tm)) * np.exp(-tm / tau)
        place_wrap(drops, d, rng.uniform(0, T), rng.uniform(0.3, 1.0))
    low = unit(bp(white(rng, n), 90, 420, circ=True))
    out = 0.55 * base * slow + 0.5 * patter + 1.4 * norm(drops) + 0.2 * low
    return hp(out, 60, circ=True)


def wind_loop(rng):
    T = 8.0
    n = ns(T)
    t = tt(n)
    # two/three gusts per loop (whole cycles -> periodic) plus slower random drift
    gust = (0.30 * np.sin(TAU * 2 * t / T + rng.uniform(0, TAU)) + 0.22 * np.sin(TAU * 3 * t / T + rng.uniform(0, TAU))
            + 0.12 * np.sin(TAU * 5 * t / T + rng.uniform(0, TAU)) + 0.35 * (slow_noise(rng, n, 0.9) - 0.5))
    gust = (gust - gust.min()) / (gust.max() - gust.min())
    gust = 0.5 - 0.5 * np.cos(np.pi * gust)                 # more contrast between lull and gust
    low = unit(bp(white(rng, n), 60, 320, circ=True))
    mid = unit(bp(white(rng, n), 250, 900, circ=True))
    high = unit(bp(white(rng, n), 800, 2600, circ=True))
    air = unit(bp(white(rng, n), 2500, 6000, circ=True))
    out = (0.7 * low * (0.3 + 0.7 * gust) + 0.75 * mid * (0.12 + 0.88 * gust ** 1.4)
           + 0.45 * high * (0.04 + 0.96 * gust ** 2.2) + 0.12 * air * gust ** 3)
    # whistling through gaps: a resonance that slides with the gust strength
    centres = [420.0, 520.0, 640.0, 780.0, 950.0]
    pos = np.clip(0.6 * gust + 0.4 * slow_noise(rng, n, 0.6), 0, 1) * (len(centres) - 1)
    wn = white(rng, n)
    for i, fc in enumerate(centres):
        w = np.clip(1.0 - np.abs(pos - i), 0, 1)
        out += 0.3 * w * unit(narrow(wn, fc, 0.035, circ=True)) * gust ** 1.5
    return hp(out, 45, circ=True)


def forest_loop(rng):
    T = 8.0
    n = ns(T)
    gust_a = slow_noise(rng, n, 0.3)
    gust_b = slow_noise(rng, n, 0.45)
    flut_a = slow_noise(rng, n, 14.0)
    flut_b = slow_noise(rng, n, 9.0)
    hi = unit(bp(white(rng, n), 2200, 8500, circ=True)) * (0.12 + 0.88 * gust_a ** 1.6) * (0.45 + 0.55 * flut_a)
    mid = unit(bp(white(rng, n), 900, 3600, circ=True)) * (0.15 + 0.85 * gust_b ** 1.4) * (0.5 + 0.5 * flut_b)
    bed = unit(bp(white(rng, n), 90, 480, circ=True)) * (0.5 + 0.25 * gust_a + 0.25 * gust_b)
    # individual leaves brushing each other (random, broadband, denser in gusts)
    p = (70.0 / SR) * (0.15 + 0.85 * gust_a ** 2)
    imp = (rng.random(n) < p) * (0.3 + 0.7 * rng.random(n)) * rng.choice([-1.0, 1.0], n)
    ticks = unit(bp(imp, 2500, 9000, circ=True))
    ticks = 5.0 * np.tanh(ticks / 5.0)
    out = 0.6 * hi + 0.5 * mid + 0.35 * bed + 0.1 * ticks
    return hp(out, 50, circ=True)


def river_loop(rng):
    T = 6.0
    n = ns(T)
    out = 0.35 * unit(_apply_gain(white(rng, n), lambda f: g_hp(f, 250, 2) * g_lp(f, 5000, 2)
                                  * (np.maximum(f, 50.0) / 1000.0) ** -0.3, circ=True))
    for lo, hi, rate, g in ((300, 700, 6.0, 0.5), (700, 1500, 9.0, 0.45), (1500, 3000, 12.0, 0.35), (3000, 6000, 14.0, 0.2)):
        band = unit(bp(white(rng, n), lo, hi, circ=True))
        out += g * band * (0.3 + 0.7 * slow_noise(rng, n, rate) ** 1.5)
    bub = np.zeros(n)
    for _ in range(int(95 * T)):
        f = np.exp(rng.uniform(np.log(300), np.log(2600)))
        place_wrap(bub, bubble(f, rng.uniform(0.01, 0.04)), rng.uniform(0, T), rng.uniform(0.15, 1.0) ** 2)
    out += 0.9 * norm(bub)
    out += 0.25 * unit(bp(white(rng, n), 60, 220, circ=True))
    return hp(out, 50, circ=True)


def fire_loop(rng):
    T = 5.0
    n = ns(T)
    roar = unit(_apply_gain(white(rng, n), lambda f: g_hp(f, 70, 2) * g_lp(f, 750, 2)
                            * (np.maximum(f, 30.0) / 100.0) ** -0.35, circ=True))
    roar *= 0.55 + 0.45 * slow_noise(rng, n, 8.0)
    hiss = unit(bp(white(rng, n), 2000, 8000, circ=True)) * (0.5 + 0.5 * slow_noise(rng, n, 5.0))
    out = 0.2 * roar + 0.03 * hiss
    cr = np.zeros(n)
    for _ in range(int(24 * T)):
        f = np.exp(rng.uniform(np.log(1200), np.log(6000)))
        tau = rng.uniform(0.0004, 0.0025)
        m = ns(0.02)
        tm = tt(m)
        c = np.sin(TAU * f * tm) * np.exp(-tm / tau) + 0.6 * white(rng, m) * np.exp(-tm / (tau * 0.6))
        place_wrap(cr, c, rng.uniform(0, T), min(0.08 * (1.0 + rng.pareto(2.2)), 0.7))
    for _ in range(9):     # bigger pops as pockets of sap burst
        f = rng.uniform(400, 1200)
        m = ns(0.08)
        tm = tt(m)
        tau = rng.uniform(0.006, 0.012)
        c = (np.sin(TAU * f * tm) * np.exp(-tm / tau) + 0.8 * norm(hp(white(rng, m), 1500) * env_ad(m, 0.0002, 0.002)))
        place_wrap(cr, c, rng.uniform(0, T), rng.uniform(0.35, 0.7))
    return hp(out + cr, 40, circ=True)


def generator_loop(rng):
    n = ns(2.0)
    t = tt(n)
    core, ph, fenv = engine(rng, n, None, [1.0, 0.45], [(230, 1.0), (470, 0.9), (940, 0.5), (1500, 0.25)],
                            0.005, noise=0.9, rattle=0.7, firings=100)
    out = core + 0.1 * np.sin(TAU * 0.5 * ph + 0.3)
    for h, a in ((1, 0.15), (2, 0.25), (3, 0.22), (4, 0.2), (5, 0.14), (6, 0.1), (7, 0.07)):
        out += a * np.sin(TAU * h * ph + rng.uniform(0, TAU))
    out += 0.1 * unit(bp(white(rng, n), 1500, 4500, circ=True))                    # cooling fan
    out *= 1.0 + 0.06 * np.sin(TAU * 2.5 * t) + 0.03 * np.sin(TAU * 4.0 * t + 1.0)  # governor hunting
    return hp(lp(out, 4500, circ=True), 40, circ=True)


def alarm_loop(rng):
    T = 1.6
    n = ns(T)
    seg = n // 4
    f = np.empty(n)
    f[:seg] = 980.0
    f[seg:2 * seg] = 780.0
    f[2 * seg:3 * seg] = 980.0
    f[3 * seg:] = 780.0
    w = np.zeros(n)
    k = ns(0.006)
    w[:k] = np.hanning(k + 2)[1:-1]
    w = np.roll(w / w.sum(), -(k // 2))
    f = np.fft.irfft(np.fft.rfft(f) * np.fft.rfft(w), n)       # circular smoothing of the steps
    cycles = np.sum(f) / SR
    f *= np.round(cycles) / cycles                              # whole number of cycles per loop
    ph = np.cumsum(f) / SR
    out = np.zeros(n)
    for h, a in enumerate((1.0, 0.35, 0.5, 0.2, 0.3, 0.12, 0.15, 0.06, 0.08), start=1):
        out += a * np.sin(TAU * h * ph)
    out = _apply_gain(out, lambda fq: 0.5 + 1.5 / np.sqrt(1.0 + ((fq - 2900.0) / 700.0) ** 2), circ=True)
    return out


def room_tone(rng):
    T = 6.0
    n = ns(T)
    t = tt(n)
    air = unit(_apply_gain(white(rng, n), lambda f: g_hp(f, 40, 2) * g_lp(f, 1500, 2)
                           * (np.maximum(f, 30.0) / 200.0) ** -0.7, circ=True))
    hiss = unit(bp(white(rng, n), 2000, 6000, circ=True))
    hum = (0.5 * np.sin(TAU * 60 * t) + 0.35 * np.sin(TAU * 120 * t + 0.7)
           + 0.15 * np.sin(TAU * 180 * t + 1.9) + 0.06 * np.sin(TAU * 300 * t + 0.3))
    slow = 1.0 + 0.08 * np.sin(TAU * t / T + 0.4) + 0.05 * np.sin(TAU * 2 * t / T + 2.0)
    return (air * slow + 0.04 * hiss + 0.28 * hum)


reg("rain_loop", rain_loop, loop=True, peak=-9.0)
reg("wind_loop", wind_loop, loop=True, peak=-9.0)
reg("forest_loop", forest_loop, loop=True, peak=-9.0)
reg("river_loop", river_loop, loop=True, peak=-9.0)
reg("fire_loop", fire_loop, loop=True, peak=-3.0)
reg("generator_loop", generator_loop, loop=True, peak=-3.0)
reg("alarm_loop", alarm_loop, loop=True, peak=-3.0)
reg("room_tone", room_tone, loop=True, peak=-9.0)


# =============================================================================
# Music (original; built only from scale tones chosen here, no quoted melody)
# =============================================================================
def pad_note(rng, freq, dur, attack, release, nharm=5, roll=1.7, detune=(-6.0, 0.0, 5.0)):
    n = ns(dur)
    t = tt(n)
    out = np.zeros(n)
    for c in detune:
        f = freq * 2.0 ** (c / 1200.0)
        for h in range(1, nharm + 1):
            if f * h > 5000:
                break
            lfo = 0.65 + 0.35 * np.sin(TAU * rng.uniform(0.07, 0.25) * t + rng.uniform(0, TAU))
            out += (1.0 / h ** roll) * lfo * np.sin(TAU * f * h * t + rng.uniform(0, TAU))
    na, nr = ns(attack), ns(release)
    out[:na] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(na) / na)
    out[n - nr:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(nr) / nr)
    return out


def soft_key(freq, dur=4.5):
    n = ns(dur)
    t = tt(n)
    out = np.zeros(n)
    for r, a, d in ((1.0, 1.0, 1.8), (2.0, 0.30, 1.1), (3.0, 0.10, 0.7), (4.2, 0.04, 0.4)):
        out += a * np.exp(-t / d) * np.sin(TAU * freq * r * t)
    na, nr = ns(0.012), ns(0.4)
    out[:na] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(na) / na)
    out[n - nr:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(nr) / nr)
    return out


def music_calm(rng):
    T = 48.0
    n = ns(T)
    t = tt(n)
    seg = T / 4.0
    chords = [
        [45, 52, 59, 60, 64],   # A2 E3 B3 C4 E4   A minor add9
        [41, 53, 57, 60, 64],   # F2 F3 A3 C4 E4   F major 7
        [38, 50, 57, 64, 65],   # D2 D3 A3 E4 F4   D minor add9
        [40, 52, 59, 62, 67],   # E2 E3 B3 D4 G4   E minor 7
    ]
    pad = np.zeros(n)
    for k, ch in enumerate(chords):
        for j, m in enumerate(ch):
            note = pad_note(rng, midi(m), seg + 6.5, 3.5, 4.0, nharm=6, roll=1.9 if j == 0 else 1.45)
            place_wrap(pad, note, k * seg - 3.0 + rng.uniform(-0.3, 0.3), 0.9 if j == 0 else 1.0 - 0.06 * j)
    # pedal drone on A (frequencies are multiples of 1/T -> exactly periodic)
    drone = np.zeros(n)
    for f, a in ((55.0, 0.35), (55.0 + 3.0 / T, 0.25), (110.0, 1.0), (110.0 - 2.0 / T, 0.7), (165.0, 0.3),
                 (220.0 + 1.0 / T, 0.3), (330.0 - 1.0 / T, 0.1)):
        drone += a * np.sin(TAU * f * t + rng.uniform(0, TAU))
    drone *= 0.8 + 0.2 * np.sin(TAU * 2.0 * t / T + rng.uniform(0, TAU))
    # a few sparse, soft notes
    notes = [(2.0, 76), (6.0, 71), (8.5, 72), (14.5, 69), (18.0, 76), (21.5, 67),
             (26.0, 77), (29.5, 76), (33.0, 69), (38.5, 71), (42.0, 74), (45.0, 64)]
    keys = np.zeros(n)
    for t0, m in notes:
        k = soft_key(midi(m))
        g = rng.uniform(0.75, 1.0)
        place_wrap(keys, k, t0, g)
        place_wrap(keys, k, t0 + 0.75, 0.3 * g)       # soft echoes
        place_wrap(keys, k, t0 + 1.5, 0.12 * g)
    keys = reverb_circ(keys, rng, 3.0, 0.8, 0.6, 250, 3500)
    air = unit(bp(white(rng, n), 500, 3000, circ=True)) * (0.5 + 0.5 * slow_noise(rng, n, 0.08))
    mix = 0.8 * norm(pad) + 0.22 * norm(drone) + 0.5 * norm(keys) + 0.012 * air
    mix = reverb_circ(mix, rng, 2.0, 0.5, 0.25, 200, 4000)
    return hp(lp(mix, 5500, circ=True), 40, circ=True)


def music_tension(rng):
    T = 32.0
    n = ns(T)
    t = tt(n)
    beats = 40
    bl = T / beats
    bph = t / bl
    bk = np.floor(bph).astype(int)
    bt = (bph - bk) * bl
    acc = np.array([1.0, 0.55, 0.8, 0.55])
    pulse = (acc[bk % 4] * np.exp(-bt / 0.28) * (1.0 - np.exp(-bt / 0.012))
             + acc[(bk - 1) % 4] * np.exp(-(bt + bl) / 0.28))
    # pulsing low drone on D
    fsub = np.round(midi(26) * T) / T                    # D1, whole number of cycles per loop
    f1 = 2.0 * fsub                                      # D2
    drone = 0.2 * np.sin(TAU * fsub * t)
    for det in (0.0, 4.0 / T, -2.0 / T):
        for h in range(1, 13):
            a = (1.0 / h ** 0.3) * np.exp(-h / 6.0) * (0.35 if h == 1 else 1.0)
            depth = min(0.3 + 0.07 * h, 0.95)
            drone += a * (1.0 - depth + depth * pulse) * np.sin(TAU * h * (f1 + det) * t + rng.uniform(0, TAU))
    # heartbeat-like thumps
    th = np.zeros(n)
    m = ns(0.5)
    tm = tt(m)
    lub = (sweep_sine(m, 95, 52, 0.03) * np.exp(-tm / 0.09)
           + 0.5 * np.sin(TAU * 196.0 * tm) * np.exp(-tm / 0.03)
           + 0.25 * np.sin(TAU * 294.0 * tm) * np.exp(-tm / 0.02)) * (1.0 - np.exp(-tm / 0.004))
    for b in range(beats):
        place_wrap(th, lub, b * bl, acc[b % 4])
        if b % 2 == 0:
            place_wrap(th, lub, b * bl + 0.21, 0.45 * acc[b % 4])
    # dissonant swells (minor seconds / tritones)
    sw = np.zeros(n)

    def swell(notes, start, dur, gain, peak=0.6):
        k = ns(dur)
        tk = tt(k)
        e = bump(k, 0.0, dur, peak, 1.5)
        s = np.zeros(k)
        for mn in notes:
            for c in (-9.0, 0.0, 8.0):
                ff = midi(mn) * 2.0 ** (c / 1200.0)
                vib = 0.004 * e * np.sin(TAU * rng.uniform(4.6, 5.6) * tk + rng.uniform(0, TAU))
                ph = TAU * ff * (tk + np.cumsum(vib) / SR)
                for h in range(1, 9):
                    if ff * h > 4500:
                        break
                    s += (1.0 / h ** 1.3) * np.sin(h * ph + rng.uniform(0, TAU))
        s *= e * (1.0 - 0.2 * e * (0.5 + 0.5 * np.sin(TAU * 7.3 * tk)))
        place_wrap(sw, s, start, gain)

    swell([50, 51, 57], 3.0, 10.0, 1.0)            # D3 Eb3 A3
    swell([53, 54, 60, 61], 13.5, 10.5, 0.9)       # F3 Gb3 C4 Db4
    swell([56, 57, 62, 63], 23.5, 10.5, 1.0)       # Ab3 A3 D4 Eb4 (wraps into the loop start)
    # thin, cold high beating tone
    k = ns(15.0)
    tk = tt(k)
    hi = (np.sin(TAU * midi(81) * tk) + np.sin(TAU * midi(82) * tk + 1.0)) * bump(k, 0.0, 15.0, 0.6, 2.0)
    high = np.zeros(n)
    place_wrap(high, hi, 15.5)
    rumble = unit(bp(white(rng, n), 60, 300, circ=True)) * (0.6 + 0.4 * slow_noise(rng, n, 0.2))
    mix = 0.75 * norm(drone) + 0.25 * norm(th) + 0.6 * norm(sw) + 0.04 * norm(high) + 0.05 * rumble
    mix = reverb_circ(mix, rng, 2.5, 0.6, 0.35, 150, 3500)
    return hp(lp(mix, 5000, circ=True), 35, circ=True)


reg("music_calm", music_calm, loop=True, peak=-6.0)
reg("music_tension", music_tension, loop=True, peak=-6.0)


# =============================================================================
# Output + verification
# =============================================================================
def finalize(x, loop=False, peak=-3.0, perc=False):
    x = np.asarray(x, float).copy()
    x -= np.mean(x)
    n = len(x)
    if not loop:
        if perc:
            # keep the transient intact: 2 ms of pre-roll, micro-ramp on the onset
            pre = ns(0.002)
            r = min(8, n)
            x[:r] *= np.linspace(0.0, 1.0, r)
            x = np.concatenate([np.zeros(pre), x])[:n]
        else:
            fi = min(ns(0.003), n // 4)
            x[:fi] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(fi) / fi)
        fo = min(ns(0.005), n // 4)
        x[n - fo:] *= 0.5 + 0.5 * np.cos(np.pi * (np.arange(fo) + 1) / fo)
    m = np.max(np.abs(x))
    if m > 0:
        x *= 10.0 ** (peak / 20.0) / m
    return x


def write_wav(path, x):
    pcm = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def expected():
    """name -> (min_s, max_s, is_loop): the full list the game expects."""
    E = {}

    def add(names, lo, hi, loop=False):
        for nm in names:
            E[nm] = (lo, hi, loop)

    def var(base, k):
        return ["%s_%d" % (base, i) for i in range(1, k + 1)]

    for s in ("asphalt", "grass", "wood", "tile"):
        add(var("step_" + s, 4), 0.18, 0.28)
    add(var("swing", 3), 0.25, 0.35)
    add(var("hit_blunt", 3), 0.25, 0.36)
    add(var("hit_blade", 3), 0.22, 0.36)
    add(var("hit_wood", 3), 0.22, 0.36)
    add(var("hit_metal", 2), 0.42, 0.58)
    add(["gun_pistol"], 0.5, 0.7)
    add(["gun_revolver"], 0.6, 0.8)
    add(["gun_shotgun"], 0.85, 1.15)
    add(["gun_rifle"], 0.95, 1.25)
    add(["gun_empty"], 0.07, 0.09)
    add(["reload_mag"], 0.5, 0.7)
    add(["reload_shell"], 0.21, 0.29)
    add(["rack"], 0.38, 0.52)
    add(["casing"], 0.25, 0.35)
    add(var("zombie_groan", 5), 1.0, 1.8)
    add(var("zombie_growl", 3), 0.7, 1.1)
    add(var("zombie_attack", 3), 0.4, 0.6)
    add(var("zombie_death", 2), 0.78, 1.02)
    add(var("zombie_thump", 3), 0.25, 0.35)
    add(var("hurt", 3), 0.25, 0.4)
    add(["breath_heavy"], 2.2, 2.6, True)
    add(["eat", "drink"], 0.78, 1.02)
    add(["cough"], 0.6, 0.8)
    add(["bandage"], 0.5, 0.7)
    add(["door_open"], 0.43, 0.57)
    add(["door_close", "door_locked"], 0.3, 0.4)
    add(["door_break"], 0.78, 1.02)
    add(["window_open"], 0.34, 0.46)
    add(var("glass_break", 2), 0.78, 1.02)
    add(["tree_fall"], 1.9, 2.5)
    add(var("chop", 3), 0.25, 0.35)
    add(["pickup"], 0.12, 0.18)
    add(["drop"], 0.17, 0.23)
    add(["craft"], 0.78, 1.02)
    add(["saw"], 1.05, 1.35)
    add(["zipper"], 0.34, 0.46)
    add(["plant"], 0.43, 0.57)
    add(["water_pour"], 0.85, 1.15)
    add(["ui_click"], 0.04, 0.06)
    add(["ui_open"], 0.10, 0.14)
    add(["ui_error"], 0.17, 0.23)
    add(["engine_idle", "engine_run"], 1.3, 1.7, True)
    add(["engine_start"], 1.2, 1.6)
    add(["engine_fail"], 1.05, 1.35)
    add(["car_door"], 0.34, 0.46)
    add(["horn"], 0.7, 0.9)
    add(["crash"], 0.78, 1.02)
    add(["skid"], 0.7, 0.9)
    add(["rain_loop", "river_loop", "room_tone"], 5.5, 6.5, True)
    add(["wind_loop", "forest_loop"], 7.5, 8.5, True)
    add(["fire_loop"], 4.5, 5.5, True)
    add(["generator_loop"], 1.8, 2.2, True)
    add(["alarm_loop"], 1.5, 1.7, True)
    add(["music_calm"], 46.0, 50.0, True)
    add(["music_tension"], 30.0, 34.0, True)
    return E


def verify():
    E = expected()
    problems = []
    rows = []
    total = 0
    for name in E:
        lo, hi, is_loop = E[name]
        path = os.path.join(OUT_DIR, name + ".wav")
        if not os.path.isfile(path) or os.path.getsize(path) <= 44:
            problems.append("%s: missing or empty" % name)
            continue
        total += os.path.getsize(path)
        with wave.open(path, "rb") as w:
            ch, sw, fr, nf = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
            raw = w.readframes(nf)
        if (ch, sw, fr) != (1, 2, SR) or nf == 0:
            problems.append("%s: bad format ch=%d width=%d rate=%d frames=%d" % (name, ch, sw, fr, nf))
            continue
        x = np.frombuffer(raw, dtype="<i2").astype(float) / 32768.0
        dur = nf / float(SR)
        pk = np.max(np.abs(x))
        rms = np.sqrt(np.mean(x ** 2))
        spec = np.abs(np.fft.rfft(x)) ** 2
        cen = float(np.sum(np.fft.rfftfreq(nf, 1.0 / SR) * spec) / (np.sum(spec) + 1e-20))
        note = ""
        if pk <= 0:
            problems.append("%s: silent" % name)
        if not (lo <= dur <= hi):
            note += " DURATION?"
            problems.append("%s: duration %.3f outside %.2f..%.2f" % (name, dur, lo, hi))
        seam = ""
        if is_loop:
            # the wrap-around step must look like any other sample-to-sample step
            d = np.abs(np.diff(x))
            jump = abs(x[0] - x[-1])
            ref = np.percentile(d, 99.9) + 1e-9
            seam = "%.2f" % (jump / ref)
            if jump > 1.5 * np.max(d) + 2.0 / 32768.0:
                note += " SEAM?"
                problems.append("%s: loop seam discontinuity" % name)
        else:
            if abs(x[0]) > 0.02 or abs(x[-1]) > 0.02:
                note += " CLICK?"
                problems.append("%s: does not start/end near zero" % name)
        rows.append((name, dur, 20 * np.log10(pk + 1e-12), 20 * np.log10(rms + 1e-12), cen,
                     "loop" if is_loop else "", seam, note))
    print("%-18s %8s %8s %8s %8s %5s %5s" % ("name", "dur(s)", "peak dB", "rms dB", "cen Hz", "kind", "seam"))
    print("-" * 68)
    for r in rows:
        print("%-18s %8.3f %8.2f %8.2f %8.0f %5s %5s%s" % r)
    print("-" * 68)
    extra = sorted(set(nm for nm, _, _, _ in REG) - set(E))
    unreg = sorted(set(E) - set(nm for nm, _, _, _ in REG))
    if extra:
        problems.append("registered but not expected: %s" % ", ".join(extra))
    if unreg:
        problems.append("expected but no generator: %s" % ", ".join(unreg))
    print("files: %d / %d expected   total size: %.2f MB   dir: %s"
          % (len(rows), len(E), total / 1e6, OUT_DIR))
    if problems:
        print("PROBLEMS:")
        for p in problems:
            print("  - " + p)
    else:
        print("OK: all files present, 22050 Hz mono 16-bit, durations in range.")
    return not problems


def main(argv):
    if "--check" in argv:
        return 0 if verify() else 1
    only = [a for a in argv if not a.startswith("-")]
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, fn, args, opts in REG:
        if only and name not in only:
            continue
        rng = np.random.default_rng([SEED, zlib.crc32(name.encode("ascii"))])
        x = finalize(fn(rng, *args), **opts)
        write_wav(os.path.join(OUT_DIR, name + ".wav"), x)
    return 0 if verify() else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
