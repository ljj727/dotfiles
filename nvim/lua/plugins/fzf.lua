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

      -- ── LSP 피커 (<leader>c* = 코드) ────────────────────────────────
      -- 0.11 내장 키(grr/gri/grt/gra/gO)는 결과를 quickfix 로 던진다.
      -- 이쪽은 같은 정보를 미리보기 붙은 fuzzy 목록으로 보여준다 —
      -- 후보가 여러 개일 때 어디로 갈지 고르고 나서 점프할 수 있다.
      -- 플러그인 추가는 없다. fzf-lua 가 원래 갖고 있던 기능이다.
      -- IDE 의 Ctrl+T. 클래스·함수 이름만 알면 프로젝트 어디든 바로 간다.
      -- 자주 쓰는 쪽에 소문자를 준다 — Shift 를 누르기 불편하다는 요청.
      -- 이 파일 심볼은 0.11 내장 gO 로도 되니 쉬운 키를 차지할 이유가 없다.
      { "<leader>cs", "<cmd>FzfLua lsp_live_workspace_symbols<CR>", desc = "심볼 (프로젝트 전체)" },
      { "<leader>cS", "<cmd>FzfLua lsp_document_symbols<CR>",       desc = "심볼 (이 파일)" },
      { "<leader>cr", "<cmd>FzfLua lsp_references<CR>",             desc = "참조 찾기" },
      { "<leader>cd", "<cmd>FzfLua lsp_definitions<CR>",            desc = "정의 목록" },
      { "<leader>ci", "<cmd>FzfLua lsp_implementations<CR>",        desc = "구현 목록" },
      { "<leader>ct", "<cmd>FzfLua lsp_typedefs<CR>",               desc = "타입 정의" },
      { "<leader>ca", "<cmd>FzfLua lsp_code_actions<CR>",           desc = "code action" },
      { "<leader>cx", "<cmd>FzfLua diagnostics_document<CR>",       desc = "진단 (이 파일)" },
      { "<leader>cX", "<cmd>FzfLua diagnostics_workspace<CR>",      desc = "진단 (프로젝트 전체)" },
    },
    opts = {
      winopts = {
        height = 0.85,
        width = 0.85,
        preview = { layout = "vertical", vertical = "down:45%" },
      },
      -- tmux 팝업·셸의 fzf 와 같은 조작감 (ctrl-j/k 로 이동)
      keymap = {
        builtin = { ["<C-d>"] = "preview-page-down", ["<C-u>"] = "preview-page-up" },
        fzf = { ["ctrl-j"] = "down", ["ctrl-k"] = "up" },
      },
    },
  },
}
