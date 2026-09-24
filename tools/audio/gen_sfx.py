"""임시 효과음 합성기(sfxr 방식). numpy + wave 만 쓴다.

  python3 tools/audio/gen_sfx.py

- 오실레이터(사인·삼각·사각·톱니·잡음) + 엔벨로프 + 주파수 슬라이드로 소리를 만들고,
  저역 통과 필터와 짧은 리버브(Schroeder: 콤 4 + 올패스 2)로 실제 녹음처럼 다듬는다.
- 출력: assets/audio/sfx/<id>.wav (44.1kHz, 16bit, 모노). id 는 AudioManager.SFX 표와 같다.
- 8단계에서 실제 녹음·작곡 사운드로 교체한다. 파일명·용도는 ART_BIBLE 8-1 에 기록.
"""
from __future__ import annotations

import math
import os
import wave

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
SR = 44100
RNG = np.random.default_rng(1234)


# ── 기본 도구 ────────────────────────────────────────────

def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(SR * seconds)) / SR


def phase_from_freq(freq: np.ndarray) -> np.ndarray:
    return 2 * np.pi * np.cumsum(freq) / SR


def osc(kind: str, freq: np.ndarray) -> np.ndarray:
    ph = phase_from_freq(freq)
    if kind == "sine":
        return np.sin(ph)
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if kind == "square":
        return np.sign(np.sin(ph)) * 0.6
    if kind == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    raise ValueError(kind)


def noise(n: int) -> np.ndarray:
    return RNG.uniform(-1, 1, n)


def env_adsr(n: int, attack: float, decay: float, sustain: float = 0.0, release: float = 0.0, curve: float = 3.0) -> np.ndarray:
    """attack/decay/release 는 초. sustain 은 레벨(decay 후 유지, 끝에서 release)."""
    e = np.zeros(n)
    a = max(1, int(attack * SR))
    d = max(1, int(decay * SR))
    r = int(release * SR)
    e[:min(a, n)] = np.linspace(0, 1, a)[:min(a, n)]
    if a < n:
        seg = min(d, n - a)
        x = np.linspace(0, 1, d)[:seg]
        e[a:a + seg] = sustain + (1 - sustain) * np.exp(-curve * x) * (1 - x)
    if a + d < n:
        e[a + d:] = sustain
    if r > 0 and r < n:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def exp_decay(n: int, seconds: float) -> np.ndarray:
    return np.exp(-np.arange(n) / (SR * seconds))


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """1차 저역 통과."""
    dt = 1.0 / SR
    rc = 1.0 / (2 * np.pi * cutoff)
    alpha = dt / (rc + dt)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def reverb(x: np.ndarray, wet: float = 0.18, room: float = 0.5, tail: float = 0.25) -> np.ndarray:
    """짧은 방 울림. room 0..1 은 지연 길이 배율."""
    pad = np.concatenate([x, np.zeros(int(SR * tail))])
    out = np.zeros_like(pad)
    for delay_ms, fb in [(29.7, 0.72), (37.1, 0.7), (41.1, 0.68), (43.7, 0.66)]:
        d = int(SR * delay_ms / 1000 * (0.5 + room))
        buf = np.zeros_like(pad)
        for i in range(len(pad)):
            buf[i] = pad[i] + (fb * buf[i - d] if i >= d else 0.0)
        out += buf
    out /= 4
    for delay_ms in (5.0, 1.7):
        d = int(SR * delay_ms / 1000)
        y = np.zeros_like(out)
        g = 0.7
        for i in range(len(out)):
            xd = out[i - d] if i >= d else 0.0
            yd = y[i - d] if i >= d else 0.0
            y[i] = -g * out[i] + xd + g * yd
        out = y
    out = lowpass(out, 4500)
    return pad * (1 - wet) + out * wet


def normalize(x: np.ndarray, peak: float) -> np.ndarray:
    m = np.max(np.abs(x))
    return x if m == 0 else x / m * peak


def fade_edges(x: np.ndarray, ms: float = 3.0) -> np.ndarray:
    n = int(SR * ms / 1000)
    if len(x) > 2 * n:
        x[:n] *= np.linspace(0, 1, n)
        x[-n:] *= np.linspace(1, 0, n)
    return x


