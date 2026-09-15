-- The gesture lines from ~/.config/hypr/input.lua.

-- macOS "Mission Control": 4-finger swipe up toggles the Quickshell workspace
-- overview, 4-finger down leaves it (the same pair CTRL+UP / CTRL+DOWN does --
-- see bindings.lua, which also has the note on why this is no longer the
-- hyprexpo plugin and how to switch back).
--
-- Three and four fingers both, because macOS uses three. Three coexists with
-- the three-finger *horizontal* workspace swipe further down -- `direction` is
-- part of the gesture spec, so the axis distinguishes them.
--
-- If the workspace swipe ever stops responding, it is almost certainly NOT this
-- conflict: Hyprland has a known bug where gestures randomly stop working and
-- `hyprctl reload` does not clear them -- the compositor has to be restarted.
-- There is no unset/ungesture in the Lua API (only hl.unbind for keys), so a
-- reload cannot remove a gesture that was registered earlier in the session.
-- Editing this file and reloading is therefore NOT a valid way to test gesture
-- changes; log out and back in.
--
-- `close` rather than a bare toggle on the downward swipe: a swipe down that
-- *opens* the overview when it is shut is not an exit gesture.
hl.gesture({ fingers = 3, direction = "up", action = function()
  hl.dispatch(hl.dsp.exec_cmd("/home/andy/.local/bin/missioncontrol"))
end })
hl.gesture({ fingers = 4, direction = "up", action = function()
  hl.dispatch(hl.dsp.exec_cmd("/home/andy/.local/bin/missioncontrol"))
end })
hl.gesture({ fingers = 3, direction = "down", action = function()
  hl.dispatch(hl.dsp.exec_cmd("/home/andy/.local/bin/missioncontrol close"))
end })
hl.gesture({ fingers = 4, direction = "down", action = function()
  hl.dispatch(hl.dsp.exec_cmd("/home/andy/.local/bin/missioncontrol close"))
end })

-- macOS "Launchpad" gesture: pinch in with four fingers toggles the Quickshell
-- app grid (the same thing SUPER+A does).
hl.gesture({ fingers = 4, direction = "pinchin", action = function()
  hl.dispatch(hl.dsp.exec_cmd("/home/andy/.local/bin/launchpad"))
end })

-- macOS "switch desktops": 3-finger horizontal swipe slides between
-- workspaces, and the slide animation itself is enabled in looknfeel.lua
-- (Omarchy ships `workspaces` animation disabled, so without that half the
-- gesture lands as an instant hard cut with no travel).
--
-- 4 fingers is already Mission Control (up) and Launchpad (pinch in), so this
-- sits on 3 the way macOS does.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- A TWO-finger version of this is not possible, and it is worth writing down
-- so nobody spends another hour on it:
--   * libinput only emits SWIPE gestures for three or more fingers. Two fingers
--     is always scroll (or pinch); there is no two-finger swipe event to bind.
--   * Hyprland refuses the config outright anyway --
--     `hl.gesture: Gesture will be overshadowed by a previous gesture.
--      Previous HORIZONTAL shadows new HORIZONTAL` -- so it shadows by
--     DIRECTION, independent of finger count. (Note that three-finger up and
--     three-finger horizontal do NOT shadow each other: different directions.)
--   * Two-finger horizontal arrives as horizontal scroll, and Hyprland has no
--     bind for the horizontal scroll axis (mouse_up/mouse_down are vertical).
-- The closest working thing is SUPER + two-finger scroll, which Omarchy already
-- binds to "Scroll active workspace forward/backward" in bindings.lua.

-- Tuning for that gesture. Hyprland's `workspace` gesture action reads these
-- `gestures.workspace_swipe_*` options even though the old workspace_swipe
-- boolean itself is gone from the new gesture system.
hl.config({
  gestures = {
    -- Default is 200px, which on this trackpad flies past a workspace on the
    -- smallest twitch -- the same over-sensitivity that made the Launchpad
    -- jump three pages in one swipe. 300 is roughly a macOS-length swipe.
    workspace_swipe_distance = 300,
    -- Now safe to keep off: looknfeel.lua pins workspaces 1-9 `persistent`, so
    -- all nine always exist and the swipe never needs to invent one. This
    -- option only ever creates a workspace past the highest EXISTING one -- and
    -- Hyprland refuses to create another while the current workspace is empty,
    -- so on its own it dead-ends one step past wherever you started. With the
    -- six pinned open, `false` correctly means "stop at the last desktop".
    workspace_swipe_create_new = false,
    -- Commit past halfway, snap back before it. Keeps a hesitant swipe from
    -- changing workspace by accident.
    workspace_swipe_cancel_ratio = 0.5,
    -- Once the swipe picks an axis, stay on it; stops a slightly diagonal
    -- three-finger drag from fighting itself.
    workspace_swipe_direction_lock = true,
    -- One swipe moves one workspace. `true` would let a single long drag run
    -- through several, which is not how macOS behaves.
    workspace_swipe_forever = false,
  },
})
