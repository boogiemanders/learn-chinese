# Round 6: the rest of the app in the approved R5c style.
# Fonts: Zhi Mang Xing (brush) + Songti SC. Three sizes per board.
# Run: python3 r6.py  -> writes R6-*.html next to this file.
import re
from pathlib import Path

HERE = Path(__file__).parent
R5C = (HERE / "R5c.html").read_text()
FILT = re.search(r'<svg width="0" height="0".*?</svg>\n', R5C, re.S).group(0)

SEAL = ('<span role="img" aria-label="Heard It" style="width:30px;height:30px;border-radius:50%;border:2px solid var(--red);'
        'color:var(--red);display:flex;align-items:center;justify-content:center;font-family:var(--brush);font-size:24px;'
        'filter:url(#stamp)">听</span>')
CHOP = ('<div aria-hidden="true" style="position:absolute;left:306px;top:372px;width:20px;padding:4px 0;border:2px solid var(--red);'
        'color:var(--red);display:flex;flex-direction:column;align-items:center;font-size:15px;line-height:17px;font-weight:700;'
        'filter:url(#stamp)"><span>听</span><span>过</span></div>')
SPK = ('<svg width="21" height="18" viewBox="0 0 16 14" fill="none" stroke="currentColor" stroke-width="1.3">'
       '<path d="M2 5 L5 5 L8 2 L8 12 L5 9 L2 9 Z"/><path d="M11 4 C13 6 13 8 11 10"/></svg>')
X = '<svg width="{s}" height="{s}" viewBox="0 0 21 21" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 4 L17 17 M17 4 L4 17"/></svg>'
DASH = '<svg width="{s}" height="{s}" viewBox="0 0 21 21" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 10.5 L18 10.5"/></svg>'
CHECK = '<svg width="{s}" height="{s}" viewBox="0 0 24 21" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M3 11 L9 17 L21 4"/></svg>'


def page(title, body, bg="var(--page)"):
    return f"""<!doctype html>
<html lang="zh">
<head>
<meta charset="utf-8">
<title>{title}</title>
<link href="https://fonts.googleapis.com/css2?family=Zhi+Mang+Xing&display=swap" rel="stylesheet">
<style>
  :root{{--page:#FAFAF8;--panel:#2D5F7C;--ink:#23485C;--ink2:#FAFAF8;--muted:#4F6F82;--line:#BFCBD3;--red:#C1352B;--brush:'Zhi Mang Xing',cursive;}}
  body {{ margin: 0; }}
  .screen {{ width: 390px; height: 844px; background: {bg}; color: var(--ink); position: relative; overflow: hidden; font-family: 'Songti SC', serif; }}
  .S {{ font-size: 15px; letter-spacing: 2px; }} .M {{ font-size: 24px; }}
  .abs {{ position: absolute !important; }}
  .vert {{ writing-mode: vertical-rl; letter-spacing: 6px; }}
  .circ {{ border-radius: 50%; display: flex; align-items: center; justify-content: center; position: relative; }}
  .row {{ display: flex; align-items: center; justify-content: space-between; min-height: 55px; border-bottom: 1px solid var(--line); }}
</style>
</head>
<body>
{FILT}<div class="screen">
{body}
</div>
</body>
</html>
"""


def tabs(active):
    out = []
    for t in ["Today", "Words", "Settings"]:
        st = "color:var(--ink);border-bottom:1px solid var(--ink);padding-bottom:3px" if t == active else ""
        out.append(f'<span style="{st}">{t}</span>')
    return ('<div class="S abs" style="left:55px;right:55px;bottom:34px;display:flex;justify-content:space-between;color:var(--muted)">'
            + "".join(out) + "</div>")


def header(right):
    return (f'  <div class="abs" style="left:26px;top:55px">{SEAL}</div>\n'
            f'  <div class="S abs" style="right:26px;top:63px;color:var(--muted)">{right}</div>')