def write(name: str, x: np.ndarray, peak: float = 0.8, fade: bool = True) -> None:
    x = normalize(x, peak)
    if fade:
        x = fade_edges(x)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def tone(kind: str, f0: float, f1: float, seconds: float, attack: float, decay: float, sustain: float = 0.0, release: float = 0.0) -> np.ndarray:
    n = int(SR * seconds)
    freq = np.geomspace(f0, f1, n) if f0 != f1 else np.full(n, f0)
    return osc(kind, freq) * env_adsr(n, attack, decay, sustain, release)


def mix(*parts: tuple[np.ndarray, int]) -> np.ndarray:
    """(신호, 시작 샘플) 목록을 섞는다."""
    length = max(len(p) + s for p, s in parts)
    out = np.zeros(length)
    for p, s in parts:
        out[s:s + len(p)] += p
    return out


def at(seconds: float) -> int:
    return int(SR * seconds)


def note(midi: float) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


# ── 효과음 ───────────────────────────────────────────────

def ui_hover() -> None:
    x = mix((tone("sine", 2100, 1800, 0.035, 0.002, 0.03) * 0.6, 0), (tone("tri", 4200, 3600, 0.02, 0.001, 0.015) * 0.2, 0))
    write("ui_hover", lowpass(x, 6000), 0.35)


def ui_click() -> None:
    n = at(0.07)
    body = tone("square", 900, 520, 0.07, 0.001, 0.05)
    click = noise(n) * exp_decay(n, 0.004)
    x = lowpass(body * 0.5 + click * 0.6, 5000)
    write("ui_click", reverb(x, 0.12, 0.2, 0.08), 0.6)


def panel_swish(name: str, rising: bool) -> None:
    n = at(0.16)
    sweep = np.linspace(0, 1, n) if rising else np.linspace(1, 0, n)
    x = noise(n)
    y = np.zeros(n)
    acc = 0.0
    for i in range(n):
        cutoff = 600 + 3500 * sweep[i]
        alpha = 1 - math.exp(-2 * math.pi * cutoff / SR)
        acc += alpha * (x[i] - acc)
        y[i] = acc
    y *= np.sin(np.linspace(0, np.pi, n)) ** 1.5
    write(name, reverb(y, 0.2, 0.3, 0.1), 0.35)


def marble_place() -> None:
    n = at(0.12)
    body = (np.sin(phase_from_freq(np.full(n, 740))) * 0.8 + np.sin(phase_from_freq(np.full(n, 1930))) * 0.35) * exp_decay(n, 0.025)
    click = highpass(noise(n), 1500) * exp_decay(n, 0.003)
    x = body + click * 0.5
    write("marble_place", reverb(lowpass(x, 5500), 0.15, 0.3, 0.12), 0.75)


def marble_remove() -> None:
    n = at(0.09)
    freq = np.geomspace(520, 980, n)
    x = np.sin(phase_from_freq(freq)) * exp_decay(n, 0.03) + highpass(noise(n), 2000) * exp_decay(n, 0.003) * 0.4
    write("marble_remove", reverb(lowpass(x, 5000), 0.12, 0.3, 0.1), 0.6)


def spin_start() -> None:
    n = at(0.35)
    whoosh = noise(n)
    y = np.zeros(n)
    acc = 0.0
    for i in range(n):
        cutoff = 400 + 2600 * (i / n) ** 0.5
        alpha = 1 - math.exp(-2 * math.pi * cutoff / SR)
        acc += alpha * (whoosh[i] - acc)
        y[i] = acc
    y *= env_adsr(n, 0.02, 0.33, 0.0)
    flick = tone("tri", 1200, 2600, 0.08, 0.001, 0.07) * 0.5
    tick = highpass(noise(at(0.03)), 2500) * exp_decay(at(0.03), 0.004)
    x = mix((y, 0), (flick, 0), (tick * 0.8, at(0.05)), (tick * 0.6, at(0.12)))
    write("spin_start", reverb(x, 0.2, 0.4, 0.2), 0.7)


