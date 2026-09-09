-- hyprbars: macOS-style title bar with traffic-light buttons.
-- The plugin is installed + enabled via hyprpm; hypr/autostart.lua loads it on
-- login with `hyprpm reload`.
--
-- Notes for this try-omarchy (Hyprland 0.56.1 Lua-config) build:
--   * bar_padding / bar_button_padding MUST be > 0 or buttons render zero-width.
--   * bar_precedence_over_border = true puts the bar INSIDE the window border,
--     so the border wraps bar + content instead of cutting between them.
--   * `hyprctl dispatch` here takes a Lua dispatcher expression, not classic args.
--   * hyprbars rebuilds its button list on every config reload, so add_button is
--     called unconditionally below -- the buttons do not stack.
--   * hyprbars has no bar_color_inactive -- one bar colour for every window.

local paths = require("default.hypr.paths")

-- Read the live theme's palette. `omarchy theme set` rewrites this file and then
-- runs omarchy-restart-hyprctl, which reloads the Hyprland config; bootstrap.lua
-- drops `hypr.*` from package.loaded on reload, so this module re-executes and
-- picks the new colours up. No hook needed.
local function theme_colors()
  local colors = {}
  local file = io.open(paths.state_home .. "/omarchy/current/theme/colors.toml", "r")
  if not file then
    return colors
  end

  for line in file:lines() do
    -- colors.toml is flat `key = "#rrggbb"` -- no tables, no arrays.
    local key, hex = line:match('^%s*([%w_]+)%s*=%s*"#(%x%x%x%x%x%x)"')
    if key then
      -- Some themes write uppercase hex (matte-black: "#D35F5F"); normalise so
      -- every value handed to Hyprland has one shape.
      colors[key] = hex:lower()
    end
  end

  file:close()
  return colors
end

local theme = theme_colors()

-- Fall back to the catppuccin values this file used to hardcode, so a missing or
-- malformed colors.toml degrades to the previous look instead of an unstyled bar.
local function color(key, fallback)
  return "rgb(" .. (theme[key] or fallback) .. ")"
end

local function hex_to_rgb(hex)
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

-- Pick a glyph colour for a button by tinting the button's own colour, rather
-- than pulling a theme foreground token. The themes' foreground keys track the
-- theme's light/dark mode, not the button -- `white` ships bright_foreground =
-- #000000, which would paint a black glyph onto its near-black buttons. Staying
-- in the button's own hue also keeps the original look, where the close icon was
-- a dark red (#4d0000) on the red dot rather than flat black.
local function glyph_for(hex)
  local r, g, b = hex_to_rgb(hex)
  local luminance = 0.299 * r + 0.587 * g + 0.114 * b
  if luminance > 140 then
    -- Light button: darken the same hue to 30%.
    r, g, b = r * 0.30, g * 0.30, b * 0.30
  else
    -- Dark button: blend 70% toward white so the glyph stays legible.
    r, g, b = r + (255 - r) * 0.70, g + (255 - g) * 0.70, b + (255 - b) * 0.70
  end
  return string.format("rgb(%02x%02x%02x)", math.floor(r), math.floor(g), math.floor(b))
end

-- Traffic lights, now theme-driven. Fallbacks are the fixed macOS colours this
-- file used before, so a missing colors.toml still yields recognisable buttons.
local function button_colors(key, fallback)
  local hex = theme[key] or fallback
  return "rgb(" .. hex .. ")", glyph_for(hex)
end

local close_bg, close_fg = button_colors("red", "ff5f57")
local max_bg, max_fg = button_colors("yellow", "febc2e")
local full_bg, full_fg = button_colors("green", "28c840")

hl.config({
  plugin = {
    hyprbars = {
      bar_height = 38,
      bar_color = color("background", "1e1e2e"),
      bar_padding = 14,
      bar_button_padding = 9,
      bar_text_size = 11,
      bar_text_align = "center",
      bar_buttons_alignment = "left",
      -- light_foreground is the dimmed title colour every stock theme ships;
      -- plain `foreground` is too bright against the bar on the light themes.
      ["col.text"] = color("light_foreground", "bac2de"),
      icon_on_hover = true,
      -- Draw the border around the whole window (bar included).
      bar_precedence_over_border = true,
    },
  },
})

if hl.plugin and hl.plugin.hyprbars and hl.plugin.hyprbars.add_button then
  -- red = close, yellow = maximize (keeps the bar), green = true fullscreen
  --
  -- The dots follow the theme's red/yellow/green. Be aware those keys are
  -- terminal-palette slots, not UI colours, so on some stock themes the dots
  -- stop reading as traffic lights: `white` renders all three as near-identical
  -- greys (#2a2a2a/#4a4a4a/#3a3a3a), matte-black's green is amber (#FFC107) and
  -- its yellow is dark red (#b91c1c), rose-pine's green is teal (#286983).
  -- Position still disambiguates them: close / maximize / fullscreen, left to
  -- right. To go back to fixed macOS colours, drop the button_colors() calls
  -- above and inline rgb(ff5f57) / rgb(febc2e) / rgb(28c840).
  --
  -- 圖示大小只吃 size（圓圈直徑），不吃 bar_text_size -- 實測過，hyprbars
  -- 沒有獨立的 icon size 選項。要調圖示大小只能換字元。實測墨跡尺寸(裝置px)：
  --   ✖ 2716=18  ✘ 2718=12  ✕ 2715=8  × 00D7=8
  --   ✚ 271A=12  ✛ 271B=12  + 002B 偏下不置中
  --   ⛶ 26F6=13  ⤢ 2922=8   \uF065=14
  -- 現用 ✘ ✚ ⛶ = 12/12/13，三顆對齊。icon 若留空字串，icon_on_hover 就沒東西
  -- 可畫 -- 必須放實際字元。
  hl.plugin.hyprbars.add_button({ bg_color = close_bg, fg_color = close_fg, size = 14, icon = "✘", action = "hyprctl dispatch 'hl.dsp.window.close()'" })
  hl.plugin.hyprbars.add_button({ bg_color = max_bg, fg_color = max_fg, size = 14, icon = "✚", action = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\" })'" })
  hl.plugin.hyprbars.add_button({ bg_color = full_bg, fg_color = full_fg, size = 14, icon = "⛶", action = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"fullscreen\" })'" })
end
