# Builds round 4: three brush treatments x three seal styles on the D3 blue layout.
# Each board: one brush font + Songti SC (2 fonts), sizes 15 / 24 / 146.
# Run: python3 make.py  -> writes A1..C3.html next to this file.
from pathlib import Path

OUT = Path(__file__).parent
RED = "#C1352B"

BRUSHES = {
    "A": dict(name="Zhi Mang Xing, dry brush, on the blue panel", font="Zhi Mang Xing",
              panel=True, ink="#FAFAF8", rot=0, top=176, left=0),
    "B": dict(name="Liu Jian Mao Cao, loose on paper (after ruriko 天晴)", font="Liu Jian Mao Cao",
              panel=False, ink="#1C3442", rot=-6, top=150, left=-8),
    "C": dict(name="Liu Jian Mao Cao, wild, on the blue panel", font="Liu Jian Mao Cao",
              panel=True, ink="#FAFAF8", rot=-5, top=160, left=-4),
}
SEALS = {
    "1": "round carved seals, white characters (ref 1)",
    "2": "square carved seals, white characters (ref 1, block)",
    "3": "thin-line red hanko, red characters (ref 3)",
}

FILTERS = """<svg width="0" height="0" style="position:absolute" aria-hidden="true">
  <filter id="stamp" x="-10%" y="-10%" width="120%" height="120%">
    <feTurbulence type="fractalNoise" baseFrequency="0.7" numOctaves="2" seed="4" result="n"/>
    <feColorMatrix in="n" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  -5 0 0 0 4.4" result="m"/>
    <feComposite in="SourceGraphic" in2="m" operator="in" result="s"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.09" numOctaves="2" seed="9" result="w"/>
    <feDisplacementMap in="s" in2="w" scale="3.5" xChannelSelector="R" yChannelSelector="G"/>
  </filter>
  <filter id="dry" x="-5%" y="-5%" width="110%" height="110%">
    <feTurbulence type="fractalNoise" baseFrequency="0.02 0.3" numOctaves="2" seed="2" result="n"/>
    <feColorMatrix in="n" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  -7 0 0 0 5.6" result="m"/>
    <feComposite in="SourceGraphic" in2="m" operator="in" result="s"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="7" result="w"/>
    <feDisplacementMap in="s" in2="w" scale="4" xChannelSelector="R" yChannelSelector="G"/>
  </filter>
</svg>"""


def splatter(color, x, y):
    dots = [(0, 0, 4), (10, 15, 1.8), (-5, 24, 1.3)]
    circles = "".join(f'<circle cx="{40+dx}" cy="{10+dy}" r="{r}"/>' for dx, dy, r in dots)
    return (f'<svg aria-hidden="true" width="80" height="70" viewBox="0 0 80 70" fill="{color}" '
            f'style="position:absolute;left:{x}px;top:{y}px;filter:url(#stamp)">{circles}</svg>')


def logo(seal):
    if seal == "1":
        mark = (f'<span style="width:34px;height:34px;border-radius:50%;background:{RED};color:#fff;'
                f'display:flex;align-items:center;justify-content:center;font-family:var(--brush);font-size:24px;'
                f'filter:url(#stamp)">听</span>')
    elif seal == "2":
        mark = (f'<span style="width:34px;height:34px;background:{RED};color:#fff;display:flex;flex-direction:column;'
                f'align-items:center;justify-content:center;font-size:15px;line-height:15px;font-weight:900;'
                f'filter:url(#stamp)"><span>听</span><span>过</span></span>')
    else:
        mark = (f'<span style="width:30px;height:30px;border:2px solid {RED};color:{RED};display:flex;flex-direction:column;'
                f'align-items:center;justify-content:center;font-size:15px;line-height:15px;font-weight:700;'
                f'filter:url(#stamp)"><span>听</span><span>过</span></span>')
    return (f'<div style="position:absolute;left:26px;top:55px;display:flex;align-items:center;gap:13px">'
            f'<span role="img" aria-label="Heard It">{mark}</span><span class="S">Heard It</span></div>')


