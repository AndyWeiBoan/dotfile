# Omarchy 客製化清單

ThinkPad X1 Carbon Gen 9 · Omarchy 4 "Quattro" (Arch + Hyprland)
盤點日期:2026-09-15

主題:把 Omarchy 改造成 macOS 外觀與操作邏輯。

---

## 1. 自製 Omarchy Plugins

全部是 `schemaVersion: 1` 的 QML plugin。**QML 是直譯的,與 CPU 架構無關** —— 除了 omarcat 的 Rust sampler 之外,都能直接在 aarch64(M1)上跑。

| Plugin | ID | 版本 | 類型 | 位置 | Remote |
|---|---|---|---|---|---|
| **Mission Control** | `io.github.andyweiboan.missioncontrol` | 1.0.4 | overlay | 實體目錄 | ✅ [omarchy-mission-control](https://github.com/AndyWeiBoan/omarchy-mission-control) |
| **Launchpad** | `io.github.andyweiboan.launchpad` | 1.1.0 | overlay | → `~/dev/omarchy-launchpad` | ✅ [omarchy-launchpad](https://github.com/AndyWeiBoan/omarchy-launchpad) |
| **Omardock** | `io.github.andyweiboan.omardock` | 0.1.0 | overlay | → `~/dev/omardock` | ✅ [omardock](https://github.com/AndyWeiBoan/omardock) |
| **Omarcat** | `io.github.andyweiboan.omarcat` | 0.1.0 | service + bar-widget | → `~/dev/omarcat` | ✅ [omarcat](https://github.com/AndyWeiBoan/omarcat) |
| **Pear menu button** | `local.pear` | 1.0.0 | bar-widget | 本機 | ❌ 無 |
| **My Notifications** | `andy.notifications` | 1.0.0 | service | 本機 | ❌ 無 |

### 各自在做什麼

- **Mission Control** — macOS 式工作區總覽:上方一排即時桌面縮圖,下方是當前桌面的視窗縮小排列
- **Launchpad** — macOS 式 app 格狀頁面:全螢幕圖示、自己的桌布加模糊、搜尋與頁點
- **Omardock** — macOS 式 dock:磨砂玻璃層架,釘選與執行中的 app。含啟動彈跳動畫、未釘選的執行中 app、內建垃圾桶圖示
- **Omarcat** — Omarchy bar 上的系統監視器,CPU 越忙貓跑越快;另有 iStat Menus 風格的分頁(處理器/記憶體/磁碟/網路)。**含 Rust 寫的 `sampler/`,換架構要重編**

---

## 2. 第三方 Plugin 與你的修改

| Plugin | 作者 | 你改了嗎 |
|---|---|---|
| `omaplug` (Plugin Manager 1.5.1) | Fross | — |
| `crmne.omastats` | crmne | ✅ **有 patch** |
| `io.github.maajix.spotlight` | maajix | ✅ **有 patch** |
| `jankeesvw.notification-center` | jankeesvw | — |
| `io.github.juliusmork-sys.monitor-settings-extender` | juliusmork-sys | — |

### Patch 內容

存在 `~/.config/omarchy/plugin-patches/`:

```
crmne.omastats.patch
crmne.omastats.files/ui/RunCat.qml        ← 替換原本的 RunCat
crmne.omastats.files/ui/frames/*.svg      ← 20 張自製貓咪動畫 frame
                                             (cat_f0_1..5 / f1 / f2 / f3,四組速度)
io.github.maajix.spotlight.patch
```

### `io.github.maajix.spotlight` patch 詳解

上游是 **Spotlight 1.1.4**(Max Randhahn,Raycast 風格命令面板)。你的 patch 把它從 Raycast 改造成 **macOS Spotlight**,共 14 處 `LOCAL EDIT`:

**形狀與動態 —— 最關鍵的三處**

| 改動 | 內容 |
|---|---|
| **藥丸形變** | `radius: hasResults ? cardRadius : height / 2` —— 收合時兩端全圓(現行 macOS Spotlight 的藥丸),有結果才方化成 `cardRadius`;加 `Behavior on radius`(110ms OutCubic)讓它morph |
| **空查詢不顯示任何東西** | 上游一開啟就列出 frecency 排序的 app 清單;改成 `q.length === 0` 直接清空 —— **開啟時只是一顆裸藥丸,打字才展開** |
| **位置固定在上方** | `anchors.verticalCenter` → `y = panel.height * 0.22`。macOS 放在畫面上方而非正中;固定比例還能避免**藥丸隨結果變多而往上爬** |

**尺寸**

```
width        750 → 560     Apple 的藥丸約螢幕三分之一,不是 750
cardRadius    12 → 20
rowRadius      8 → 10
searchHeight  56 → 50      Apple 的藥丸是矮的,不是 hero banner
searchFontSize 1.5 → 1.35  配合變矮的搜尋列
```

**顏色**

| 屬性 | 原 | 改 | 理由 |
|---|---|---|---|
| `glassBackground` | 0.62 | **0.45** | 更透 |
| `scrim` | `menu.scrim` 0.25 | **`"transparent"`** | **macOS Spotlight 不壓暗桌面** —— 藥丸浮在未受影響的畫面上 |
| `selectedBackground` | `foreground` 0.12 | **`accent` 0.85** | Apple 用實心強調色填滿選中列,不是淡灰 |
| `selectedText` | `menu.selectedText` | `#ffffff` | |
| 搜尋圖示 | `foreground` @0.5 | `#ffffff` @0.7 | |
| 輸入文字 | `foreground` | `#ffffff` | |
| placeholder | `foreground` @0.38 | `#ffffff` @**0.75** | 0.38 在磨砂卡片上糊掉了 |

**字型**

```qml
Qt.fontFamilies().indexOf("Inter") >= 0 ? "Inter" : "Noto Sans"
```

> `Style.font.menuFamily` 是系統字型,在這台是 **Comic Code —— 一個等寬字型**。Spotlight 用的是 SF Pro,**Inter 是最接近的免費替代**,沒裝時退回 Noto Sans。

**footer**

有結果才存在(`visible: card.hasResults`,連同它上面的分隔線),所以空狀態真的只剩藥丸。

> 相關:`looknfeel.lua` 裡有 `omarchy-spotlight` 的 layer rule。


管理工具:`~/.local/bin/omarchy-plugin-patches`(自製,2 KB)

> **Spotlight 已納入版控** —— `spotlight/` 有完整模組:patch 本身、layer rule 與
> 按鍵片段、`install.sh` / `verify.sh`,以及不依賴 patch 的 `PROMPT.md`
> (上游改版讓 patch 貼不上去時,靠它重做)。omastats 的 patch 與 20 張貓 SVG
> 仍未納入。

備份:`.local.runcat.bak.20260910144733/`(原始 runcat,5 張 frame)

---

## 3. 自製圖示

放在 `~/.local/share/icons/hicolor/scalable/apps/`,全部手寫 SVG:

| 檔案 | 大小 | 內容 |
|---|---|---|
| `omacalc-macos.svg` | 15 KB | macOS 計算機風格,多層 linearGradient |
| `claude-code.svg` | 4.3 KB | 漸層底板 |
| `launchpad.svg` | 1.4 KB | macOS Launchpad:淺色圓角方塊 + 3×3 格 |

另外 plugin-patches 裡還有 **20 張貓咪 SVG**(見上)。

> 其餘 app 圖示(basecamp / hey / whatsapp / youtube / x / google-* / zoom / discord / forticlient / disk-usage)來自 `/usr/share/icons/hicolor/`,是 **Omarchy 本身或套件附帶的**,不是自製。

---

## 4. App 封裝(26 個 `.desktop`)

位置:`~/.local/share/applications/`

### 4a. Web app 封裝 — `omarchy-launch-webapp`

| 名稱 | URL |
|---|---|
| Basecamp | launchpad.37signals.com |
| Discord | discord.com/channels/@me |
| Google Contacts | contacts.google.com |
| Google Maps | maps.google.com |
| Google Messages | messages.google.com/web/conversations |
| Google Photos | photos.google.com |
| WhatsApp | web.whatsapp.com |
| X | x.com |
| YouTube | youtube.com |

### 4b. Web app handler(有自訂 URL handler)

- **HEY** → `omarchy-webapp-handler-hey %u`
- **Zoom** → `omarchy-webapp-handler-zoom %u`

### 4c. 終端機 TUI 封裝

- **Disk Usage** → `xdg-terminal-exec --app-id=TUI.float -e bash -c "dua i /"`
- **Docker** → `xdg-terminal-exec --app-id=TUI.tile -e omarchy-launch-docker-tui`

### 4d. 自製工具封裝 ⭐

| 名稱 | Exec |
|---|---|
| **Claude Code** | `setsid uwsm-app -- xdg-terminal-exec --app-id=org.omarchy.agent --dir=/home/andy/Work -e claude --permission-mode auto` |
| **Claude Code URL Handler** | `~/.local/bin/claude --handle-uri %u` |
| **Higgstar VPN** | `foot -T higgstar-vpn -e ~/.local/bin/higgstar-vpn` (openfortivpn) |
| **Proxy Browser (higgstar)** | `foot -T proxy-browser-higgstar -e ~/.local/bin/proxy-browser-higgstar` |
| **VNC — Mac (172.16.64.129)** | `remmina -c ~/.local/share/remmina/mac-higgstar.remmina` |
| **VNC Server (wayvnc)** | `~/.local/bin/wayvnc-toggle` |
| **Launchpad** | `omarchy-shell shell toggle io.github.andyweiboan.launchpad "{}"` |

### 4e. 一般應用程式

chromium · foot · imv (圖片) · mpv (影片) · flea (檔案管理) · omacalc (`/usr/bin/omacalc`)

---

## 5. `~/.local/bin` 腳本

### 自製工具

| 腳本 | 大小 | 用途 |
|---|---|---|
| `nwg-dock-guard` | 2.9 KB | **守護 nwg-dock**。nwg-dock-hyprland 在螢幕底緣建 1px hotspot layer 讓 dock 滑出;接上/拔掉螢幕或 Hyprland reload 後 hotspot 會消失而不重建 —— process 還活著但 dock 打不開。這支監看 Hyprland event socket,偵測到 hotspot 不見就重啟 dock |
| `proxy-browser-higgstar` | 3.2 KB | 公司 proxy 瀏覽器 |
| `missioncontrol` | 3.4 KB | Mission Control 啟動器 |
| `omarchy-plugin-patches` | 2.1 KB | plugin patch 套用工具 |
| `launchpad` | 1.8 KB | Launchpad 啟動器 |
| `wayvnc-toggle` | 1.4 KB | VNC server 開關 |
| `higgstar-vpn` | 886 B | openfortivpn 連線 |
| `nwg-dock-guard.bak` | 2.4 KB | 舊版備份 |

### mise wrapper(統一格式,111–154 B)

`claude` `codex` `copilot` `crush` `gemini` `grok` `opencode` `pi` `omp` `hunk` `ghui` `gh` `playwright`

格式一律是:

```bash
#!/bin/bash
export MISE_MINIMUM_RELEASE_AGE=0
mise use -g --quiet "<pkg>" || exit 1
exec mise x "<pkg>" -- "<bin>" "$@"
```

---

## 6. Hyprland 設定 ⚠️ **完全沒有版控**

`~/.config/hypr/`(另有 20+ 個 `.bak.<timestamp>` 備份檔,是逐步調校留下的):

| 檔案 | 大小 | 內容 |
|---|---|---|
| `looknfeel.lua` | 16.9 KB | blur `passes=4 size=9`、**hyprglass**(dock 的液態玻璃)、**dynamic_cursors**(抖動放大)、hyprexpo、工作區 1-9 persistent、`omarchy-spotlight` / `launchpad` (xray) / `omardock` 的 layer rules |
| `input.lua` | 10.8 KB | **全部手勢**、工作區滑動調校、三段捲動速度(見第 7 節) |
| `bindings.lua` | 7.1 KB | 按鍵綁定 |
| `hyprbars.lua` | 6.4 KB | 標題列 |
| `autostart.lua` | 3.8 KB | 登入時 `hyprpm reload -n` 載入外掛 |
| `hyprland.lua` | 1.4 KB | 主設定 |
| `hyprsunset.conf` | 364 B | 色溫 |
| `monitors.lua` | — | 全域 `scale = 2`、`GDK_SCALE=2` |

其他:

| 檔案 | 內容 |
|---|---|
| `~/.config/nwg-dock-hyprland/style.css` | 1.3 KB，dock 外觀。**刻意拿掉 `box-shadow`** —— hyprglass 會把陰影當成有畫到的像素，導致玻璃變成方形光暈 |
| `~/.config/chromium-flags.conf` | VA-API 硬體解碼(已驗證生效) |
| `~/.claude/settings.json` | `CLAUDE_CODE_SCROLL_SPEED` |
| `foot.ini` | `[scrollback] multiplier = 3.0`(與 `scroll_factor` 相乘) |

> 兩套 dock 並存:**nwg-dock-hyprland**(第三方,搭 `nwg-dock-guard` 守護,套了 hyprglass 液態玻璃)與 **omardock**(自製 QML)。

---

## 7. 手勢、游標與捲動調校

### 7a. 觸控板手勢(`input.lua`)

| 手勢 | 動作 | 對應 macOS |
|---|---|---|
| **3 或 4 指上滑** | 開 Mission Control | Mission Control |
| **3 或 4 指下滑** | 關 Mission Control(用 `hide` 不用 toggle) | — |
| **4 指捏合 (pinchin)** | 開/關 Launchpad(等同 `SUPER+A`) | Launchpad |
| **3 指水平滑動** | 切換工作區 | 切換桌面 |
| `SUPER` + 兩指捲動 | 前後切換工作區 | (Omarchy 預設) |

> 三指與四指都綁上下,是因為 macOS 用三指;三指**上下**與三指**水平**不衝突,因為 Hyprland 以 `direction` 區分。

### 7b. 工作區滑動調校

```lua
workspace_swipe_distance      = 300    -- 預設 200 在這觸控板上一抖就飛過去
workspace_swipe_create_new    = false  -- 配合 looknfeel 釘選 1-9 persistent
workspace_swipe_cancel_ratio  = 0.5    -- 過半才生效,猶豫的滑動會彈回
workspace_swipe_direction_lock = true  -- 選定軸向後鎖住,避免斜滑自己打架
workspace_swipe_forever       = false  -- 一次滑一格,macOS 行為
```

> 這些 `gestures.workspace_swipe_*` 在新手勢系統下仍然生效,即使 `workspace_swipe` 布林本身已被移除。

### 7c. ⚠️ 兩個已查證的坑(寫在註解裡,別再花一小時)

**兩指手勢做不到**
- libinput **只對三指以上發出 SWIPE 事件**,兩指永遠是 scroll 或 pinch
- Hyprland 直接拒絕設定:`Gesture will be overshadowed by a previous gesture. Previous HORIZONTAL shadows new HORIZONTAL` —— 它**依方向遮蔽,與指數無關**
- 兩指水平送出的是 horizontal scroll,而 Hyprland 沒有水平軸的 bind(`mouse_up`/`mouse_down` 只有垂直)
- 最接近的替代:`SUPER` + 兩指捲動

**手勢改了要登出重登,不能 reload**
- Hyprland 有已知 bug:手勢會隨機停止作用,`hyprctl reload` **清不掉**
- Lua API **沒有 unset/ungesture**(只有 `hl.unbind` 給按鍵),所以 reload 無法移除本次工作階段中已註冊的手勢
- **改 `input.lua` 後重新載入不是有效的測試方式** —— 必須登出再登入

### 7d. 滑鼠抖動放大(dynamic-cursors,`looknfeel.lua`)

macOS 的「搖晃滑鼠找游標」:

```lua
dynamic_cursors = {
  enabled = true,
  mode    = "none",
  hyprcursor = { resolution = 224 },
  shake = {
    enabled   = true,
    base      = 4.0,    -- 放大倍率
    threshold = 3.0,    -- 外掛預設 6.0 要很用力搖;3.0 一般「咦游標呢」的晃動就觸發
    timeout   = 1000,   -- 外掛預設 2000 太久,找到了還在放大
    effects   = false,
  },
}
```

**關鍵修正 —— `resolution = 224`**

預設值 `-1` 會用 `[cursor size] × [shake:base]` 計算,**這個公式忽略了 monitor scale**。本機面板 scale = 2,所以一般游標本來就佔 `size × 2` 實體像素,4 倍放大需要四倍於此。載入了不足一半的解析度 —— **這就是為什麼放大後的游標反而比沒放大時還小**。

```
resolution = cursor_size × scale × base = 28 × 2 × 4 = 224
```

> 這三個數字任一改變都要重算。

### 7e. 觸控板捲動速度

| 範圍 | 值 | 理由 |
|---|---|---|
| 全域 `touchpad.scroll_factor` | **0.85** | Omarchy 預設 0.4 + `foot.ini` `multiplier = 7.0` 方向相反 —— 0.4 要滑很久才送出一個事件,7.0 讓那個事件一次跳七行。**又費力又跳**。總速度 = factor × multiplier,平滑度 = 1/multiplier,所以拉高 factor、降低 multiplier:`0.85 × 3.0` 總速度接近舊的 `0.4 × 7.0`,但一次只走三行 |
| `org.omarchy.agent` (Claude Code) | **0.8** | 翻閱大量 agent 輸出要比網頁穩;Omarchy 原本用 `o.window("(Alacritty\|kitty\|foot)", ...)` 補償終端機,但這視窗的 app id 是 `org.omarchy.agent`,**匹配不到**,所以吃的是裸的全域值 |
| `chromium` | **0.5** | 網頁一個事件捲動的距離遠大於一行終端機文字 |

**兩者性質不同,別搞混:**
- `scroll_factor` 是**裝置設定** → `hyprctl reload` 會套用到**已開啟**的視窗
- `o.window(..., { scroll_touchpad = ... })` 是**視窗規則** → **不會**影響已開啟的視窗,要重開該 app

> 這裡管不到的:全螢幕 TUI(Claude Code)自己接走捲動事件,捲多遠由 `~/.claude/settings.json` 的 `CLAUDE_CODE_SCROLL_SPEED` 決定,不是這個 factor。

---

## 8. ⚠️ 版控風險

| 專案 | Git | Remote | 風險 |
|---|---|---|---|
| `~/dev/dotfile` | ✅ | ✅ AndyWeiBoan/dotfile | 只有 1 個 `init` commit,僅含 `hyprbar/` `nvim/`;`launchpad/` `mission-control/` 未追蹤 |
| `~/dev/omarchy-launchpad` | ✅ | ✅ | — |
| `~/dev/mission-control` | ✅ | ✅ | — |
| `~/dev/omardock` | ✅ | ✅ AndyWeiBoan/omardock | — (2026-09-15 建立並推送) |
| `~/dev/omarcat` | ✅ | ✅ AndyWeiBoan/omarcat | — (2026-09-15 `git init` 並推送;此前**連 git repo 都不是**) |
| `~/.config/hypr` | ❌ | ❌ | **完全沒版控** |
| `~/.config/omarchy/plugin-patches` | 部分 | 部分 | Spotlight 的 patch 已在 `dotfile/spotlight/`;omastats 的 patch + 20 張貓 SVG **仍沒版控** |
| `~/.local/share/icons/.../apps/*.svg` | ❌ | ❌ | 3 張自製圖示,**沒版控** |
| `~/.local/bin` 自製腳本 | 部分 | 部分 | `omarchy-plugin-patches` 已在 `dotfile/spotlight/tools/`;其餘 7 支 **沒版控** |

---

## 9. 待辦

1. `~/.config/hypr` 納入 dotfile repo(照既有 `install.sh` + `verify.sh` + `config/` 格式)
2. ~~`plugin-patches` 納入版控~~ —— Spotlight 已完成(`spotlight/`);**omastats 的 patch 與 20 張貓 SVG 還沒**
3. 3 張自製 SVG 圖示納入版控
4. `~/.local/bin` 自製腳本納入版控 —— `omarchy-plugin-patches` 已完成,**還有 7 支**(`higgstar-vpn`、`proxy-browser-higgstar`、`wayvnc-toggle`、`nwg-dock-guard`、`launchpad`、`missioncontrol`、`nwg-dock-guard.bak`)
5. 把 `launchpad/` `mission-control/` 從 dotfile 目錄清掉(各自已有 repo)

### 移植到 M1 (Fedora Asahi Remix 44 / aarch64) 時

- QML plugin(Mission Control / Launchpad / Omardock / Pear / Notifications)**可直接用**
- **Omarcat 的 `sampler/` 要為 aarch64 重編**(Rust,可行)
- `omarchy-launch-webapp` 系列 `.desktop` 依賴 Omarchy 指令,**需改寫**
- mise wrapper 可直接用
