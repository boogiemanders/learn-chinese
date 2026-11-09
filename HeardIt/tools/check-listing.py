#!/usr/bin/env python3
"""Check App Store listing fields against Apple's character limits."""
import re, sys
from pathlib import Path
limits = {"Name": 30, "Subtitle": 30, "Promotional text": 170, "Keywords": 100, "Description": 4000, "What's New": 4000}
text = Path(sys.argv[1] if len(sys.argv) > 1 else "AppStore/listing.md").read_text()
ok = True
for sec in re.split(r"\n## ", text)[1:]:
    title, _, body = sec.partition("\n")
    key = next((k for k in limits if title.startswith(k)), None)
    if not key: continue
    n = len(body.strip())
    flag = "OK " if n <= limits[key] else "OVER"
    ok &= n <= limits[key]
    print(f"{flag} {key:17} {n:5} / {limits[key]}")
for line in re.findall(r"^\d\. (.+)$", text, re.M):
    print(("OK " if len(line) <= 40 else "OVER"), "caption", len(line), line)
sys.exit(0 if ok else 1)
