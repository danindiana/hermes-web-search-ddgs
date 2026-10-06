#!/bin/sh
# Re-render all diagrams (.dot -> .png @160dpi + .svg) and the logo PNG
set -e
cd "$(dirname "$0")"
for f in diagrams/*.dot; do b="${f%.dot}"; dot -Tpng -Gdpi=160 "$f" -o "$b.png"; dot -Tsvg "$f" -o "$b.svg"; done
command -v rsvg-convert >/dev/null && rsvg-convert -w 1280 assets/logo.svg -o assets/logo.png || convert -background none -density 200 assets/logo.svg -resize 1280x assets/logo.png
