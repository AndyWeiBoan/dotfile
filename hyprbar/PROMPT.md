# 重建提示詞

換機器、重灌、或想在別台 Omarchy 上做出同一套標題列時，把 **§1 的內容整段貼給
Claude Code**（在目標機器上、Hyprland session 裡開）。

§2 是常見變體的追加指令，§3 是驗收標準，§4 是寫這段提示詞時的取捨說明。

---

## §1 主提示詞（整段複製）

````text
在這台 Omarchy / Hyprland 機器上裝 hyprbars，做出 macOS 風格的視窗標題列，
並讓顏色跟著 Omarchy 主題自動連動。

## 背景（不用再研究，直接採用）

標題列是 window decoration，必須貼在每個視窗上緣。Wayland 不允許一個 client
替別的 client 畫裝飾，quickshell 的 layer-shell 只能錨定螢幕，做不到這件事。
Hyprland 本身也沒有內建標題列。唯一可行的是 compositor 外掛 —— 用 hyprwm 官方
的 hyprbars，透過 hyprpm 安裝。不要試圖改 quickshell，也不要用 layer-shell
overlay 去蓋視窗（z-order 和拖動會壞掉）。

## 環境假設

- Omarchy，Hyprland 使用 Lua 設定（~/.config/hypr/*.lua，不是 hyprland.conf）
- 個人覆寫放 ~/.config/hypr/，絕對不要動 /usr/share/omarchy/（更新會被蓋掉）
- 主題調色盤在 ~/.local/state/omarchy/current/theme/colors.toml
  格式是扁平的 `key = "#rrggbb"`，沒有 table 沒有 array

## 要做的事

### 1. 安裝外掛

hyprpm 會抓取跟當前 Hyprland 版本相符的原始碼並編譯，所以需要 build toolchain。
先確認這些套件存在（cpio 最常缺，而且失敗訊息不明顯）：
base-devel cmake meson ninja cpio git pkgconf

然後依序執行，每一步都要確認成功再往下：
  hyprpm update
  hyprpm add https://github.com/hyprwm/hyprland-plugins
  hyprpm enable hyprbars
  hyprpm reload -n

### 2. 開機自動載入

hyprpm 不會自己在開機時載入外掛。在 ~/.config/hypr/autostart.lua 加上：
  o.exec_on_start("hyprpm reload -n")
沒有這行，每次登入標題列都會消失。

### 3. 建立 ~/.config/hypr/hyprbars.lua

版面設定：
  bar_height = 38
  bar_padding = 14
  bar_button_padding = 9
  bar_buttons_alignment = "left"
  bar_text_size = 11
  bar_text_align = "center"
  bar_precedence_over_border = true
  icon_on_hover = true

顏色不要寫死，開檔讀 ~/.local/state/omarchy/current/theme/colors.toml：
  bar_color   <- background
  col.text    <- light_foreground   （比 foreground 暗一階，六個內建主題都有）
用 Lua 的 io.open + string.match 解析，不需要 TOML 函式庫。
路徑用 require("default.hypr.paths").state_home，不要自己拼 os.getenv("HOME")。
讀不到檔案時要 fallback 到寫死的值，讓它降級成舊外觀而不是沒上色的裸 bar。

三顆按鈕（由左至右）：
  紅 = 關閉        hyprctl dispatch 'hl.dsp.window.close()'
  黃 = 最大化      hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized" })'
  綠 = 全螢幕      hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen" })'
按鈕底色取自主題的 red / yellow / green。
圖示用 ✘ ✚ ⛶，size 都設 14。

圖示顏色必須從按鈕自己的顏色算出來，不可以寫死、也不可以讀主題的 foreground：
  算感知亮度 0.299R + 0.587G + 0.114B
  > 140（亮按鈕）→ 同色相乘以 0.30 變深
  <= 140（暗按鈕）→ 往白色混 70% 變亮
理由：主題色亮度差距很大，固定深色圖示在暗按鈕上會看不見；而主題的 foreground
系列跟著「主題的明暗模式」走、不是跟著按鈕走（white 主題的 bright_foreground
是 #000000，會在近黑的按鈕上畫黑圖示）。

### 4. 掛進設定

確認 ~/.config/hypr/hyprland.lua 有 require("hypr.hyprbars")，
位置放在其他 require("hypr.*") 之間。沒有這行的話設定檔只是死碼。

## 這個 build 的已知陷阱（請直接遵守，不要重新踩）

- bar_padding / bar_button_padding 必須 > 0，否則按鈕被算成零寬度整排消失，
  而且是無聲失敗、沒有錯誤訊息。
- bar_precedence_over_border = true 讓標題列畫在邊框內側，邊框包住 bar + 內容。
  設 false 邊框會從中間切斷。
- hyprbars 沒有 bar_color_inactive，所有視窗共用同一個 bar 顏色。
- add_button 每次設定重載都會重建按鈕清單，所以可以無條件呼叫，按鈕不會疊加。
- 這個 build 的 hyprctl dispatch 吃 Lua dispatcher 運算式，不是傳統參數格式。
- hyprbars 沒有獨立的 icon size 選項：size 只控制圓圈直徑，bar_text_size 不影響
  圖示。要調圖示大小只能換字元。已量過的墨跡尺寸（裝置 px）：
    ✖ U+2716=18  ✘ U+2718=12  ✕ U+2715=8  × U+00D7=8
    ✚ U+271A=12  ✛ U+271B=12  + U+002B 偏下不置中
    ⛶ U+26F6=13  ⤢ U+2922=8
  現用組合 ✘ ✚ ⛶ = 12/12/13，三顆視覺對齊。
- icon 不能是空字串，否則 icon_on_hover 沒東西可畫。
- 有些主題的 colors.toml 用大寫 hex（matte-black 是 "#D35F5F"），
  解析後統一轉小寫再交給 Hyprland。
- 不需要寫 theme-set hook。omarchy theme set 會呼叫 omarchy-restart-hyprctl 重載
  設定，而 Omarchy 的 bootstrap.lua 重載時會把 hypr.* 從 package.loaded 清掉，
  模組會重新執行、重新讀檔。

## 驗收（請實際跑，不要只說「應該可以了」）

1. hyprctl reload；hyprctl configerrors 必須是空的
2. hyprctl plugin list 要看得到 hyprbars
3. 把執行期的值跟主題檔對照，兩者必須完全相同：
     hyprctl getoption plugin:hyprbars:bar_color -j   →  colors.toml 的 background
     hyprctl getoption plugin:hyprbars:col.text -j    →  colors.toml 的 light_foreground
   （hyprctl 回傳的是 AARRGGBB packed int，記得轉換再比對）
4. 用同一段解析邏輯，對 /usr/share/omarchy/themes/*/colors.toml 全部跑一遍，
   確認六個內建主題都解析得出 background / light_foreground / red / yellow / green，
   而且推導出的圖示色跟按鈕色有足夠對比。
