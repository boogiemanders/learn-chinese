#!/usr/bin/env python3
"""Add word-level vocabulary from the private coaching-session log to Shared/words.json.

Only single words and short terms (1-4 characters) are taken; no sentences, notes or
dialogue. Readings come from open tools (pypinyin, PyCantonese) and meanings from
CC-CEDICT (CC BY-SA 4.0), falling back to a short session gloss only when CC-CEDICT has none.

usage: import-sessions.py <phrases.csv> <cedict_ts.u8>
"""
import csv, json, re, sys
from pathlib import Path
import pycantonese
from pypinyin import pinyin, Style

src, cedict_path = sys.argv[1], sys.argv[2]
words_path = Path("Shared/words.json")
words = json.loads(words_path.read_text())
have = {w["simplified"] for w in words}

cedict = {}
for line in open(cedict_path, encoding="utf-8"):
    if line.startswith("#"): continue
    m = re.match(r"(\S+) (\S+) \[([^\]]+)\] /(.+)/", line)
    if not m: continue
    trad, simp, _, defs = m.groups()
    good = [d for d in defs.split("/") if not re.match(r"(variant of|old variant|surname|CL:|see |abbr\. for|used in)", d)]
    if good and simp not in cedict:
        cedict[simp] = (trad, good)

def meaning(simp, gloss):
    if simp in cedict:
        defs = cedict[simp][1]
        best = min(defs[:3], key=len)
        return re.sub(r"\s*\([^)]*\)", "", best).strip()[:40] or None
    g = gloss.strip().rstrip(".")
    return g[:40] if g else None

def py(s): return "".join(x[0] for x in pinyin(s, style=Style.TONE))
def jp(s):
    out = []
    for _, j in pycantonese.characters_to_jyutping(s):
        if not j: return ""
        out.append(re.sub(r"(\d)(?=[a-z])", r"\1 ", j))
    return " ".join(out)

best = {}
for r in csv.DictReader(open(src, encoding="utf-8-sig")):
    s = r["simplified"].strip()
    if not re.fullmatch(r"[㐀-鿿]{1,4}", s) or s in have: continue
    n = int(r["sessions"] or 0)
    if s not in best or n > best[s][0]: best[s] = (n, r)

added = []
for s, (n, r) in sorted(best.items(), key=lambda kv: -kv[1][0]):
    m = meaning(s, r["english"])
    if not m: continue
    trad = (r["traditional"] or "").strip() or cedict.get(s, (s,))[0]
    canto = r["language"] == "Cantonese"
    j = (r["jyutping"] or "").strip() if canto and r["jyutping"].strip() else jp(trad)
    added.append({"id": f"c-{len(added)+1:04d}", "simplified": s, "traditional": trad,
                  "pinyin": py(s), "jyutping": j, "meaning": m,
                  "deck": "cantoPair" if canto else "core", "mandarinWord": None, "note": None})

words_path.write_text(json.dumps(words + added, ensure_ascii=False, indent=1))
print(f"added {len(added)}; library now {len(words) + len(added)} words")
