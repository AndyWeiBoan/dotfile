-- Spotlight key bindings. Append to ~/.config/hypr/bindings.lua.
--
-- Spotlight takes SUPER+SPACE, the primary launcher key, and Omarchy's own menu
-- moves down to ALT+SPACE. SUPER+ALT+SPACE (Apps menu) is left alone.
--
-- `hl.unbind` first: SUPER+SPACE already belongs to Omarchy's menu, and binding
-- over it without unbinding leaves both handlers attached.
hl.unbind("SUPER + SPACE")
o.bind("SUPER + SPACE", "Spotlight", "omarchy-shell shell toggle io.github.maajix.spotlight '{}'")

-- The toggle payload can prime the query, so this opens Spotlight already
-- typing a reminder. NOT on SUPER+SHIFT+SPACE -- Omarchy uses that for
-- "Toggle top bar".
o.bind("ALT + SHIFT + SPACE", "Spotlight reminder",
  "omarchy-shell shell toggle io.github.maajix.spotlight '{\"query\":\"remind me \"}'")

o.bind("ALT + SPACE", "Omarchy menu", "omarchy-menu toggle")
