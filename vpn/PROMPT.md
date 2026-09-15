# 重建提示詞

換機器、重灌，或要在別台 Omarchy 上做出同一個 VPN 開關時，把 **§1 整段貼給
Claude Code**。

§2 是變體，§3 是驗收標準，§4 是寫這段時的取捨說明。

> ⚠️ §1 裡**沒有任何 gateway 位址、帳號或憑證指紋**，那些是每個人自己的。
> 提示詞只描述怎麼把東西接起來。

---

## §1 主提示詞（整段複製）

````text
在這台 Omarchy / Hyprland 機器上，做一個 Fortinet SSL VPN 的一鍵開關 ——
從應用程式啟動器點一下連線，再點一下斷線。

## 背景（不用再研究，直接採用）

Fortinet 官方的 FortiClient 在這類機器上常常是壞的（GUI 起不來或依賴裝不起來）。
開源的 openfortivpn 是可用的替代，同一個協定，CLI。

它是**前景、互動式**的程式：連線時會依序問三件事 ——
  1. sudo 的登入密碼（要改路由表和建 ppp 介面）
  2. VPN 密碼
  3. FortiToken 的 2FA 動態碼
所以不能做成背景服務，也不要包 systemd unit。要包成一個**在終端機裡跑的
.desktop**，讓那三個提示有地方輸入。

## 環境假設

- Omarchy（Arch + Hyprland）
- 個人執行檔放 ~/.local/bin/，啟動器條目放 ~/.local/share/applications/
- 終端機用 foot（Omarchy 預設有）

## 要做的事

### 1. 裝套件

  omarchy pkg add openfortivpn

### 2. 寫 ~/.local/bin/vpn-toggle

一支 bash 腳本，接一個參數當 profile 名稱（預設讀 $OPENFORTIVPN_PROFILE，
再預設 "work"），對應到 ~/.config/openfortivpn/<profile>.conf。

行為：

  - 已經在跑（pgrep -x openfortivpn）→ sudo pkill -INT -x openfortivpn，
    印「Disconnected」，等一個按鍵再關閉視窗
  - 沒在跑 → sudo openfortivpn -c <conf>
  - openfortivpn 沒裝 / conf 不存在 → 印清楚的錯誤並告訴使用者怎麼補
  - 結束時一律 `read -n1` 暫停。這支是在自己的終端機視窗裡跑的，不暫停的話
    視窗會在你讀到錯誤訊息之前就消失

兩個要寫進註解的重點：

  - pgrep -x openfortivpn **不分 profile**。同時跑兩條隧道時會斷錯條。
    我們不這樣用，但下一個人要知道。
  - 連線前檢查 conf 的權限，不是 600 就警告。那個檔案裡有 gateway 位址和
    你的帳號。

### 3. 包成 .desktop

  ~/.local/share/applications/<profile>-vpn.desktop

  Exec=foot -T <profile>-vpn -e /home/<you>/.local/bin/vpn-toggle <profile>
  Terminal=false
  Categories=Network;
  Icon=forticlient

`Terminal=false` 加上自己叫 foot，而不是 `Terminal=true`：後者交給 XDG 挑終端
機，在 Wayland 上行為不一致。`-T` 給視窗一個固定標題，需要的話可以下視窗規則。

Icon=forticlient 通常已經存在於系統圖示主題裡。沒有就換一個 Network 類的。

### 4. 建 profile（不要幫使用者填內容）

  ~/.config/openfortivpn/<profile>.conf     chmod 600

  host = <gateway>
  port = 443
  username = <account>
  trusted-cert = <sha256>

**不要寫 `password = ` 那一行。** openfortivpn 支援它，但那是把帳號密碼放進
純文字檔，而且有 2FA 的話還是會跳提示，省不了事。

trusted-cert 的說明要寫進註解裡，因為它最容易被草率處理：

  - 它把 gateway 的**葉憑證**用 SHA256 釘住
  - 之所以常常需要它，是因為很多 Fortinet gateway 只送自己的憑證、不送中介
    CA，鏈不完整，正常的 CA 驗證一定失敗 —— 跟 gateway 合不合法無關
  - 取得方式是先**不寫這行**跑一次，openfortivpn 會拒絕連線並印出它看到的指紋
  - **那個指紋要另外管道查證**（問管 gateway 的人，或從一台你已經信任的機器
    比對）再貼進去。把失敗訊息印出來的東西直接貼上，等於信任中間人
  - gateway 換憑證時這會照設計壞掉並印出新指紋。那是功能正常，不是 bug

## 完成後自我檢查

  1. 應用程式啟動器裡找得到這個條目
  2. 點一下 → 開出一個終端機視窗，依序問 sudo 密碼、VPN 密碼、2FA
  3. 連上之後 `ip -o link show` 看得到 ppp0
  4. 再點一次 → 印 Disconnected，ppp0 消失
  5. `stat -c %a <conf>` 是 600
  6. conf 裡沒有 password 那一行
````

---

## §2 變體

**多個 gateway**：腳本已經吃 profile 參數，多做幾個 `.desktop` 指到不同 profile
即可。但 §1 提過的 `pgrep -x` 不分 profile —— 要同時開兩條就得改成解析
`/proc/<pid>/cmdline` 找 `-c <conf>`，或改用 pidfile。

**不要 sudo 密碼提示**：可以在 `/etc/sudoers.d/` 給 openfortivpn 免密碼。
**本機沒有這樣做**：那等於讓任何本機程序無提示地改你的路由表。要做的話至少
用完整路徑並限定 `-c` 的參數。

**綁快捷鍵**：`o.bind(..., "vpn-toggle work")` 不會有效果 —— 它需要一個終端機
視窗才能問密碼。要綁的話綁 `foot -e ...` 那一整串，跟 `.desktop` 裡一樣。

**想要狀態顯示在 bar 上**：另一件事。`pgrep -x openfortivpn` 就是判斷式，做成
一個 Omarchy bar widget 即可，但這個模組不含。

---

## §3 驗收標準

跑 `./verify.sh <profile>`。它查套件、兩個檔案、profile 的權限與必要欄位、
有沒有明文密碼、指紋是不是還停在範例的全零值，最後報告隧道當下是開是關。

**它從不印出 host、username 或指紋的值**，只印欄位在不在。這是刻意的：
verify 的輸出常常會被貼進聊天視窗或 issue。

---

## §4 取捨說明

**為什麼不做成 systemd service。**
它一定要問 2FA 動態碼，那是每次連線都不一樣的東西，沒有辦法預先放進任何設定檔。
一個會停在那裡等輸入的服務是壞掉的服務。所以它就該是一個前景程式，而 .desktop
只是替它開一個有 TTY 的視窗。

**為什麼 profile 不進 repo。**
裡面有 gateway 位址和帳號。`config/profile.conf.example` 是全佔位符版本，
真正的內容由 `install.sh` 提示使用者自己寫，而且**只有在檔案不存在時**才提示 ——
已經有的話它只檢查並修正權限，不會覆蓋。

**為什麼 trusted-cert 的註解寫這麼長。**
這是整個設定裡唯一一個「照著錯誤訊息做就會出事」的地方。openfortivpn 失敗時
很貼心地印出指紋，而最自然的反應就是複製貼上 —— 那一步正好把憑證釘選從一個
安全機制變成一個橡皮圖章。長度是刻意的。

**為什麼加權限檢查。**
寫這個模組的時候，本機那份 conf 是 **644**，任何本機使用者都讀得到 gateway
位址和帳號。不是災難，但沒有理由。腳本連線前會警告，`install.sh` 會直接修掉。
