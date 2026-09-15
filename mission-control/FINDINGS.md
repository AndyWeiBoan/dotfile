# 實驗紀錄

做「macOS Mission Control」時實際試過的東西、結果、和證據。
**這一份的用途是防止重踩** —— 下面每一條都是花時間驗證過的，不要憑直覺推翻。

日期：2026-09-11。環境：Omarchy / Hyprland 0.56（Lua 設定）、Quickshell 0.3.1、
hyprexpo（sandwichfarm fork）、eDP-1 單螢幕 scale 2。

---

## 一、hyprexpo 的背景**不可能**做成模糊

這是整件事的核心結論。目標是讓 overview 的背景像 Launchpad 那樣是一張模糊的桌布，
試了兩條路，**兩條都失敗**。

### 1.1 `bg_col = "rgba(00000000)"`（把背景設成全透明）

想法是：背景透明的話，就可以在底下墊一層 Quickshell 的模糊桌布 layer。

**結果：畫面還是純黑。**

hyprexpo 是 compositor 裡的 render pass，它每一幀都會把整個 monitor 清成自己的
背景色再畫縮圖。「透明」對它來說不是「讓底下透上來」，而是「用一個 alpha=0 的顏色
去清畫面」，清完還是黑的。底下墊什麼都看不到。

證據：`~/.config/hypr/looknfeel.lua` 改成 `rgba(00000000)` → `hyprctl reload` →
`hyprctl getoption plugin:hyprexpo:bg_col` 回報 `int: 0`（確實吃進去了）→ 截圖
仍然是黑底。

### 1.2 `wallpaper_bg = 1`（用桌布當背景）

**結果：完全沒有反應，畫面跟 `wallpaper_bg = 0` 一模一樣。**

原因：這個選項畫的是 **Hyprland 內建的桌布**。Omarchy 的桌布是由一個
**layer-surface client** 畫的（`~/.local/state/omarchy/current/background` 那張圖
是某個 client 在讀），對 compositor 來說那只是一個普通的 layer surface，
hyprexpo 拿不到它的貼圖。

證據：`hyprctl getoption plugin:hyprexpo:wallpaper_bg` 回報 `int: 1`，截圖無變化。

### 1.3 為什麼 Launchpad 可以、hyprexpo 不行

Launchpad（`~/.config/quickshell/launchpad/shell.qml`）是一個**獨立的
Quickshell 程序，擁有自己的 Wayland surface**。它在 QML 裡對一個 `Image` 套
`MultiEffect { blurEnabled: true }`，模糊是在它自己的 surface 裡算的。

hyprexpo 沒有 surface，它是合成器的一段 render code。除非改 plugin 的 C++ 原始碼，
否則沒有插手的餘地。

> **注意**：Launchpad 當初是刻意**不用** compositor blur 的。用 `hl.layer_rule`
> 對一個全螢幕 layer 開 blur，會讓 hyprbars 的標題列每次重繪就閃爍（透明/有色交替），
> 而且 `new_optimizations = false` 也擋不住。所以「在 QML 裡自己模糊」不只是繞路，
> 它本身就是正解。

### 1.4 結論

想要模糊背景，**唯一**的路是不要用 hyprexpo，自己寫一個 Quickshell overview。
那就是 `PROMPT.md` 在講的事。

---

## 二、hyprexpo 可以做到什麼（已調校完成）

背景做不到，但其他部分調得相當好，現況見 `config/hyprexpo.lua`。

| 項目 | 結果 |
|---|---|
| 自適應格子 | ✅ `expo_grid(n)` 從 `desktop_count` 算出 columns/rows |
| 自適應間距 | ✅ `gaps_in = 72/cols`、`gaps_out = gaps_in*2+12` |
| 自適應標籤 | ✅ `label_font_size = 72/cols` |
| 圓角縮圖 | ✅ `tile_rounding = 14` |
| 邊框高亮 | ✅ 目前桌面 / focus / hover 用同一條邊的不同亮度 |
| 背景 | ⚠️ 只能純色，用 `rgb(0b0c12)`（帶藍的近黑） |

自適應對照表（`expo_grid` 的實際輸出，跑過驗證）：

```
n=2   2x1    n=3   3x1    n=4   2x2    n=5   3x2    n=6   3x2
n=7   4x2    n=8   4x2    n=9   3x3    n=10-12  4x3
```

規則：浪費最少格子 → 不准直的比橫的高（螢幕是橫的）→ 欄數上限 4（再多縮圖看不清）
→ 永遠不會是 1 欄。

### 2.1 `columns = 1` 會壞掉

單欄「膠卷」排版：**標籤畫得出來，縮圖畫不出來**。tile 幾何退化。
`expo_grid()` 最後那行 `math.max(2, cols)` 就是為了這個。

### 2.2 這個 build 不能用 `hyprctl keyword`

```
$ hyprctl keyword plugin:hyprexpo:gaps_out 60
keyword can't work with non-legacy parsers. Use eval.
```

Omarchy 用 Lua 設定，`hyprctl keyword` 被擋掉，而且**是無聲失敗** —— 指令回
`ok`，值卻沒變。調參數只能改檔案再 `hyprctl reload`。
（這害我白測了一輪，以為 transparent 沒效果其實是根本沒設進去。）

### 2.3 標籤預設字體會畫出怪字

`label_font_family` 預設 `sans`，在這台機器上會解析到系統字體 **Comic Code**
（等寬），數字造型很特殊，放大到 24px 會看起來像亂碼（"2" 像 "ク"）。
改成 `Noto Sans` + `label_font_bold = 1` 就正常。

### 2.4 怎麼截圖 expo

`grim` **抓得到** expo 的畫面，但有兩個坑：