def chop(seal, x, y):
    """The signature seal that sits beside the hero, like the chop on a painting."""
    if seal == "1":
        disc = ('<span style="position:absolute;left:{l}px;top:{t}px;width:34px;height:34px;border-radius:50%;'
                f'background:{RED};color:#fff;display:flex;align-items:center;justify-content:center;'
                'font-family:var(--brush);font-size:24px;filter:url(#stamp)">{c}</span>')
        return (f'<div aria-hidden="true" style="position:absolute;left:{x}px;top:{y}px;width:34px;height:34px">'
                + disc.format(l=0, t=0, c="听") + '</div>')
    if seal == "2":
        return (f'<div aria-hidden="true" style="position:absolute;left:{x}px;top:{y}px;width:24px;padding:5px 0;'
                f'background:{RED};color:#fff;display:flex;flex-direction:column;align-items:center;'
                f'font-size:15px;line-height:17px;font-weight:900;filter:url(#stamp)"><span>听</span><span>过</span></div>')
    return (f'<div aria-hidden="true" style="position:absolute;left:{x}px;top:{y}px;width:20px;padding:4px 0;'
            f'border:2px solid {RED};color:{RED};display:flex;flex-direction:column;align-items:center;'
            f'font-size:15px;line-height:17px;font-weight:700;filter:url(#stamp)"><span>听</span><span>过</span></div>')


def got_it(seal):
    if seal == "3":
        return (f'<div class="opt" style="position:relative"><span style="position:absolute;inset:5px;'
                f'border:2px solid {RED};filter:url(#stamp)"></span>'
                f'<span class="S" style="color:{RED};font-weight:700">记得</span><span class="S" style="color:{RED}">Got it</span></div>')
    radius = "inset:0;"
    tilt = "transform:rotate(-1.5deg);"
    return (f'<div class="opt" style="position:relative;color:#fff"><span style="position:absolute;{radius}{tilt}'
            f'background:{RED};filter:url(#stamp)"></span>'
            f'<span class="S" style="position:relative;font-weight:700">记得</span><span class="S" style="position:relative">Got it</span></div>')


def board(bk, sk):
    b = BRUSHES[bk]
    hero_style = (f"position:absolute;left:{b['left']}px;right:0;top:{b['top']}px;text-align:center;"
                  f"font-family:var(--brush);font-size:146px;line-height:1;color:{b['ink']};"
                  f"transform:rotate({b['rot']}deg);filter:url(#dry)")
    if b["panel"]:
        stage = f"""
  <div style="position:absolute;left:26px;right:26px;top:123px;height:338px;background:var(--panel)"></div>
  {splatter(b['ink'], 60, 140)}
  <div style="{hero_style}">叉烧</div>
  {chop(sk, 306, 372)}
  <div class="M" style="position:absolute;left:0;right:0;top:364px;text-align:center;color:var(--ink2);letter-spacing:8px">叉烧</div>
  <div class="S" style="position:absolute;left:0;right:0;top:410px;text-align:center;color:var(--ink2)">barbecued pork</div>"""
    else:
        stage = f"""
  {splatter(b['ink'], 52, 140)}
  <div style="{hero_style}">叉烧</div>
  {chop(sk, 318, 330)}
  <div class="M" style="position:absolute;right:26px;top:384px;letter-spacing:8px">叉烧</div>
  <div class="S" style="position:absolute;right:26px;top:422px;color:var(--muted);font-style:italic">barbecued pork</div>"""

    return f"""<!doctype html>
<html lang="zh">
<head>
<meta charset="utf-8">
<title>R4 {bk}{sk}: {b['name']} + {SEALS[sk]}</title>
<link href="https://fonts.googleapis.com/css2?family={b['font'].replace(' ', '+')}&display=swap" rel="stylesheet">
<style>
  /* Round 4 {bk}{sk}. Fonts: {b['font']} (hero + carved seal) + Songti SC. Sizes: 15 / 24 / 146. */
  :root{{--page:#FAFAF8;--panel:#2D5F7C;--ink:#23485C;--ink2:#FAFAF8;--muted:#4F6F82;--line:#BFCBD3;--brush:'{b['font']}',cursive;}}
  body {{ margin: 0; }}
  .screen {{ width: 390px; height: 844px; background: var(--page); color: var(--ink); position: relative; overflow: hidden; font-family: 'Songti SC', serif; }}
  .S {{ font-size: 15px; letter-spacing: 2px; }} .M {{ font-size: 24px; }}
  .vert {{ writing-mode: vertical-rl; letter-spacing: 6px; }}
  .opt {{ flex: 1; min-height: 55px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; }}
</style>
</head>
<body>
{FILTERS}
<div class="screen">
  {logo(sk)}
  <div class="S" style="position:absolute;right:26px;top:63px;color:var(--muted)">11·09 · 6 left</div>
{stage}

  <div class="M" style="position:absolute;left:0;right:0;top:495px;display:flex;justify-content:center;gap:34px;align-items:center">
    <span>普 chāshāo</span><span style="width:1px;height:34px;background:var(--line)"></span><span>粵 caa1 siu1</span>
  </div>
  <div style="position:absolute;left:0;right:0;top:576px;text-align:center">
    <span class="S" style="display:inline-flex;align-items:center;gap:8px;border-bottom:1px solid var(--ink);padding-bottom:5px">
      <svg width="16" height="14" viewBox="0 0 16 14" fill="none" stroke="var(--ink)" stroke-width="1.3"><path d="M2 5 L5 5 L8 2 L8 12 L5 9 L2 9 Z"/><path d="M11 4 C13 6 13 8 11 10"/></svg>
      听一听 · Hear it</span>
  </div>
  <div style="position:absolute;left:26px;right:26px;bottom:89px;display:flex;border-top:1px solid var(--line);border-bottom:1px solid var(--line)">
    <div class="opt"><span class="S">不记得</span><span class="S">Missed</span></div>
    <div style="width:1px;background:var(--line)"></div>
    <div class="opt"><span class="S">不确定</span><span class="S">Not sure</span></div>
    <div style="width:1px;background:var(--line)"></div>
    {got_it(sk)}
  </div>
  <div class="S" style="position:absolute;left:26px;right:26px;bottom:34px;display:flex;justify-content:space-between;color:var(--muted)">
    <span>今日 Today</span><span>词表 Words</span><span>设定 Settings</span>
  </div>
</div>
</body>
</html>
"""