5. 如果有 grim 和 imagemagick，截圖取樣標題列那一行確認實際畫出來的顏色：
     grim /tmp/s.png && magick /tmp/s.png -crop 200x1+0+113 +repage txt: \
       | grep -oE '#[0-9A-F]{6}' | sort | uniq -c | sort -rn | head
   按鈕取樣值跟主題值差 ~3/255 是正常的（hyprbars 用自己的 shader 畫圓點）；
   bar_color 走 Hyprland 設定路徑，應該完全精確。

## 規則

- 改任何 ~/.config 檔案前先備份成 <檔名>.bak.$(date +%s)
- 絕對不要修改 /usr/share/omarchy/ 底下的東西（讀取沒問題）
- 設定檔的註解要寫「為什麼」，特別是上面那些陷阱 —— 半年後回來看會需要
- 完成後告訴我：驗收每一項的實際輸出，以及有沒有哪一項沒過
````

---

## §2 變體追加指令

接在 §1 後面，或事後單獨提出。

### 想要固定的 macOS 紅綠燈配色（不跟主題）

````text
三顆按鈕不要跟主題，用固定的 macOS 配色：
  底色  rgb(ff5f57) / rgb(febc2e) / rgb(28c840)
  圖示  rgb(4d0000) / rgb(5c3d00) / rgb(003d0a)
