#!/usr/bin/env bash
# Check that the Spotlight restyle is actually in effect -- not that the files
# look right, but that the running system reports what we expect.

set -uo pipefail

PLUGIN_ID="io.github.maajix.spotlight"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
PATCH="$HOME/.config/omarchy/plugin-patches/$PLUGIN_ID.patch"
QML="$PLUGIN_DIR/Spotlight.qml"

fail=0
ok()   { printf '  \033[32mok\033[0m  %s\n' "$*"; }
bad()  { printf '  \033[31mBAD\033[0m %s\n' "$*"; fail=$((fail+1)); }
warn() { printf '  \033[33m--\033[0m  %s\n' "$*"; }

echo "== plugin =="
if [ -d "$PLUGIN_DIR" ]; then
  v=$(python3 -c "import json;print(json.load(open('$PLUGIN_DIR/manifest.json'))['version'])" 2>/dev/null || echo "?")
  ok "installed, version $v"
  [ "$v" = "1.1.4" ] || warn "patch was made against 1.1.4; upstream may have moved"
else
  bad "not installed at $PLUGIN_DIR"; echo; exit 1
fi

echo "== local edits =="
n=$(grep -c 'LOCAL EDIT' "$QML" 2>/dev/null || echo 0)
[ "$n" -eq 14 ] && ok "14 LOCAL EDIT markers in Spotlight.qml" \
                || bad "expected 14 LOCAL EDIT markers, found $n"

# The three that break the look if they are missing, checked by behaviour not
# by line number.
grep -q 'radius: hasResults ? root.cardRadius : height / 2' "$QML" \
  && ok "pill morph (radius follows hasResults)" \
  || bad "pill morph missing -- card radius is not conditional"

grep -q 'q.length === 0' "$QML" \
  && ok "empty query lists nothing" \
  || bad "empty query still builds the frecency list"

grep -q 'y: Math.round(panel.height \* 0.22)' "$QML" \
  && ok "card pinned to the upper fifth" \
  || bad "card is still vertically centred"

echo "== patch =="
if [ -f "$PATCH" ]; then
  if git -C "$PLUGIN_DIR" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
    ok "patch recorded and currently applied"
  else
    bad "patch exists but does not match the working tree -- re-record it:
        cd $PLUGIN_DIR && git diff > $PATCH"
  fi
else
  bad "no patch at $PATCH -- the next 'omarchy plugin update' will wipe the restyle"
fi
command -v omarchy-plugin-patches >/dev/null \
  && ok "omarchy-plugin-patches is on PATH" \
  || bad "omarchy-plugin-patches not installed to ~/.local/bin"

echo "== hyprland =="
# Hyprland has no dump for layer rules (`hyprctl layers` lists surfaces, not
# rules), so this one can only be read back from the config.
grep -q 'omarchy-spotlight' "$HOME/.config/hypr/looknfeel.lua" 2>/dev/null \
  && ok "layer rule present in looknfeel.lua (no runtime dump exists for this)" \
  || bad "no omarchy-spotlight layer rule -- the card will not be frosted"

blur=$(hyprctl getoption decoration:blur:enabled -j 2>/dev/null \
       | python3 -c 'import sys,json;print(json.load(sys.stdin).get("bool"))' 2>/dev/null)
[ "$blur" = "True" ] && ok "global blur is enabled" \
  || bad "decoration:blur:enabled is '$blur' -- a layer rule does nothing without it"

# The binds dispatch through Lua, so the plugin id never appears in the dump.
# The description does.
hyprctl binds -j 2>/dev/null | grep -qi '"description": *"Spotlight' \
  && ok "a key is bound to Spotlight" \
  || bad "no key bound to Spotlight"

echo "== font =="
if fc-list : family 2>/dev/null | tr ',' '\n' | grep -qix 'inter'; then
  ok "Inter installed -- the restyle will use it"
else
  warn "Inter not installed; falling back to Noto Sans (omarchy pkg add inter-font)"
fi

echo
[ "$fail" -eq 0 ] && echo "All checks passed." || echo "$fail check(s) failed."
exit $(( fail > 0 ))