def panel(hero, line_m, line_s, labels=("菜单解码", "你已经会说")):
    return f"""
  <div class="abs" style="left:26px;right:26px;top:123px;height:338px;background:var(--panel)"></div>
  <div class="S abs vert" style="left:42px;top:144px;color:var(--ink2)">{labels[0]}</div>
  <div class="S abs vert" style="right:42px;top:144px;color:var(--ink2)">{labels[1]}</div>
  <div class="abs" style="left:0;right:0;top:183px;text-align:center;font-family:var(--brush);font-size:146px;line-height:1;color:var(--ink2)">{hero}</div>
  {f'<div class="M abs" style="left:0;right:0;top:364px;text-align:center;color:var(--ink2);letter-spacing:8px">{line_m}</div>' if line_m else ''}
  <div class="S abs" style="left:0;right:0;top:410px;text-align:center;color:var(--ink2)">{line_s}</div>
  {CHOP}"""


boards = {}

def plain(pad="0 13px", center=False):
    al = "center" if center else "flex-start"
    return (f'<div style="display:flex;flex-direction:column;justify-content:center;align-items:{al};height:100%;padding:{pad};box-sizing:border-box;line-height:1.25">'
            '<span class="M" style="letter-spacing:4px">叉烧</span><span class="S" style="letter-spacing:1px">chāshāo</span>'
            '<span class="S" style="letter-spacing:1px;opacity:.85">barbecued pork</span></div>')

# 1. Lock screen in context. iOS draws lock screen widgets in one tint (white), so no red or blue fills there.
W = "rgba(255,255,255,.92)"
boards["R6-lock"] = page("R6 Lock screen with Heard It widgets", f"""
  <div class="S abs" style="left:0;right:0;top:89px;text-align:center;color:{W};letter-spacing:0">叉烧 chāshāo · barbecued pork</div>
  <div class="abs" style="left:0;right:0;top:110px;text-align:center;color:#fff;font:600 89px/1 -apple-system,system-ui,sans-serif;letter-spacing:-2px">9:41</div>
  <div class="abs" style="left:34px;top:233px;width:221px;height:72px;border-radius:21px;background:rgba(255,255,255,.14);color:#fff">{plain()}</div>
  <div class="abs circ" style="left:284px;top:233px;width:72px;height:72px;background:rgba(255,255,255,.14);color:#fff"><div style="display:flex;flex-direction:column;align-items:center;line-height:1.15;text-align:center"><span style="font-size:17px">叉烧</span><span style="font-size:10px">chāshāo</span><span style="font-size:10px;opacity:.85">BBQ pork</span></div></div>
  <div class="abs circ" style="left:47px;bottom:55px;width:55px;height:55px;background:rgba(255,255,255,.14)"></div>
  <div class="abs circ" style="right:47px;bottom:55px;width:55px;height:55px;background:rgba(255,255,255,.14)"></div>
  <div class="abs" style="left:130px;right:130px;bottom:13px;height:5px;border-radius:3px;background:#fff"></div>""",
    bg="var(--panel)")

# 2. Widget sheet: every size and state, at real size.
SW = "background:#2D5F7C;border-radius:21px;color:#fff;box-sizing:border-box"
def lbl(t, top):
    return f'<div class="S abs" style="left:26px;top:{top}px;color:var(--muted)">{t}</div>'
mini = lambda icon, s: f'<span class="circ" style="width:34px;height:34px;border:1px solid rgba(255,255,255,.6)">{icon.format(s=s)}</span>'
boards["R6-widgets"] = page("R6 Widget sizes and states", f"""
  {lbl("Lock screen · rectangular", 55)}
  <div class="abs" style="left:26px;top:89px;width:221px;height:72px;{SW}">{plain()}</div>
  {lbl("1×1", 199)}
  <div class="abs circ" style="left:26px;top:233px;width:72px;height:72px;{SW};border-radius:50%"><div style="display:flex;flex-direction:column;align-items:center;line-height:1.15;text-align:center"><span style="font-size:17px">叉烧</span><span style="font-size:10px">chāshāo</span><span style="font-size:10px;opacity:.85">BBQ pork</span></div></div>
  {lbl("Inline", 199).replace("left:26px", "left:123px")}
  <div class="S abs" style="left:123px;top:252px;padding:5px 13px;{SW};border-radius:13px;letter-spacing:0">叉烧 chāshāo · barbecued pork</div>
  {lbl("Home screen · small", 343)}
  <div class="abs" style="left:26px;top:377px;width:158px;height:158px;border-radius:21px;background:var(--panel);color:#fff">{plain(center=True)}</div>
  <div class="S abs" style="left:205px;top:377px;right:26px;color:var(--muted);line-height:1.6;letter-spacing:0">On the lock screen iOS tints widgets one colour, so they're white on your wallpaper. On the home screen they keep the blue. The inline line is cut off by iOS if a word's English is long, so it uses a short gloss.</div>""")

