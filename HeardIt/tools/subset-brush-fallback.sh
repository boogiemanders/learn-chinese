#!/bin/sh
# Rebuild the LXGW WenKai TC fallback so it covers every character in Shared/words.json.
# Run from HeardIt/ after adding words. Needs: python3 with fonttools.
set -e
tmp=$(mktemp -d)
curl -sSL -o "$tmp/full.ttf" https://raw.githubusercontent.com/google/fonts/main/ofl/lxgwwenkaitc/LXGWWenKaiTC-Bold.ttf
python3 -c "import json;w=json.load(open('Shared/words.json'));print(''.join(sorted({c for x in w for k in ('simplified','traditional') for c in x[k]})))" > "$tmp/chars.txt"
python3 -m fontTools.subset "$tmp/full.ttf" --text-file="$tmp/chars.txt" --output-file=Shared/Fonts/LXGWWenKaiTC-Bold.ttf --layout-features='*'
rm -rf "$tmp"