def ball_roll_loop() -> None:
    """1초 이음매 없는 루프: 저역 잡음 + 25Hz 덜컹거림 + 약한 고음 쉬익."""
    seconds = 1.05  # 끝 0.05초는 앞과 크로스페이드한 뒤 잘라 낸다 → 정확히 1초
    n = at(seconds)
    base = noise(n + at(0.2))
    rumble = lowpass(base, 380)[at(0.2):]
    hiss = highpass(lowpass(base, 5000), 1800)[at(0.2):]
    t = np.arange(n) / SR
    am = 0.65 + 0.35 * np.sin(2 * np.pi * 25 * t) ** 2  # 정수 Hz → 1초에 딱 맞음
    tick = np.zeros(n)
    for k in range(12):
        s = int(n * k / 12)
        m = min(at(0.004), n - s)
        tick[s:s + m] += highpass(noise(m), 3000) * np.linspace(1, 0, m) * 0.25
    x = rumble * am * 1.6 + hiss * 0.25 + tick
    # 끝과 시작을 크로스페이드해 이음매 제거
    fade = at(0.05)
    x[:fade] = x[:fade] * np.linspace(0, 1, fade) + x[-fade:] * np.linspace(1, 0, fade)
    x = x[:-fade]
    write("ball_roll_loop", x, 0.55, fade=False)


def deflector_hit() -> None:
    n = at(0.12)
    ping = (np.sin(phase_from_freq(np.full(n, 2350))) * 0.6 + np.sin(phase_from_freq(np.full(n, 3710))) * 0.4) * exp_decay(n, 0.018)
    click = highpass(noise(n), 2500) * exp_decay(n, 0.002)
    knock = np.sin(phase_from_freq(np.geomspace(500, 300, n))) * exp_decay(n, 0.012) * 0.6
    x = ping * 0.7 + click + knock
    write("deflector_hit", reverb(x, 0.22, 0.4, 0.15), 0.7)


def pocket_land() -> None:
    n = at(0.18)
    thock = (np.sin(phase_from_freq(np.geomspace(420, 330, n))) + 0.4 * np.sin(phase_from_freq(np.full(n, 610)))) * exp_decay(n, 0.035)
    click = highpass(noise(n), 1200) * exp_decay(n, 0.004) * 0.6
    rattle = np.zeros(at(0.25))
    for k, (dt, amp) in enumerate([(0.07, 0.35), (0.12, 0.2), (0.155, 0.1)]):
        m = at(0.03)
        s = at(dt)
        part = (np.sin(phase_from_freq(np.full(m, 900 + 150 * k))) * 0.6 + highpass(noise(m), 2000) * 0.4) * exp_decay(m, 0.008) * amp
        rattle[s:s + m] += part
    x = mix((thock + click, 0), (rattle, 0))
    write("pocket_land", reverb(lowpass(x, 6000), 0.2, 0.35, 0.18), 0.75)


def chip_click() -> None:
    n = at(0.06)
    x = (np.sin(phase_from_freq(np.full(n, 2900))) * 0.5 + np.sin(phase_from_freq(np.full(n, 4300))) * 0.35 + np.sin(phase_from_freq(np.full(n, 6100))) * 0.15) * exp_decay(n, 0.012)
    x += highpass(noise(n), 3000) * exp_decay(n, 0.0015) * 0.5
    write("chip_click", reverb(x, 0.1, 0.2, 0.06), 0.45)


def arpeggio(notes: list[float], step: float, length: float, kind: str = "square", sparkle: bool = False) -> np.ndarray:
    parts = []
    for i, m in enumerate(notes):
        n = at(length)
        f = note(m)
        vib = 1 + 0.004 * np.sin(2 * np.pi * 6 * np.arange(n) / SR)
        sig = osc(kind, f * vib) * 0.5 + osc("sine", 2 * f * vib) * 0.2
        sig *= env_adsr(n, 0.004, length * 0.9, 0.0)
        parts.append((sig, at(step * i)))
        if sparkle:
            s = at(0.04)
            parts.append((osc("sine", np.full(s, f * 4)) * exp_decay(s, 0.01) * 0.2, at(step * i)))
    return mix(*parts)


def win_normal() -> None:
    x = arpeggio([84, 88, 91], 0.055, 0.18, "square")
    write("win_normal", reverb(lowpass(x, 6000), 0.2, 0.4, 0.2), 0.55)