1. **要等約 2 秒**。expo 有 zoom-out 動畫，太早拍會拍到格子還在放大的中間狀態
   （第一次拍出來像是「只有兩格而且被切掉」，其實是動畫沒跑完）。
2. **關閉 expo 會「選取」游標所在的那一格**，等於把使用者的焦點搬走。
   腳本要先記下原本的 workspace，拍完再 `hl.dsp.focus` 切回去。

可用的腳本在 `tools/shot-expo.sh`。

### 2.5 dispatcher 只吃 `toggle` 和 `select`

`hl.plugin.hyprexpo.expo("off")` 會噴
`hl.dispatch: expected a dispatcher`。從 `.so` 撈字串確認只有這兩個。

---

## 三、桌面數量與 bar 的連動（非 hyprexpo，但同一條線）

### 3.1 workspace 是用到才生出來的

Hyprland 的 workspace 預設是動態的。實際上只有 1 和 2 存在，3–9 不存在。
這會**同時**打壞兩件事：

- 三指滑動切桌面滑不過去（滑不到一個不存在的 workspace）
- hyprexpo 的格子（`max_workspace` / `dynamic_grid = 0` 假設它們都在）

### 3.2 `workspace_swipe_create_new = true` 不是解法

它**最多只生一個**。Hyprland 拒絕在「當前 workspace 是空的」時再生下一個
（否則一直滑就會生出無限個空桌面）。所以從 2 滑到 3（空的）之後，4 就生不出來了。

正解是 `hl.workspace_rule({ workspace = "N", persistent = true })` 把桌面釘住。

### 3.3 桌面數 = bar 上的數字數，沒辦法分開

`/usr/share/omarchy/shell/plugins/bar/widgets/Workspaces.qml`：

```qml
var ids = [1, 2, 3, 4, 5]          // 固定至少這五個
// 然後把所有「存在的」workspace 也加進去
```

只要 workspace 被釘成 persistent，它就一定出現在 bar 上。
（釘 9 個 → bar 出現 9 個數字 → 被打回票，最後定 6 個。）

要桌面多但 bar 數字少，只能 clone 這個 widget 成本地 plugin 去改。

---

## 四、Quickshell 0.3.1 有什麼（給重寫版用）

全部是從 `/usr/lib/qt6/qml/Quickshell/*/。qmltypes` 實際撈出來的，不是猜的。

### 4.1 `Quickshell.Wayland` 底下的隱藏子模組

`Quickshell/Wayland/qmldir` 會 re-export 這些，**但主 `.qmltypes` 裡看不到**，
只 grep 主檔會誤判成「沒有這個 API」：

```
_WlrLayerShell  _ToplevelManagement  _Screencopy
_BackgroundEffect  _IdleInhibitor  _IdleNotify  _ShortcutsInhibitor
```

### 4.2 `ScreencopyView`（`_Screencopy`）— **存在**

```
captureSource : QObject      // 可以是 screen，也可以是 Toplevel
live          : bool
paintCursor   : bool
hasContent    : bool  (readonly)
sourceSize    : QSize (readonly)
captureFrame()
```

### 4.3 `Toplevel`（`_ToplevelManagement`）— **存在**

```
appId title parent activated screens maximized minimized fullscreen
activate() close() fullscreenOn(screen) setRectangle(window, rect)
```

⚠️ **沒有座標/尺寸屬性**。視窗幾何要另外從 Hyprland IPC 拿。

### 4.4 `Quickshell.Hyprland` 的 IPC — 這是關鍵

```
Hyprland.workspaces            -> HyprlandWorkspace[]
Hyprland.toplevels             -> HyprlandToplevel[]
Hyprland.focusedWorkspace / focusedMonitor / activeToplevel
Hyprland.dispatch(request)
Hyprland.refreshWorkspaces() / refreshToplevels() / refreshMonitors()

HyprlandWorkspace : id name active focused urgent hasFullscreen
                    monitor  toplevels  lastIpcObject
HyprlandToplevel  : address handle  wayland  title activated urgent
                    lastIpcObject
HyprlandMonitor   : id name x y width height scale activeWorkspace focused
```

**兩個最重要的欄位：**

- `HyprlandWorkspace.toplevels` —— 直接給你「這個桌面上有哪些視窗」，
  不用自己去 match `hyprctl clients` 的 workspace id。
- `HyprlandToplevel.wayland` —— 就是 4.3 那個 `Toplevel` 物件，
  可以直接餵給 `ScreencopyView.captureSource`。

視窗幾何從 `lastIpcObject` 拿（就是 `hyprctl clients -j` 的那一筆，
含 `at`、`size`、`workspace`、`floating`、`fullscreen`）。

### 4.5 `BackgroundEffect`（`_BackgroundEffect`）— 存在，但**先別用**

```
blurRegion : PendingRegion
```

這是向 compositor 要求「在這塊區域後面做模糊」。看起來很誘人，但這正是
**當初讓 hyprbars 閃爍的那條路**（全螢幕 layer 的 compositor blur）。
Launchpad 最後是用 QML 自己模糊才解決的。

**要用的話必須先驗證不會讓 hyprbars 閃爍**，見 §1.3 的註記。

---

## 五、最大風險 —— 已驗證，**抓得到**

> **`ScreencopyView` 能不能抓到「不在畫面上」的視窗？** → 可以，而且是即時的。
> 完整結果在 §7.1。下面保留當初的推論，因為它解釋了為什麼這件事值得先測。

Mission Control 的整個前提，就是要顯示**其他** workspace 上的視窗。
但在 Wayland 上，不可見的 surface 通常不再產生新的 frame。可能的結果有三種：