# 3. Card before reveal: only the brush word, plus the sound.
boards["R6-front"] = page("R6 Card before reveal", f"""
{header("6 left")}
{panel("叉烧", "", "Tap to see")}
  <div role="button" aria-label="Hear it" class="abs circ" style="left:167px;top:495px;width:55px;height:55px;border:1px solid var(--ink)">{SPK}</div>
  <div class="S abs" style="left:0;right:0;top:565px;text-align:center;color:var(--muted)">Say it first, then check</div>
  {tabs("Today")}""")

# 4. Done for today.
days = ["M", "T", "W", "T", "F", "S", "S"]
def day(i):
    if i < 4:   # done
        mark = '<span class="circ" style="width:30px;height:30px;border:2px solid var(--red);filter:url(#stamp)"></span>'
    elif i == 4:  # today
        mark = (f'<span class="circ" style="width:34px;height:34px;color:#fff"><span class="abs" style="inset:0;border-radius:50%;'
                f'background:var(--red);filter:url(#stamp)"></span><span style="position:relative;display:flex">{CHECK.format(s=15)}</span></span>')
    else:
        mark = '<span class="circ" style="width:32px;height:32px;border:1px solid var(--line)"></span>'
    return (f'<div style="display:flex;flex-direction:column;align-items:center;gap:8px;width:34px">'
            f'<span style="height:34px;display:flex;align-items:center">{mark}</span><span class="S" style="color:var(--muted);letter-spacing:0">{days[i]}</span></div>')
boards["R6-done"] = page("R6 Done for today", f"""
{header("0 left")}
{panel("好了", "今日完成", "[ done for today ]", labels=("今日", "五天连续"))}
  <div class="M abs" style="left:0;right:0;top:495px;text-align:center">6 words · 5 got it</div>
  <div class="abs" style="left:34px;right:34px;top:576px;display:flex;justify-content:space-between">{''.join(day(i) for i in range(7))}</div>
  <div class="S abs" style="left:0;right:0;bottom:123px;text-align:center;color:var(--muted)">Next cards tomorrow at 8:00</div>
  {tabs("Today")}""")

# 5. Words list.
words = [("叉烧", "barbecued pork", 3), ("点心", "dim sum", 2), ("菜单", "menu", 3), ("买单", "the bill", 1),
         ("牛腩", "beef brisket", 1), ("虾饺", "shrimp dumpling", 0), ("云吞面", "wonton noodles", 2), ("打包", "to go", 2)]
def dots(n):
    return "".join(f'<span style="width:8px;height:8px;border-radius:50%;{"background:var(--ink)" if i < n else "border:1px solid var(--line);box-sizing:border-box"}"></span>' for i in range(3))
rows = "".join(f'<div class="row"><span style="display:flex;align-items:baseline;gap:13px"><span class="M">{c}</span>'
               f'<span class="S" style="color:var(--muted)">{e}</span></span><span style="display:flex;gap:5px">{dots(n)}</span></div>'
               for c, e, n in words)
decks = "".join(f'<span style="{"color:var(--ink);border-bottom:1px solid var(--ink);padding-bottom:3px" if i == 0 else ""}">{d}</span>'
                for i, d in enumerate(["Menu", "Travel", "Essentials", "Canto pairs"]))
boards["R6-words"] = page("R6 Words list", f"""
{header("66 words")}
  <div class="abs" style="left:26px;top:110px;font-family:var(--brush);font-size:55px;line-height:1">词表</div>
  <div class="S abs" style="left:26px;right:26px;top:199px;display:flex;justify-content:space-between;color:var(--muted)">{decks}</div>
  <div class="abs" style="left:26px;right:26px;top:243px;border-top:1px solid var(--line)">{rows}</div>
  {tabs("Words")}""")

