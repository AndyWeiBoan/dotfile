#!/usr/bin/env bash
# Install hyprbars (macOS-style title bars) on an Omarchy / Hyprland machine.
#
# Idempotent: safe to re-run. See README.md for what each step does and why.
#
#   ./install.sh            # install + wire up config
#   ./install.sh --rebuild  # only rebuild the plugin (after a Hyprland update)

set -euo pipefail

REPO_URL="https://github.com/hyprwm/hyprland-plugins"
PLUGIN="hyprbars"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

command -v hyprpm  >/dev/null || die "hyprpm not found -- is this a Hyprland machine?"
command -v hyprctl >/dev/null || die "hyprctl not found -- is this a Hyprland machine?"
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || die "Run this from inside a running Hyprland session."

# hyprpm compiles the plugin against the running Hyprland's headers, so a
# toolchain has to be present. Omarchy ships base-devel already; cpio is the one
# that is commonly missing and the failure it produces is not obvious.
say "Checking build dependencies"
missing=()
for pkg in base-devel cmake meson ninja cpio git pkgconf; do
  pacman -Qq "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done
if [ ${#missing[@]} -gt 0 ]; then
  say "Installing: ${missing[*]}"
  sudo pacman -S --needed --noconfirm "${missing[@]}"
fi

# `hyprpm update` fetches the Hyprland source matching the running version and
# builds the plugin headers. It MUST be re-run after every Hyprland upgrade --
# a plugin built against old headers refuses to load and the bar silently
# disappears. See the "After a Hyprland update" section in README.md.
say "Building plugin headers for $(hyprctl version | head -1 | awk '{print $2}')"
hyprpm update

if [ "${1:-}" = "--rebuild" ]; then
  say "Reloading plugins"
  hyprpm reload -n
  say "Done (rebuild only)."
  exit 0
fi

if hyprpm list 2>/dev/null | grep -q "Plugin $PLUGIN"; then
  say "Plugin repository already added"
else
  say "Adding $REPO_URL"
  hyprpm add "$REPO_URL"
fi

say "Enabling $PLUGIN"
hyprpm enable "$PLUGIN"

say "Installing $HYPR_DIR/hyprbars.lua"
mkdir -p "$HYPR_DIR"
if [ -e "$HYPR_DIR/hyprbars.lua" ] && ! cmp -s "$SRC_DIR/config/hyprbars.lua" "$HYPR_DIR/hyprbars.lua"; then
  backup="$HYPR_DIR/hyprbars.lua.bak.$(date +%s)"
  cp "$HYPR_DIR/hyprbars.lua" "$backup"
  warn "Existing config backed up to $backup"
fi
cp "$SRC_DIR/config/hyprbars.lua" "$HYPR_DIR/hyprbars.lua"

# hyprland.lua has to require the module, or the file is just dead code on disk.
if [ -f "$HYPR_DIR/hyprland.lua" ] && ! grep -q 'require("hypr.hyprbars")' "$HYPR_DIR/hyprland.lua"; then
  say "Adding require(\"hypr.hyprbars\") to hyprland.lua"
  # Sit with the other personal overrides: just before require("hypr.autostart")
  # if that exists, otherwise after the last require("hypr.*"). Order does not
  # actually matter (these are declarative), but keeping the block tidy does.
  awk '
    /^require\("hypr\.autostart"\)/ && !before { before = NR }
    /^require\("hypr\./ { last = NR }
    { lines[NR] = $0 }
    END {
      at = before ? before - 1 : last
      for (i = 1; i <= NR; i++) {
        if (i == at + 1) print "require(\"hypr.hyprbars\")"
        print lines[i]
      }
      if (at == NR) print "require(\"hypr.hyprbars\")"
    }
  ' "$HYPR_DIR/hyprland.lua" > "$HYPR_DIR/hyprland.lua.tmp"
  mv "$HYPR_DIR/hyprland.lua.tmp" "$HYPR_DIR/hyprland.lua"
fi

# Plugins are NOT persisted across reboots by hyprpm itself -- something has to
# call `hyprpm reload` at login or the bar is missing until you run it by hand.
if [ -f "$HYPR_DIR/autostart.lua" ] && ! grep -q 'hyprpm reload' "$HYPR_DIR/autostart.lua"; then
  say "Adding the login hook to autostart.lua"
  cat >> "$HYPR_DIR/autostart.lua" <<'LUA'

-- Load hyprpm-managed Hyprland plugins (hyprbars) on login.
o.exec_on_start("hyprpm reload -n")
LUA
fi

say "Reloading"
hyprpm reload -n
hyprctl reload >/dev/null

errors="$(hyprctl configerrors 2>&1 | tr -d '[:space:]')"
[ -z "$errors" ] || die "Hyprland reported config errors:\n$(hyprctl configerrors)"

say "Done. Title bars should be visible now."
say "Verify with: ./verify.sh"