1. 抓得到即時內容 → 最好，完整的 macOS 體驗
2. 抓得到最後一張舊畫面（stale frame）→ 可接受，macOS 的縮圖其實也不是即時的
3. 完全抓不到（黑的 / `hasContent` 永遠 false）→ **整個計畫要改方向**

**這件事必須第一個測**，不要先寫 UI。`PROMPT.md` 的 §2 第 0 步就是這個 spike，
以及三種結果各自的 Plan B。**實測結果是 (1)**，見 §7.1。

---

## 六、小結：三條路的取捨

| | hyprexpo（現況） | Quickshell 重寫 | 兩者並存 |
|---|---|---|---|
| 背景模糊 | ❌ 不可能 | ✅ | ✅ |
| 真實視窗內容 | ✅ 合成器直接畫 | ⚠️ 看 §5 的結果 | ✅ |
| 拖拉視窗換桌面 | ✅ 內建 | ❌ 要自己寫 | ✅ |
| 維護成本 | 低（改參數） | 高（幾百行 QML） | 高 |
| 目前狀態 | 裝著，當 fallback | **現行版本** | — |

**結果**：spike 過了（§7.1），Quickshell 版做出來了，CTRL+UP 現在指向它。
hyprexpo 沒有移除 —— plugin 還在、`looknfeel.lua` 的設定還在，隨時可以指回去。


---

## 七、Quickshell 重寫版（2026-09-11 完成）

`~/.config/quickshell/missioncontrol/shell.qml` + `~/.local/bin/missioncontrol`。
下面是寫的過程中真正絆到人的東西。

### 7.1 spike：離畫面的視窗**抓得到**，而且是即時的

最小重現：在 workspace 2 開一個 Chrome，人待在 workspace 1，然後對
`HyprlandToplevel.wayland` 開一個 `ScreencopyView { live: true }`。

```
SPIKE hasContent 55c058e3d1d0 true sourceSize=3792x2178
```

畫出來是 Chrome 當下的內容，不是最後一張舊畫面 —— 就是 `PROMPT.md` 列的三種結果
裡最好的那一種。原因：Hyprland 為了 screencopy 會把 toplevel 單獨算進一個
offscreen buffer，跟它在不在畫面上、有沒有被蓋住都無關。

順帶量到的兩件事：

- `sourceSize` **正好等於**視窗的 `size` 乘 monitor scale（1896x1089 × 2 = 3792x2178）。
  也就是說截到的就是視窗本身，**不含 hyprbars 的標題列**，所以縮圖裡的視窗會比
  真實桌面少一條標題列。
- `ScreencopyView` 會**維持長寬比並置中**，不是拉伸填滿。把它照 `at`/`size` 換算後
  擺好，它自己就會剛好填滿，不用另外處理。

### 7.2 Lua parser 下，IPC 的 dispatch 字串**不是 dispatcher 名稱**

這個最容易中，因為到處的文件和範例都寫 `dispatch("workspace 3")`。

```
Dispatch request "workspace 3" failed with error
  [string "return hl.dispatch(workspace 3)"]:1: ')' expected near '3'
  → Note: dispatch in lua is a shorthand for hl.dispatch(...)
```

Omarchy 用 Lua 設定，所以送進去的字串會被**貼進 `hl.dispatch(...)` 當 Lua 求值**。
`hyprctl dispatch workspace 3` 在這台機器上同樣會失敗。正確寫法：

```lua
hl.dsp.focus({ workspace = "3" })                    -- 切桌面
hl.dsp.focus({ window = "address:0x55c058e3d1d0" })  -- 跳到某個視窗
```

**`hl.dsp.workspace` 不是這個。** 它是一個 table，裡面是 workspace 的*管理*動作
（`rename` / `move`（搬到別的螢幕）/ `change_id` / `toggle_special`）。
「切過去」在 Hyprland 的模型裡屬於 focus。
（要列出有哪些：`hyprctl eval` 可以跑任意 Lua，但不會把 return 值印出來，
要自己 `io.open` 寫到檔案裡。）

Quickshell 有 `Hyprland.usingLua` 可以判斷，所以 shell.qml 兩種語法都留著。

### 7.3 `HyprlandToplevel.address` 沒有 `0x`，dispatcher 要有

`hyprctl clients -j` 給的是 `0x55c058e3d1d0`，Quickshell 的 `address` 屬性是
`55c058e3d1d0`。少了前綴，Hyprland 回 `hl.focus: window not found` ——
**而且點下去只是沒反應**，不會報錯給使用者看。

### 7.4 圓角要用 mask，`clip: true` 只會切出方角

`ScreencopyView` 不是 `Rectangle`，沒有 `radius`。把整格 render 成 texture
再用一個圓角 `Rectangle` 當遮罩：

```qml
Item { layer.enabled: true
       layer.effect: MultiEffect { maskEnabled: true; maskSource: tileMask
                                   maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 } }
Item { id: tileMask; layer.enabled: true; visible: false
       Rectangle { anchors.fill: parent; radius: 14; color: "black" } }
```

### 7.5 變暗的那一層要蓋在縮圖**上面**

第一版把「非當前桌面變暗」的 `Rectangle` 畫在視窗縮圖底下，結果只暗到桌布：
**有視窗的桌面看起來是亮的，空桌面看起來是暗的**，剛好相反。

### 7.6 邊框 0.80 和 0.93 是同一個顏色

肉眼分不出來。改成「選取 0.96 / 當前桌面 0.50 / 其他 0.15」三級才看得出差別。
hover 不另外給一級 —— hover 直接設成選取，這樣鍵盤和滑鼠是同一個狀態。

### 7.7 測法

