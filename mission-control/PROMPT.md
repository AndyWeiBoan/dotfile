# 重建提示詞

兩種用法：

- **想要背景模糊的 macOS Mission Control（＝這台機器現在跑的東西）** → 貼 **§2**。
  自己寫一個 Quickshell overview，幾百行 QML。當初的關鍵風險（離畫面的視窗抓不抓
  得到）**已經驗證過了，抓得到**，所以這條路現在是通的。
- **只想要十分鐘弄好、不在乎背景** → 貼 **§1**。裝 hyprexpo 並照
  `config/hyprexpo.lua` 設定，但**背景是純色、不可能模糊**（原因見 `FINDINGS.md` §1）。
  這也是目前留著的 fallback。

§3 是變體追加指令，§4 是驗收標準，§5 是寫這段提示詞時的取捨說明。

> 先讀 `FINDINGS.md`。那份記錄了實際試過而且失敗的東西，不重讀會重踩。

---

## §1 主提示詞 A：hyprexpo 版（現況、可用）

````text
在這台 Omarchy / Hyprland 機器上裝 hyprexpo，做出 macOS Mission Control 風格的
工作區總覽。格子和間距要能隨桌面數量自適應。

## 背景（不用再研究，直接採用）

- hyprexpo **已經從 hyprwm/hyprland-plugins 上游刪除**。要用
  https://github.com/sandwichfarm/hyprexpo 這個 fork（有跟上 Hyprland 0.56）。
- 這個 overview 的**背景不可能做成模糊**。已經實測過兩條路都失敗：
  `bg_col` 設成全透明還是畫出純黑（plugin 每幀把 monitor 清成自己的背景色，
  底下墊東西也透不上來）；`wallpaper_bg = 1` 完全無效（它畫的是 Hyprland 內建
  桌布，而 Omarchy 的桌布是 layer-surface client 畫的，plugin 拿不到）。
  不要再試這兩個，也不要試著在底下墊一層模糊 layer。
- 如果使用者堅持要模糊背景，那不是調 hyprexpo 參數能解決的，要改寫成
  Quickshell overview —— 那是另一份提示詞（§2）。

## 環境假設

