-- 포매팅 — conform.nvim
--
-- [설계] lsp.lua 와 같은 원칙: 포매터가 있으면 쓰고 없으면 조용히 넘어간다.
--   conform 은 formatters_by_ft 에 적힌 것 중 "실행 가능한 첫 번째"를 쓰고,
--   하나도 없으면 lsp_format = "fallback" 에 따라 LSP 포매팅으로 넘긴다.
--   그것도 없으면 아무 일도 일어나지 않는다 — 오류가 아니다.
--
-- [저장 시 자동 포매팅은 끈다] 남의 코드를 열었다가 저장만 해도 파일 전체가
--   바뀌어 diff 가 폭발하는 사고를 막는다. <leader>f 로 명시적으로 부른다.
--   켜고 싶으면 아래 format_on_save 주석을 풀면 된다.

return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      -- <leader>c* = 코드(LSP) 네임스페이스. 처음엔 <leader>f 였는데 그러면
      -- <leader>ff/fg(fzf 찾기)의 접두사가 되어 포매팅이 timeoutlen 만큼
      -- 기다렸다 실행된다. fzf 네임스페이스를 침범하지 않도록 옮겼다.
      {
        "<leader>cf",
        function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
        mode = { "n", "v" },
        desc = "포매팅",
      },
    },
    opts = {
      -- 왼쪽부터 찾아서 설치된 첫 번째를 쓴다.
      formatters_by_ft = {
        lua        = { "stylua" },
        python     = { "ruff_format", "black" },
        javascript = { "prettierd", "prettier" },
        typescript = { "prettierd", "prettier" },
        javascriptreact = { "prettierd", "prettier" },
        typescriptreact = { "prettierd", "prettier" },
        json       = { "prettierd", "prettier" },
        yaml       = { "prettierd", "prettier" },
        markdown   = { "prettierd", "prettier" },
        go         = { "gofmt" },
        rust       = { "rustfmt" },
        c          = { "clang-format" },
        cpp        = { "clang-format" },
        java       = { "google-java-format" },
        sh         = { "shfmt" },
      },
      -- 위 목록에 없는 파일타입은 LSP 포매팅으로 넘긴다.
      default_format_opts = { lsp_format = "fallback" },
      -- format_on_save = { timeout_ms = 500, lsp_format = "fallback" },
    },
  },
}
