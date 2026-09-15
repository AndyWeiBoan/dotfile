//@ pragma UseQApplication

// A macOS-Launchpad-style app grid for Hyprland, built on Quickshell.
//
// nwg-drawer could not do the three things that make it read as Launchpad --
// a fixed rows x columns page, page dots, and an icon size that adapts to the
// screen -- so this replaces it.
//
// Runs as a DAEMON, started at login by autostart.lua, and shows/hides itself on
// `qs ipc call launchpad {open,hide,toggle}`. ~/.local/bin/launchpad wraps that
// and SUPER+A is bound to the wrapper.
//
// It is a daemon because launching it per keypress took ~340ms before anything
// appeared, which is visible as a lag. That is not this config being slow: an
// empty layer surface is 5ms, so roughly 145ms is Qt/QML starting up and 190ms
// is decoding the 5120x2880 wallpaper, neither of which can be avoided per
// launch (giving the Image a smaller sourceSize measured *slower* -- Qt still
// parses the whole JPEG and then adds a scale). Staying resident pays both once,
// at login, and a toggle becomes a unix socket round trip. Same treatment, same
// numbers, as ~/.config/quickshell/missioncontrol.
//
// One window per screen, so a 5K monitor and the laptop panel each size their
// own grid instead of sharing one pixel-fixed icon size.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: root

  // Page shape. Everything else -- cell size, icon size, fonts -- derives from
  // these and the screen, which is what keeps it sharp on both monitors.
  readonly property int columns: 6
  readonly property int rows: 5
  readonly property int perPage: columns * rows

  // Starts hidden. A config that shows itself on load flashed the whole grid
  // across the screen at every login, before the wrapper could hide it.
  property bool shown: false

  IpcHandler {
    target: "launchpad"

    // NOT named `show`. `qs ipc` has its own subcommands -- show, call, wait,
    // listen, prop -- and its parser claims those words wherever they appear,
    // so `qs ipc call launchpad show` never reaches this object: it prints the
    // function list and exits 0, silently.
    function open(): void { root.setShown(true); }
    function hide(): void { root.setShown(false); }
    function toggle(): void { root.setShown(!root.shown); }
    function state(): string { return root.shown ? "shown" : "hidden"; }
  }

  function setShown(next) {
    if (next === root.shown)
      return;
    if (next) {
      // A resident process keeps whatever the user left behind. Reopening onto
      // the previous search text and page would be wrong -- Launchpad always
      // opens on page one with an empty box -- so reset here rather than on
      // hide, where a stale frame of the reset could be visible.
      root.query = "";
      root.resetRequested();
    }
    root.shown = next;
  }

  // Panels listen for this to clear their own search field and page index;
  // those live per-screen, so root cannot reach them directly.
  signal resetRequested()

  property string query: ""

  // Every visible application, sorted by name. DesktopEntries is Quickshell's
  // own .desktop index, so this tracks installs/removals live.
  readonly property var allApps: {
    const out = [];
    const values = DesktopEntries.applications.values || [];
    for (let i = 0; i < values.length; i++) {
      const entry = values[i];
      if (!entry || entry.noDisplay)
        continue;
      // Launchpad's own entry exists only so the dock can pin it; listing it
      // inside itself would be silly.
      if (String(entry.id) === "launchpad")
        continue;
      out.push(entry);
    }
    out.sort((a, b) => String(a.name).toLowerCase().localeCompare(String(b.name).toLowerCase()));
    return out;
  }

  // Typing filters in place, the way Launchpad's search does.
  readonly property var apps: {
    const q = root.query.trim().toLowerCase();
    if (q.length === 0)
      return root.allApps;
    return root.allApps.filter(entry => {
      return String(entry.name || "").toLowerCase().includes(q)
          || String(entry.genericName || "").toLowerCase().includes(q);
    });
  }

  readonly property int pageCount: Math.max(1, Math.ceil(root.apps.length / root.perPage))

  function iconFor(entry) {
    const name = String((entry && entry.icon) || "");
    if (name.length === 0)
      return Quickshell.iconPath("application-x-executable", true);
    if (name.startsWith("file://") || name.startsWith("image://"))
      return name;
    if (name.startsWith("/"))
      return "file://" + name;
    const themed = Quickshell.iconPath(name, true);
    return themed.length > 0 ? themed : Quickshell.iconPath("application-x-executable", true);
  }

  // Launch through uwsm-app + gtk-launch, the same path Omarchy's own menu
  // uses: it keeps apps out of the compositor's systemd scope and copes with
  // desktop ids containing spaces. Keep the .desktop suffix or ids like
  // org.telegram.desktop fail to resolve.
  function launch(entry) {
    const id = String((entry && entry.id) || "");
    if (id.length === 0)
      return;
    Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", id + ".desktop"]);
    // Hide, never Qt.quit(): this process is the daemon, and quitting it would
    // make the next SUPER+A pay the full ~340ms startup again.
    root.setShown(false);
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"

      // Hiding tears down the layer surface but keeps the QML tree and, more to
      // the point, the decoded wallpaper -- which is the 190ms.
      visible: root.shown

      // Overlay layer so it covers the bar too, exclusive keyboard focus so
      // typing goes to the search box without a click first. The namespace is
      // what looknfeel.lua's blur layer rule matches on.
      WlrLayershell.namespace: "launchpad"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      exclusionMode: ExclusionMode.Ignore

      // --- derived geometry -------------------------------------------------
      readonly property real sidePad: Math.round(panel.width * 0.06)
      readonly property real searchBand: Math.round(panel.height * 0.13)
      readonly property real dotsBand: Math.round(panel.height * 0.07)
      readonly property real gridW: panel.width - sidePad * 2
      readonly property real gridH: panel.height - searchBand - dotsBand
      readonly property real cellW: gridW / root.columns
      readonly property real cellH: gridH / root.rows
      // Icon takes a little under half the cell so the label and the gaps have
      // room; the cap keeps it sane if a screen is very wide but short.
      readonly property int iconSize: Math.max(32, Math.round(Math.min(cellW * 0.44, cellH * 0.52)))
      readonly property int labelSize: Math.max(10, Math.round(iconSize * 0.15))

      // Background: the desktop wallpaper, blurred here in QML, with a dark
      // tint over it -- exactly what macOS Launchpad does.
      //
      // This is deliberately NOT a compositor blur. A `blur = true` layer rule
      // on a full-screen layer makes hyprbars' title bars flicker between
      // transparent and coloured whenever they redraw, and turning off
      // decoration:blur:new_optimizations was not enough to stop it. Blurring
      // the wallpaper image ourselves keeps Hyprland's blur machinery out of it
      // entirely, so there is nothing left to flicker.
      Image {
        id: wallpaper
        anchors.fill: parent
        // The Omarchy theme's current background; the symlink follows theme
        // switches, so this always matches what is actually on the desktop.
        source: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
        fillMode: Image.PreserveAspectCrop
        // Loaded synchronously on purpose: asynchronous loading painted the
        // icon grid first and blurred the background a beat later, which read
        // as the window opening in two steps. A local JPEG costs a few ms.
        asynchronous: false
        cache: true
        visible: false
      }

      MultiEffect {
        anchors.fill: parent
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        brightness: -0.1
      }

      Rectangle {
        anchors.fill: parent
        color: "#0e101a"
        opacity: 0.42
      }

      // Click anywhere that isn't an app to dismiss. A TapHandler rather than a
      // MouseArea: a MouseArea grabs the press and the DragHandler below would
      // never see a swipe. Handlers cooperate -- a drag simply isn't a tap.
      TapHandler {
        onTapped: root.setShown(false)
      }

      function goTo(index) {
        pages.currentIndex = Math.max(0, Math.min(index, root.pageCount - 1));
      }

      // Paging is driven explicitly rather than by letting the ListView free-
      // drag: with SnapOneItem + StrictlyEnforceRange a drag has to cross half
      // a page to commit, which on a 5K screen means a huge sweep -- anything
      // less slid a little and sprang back.
      //
      // A touchpad two-finger scroll arrives as a burst of small wheel events,
      // so they are accumulated and a page turns once the total passes one
      // notch; the accumulator resets on each turn so one long swipe does not
      // skip several pages.
      property real wheelAccumulated: 0
      // Set the moment a page turns, cleared only once the scrolling has been
      // quiet for a beat. One physical swipe = one page: a touchpad keeps
      // firing events through the whole gesture, and without this the tail of
      // a single flick kept re-crossing the threshold and ran to the last page.
      property bool paging: false

      Timer {
        id: pagingCooldown
        interval: 300
        onTriggered: panel.paging = false
      }

      function scrolled(delta) {
        if (root.pageCount <= 1)
          return;

        // Still inside the gesture that already turned a page: swallow the
        // rest of it, and keep pushing the cooldown out until the finger stops.
        if (panel.paging) {
          panel.wheelAccumulated = 0;
          pagingCooldown.restart();
          return;
        }

        panel.wheelAccumulated += delta;
        if (panel.wheelAccumulated <= -120)
          panel.goTo(pages.currentIndex + 1);
        else if (panel.wheelAccumulated >= 120)
          panel.goTo(pages.currentIndex - 1);
        else
          return;

        panel.wheelAccumulated = 0;
        panel.paging = true;
        pagingCooldown.restart();
      }

      // Two handlers, because WheelHandler.orientation defaults to Qt.Vertical
      // and silently drops horizontal wheel events -- which is why a sideways
      // two-finger swipe did nothing while an up/down one paged fine.
      WheelHandler {
        orientation: Qt.Horizontal
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => panel.scrolled(event.angleDelta.x)
      }

      WheelHandler {
        orientation: Qt.Vertical
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => panel.scrolled(event.angleDelta.y)
      }

      // Click-and-drag / touch swipe: commit on release once the drag has gone
      // a twelfth of the screen, instead of half a page.
      DragHandler {
        id: swipe
        target: null
        yAxis.enabled: false
        property real startX: 0
        onActiveChanged: {
          if (active) {
            startX = centroid.position.x;
            return;
          }
          const dx = centroid.position.x - startX;
          const threshold = panel.width / 12;
          if (dx <= -threshold)
            panel.goTo(pages.currentIndex + 1);
          else if (dx >= threshold)
            panel.goTo(pages.currentIndex - 1);
        }
      }

      // --- search pill ------------------------------------------------------
      Rectangle {
        id: searchPill
        width: Math.round(panel.width * 0.24)
        height: Math.round(panel.searchBand * 0.42)
        radius: height / 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(panel.searchBand * 0.34)
        color: Qt.rgba(1, 1, 1, 0.14)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)

        Text {
          id: glass
          anchors.verticalCenter: parent.verticalCenter
          x: parent.height * 0.42
          text: "⌕"
          color: Qt.rgba(1, 1, 1, 0.65)
          font.pixelSize: Math.round(parent.height * 0.5)
        }

        TextInput {
          id: search
          anchors {
            left: glass.right; leftMargin: parent.height * 0.3
            right: parent.right; rightMargin: parent.height * 0.5
            verticalCenter: parent.verticalCenter
          }
          color: "#ffffff"
          font.pixelSize: Math.round(parent.height * 0.42)
          selectByMouse: true
          selectionColor: Qt.rgba(1, 1, 1, 0.25)
          focus: true
          onTextChanged: {
            root.query = text;
            pages.currentIndex = 0;
          }

          // The daemon keeps this TextInput alive between openings, so it has
          // to be cleared and re-focused explicitly. Focus especially: the
          // layer surface is torn down on hide and the item loses focus with
          // it, and without taking it back typing would go nowhere on the
          // second opening.
          Connections {
            target: root
            function onResetRequested() {
              search.text = "";
              pages.currentIndex = 0;
              search.forceActiveFocus();
            }
          }

          Keys.onEscapePressed: root.setShown(false)
          Keys.onReturnPressed: if (root.apps.length > 0) root.launch(root.apps[0])
          Keys.onEnterPressed: if (root.apps.length > 0) root.launch(root.apps[0])
          Keys.onLeftPressed: event => {
            if (search.text.length > 0) { event.accepted = false; return; }
            panel.goTo(pages.currentIndex - 1);
          }
          Keys.onRightPressed: event => {
            if (search.text.length > 0) { event.accepted = false; return; }
            panel.goTo(pages.currentIndex + 1);
          }

          Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: search.text.length === 0
            text: "Search"
            color: Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: search.font.pixelSize
          }
        }
      }

      // --- paged grid -------------------------------------------------------
      ListView {
        id: pages
        anchors {
          left: parent.left; leftMargin: panel.sidePad
          right: parent.right; rightMargin: panel.sidePad
          top: parent.top; topMargin: panel.searchBand
        }
        height: panel.gridH

        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: 220
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        model: root.pageCount
        // Panel-level WheelHandler/DragHandler own paging; a self-flicking
        // ListView would fight them and swallow their events.
        interactive: false

        delegate: Item {
          required property int index
          width: pages.width
          height: pages.height

          Grid {
            anchors.centerIn: parent
            columns: root.columns
            rowSpacing: 0
            columnSpacing: 0

            Repeater {
              model: {
                const start = index * root.perPage;
                return root.apps.slice(start, start + root.perPage);
              }

              delegate: Item {
                id: tile
                required property var modelData
                width: panel.cellW
                height: panel.cellH

                Rectangle {
                  anchors.fill: parent
                  anchors.margins: Math.round(panel.cellW * 0.06)
                  radius: Math.round(panel.iconSize * 0.22)
                  color: hover.hovered ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                  Behavior on color { ColorAnimation { duration: 120 } }
                }

                Column {
                  anchors.centerIn: parent
                  spacing: Math.round(panel.iconSize * 0.14)

                  Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: root.iconFor(tile.modelData)
                    sourceSize.width: panel.iconSize
                    sourceSize.height: panel.iconSize
                    width: panel.iconSize
                    height: panel.iconSize
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    scale: hover.hovered ? 1.06 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120 } }
                  }

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: panel.cellW * 0.9
                    horizontalAlignment: Text.AlignHCenter
                    text: String(tile.modelData.name || "")
                    color: "#ffffff"
                    font.pixelSize: panel.labelSize
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                  }
                }

                HoverHandler { id: hover }
                TapHandler { onTapped: root.launch(tile.modelData) }
              }
            }
          }
        }
      }

      // --- page dots --------------------------------------------------------
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: panel.searchBand + panel.gridH + Math.round(panel.dotsBand * 0.3)
        spacing: Math.round(panel.dotsBand * 0.22)
        visible: root.pageCount > 1

        Repeater {
          model: root.pageCount
          delegate: Rectangle {
            required property int index
            width: Math.max(6, Math.round(panel.dotsBand * 0.11))
            height: width
            radius: width / 2
            color: index === pages.currentIndex ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.35)
            Behavior on color { ColorAnimation { duration: 150 } }

            TapHandler { onTapped: pages.currentIndex = index }
          }
        }
      }
    }
  }
}