def win_good() -> None:
    x = arpeggio([79, 84, 88, 91, 96], 0.05, 0.22, "square", sparkle=True)
    write("win_good", reverb(lowpass(x, 6500), 0.22, 0.45, 0.25), 0.6)


def brass(midis: list[float], seconds: float, attack: float = 0.02) -> np.ndarray:
    n = at(seconds)
    out = np.zeros(n)
    t = np.arange(n) / SR
    for m in midis:
        f = note(m) * (1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 3, 0, 1))
        out += osc("saw", f) * 0.35 + osc("square", f * 0.5) * 0.15
    out = lowpass(out, 2600)
    return out * env_adsr(n, attack, seconds * 0.3, 0.55, seconds * 0.35)


def win_big() -> None:
    x = mix(
        (brass([72, 76, 79], 0.16), 0),
        (brass([72, 76, 79], 0.16), at(0.18)),
        (brass([77, 81, 84], 0.7), at(0.36)),
        (arpeggio([96, 100, 103, 108], 0.06, 0.2, "tri", sparkle=True) * 0.6, at(0.4)),
    )
    write("win_big", reverb(x, 0.25, 0.6, 0.4), 0.8)


def win_jackpot() -> None:
    parts = [
        (brass([67, 72, 76], 0.14), 0),
        (brass([67, 72, 76], 0.14), at(0.15)),
        (brass([67, 72, 76], 0.14), at(0.30)),
        (brass([72, 76, 79, 84], 1.4), at(0.46)),
    ]
    for k in range(18):
        parts.append((arpeggio([96 + (k * 5) % 12], 0.0, 0.12, "tri", sparkle=True) * 0.35, at(0.5 + k * 0.07)))
    x = mix(*parts)
    write("win_jackpot", reverb(x, 0.28, 0.7, 0.6), 0.85)


def lose() -> None:
    x = mix((tone("tri", note(64), note(63), 0.16, 0.005, 0.15), 0), (tone("tri", note(60), note(59), 0.28, 0.005, 0.26), at(0.13)))
    write("lose", reverb(lowpass(x, 2500), 0.2, 0.4, 0.2), 0.35)


def near_miss() -> None:
    n = at(0.45)
    freq = np.geomspace(note(76), note(69), n)
    x = osc("tri", freq) * env_adsr(n, 0.01, 0.42, 0.0) + osc("sine", freq * 2) * env_adsr(n, 0.01, 0.3, 0.0) * 0.2
    write("near_miss", reverb(lowpass(x, 3000), 0.25, 0.4, 0.25), 0.4)


def deny() -> None:
    x = mix((tone("square", 180, 160, 0.09, 0.002, 0.08, 0.3, 0.02), 0), (tone("square", 150, 130, 0.12, 0.002, 0.1, 0.3, 0.03), at(0.1)))
    write("deny", reverb(lowpass(x, 1800), 0.12, 0.2, 0.1), 0.45)


def clover_get() -> None:
    x = arpeggio([91, 96, 100], 0.04, 0.2, "sine", sparkle=True)
    write("clover_get", reverb(x, 0.25, 0.5, 0.25), 0.5)


def neon_flicker() -> None:
    n = at(0.22)
    t = np.arange(n) / SR
    buzz = osc("saw", np.full(n, 120)) * 0.5 + osc("square", np.full(n, 240)) * 0.3
    gate = (np.sin(2 * np.pi * 23 * t) > -0.2).astype(float) * env_adsr(n, 0.005, 0.2, 0.0)
    x = lowpass(buzz * gate + highpass(noise(n), 3000) * gate * 0.15, 3000)
    write("neon_flicker", reverb(x, 0.15, 0.3, 0.12), 0.4)


def coin_drop() -> None:
    n = at(0.2)
    x = np.zeros(n)
    for k, (dt, f) in enumerate([(0.0, 3200), (0.05, 3600), (0.09, 3400)]):
        m = at(0.08)
        s = at(dt)
        part = (np.sin(phase_from_freq(np.full(m, f))) + 0.5 * np.sin(phase_from_freq(np.full(m, f * 1.51)))) * exp_decay(m, 0.02) * (1 - 0.3 * k)
        end = min(n, s + m)
        x[s:end] += part[:end - s]
    write("coin_drop", reverb(x, 0.2, 0.3, 0.12), 0.4)


