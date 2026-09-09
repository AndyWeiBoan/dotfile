#!/usr/bin/env bash
# End-to-end check that the C# LSP actually works.
#
# Builds a throwaway C# project, opens it in headless Neovim, waits for the LSP
# to attach, and reads back the RUNTIME state. Checking that csharp.lua "looks
# right" proves nothing -- this proves Roslyn loaded the project and analysed it.

set -uo pipefail

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail=0

ok()  { printf '\033[1;32m  ok\033[0m  %s\n' "$*"; }
bad() { printf '\033[1;31m FAIL\033[0m %s\n' "$*"; fail=1; }

echo "== prerequisites =="
for c in nvim dotnet; do
  if command -v "$c" >/dev/null; then ok "$c $($c --version 2>/dev/null | head -1)"
  else bad "$c not found"; fi
done

LS="$HOME/.local/share/nvim/mason/bin/roslyn-language-server"
if [ -x "$LS" ]; then
  ok "Roslyn LS $("$LS" --version 2>/dev/null | head -1)"
else
  bad "Roslyn LS missing at $LS -- run ./install.sh"
fi

[ "$fail" -eq 0 ] || { echo; echo "Prerequisites missing, stopping."; exit 1; }

echo
echo "== building throwaway project in $WORK =="
cat > "$WORK/Probe.csproj" <<'XML'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>
XML
# `using System;` is deliberately unused: it makes Roslyn emit IDE0005, an
# ANALYSER diagnostic. A syntax error would prove only that the parser ran --
# IDE0005 proves the project was loaded and the analysers actually executed.
cat > "$WORK/Program.cs" <<'CS'
using System;
class Probe {
    static void Main() {
        var list = new System.Collections.Generic.List<int>();
        list.Add(1);
        System.Console.WriteLine(list.Count);
    }
}
CS
ok "project written"

cat > "$WORK/probe.lua" <<'LUA'
local out = vim.fn.expand("%:p:h") .. "/probe.out"
local function report(m) local f = io.open(out, "a"); f:write(m .. "\n"); f:close() end
local done, start = false, vim.uv.now()
local t = vim.uv.new_timer()
t:start(1500, 1500, vim.schedule_wrap(function()
  if done then return end
  local cl = vim.lsp.get_clients({ bufnr = 0 })
  local d = vim.diagnostic.get(0)
  -- Stop as soon as a diagnostic lands, or give up waiting for analysis at 45s.
  if #cl > 0 and (#d > 0 or vim.uv.now() - start > 45000) then
    done = true; t:stop()
    report("client=" .. cl[1].name)
    report("root=" .. tostring(cl[1].config.root_dir))
    report("codeLensProvider=" .. tostring(cl[1].server_capabilities.codeLensProvider))
    report("diagnostics=" .. #d)
    for _, x in ipairs(d) do
      report(string.format("  [%s] L%d %s", x.code or x.source or "?", x.lnum + 1, x.message))
    end
    vim.cmd("qa!")
  elseif vim.uv.now() - start > 60000 then
    done = true; t:stop(); report("TIMEOUT"); vim.cmd("qa!")
  end
end))
LUA

echo
echo "== opening it in headless Neovim (up to 90s; first run restores NuGet) =="
( cd "$WORK" && timeout 90 nvim --headless -c "set noswapfile" Program.cs -S probe.lua ) >/dev/null 2>&1

OUT="$WORK/probe.out"
if [ ! -s "$OUT" ]; then
  bad "probe produced no output -- Neovim did not reach the LSP stage"
  exit 1
fi

echo
echo "== runtime state =="
sed 's/^/  /' "$OUT"
echo

grep -q '^client=roslyn'            "$OUT" && ok "Roslyn attached"                     || bad "Roslyn did not attach"
grep -q "^root=$WORK"               "$OUT" && ok "root_dir points at the project"      || bad "root_dir is wrong"
grep -q '^codeLensProvider=false'   "$OUT" && ok "codelens disabled (csharp.lua works)" || bad "codelens still enabled -- the LspAttach autocmd did not run"
grep -q 'IDE[0-9]'                  "$OUT" && ok "analyser diagnostics present"        || bad "no analyser diagnostics -- project may not have loaded"

echo
[ "$fail" -eq 0 ] && echo "All checks passed." || echo "Some checks failed (see above)."
exit "$fail"
