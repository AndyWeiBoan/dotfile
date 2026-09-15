# mission-control — macOS 風格的工作區總覽

在 Omarchy / Hyprland 上，用 `CTRL+UP`（或三指／四指上滑）叫出 macOS Mission Control：
**上方一條 Spaces 列**放所有桌面的縮圖，**下方是目前桌面**的視窗 ——
背景是**清晰的真桌面**（macOS 不模糊它），視窗會從自己原本的位置**縮小**進去，
每個底下掛著 app 圖示和標題。

```
┌──────────────────────────────────────────────────────────┐
│  ┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌────┐          │ ← Spaces 列
│  │ 1  │  │ 2  │  │ 3  │  │ 4  │  │ 5  │  │ 6  │          │   目前桌面邊框最亮
│  └────┘  └────┘  └────┘  └────┘  └────┘  └────┘          │
├──────────────────────────────────────────────────────────┤
│        ┌──────────────┐      ┌──────────────┐            │
│        │              │      │              │            │ ← 目前桌面的視窗
│        │    終端機     │      │    瀏覽器     │            │   攤開、互不重疊
│        └──────●───────┘      └──────●───────┘            │
│            終端機標題            瀏覽器標題                  │ ← 圖示跨在下緣
└──────────────────────────────────────────────────────────┘
        背景：清晰的真桌布（macOS 不模糊它）+ 一層極淡的暗化
```

| 操作 | 動作 |
|---|---|
| `CTRL+UP` / 三指或四指上滑 | 開關（IPC toggle，~80ms） |
| `CTRL+DOWN` / 三指或四指下滑 | **只退出**，不會反過來打開 |
| 點上方縮圖 | 切到那個桌面 |
| 點下方視窗 | 直接跳到那個視窗 |
| 方向鍵 ←→ | **切到上／下一個桌面，但不關掉** —— 下半部跟著換，可以翻完再挑 |
| 方向鍵 ↑↓ / Tab | 在攤開的視窗之間移動 |
| `Enter` | 跳到選取的視窗 |
| `1`–`9` | 直接跳到第 n 個桌面 |
| `Esc` / 點背景 | 關掉 |

| 檔案 | 內容 |
|---|---|
| `config/missioncontrol.qml` | **現行版本**，貼到 `~/.config/quickshell/missioncontrol/shell.qml` |
| `tools/missioncontrol` | wrapper，貼到 `~/.local/bin/missioncontrol`（吃 `daemon` / `close`） |
| `config/autostart-snippet.lua` | 貼進 `~/.config/hypr/autostart.lua`，登入時起常駐程序 |
| `config/hyprexpo.lua` | **舊版 fallback**（hyprexpo plugin）的設定，留著備查 |
| `tools/shot-expo.sh` | 截 hyprexpo 畫面的輔助腳本（Quickshell 版不需要） |
| `PROMPT.md` | 給 AI 的重建提示詞。§1 = hyprexpo 版，§2 = Quickshell 版 |
| `FINDINGS.md` | **實驗紀錄：試過什麼、為什麼失敗。動手前先讀這個。** |

沒有 `install.sh` —— 這是三個檔案加幾行設定，自動化反而更容易出錯。
安裝步驟在 `PROMPT.md` §2 最後。

---

## 〇、它是常駐程序，不是每次重開

**這點會影響你怎麼改它。** 登入時 `autostart.lua` 起一個 `qs -d -p …`，
之後每次按 CTRL+UP 只是對它 `qs … ipc call overview toggle`。

原因是延遲。每次重開 `qs` 從按下到畫面出現 **~340ms**，看得出來在等：

| | 到畫面出現 |
|---|---|
| 一個空的 layer surface | 5 ms |
| 完整版但不載桌布 | 150 ms |
| 完整版（每次重開） | **340 ms** |
| **常駐 + IPC** | **75–90 ms** |

也就是 Qt/QML 啟動 ~145ms + 解那張 5K 桌布 ~190ms，兩個都是**每次重開都要付**的。
（`sourceSize` 想叫 Qt 解碼小一點 —— 試了三種尺寸，**每一種都更慢**，見
`FINDINGS.md` §8.2。不要再試。）

