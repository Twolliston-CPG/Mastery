#!/usr/bin/env python3
"""Generate banner.svg for The Way of the Surge. Render: rsvg-convert -z 2 banner.svg -o banner.png"""
import math

W, H = 1600, 800
X0, X1 = 96, 1504          # week 0 .. week 26
BASE, RISE, K = 690, 520, 3.5
GATES = [4, 9, 13, 17, 21, 26]

def pt(week):
    t = week / 26
    x = X0 + (X1 - X0) * t
    y = BASE - RISE * (math.exp(K * t) - 1) / (math.exp(K) - 1)
    return x, y

curve = " ".join(f"{'M' if i == 0 else 'L'}{x:.1f},{y:.1f}"
                 for i, (x, y) in enumerate(pt(w / 8) for w in range(0, 26 * 8 + 1)))
area = f"{curve} L{X1},{BASE} L{X0},{BASE} Z"

ticks = ""
for w in range(27):
    x, _ = pt(w)
    gate = w in GATES
    ticks += (f'<line x1="{x:.1f}" y1="{BASE}" x2="{x:.1f}" y2="{BASE + (14 if gate else 7)}" '
              f'stroke="{"#e0703f" if gate else "#4a5d75"}" stroke-width="{2 if gate else 1.2}"/>\n')

gates = ""
for i, w in enumerate(GATES, 1):
    x, y = pt(w)
    last = w == 26
    gates += f'<line x1="{x:.1f}" y1="{y:.1f}" x2="{x:.1f}" y2="{BASE}" stroke="#e0703f" stroke-width="1" stroke-dasharray="3 5" opacity="0.45"/>\n'
    if last:
        gates += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="26" fill="#e0703f" opacity="0.18"/>\n'
    gates += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{11 if last else 7}" fill="#e0703f" stroke="#0f1b2d" stroke-width="3"/>\n'
    gates += (f'<text x="{x:.1f}" y="{BASE + 34}" text-anchor="middle" font-size="13" font-weight="600" '
              f'letter-spacing="1.5" fill="#e0703f">GATE {i}</text>\n')

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="Avenir Next, Helvetica, Arial, sans-serif">
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#0b1524"/><stop offset="1" stop-color="#13253d"/>
  </linearGradient>
  <linearGradient id="line" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#2f6fb8"/><stop offset="0.75" stop-color="#6bb0f0"/><stop offset="1" stop-color="#e0703f"/>
  </linearGradient>
  <linearGradient id="fill" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#2f6fb8" stop-opacity="0.38"/><stop offset="1" stop-color="#2f6fb8" stop-opacity="0"/>
  </linearGradient>
</defs>
<rect width="{W}" height="{H}" fill="url(#bg)"/>
<path d="{area}" fill="url(#fill)"/>
<line x1="{X0}" y1="{BASE}" x2="{X1}" y2="{BASE}" stroke="#4a5d75" stroke-width="1.2"/>
{ticks}{gates}<path d="{curve}" fill="none" stroke="url(#line)" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
<circle cx="{X0}" cy="{BASE}" r="6" fill="#0f1b2d" stroke="#6bb0f0" stroke-width="2.5"/>
<text x="{X0}" y="{BASE + 34}" text-anchor="middle" font-size="13" font-weight="600" letter-spacing="1.5" fill="#8fa3bb">ZERO</text>

<text x="{X0}" y="150" font-size="17" font-weight="600" letter-spacing="5" fill="#6bb0f0">A 26-WEEK SERIES · SIX GATES</text>
<text x="{X0}" y="240" font-size="62" font-weight="500" letter-spacing="8" fill="#c9d6e6">THE WAY OF</text>
<text x="{X0 - 6}" y="385" font-size="156" font-weight="700" letter-spacing="2" fill="#ffffff">THE SURGE</text>
<rect x="{X0}" y="420" width="84" height="5" fill="#e0703f"/>
<text x="{X0}" y="482" font-size="38" font-weight="500" fill="#ffffff">From Zero to The Surge</text>
<text x="{X0}" y="528" font-size="20" font-weight="500" letter-spacing="1" fill="#8fa3bb">DevOps  ·  DevSecOps  ·  Platform Engineering</text>
</svg>
'''
open("banner.svg", "w").write(svg)