for bk in BRUSHES:
    for sk in SEALS:
        (OUT / f"{bk}{sk}.html").write_text(board(bk, sk))
print("wrote", len(BRUSHES) * len(SEALS), "boards")


# --- Photo variants: D3 layout over the Gemini wildflower photo (seal style 2) ---
def photo_board(mode, bk):
    b = BRUSHES[bk]
    hero = (f"position:absolute;left:{b['left']}px;right:0;top:{b['top']}px;text-align:center;"
            f"font-family:var(--brush);font-size:146px;line-height:1;color:#FAFAF8;"
            f"transform:rotate({b['rot']}deg);filter:url(#dry)")
    if mode == "F":  # whole screen is the photo
        root = "--page:#7A8F9C;--ink:#FFFFFF;--muted:rgba(255,255,255,.8);--line:rgba(255,255,255,.45)"
        stage = f"""
  <img src="wildflower.jpg" alt="" style="position:absolute;left:0;top:0;width:390px;height:834px;object-fit:cover;
    transform:translate(105px,110px);-webkit-mask-image:linear-gradient(to bottom,transparent 0,#000 80px,#000 330px,transparent 440px),linear-gradient(to right,transparent 0,#000 80px);
    -webkit-mask-composite:source-in;mask-composite:intersect">
  <div style="{hero}">叉烧</div>
  <div class="M" style="position:absolute;left:26px;top:364px;letter-spacing:8px">叉烧</div>
  <div class="S" style="position:absolute;left:26px;top:410px;color:var(--muted)">barbecued pork</div>"""
        name = "whole screen"
    else:  # photo fills the panel only
        root = "--page:#FAFAF8;--ink:#23485C;--muted:#4F6F82;--line:#BFCBD3"
        stage = f"""
  <div style="position:absolute;left:26px;right:26px;top:123px;height:338px;overflow:hidden;background:#7A8F9C">
    <img src="wildflower.jpg" alt="" style="position:absolute;left:0;top:0;width:390px;height:834px;transform:translate(95px,-20px);-webkit-mask-image:linear-gradient(to right,transparent 0,#000 80px)">
  </div>
  <div style="{hero}">叉烧</div>
  <div class="M" style="position:absolute;left:47px;top:364px;letter-spacing:8px;color:#FAFAF8">叉烧</div>
  <div class="S" style="position:absolute;left:47px;top:410px;color:#FAFAF8">barbecued pork</div>"""
        name = "in the panel"
    html = board(bk, "2")
    start = html.index('<div class="screen">')
    head, body = html[:start], html[start:]
    head = head.replace(";--brush:", ";" + root + ";--brush:").replace(
        f"<title>R4 {bk}2:", f"<title>R4 {mode}{bk}: wildflower photo {name},")
    a = body.index('<div class="S" style="position:absolute;right:26px;top:63px')
    a = body.index("</div>", a) + len("</div>")
    z = body.index('<div class="M" style="position:absolute;left:0;right:0;top:495px')
    return head + body[:a] + stage + "\n\n  " + body[z:]


for mode, bk in [("P", "A"), ("F", "A"), ("F", "B")]:
    (OUT / f"{mode}{bk}.html").write_text(photo_board(mode, bk))
print("wrote photo boards")