bar_color 和 col.text 仍然跟主題連動。
理由：主題的 red/yellow/green 是終端機調色盤的語意欄位不是 UI 顏色，
white 主題會讓三顆變成幾乎一樣的深灰、matte-black 的 green 是琥珀色、
rose-pine 的 green 是藍青色，紅綠燈的辨識度會消失。
````

### 想讓標題列跟視窗內容有色差

````text
bar_color 改讀 lighter_background 而不是 background，
讓標題列跟視窗內容之間有一條可見的分界。
````

### 想改按鈕位置或行為

````text
bar_buttons_alignment 改成 "right" 把三顆移到右邊。
按鈕順序由 add_button 的呼叫順序決定 —— 第一個呼叫的在最外側。
要改行為就換 action 字串，格式是：
  hyprctl dispatch '<Lua dispatcher 運算式>'
可用的 dispatcher 查 hyprctl dispatch 的說明。
````

### 只想調圖示大小

````text
hyprbars 沒有 icon size 選項，size 只控制圓圈直徑。
要讓圖示變大就換成墨跡更大的字元（✖ U+2716 是 18px，目前用的 ✘ U+2718 是 12px）。
換字元後三顆的視覺大小要重新對齊，不要只換一顆。
````

### Hyprland 更新後標題列消失

````text
標題列不見了，Hyprland 剛更新過。
外掛是針對特定 Hyprland commit 編譯的，升級後舊的 .so 會拒絕載入。
跑 hyprpm update && hyprpm reload -n 重新編譯，然後用 hyprctl plugin list 確認。
````

---

## §3 驗收標準

跑 `./verify.sh`，或人工確認以下每一項：

| 檢查 | 通過條件 |
|---|---|
| `hyprctl configerrors` | 輸出為空 |
| `hyprctl plugin list` | 含 `hyprbars` |
| `hyprpm list` | hyprbars `enabled: true` |
| `plugin:hyprbars:bar_color` | 等於主題的 `background` |
| `plugin:hyprbars:col.text` | 等於主題的 `light_foreground` |
| `omarchy theme set <別的主題>` | 顏色自動跟著換，不用手動重載 |
| 重新登入 | 標題列仍在（`autostart.lua` 那行有效） |
| 六個內建主題解析 | 每個都取得到五個色鍵，圖示色跟按鈕色有對比 |

---

## §4 為什麼這段提示詞要寫這麼細

這些是實際踩過、而且**從文件或原始碼看不出來**的東西。
不寫進提示詞的話，下一次（或下一個 AI）會重踩一遍：

1. **quickshell 的誤解** —— 直覺會以為標題列是 shell 畫的，先擋掉這條死路。
2. **`bar_padding` 必須 > 0** —— 無聲失敗，最難查。
3. **圖示大小只能靠換字元** —— 會有人一直去調 `bar_text_size`，沒有用。
4. **圖示顏色不能讀主題 foreground** —— 這個錯誤只在 `white` 這種淺色主題才會炸，
   在深色主題下測不出來。
5. **不需要 hook** —— 會有人多寫一個 `theme-set.d` 腳本，其實 Omarchy 的
   `bootstrap.lua` 已經處理了模組重載。
6. **Hyprland 更新後要重編外掛** —— 症狀（標題列消失）跟原因（ABI 不符）
   看起來完全無關。
7. **要求實跑驗收** —— 這類設定很容易「看起來對」但執行期的值是舊的。
   對照 `hyprctl getoption` 跟主題檔是唯一可靠的檢查。
