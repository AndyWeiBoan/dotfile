#!/usr/bin/env bash
# Verify hyprbars is loaded and its colours actually match the active Omarchy theme.
#
# Compares what Hyprland reports at runtime against the theme's colors.toml,
# rather than trusting that the config file "looks right".

set -uo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme"
COLORS="$STATE/colors.toml"
fail=0

ok()  { printf '\033[1;32m  ok\033[0m  %s\n' "$*"; }
bad() { printf '\033[1;31m FAIL\033[0m %s\n' "$*"; fail=1; }

theme_color() { grep -oP "^$1\s*=\s*\"#\K[0-9a-fA-F]{6}" "$COLORS" | head -1 | tr 'A-F' 'a-f'; }

# hyprctl reports colours as a packed AARRGGBB int; the theme file is #rrggbb.
runtime_color() {
  hyprctl getoption "plugin:hyprbars:$1" -j 2>/dev/null \
    | python3 -c 'import sys,json; print(format(json.load(sys.stdin)["int"] & 0xffffff, "06x"))' 2>/dev/null
}

echo "== plugin =="
if hyprctl plugin list 2>/dev/null | grep -q hyprbars; then
  ok "hyprbars loaded into the running Hyprland"
else
  bad "hyprbars is NOT loaded -- run: hyprpm reload -n  (or ./install.sh --rebuild after a Hyprland update)"
fi

if hyprpm list 2>/dev/null | grep -A1 'Plugin hyprbars' | grep -q 'enabled: .*true'; then
  ok "hyprbars enabled in hyprpm"
else
  bad "hyprbars not enabled -- run: hyprpm enable hyprbars"
fi

echo
echo "== config =="
if [ -z "$(hyprctl configerrors 2>&1 | tr -d '[:space:]')" ]; then
  ok "no Hyprland config errors"
else
  bad "config errors:"; hyprctl configerrors
fi

echo
echo "== theme linkage ($(cat "$STATE.name" 2>/dev/null || echo '?')) =="
if [ ! -r "$COLORS" ]; then
  bad "cannot read $COLORS"
else
  # bar_color <- background, col.text <- light_foreground. These are exact:
  # Hyprland stores what the config gave it.
  for pair in "bar_color:background" "col.text:light_foreground"; do
    opt="${pair%%:*}"; key="${pair##*:}"
    want="$(theme_color "$key")"; got="$(runtime_color "$opt")"
    if [ "$want" = "$got" ]; then
      ok "$opt = #$got  (theme $key)"
    else
      bad "$opt = #${got:-?}  but theme $key = #${want:-?}"
    fi
  done
fi

echo
echo "== buttons =="
echo "  These are drawn by hyprbars itself and are not exposed via hyprctl."
echo "  Expected from the theme:"
for key in red yellow green; do
  printf '    %-7s #%s\n' "$key" "$(theme_color "$key")"
done
if command -v grim >/dev/null && command -v magick >/dev/null; then
  echo "  Sample them on screen with:"
  echo "    grim /tmp/s.png && magick /tmp/s.png -crop 200x1+0+113 +repage txt: \\"
  echo "      | grep -oE '#[0-9A-F]{6}' | sort | uniq -c | sort -rn | head"
  echo "  (hyprbars renders the dots through its own shader, so sampled values"
  echo "   can sit within ~3/255 of the theme value -- that is expected.)"
fi

echo
[ "$fail" -eq 0 ] && echo "All checks passed." || echo "Some checks failed (see above)."
exit "$fail"