UI 沒辦法用指令點，所以測的時候把 `shell.qml` 複製一份，注一個
`Timer { interval: 1200; running: true; onTriggered: { root.goToWorkspace(3) } }`
進去，再從外面看 `hyprctl activeworkspace` 有沒有變、程序有沒有自己結束。
`expoGrid()` 也是同一招，注一個 `for (let n=1;n<=12;n++) console.log(...)`。

（注意：測的時候會在使用者的桌面上蓋一層全螢幕 overlay，人如果正在用電腦，
他的點擊會打到你的測試視窗上 —— 第一輪就是這樣，看到一個對不上的
`focusWindow` dispatch，才順手挖出 7.3 那個 bug。）

### 7.8 版面後來改成真正的 macOS 版面（同一天）

第一版是「所有桌面排成 3x2 的大格子」。對照真的 macOS 截圖之後改成兩段式：

- **上方一條 Spaces 列**：所有桌面的小縮圖，標籤在下面，目前桌面邊框最亮。
- **下方**：**目前**桌面的視窗攤開、互不重疊，app 圖示跨在每個視窗的下緣，
  標題在圖示下面。

比例是量 macOS 截圖來的：Spaces 列約螢幕高的 **15.5%**，列裡的縮圖約列高的 **2/3**，
剩下的留給標籤。

兩個設計上的取捨，寫下來免得下次「修」錯方向：

- **下半部永遠是目前桌面，不會跟著滑鼠 hover 別的桌面而換。** macOS 就是這樣，
  而且 hover 預覽會讓整個畫面一直跳。要看別的桌面就直接點過去。
- **Exposé 裡的視窗不套「非選取變暗」。** 大格子版那樣做是對的（那裡桌布是主體），
  但在 Exposé 裡視窗就是內容，把六個裡的五個壓暗會讓整個畫面看起來像關掉了。
  選取只用一圈白框加一點點放大。

### 7.9 退出鍵不能做成 toggle

`CTRL+DOWN` 和三指下滑都是「退出」。如果直接接同一支 toggle 腳本，
**在沒開的時候按下去會把它打開**，那就不是退出鍵了。
腳本因此吃一個 `close` 參數：有開就關，沒開就什麼都不做。

### 7.10 退出鍵為什麼是 compositor 綁定而不是寫在 QML 裡

本來想寫在 QML 的 `Keys.onPressed`（這樣就不會蓋掉終端機裡的 CTRL+DOWN），
但 overview 是**獨佔鍵盤焦點**的 layer，而虛擬鍵盤（`wtype`）按下的修飾鍵
不一定會跟著送到 client，測不出可靠的行為。所以正式的退出是 Hyprland 的
`o.bind("CTRL + DOWN", ...)`，QML 裡那段當保險。
代價：`CTRL+DOWN` 跟 `CTRL+UP` 一樣會蓋掉終端機／nvim 的同一組鍵。

### 7.11 測試腳本會被使用者本人關掉

跑自動測試時 overview 會蓋在使用者的桌面上。人正在用電腦的話，
他會直接把它關掉 —— 於是 `qs` 在 `wtype` 送鍵之前就已經結束了，
log 裡一行按鍵都沒有，看起來像「按鍵處理壞了」。
**先印 `kill -0 $PID` 確認程序還活著再下結論。**

### 7.12 Exposé 不是「把視窗排進格子」，是「把整個桌面等比縮小」

第一版的 Exposé 把 n 個視窗塞進 n 個等分格子，每個視窗縮到剛好填滿自己那一格。
**看起來就是不像 macOS**：小的浮動視窗被放大到跟主視窗一樣大，而且每個視窗都跑到
它原本不在的位置。

真正的作法是**所有視窗共用同一個縮放比**，位置維持在桌面上原本的地方。
macOS 還會把重疊的視窗推開，但**在 Hyprland 上不需要** —— 平鋪本來就不重疊
（浮動視窗會重疊，那就讓它重疊，那本來就是它在的地方）。

量真的 macOS 截圖得到的比例：

| | 佔螢幕 |
|---|---|
| Spaces 列高 | 15.8% |
| 列裡的縮圖高 | 列高的 ~2/3（剩下給標籤） |
| 列下方到最上面那個視窗 | 5.8% |
| 下緣留白（dock） | 10% |
| app 圖示 | 寬的 2.3% |
| 視窗標題 | 寬的 0.85% |

### 7.13 縮放要用「可用區域」，而且定位要對齊視窗不是對齊桌面

拿整個 monitor 矩形去縮，bar 那條空白也會被等比縮進去，結果最上面的視窗離
Spaces 列**多掉了一整條 bar 的距離**，間距比例就跑掉了。

兩件事一起修：

1. **縮放比用 monitor 的 `reserved` 扣掉之後的可用區域算**。
2. **定位對齊「所有視窗的 bounding box」**，不是對齊桌面矩形 ——
   bbox 的頂端永遠落在「Spaces 列下方 5.8%」，水平置中。
   這樣不管 bar 佔多少、視窗在桌面哪裡，間距比例都是固定的。

### 7.14 `reserved` 的單位跟 `width`/`height` 不一樣

`hyprctl monitors -j` 裡：

- `width` / `height` 是**實體像素**（3840x2400），要除以 `scale` 才是邏輯大小
- `reserved` 是**邏輯座標**（`[0, 35, 0, 0]`，就是 bar 的 35 邏輯 px）

同一個 json 物件裡兩種單位。拿 bar 的實際高度對過才確定的。
除錯的話：視窗的 `at` / `size` 跟 `reserved` 同一個座標系，跟 `width`/`height` 不是。

### 7.15 左右方向鍵切桌面要「切了不關」

