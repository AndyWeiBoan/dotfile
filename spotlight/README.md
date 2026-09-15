# Spotlight — Raycast 風格改造成 macOS Spotlight

這**不是我們寫的外掛**。上游是 Max Randhahn 的
[io.github.maajix.spotlight](https://github.com/maajix/omarchy-spotlight)
（1.1.4），一個 Raycast 風格的命令面板。我們只改它的外觀。

```
上游（Raycast）                    改造後（macOS）
┌──────────────────────────────┐   ╭──────────────────────╮
│ 🔍 Search…            750px  │   │ 🔍 Search…     560px │  ← 收合＝全圓藥丸
├──────────────────────────────┤   ╰──────────────────────╯     打字才展開
│ Firefox                      │
│ Terminal          一開就列    │   桌面不壓暗，藥丸固定在
│ Settings          frecency   │   畫面上方 22% 處
└──────────────────────────────┘
```

| 檔案 | 內容 |
|---|---|
| `PROMPT.md` | **給 AI 的完整重建提示詞** —— 換機器或上游改版時用這個，不依賴 patch |
| `install.sh` | 裝外掛 + 貼 patch + 裝重貼工具，可重複執行 |
| `verify.sh` | 驗證改造真的生效（查執行期狀態，不是查檔案長相） |
| `config/io.github.maajix.spotlight.patch` | 對 `Spotlight.qml` 的 14 處改動 |
| `config/looknfeel-snippet.lua` | 磨砂玻璃的 layer rule |
| `config/bindings-snippet.lua` | `SUPER+SPACE` 等按鍵 |
| `tools/omarchy-plugin-patches` | 更新後重貼 patch 的工具（通用，不只 Spotlight） |

---

## 一、為什麼是 patch，不是 fork

外掛裝在 `~/.config/omarchy/plugins/<id>/`，每個都是一個 git 工作目錄。
`omarchy plugin update` 會把上游**直接蓋在工作目錄上**，本地編輯全部消失。

Fork 一份自己維護是另一條路，但代價是每次上游修 bug 都要自己合併 —— 我們要的只是
外觀，邏輯完全採用上游的。所以改動存成 patch，更新後重貼：

```bash
omarchy plugin update
omarchy-plugin-patches          # 重貼所有 plugin-patches/*.patch
```

`omarchy-plugin-patches` 會先 `git apply --reverse --check` 判斷是否已套用，
所以重複跑是安全的。上游動到同一段時會印 `FAILED ... upstream moved`，
那時候就要靠 `PROMPT.md` 手工重做，再 `git diff` 重錄一份 patch。

> 這支工具是通用的，不是為 Spotlight 寫的。它還支援 `<id>.files/` 放**全新檔案**
> ——`git diff` 看不到未追蹤的檔案，omastats 那 100 張跑者 SVG 就是靠這個回來的。

---

## 二、改了哪 14 處

全部在 `Spotlight.qml`（1843 行）裡，每一處都標了 `// LOCAL EDIT:`。

### 2.1 形狀與動態 —— 關鍵的三處

| 改動 | 內容 |
|---|---|
| **藥丸形變** | `radius: hasResults ? cardRadius : height / 2`。收合時兩端全圓，有結果才方化成 `cardRadius`；`Behavior on radius`（110ms OutCubic）讓它 morph |
| **空查詢不顯示任何東西** | `rebuild()` 開頭 `if (q.length === 0)` 直接清空並 return。上游一開啟就列 frecency 排序的 app 清單 |
| **位置固定在上方** | `anchors.verticalCenter` → `y = panel.height * 0.22` |

固定 `y` 不只是為了模仿 macOS 的位置，還順便解掉一個問題：置中的話**藥丸會隨著
結果變多而往上爬**。固定之後它開在哪就在哪，只往下長。

「空查詢什麼都不顯示」看起來是一處改動，實際上是三處：`rebuild()` 的早退、
footer 與其分隔線的 `visible: card.hasResults`，以及 card 的 `height` 算式裡
footer 那一項也要條件化。漏掉後兩者，空狀態會是一顆藥丸下面吊著一條空白。

### 2.2 尺寸

```
width          750 → 560     Apple 的藥丸約螢幕三分之一，不是 750
cardRadius      12 → 20
rowRadius        8 → 10
searchHeight    56 → 50      Apple 的藥丸是矮的，不是 hero banner
searchFontSize 1.5 → 1.35    配合變矮的搜尋列
```

### 2.3 顏色

| 屬性 | 原 | 改 | 理由 |
|---|---|---|---|
| `glassBackground` | 0.62 | **0.45** | 更透 |
| `scrim` | `menu.scrim` 0.25 | **`"transparent"`** | **macOS Spotlight 不壓暗桌面** |
| `selectedBackground` | `foreground` 0.12 | **`accent` 0.85** | Apple 用實心強調色填滿選中列 |
| `selectedText` | `menu.selectedText` | `#ffffff` | |
| 搜尋圖示 | `foreground` @0.5 | `#ffffff` @0.7 | |
| 輸入文字 | `foreground` | `#ffffff` | |
| placeholder | `foreground` @0.38 | `#ffffff` @**0.75** | 0.38 在磨砂卡片上糊掉了 |

> ⚠️ 這些寫死的 `#ffffff` 假設主題是暗色。本機六個主題都是，所以沒處理亮色主題。

### 2.4 字型

```qml
Qt.fontFamilies().indexOf("Inter") >= 0 ? "Inter" : "Noto Sans"
```

`Style.font.menuFamily` 是系統字型，在這台是 **Comic Code —— 一個等寬字型**。
Spotlight 用的是 SF Pro，Inter 是最接近的免費替代。

> **本機目前沒裝 Inter**，所以實際跑的是 Noto Sans。要用就
> `omarchy pkg add inter-font`。

---

## 三、Hyprland 那一半

改 QML 只做到一半，玻璃感是 **compositor 畫的**。

```lua
hl.layer_rule({ match = { namespace = "omarchy-spotlight" },
                blur = true, ignore_alpha = 0.25 })
```

`ignore_alpha` 這個數字要卡在兩個值中間，而且**兩邊都沒有錯誤訊息**：

```
    0.45  ← card 自己的 glassBackground
          ↑ 超過這裡：Hyprland 判定表面太透明不值得模糊，玻璃直接消失
    0.25  ← 現值
          ↓ 低於 backdrop 的 alpha：整個螢幕都被模糊，「不壓暗桌面」就白做了
    0.00  ← 全螢幕透明 backdrop
```

直覺會以為「調高 = 更透明」，實際上調過 0.45 是玻璃**不見**。改
`glassBackground` 的時候記得一起重算。

還有一件事最容易漏：**Omarchy 預設 `decoration.blur.enabled = false`**，
只加 layer rule 不會有任何效果。

按鍵是 `SUPER+SPACE`（Omarchy 自己的選單讓到 `ALT+SPACE`），
`ALT+SHIFT+SPACE` 用 payload 預填 `"remind me "` 直接進 reminder 模式。

---

## 四、驗證

```bash
./verify.sh
```

它查的是執行期狀態，不是檔案長相：外掛版本、14 個 `LOCAL EDIT` 標記、三處關鍵
改動、patch 貼得回去、全域模糊真的開著、真的有鍵綁到 Spotlight。

> 寫 `verify.sh` 時踩到的兩個坑，留給下一個人：
> `hyprctl getoption decoration:blur:enabled -j` 回的是 `"bool": true`，
> 不是 `"int"`；而 `hyprctl binds` 裡**找不到 plugin id** —— 這些 bind 的
> dispatcher 是 `__lua`，參數是不透明的編號，只有 `description` 欄位認得出來。
> Hyprland 也**沒有任何指令可以倒出 layer rules**（`hyprctl layers` 列的是
> surface 不是規則），所以那一項只能從設定檔讀回來。

---

## 五、疑難排解

| 症狀 | 原因 / 解法 |
|---|---|
| 更新後外觀退回 Raycast 樣 | `omarchy plugin update` 蓋掉了。跑 `omarchy-plugin-patches` |
| `FAILED ... upstream moved` | 上游動到同一段。照 `PROMPT.md` 手工重做，再 `git diff` 重錄 |
| 卡片沒有磨砂感 | 先查 `decoration.blur.enabled`，Omarchy 預設是 false |
| 玻璃整個不見（不是變透明） | `ignore_alpha` 超過了 `glassBackground` |
| 整個螢幕都被模糊 | `ignore_alpha` 太低，連透明 backdrop 一起模糊了 |
| 按 SUPER+SPACE 跳出兩個東西 | `bindings.lua` 少了 `hl.unbind("SUPER + SPACE")` |
| placeholder 看不清楚 | 亮色主題。那七個寫死的 `#ffffff` 沒有為亮色主題處理 |
| 字看起來像等寬 | patch 沒貼上，落回 `Style.font.menuFamily`（本機是 Comic Code） |
