# launchpad — macOS 風格的 app 格狀啟動器

`SUPER+A`（或四指捏合）叫出全螢幕的 app 格子：固定 6×5 一頁、頁面圓點、
打字即篩選，背景是模糊的桌布。

| 檔案 | 內容 |
|---|---|
| `config/launchpad.qml` | 貼到 `~/.config/quickshell/launchpad/shell.qml` |
| `tools/launchpad` | wrapper，貼到 `~/.local/bin/launchpad`（吃 `daemon` / `close`） |

`~/.config/hypr/autostart.lua` 要有：

```lua
o.exec_on_start("sleep 2 && /home/andy/.local/bin/launchpad daemon")
```

---

## 〇、它是常駐程序，不是每次重開

**這點會影響你怎麼改它。** 登入時起一個 `qs -d -p …`，之後每次 `SUPER+A` 只是
`qs … ipc call launchpad toggle`。

| | 開啟到畫面出現 |
|---|---|
| 每次重跑 `qs`（舊版） | **337–354 ms** |
| **常駐 + IPC** | **64–92 ms**（10 次實測，沒有累積） |

那 340ms 不是這份 config 慢：一個空的 layer surface 只要 5ms，所以大約
**145ms 是 Qt/QML 啟動、190ms 是解那張 5120×2880 的桌布**，兩個都是每次重開都要付的。
（`sourceSize` 想叫 Qt 解碼小一點**反而更慢**，五種尺寸都試過 ——
Qt 還是要 parse 整張 JPEG，然後多做一次平滑縮放。不要再試。）

代價：常駐 **~436 MB RSS**、隱藏時 **0.2%** CPU、登入時多約 1 秒起 daemon。

這也是 Quickshell 官方 FAQ 的建議做法 —— 它刻意不提供「開關視窗」的指令，
要你自己用 `IpcHandler` 去改 `visible`。

> 改 QML 時記得：**不要用 `Qt.quit()`**，那會把常駐程序殺掉，
> 下一次按鍵就又要付 340ms。一律 `root.setShown(false)`。

## 一、常駐化會踩的坑（跟 mission-control 同一份清單）

1. **預設一定要 `shown: false`**。config 載入就顯示的話，每次登入都會閃一下整個格子。
2. **IPC 函式不可以叫 `show`**。`qs ipc` 自己的子命令是
   show / call / wait / listen / prop，解析器**在任何位置**看到這些字都當子命令，
   所以 `ipc call launchpad show` 根本沒送到物件上 —— 它印出函式清單然後 **exit 0**。
   靜默失敗。開啟的那個函式叫 `open`。
3. **常駐會記住使用者上次留下的狀態。** 重新打開時必須清掉搜尋字串、回到第一頁，
   **並且重新 `forceActiveFocus()`** —— 隱藏時 layer surface 被拆掉，
   TextInput 會一起失去焦點，不搶回來的話第二次打開就打不進字。
   （所以有 `resetRequested()` 這個 signal：搜尋框和頁碼是 per-screen 的，
   root 碰不到，只能用 signal 通知。）
4. **wrapper 的探活不要用 pgrep**。`qs -d -p` 的 cmdline **保留 `-d`**，
   所以 `qs -p <config>` 這個 pattern 抓不到 daemon，會判定「沒在跑」然後
   每次按鍵都再開一個實例。用同一個 socket 問 `ipc call launchpad state` 就好。
5. **`qs -d -p` 在已有實例時不會拒絕，它會再開第二個**，而 `qs ipc` 預設只跟
   **最舊的**那個講話 —— 另一個就變成幽靈，症狀是「偶發打不開」。
   wrapper 用 `flock` 序列化。
6. **`flock` 的 fd 會被 daemon 繼承**，而 daemon 是長駐的 → 鎖永遠不釋放 →
   之後每次按鍵都死等。啟動 daemon 時要 `9>&-` 把那個 fd 關掉。
   而且 `flock -w 2` 設上限：寧可沒序列化，也不能讓按鍵卡死。

## 二、背景模糊在這裡是對的（跟 mission-control 不一樣）

macOS 的 **Launchpad 確實是毛玻璃**，所以這裡保留 QML 裡的
`MultiEffect { blurEnabled: true }`。
（Mission Control 不一樣 —— 那個背景是清晰的真桌面，早期版本加的全螢幕模糊是錯的。）

> **不要換成 compositor blur。** 對全螢幕 layer 開 `hl.layer_rule({ blur = true })`
> 會讓 hyprbars 的標題列每次重繪就閃爍，而且 `new_optimizations = false` 擋不住。
> 「在 QML 裡自己模糊」不是繞路，它就是正解。

## 三、要淡入淡出的話，不要用 QML 的 opacity

**QtQuick 的 `opacity` 是逐個子項各自繼承，不是群組透明**（包進一個父 Item 再設
opacity 也一樣沒用，父項的 opacity 同樣乘進每個子項）。對「桌布」和「圖示」分別做
淡出，等於讓亮的桌布從半透明的圖示底下透出來 —— 畫面在淡向全無的中途反而變亮。

要整層淡出就用 `HyprlandWindow.opacity`（`Quickshell.Hyprland` 的 attached
property，合成器層級）。詳見 `../mission-control/FINDINGS.md` §10。
