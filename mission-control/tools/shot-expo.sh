#!/usr/bin/env bash
# Screenshot the hyprexpo overview.
#
# Two things make this harder than `grim out.png`:
#   1. expo opens with a zoom-out animation. Capture too early and you get the
#      grid mid-flight, which looks like a completely different (broken) layout
#      -- tiles far too large and cut off at the edges.
#   2. Closing expo SELECTS whichever tile the cursor happens to be over, so a
#      naive open/capture/close drags the user onto a random workspace. This
#      records the starting workspace and puts them back.
#
# Usage: ./shot-expo.sh [output.png]   (also writes <name>-small.png at 45%)

set -uo pipefail

out="${1:-expo.png}"
toggle='hl.plugin.hyprexpo.expo("toggle")'   # the dispatcher only accepts toggle/select

orig=$(hyprctl activeworkspace -j 2>/dev/null \
       | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' 2>/dev/null) || {
  echo "cannot reach Hyprland" >&2; exit 1
}

hyprctl dispatch "$toggle" >/dev/null 2>&1
sleep 2                                    # let the zoom-out settle
grim "$out" || { echo "grim failed" >&2; exit 1; }
hyprctl dispatch "$toggle" >/dev/null 2>&1
sleep 0.8
hyprctl dispatch "hl.dsp.focus({ workspace = \"$orig\" })" >/dev/null 2>&1

if command -v magick >/dev/null 2>&1; then
  magick "$out" -resize 45% "${out%.png}-small.png"
fi

echo "captured $out (restored workspace $orig)"
