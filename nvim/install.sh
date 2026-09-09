#!/usr/bin/env bash
# Set up the C# / Roslyn LSP on a LazyVim install.
#
# Idempotent: safe to re-run. See README.md for what each step does and why.

set -euo pipefail

NVIM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASON_BIN="$HOME/.local/share/nvim/mason/bin/roslyn-language-server"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

command -v nvim >/dev/null || die "nvim not found"

# --- .NET -------------------------------------------------------------------
# Roslyn LS is a .NET program, so a SDK has to be on PATH before it can start.
say "Checking .NET"
if command -v dotnet >/dev/null; then
  say "dotnet $(dotnet --version)"
elif command -v mise >/dev/null; then
  say "Installing dotnet via mise"
  mise use -g dotnet@latest
  eval "$(mise activate bash)" || true
else
  die "No dotnet and no mise. Install a .NET SDK first (mise use -g dotnet@latest)."
fi

# --- LazyVim ----------------------------------------------------------------
if [ ! -f "$NVIM_DIR/init.lua" ]; then
  say "No Neovim config found -- installing the LazyVim starter"
  git clone https://github.com/LazyVim/starter "$NVIM_DIR"
  rm -rf "$NVIM_DIR/.git"
fi

# --- config -----------------------------------------------------------------
say "Installing lua/plugins/csharp.lua"
mkdir -p "$NVIM_DIR/lua/plugins"
target="$NVIM_DIR/lua/plugins/csharp.lua"
if [ -e "$target" ] && ! cmp -s "$SRC_DIR/config/plugins/csharp.lua" "$target"; then
  backup="$target.bak.$(date +%s)"
  cp "$target" "$backup"
  warn "Existing csharp.lua backed up to $backup"
fi
cp "$SRC_DIR/config/plugins/csharp.lua" "$target"

if [ ! -e "$NVIM_DIR/.neoconf.json" ]; then
  cp "$SRC_DIR/config/.neoconf.json" "$NVIM_DIR/.neoconf.json"
fi

# --- plugins ----------------------------------------------------------------
say "Syncing plugins (this pulls roslyn.nvim and symbol-usage.nvim)"
nvim --headless "+Lazy! sync" +qa 2>&1 | tail -3 || true

# --- Roslyn -----------------------------------------------------------------
# LazyVim's ensure_installed fires asynchronously on startup, so a plain
# `nvim +qa` can exit before mason has finished downloading. Drive the install
# explicitly and block until the binary is actually on disk.
if [ -x "$MASON_BIN" ]; then
  say "Roslyn already installed: $("$MASON_BIN" --version 2>/dev/null | head -1)"
else
  say "Installing Roslyn through mason (needs the Crashdummyy registry)"
  # `nvim -c` takes a single command, so the driver goes in a temp file and is
  # sourced with :luafile. mason's install is async, hence the explicit wait.
  driver="$(mktemp --suffix=.lua)"
  cat > "$driver" <<'LUA'
local mr = require("mason-registry")
local done = false
mr.refresh(function()
  local ok, pkg = pcall(mr.get_package, "roslyn")
  if not ok then
    print("ERROR: package roslyn not found -- is the Crashdummyy registry configured?")
    done = true
    return
  end
  if pkg:is_installed() then done = true return end
  pkg:once("install:success", function() done = true end)
  pkg:once("install:failed", function()
    print("ERROR: roslyn install failed")
    done = true
  end)
  pkg:install()
end)
if not vim.wait(300000, function() return done end, 200) then
  print("ERROR: timed out waiting for the roslyn install")
end
LUA
  nvim --headless -c "luafile $driver" +qa 2>&1 | grep -i '^ERROR' || true
  rm -f "$driver"

  [ -x "$MASON_BIN" ] || die "Roslyn did not install. Open nvim and run :Mason to see the error."
  say "Installed: $("$MASON_BIN" --version 2>/dev/null | head -1)"
fi

say "Done."
say "Verify with: ./verify.sh"
