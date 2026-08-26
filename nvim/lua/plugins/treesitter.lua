-- 구문 하이라이팅·구조 인식 담당. LSP 와 역할이 다르다 —
-- treesitter 는 "구문"(이게 함수 선언이다), LSP 는 "의미"(이 이름이 무엇을
-- 가리키며 어디에 정의됐다). 그래서 LSP 를 넣은 뒤에도 그대로 필요하다.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master", -- main 브랜치는 API 재작성 중이라 안정된 master 사용
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      -- 실제 작업 파일 분포에 맞춘 것 (js/ts 다수, md, json, py, yaml, toml, sh)
      ensure_installed = {
        "lua", "vim", "vimdoc", "query",
        "javascript", "typescript", "tsx", "json", "jsonc",
        "python", "bash", "markdown", "markdown_inline",
        "yaml", "toml", "dockerfile", "sql", "css", "html",
        "c", "cpp", "gitcommit", "diff",
      },
      auto_install = false, -- 원격 서버에서 컴파일러 없이 실패하는 것 방지
      highlight = { enable = true },
      indent = { enable = true },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-space>",
          node_incremental = "<C-space>",
          node_decremental = "<BS>",
        },
      },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
}
