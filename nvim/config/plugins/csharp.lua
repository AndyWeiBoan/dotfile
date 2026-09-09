-- C# / .NET LSP via roslyn.nvim (Microsoft.CodeAnalysis.LanguageServer)
-- 刻意不用 omnisharp / csharp-ls：只有 Roslyn 這支支援反編譯跳轉
-- (go-to-definition 進到沒有原始碼的型別)。

return {
  -- Mason ------------------------------------------------------------------
  -- roslyn 這個套件只存在於 Crashdummyy 的 registry，官方 mason-registry 沒有。
  -- 少加第二個 registry 就會出現 "Package roslyn was not found"。
  {
    "mason-org/mason.nvim",
    opts = {
      registries = {
        "github:mason-org/mason-registry",
        "github:Crashdummyy/mason-registry",
      },
      ensure_installed = { "roslyn" },
    },
  },

  -- roslyn.nvim ------------------------------------------------------------
  {
    "seblyng/roslyn.nvim",
    ft = "cs",
    opts = {
      -- 關閉檔案監控，否則 Roslyn 會對暫存/已刪除的檔案噴 ENOENT。
      filewatching = "off",
      broad_search = false,
      lock_target = false,

      config = {
        settings = {
          ["csharp|inlay_hints"] = {
            csharp_enable_inlay_hints_for_implicit_object_creation = true,
            csharp_enable_inlay_hints_for_implicit_variable_types = true,
            csharp_enable_inlay_hints_for_lambda_parameter_types = true,
            csharp_enable_inlay_hints_for_types = true,
            dotnet_enable_inlay_hints_for_indexer_parameters = true,
            dotnet_enable_inlay_hints_for_literal_parameters = true,
            dotnet_enable_inlay_hints_for_object_creation_parameters = true,
            dotnet_enable_inlay_hints_for_other_parameters = true,
            dotnet_enable_inlay_hints_for_parameters = true,
            dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = false,
            dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = false,
            dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = false,
          },
        },
      },
    },
  },

  -- Treesitter -------------------------------------------------------------
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "c_sharp" } },
  },

  -- Reference 數量 ---------------------------------------------------------
  -- 內建 codelens 換成 symbol-usage.nvim：不佔一整行，且不需要 codelens refresh。
  {
    "Wansmer/symbol-usage.nvim",
    event = "LspAttach",
    opts = {},
  },
  {
    "neovim/nvim-lspconfig",
    init = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("csharp_disable_codelens", { clear = true }),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client then
            client.server_capabilities.codeLensProvider = false
          end
        end,
      })
    end,
  },

  -- C# 檔案的格式化鍵位 ----------------------------------------------------
  -- Roslyn 沒有 conform/none-ls formatter，直接打 LSP。
  {
    "stevearc/conform.nvim",
    optional = true,
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("csharp_format_keys", { clear = true }),
        pattern = "cs",
        callback = function(args)
          vim.keymap.set("v", "=", function()
            vim.lsp.buf.format({ async = false })
          end, { buffer = args.buf, desc = "Format selection (Roslyn)" })

          vim.keymap.set("n", "==", function()
            vim.lsp.buf.format({ async = false })
          end, { buffer = args.buf, desc = "Format buffer (Roslyn)" })
        end,
      })
    end,
  },
}