# 6. Settings.
def toggle(on):
    if on:
        return '<span style="width:44px;height:26px;border-radius:13px;background:var(--ink);position:relative"><span class="abs" style="right:3px;top:3px;width:20px;height:20px;border-radius:50%;background:#fff"></span></span>'
    return '<span style="width:44px;height:26px;border-radius:13px;border:1px solid var(--line);box-sizing:border-box;position:relative"><span class="abs" style="left:3px;top:2px;width:20px;height:20px;border-radius:50%;background:var(--line)"></span></span>'
seg = ('<span style="display:flex;border:1px solid var(--ink)"><span class="M" style="padding:0 13px;background:var(--ink);color:#fff">简</span>'
       '<span class="M" style="padding:0 13px">繁</span></span>')
step = ('<span style="display:flex;align-items:center;gap:13px"><span class="circ" style="width:30px;height:30px;border:1px solid var(--line)">'
        + DASH.format(s=13) + '</span><span class="M">6</span><span class="circ" style="width:30px;height:30px;border:1px solid var(--line)">'
        '<svg width="13" height="13" viewBox="0 0 21 21" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 10.5 L18 10.5 M10.5 3 L10.5 18"/></svg></span></span>')
def srow(label, ctl):
    return f'<div class="row"><span class="S">{label}</span>{ctl}</div>'
boards["R6-settings"] = page("R6 Settings", f"""
{header("")}
  <div class="abs" style="left:26px;top:110px;font-family:var(--brush);font-size:55px;line-height:1">设定</div>
  <div class="abs" style="left:26px;right:26px;top:199px;border-top:1px solid var(--line)">
    {srow("Characters", seg)}
    {srow("普 Mandarin pinyin", toggle(True))}
    {srow("粵 Cantonese jyutping", toggle(True))}
    {srow("Play sound when shown", toggle(True))}
    {srow("Cards a day", step)}
  </div>
  <div class="S abs" style="left:26px;top:504px;color:var(--muted)">Decks</div>
  <div class="abs" style="left:26px;right:26px;top:534px;border-top:1px solid var(--line)">
    {srow("Menu", toggle(True))}{srow("Travel", toggle(True))}{srow("Essentials", toggle(True))}{srow("Canto pairs", toggle(False))}
  </div>
  {tabs("Settings")}""")

# 7. App icon options, big and at home-screen size.
def icon(kind, size):
    r = round(size * 0.225); ring = round(size * 0.62); bw = max(2, round(size * 0.03)); fs = round(size * 0.4)
    bg = "#FAFAF8" if kind == 2 else "var(--panel)"
    ch = "var(--red)" if kind == 2 else "#fff"
    if kind == 3:
        inner = (f'<span class="circ" style="width:{ring}px;height:{ring}px;color:#fff;font-family:var(--brush);font-size:{fs}px">'
                 f'<span class="abs" style="inset:0;border-radius:50%;background:var(--red);filter:url(#stamp)"></span><span style="position:relative">听</span></span>')
    else:
        inner = (f'<span class="circ" style="width:{ring}px;height:{ring}px;border:{bw}px solid var(--red);color:{ch};font-family:var(--brush);'
                 f'font-size:{fs}px;filter:url(#stamp)">听</span>')
    edge = "box-shadow:0 0 0 1px var(--line);" if kind == 2 else ""
    return f'<span style="flex-shrink:0;width:{size}px;height:{size}px;border-radius:{r}px;background:{bg};{edge}display:flex;align-items:center;justify-content:center">{inner}</span>'
names = {1: "Blue, red ring, white 听", 2: "Paper, red ring, red 听", 3: "Blue, red stamp, white 听"}
irows = "".join(f'<div style="display:flex;align-items:center;gap:34px;margin-bottom:34px">{icon(k, 144)}'
                f'<div style="display:flex;flex-direction:column;gap:13px">{icon(k, 60)}<span class="S" style="color:var(--muted)">{k} · {names[k]}</span></div></div>'
                for k in (1, 2, 3))
boards["R6-icon"] = page("R6 App icon options", f"""
  <div class="abs" style="left:26px;top:55px;font-family:var(--brush);font-size:55px;line-height:1">听过</div>
  <div class="abs" style="left:26px;right:26px;top:144px">{irows}</div>""")

for name, html in boards.items():
    (HERE / f"{name}.html").write_text(html)
print("wrote", ", ".join(boards))
