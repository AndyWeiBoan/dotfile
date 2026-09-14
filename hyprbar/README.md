# hyprbars — Hyprland 的 macOS 風格標題列

在 Omarchy / Hyprland 上，替每個視窗加上帶三顆紅綠燈按鈕的標題列，
並讓顏色跟著 Omarchy 主題自動連動。

```
┌────────────────────────────────────────────┐
│  ● ● ●            視窗標題                  │  ← hyprbars（38px）
├────────────────────────────────────────────┤
│                                            │
│              視窗內容                       │
└────────────────────────────────────────────┘
```

| 檔案 | 內容 |
|---|---|
| `install.sh` | 安裝腳本，可重複執行；`--rebuild` 只重建外掛 |
| `verify.sh` | 檢查外掛有載入、且顏色真的等於當前主題 |
| `config/hyprbars.lua` | 實際設定檔，安裝到 `~/.config/hypr/hyprbars.lua` |
| `PROMPT.md` | 給 AI 的完整重建提示詞（換機器時用這個） |

---

## 一、為什麼需要裝外掛，不能改 quickshell？

這是最常見的誤解，先講清楚，因為它決定了整個做法。

Omarchy 的 shell 是 **quickshell**（`quickshell -n -p /usr/share/omarchy/shell`），
它負責頂部狀態列、啟動器、通知、鎖屏。這些全都是 **wlr-layer-shell** surface ——
這種 surface 只能錨定在「螢幕」的邊緣或某個區域。

而標題列是 **視窗裝飾（window decoration）**，必須貼在**每一個視窗**的上緣，
跟著視窗移動、縮放、疊放順序走。

Wayland 沒有任何協議讓一個 client 去替別的 client 的視窗畫外框 ——
這是 Wayland 安全模型刻意的設計。server-side decoration 只有 **compositor 本人**能畫，
而 Hyprland 本身沒有內建標題列（`decoration` 區塊只有 border / rounding / shadow / blur）。

所以路只有三條：

1. 改 Hyprland 原始碼重編譯 —— 每次升級都要重來
2. 自己寫一個 compositor plugin
3. 用現成的 plugin

**hyprbars 就是第 2 條的成品**，而且是 hyprwm 官方 `hyprland-plugins` repo 裡的
（跟 borders-plus-plus、hyprfocus 同一包）。它是編進 Hyprland 行程裡的 C++ 外掛，
直接掛在 Hyprland 的 decoration API 上 —— 這是唯一能碰到那一層的方式。

> 理論上可以用 quickshell 硬幹：一直 poll `hyprctl clients`，
> 然後在每個視窗上方蓋一個 layer-shell overlay。
> 但視窗一疊起來 z-order 就爛掉、拖動會延遲、全螢幕會穿幫。實務上不能用。

---

## 二、怎麼安裝的

用 Hyprland 內建的外掛管理器 `hyprpm`。它會**抓取跟當前 Hyprland 版本相符的原始碼、
編譯 headers、再編譯外掛** —— 所以需要完整的 build toolchain。

```bash
# 1. build 相依（Omarchy 大多已有；cpio 最常缺，而且失敗訊息不明顯）
sudo pacman -S --needed base-devel cmake meson ninja cpio git pkgconf

# 2. 為「當前執行中的 Hyprland 版本」建立 headers
hyprpm update

# 3. 加入官方外掛庫
hyprpm add https://github.com/hyprwm/hyprland-plugins

# 4. 啟用 hyprbars
hyprpm enable hyprbars

# 5. 載入
hyprpm reload -n
```