`goToWorkspace()` 切完就 `Qt.quit()`，那是給「點縮圖」用的。方向鍵要的是
**切過去但留在 overview 裡**，下半部跟著換成那個桌面的視窗，翻完再挑。
所以是另一個函式，不呼叫 `quitSoon`。

換桌面之後 `selected` 要歸零 —— 上一個桌面留下來的 index 在新桌面可能指到空的。
`onWindowsChanged` 裡重設。

## 八、開啟延遲：340ms -> 80ms（常駐化）

每次按 CTRL+UP 都重新跑 `qs`，**從按下到畫面出現要 ~340ms**，肉眼看得出來是在等。

### 8.1 先拆，不要猜

| 量什麼 | 到 layer 真的出現在畫面上 |
|---|---|
| 一個空的 `PanelWindow`（沒圖、沒 screencopy） | **5 ms** |
| 完整版但把桌布 `source` 清空 | **150 ms** |
| 完整版 | **340 ms** |

→ Qt/QML 程序啟動 ~145ms，桌布 ~190ms，**ScreencopyView 幾乎免費**
（340 vs 342ms，而那是抓六個桌面所有視窗）。

### 8.2 `sourceSize` 反而更慢（試了三次都是）

桌布是 5120x2880 的 3.7MB JPEG，「叫 Qt 解碼小一點」看起來是標準答案。實測：

| | 時間 |
|---|---|
| 原樣（無 `sourceSize`） | **341 ms** |
| `sourceSize.width = 螢幕寬/2` | 505 ms |
| 同上，且兩個 Image 用同一個尺寸（想共用 cache） | 496 ms |
| 剛好 1/2（2560）／1/4（1280）／1/8（640） | 320 / 321 / 418 ms（抖動比原樣大） |

Qt 還是要 parse 整張 JPEG，然後**多做一次平滑縮放**，省下來的像素抵不過。
**這條路是死的，不要再試。**

### 8.3 正解是常駐 + IPC（Quickshell 官方 FAQ 也是這樣講）

> Quickshell doesn't come with a command to open or close a window; however, you
> can make your own using IpcHandler... Said functions can change the
> `QsWindow.visible` property of a window, or load/unload it using a LazyLoader.
> —— Quickshell FAQ

做法：`shell.qml` 裡放一個 `IpcHandler { target: "overview" }`，暴露
`toggle/show/hide/state`，`PanelWindow.visible` 綁在一個 `shown` 屬性上。
登入時 `qs -d -p <config>` 起一個常駐程序，之後每次按鍵只是
`qs -p <config> ipc call overview toggle` —— 一次 unix socket 往返。

做一樣東西的人也是這樣做（`Shanu-Kumawat/quickshell-overview`：
`exec-once = qs -c overview` + `qs ipc -c overview call overview toggle`）。

結果：

| | |
|---|---|
| 登入時起常駐（只付一次） | ~410 ms |
| **show** | **75–90 ms** |
| hide | 83–133 ms |
| RSS 常駐 | ~375 MB |
| CPU 隱藏時 | **0.2%** of a core |
| CPU 開著時 | **12.8%** of a core（有視窗在動畫時；Omarchy 自己的 shell 同期是 2.2%） |

隱藏時把 layer surface 拆掉，但 QML tree 和**已解碼的桌布**留著 —— 那就是省下的 190ms。

### 8.4 常駐化帶出來的四個坑

1. **`property bool shown: true` 會在每次登入閃一下整個 overview**。
   config 載入時就顯示，wrapper 的 `hide` 慢一步才到。改成預設 `false`，
   由 wrapper 的冷啟動路徑明確 `show`。
2. **`Qt.quit()` 要全部換成 `setShown(false)`**。漏一個就會在使用者選了某個視窗之後
   把常駐程序殺掉，下一次按鍵又要付 340ms。
3. **開場動畫不能寫在 `Component.onCompleted`**。常駐之後元件只建立一次、顯示很多次，
   寫在 onCompleted 只有第一次會有動畫。改成綁 `shown`，而且 `Behavior` 要
   `enabled: root.shown`，否則關閉時會看到它慢慢縮回去。
4. **顯示前要 `refreshMonitors/Workspaces/Toplevels`**。常駐程序可能已經閒置幾小時，
   而每個縮圖的位置和大小都是從 `lastIpcObject` 算的 —— 視窗在它「沒興趣」的期間被搬過，
   就會畫在錯的地方。三次 socket 往返，都在第一帧之前。

### 8.5 `pgrep -f "qs -p <config>"` 抓不到 daemon

`qs -d -p` 的 cmdline **保留 `-d`**（`qs -d -p /home/.../missioncontrol`），
所以 `qs -p <config>` 這個 pattern 不match。第一版 wrapper 就是這樣判斷「有沒有在跑」，
結論永遠是「沒有」，於是**每次按鍵都在前景再開一個實例**然後卡住。

正解：探活用同一個 socket 問 —— `qs -p <config> ipc call overview state`，
成功就是活著。完全繞開「launch flag 長什麼樣」這個問題。

### 8.6 `live: false` + `captureFrame()` 省 CPU：撤掉了

想讓 Spaces 列的小縮圖只抓一張靜態畫面。**撤掉的理由不是它沒用，是量錯了**：
當初看到的「150% CPU」其實是 **15%**（見 8.7），而且那 15% 是因為被抓的那個桌面上
有個終端機在跑動畫，不是固定成本。

而且 `live: false` 對**離畫面**的 toplevel 抓不抓得到，**沒驗證過** ——
測的時候剛好只剩一個視窗，全在當前桌面。`live: true` 抓離畫面的視窗是量過確定可行的。
沒有實測好處、卻有未驗證風險，所以退回 `live: root.shown`。
要再試的話，**先在別的 workspace 開一個視窗**再測。

