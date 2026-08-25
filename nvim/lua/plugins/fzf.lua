-- 파일 탐색 + 그렙. telescope 보다 가볍고, 이미 설치된 fd·ripgrep 을 그대로 쓴다.
return {
  {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    keys = {
      { "<leader><space>", "<cmd>FzfLua files<CR>", desc = "파일 찾기" },
      { "<leader>ff", "<cmd>FzfLua files<CR>", desc = "파일 찾기" },
      { "<leader>fg", "<cmd>FzfLua live_grep<CR>", desc = "전역 그렙" },
      { "<leader>fb", "<cmd>FzfLua buffers<CR>", desc = "버퍼 목록" },
      { "<leader>fh", "<cmd>FzfLua helptags<CR>", desc = "도움말 검색" },
      { "<leader>fr", "<cmd>FzfLua oldfiles<CR>", desc = "최근 파일" },
      { "<leader>fw", "<cmd>FzfLua grep_cword<CR>", desc = "커서 단어 그렙" },
      { "<leader>fc", "<cmd>FzfLua commands<CR>", desc = "명령 목록" },
      { "<leader>fs", "<cmd>FzfLua git_status<CR>", desc = "git 변경 파일" },
    },
    opts = {
      winopts = {
        height = 0.85,
        width = 0.85,
        preview = { layout = "vertical", vertical = "down:45%" },
      },
      -- 셸의 fzf 와 같은 조작감 (ctrl-j/k 로 이동)
      keymap = {
        builtin = { ["<C-d>"] = "preview-page-down", ["<C-u>"] = "preview-page-up" },
        fzf = { ["ctrl-j"] = "down", ["ctrl-k"] = "up" },
      },
    },
  },
}
