#!/usr/bin/env bash
# Install the macOS-Spotlight restyle of io.github.maajix.spotlight.
#
# Idempotent. Run again after `omarchy plugin update` to re-apply the patch --
# or just run `omarchy-plugin-patches`, which this installs to ~/.local/bin.
#
#   ./install.sh              install the plugin if missing, then patch it
#   ./install.sh --patch-only skip the plugin install, just re-apply

set -uo pipefail

PLUGIN_ID="io.github.maajix.spotlight"
UPSTREAM="https://github.com/maajix/omarchy-spotlight"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
PATCH_DIR="$HOME/.config/omarchy/plugin-patches"
BIN_DIR="$HOME/.local/bin"

say() { printf '==> %s\n' "$*"; }
die() { printf '!! %s\n' "$*" >&2; exit 1; }

command -v omarchy >/dev/null || die "omarchy is not on PATH -- this is not an Omarchy machine."

# ---------------------------------------------------------------- 1. plugin
if [ "${1:-}" != "--patch-only" ] && [ ! -d "$PLUGIN_DIR" ]; then
  say "Installing $PLUGIN_ID from $UPSTREAM"
  omarchy plugin add "$UPSTREAM" --enable || die "plugin add failed"
fi
[ -d "$PLUGIN_DIR" ] || die "$PLUGIN_DIR does not exist. Install the plugin first."

version=$(python3 -c "import json;print(json.load(open('$PLUGIN_DIR/manifest.json'))['version'])" 2>/dev/null || echo "?")
say "Plugin present, version $version (the patch was made against 1.1.4)"

# ---------------------------------------------------------------- 2. patch
say "Installing the patch and the re-apply tool"
mkdir -p "$PATCH_DIR" "$BIN_DIR"
cp "$HERE/config/$PLUGIN_ID.patch" "$PATCH_DIR/"
install -m 755 "$HERE/tools/omarchy-plugin-patches" "$BIN_DIR/omarchy-plugin-patches"

if git -C "$PLUGIN_DIR" apply --reverse --check "$PATCH_DIR/$PLUGIN_ID.patch" >/dev/null 2>&1; then
  say "Patch is already applied -- nothing to do"
elif git -C "$PLUGIN_DIR" apply "$PATCH_DIR/$PLUGIN_ID.patch" 2>/dev/null; then
  say "Patch applied"
  omarchy restart shell
else
  die "Patch does not apply to version $version. Upstream moved -- rebuild the
    restyle by hand from PROMPT.md, then re-record the patch:
      cd $PLUGIN_DIR && git diff > $PATCH_DIR/$PLUGIN_ID.patch"
fi

# ---------------------------------------------------------------- 3. hyprland
cat <<'EOF'

==> Hyprland config is NOT written automatically.

    Append these to your own files -- they are small and you may already have
    conflicting binds:

      config/looknfeel-snippet.lua  ->  ~/.config/hypr/looknfeel.lua
      config/bindings-snippet.lua   ->  ~/.config/hypr/bindings.lua

    The layer rule needs blur enabled globally. Omarchy ships it OFF:

      decoration.blur.enabled = true

    Then: hyprctl reload && hyprctl configerrors

==> Optional: the restyle asks for Inter and falls back to Noto Sans.

      omarchy pkg add inter-font

EOF
say "Done. Verify with ./verify.sh"