# ── 3단계: 업그레이드·구슬 승급 ──────────────────────────

def buy_coin() -> None:
    """업그레이드 구매 코인음. 연속 구매 시 AudioManager 가 피치를 올린다."""
    n = at(0.22)
    x = np.zeros(n)
    for k, (dt, f) in enumerate([(0.0, 1976.0), (0.045, 2637.0)]):
        m = at(0.16)
        s = at(dt)
        part = (np.sin(phase_from_freq(np.full(m, f))) + 0.45 * np.sin(phase_from_freq(np.full(m, f * 2.01)))) * exp_decay(m, 0.045)
        end = min(n, s + m)
        x[s:end] += part[:end - s] * (1.0 - 0.25 * k)
    click = highpass(noise(n), 3000) * exp_decay(n, 0.002) * 0.3
    write("buy_coin", reverb(x + click, 0.18, 0.35, 0.14), 0.62)


def slot_open() -> None:
    """트레이 새 홈이 열리는 '딸깍'(금속 걸쇠 두 번)."""
    n = at(0.16)
    x = np.zeros(n)
    for dt, f in [(0.0, 1400.0), (0.055, 2100.0)]:
        m = at(0.05)
        s = at(dt)
        part = (highpass(noise(m), 1800) * 0.7 + np.sin(phase_from_freq(np.full(m, f))) * 0.6) * exp_decay(m, 0.006)
        x[s:s + m] += part
    write("slot_open", reverb(lowpass(x, 7000), 0.12, 0.25, 0.08), 0.7)


def marble_roll() -> None:
    """구슬이 트레이로 굴러 들어오는 짧은 구름 소리(점점 느려짐)."""
    n = at(0.5)
    t = np.arange(n) / SR
    rate = 38 * (1 - t / 0.55)
    ph = np.cumsum(rate) / SR
    ticks = (np.sin(2 * np.pi * ph) > 0.92).astype(float)
    body = lowpass(noise(n), 900) * 0.6 + ticks * highpass(noise(n), 2500) * 0.5
    x = body * env_adsr(n, 0.02, 0.45, 0.4, 0.1)
    write("marble_roll", reverb(x, 0.1, 0.3, 0.1), 0.5)


def golden_beam() -> None:
    """황금 포켓 빛줄기: 위에서 내려오는 반짝이 스윕 + 종소리."""
    n = at(1.0)
    sweep = osc("sine", np.geomspace(2600, 700, n)) * env_adsr(n, 0.01, 0.45, 0.0) * 0.4
    shimmer = np.zeros(n)
    for k in range(10):
        m = at(0.08)
        s = at(0.02 + k * 0.04)
        shimmer[s:s + m] += np.sin(phase_from_freq(np.full(m, note(96 - k)))) * exp_decay(m, 0.02) * 0.25
    bell_n = at(0.7)
    bell = (np.sin(phase_from_freq(np.full(bell_n, note(84)))) + 0.4 * np.sin(phase_from_freq(np.full(bell_n, note(84) * 2.76)))) * exp_decay(bell_n, 0.25)
    x = mix((sweep + shimmer, 0), (bell * 0.6, at(0.42)))
    write("golden_beam", reverb(x, 0.3, 0.7, 0.5), 0.7)


def promote_charge() -> None:
    """승급: 빛이 모이며 차오르는 소리(1.0초, 상승)."""
    n = at(0.75)
    t = np.arange(n) / SR
    f = np.geomspace(180, 1400, n)
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * (6 + 22 * t / 0.75) * t)
    x = (osc("saw", f) * 0.25 + osc("sine", f * 2) * 0.3) * trem * np.linspace(0.2, 1.0, n)
    x = lowpass(x, 3500) + highpass(noise(n), 4000) * np.linspace(0, 0.25, n)
    write("promote_charge", reverb(x, 0.2, 0.5, 0.2), 0.6)


