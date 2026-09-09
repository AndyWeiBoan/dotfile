# Neovim LSP — C# / .NET via Roslyn

在 LazyVim 上把 C# 的 LSP 換成微軟官方的
**Microsoft.CodeAnalysis.LanguageServer（Roslyn）**，
而不是 omnisharp 或 csharp-ls。

| 檔案 | 內容 |
|---|---|
| `install.sh` | 安裝腳本，可重複執行 |
| `verify.sh` | 端對端驗證：實際開一個 C# 專案，確認 LSP attach 且有診斷 |
| `config/plugins/csharp.lua` | 設定本體，安裝到 `~/.config/nvim/lua/plugins/csharp.lua` |
| `config/.neoconf.json` | lua_ls 的 neoconf 設定 |
| `PROMPT.md` | 給 AI 的完整重建提示詞（換機器時用這個） |

---

## 一、現況

底層是 **LazyVim**，`~/.config/nvim` 幾乎是原廠 starter：

```
~/.config/nvim/
├── init.lua                  只有 require("config.lazy")
├── lua/config/*.lua          LazyVim starter 原樣，沒有 LSP 相關內容
├── lua/plugins/example.lua   LazyVim 範例檔，開頭是 `if true then return {} end`，等於沒作用
└── lua/plugins/csharp.lua    ← 唯一的自訂內容，全部的 LSP 工作都在這裡
```

`lazyvim.json` 的 `extras` 是空的 —— **沒有啟用 LazyVim 內建的 C# extra**，
因為那個 extra 裝的是 omnisharp。整套是自己接的。

本機實測版本：

```
Neovim                 0.12.5
LazyVim                c10948c5 (2026-06-02)
roslyn.nvim            seblyng/roslyn.nvim @ de9a98d6
Roslyn LS              5.12.0-1.26452.1
.NET SDK               10.0.400（由 mise 提供）
mason registry         Crashdummyy/mason-registry @ 2026-09-04-pumped-sponge
```

---

## 二、為什麼是 Roslyn，不是 omnisharp

C# 在 Neovim 上有三個選擇：

| 方案 | 狀況 |
|---|---|
| **omnisharp** | LazyVim 內建 extra 用的。舊、慢，反編譯跳轉支援不完整 |
| **csharp-ls** | 輕量，但功能少，一樣沒有完整的反編譯跳轉 |
| **Roslyn（本設定）** | 微軟自家、VS Code C# Dev Kit 用的同一支。**唯一支援反編譯跳轉的** |

決定性的差異是**反編譯跳轉** —— 對一個沒有原始碼的型別（例如
`System.Collections.Generic.List<T>`）按 go-to-definition，
Roslyn 會反編譯出 C# 給你看，另外兩個不行。

代價是它**不在官方 mason registry 裡**，要多設一個 registry（見下）。

---

## 三、怎麼安裝

### 1. .NET SDK

Roslyn LS 是 .NET 程式，需要 runtime。本機用 mise 管：

```bash
mise use -g dotnet@latest
```

`~/.config/mise/config.toml` 目前是：

```toml
[tools]
dotnet = "latest"     # → 10.0.400
```

裝在 `~/.local/share/mise/dotnet-root/sdk`。

### 2. 第二個 mason registry（關鍵步驟）

`roslyn` 這個套件**只存在於 `Crashdummyy/mason-registry`**，
官方 `mason-org/mason-registry` 沒有。少加這一個 registry，
`:MasonInstall roslyn` 就會回 **`Package roslyn was not found`**。

在 `csharp.lua` 裡設定：

```lua
{
  "mason-org/mason.nvim",
  opts = {
    registries = {
      "github:mason-org/mason-registry",     -- 官方的要留著，其他工具靠它
      "github:Crashdummyy/mason-registry",   -- roslyn 在這裡
    },
    ensure_installed = { "roslyn" },
  },
}
```

這個寫法能成立，是因為 LazyVim 的 mason 設定是
`require("mason").setup(opts)` 直接把 `opts` 丟進去，
再自己處理 `ensure_installed`
（見 `LazyVim/lua/lazyvim/plugins/lsp/init.lua:294`）。
所以 `registries` 會原封不動傳給 mason，`ensure_installed` 由 LazyVim 迴圈安裝。

### 3. 安裝與驗證

```bash
./install.sh        # 複製設定 + 同步外掛 + 安裝 roslyn
./verify.sh         # 開一個真的 C# 專案確認 LSP 會 attach
```

裝完的位置：

```
~/.local/share/nvim/mason/packages/roslyn/libexec/Microsoft.CodeAnalysis.LanguageServer.dll
~/.local/share/nvim/mason/bin/roslyn-language-server
```

---

