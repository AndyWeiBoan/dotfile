# 重建提示詞

換機器、重灌，或上游改版讓 `config/io.github.maajix.spotlight.patch` 貼不上去時，
把 **§1 整段貼給 Claude Code**（在目標機器上、Hyprland session 裡開）。

這份提示詞刻意**不依賴那個 patch 檔**。patch 只在上游版本沒動時可用；提示詞描述
的是「要達成什麼」和「為什麼」，上游怎麼重構都還原得出來。

§2 是變體，§3 是驗收標準，§4 是寫這段時的取捨說明。

---

## §1 主提示詞（整段複製）

````text
在這台 Omarchy / Hyprland 機器上，把第三方外掛 Spotlight 從 Raycast 風格改造成
macOS Spotlight 的外觀。

## 背景（不用再研究，直接採用）

Spotlight 是別人的 Omarchy shell plugin：
  id      io.github.maajix.spotlight
  作者    Max Randhahn
  上游    Raycast 風格的命令面板 —— 寬卡片、置中、一開啟就列出 app
我們要的是 macOS Spotlight：窄藥丸、偏上、空查詢時什麼都不顯示。

這是「改別人的外掛」，不是寫自己的。所以：

1. 不要 fork、不要重寫，只改 Spotlight.qml 一個檔案
2. 每一處改動都要留 `// LOCAL EDIT: <為什麼>` 註解 —— 這是之後 re-make patch
   時唯一能認出哪些是我們的東西的依據
3. 改完必須把 diff 存成 patch，否則 `omarchy plugin update` 會整個蓋掉

## 環境假設