### 8.7 `/proc/<pid>/stat` 的 CPU 換算差了 10 倍

utime/stime 的單位是 clock tick，`getconf CLK_TCK` 在這台機器是 **100**（不是 1000）。
N 秒內佔一個核心的百分比 = `delta_ticks / N`，我第一版寫成 `delta*10/N`，
**所有數字都大了 10 倍** —— 一度回報「153% of a core」，實際是 15.3%。
量效能之前先把單位換算跟一個已知的值對過。

### 8.8 量測腳本自己會被自己的 pkill 殺掉

`pkill -f "quickshell/missioncontrol"` 會match**執行這個指令的 shell 自己**
（heredoc 整段都在它的 cmdline 裡），於是腳本還沒寫完就被 SIGTERM（exit 144）。
pattern 要用**展開後**的路徑（`pkill -f -- "$CFG"`），那個字串不會出現在 wrapper 裡。

### 8.9 自動化量測會被使用者本人干擾（7.11 的續集）

overview 是**獨佔鍵盤焦點**的全螢幕 layer。使用者在那幾秒內打字，按鍵會送到 overview ——
數字鍵會切桌面並關閉它。於是「開著時的 CPU」實際上量到的是隱藏狀態，得到 0%。
量測要**在區間頭尾都確認 layer 還在**，不符就丟掉重測。

## 九、改成 macOS 真正的作法：不模糊背景 + 桌面縮小動畫（2026-09-11）

使用者指出：**macOS Mission Control 的背景沒有模糊**，就是完整的真桌面，
上面疊一條 Spaces 列；而且視窗是**從原本的位置和大小「縮小」進去**的。
對照他給的 Catalina 截圖確認無誤 —— 桌布是清晰的。

**全螢幕模糊是這個專案自己發明的，不是它在模仿的那個東西。** 已改掉。

### 9.1 作法

- 背景：`Image` 直接畫桌布，**不套 `MultiEffect`**，上面只蓋一層 `opacity 0.14` 的極淡暗化。
- 動畫：每個視窗有兩組矩形 ——
  - `real` = 它在真桌面上的位置（`at - 螢幕原點`，**scale 1**）。overlay 是 1:1 蓋住螢幕、
    底下的桌布又是真的那張，所以視窗畫在這裡會**剛好蓋在它自己身上**。
  - `target` = overview 裡的位置（同一個縮放比）。
  - 開啟 = 從 `real` 動畫到 `target`。這就是「桌面縮小」的錯覺來源。
- x/y/width/height **四個都要用同一條 easing**，不然視窗會邊縮邊變形。
- Spaces 列從畫面上方滑下來；app 圖示和標題在縮小**結束時才淡入**
  （跟著全尺寸的視窗一起出現會像「視窗長出了一個標籤」）。

### 9.2 它沒有變快（誠實的結果）

使用者猜「換這種作法會比較簡單、效能比較好」。**簡單是真的，變快不是**：

| | show latency | CPU（開著時） |
|---|---|---|
| 全螢幕模糊版 | 82–90 ms | 12.8% |
| 不模糊 + 縮小動畫 | 78–89 ms | 12.6% |

在誤差內。那個模糊是 GPU 的一個 pass，本來就不是瓶頸 ——
瓶頸是 Qt 啟動和 JPEG 解碼（§8.1）。**這個改動的價值是「像 macOS」，不是效能。**

### 9.3 兩段式狀態：`shown` 和 `expanded` 不能合成一個

`shown` 把 surface 叫上來（此時視窗畫在 `real`，看起來跟原本的桌面一模一樣），
`expanded` 才開始縮。合成一個的話，第一帧就已經在 `target`，完全沒有動畫可言。

### 9.4 `expanded` 的觸發**不能用固定延遲**

第一版是 `shown = true` 之後 16ms 翻 `expanded`。實測抓不到動畫：
**layer surface 要 ~80ms 以上才真的被合成出來**，所以 260ms 的縮小動畫有一大段
是在畫面還沒出現的時候跑完的，overview 一出現視窗就已經縮到四分之三了。

正解：`QsWindow` 有 **`backingWindowVisible`**（以及 `backingWindowVisibleChanged`），
那是「真正的 surface 上去了」。用它觸發，再多等一帧讓全尺寸的畫面至少畫出來一次。
另外留一個 400ms 的 fallback timer，萬一那個訊號沒來也不會卡在全尺寸。

### 9.5 `hyprctl layers` 報告 layer 存在 ≠ 畫面已經出現

§8 那個「show 80ms」量的是 **layer 建立**（`hyprctl layers -j` 看得到），
**不是第一帧可見**。實測在 `hyprctl layers` 報告存在之後 70ms 截圖，
畫面上還是原本的桌面（bar 還看得到）。

要量真的「按下到看得到」，得抓一小塊畫面（例如 bar 的一條）連續截圖，
用 `compare -metric AE` 找第一格跟基準不同的。**不要用 layer 的存在當代理指標。**

### 9.6 IPC 函式**不可以叫 `show`**（靜默失敗，最惡劣的一種）

```
$ qs -p <cfg> ipc call overview show
target overview
  function toggle(): void
  ...
$ echo $?
0
```

`qs ipc` 自己的子命令是 **show / call / wait / listen / prop**，它的參數解析器
**在任何位置**看到這些字都會當成子命令。所以 `ipc call overview show` 根本沒送到
物件上，而是印出函式清單然後 **exit 0**。

`hide` / `toggle` / `state` 不是子命令名稱，可以用。開啟的那個函式改叫 **`open`**。