## 四、設定了什麼

全部在 `config/plugins/csharp.lua`。逐段說明：

### 4.1 roslyn.nvim

```lua
{
  "seblyng/roslyn.nvim",
  ft = "cs",
  opts = {
    filewatching = "off",
    broad_search = false,
    lock_target = false,
    ...
  },
}
```

- **`filewatching = "off"`** —— 不關的話 Roslyn 會對暫存檔／已刪除的檔案噴 `ENOENT`。
  這是最吵的一個問題，關掉最乾淨。
- **`broad_search = false`** —— 只在目前目錄往上找 `.sln` / `.csproj`，不要掃整個樹。
- **`lock_target = false`** —— 允許在多個 solution 之間切換。

### 4.2 Inlay hints

`["csharp|inlay_hints"]` 底下把十幾個開關全開：型別、參數名、lambda 參數、
隱含 `new`、`var` 的實際型別等等。

注意這個 key 的格式是 **`csharp|inlay_hints`（用 `|` 分隔）**，
這是 Roslyn LS 自己的設定命名空間，不是 nvim 的慣例，寫錯不會報錯、只是沒效果。

### 4.3 Reference 數量：換掉 codelens

LazyVim 預設用 LSP codelens 顯示 reference 數量，但它**佔掉一整行**，
而且需要手動 refresh。改用 `symbol-usage.nvim`，顯示在行尾的 virtual text。

所以要**主動關掉 Roslyn 的 codelens**，否則兩者會同時出現：

```lua
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("csharp_disable_codelens", { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client then
      client.server_capabilities.codeLensProvider = false
    end
  end,
})
```

> 這段是**在 client 附加之後改掉 capability**，不是叫 server 不要送。
> `verify.sh` 會檢查 `codeLensProvider` 執行期確實是 `false`。

### 4.4 格式化鍵位

Roslyn **沒有對應的 conform / none-ls formatter**，
所以 LazyVim 那套 `conform.nvim` 的格式化路徑對 `.cs` 檔是空的。
直接綁鍵位打 LSP：

```lua
vim.keymap.set("v", "=",  function() vim.lsp.buf.format({ async = false }) end, ...)
vim.keymap.set("n", "==", function() vim.lsp.buf.format({ async = false }) end, ...)
```

只在 `FileType cs` 時綁 buffer-local，不影響其他語言的 `=` 行為。

### 4.5 Treesitter

```lua
{ "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "c_sharp" } } }
```

parser 名稱是 **`c_sharp`**（底線），不是 `csharp` 也不是 `cs`。

---

## 五、驗證

```bash
./verify.sh
```

它不是檢查「設定檔長得對不對」，而是**真的建一個最小 C# 專案、
用 headless nvim 開檔、等 LSP attach、讀回執行期狀態**：

```
client=roslyn  codeLensProvider=false
diagnostics=1
  [IDE0005] L1 Using directive is unnecessary.
```

三件事同時成立才算通過：

1. `client=roslyn` —— LSP 有 attach，而且 root_dir 正確指到專案目錄
2. `codeLensProvider=false` —— §4.3 的 autocmd 真的生效了
3. 有 `IDE0005` 這種 **analyzer 診斷** —— 代表 Roslyn 不只啟動，
   而是真的載入專案、跑完分析（只有語法錯誤的話不能證明這件事）

---

## 六、疑難排解

| 症狀 | 原因 / 解法 |
|---|---|
| `Package roslyn was not found` | 少了 `Crashdummyy/mason-registry`，見 §3.2 |
| 開 `.cs` 沒有任何 LSP | 目錄裡沒有 `.sln` 或 `.csproj`；Roslyn 需要專案檔才會 attach |
| 一直噴 `ENOENT` | `filewatching` 沒設成 `"off"` |
| Reference 數量出現兩次 | 停用 codelens 的 autocmd 沒生效，跑 `./verify.sh` 確認 |
| `=` 在 `.cs` 沒反應 | Roslyn 沒有 conform formatter，要靠 §4.4 的鍵位 |
| Inlay hints 沒出現 | 檢查 key 是不是寫成 `csharp|inlay_hints`（`|` 不是 `.`） |
| LSP 啟動極慢 | 第一次要還原 NuGet 套件，`dotnet restore` 先跑一次會快很多 |

```vim
:LspInfo                      " 有沒有 attach、root_dir 在哪
:Mason                        " roslyn 裝好了沒
:checkhealth lazy             " 外掛狀態
:lua =vim.lsp.get_clients()   " 執行期 client 細節
```

```bash
~/.local/share/nvim/mason/bin/roslyn-language-server --version   # LS 本身跑不跑得起來
dotnet --list-sdks                                              # .NET 在不在
```
