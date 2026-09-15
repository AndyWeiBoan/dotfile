# VPN — Fortinet SSL VPN 一鍵開關

點一下連線，再點一下斷線。用開源的 `openfortivpn`，不是 FortiClient。

```
應用程式啟動器
  └── "Work VPN (openfortivpn)"
        └── foot -T work-vpn -e ~/.local/bin/vpn-toggle work
              ├── 沒在跑 → sudo openfortivpn -c ~/.config/openfortivpn/work.conf
              │             ① sudo 密碼  ② VPN 密碼  ③ FortiToken 2FA
              └── 在跑   → sudo pkill -INT -x openfortivpn
```

| 檔案 | 內容 |
|---|---|
| `PROMPT.md` | 給 AI 的完整重建提示詞（換機器用這個） |
| `install.sh` | 裝套件 + 腳本 + 啟動器條目，可重複執行 |
| `verify.sh` | 檢查安裝與 profile 是否安全。**從不印出位址、帳號或指紋** |
| `tools/vpn-toggle` | 開關腳本，接 profile 名稱參數 |
| `config/profile.conf.example` | profile 範本，全部是佔位符 |
| `config/vpn.desktop.template` | 啟動器條目範本 |

```bash
./install.sh work        # profile 名稱，預設 work
./verify.sh work
```

---

## 一、為什麼不是服務

`openfortivpn` 連線時會依序問三件事：sudo 密碼、VPN 密碼、**FortiToken 的 2FA
動態碼**。第三項每次都不一樣，沒有任何設定檔放得下。

一個會停在那裡等人輸入的 systemd service 是壞掉的 service。所以它就該是前景
程式，而 `.desktop` 的唯一工作是替它開一個有 TTY 的視窗：

```ini
Exec=foot -T work-vpn -e /home/you/.local/bin/vpn-toggle work
Terminal=false
```

`Terminal=false` 加上自己叫 `foot`，而不是 `Terminal=true` —— 後者把選終端機的
權力交給 XDG，在 Wayland 上行為不一致。

同理，**綁快捷鍵沒有意義**：`o.bind(..., "vpn-toggle work")` 會開一個沒有 TTY
的程序，密碼提示無處可去。要綁就綁 `foot -e ...` 那一整串。

## 二、profile 不在這個 repo 裡

`~/.config/openfortivpn/<profile>.conf` 有 gateway 位址和你的帳號，所以 repo 裡
只有全佔位符的 `config/profile.conf.example`。`install.sh` **只在檔案不存在時**
提示你自己寫；已經有的話它只檢查權限並修正，不會覆蓋。

```
host = vpn.example.com
port = 443
username = your.name
trusted-cert = 0000...0000
```

**不要寫 `password = ` 那一行。** openfortivpn 支援，但那是把帳號密碼放進純文字
檔，而且有 2FA 的話還是會跳提示，一點也沒省到。`verify.sh` 會把這一行當成失敗。

### trusted-cert —— 唯一一個「照錯誤訊息做就會出事」的地方

它把 gateway 的**葉憑證**用 SHA256 釘住。之所以常常需要，是因為很多 Fortinet
gateway 只送自己的憑證、不送中介 CA，鏈不完整，正常 CA 驗證必定失敗 —— 跟
gateway 合不合法無關。

取得方式是先**不寫這行**跑一次，openfortivpn 會拒絕連線並印出它看到的指紋。

> ⚠️ 那個指紋**要另外管道查證**再貼進去 —— 問管 gateway 的人，或從一台你已經
> 信任的機器比對。把失敗訊息印出來的東西直接複製貼上，等於信任中間人：
> 憑證釘選就從安全機制變成橡皮圖章。

gateway 換憑證時這會照設計壞掉並印出新指紋。那是功能正常。

## 三、已知限制

**`pgrep -x openfortivpn` 不分 profile。** 同時跑兩條隧道時會斷錯條。腳本註解裡
寫了，要同時開兩條就得改成解析 `/proc/<pid>/cmdline` 找 `-c`，或改用 pidfile。

**每次連線都要 sudo 密碼。** 可以在 `/etc/sudoers.d/` 給免密碼，**本機沒有這樣
做** —— 那等於讓任何本機程序無提示地改你的路由表。

## 四、驗證

```bash
./verify.sh work
```

```
== package ==   openfortivpn 的版本
== files ==     vpn-toggle 可執行、.desktop 存在
== profile ==   權限是 600、四個欄位都在、沒有明文密碼、
                指紋不是範例的全零佔位符
== state ==     隧道當下是開是關（關著不算失敗，那是閒置狀態）
```

**它只印欄位在不在，從不印值。** verify 的輸出常常會被貼進聊天視窗或 issue。

## 五、疑難排解

| 症狀 | 原因 / 解法 |
|---|---|
| 點了視窗閃一下就消失 | 腳本結尾少了 `read -n1` 暫停，錯誤訊息來不及看 |
| `Gateway certificate validation failed` | 缺 `trusted-cert`，或 gateway 換憑證了。照上面的流程重新查證新指紋 |
| 連上但什麼都連不到 | DNS。`resolvectl status ppp0` 看有沒有拿到公司的 DNS |
| 斷線斷到別條隧道 | `pgrep -x` 不分 profile，見第三節 |
| 啟動器找不到條目 | `update-desktop-database ~/.local/share/applications` |
