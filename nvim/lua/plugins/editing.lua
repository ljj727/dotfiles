-- 편집 보조. mini.* 는 각각 독립 모듈이라 가볍다.
--
-- 참고: 주석 토글(gcc / gc)과 괄호 매칭 하이라이팅은 Neovim 0.10+ 에 내장돼
--       있으므로 Comment.nvim 같은 플러그인이 필요하지 않다.
return {
  -- 괄호·따옴표 자동 닫기
  {
    "echasnovski/mini.pairs",
    event = "InsertEnter",
    opts = {},
  },

  -- 둘러싸기: saiw" (단어를 "로 감싸기), sd" (제거), sr"' (교체)
  {
    "echasnovski/mini.surround",
    keys = { "sa", "sd", "sr", "sf", "sF", "sh" },
    -- init.lua 의 defaults.cond 가 VSCode 안에서 모든 플러그인을 막는데,
    -- 이건 예외로 살린다. UI 를 그리지 않고 버퍼 텍스트만 고치는 동작이라
    -- VSCode 와 충돌할 일이 없고, VSCode 에는 대응 기능이 없다.
    cond = true,
    opts = {},
  },

  -- TODO / FIXME / HACK 등을 눈에 띄게 + 목록으로 찾기
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = { signs = false },
    keys = {
      { "<leader>ft", "<cmd>TodoQuickFix<CR>", desc = "TODO 목록" },
      { "]t", function() require("todo-comments").jump_next() end, desc = "다음 TODO" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "이전 TODO" },
    },
  },

  -- 버퍼를 닫아도 창 배치가 깨지지 않는다.
  -- 기본 :bdelete 는 그 버퍼를 띄운 창까지 닫아버린다.
  {
    "echasnovski/mini.bufremove",
    keys = {
      {
        "<leader>bd",
        function() require("mini.bufremove").delete(0, false) end,
        desc = "버퍼 닫기 (창 유지)",
      },
      {
        "<leader>bD",
        function() require("mini.bufremove").delete(0, true) end,
        desc = "버퍼 강제 닫기",
      },
    },
  },

  -- undo 이력을 트리로 보고 되돌린다. undofile 을 켜뒀으므로 세션을 닫아도 남는다.
  {
    "mbbill/undotree",
    cmd = "UndotreeToggle",
    keys = {
      { "<leader>uu", "<cmd>UndotreeToggle<CR>", desc = "undo 트리" },
    },
  },
}