def promote_flash() -> None:
    """승급: 흰 섬광 순간의 '쨍' + 폭발."""
    n = at(0.8)
    boom = lowpass(noise(n), 700) * exp_decay(n, 0.12) * 0.9
    ping = (np.sin(phase_from_freq(np.full(n, 1760.0))) + 0.5 * np.sin(phase_from_freq(np.full(n, 2640.0)))) * exp_decay(n, 0.18) * 0.5
    x = boom + ping + highpass(noise(n), 3000) * exp_decay(n, 0.05) * 0.4
    write("promote_flash", reverb(x, 0.3, 0.6, 0.4), 0.85)


def promote_jingle(name: str, level: int) -> None:
    """승급 징글. level 1(나무~은) · 2(금~에메랄드) · 3(다이아~코스믹): 높을수록 길고 화음·반짝임이 많다."""
    if level == 1:
        x = arpeggio([72, 76, 79, 84], 0.08, 0.35, "square", sparkle=True)
        write(name, reverb(x, 0.2, 0.5, 0.3), 0.7)
        return
    if level == 2:
        parts = [
            (arpeggio([67, 71, 74, 79, 83], 0.07, 0.3, "square", sparkle=True) * 0.8, 0),
            (brass([67, 71, 74, 79], 0.9), at(0.38)),
        ]
        write(name, reverb(mix(*parts), 0.26, 0.65, 0.45), 0.8)
        return
    parts = [
        (brass([60, 64, 67], 0.16), 0),
        (brass([62, 65, 69], 0.16), at(0.17)),
        (brass([64, 67, 71], 0.16), at(0.34)),
        (brass([60, 64, 67, 72, 76], 1.6), at(0.52)),
    ]
    for k in range(24):
        parts.append((arpeggio([96 + (k * 7) % 12], 0.0, 0.14, "tri", sparkle=True) * 0.3, at(0.55 + k * 0.055)))
    bass_n = at(1.6)
    parts.append((osc("sine", np.full(bass_n, note(36))) * env_adsr(bass_n, 0.02, 1.2, 0.3, 0.3) * 0.5, at(0.52)))
    write(name, reverb(mix(*parts), 0.32, 0.8, 0.7), 0.88)


# ── 5단계: 래칫 남작 ──────────────────────────────────────

def dialogue_blip_baron() -> None:
    """대사 타자기 목소리 '삑'. 낮고 찍찍거리는 톤(DialogueBox 가 호출마다 피치를 흔든다)."""
    body = tone("square", 190, 150, 0.05, 0.002, 0.04) * 0.7
    squeak = tone("tri", 420, 340, 0.05, 0.001, 0.025) * 0.3
    x = lowpass(body + squeak, 3200)
    write("dialogue_blip_baron", x, 0.5)


# ── 6단계: 딜러 루시 ──────────────────────────────────────

def dialogue_blip_lucy() -> None:
    """대사 타자기 목소리 '삑'. 밝고 또렷한 톤(남작보다 높고 짧다)."""
    body = tone("sine", 620, 560, 0.045, 0.002, 0.03) * 0.6
    sparkle = tone("tri", 1100, 980, 0.045, 0.001, 0.02) * 0.25
    x = lowpass(body + sparkle, 5200)
    write("dialogue_blip_lucy", x, 0.5)


def baron_footstep() -> None:
    n = at(0.16)
    thud = np.sin(phase_from_freq(np.geomspace(110, 60, n))) * exp_decay(n, 0.05)
    knock = highpass(noise(n), 800) * exp_decay(n, 0.02) * 0.4
    write("baron_footstep", lowpass(thud * 0.8 + knock, 2500), 0.55)


def baron_cane_tap() -> None:
    n = at(0.13)
    click = highpass(noise(n), 2000) * exp_decay(n, 0.004)
    knock = np.sin(phase_from_freq(np.geomspace(700, 420, n))) * exp_decay(n, 0.03) * 0.6
    write("baron_cane_tap", reverb(click * 0.6 + knock, 0.18, 0.3, 0.1), 0.6)


def bass_drop() -> None:
    """파산 시 저음 콘트라베이스 한 번."""
    n = at(0.9)
    fund = np.sin(phase_from_freq(np.full(n, note(33)))) * env_adsr(n, 0.015, 0.75, 0.25, 0.35)
    growl = osc("saw", np.full(n, note(33))) * env_adsr(n, 0.02, 0.6, 0.15, 0.3) * 0.35
    x = lowpass(fund + growl, 380)
    write("bass_drop", reverb(x, 0.3, 0.7, 0.5), 0.85)