> ⚠️ **本機不是這樣跑的。** hyprpm 的 hyprbars 在這台是**停用**的，實際載入的是
> 自己編的修補版，因為官方版在 Hyprland 0.56 上會閃爍。原因與作法見
> [六、閃爍 Bug 與修補版](#六閃爍-bug-與修補版hyprland-056)。
> 上面這段仍然要做過一次 —— `hyprpm update` 產生的 headers 是自行編譯的前提。


裝完的狀態（本機實際值）：

```
外掛編譯產物   /var/cache/hyprpm/andywei/hyprland-plugins/hyprbars.so
外掛庫狀態     /var/cache/hyprpm/andywei/hyprland-plugins/state.toml
               url = 'https://github.com/hyprwm/hyprland-plugins'
               author = 'hyprwm'
               [hyprbars] enabled = true
Hyprland       0.56.1 (commit 5c9377c1)
```

### 開機自動載入

**`hyprpm` 不會自己在開機時載入外掛。** 沒有這一步，每次登入標題列都會消失，
要手動 `hyprpm reload` 才回來。所以 `~/.config/hypr/autostart.lua` 要加：

```lua
-- Load hyprpm-managed Hyprland plugins (hyprbars) on login.
o.exec_on_start("hyprpm reload -n")
```

### 掛進 Hyprland 設定

`~/.config/hypr/hyprland.lua` 要 require 這個模組，否則設定檔只是躺在硬碟上的死碼：

```lua
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.hyprbars")   -- ← 這行
require("hypr.autostart")
```

### Hyprland 更新之後（重要）

外掛是**針對特定 Hyprland commit 編譯**的。Hyprland 一升級，舊的 `.so` 就拒絕載入，
標題列會無聲消失。每次 `omarchy update` 之後跑：

```bash
./install.sh --rebuild                        # 等同 hyprpm update && hyprpm reload -n
~/dev/hyprland-plugins/rebuild-hyprbars.sh    # 再重編修補版的 hyprbars
```

第二行不能省 —— 修補版是自己編的，`hyprpm update` 不會碰它，而外掛 ABI 是
**綁定 commit** 的，Hyprland 一升級舊的 `.so` 就拒絕載入。

---

## 三、設定了什麼

全部在 `~/.config/hypr/hyprbars.lua`（本 repo 的 `config/hyprbars.lua`）。

### 3.1 版面

```lua
bar_height = 38,
bar_padding = 14,
bar_button_padding = 9,
bar_buttons_alignment = "left",   -- 紅綠燈在左邊，跟 macOS 一樣
bar_text_size = 11,
bar_text_align = "center",
bar_precedence_over_border = true,
icon_on_hover = true,             -- 平常是純色圓點，滑過去才顯示圖示
```

踩過的坑：

- **`bar_padding` / `bar_button_padding` 必須 > 0**，否則按鈕會被算成零寬度，
  整排消失。這個失敗是無聲的，沒有錯誤訊息。
- **`bar_precedence_over_border = true`** 讓標題列畫在視窗邊框**內側**，
  邊框會包住「標題列 + 內容」。設成 false 的話邊框會從中間切斷，很醜。
- **hyprbars 沒有 `bar_color_inactive`** —— 所有視窗共用同一個 bar 顏色，
  沒辦法讓未聚焦視窗的標題列變暗。

### 3.2 顏色跟主題連動

**原本是寫死的**，抄自 catppuccin：

```lua
bar_color = "rgb(1e1e2e)"       -- catppuccin background
["col.text"] = "rgba(bac2deff)" -- catppuccin light_foreground
```

換到 tokyo-night 之後就對不上了。現在改成開檔讀當前主題的調色盤：

```lua
local paths = require("default.hypr.paths")

local function theme_colors()
  local colors = {}
  local file = io.open(paths.state_home .. "/omarchy/current/theme/colors.toml", "r")
  if not file then return colors end
  for line in file:lines() do
    -- colors.toml 是扁平的 `key = "#rrggbb"`，沒有 table 也沒有 array
    local key, hex = line:match('^%s*([%w_]+)%s*=%s*"#(%x%x%x%x%x%x)"')
    if key then
      colors[key] = hex:lower()   -- matte-black 用大寫 "#D35F5F"
    end
  end
  file:close()
  return colors
end
```

**為什麼不需要 hook：** `omarchy theme set` 會改寫
`~/.local/state/omarchy/current/theme/colors.toml`，然後呼叫 `omarchy-restart-hyprctl`
重載 Hyprland 設定；而 Omarchy 的 `bootstrap.lua` 在重載時會把 `hypr.*` 從
`package.loaded` 清掉。所以這個模組會**重新執行、重新讀檔**，顏色自動跟上。

對應關係：

| hyprbars 選項 | 主題欄位 | 理由 |
|---|---|---|
| `bar_color` | `background` | 跟視窗內容同底色，接縫看不出來（macOS 就是這樣） |
| `col.text` | `light_foreground` | 比 `foreground` 暗一階的標題色，六個內建主題都有 |

> `light_foreground` 在 catppuccin 剛好就是 `#bac2de` —— 跟原本寫死的值一模一樣，
> 所以這是**零視覺變化的重構**，只是不再寫死。

### 3.3 三顆按鈕

```lua
-- red = close, yellow = maximize（保留標題列）, green = true fullscreen
hl.plugin.hyprbars.add_button({ bg_color = close_bg, fg_color = close_fg, size = 14, icon = "✘", action = "..." })
hl.plugin.hyprbars.add_button({ bg_color = max_bg,   fg_color = max_fg,   size = 14, icon = "✚", action = "..." })
hl.plugin.hyprbars.add_button({ bg_color = full_bg,  fg_color = full_fg,  size = 14, icon = "⛶", action = "..." })
```

- 按鈕顏色取自主題的 `red` / `yellow` / `green`。
- **`add_button` 每次設定重載都會重建按鈕清單**，所以這段可以無條件執行，
  按鈕不會愈疊愈多。
- 這個 build 的 `hyprctl dispatch` 吃的是 **Lua dispatcher 運算式**，不是傳統參數：
  `hyprctl dispatch 'hl.dsp.window.close()'`

#### 圖示大小的坑

hyprbars **沒有獨立的 icon size 選項**。`size` 只控制圓圈直徑，`bar_text_size` 不影響圖示。
要調圖示大小**只能換字元**。實測墨跡尺寸（裝置 px）：

```
✖ U+2716 = 18    ✘ U+2718 = 12    ✕ U+2715 = 8    × U+00D7 = 8
✚ U+271A = 12    ✛ U+271B = 12    + U+002B 偏下不置中
⛶ U+26F6 = 13    ⤢ U+2922 = 8      = 14
```

現用 `✘ ✚ ⛶` = 12 / 12 / 13，三顆視覺對齊。
另外 **`icon` 不能留空字串**，否則 `icon_on_hover` 沒東西可畫。

#### 圖示顏色是算出來的，不是讀主題

主題色亮度差距很大，固定的深色圖示在暗色按鈕上會完全看不見
（`white` 主題的三顆是 `#2a2a2a` 級的深灰）。

也**不能**用主題的 `foreground` 系列 —— 那些欄位跟著**主題的明暗模式**走，
不是跟著按鈕走。`white` 的 `bright_foreground` 是 `#000000`，
會在近黑的按鈕上畫黑色圖示。

所以圖示顏色**從按鈕自己的顏色推導**：

```lua
local function glyph_for(hex)
  local r, g, b = hex_to_rgb(hex)
  local luminance = 0.299 * r + 0.587 * g + 0.114 * b
  if luminance > 140 then
    r, g, b = r * 0.30, g * 0.30, b * 0.30                          -- 亮按鈕 → 壓深
  else
    r, g, b = r + (255-r)*0.70, g + (255-g)*0.70, b + (255-b)*0.70  -- 暗按鈕 → 提亮
  end
  return string.format("rgb(%02x%02x%02x)", math.floor(r), math.floor(g), math.floor(b))
end
```

停在同一個色相，所以保留了原本的質感（叉叉是深紅色而不是純黑）。
六個內建主題的推導結果：

```
theme         red             yellow          green
catppuccin    f38ba8→482932   f9e2af→4a4334   a6e3a1→314430
gruvbox       ea6962→461f1d   d8a657→40311a   a9b665→32361e
matte-black   d35f5f→f1cfcf   b91c1c→eababa   ffc107→4c3902
rose-pine     b4637a→e8d0d7   ea9d34→462f0f   286983→bed2d9
tokyo-night   f7768e→4a232a   e0af68→43341f   9ece6a→2f3d1f
white         2a2a2a→bfbfbf   4a4a4a→c8c8c8   3a3a3a→c3c3c3
```

---

## 四、已知的取捨

主題的 `red` / `yellow` / `green` 是**終端機調色盤的語意欄位，不是 UI 顏色**。
在某些內建主題下，三顆點會失去「紅綠燈」的辨識度：

| 主題 | 狀況 |
|---|---|
| `white` | 三顆是 `#2a2a2a` / `#4a4a4a` / `#3a3a3a`，肉眼幾乎分不出來 |
| `matte-black` | green 是琥珀色 `#FFC107`，yellow 是暗紅 `#b91c1c` |
| `rose-pine` | green 是藍青色 `#286983` |

位置順序（左到右 = 關閉／最大化／全螢幕）還是能區分，所以這是可接受的取捨。

**要退回固定 macOS 配色**：把 `config/hyprbars.lua` 裡的 `button_colors()` 呼叫拿掉，
直接寫回 `rgb(ff5f57)` / `rgb(febc2e)` / `rgb(28c840)`，
圖示色寫 `rgb(4d0000)` / `rgb(5c3d00)` / `rgb(003d0a)`。

---

## 五、驗證

```bash
./verify.sh
```

它不是看設定檔「長得對不對」，而是把 **Hyprland 執行期回報的值**跟主題檔對照：

```
== theme linkage (gruvbox) ==
  ok  bar_color = #282828  (theme background)
  ok  col.text = #bdae93  (theme light_foreground)
```

按鈕顏色 `hyprctl` 查不到（hyprbars 自己畫的），要從螢幕取樣：

```bash
grim /tmp/s.png && magick /tmp/s.png -crop 200x1+0+113 +repage txt: \
  | grep -oE '#[0-9A-F]{6}' | sort | uniq -c | sort -rn | head
```

實測（gruvbox）：

```
41 #282828   ← bar 底色
20 #E76861   ← 紅（主題 #ea6962）
20 #D5A456   ← 黃（主題 #d8a657）
20 #A7B464   ← 綠（主題 #a9b665）
```

取樣值跟主題值差 ~3/255 是正常的 —— hyprbars 用自己的 shader 畫按鈕圓點，
`bar_color` 走 Hyprland 設定路徑所以完全精確。

---

## 六、閃爍 Bug 與修補版（Hyprland 0.56）

### 症狀

`decoration:rounding` 非 0 **且**有模糊在跑的時候，標題列會閃爍 —— 有時整條變成
實心色塊，有時背景直接透出來。兩者缺一就不會發生。

上游 issue：**[hyprwm/hyprland-plugins#697](https://github.com/hyprwm/hyprland-plugins/issues/697)**
（**OPEN**，回報者 thoastbrot，2026-08-12，不是我們開的）

### 根因

Hyprland 的模糊材質路徑 `CHyprOpenGLImpl::renderTextureWithBlur`
（`src/render/OpenGL.cpp`）會把自己的 alpha-discard 遮罩寫進 stencil buffer，
結尾呼叫 `glStencilMask(0x00)` 而**從未還原**。0.56 起，任何走這條路徑渲染的表面
—— 開了 `ignore_alpha` 的模糊 layer、模糊視窗 —— 都會把 stencil 寫入遮罩留在 0，
交給下一個渲染的東西。

hyprbars 接著用這段遮住視窗圓角：

```cpp
glClearStencil(0);
glClear(GL_STENCIL_BUFFER_BIT);
... renderRect(windowBox) ...
```

寫入遮罩是 0 代表 stencil 寫入被完全停用，所以**這個 clear 和這次 mask draw
都被靜默丟棄**。標題列於是拿**前一個表面的 discard 遮罩**去測試，
`glStencilFunc(GL_NOTEQUAL, 1, -1)` 把它大部分面積拒絕掉，背景就透出來。

> **為什麼是閃爍而不是一直壞：** 某一 frame 裡有沒有模糊表面排在裝飾之前渲染，
> 取決於 damage。所以它時好時壞。

### 修復

在 clear 之前把寫入遮罩拿回來。`barDeco.cpp` 既有的清理區塊本來就會在之後
還原成 `-1`，所以只要加一行：

```cpp
glStencilMask(0xFF);        // ← 加這行

glClearStencil(0);
glClear(GL_STENCIL_BUFFER_BIT);
```

### 這台機器怎麼跑的

| | |
|---|---|
| 原始碼 | `~/dev/hyprland-plugins`，分支 `fix/hyprbars-stencil-mask`，commit `a58ab81` |
| 建置腳本 | `~/dev/hyprland-plugins/rebuild-hyprbars.sh` |
| 產物 | `~/.local/share/hyprbars-patched/hyprbars.so` |
| 載入 | `autostart.lua` 的 `hyprctl plugin load ...`，**不走 hyprpm** |
| hyprpm 的 hyprbars | **停用** —— 兩個絕不能同時載入 |

那份原始碼樹**釘在 hyprpm 為當前 Hyprland 配對的 plugin commit 上**
（見 `hyprpm.toml` 的 `commit_pins`）。`omarchy update` 升級 Hyprland 之後，
要查出新的 pin、把這個分支 rebase 上去，再跑一次 `rebuild-hyprbars.sh`。

`rebuild-hyprbars.sh` 會先 `hyprctl plugin unload` 再覆蓋 —— Hyprland 會把 `.so`
保持 mapped，不先卸載就蓋不掉。

### ⚠️ 尚未送上游

`~/dev/hyprland-plugins` 的 `origin` 指向 **hyprwm 上游本身，不是 fork**，
所以那個 commit 目前哪裡都推不出去。要送 PR 得先 `gh repo fork`。

Issue #697 仍然開著，其他人也在受影響 —— 這個修復值得送出去。

---

## 七、疑難排解

| 症狀 | 原因 / 解法 |
|---|---|
| 登入後標題列不見 | `autostart.lua` 少了 `o.exec_on_start("hyprpm reload -n")` |
| Hyprland 更新後不見 | 外掛要重編：`./install.sh --rebuild` |
| 按鈕整排消失 | `bar_padding` 或 `bar_button_padding` 是 0 |
| 滑過去沒有圖示 | 某顆 `icon` 是空字串 |
| 顏色沒跟著主題換 | `hyprctl reload` 後跑 `./verify.sh` 看哪一項不符 |
| 邊框從標題列中間切過 | `bar_precedence_over_border` 沒設成 true |
| 按鈕愈開愈多 | 不會發生 —— hyprbars 每次重載都重建按鈕清單 |
| `hyprpm update` 編譯失敗 | 缺 build 相依，通常是 `cpio` |
| **標題列閃爍／變成實心色塊** | 官方版的 stencil bug（#697）。要跑修補版 —— 見第六節 |
| Hyprland 升級後標題列又開始閃 | 修補版沒重編，跑 `~/dev/hyprland-plugins/rebuild-hyprbars.sh` |
| 標題列行為詭異、兩套並存 | hyprpm 的 hyprbars 沒停用，和修補版同時載入了 |

```bash
hyprctl plugin list          # 外掛有沒有真的載入
hyprpm list                  # 有沒有 enabled
hyprctl configerrors         # 設定有沒有錯
```