這個 bug 潛伏了一陣子：daemon 的測試大多用 `toggle` 和 `hide`，兩個都正常，
只有 wrapper 的冷啟動路徑和量測腳本用 `show` —— 於是「量不到動畫」看起來像動畫寫錯，
實際上是 overview 從頭到尾沒打開。

### 9.7 關閉動畫期間 `shown` 還是 true

`hide` 是「先 `expanded = false`，260ms 後才 `shown = false`」。所以：

- `state` 在關閉動畫期間仍然回報 `shown` —— 當 liveness 探測沒問題，當 UI 狀態會誤判。
- `toggle` 要看 **`expanded`** 而不是 `shown`，否則在關閉途中按下去會「想關一個正在關的東西」，
  看起來像沒反應。
- `setShown(true)` 在關閉途中要能**重新展開**（先 `collapseThenHide.stop()`），
  不能被「已經 shown 了」的 guard 擋掉。

### 9.8 關閉時沒停掉展開 timer -> `toggle` 整個卡死（真的出過，使用者按不開）

症狀：**`CTRL+UP` 完全沒反應，但 `qs ipc call overview open` 正常。**

原因鏈：

1. 開啟是非同步的 —— `backingWindowVisible` 觸發一個 timer，它晚一點才把
   `expanded` 設成 true。
2. 關閉是「先 `expanded = false`，260ms 後才 `shown = false`」。
3. 那個還沒觸發的展開 timer 原本的守衛是 `if (root.shown)` ——
   **而關閉動畫期間 `shown` 還是 true**，所以它照樣把 `expanded` 設回 true。
4. 260ms 到了，`shown = false`，但 **`expanded` 卡在 true**。
5. `toggle` 讀 `!expanded` = false → 去「關」一個已經關掉的 overview → 沒反應。永久。

**教訓：非同步開啟的守衛不能用「現在的顯示狀態」，要用「使用者要的狀態」。**
加一個 `wantOpen` 屬性記錄意圖，所有展開 timer 改看它，關閉時明確
`expandFallback.stop()`，而且已隱藏時再收到 close 要順手把 `expanded` 歸零自我修復。
`toggle` 也改成看 `wantOpen` —— 動畫中途 `shown` 和 `expanded` 都答不出
「這東西該是開還是關」。

**驗收方式**（只測 `open` 會漏掉這個 bug，要測 wrapper 實際走的那條路）：
連續 8 次 toggle 開關、3 次「開了馬上關」的快速連按（每次之後都要能再開起來）、
以及對已關閉的 overview 再 close 一次。

## 十、關閉閃爍：QtQuick 的 opacity 不是群組透明（2026-09-11）

使用者回報關閉時會閃。修了兩輪，第一輪修錯方向、第二輪才對，過程值得完整留下。

### 10.1 先建立「閃爍」的量化定義

`grim` 截一張 3840x2400 要 ~500ms，**比 260ms 的動畫還久**，根本抓不到中間格。
改成錄影再拆格：

```
gpu-screen-recorder -w eDP-1 -f 60 -q ultra -cursor no -o close.mp4
ffmpeg -sseof -2.6 -i close.mp4 -vf "fps=60,scale=640:-1" f%03d.png
magick f001.png -colorspace Gray -format "%[fx:mean]" info:     # 每格平均亮度
```

**驗收標準：關閉過程的平均亮度必須單調下降。** 中間凸起來就是在閃。
這把「閃爍」從一句形容變成一個可以比較的數字，是整段除錯的轉折點。

### 10.2 第一輪：猜錯了（以為是 bar）

推論是「overlay 蓋住 bar，關閉時 bar 要重新出現」。於是讓 overlay 不要蓋住那 35px
（`margins.top` = monitor 的 `reserved`，桌布補 `y: -topInset` 才不會偏移）。
**使用者直接說跟 bar 無關，已撤掉。**

順帶一個確實有用的副產品：bar 在 **level 2 (Top)**，我們在 **level 3 (Overlay)**，
所以預設就是蓋過去的。真的想留 bar 的話這條路可行（而且 macOS 的 menu bar 在
Mission Control 時也是留著的），只是它不是閃爍的原因。

### 10.3 第二輪：使用者的觀察才是對的

他說「好像跟關閉螢幕列的時機有關，那個區塊好像又做了一次重新渲染」。
確實：那條區域**變了兩次** —— 列先滑走露出我們畫的桌布，surface 撤掉時同一塊又
換成真桌面。改成「列進來之後就不走」（`stripDeployed` latch），
由收尾的淡出一次帶走。

**還是閃，而且閃法不一樣了** —— 因為淡出本身就是新的閃爍源。

### 10.4 真正的原因：淡出自己造成的亮度凸起

錄影拆格量到：

```
overview 開著      0.2084
視窗縮回去         0.1962 -> 0.1478    變暗，正常
★ 中間 ~130ms      0.1600 -> 0.1803    又變亮   <-- 就是這裡
最後               0.1624 -> 0.1422    再變暗
```

那 130ms **正好等於 `fadeDuration`**。

原因：**QtQuick 的 `opacity` 是逐個子項各自繼承，不是群組透明。**
分別對「桌布 Image」「暗化 Rectangle」「stage」設 opacity 動畫，等於讓
**暗色的視窗縮圖和亮色的桌布以同樣速率變透明** —— 桌布就從半透明的視窗底下透出來，
畫面在「淡向全無」的中途反而變亮。

（在 QML 裡把它們包進一個父 Item 再對父 Item 設 opacity **也一樣沒用**，
父項的 opacity 同樣是乘進每個子項。要真的群組透明必須 `layer.enabled: true`
把整棵子樹先畫進 texture，代價是一張全螢幕 FBO。）