常駐的代價：**RSS ~375 MB**。隱藏時 CPU **0.2%**，開著時 **12.8%**
（有視窗在動畫的情況；Omarchy 自己的 shell 同期是 2.2%）。

這也是 Quickshell 官方 FAQ 的建議做法 —— 它刻意不提供「開關視窗」的指令，
要你自己用 `IpcHandler` 去改 `visible`。

> 改 QML 的時候記得：**不要用 `Qt.quit()`**，那會把常駐程序殺掉，
> 下一次按鍵就又要付 340ms。一律 `root.setShown(false)`。

---

## 一、為什麼不是 hyprexpo

**唯一的理由是背景。** hyprexpo 其他方面都很好（拖拉視窗換桌面甚至是免費的），
但它的背景**只能是純色** —— 而 macOS 的背景是**你原本的桌面**，視窗從原位縮小進去。
純色背景做不到那件事。

這不是參數沒調對，是架構決定的。完整證據在 `FINDINGS.md` §1，結論：

- hyprexpo 是 **compositor 裡的一段 render pass，沒有自己的 surface**。
  它每一幀把整個 monitor 清成 `bg_col`，所以「透明的 bg_col」不是讓底下透上來，
  而是用 alpha=0 的顏色清畫面 —— 底下墊什麼都看不到。
- `wallpaper_bg = 1` 畫的是 Hyprland **內建**桌布；Omarchy 的桌布是一個
  layer-surface client 畫的，plugin 拿不到它的貼圖。

Quickshell 版是**獨立程序、擁有自己的 surface**，所以可以自己畫桌布，
並且把視窗畫在「它本來的位置」再動畫縮小。

> **不要加 compositor blur**（`hl.layer_rule({ blur = true })`，或 Quickshell 的
> `BackgroundEffect`，那是同一件事）。會讓 hyprbars 的標題列每次重繪就閃爍，
> 而且 `new_optimizations = false` 擋不住。這是 Launchpad 踩過的坑。
>
> 也**不要加 QML 裡的全螢幕模糊** —— 早期版本這樣做過，但那是本專案自己發明的，
> macOS 並沒有模糊桌面。而且實測**拿掉之後既沒變快也沒變慢**
> （82–90ms → 78–89ms，CPU 12.8% → 12.6%，見 `FINDINGS.md` §9.2），
> 所以改掉純粹是為了像 macOS。

**hyprexpo 沒有移除**，plugin 還裝著、設定還在 `looknfeel.lua`。
要換回去只要把 `bindings.lua` 的 CTRL+UP 和 `input.lua` 的上滑手勢指回
`hl.plugin.hyprexpo.expo("toggle")`，兩個檔案裡都有註解寫怎麼改。

---

## 二、現況：能做到什麼

| | 狀態 |
|---|---|
| 清晰的真桌面背景 + 視窗縮小動畫 | ✅ 跟 macOS 一致 |
| 上方 Spaces 列 + 下方視窗 Exposé | ✅ 照 macOS 的版面 |
| 真實的視窗內容縮圖 | ✅ 即時，連「不在畫面上」的桌面也是 |
| app 圖示 + 視窗標題 | ✅ 圖示跨在視窗下緣，標題在下面 |
| 點桌面切換 / 點視窗直接跳過去 | ✅ |
| 鍵盤導覽（方向鍵、1–9、Enter、Esc、CTRL+DOWN） | ✅ |
| 拖拉視窗換桌面 | ❌ hyprexpo 有，這版沒有（要自己實作 drag + `movetoworkspace`） |
| 看「別的桌面」有哪些視窗的大圖 | ❌ 跟 macOS 一樣，下半部永遠是**目前**桌面 |

**「不在畫面上的視窗抓不抓得到」是整個計畫的前提，動工前先驗證過了**：
抓得到，而且是即時的，不是最後一張舊畫面。Hyprland 為了 screencopy 會把 toplevel
單獨算進一個 offscreen buffer，跟它在不在畫面上無關。

---

