-- Mission Control (hyprexpo) -- extracted from ~/.config/hypr/looknfeel.lua.
--
-- This is the CURRENT, WORKING overview: a hyprexpo grid whose columns, rows,
-- gaps and label size are all derived from `desktop_count`. It is the fallback
-- if the Quickshell rewrite in ../PROMPT.md is never built, and the reference
-- for the behaviour that rewrite has to match or beat.
--
-- Paste into looknfeel.lua. Requires `hyprpm enable hyprexpo` (sandwichfarm
-- fork -- the hyprwm one was deleted upstream). See ../FINDINGS.md.

-- Six desktops that always exist, macOS style.
--
-- Hyprland creates workspaces on demand and destroys them again when the last
-- window leaves, so a fixed desktop count is only ever notional: in practice 1
-- and 2 existed and the rest did not. That breaks both things that assume a
-- fixed count:
--   * the 3-finger swipe (input.lua) cannot travel onto a workspace that is not
--     there, and `workspace_swipe_create_new` only ever conjures ONE -- Hyprland
--     refuses to create another while the current workspace is empty, so the
--     swipe dead-ends on the first empty one it makes;
--   * hyprexpo's grid below (max_workspace, dynamic_grid = 0).
-- `persistent` pins them open, so all six are always real and swipeable.
--
-- SIX, not nine: this count is also exactly what the bar shows. The workspace
-- widget renders `[1,2,3,4,5]` plus every workspace that exists
-- (shell/plugins/bar/widgets/Workspaces.qml), so pinning nine put nine numbers
-- in the bar, which was too noisy. Raising this number adds bar digits; there
-- is no way to pin a workspace open without the widget listing it.
--
-- No `monitor` field on purpose: binding them to eDP-1 would strand the
-- external display with no workspaces of its own.
local desktop_count = 6
for i = 1, desktop_count do
  hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

-- Workspace overview via the hyprexpo plugin (sandwichfarm fork; hyprpm, loaded
-- on login by autostart.lua's `hyprpm reload -n`). Trigger: CTRL+UP
-- (bindings.lua) or a 4-finger swipe up on the trackpad (input.lua). Guarded so
-- it's a no-op until `hyprpm enable hyprexpo`.
-- Keynav: arrows move, Enter picks, Esc cancels.
--
-- THE GRID AND SPACING ARE DERIVED, NOT HARD-CODED. Everything below is a
-- function of `desktop_count` above, so changing that one number re-lays out
-- the overview correctly -- no second place to remember to edit.

-- Pick the grid for n desktops: the layout that wastes the fewest cells while
-- staying at least as wide as it is tall, because screens are landscape and a
-- portrait grid leaves big empty bands down the sides.
--   2 -> 2x1   3 -> 3x1   4 -> 2x2   5 -> 3x2   6 -> 3x2
--   7 -> 4x2   8 -> 4x2   9 -> 3x3  12 -> 4x3
-- Columns are capped at 4: past that the thumbnails get too small to read at a
-- glance, which is the entire point of the overview.
local function expo_grid(n)
  local cols, rows
  for c = 1, math.min(n, 4) do
    local r = math.ceil(n / c)
    if c >= r and (cols == nil or c * r < cols * rows) then
      cols, rows = c, r
    end
  end
  if cols == nil then cols, rows = 4, math.ceil(n / 4) end
  -- Never 1 column: `columns = 1` renders the labels but NOT the thumbnails
  -- (degenerate tile geometry in the plugin). Tested, not theoretical.
  return math.max(2, cols), rows
end

local expo_cols, expo_rows = expo_grid(desktop_count)

-- Spacing scales inversely with the grid, so the gaps stay visually in
-- proportion to the tiles instead of eating them alive once there are more
-- desktops. gaps_out is the margin around the whole grid; the extra constant
-- keeps a tile off the screen edge even in the densest layout.
--   2 cols -> 36 in / 84 out    3 cols -> 24 / 60    4 cols -> 18 / 48
local expo_gaps_in = math.floor(72 / expo_cols)
local expo_gaps_out = expo_gaps_in * 2 + 12

-- Label size tracks the tile size for the same reason.
local expo_label_size = math.floor(72 / expo_cols)

-- BACKGROUND: SOLID, AND IT HAS TO BE. Two things were tried and neither works:
--   * `bg_col = "rgba(00000000)"` -- hyprexpo clears the monitor to its own
--     background every frame, so a transparent colour still renders black. You
--     cannot put a blurred layer underneath and let it show through.
--   * `wallpaper_bg = 1` -- does nothing here. It draws Hyprland's own
--     wallpaper, and Omarchy's wallpaper is painted by a layer-surface client,
--     which the plugin cannot reach.
-- So there is no way to get the Launchpad's frosted-wallpaper backdrop out of
-- hyprexpo: that one blurs an Image in QML, inside a process that owns its own
-- surface. This is a near-black with a slight blue cast rather than pure
-- #000000, which reads softer next to the rounded tiles.
if hl.plugin and hl.plugin.hyprexpo then
  hl.config({
    plugin = {
      hyprexpo = {
        columns = expo_cols,
        rows = expo_rows,
        max_workspace = desktop_count,
        -- Always draw the full grid, not just the occupied workspaces -- the
        -- desktops are pinned persistent above precisely so all of them show.
        dynamic_grid = 0,
        skip_empty = 0,

        gaps_in = expo_gaps_in,
        gaps_out = expo_gaps_out,
        bg_col = "rgb(0b0c12)",
        wallpaper_bg = 0,

        -- Rounded thumbnails with a hairline edge, so a tile showing a mostly
        -- dark window still reads as a card against the dark background.
        -- Current/focus/hover brighten the same edge instead of introducing a
        -- second colour.
        tile_rounding = 14,
        tile_rounding_power = 2,
        border_width = 2,
        border_color = "rgba(ffffff26)",
        border_color_current = "rgba(ffffffcc)",
        border_color_focus = "rgba(ffffffee)",
        border_color_hover = "rgba(ffffff88)",

        label_enable = 1,
        label_pos = "top_left",
        label_font_size = expo_label_size,
        label_col = "rgba(ffffffdd)",
        show_workspace_names = 1,
        -- The default `sans` resolves to the system font, which here is Comic
        -- Code -- a monospace with stylised numerals that read as wrong glyphs
        -- at label size. Noto Sans has plain digits. Bold so a number sitting
        -- over a bright thumbnail stays legible.
        label_font_family = "Noto Sans",
        label_font_bold = 1,

        workspace_method = "first 1",
        gesture_distance = 300,
        show_cursor = 1,
        keynav_enable = 1,
        keynav_wrap_v = 1,
      },
    },
  })
end