### 10.5 正解：`HyprlandWindow.opacity`（合成器層級的整層透明度）

`Quickshell.Hyprland` 有一個 **attached type** `HyprlandWindow`，帶 `opacity`：

```qml
PanelWindow {
    HyprlandWindow.opacity: root.contentOpacity   // 0..1
}
```

合成器會**先把我們這層合成完、再整體混合**，這才是「群組透明」的正確語意；
而且不用多一張全螢幕 FBO，比 `layer.enabled` 便宜。

動畫方式：綁到 root 的一個 `real` 屬性，在那個屬性上放 `Behavior`，
attached property 跟著 binding 走（直接對 attached property 下 Behavior 不可靠）。

**修好後的量測：**

| | 關閉過程最大正向亮度跳動 |
|---|---|
| 逐項 opacity（壞的） | **+0.0325** |
| `HyprlandWindow.opacity`（好的） | **+0.0002**（雜訊級） |

差 160 倍，曲線全程單調下降。

### 10.6 教訓

1. **「閃爍」這種主觀症狀要先想辦法變成數字**，否則每一輪都是猜。
   這個案子的數字是「逐格平均亮度必須單調」。
2. **不要相信自己對原因的第一個推論。** 我猜 bar、猜錯；使用者指出是螢幕列的時機，
   對；但真正的機制又比他說的更下一層（是淡出的合成方式）。三層都不一樣。
3. **加一個效果去修另一個效果，很容易製造新的症狀。** 淡出是為了修閃爍加的，
   結果它自己就是閃爍。使用者說「閃法變了」就是這個訊號。

## 十一、手勢：`hyprctl reload` 不能用來測手勢（Hyprland 上游 bug）

使用者回報「二指/三指左右滑切桌面失效了」，而且在我把新加的手勢移除之後**還是沒效**。

### 11.1 我第一個判斷是錯的

我推論成「同一個手指數不同方向會衝突，先註冊的贏」，於是把三指上/下移掉。
**使用者說他記得三指是可以並存的 —— 他對。** `direction` 本來就是 gesture spec 的
一部分，軸向足以區分；而且移除之後症狀沒變，等於直接否證了我的推論。

我還把那個推測**寫進註解當成事實**，那是不該做的事。已改正。

### 11.2 真正的原因：上游的 bug

`hyprwm/Hyprland` discussion #12086：

> 3 finger swipe gestures to them just randomly stop and **hyprctl reload or
> nothing resets it till reboots**.

症狀對得上得可怕：鍵盤切桌面正常、手勢切桌面「會動一點但放手就彈回去」、
右鍵也會失去反應、`hyprctl workspace` 指令正常。**目前無解，只能重啟。**
多人可重現、已確認是 bug，根因未知。

### 11.3 所以：不要用「改檔案 + `hyprctl reload`」來測手勢

而且 Lua API **沒有 unset/ungesture**（只有按鍵的 `hl.unbind`），
所以 reload **無法移除**本次 session 早先註冊過的手勢 —— 檔案裡刪掉了，
執行中的 compositor 裡還在。

這一條讓整段除錯歪掉：我這次為了測試 reload 了十幾次，很可能就是觸發條件；
而在那之後，任何「改設定再 reload」的驗證都是無效的，因為舊註冊還留著。

**測手勢只有一個有效方法：登出再登入。**

### 11.4 可以先試的補救（不用重登）

`omarchy restart trackpad` —— 它 unbind/rebind `i2c_hid_acpi` 驅動（需要 sudo）。
上游那份 discussion 提到**右鍵也會一起失效**，這暗示問題在 input device 那一側
而不是純粹在 Hyprland 的手勢表，所以重綁驅動有機會救回來。
不行的話才需要登出。

### 11.5 兩指左右滑切桌面：**做不到**（三層原因）

使用者從一開始講的就是「二指」，而我一直把它當成三指那條在處理 —— 這是我沒問清楚，
白繞了好幾輪。他要的是**不按任何修飾鍵、純兩指左右滑切桌面**。做不到，三個獨立的原因：

1. **libinput 只對三指以上發出 SWIPE 手勢。** 兩指永遠是 scroll（或 pinch），
   根本沒有「兩指 swipe」這個事件可以綁。
2. **Hyprland 直接拒絕這個設定**（這是最快的檢查方式，加完 `hyprctl configerrors` 就看得到）：
   ```
   hl.gesture: Gesture will be overshadowed by a previous gesture.
   Previous HORIZONTAL shadows new HORIZONTAL
   ```
   → 它是**按 direction 判斷遮蔽，跟手指數無關**。
   **順帶否證了 §11.1 我那個錯誤推論**：三指 up 和三指 horizontal **不會**互相遮蔽
   （方向不同），配置也不報錯 —— 使用者記得的沒錯。
3. 兩指水平在系統裡是**水平 scroll**，而 Hyprland **沒有水平滾動軸的 bind**
   （`mouse_up`/`mouse_down` 是垂直的）。

**最接近的可用方案**：`SUPER + 兩指滾動` —— Omarchy 預設就綁了
（`bindings.lua` 的 "Scroll active workspace forward/backward"，實測動作正常）。

真要做無修飾鍵的兩指切桌面，只能自己寫一個讀 libinput 原始事件的 daemon，
而且會把全系統的水平滾動吃掉（Chrome 左右滾、終端機寬輸出）。不建議。

**教訓：加手勢之後一定要看 `hyprctl configerrors`。** Hyprland 會明確告訴你遮蔽關係，
第一輪如果就看了，§11.1 那個錯誤推論根本不會產生。