- Omarchy，Hyprland 用 Lua 設定（~/.config/hypr/*.lua，不是 hyprland.conf）
- 外掛裝在 ~/.config/omarchy/plugins/<id>/，每個都是獨立 git 工作目錄
- 絕對不要動 /usr/share/omarchy/（更新會被蓋掉）

## 要做的事

### 1. 安裝外掛

  omarchy plugin add https://github.com/maajix/omarchy-spotlight --enable

裝完確認 ~/.config/omarchy/plugins/io.github.maajix.spotlight/ 存在，
記下 manifest.json 的 version（本機驗證過的是 1.1.4）。

### 2. 改 Spotlight.qml

一共十四處。**先整份讀過一次再動手** —— 屬性大多集中在檔案上半部的
readonly property 區塊，版面在下半部的 card 元件裡。

#### 2a. 形狀與動態 —— 最關鍵的三處，其他都是配色

(1) 藥丸形變。card 的 radius 原本固定是 cardRadius，改成：

      radius: hasResults ? root.cardRadius : height / 2

    收合時兩端全圓（現行 macOS Spotlight 開啟時就是一顆藥丸），有結果才方化。
    再加一個 Behavior 讓它 morph，時長對齊既有的 height Behavior：

      Behavior on radius {
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
      }

(2) 空查詢不顯示任何東西。找到 rebuild() 函式，在算出 q 之後、組 next 之前插入：

      if (q.length === 0) {
        root.rows = []
        displayModel.clear()
        root.selectedIndex = 0
        return
      }

    上游一開啟就列出 frecency 排序的 app 清單。macOS 不是這樣 —— 打開只是一顆
    裸藥丸，打字才展開。

    同時 footer 和它上面的分隔線都要加 `visible: card.hasResults`，
    card 的 height 算式裡 footer 那一項也要跟著條件化：

      height: root.searchHeight
        + (hasResults ? root.hairline + root.listPadding * 2 + listHeight : 0)
        + (hasResults ? root.hairline + root.footerHeight : 0)

    沒有這步，空狀態會是一顆藥丸下面吊著一條空的 footer。

(3) 位置固定在上方。把 card 的 anchors.verticalCenter 拿掉，改成：

      y: Math.round(panel.height * 0.22)

    macOS 把 Spotlight 放在畫面上方而非正中。用固定比例而不是置中，還順便解掉
    另一個問題：置中的話藥丸會**隨著結果變多而往上爬**。固定 y 之後它開在哪就
    在哪，只往下長。

#### 2b. 尺寸

    width          Style.space(750) → Style.space(560)
    cardRadius     Style.space(12)  → Style.space(20)
    rowRadius      Style.space(8)   → Style.space(10)
    searchHeight   Style.space(56)  → Style.space(50)
    searchFontSize baseSize * 1.5   → baseSize * 1.35

寬度：Apple 的藥丸大約佔螢幕三分之一，不是 750。
searchFontSize 要跟著 searchHeight 一起降，否則字會頂滿變矮的搜尋列。
`width` 那行的 `panel.width - Style.space(48)` 夾限保留不動。

#### 2c. 顏色

    glassBackground     Color.menu.background @0.62 → @0.45     更透
    scrim               Color.menu.scrim @0.25      → "transparent"
    selectedBackground  Color.foreground @0.12      → Color.accent @0.85
    selectedText        Color.menu.selectedText     → "#ffffff"
    搜尋放大鏡圖示      foreground @0.5             → "#ffffff" @0.7
    輸入文字 / 選取文字 foreground                  → "#ffffff"
    placeholder         foreground @0.38            → "#ffffff" @0.75

scrim 全透明：macOS Spotlight **不壓暗桌面**，藥丸浮在未受影響的畫面上。
selectedBackground：Apple 用實心強調色填滿選中列，不是淡灰。
placeholder 的 0.38 在磨砂卡片上會糊掉，必須拉到 0.75。

其餘顏色（glassBorder、glassSheen、dividerColor）不要動。

#### 2d. 字型

    fontFamily: Style.font.menuFamily
      → Qt.fontFamilies().indexOf("Inter") >= 0 ? "Inter" : "Noto Sans"

`Style.font.menuFamily` 是系統字型。在這台是 Comic Code —— **一個等寬字型**，
拿來排 Spotlight 很奇怪。Spotlight 用的是 SF Pro，Inter 是最接近的免費替代。

注意：Inter 預設**沒裝**。要真的用到它得先 `omarchy pkg add inter-font`，
否則這行會落到 Noto Sans。兩者都比 Comic Code 合適，所以不裝也可以接受。

### 3. 存成 patch（不能省）

`omarchy plugin update` 會把上游直接蓋在工作目錄上，本地編輯全部丟掉。

  mkdir -p ~/.config/omarchy/plugin-patches
  cd ~/.config/omarchy/plugins/io.github.maajix.spotlight
  git diff > ~/.config/omarchy/plugin-patches/io.github.maajix.spotlight.patch

再裝一支重貼工具到 ~/.local/bin/omarchy-plugin-patches（本 repo 的
tools/omarchy-plugin-patches 就是）。它的行為要是：

  - 掃 ~/.config/omarchy/plugin-patches/*.patch，逐一對應到已安裝的外掛
  - 先把 <id>.files/ 底下的整新檔案 cp 進去（git diff 看不到未追蹤的檔案，
    新增的檔案沒有這步不會回來）
  - 用 `git apply --reverse --check` 判斷是否已套用，已套用就跳過 —— 重複跑安全
  - 套用失敗時明確印出「上游動過了，要手工重做」，不要靜默失敗
  - 有任何一個真的貼上去才 `omarchy restart shell`

每次 `omarchy plugin update` 之後跑它。

### 4. 加 Hyprland 的磨砂玻璃 layer rule

在 ~/.config/hypr/looknfeel.lua 加：

  hl.layer_rule({ match = { namespace = "omarchy-spotlight" },
                  blur = true, ignore_alpha = 0.25 })

模糊是**compositor 的**，不是 QML 的。ignore_alpha 這個數字要卡在兩個值之間：

  高於 backdrop 的 alpha  —— 否則整個螢幕都被模糊，「不壓暗桌面」就白做了
  低於 card 的 alpha 0.45 —— 超過的話 Hyprland 判定這個表面太透明、不值得模糊，
                             玻璃會直接消失，而不是變得更透明

0.25 在這個區間中央。之後若改了 glassBackground，這個數字要重算。

**還要確認全域模糊是開的**：`decoration.blur.enabled = true`。
Omarchy 預設是 **false**，只加 layer rule 不會有任何效果。

### 5. 綁按鍵

在 ~/.config/hypr/bindings.lua：

  hl.unbind("SUPER + SPACE")
  o.bind("SUPER + SPACE", "Spotlight",
    "omarchy-shell shell toggle io.github.maajix.spotlight '{}'")
  o.bind("ALT + SHIFT + SPACE", "Spotlight reminder",
    "omarchy-shell shell toggle io.github.maajix.spotlight '{\"query\":\"remind me \"}'")
  o.bind("ALT + SPACE", "Omarchy menu", "omarchy-menu toggle")

Spotlight 接手主啟動鍵 SUPER+SPACE，Omarchy 自己的選單讓到 ALT+SPACE。
一定要先 hl.unbind —— SUPER+SPACE 本來就綁著 Omarchy 選單，直接蓋上去會兩個都觸發。
不要用 SUPER+SHIFT+SPACE，Omarchy 拿它做「Toggle top bar」。
SUPER+ALT+SPACE（Apps menu）不要動。

payload 可以預填查詢字串，第二個 bind 就是靠這個直接進到 reminder 模式。

## 完成後自我檢查

  1. 按 SUPER+SPACE —— 出現的是一顆**兩端全圓的窄藥丸**，畫面其餘部分**沒有變暗**
  2. 這時候**沒有任何結果列、沒有 footer**
  3. 打一個字 —— 藥丸向下展開成圓角矩形，形狀是**動畫過渡**的，不是瞬間跳變
  4. 選中列是**實心強調色**，不是淡灰
  5. 藥丸的上緣在展開前後**停在同一個 y**，不會往上爬
  6. 卡片背後看得到模糊的桌布
  7. 全部清掉查詢 —— 縮回藥丸，footer 消失

第 6 點沒過，先查 `decoration.blur.enabled` 是不是 true，再查 ignore_alpha。
````

---

## §2 變體

**想保留上游的置中行為**（不喜歡固定在上方）：跳過 2a 的第 (3) 點，留著
`anchors.verticalCenter`。代價是藥丸會隨結果數量上下移動。

**想要空查詢仍然列出常用 app**：跳過 2a 的第 (2) 點。這樣 footer 的
`visible: card.hasResults` 和 height 算式也都不用改 —— 那三處是同一件事的三個面向。

**不裝 Inter**：2d 的 fallback 已經處理了，會落到 Noto Sans。真的想要 SF Pro 的
質感就 `omarchy pkg add inter-font`。

**主題是亮色系**：2c 那幾個寫死的 `#ffffff` 在亮色主題上會看不見。改成
`Color.menu.background` 的對比色，或乾脆用 `Color.foreground` —— 但那樣
placeholder 又會糊掉，要重新調 opacity。**本機六個主題都是暗色，所以沒處理這件事。**

---

## §3 驗收標準

§1 結尾那七點是給執行的 agent 自己看的。人要另外確認的是：

| 項目 | 怎麼確認 |
|---|---|
| patch 真的存下來了 | `ls -la ~/.config/omarchy/plugin-patches/io.github.maajix.spotlight.patch` |
| patch 真的貼得回去 | `cd ~/.config/omarchy/plugins/io.github.maajix.spotlight && git apply --reverse --check ~/.config/omarchy/plugin-patches/*.patch` 無輸出 = 已套用 |
| 改動有標記 | `grep -c 'LOCAL EDIT' Spotlight.qml` 應該是 14 |
| 更新後活得下來 | `omarchy plugin update` 之後跑 `omarchy-plugin-patches`，外觀要回來 |

或直接跑本 repo 的 `./verify.sh`。

---

## §4 取捨說明（寫這段提示詞時的判斷）

**為什麼提示詞不是「套用這個 patch」。**
patch 綁死在上游 1.1.4 的行號和上下文。Spotlight.qml 一重構就貼不上去，那時候
patch 是零價值的，而「要達成什麼」永遠有效。patch 留在 `config/` 是為了**上游沒動
的時候省事**，不是主要路徑。

**為什麼要求留 `LOCAL EDIT` 註解。**
唯一能在一個 1800 行的別人檔案裡認出哪些是我們的東西的方法。之後 re-make patch
時 `grep -n 'LOCAL EDIT'` 就是清單。數量（14）本身也是驗收指標。

**為什麼把三處形狀改動跟配色分開講。**
配色改錯了只是醜；形狀那三處改錯了會壞掉 —— 漏了 footer 的 visible 就會有一條
吊在藥丸下面的空白，漏了 height 算式就會有一塊透明的空洞。它們看起來像三個獨立
的改動，實際上是「空查詢時只剩一顆藥丸」這一件事的三個面向，要一起做。

**為什麼 ignore_alpha 要解釋上下界。**
這個數字是唯一沒辦法從 QML 看出來、也沒有錯誤訊息的地方。設太高玻璃直接消失，
而直覺會以為「更高 = 更透明」。寫死一個 0.25 而不解釋，下一個人改
`glassBackground` 的時候一定會踩到。

**為什麼不做亮色主題。**
本機六個主題全是暗色，寫死 `#ffffff` 沒有代價。要做就得把那七個顏色全部改成
從主題推導，那是另一個層級的工作量，而且沒有實際需求。§2 標記了這個缺口。
