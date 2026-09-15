-- The Mission Control lines from ~/.config/hypr/autostart.lua.

-- macOS "Mission Control" (CTRL+UP): the Quickshell overview runs resident and
-- shows/hides over IPC, because launching it per keypress took ~340ms before
-- anything appeared -- ~145ms of Qt/QML startup plus ~190ms decoding the 5K
-- wallpaper, neither avoidable per launch. Resident it opens in ~80ms.
--
-- It loads hidden, so there is nothing to put away and no flash at login.
-- `sleep 2` for the same reason as the dock: exec_on_start fires on
-- hyprland.start, before the layer-shell stack is up. If it loses the race
-- anyway, the first CTRL+UP starts the daemon itself and pays the old cost once.
o.exec_on_start("sleep 2 && /home/andy/.local/bin/missioncontrol daemon")