## 三、版面是怎麼算的

沒有任何寫死的像素值，全部從螢幕尺寸和數量推導。

**Spaces 列**（比例是量真的 macOS 截圖來的）：

```js
stripH      = 螢幕高 * 0.155      // 整條列（量 macOS 是 15.8%）
stripTileH  = min(stripH - 標籤高 - 內距*2,     // 桌面少 -> 被列高卡住
                  可用寬 / 桌面數 * (高/寬))     // 桌面多 -> 被寬度卡住
stripTileW  = stripTileH * 螢幕長寬比            // 縮圖永遠是螢幕的縮小版
```

**下半部的 Exposé**：**不是**把視窗排進格子，是把**整個桌面用同一個縮放比縮小**，
視窗維持在它原本的位置和相對大小 —— 這才是 macOS 的作法，也才看得出「這是我的桌面，
只是變小了」。排進格子會把小浮動視窗放大到跟主視窗一樣，而且每個都跑錯位置。

**而且它是動畫出來的。** 每個視窗有兩組矩形：`real`（在真桌面上的位置，scale 1，
overlay 是 1:1 蓋住螢幕、底下桌布又是真的那張，所以剛好蓋在它自己身上）和
`target`（overview 裡的位置）。開啟就是 `real` → `target`，關閉反過來。

> 觸發時機**不能用固定延遲** —— layer surface 要 ~80ms 以上才真的被合成出來，
> 用 16ms 的 timer 會讓動畫在畫面出現前就跑掉大半。要用 `QsWindow` 的
> **`backingWindowVisible`**。見 `FINDINGS.md` §9.4。

```js
縮放比 = min(可用寬 / 桌面可用寬, 可用高 / 桌面可用高)
```

兩個細節：

- **縮放比要用「可用區域」算**（monitor 的 `reserved` 扣掉 bar 之後），
  不然 bar 那條空白也被等比縮進去，視窗會離 Spaces 列多掉一整條 bar 的距離。
- **定位對齊「所有視窗的 bounding box」**，不是對齊桌面矩形。bbox 的頂端永遠落在
  「Spaces 列下方 5.8%」，水平置中 —— 這樣不管 bar 佔多少，間距比例都是固定的。

macOS 還會把重疊的視窗推開，這裡不用：Hyprland 是平鋪的，本來就不重疊。
（浮動視窗會重疊，那就讓它重疊，那本來就是它在的地方。）

---

## 四、桌面數量會連動到 bar

**這件事沒辦法分開，改數量之前要知道。**

Hyprland 的 workspace 是用到才生出來的，所以桌面必須釘成 `persistent`
才會全部存在（否則 Spaces 列會有洞、三指滑動也會卡）。而 Omarchy 的
`shell/plugins/bar/widgets/Workspaces.qml` 是這樣寫的：

```qml
var ids = [1, 2, 3, 4, 5]          // 固定至少這五個
// 然後把所有「存在的」workspace 也加進去
```

→ **釘幾個桌面，bar 上就會出現幾個數字。** 釘 9 個就是 9 個數字。

要分開只能 clone 這個 widget 成本地 plugin 再改 `workspaceIds()`，
做法參考 `~/.config/omarchy/plugins/local.pear/`。

---

## 五、相關設定

這個 overview 跟「三指滑動切桌面」是同一條線上的東西：

- `~/.config/hypr/bindings.lua` — `CTRL+UP` 開關、`CTRL+DOWN` 退出
- `~/.config/hypr/input.lua` — 三指左右滑切桌面、三／四指上下滑開關 overview
- `~/.config/hypr/looknfeel.lua` — 1–6 的 `persistent` 規則、workspace 滑動動畫
  （Omarchy 預設把這個動畫**關掉**，沒有它切桌面是瞬間硬跳）、
  以及留著備用的 hyprexpo 設定

> `CTRL+UP` / `CTRL+DOWN` 是**全域**綁定，會蓋掉終端機和 nvim 裡的同一組鍵。
> 會礙事的話改成 `SUPER + UP/DOWN`（記得先 `hl.unbind("SUPER + UP")`）。
