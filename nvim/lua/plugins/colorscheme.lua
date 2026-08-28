-- 터미널(Ghostty)·tmux 와 같은 Catppuccin Mocha 로 통일.
-- 2026-08-28: Dracula 에서 옮겼다. 색 정의는 세 곳에 있고 함께 고쳐야 한다 —
--   ghostty/config  theme = Catppuccin Mocha   (터미널 16색)
--   tmux/theme.conf @c_* 팔레트                (상태바·pane 바)
--   이 파일                                     (버퍼 안 구문 색)
return {
  {
    "catppuccin/nvim",
    name = "catppuccin", -- 저장소 이름이 nvim 이라 그대로 두면 헷갈린다
    priority = 1000, -- 다른 플러그인보다 먼저 로드해야 색이 깜빡이지 않는다
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = true, -- 터미널의 background-opacity/blur 가 보이게
        styles = {
          comments = { "italic" },
          keywords = { "italic" },
        },
        -- 기본 대비가 낮은 편이라 살짝 올린다. 반투명 배경 위에서 특히 체감된다.
        dim_inactive = { enabled = false },
        -- 쓰는 플러그인에만 통합을 켠다. 전부 켜면 로드가 느려지고,
        -- 안 쓰는 플러그인의 하이라이트까지 정의된다.
        integrations = {
          blink_cmp = true,
          gitsigns = true,
          treesitter = true,
          which_key = true,
          fzf = true,
          snacks = true,
          mini = { enabled = true },
          native_lsp = {
            enabled = true,
            underlines = {
              errors = { "undercurl" },
              warnings = { "undercurl" },
              hints = { "undercurl" },
              information = { "undercurl" },
            },
          },
        },
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
}