- Omarchy，Hyprland 使用 Lua 設定（~/.config/hypr/*.lua，不是 hyprland.conf）
- 個人覆寫放 ~/.config/hypr/，絕對不要動 /usr/share/omarchy/（更新會被蓋掉）
- **這個 build 的 `hyprctl keyword` 不能用**，會回
  "keyword can't work with non-legacy parsers"。而且它是無聲失敗：指令印 ok，
  值卻沒變。調參數一律改檔案再 `hyprctl reload`，然後用 `hyprctl getoption` 驗證。

## 要做的事

### 1. 安裝

  hyprpm update
  hyprpm add https://github.com/sandwichfarm/hyprexpo
  hyprpm enable hyprexpo
  hyprpm reload -n

確認 ~/.config/hypr/autostart.lua 有 `o.exec_on_start("hyprpm reload -n")`，
沒有的話每次登入 plugin 都不會載入。

### 2. 先把桌面釘住，這是前提不是裝飾

Hyprland 的 workspace 是**用到才生出來**的。不釘住的話實際只有 1、2 存在，
overview 的格子和三指滑動都會壞掉。

在 looknfeel.lua 裡：

  local desktop_count = 6
  for i = 1, desktop_count do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
  end

不要加 `monitor` 欄位 —— 綁死在內建螢幕的話，外接螢幕插上來會分不到 workspace。

**要先告知使用者一個副作用**：桌面數量 = bar 上的數字數量，沒辦法分開。
Omarchy 的 Workspaces.qml 固定顯示 `[1,2,3,4,5]` 再加上所有存在的 workspace，
所以釘 9 個就會出現 9 個數字。先問清楚要幾個再動手。

### 3. 自適應的格子與間距

**不要寫死 columns/rows/gaps。** 全部從 `desktop_count` 算出來，
這樣改一個數字就能重排，不會有第二個地方要記得改。

寫一個 `expo_grid(n)`，規則：
  - 浪費最少格子（cols*rows 最小）
  - 不准直的比橫的高（`cols >= rows`）—— 螢幕是橫的，直排會左右留一大片空
  - 欄數上限 4 —— 再多縮圖就小到看不清，overview 就沒意義了
  - **永遠不要回傳 1 欄** —— `columns = 1` 畫得出標籤但畫不出縮圖（tile 幾何退化），
    這是實測過的，不是理論

預期輸出（請照這個驗證你的實作）：
  n=2 2x1 / n=3 3x1 / n=4 2x2 / n=5 3x2 / n=6 3x2
  n=7 4x2 / n=8 4x2 / n=9 3x3 / n=10~12 4x3

間距和標籤大小跟著欄數反比縮放，比例才會一致：
  gaps_in  = floor(72 / cols)
  gaps_out = gaps_in * 2 + 12
  label_font_size = floor(72 / cols)

### 4. 外觀

  dynamic_grid = 0, skip_empty = 0      -- 畫完整的格子，不是只畫有東西的
  max_workspace = desktop_count
  bg_col = "rgb(0b0c12)"                -- 帶藍的近黑，比純黑柔和
  wallpaper_bg = 0                      -- 設 1 沒有效果，見上面
  tile_rounding = 14, tile_rounding_power = 2
  border_width = 2
  border_color         = "rgba(ffffff26)"
  border_color_current = "rgba(ffffffcc)"
  border_color_focus   = "rgba(ffffffee)"
  border_color_hover   = "rgba(ffffff88)"
  label_font_family = "Noto Sans"       -- 預設的 sans 會解析成系統的 Comic Code，
  label_font_bold = 1                   -- 等寬字的數字造型放大後看起來像亂碼
  label_col = "rgba(ffffffdd)"
  keynav_enable = 1, keynav_wrap_v = 1, show_cursor = 1

目前桌面/focus/hover 用**同一條邊框的不同亮度**，不要引入第二種顏色。

### 5. 綁定

  bindings.lua:
    o.bind("CTRL + UP", "Workspace overview (Mission Control)", function()
      if hl.plugin and hl.plugin.hyprexpo then hl.plugin.hyprexpo.expo("toggle") end
    end)
  input.lua:
    hl.gesture({ fingers = 4, direction = "up", action = function()
      if hl.plugin and hl.plugin.hyprexpo then hl.plugin.hyprexpo.expo("toggle") end
    end })

兩個都要用 `if hl.plugin and hl.plugin.hyprexpo` 包起來，這樣在還沒
`hyprpm enable` 之前只是無作用，不會讓整份設定報錯。

dispatcher **只吃 "toggle" 和 "select"**，沒有 "off"。

### 6. 順手把三指切桌面也做了（跟這個是同一條線）

  input.lua:
    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
    hl.config({ gestures = {
      workspace_swipe_distance = 300,      -- 預設 200 在觸控板上太敏感
      workspace_swipe_create_new = false,  -- 桌面已經釘住了，這裡才該是 false
      workspace_swipe_cancel_ratio = 0.5,
      workspace_swipe_direction_lock = true,
      workspace_swipe_forever = false,     -- 一次滑動走一格，像 macOS
    }})

  looknfeel.lua（Omarchy 預設把這個動畫**關掉**，沒有這行切桌面是瞬間硬跳）：
    hl.animation({ leaf = "workspaces", enabled = true, speed = 4.5,
                   bezier = "easeOutQuint", style = "slide" })
    -- speed 是「時長」不是速度，數字越大越慢。4.5 = 450ms。

注意：`workspace_swipe_create_new = true` **不是**「滑不過去」的解法。
它最多只生一個 workspace，而且 Hyprland 拒絕在當前 workspace 是空的時候再生下一個，
所以滑到第一個空桌面就會卡死。正解是第 2 步的 persistent。

## 驗收（請實際跑，不要只說「應該可以了」）

1. `hyprctl configerrors` 必須是空的
2. `hyprctl plugin list` 看得到 hyprexpo
3. 每一個算出來的值都要跟執行期對照：
     hyprctl getoption plugin:hyprexpo:columns / rows / max_workspace
                                      / gaps_in / gaps_out / label_font_size
4. `hyprctl workspaces` 要看得到 desktop_count 個 workspace
5. 把 `expo_grid()` 抽出來對 n=1..12 跑一遍，跟上面的預期表逐項比對
6. **實際截圖看**。grim 抓得到 expo，但要注意兩件事：
     - 要等約 2 秒讓 zoom-out 動畫跑完，太早拍會拍到放大到一半的中間狀態
     - 關閉 expo 會「選取」游標所在的那一格，等於把使用者的焦點搬走
       → 先記下原本的 workspace，拍完再 `hl.dsp.focus` 切回去
   可以直接用這個 repo 的 tools/shot-expo.sh

## 規則

- 改任何 ~/.config 檔案前先備份成 <檔名>.bak.$(date +%s)
- 絕對不要修改 /usr/share/omarchy/ 底下的東西（讀取沒問題）
- 設定檔的註解要寫「為什麼」，特別是上面那些陷阱
- 完成後告訴我：驗收每一項的實際輸出，以及有沒有哪一項沒過
````

---

## §2 主提示詞 B：Quickshell 版（現行版本）

> 這份提示詞在這台機器上跑完過，成品是 `config/missioncontrol.qml`。
> 第 0 步的 spike 已經有答案了，但**換一台機器 / 換一版 Hyprland 還是要重測**
> —— 整個計畫都押在那一個假設上。

````text
在這台 Omarchy / Hyprland 機器上，用 Quickshell 寫一個 macOS Mission Control：
模糊的桌布背景 + 每個桌面一張縮圖，格子和間距隨桌面數量自適應。

現在已經有一個 hyprexpo 版（~/.config/hypr/looknfeel.lua），功能正常，
唯一的缺點是背景只能純色。這次重寫就是為了那個模糊背景。
**做不出來的話就退回 hyprexpo 版，不要交一個更差的東西。**

## 第 0 步：先做 spike，這一步會決定整個計畫（不要跳過）

**要驗證的問題：`ScreencopyView` 抓不抓得到「不在畫面上」的視窗？**

> 在 Hyprland 0.56 / Quickshell 0.3.1 上**實測是結果 (1)**：抓得到，而且是即時的。
> Hyprland 為了 screencopy 會把 toplevel 單獨算進一個 offscreen buffer，跟它在不在
> 畫面上無關。所以下面照「完整計畫」走就好。仍然先花五分鐘重測一次，因為這是整份
> 計畫唯一的死穴。

整個 Mission Control 的前提是顯示**其他** workspace 上的視窗內容。但在 Wayland 上，
不可見的 surface 通常不再產生新的 frame。這件事沒有驗證之前，不要寫任何 UI。

寫一個最小的 QML：在別的 workspace 開一個視窗，然後

  import Quickshell.Wayland
  ScreencopyView {
    captureSource: <那個視窗的 Toplevel 物件>
    live: true
  }

印出 `hasContent` 和 `sourceSize`，並且把畫面存下來看。

三種結果，各自的走法：

  (1) 抓得到即時內容
      → 最好。照下面的完整計畫做。

  (2) 抓得到最後一張舊畫面（stale frame）
      → 可以接受，macOS 的縮圖其實也不是即時的。照完整計畫做，但要在切換
        workspace 時 refresh，並且告訴使用者縮圖可能是舊的。

  (3) 完全抓不到（畫面是黑的，或 hasContent 永遠 false）
      → **停下來，回報使用者**。這時候 Quickshell 版只能畫「視窗圖示 + 標題」
        的示意版，不是真的縮圖。那比 hyprexpo 版差，不值得做。
        先問使用者要不要接受示意版，不要自己決定硬做下去。

## 環境（已經查證過，直接用，不要再猜 API）

Quickshell 0.3.1。**注意：`Quickshell/Wayland/quickshell-wayland.qmltypes` 主檔裡
只有 WlSessionLock，只 grep 那個檔會誤判成「沒有這些 API」。**真正的型別在
qmldir re-export 的子模組裡：

  Quickshell/Wayland/_Screencopy         -> ScreencopyView
  Quickshell/Wayland/_ToplevelManagement -> Toplevel
  Quickshell/Wayland/_WlrLayerShell      -> WlrLayershell
  Quickshell/Wayland/_BackgroundEffect   -> BackgroundEffect
  Quickshell/Hyprland/_Ipc               -> Hyprland 單例

可用的東西：

  ScreencopyView : captureSource(QObject) live paintCursor
                   hasContent(ro) sourceSize(ro) captureFrame()

  Toplevel : appId title parent activated screens
             maximized minimized fullscreen
             activate() close() fullscreenOn() setRectangle()
             ※ 沒有座標/尺寸屬性，幾何要從 Hyprland IPC 拿

  Hyprland.workspaces  -> HyprlandWorkspace[]
  Hyprland.toplevels   -> HyprlandToplevel[]
  Hyprland.focusedWorkspace / focusedMonitor / activeToplevel
  Hyprland.dispatch(request)
  Hyprland.usingLua                     -- 見下面「dispatch 的語法」
  Hyprland.refreshWorkspaces() / refreshToplevels()

  HyprlandWorkspace : id name active focused urgent hasFullscreen
                      monitor  toplevels  lastIpcObject
  HyprlandToplevel  : address handle  wayland  title activated urgent
                      lastIpcObject
  HyprlandMonitor   : id name x y width height scale activeWorkspace focused

**兩個關鍵欄位**（這兩個讓整件事變得可行，不要自己去 parse hyprctl）：
  - HyprlandWorkspace.toplevels  = 這個桌面上有哪些視窗，已經分好了
  - HyprlandToplevel.wayland     = 上面那個 Toplevel 物件，可以直接餵給
                                   ScreencopyView.captureSource

視窗幾何從 HyprlandToplevel.lastIpcObject 拿，那就是 `hyprctl clients -j` 的
那一筆，含 at / size / workspace / floating / fullscreen / focusHistoryID。
座標是**全域邏輯座標**，換算進縮圖前要先減掉這個螢幕的原點；而
`HyprlandMonitor.width/height` 是**實體像素**，要除以 scale 才是邏輯大小。

### dispatch 的語法（一定會中的坑，先讀）

Omarchy 用 **Lua** 設定，Lua parser 下送進 IPC 的字串**不是**「dispatcher 名稱 +
參數」，而是一段會被貼進 `hl.dispatch(...)` 求值的 **Lua 運算式**。所以到處看得到的
`dispatch("workspace 3")` 在這裡是語法錯誤，`hyprctl dispatch workspace 3` 一樣會死。

  切桌面：  hl.dsp.focus({ workspace = "3" })
  跳到視窗：hl.dsp.focus({ window = "address:0x55c058e3d1d0" })

- **不要用 `hl.dsp.workspace`**。它是一個 table，裡面是 workspace 的*管理*動作
  （rename / move 到別的螢幕 / change_id / toggle_special）。「切過去」屬於 focus。
- **`HyprlandToplevel.address` 沒有 `0x` 前綴**（`55c0...`），但 dispatcher 要有
  （`0x55c0...`）。少了就回 `hl.focus: window not found`，而使用者只會看到
  「點了沒反應」。
- 用 `Hyprland.usingLua` 分支，兩種語法都留著。
- dispatch 是走 socket 的非同步請求，**送完同一個 tick 就 `Qt.quit()` 會把它切掉**。
  用一個 ~80ms 的 Timer 再退出。

## 架構

參考現有的 Launchpad：~/.config/quickshell/launchpad/shell.qml
（同一套 layer-shell + Variants + 自適應格子的寫法，可以直接抄骨架）

  ~/.config/quickshell/missioncontrol/shell.qml
  ~/.local/bin/missioncontrol          -- toggle 腳本

toggle 腳本要 pgrep **設定檔路徑**而不是程序名 —— Quickshell 的程序叫 `qs`，
不叫 missioncontrol。Launchpad 的腳本已經是這樣寫的，照抄。

### 背景：清晰的真桌面，不要模糊

macOS Mission Control **沒有模糊桌面** —— 背景就是你原本的桌面，只有上方那條
Spaces 列是毛玻璃。直接畫桌布，蓋一層 `opacity ~0.14` 的暗化就好。
**不要加 `sourceSize`**（想叫 Qt 解碼小一點反而更慢，五種尺寸都試過，見 §FINDINGS 8.2）。

### 視窗要「從原位縮小」進去（整個效果的核心）

每個視窗兩組矩形：

  real   = ipc.at - 螢幕原點、尺寸 = ipc.size   // scale 1，剛好蓋在它自己身上
  target = 縮放後在 overview 裡的位置

開啟 = `real` 動畫到 `target`，關閉反過來。x/y/width/height **四個用同一條 easing**，
不然視窗會邊縮邊變形。app 圖示和標題要**縮完才淡入**。

狀態要**兩段**，不能合成一個：`shown` 把 surface 叫上來（視窗畫在 real，
看起來就是原本的桌面），`expanded` 才開始縮。

**`expanded` 的觸發不能用固定延遲。** layer surface 要 ~80ms 以上才真的被合成，
16ms 的 timer 會讓動畫在畫面出現前就跑掉大半。用 `QsWindow.backingWindowVisible`
（`onBackingWindowVisibleChanged`）再多等一帧，並留一個 ~400ms 的 fallback timer。

### 不要用 compositor blur，也不要用 QML 全螢幕模糊

  Image { id: wallpaper
          source: "file://" + Quickshell.env("HOME")
                  + "/.local/state/omarchy/current/background"
          fillMode: Image.PreserveAspectCrop
          asynchronous: false      // 設 true 會變成「先出現內容、背景才模糊」的兩段式開場
          cache: true; visible: false }
  MultiEffect { anchors.fill: parent; source: wallpaper
                autoPaddingEnabled: false
                blurEnabled: true; blur: 1.0; blurMax: 64; brightness: -0.1 }
  Rectangle { anchors.fill: parent; color: "#0e101a"; opacity: 0.42 }

**絕對不要**用 `hl.layer_rule({ blur = true })` 對這個全螢幕 layer 開 compositor
blur，也不要用 `BackgroundEffect.blurRegion`。那會讓 hyprbars 的標題列每次重繪就
閃爍（透明／有色交替），而且 `new_optimizations = false` 擋不住。這是踩過的坑。
（真的想用 BackgroundEffect 的話，必須先單獨驗證不會讓 hyprbars 閃爍。）

### 每個桌面的縮圖

一個 Item，寬高比等於螢幕，裡面放該 workspace 的視窗：

  for each toplevel in workspace.toplevels:
      ScreencopyView {
        captureSource: toplevel.wayland
        live: <看 spike 的結果>
        x/y/width/height: 從 toplevel.lastIpcObject 的 at/size 換算，
                          乘上 (縮圖寬 / 螢幕寬) 的縮放比
      }

空的 workspace 就只顯示背景（可以放同一張桌布，不模糊，代表那是個空桌面）。

### 版面：照真的 macOS，不要排成一個大格子

第一版把所有桌面排成 3x2 的大格子，看起來不像 macOS。真正的版面是兩段：

  上方 Spaces 列：所有桌面的小縮圖，標籤在下面，目前桌面邊框最亮
  下方：**目前**桌面的視窗攤開、互不重疊，app 圖示跨在每個視窗的下緣、標題在下

比例量真的 macOS 截圖：Spaces 列約螢幕高的 15.5%，列裡的縮圖約列高的 2/3。

  stripTileH = min(列高 - 標籤高 - 內距*2,        -- 桌面少 -> 卡在列高
                   可用寬 / 桌面數 * (高/寬))      -- 桌面多 -> 卡在寬度
  stripTileW = stripTileH * 螢幕長寬比

下方的 Exposé：n 個視窗 -> 1→1x1 2→2x1 4→2x2 6→3x2 9→3x3，再多就 ceil(√n) 欄。
每個視窗**照自己的長寬比**縮進格子，**但不要放大超過原尺寸**（把小浮動視窗撐滿
一格，看起來會像另一個視窗）。最後一排不滿要置中，不要靠左吊著。

兩個取捨，不要「修」掉：
  - 下半部永遠是目前桌面，不要跟著 hover 別的桌面換 —— macOS 就是這樣，
    而且 hover 預覽會讓整個畫面一直跳。
  - Exposé 裡**不要**做「非選取變暗」。Spaces 列那邊要（那裡桌布是主體），
    但在 Exposé 裡視窗就是內容，壓暗其他的會讓整個畫面看起來像關掉了。
    選取只用一圈白框加一點點放大。

  圖示用 DesktopEntries.heuristicLookup(appId)，再 fallback 到
  Quickshell.iconPath()。appId 從 lastIpcObject 的 class 欄位拿。

### 互動

  - 點上方 Spaces 列的縮圖 -> 切到那個桌面然後關掉自己（語法見上面）
  - 點下方攤開的視窗 -> 直接 focus 那個視窗（macOS 就是這樣）
  - Esc / 點背景 -> 關掉
  - 方向鍵在攤開的視窗之間移動（上下左右都要 wrap）、1-9 跳桌面、Enter 選取
  - hover 直接當成選取，不要讓 hover 和鍵盤選取變成兩個獨立狀態
  - **退出鍵（CTRL+DOWN／下滑）不可以做成 toggle** —— 沒開的時候按下去會把它
    打開，那就不是退出鍵。腳本吃一個 `close` 參數：有開就關，沒開什麼都不做。
  - 退出鍵要下在 **Hyprland 綁定**，不要只寫在 QML 的 Keys 裡：overview 獨佔
    鍵盤焦點，虛擬鍵盤的修飾鍵不一定送得到 client。QML 那段留著當保險就好。
  - 背景的關閉要用 TapHandler，**不要用 MouseArea** —— MouseArea 會搶走 press，
    讓同層的 DragHandler 收不到事件。這是 Launchpad 踩過的。

### 其他實作細節（都是踩過才知道的）

- **圓角**：`ScreencopyView` 不是 `Rectangle`，沒有 radius，而 `clip: true` 只會切出
  方角。要把整格 `layer.enabled: true`，再用
  `MultiEffect { maskEnabled: true; maskSource: <一個圓角 Rectangle 的 layer> }` 遮。
- **「非當前桌面變暗」的那一層要蓋在視窗縮圖上面**。蓋在底下只會暗到桌布，結果
  有視窗的桌面看起來是亮的、空桌面是暗的，剛好相反。
- **邊框亮度**：0.80 和 0.93 肉眼分不出來。用「選取 0.96 / 當前桌面 0.50 / 其他 0.15」。
- **`ScreencopyView` 會維持長寬比並置中**，不是拉伸填滿。照 at/size 擺好它就剛好填滿。
- 截到的是視窗本身，**不含 hyprbars 的標題列**，縮圖會比真實桌面少一條標題列。
- 視窗疊法照 `focusHistoryID` 由大到小畫，最後 focus 的那個才會在最上面。
- 每一格（包含空桌面）都墊同一張桌布，空桌面才會讀成「一個空的桌面」而不是
  「格子破了一個洞」。

## 要做成常駐程序，不要每次重開（這是硬要求，不是優化）

每次按鍵重跑 `qs`，從按下到畫面出現 **~340ms**，肉眼看得出來在等。拆開是
Qt/QML 啟動 ~145ms + 解 5K 桌布 ~190ms（空的 layer surface 只要 5ms，
ScreencopyView 幾乎免費）。兩者都無法在單次啟動裡省掉 ——
**`sourceSize` 試過三種尺寸，每一種都更慢**（見 FINDINGS §8.2），不要再試。

做法（Quickshell FAQ 的建議路線）：

  IpcHandler { target: "overview"
    function toggle(): void { root.setShown(!root.shown); }
    function show(): void   { root.setShown(true); }
    function hide(): void   { root.setShown(false); }
    function state(): string { return root.shown ? "shown" : "hidden"; }
  }
  PanelWindow { visible: root.shown ... }

登入時 `qs -d -p <config>`，按鍵時 `qs -p <config> ipc call overview toggle`。
結果 75–90ms，代價是常駐 ~375MB、隱藏時 0.2% CPU。

### 常駐化的四個坑（每一個都踩過）

- **預設一定要 `shown: false`**。config 載入就顯示的話，每次登入都會閃一下整個
  overview（wrapper 的 `hide` 慢一步）。wrapper 的冷啟動路徑再明確 `show`。
- **`Qt.quit()` 全部換成 `setShown(false)`**。漏一個就會在使用者選完視窗之後把
  常駐程序殺掉，下次按鍵又付 340ms。
- **開場動畫不能寫在 `Component.onCompleted`** —— 元件只建立一次、顯示很多次，
  只有第一次會有動畫。綁 `shown`，而且 `Behavior { enabled: root.shown }`，
  不然關閉時會看到它慢慢縮回去。
- **顯示前要 refreshMonitors/Workspaces/Toplevels**。常駐程序可能閒置幾小時，
  而縮圖的位置大小全從 `lastIpcObject` 算 —— 視窗被搬過就會畫在錯的地方。

### wrapper 的探活不要用 pgrep

`qs -d -p` 的 cmdline **保留 `-d`**，所以 `pgrep -f "qs -p <config>"` 抓不到 daemon，
會判定「沒在跑」然後**每次按鍵都在前景再開一個實例**。用同一個 socket 問就好：

  alive() { qs -p "$CONFIG" ipc call overview state >/dev/null 2>&1; }

## 安裝（四個東西）

1. `~/.config/quickshell/missioncontrol/shell.qml`
2. `~/.local/bin/missioncontrol`（wrapper：無參數 = toggle、`close` = 只關、
   `daemon` = 起常駐）
3. `~/.config/hypr/autostart.lua`：
   ```lua
   o.exec_on_start("sleep 2 && /home/andy/.local/bin/missioncontrol daemon")
   ```
   `sleep 2` 跟 dock 同一個理由：`exec_on_start` 在 layer-shell 還沒好的時候就開火。
4. bindings.lua / input.lua 指過去：
   ```lua
   o.bind("CTRL + UP", "Workspace overview (Mission Control)",
     "/home/andy/.local/bin/missioncontrol")
   o.bind("CTRL + DOWN", "Close workspace overview",
     "/home/andy/.local/bin/missioncontrol close")
   for _, n in ipairs({ 3, 4 }) do
     hl.gesture({ fingers = n, direction = "up", action = function()
       hl.dispatch(hl.dsp.exec_cmd("/home/andy/.local/bin/missioncontrol"))
     end })
     hl.gesture({ fingers = n, direction = "down", action = function()
       hl.dispatch(hl.dsp.exec_cmd("/home/andy/.local/bin/missioncontrol close"))
     end })
   end
   ```
   三指上滑跟三指左右滑（切桌面）不衝突 —— Hyprland 用手勢起始的方向分辨。

## 怎麼測（UI 沒辦法用指令點）

量效能之前先確認兩件事，不然會得到假數字：

- `/proc/<pid>/stat` 的 utime/stime 單位是 clock tick，`getconf CLK_TCK` 是 **100**。
  N 秒佔一核的百分比 = `delta / N`。寫成 `delta*10/N` 會讓所有數字大 10 倍
  （一度回報 153%，實際 15.3%）。
- **量測區間的頭尾都要確認 layer 還在**。overview 獨佔鍵盤焦點，使用者在那幾秒打字
  就會把它關掉（數字鍵會切桌面），於是「開著時的 CPU」量到的是隱藏狀態。
- `pkill -f "<literal>"` 會match執行它的 shell 自己（heredoc 全在 cmdline 裡），
  pattern 要用展開後的變數。

把 `shell.qml` 複製一份到暫存目錄，注一個 timer 進去驅動要測的函式，
再從外面用 `hyprctl` 看狀態有沒有變、程序有沒有自己結束：

    Timer { interval: 1200; running: true
            onTriggered: { root.goToWorkspace(3) } }

`expoGrid()` 同一招：注一個 `for (let n=1;n<=12;n++) console.log(...)` 再 `Qt.quit()`。
**注意測的時候會在使用者桌面上蓋一層全螢幕 overlay**，人如果正在用電腦，
他的點擊會打到你的測試視窗上 —— 看到對不上的結果先確認是不是這個。

## 規則

- 不要動現有的 hyprexpo 設定，那是 fallback。做好之前 CTRL+UP 要維持原行為。
- 做不出來就說做不出來，不要交一個比 hyprexpo 版差的東西。
- 完成後截圖給我看，並且回報第 0 步 spike 的實際結果。
````

---

## §3 變體追加指令

接在 §1 或 §2 後面，或事後單獨提出。

### 想改桌面數量

````text
把 desktop_count 改成 N。
格子、間距、標籤大小、persistent 規則、max_workspace 全部都是從它算出來的，
所以只要改那一行，不要有第二個地方要改。
改完提醒我 bar 上的數字會跟著變成 N 個 —— 這兩件事在 Omarchy 沒辦法分開。
````

### 想要桌面多、但 bar 上的數字少

````text
Omarchy 的 Workspaces.qml 寫死「[1,2,3,4,5] 加上所有存在的 workspace」，
所以 persistent 的桌面一定會出現在 bar 上。要分開只能 clone 這個 widget
成本地 plugin 再改 workspaceIds()。
做法參考 ~/.config/omarchy/plugins/local.pear/ —— 那是一個只取代單一 bar
按鈕的本地 plugin，不用 fork 整個上游模組。
````

### 想要「膠卷」式的單欄直向排列

````text
hyprexpo 做不到：columns = 1 會畫得出標籤但畫不出縮圖（tile 幾何退化），實測過的。
真正的 niri 式滾動總覽要 yayuuu/hyprland-scroll-overview，
但它沒有 Hyprland 0.56 的 build（pin 停在 0.55.4）。先查它有沒有更新再說。
````

### 背景想要更暗／更亮

````text
hyprexpo 版：改 bg_col。現在是 rgb(0b0c12)。
Quickshell 版：改 MultiEffect 的 brightness，或上面那層 Rectangle 的 opacity。
````

---

## §4 驗收標準

### hyprexpo 版

| 檢查 | 通過條件 |
|---|---|
| `hyprctl configerrors` | 輸出為空 |
| `hyprctl plugin list` | 含 `hyprexpo` |
| `hyprctl workspaces` | 數量 = `desktop_count` |
| `getoption columns/rows/max_workspace` | 等於 `expo_grid()` 算出來的值 |
| `getoption gaps_in/gaps_out/label_font_size` | 等於公式算出來的值 |
| `expo_grid()` 對 n=1..12 | 逐項符合預期表 |
| 改 `desktop_count` 再 reload | 格子、間距、標籤全部跟著變，沒有漏改的地方 |
| 截圖 | 標籤是正常數字（不是 Comic Code 的怪字）、縮圖有圓角、目前桌面邊框較亮 |
| 三指左右滑 | 從第 1 個桌面可以一路滑到最後一個，中途不卡 |
| 重新登入 | overview 仍然叫得出來（`hyprpm reload -n` 那行有效） |

### Quickshell 版

| 檢查 | 通過條件 |
|---|---|
| spike | 明確回報 (1)/(2)/(3) 哪一種，有實際畫面佐證 |
| `hyprctl configerrors` | 輸出為空 |
| QML log | 沒有 error / warning（`Failed to register with host portal` 那行可忽略） |
| 開場 | 一次到位，沒有「先出現內容、背景才模糊」的兩段式 |
| hyprbars | 開關 overview 之後，在有視窗的地方打字，標題列**不會閃爍** |
| 縮圖 | 視窗位置比例正確，空桌面顯示得出來 |
| `expoGrid()` 對 n=1..12 | 逐項符合 §2 的預期表 |
| 切桌面 | 注一個 timer 呼叫 `goToWorkspace(3)`，`hyprctl activeworkspace` 真的變成 3 |
| 跳視窗 | 同樣手法對別的 workspace 上的視窗，focus 真的跳過去（**注意 0x 前綴**） |
| dispatch | 執行後 QML log 裡**沒有** `quickshell.hyprland.ipc` 的 warning |
| 退出 | 選完之後程序自己結束，不是留在背景 |
| toggle | 連按兩次 CTRL+UP：第二次要關掉，不是開第二份 |
| 退場 | 做不出來時 CTRL+UP 仍然是原本的 hyprexpo 行為 |

---

## §5 為什麼這段提示詞要寫這麼細

跟 `hyprbar/PROMPT.md` 同樣的理由：下面每一條都**從文件或原始碼看不出來**，
不寫進去的話，下一次（或下一個 AI）會重踩一遍。

1. **背景模糊是不可能的** —— 這是最重要的一條。`bg_col` 有 alpha 參數、
   `wallpaper_bg` 有這個選項，兩個看起來都「應該會動」，實際上都不會。
   不先擋掉，一定會有人花半小時在這上面。
2. **`hyprctl keyword` 無聲失敗** —— 指令印 `ok`、值卻沒變，害人誤判實驗結果。
   這一條讓我白跑了一輪測試。
3. **`columns = 1` 只畫標籤不畫縮圖** —— 「膠卷式排版」是很自然會想到的需求，
   而失敗的樣子（有標籤沒圖）看起來像別的 bug。
4. **`workspace_swipe_create_new = true` 不是解法** —— 症狀（滑不過去）跟正解
   （persistent workspace）看起來毫無關聯，而且 `true` 會「看起來有效一格」
   然後卡死，比完全無效更容易誤導。
5. **桌面數 = bar 數字數** —— 使用者不會預期釘住桌面會改變 bar 的外觀。
   要先問再做，不要做完才說。
6. **Quickshell 的型別藏在子模組** —— 只 grep 主 `.qmltypes` 會得到
   「這個版本沒有 ScreencopyView」的**錯誤**結論，然後放棄一條其實可行的路。
7. **`HyprlandWorkspace.toplevels` 和 `HyprlandToplevel.wayland`** ——
   不知道這兩個欄位的話，會去自己 parse `hyprctl clients` 再用 title/appId
   做 match，遇到同名視窗就錯。
8. **不要用 compositor blur** —— 這是 Launchpad 踩過的坑，而症狀（hyprbars 閃爍）
   跟原因（全螢幕 layer 的 blur 弄髒了快取）看起來完全無關，
   而且 `new_optimizations = false` 這個「明顯的解法」擋不住。
9. **`MouseArea` 會餓死 `DragHandler`** —— 同樣是 Launchpad 踩過的，
   症狀是手勢完全沒反應，很難聯想到是被同層的 MouseArea 搶走 press。
10. **spike 要排在第 0 步** —— 整個 Quickshell 計畫都押在「抓得到離畫面的視窗」
    這個還沒驗證的假設上。先寫 UI 再發現抓不到，就是幾百行白寫。
11. **要求實跑驗收和截圖** —— 這類設定很容易「看起來對」但執行期的值是舊的，
    特別是在 `hyprctl keyword` 會假裝成功的情況下。
12. **Lua parser 下 dispatch 不吃 `"workspace 3"`** —— 所有文件和範例都是那個寫法，
    而失敗訊息是一行 Lua 語法錯誤，看起來跟「我打錯 dispatcher 名字」完全不像。
13. **`address` 少了 `0x` 只是「點了沒反應」** —— 不會 crash、不會紅字，
    使用者只會覺得這個功能壞了。這種靜默失敗最該寫進提示詞。
14. **變暗的層蓋錯邊、邊框亮度差太小** —— 兩個都是「寫出來自己看不出哪裡怪」
    但並排一比就很明顯的問題。列出來比事後重調便宜。
15. **UI 要靠注 timer 才測得到** —— 不寫的話下一個 AI 只會說「應該可以了」，
    而這份提示詞從第一版就要求「實際跑」。
