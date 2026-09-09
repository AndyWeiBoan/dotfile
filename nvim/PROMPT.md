# 重建提示詞 — Neovim C# / Roslyn LSP

換機器、重灌、或想在別台機器上接同一套 C# LSP 時，
把 **§1 的內容整段貼給 Claude Code**。

§2 是常見變體，§3 是驗收標準，§4 是寫這段提示詞時的取捨說明。

---

## §1 主提示詞（整段複製）

````text
在這台機器的 LazyVim 上把 C# 的 LSP 接成微軟官方的 Roslyn
(Microsoft.CodeAnalysis.LanguageServer)。

## 背景（不用再研究，直接採用）

C# 在 Neovim 上有三個選擇：omnisharp（LazyVim 內建 extra 用的，舊而且慢）、
csharp-ls（輕量但功能少）、Roslyn（微軟自家，VS Code C# Dev Kit 同一支）。

選 Roslyn 的決定性理由是**反編譯跳轉**：對沒有原始碼的型別（例如
System.Collections.Generic.List<T>）按 go-to-definition，Roslyn 會反編譯出
C# 給你看，另外兩個做不到。

所以不要啟用 LazyVim 的 C# extra（那個裝的是 omnisharp），
用 seblyng/roslyn.nvim 自己接。

## 環境假設