def contract_unroll() -> None:
    """양피지가 펼쳐지는 '스르륵'."""
    n = at(0.6)
    x = noise(n)
    y = np.zeros(n)
    acc = 0.0
    sweep = np.sin(np.linspace(0, np.pi, n))
    for i in range(n):
        cutoff = 1200 + 2600 * sweep[i]
        alpha = 1 - math.exp(-2 * math.pi * cutoff / SR)
        acc += alpha * (x[i] - acc)
        y[i] = acc
    y *= sweep ** 0.7
    write("contract_unroll", reverb(y, 0.22, 0.4, 0.15), 0.4)


def quill_sign() -> None:
    """깃펜으로 서명하는 '사각사각'(짧은 잡음을 불규칙 간격으로)."""
    rng = np.random.default_rng(42)
    total = at(0.8)
    x = np.zeros(total)
    t = 0.0
    while t < 0.65:
        dur = rng.uniform(0.03, 0.09)
        m = at(dur)
        s = at(t)
        scratch = highpass(noise(m), 3500) * exp_decay(m, dur * 0.4) * rng.uniform(0.5, 1.0)
        end = min(total, s + m)
        x[s:end] += scratch[:end - s]
        t += dur + rng.uniform(0.01, 0.05)
    write("quill_sign", lowpass(x, 8000), 0.4)


def stamp_thud() -> None:
    """빨간 도장이 쾅 찍히는 소리."""
    n = at(0.3)
    thump = np.sin(phase_from_freq(np.geomspace(140, 55, n))) * exp_decay(n, 0.09)
    crack = highpass(noise(at(0.02)), 1500) * exp_decay(at(0.02), 0.006)
    x = np.zeros(n)
    x[:len(crack)] += crack * 0.8
    x += thump * 0.9
    write("stamp_thud", reverb(lowpass(x, 3000), 0.2, 0.4, 0.2), 0.85)


def chip_bag_toss() -> None:
    """칩 자루가 상단 바로 던져지는 '휙 + 짤랑'."""
    swish_n = at(0.24)
    swish = highpass(noise(swish_n), 1000) * np.sin(np.linspace(0, np.pi, swish_n)) * 0.5
    parts: list[tuple[np.ndarray, int]] = [(swish, 0)]
    rng = np.random.default_rng(7)
    for k in range(8):
        f = rng.uniform(2600, 4200)
        m = at(0.05)
        chime = (np.sin(phase_from_freq(np.full(m, f))) + 0.4 * np.sin(phase_from_freq(np.full(m, f * 1.5)))) * exp_decay(m, 0.03)
        parts.append((chime * 0.35, at(0.2 + k * 0.025)))
    write("chip_bag_toss", reverb(mix(*parts), 0.2, 0.35, 0.15), 0.55)


def pickpocket_squeak() -> None:
    """소매치기 "찍!" (높고 짧은 쥐 울음)."""
    n = at(0.22)
    squeak = osc("tri", np.geomspace(1800, 900, n)) * env_adsr(n, 0.005, 0.15, 0.0, 0.05)
    x = lowpass(squeak, 5000)
    write("pickpocket_squeak", x, 0.6)


# ── 6단계: 스킬트리·자동화·특수 기능 ──────────────────────

def lock_break() -> None:
    """첫 클로버: 스킬트리 자물쇠가 깨진다(짧은 크랙 + 밝은 챠임)."""
    n = at(0.12)
    crack = highpass(noise(n), 2200) * exp_decay(n, 0.03)
    m = at(0.5)
    chime = (osc("sine", np.full(m, note(79))) + 0.5 * osc("sine", np.full(m, note(84)))) * env_adsr(m, 0.005, 0.4, 0.0, 0.1)
    x = mix((crack * 0.8, 0), (chime * 0.5, at(0.03)))
    write("lock_break", reverb(x, 0.2, 0.4, 0.3), 0.8)