- Neovim + LazyVim，設定在 ~/.config/nvim
- 自訂外掛放 ~/.config/nvim/lua/plugins/*.lua
- 全部工作寫在單一個檔案 lua/plugins/csharp.lua，不要拆散
- .NET SDK 用 mise 管（mise use -g dotnet@latest）

## 要做的事

### 1. .NET SDK

Roslyn LS 是 .NET 程式，需要 runtime。確認 dotnet 在 PATH 上，
沒有的話用 mise 裝：mise use -g dotnet@latest

### 2. 第二個 mason registry（最容易漏掉的一步）

roslyn 這個套件只存在於 Crashdummyy/mason-registry，
官方 mason-org/mason-registry 沒有。少加這個 registry，
:MasonInstall roslyn 會回 "Package roslyn was not found"。

在 csharp.lua 裡設定 mason：
  registries = {
    "github:mason-org/mason-registry",     -- 官方的要留著，其他工具靠它
    "github:Crashdummyy/mason-registry",   -- roslyn 在這裡
  }
  ensure_installed = { "roslyn" }

這個寫法成立是因為 LazyVim 的 mason config 是
require("mason").setup(opts) 直接把 opts 丟進去、再自己處理 ensure_installed，
所以 registries 會原封不動傳給 mason。

### 3. roslyn.nvim

外掛 seblyng/roslyn.nvim，ft = "cs"，opts 設定：
  filewatching = "off"     -- 不關的話會對暫存/已刪除的檔案一直噴 ENOENT
  broad_search = false     -- 只往上找 .sln/.csproj，不要掃整個樹
  lock_target = false      -- 允許在多個 solution 之間切換

Inlay hints 在 config.settings 的 ["csharp|inlay_hints"] 底下全開
（型別、參數名、lambda 參數型別、隱含 new、var 的實際型別等等）。
注意這個 key 用 | 分隔不是 . ，那是 Roslyn LS 自己的設定命名空間，
寫錯不會報錯、只是沒效果。

### 4. Reference 數量：用 symbol-usage.nvim 取代 codelens

裝 Wansmer/symbol-usage.nvim（event = "LspAttach"），
它顯示在行尾，不像 codelens 佔掉一整行、也不需要手動 refresh。

然後必須主動關掉 Roslyn 的 codelens，否則兩者會同時出現。
做法是在 LspAttach 之後改掉 client 的 capability：
  client.server_capabilities.codeLensProvider = false
用 nvim_create_autocmd("LspAttach", ...) 加一個具名的 augroup。

### 5. 格式化鍵位

Roslyn 沒有對應的 conform / none-ls formatter，
所以 LazyVim 那套格式化路徑對 .cs 是空的。
在 FileType cs 時綁 buffer-local 鍵位直接打 LSP：
  visual "="   → vim.lsp.buf.format({ async = false })
  normal "=="  → vim.lsp.buf.format({ async = false })
一定要 buffer-local，不要影響其他語言的 = 行為。

### 6. Treesitter

ensure_installed 加上 "c_sharp"（底線，不是 csharp 也不是 cs）。

## 驗收（請實際跑，不要只說「應該可以了」）

不要只檢查設定檔長得對不對 —— 那證明不了任何事。
請建一個最小 C# 專案（.csproj + 一個 Program.cs），
用 headless nvim 開檔、等 LSP attach、把執行期狀態讀回來。

Program.cs 裡故意放一行沒用到的 `using System;`，
這樣 Roslyn 會產生 IDE0005 這個 **analyzer 診斷**。
不要用語法錯誤來測 —— 語法錯誤只能證明 parser 跑了，
IDE0005 才能證明專案真的被載入、analyzer 真的執行完。

三件事都成立才算通過：
  1. client 名稱是 roslyn，而且 root_dir 指到專案目錄
  2. server_capabilities.codeLensProvider == false（證明第 4 步的 autocmd 生效）
  3. 診斷裡有 IDE0005

第一次跑會很慢（要還原 NuGet），timeout 給到 90 秒以上。

## 規則

- 改任何 ~/.config 檔案前先備份成 <檔名>.bak.$(date +%s)
- 設定檔的註解要寫「為什麼」，特別是上面那些坑
- 不要在沒問過我的情況下跑 :Lazy sync 或 :Lazy update
  —— 那會動到 lazy-lock.json，把其他外掛一起升級
- 完成後告訴我：驗收每一項的實際輸出，以及有沒有哪一項沒過
````

---

## §2 變體追加指令

### 想要 reference 數量回到內建 codelens

````text
拿掉 symbol-usage.nvim，並移除那個把 codeLensProvider 設成 false 的
LspAttach autocmd。LazyVim 內建的 codelens 就會自己出現。
代價是它佔掉一整行，而且要自己處理 refresh 時機。
````

### 想關掉 inlay hints

````text
把 ["csharp|inlay_hints"] 底下的開關全部改成 false，
或整段拿掉（預設就是關的）。
也可以留著設定、用 LazyVim 的 <leader>uh 動態切換。
````

### 開 .cs 沒有 LSP

````text
開 .cs 檔沒有任何 LSP attach。
Roslyn 需要 .sln 或 .csproj 才會啟動 —— 先確認目錄往上找得到專案檔。
再確認：
  :Mason 裡 roslyn 是 installed
  ~/.local/share/nvim/mason/bin/roslyn-language-server --version 跑得起來
  dotnet --list-sdks 有輸出
如果 :MasonInstall roslyn 說找不到套件，就是少了 Crashdummyy registry。
````

### 想加別的語言的 LSP

````text
一般語言直接用 LazyVim 的 extra 就好（:LazyExtras），不要手接。
只有 C# 需要手接，因為 LazyVim 的 C# extra 綁的是 omnisharp。
````

---

## §3 驗收標準

跑 `./verify.sh`，或人工確認：

| 檢查 | 通過條件 |
|---|---|
| `roslyn-language-server --version` | 有版本輸出 |
| `dotnet --list-sdks` | 至少一個 SDK |
| headless 開 `.cs` | `client=roslyn` |
| `root_dir` | 等於專案目錄 |
| `codeLensProvider` | `false` |
| 診斷 | 含 `IDE0005`（analyzer 有跑） |

實測輸出：

```
client=roslyn
root=/tmp/tmp.hfdJY1iGIC
codeLensProvider=false
diagnostics=1
  [IDE0005] L1 Using directive is unnecessary.
```

---

## §4 為什麼這段提示詞要寫這麼細

這些是實際踩過、而且**從文件看不出來**的東西：

1. **roslyn 不在官方 mason registry** —— 錯誤訊息是
   `Package roslyn was not found`，看起來像打錯字，不會聯想到要加 registry。
2. **`csharp|inlay_hints` 用 `|` 分隔** —— 寫成 `.` 不會報錯，只是靜靜地沒效果。
3. **`filewatching = "off"`** —— 不關就一直噴 ENOENT，但錯誤訊息指向檔案系統，
   不會讓人聯想到是這個選項。
4. **codelens 要在 LspAttach 之後關** —— 這是改 client 端的 capability，
   不是叫 server 不要送，寫在 opts 裡沒有用。
5. **Roslyn 沒有 conform formatter** —— 會有人一直去調 conform 設定，
   但那條路徑對 `.cs` 根本是空的。
6. **treesitter parser 叫 `c_sharp`** —— 直覺會寫 `csharp`。
7. **驗收要用 analyzer 診斷不是語法錯誤** —— 用語法錯誤測會得到假陽性：
   parser 跑了但專案根本沒載入，一樣看得到紅線。
8. **明確禁止 `:Lazy sync`** —— 不然 AI 會順手升級所有外掛、動到 lockfile。