def fever_start() -> None:
    """피버 타임 발동: 상승 스윕 + 팡파르."""
    n = at(0.5)
    sweep = osc("saw", np.geomspace(180, 1400, n)) * env_adsr(n, 0.02, 0.4, 0.2, 0.1) * 0.5
    m = at(0.35)
    chord = sum(osc("square", np.full(m, note(p))) for p in [72, 76, 79, 84]) * 0.15
    x = mix((sweep, 0), (chord * env_adsr(m, 0.01, 0.3, 0.0, 0.05), at(0.35)))
    write("fever_start", reverb(lowpass(x, 6000), 0.25, 0.5, 0.3), 0.9)


def fever_end() -> None:
    """피버 타임 종료: 부드러운 하강."""
    n = at(0.4)
    x = osc("sine", np.geomspace(900, 260, n)) * env_adsr(n, 0.01, 0.35, 0.0, 0.1) * 0.5
    write("fever_end", lowpass(x, 3500), 0.6)


def piggy_break() -> None:
    """황금 저금통이 깨지며 칩이 쏟아진다."""
    n = at(0.18)
    crack = highpass(noise(n), 1800) * exp_decay(n, 0.05)
    parts: list[tuple[np.ndarray, int]] = [(crack * 0.9, 0)]
    rng = np.random.default_rng(19)
    for k in range(10):
        f = rng.uniform(2400, 4000)
        m = at(0.05)
        coin = osc("sine", np.full(m, f)) * exp_decay(m, 0.03)
        parts.append((coin * 0.3, at(0.08 + k * 0.03)))
    write("piggy_break", reverb(mix(*parts), 0.2, 0.4, 0.2), 0.8)


def wof_appear() -> None:
    """운명의 휠 등장 챠임."""
    m = at(0.6)
    chord = sum(osc("sine", np.full(m, note(p))) for p in [67, 72, 76, 79]) * 0.2
    write("wof_appear", reverb(chord * env_adsr(m, 0.02, 0.5, 0.1, 0.2), 0.3, 0.6, 0.4), 0.75)


def wof_tick() -> None:
    """운명의 휠이 도는 동안 딸깍거림."""
    n = at(0.05)
    x = highpass(noise(n), 3000) * exp_decay(n, 0.02)
    write("wof_tick", x, 0.4)


def wof_land() -> None:
    """운명의 휠이 칸에 멈춤."""
    n = at(0.3)
    thud = osc("sine", np.geomspace(500, 220, n)) * exp_decay(n, 0.12)
    ring = osc("sine", np.full(n, note(88))) * exp_decay(n, 0.2) * 0.4
    write("wof_land", reverb(thud * 0.7 + ring, 0.2, 0.4, 0.2), 0.75)


def destiny_flip() -> None:
    """운명 뒤집기: 공이 옆 포켓으로 튕기는 '딱'."""
    n = at(0.1)
    click = highpass(noise(at(0.015)), 2500) * exp_decay(at(0.015), 0.006)
    bounce = osc("tri", np.geomspace(700, 300, n)) * exp_decay(n, 0.06) * 0.6
    x = np.zeros(n)
    x[:len(click)] += click
    x += bounce
    write("destiny_flip", x, 0.65)


def main() -> None:
    ui_hover()
    ui_click()
    panel_swish("panel_open", True)
    panel_swish("panel_close", False)
    marble_place()
    marble_remove()
    spin_start()
    ball_roll_loop()
    deflector_hit()
    pocket_land()
    chip_click()
    win_normal()
    win_good()
    win_big()
    win_jackpot()
    lose()
    near_miss()
    deny()
    clover_get()
    neon_flicker()
    coin_drop()
    buy_coin()
    slot_open()
    marble_roll()
    golden_beam()
    promote_charge()
    promote_flash()
    promote_jingle("promote_jingle_1", 1)
    promote_jingle("promote_jingle_2", 2)
    promote_jingle("promote_jingle_3", 3)
    dialogue_blip_baron()
    baron_footstep()
    baron_cane_tap()
    bass_drop()
    contract_unroll()
    quill_sign()
    stamp_thud()
    chip_bag_toss()
    pickpocket_squeak()
    dialogue_blip_lucy()
    lock_break()
    fever_start()
    fever_end()
    piggy_break()
    wof_appear()
    wof_tick()
    wof_land()
    destiny_flip()
    print("sfx ok:", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
