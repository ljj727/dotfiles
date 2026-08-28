-- ============================================================================
-- Neovim — 직접 구성 (kickstart 방식)
--
-- 원칙
--   · 모든 줄을 이해한 상태를 유지한다. 이해 못 하는 설정은 넣지 않는다
--   · 플러그인은 최소로. 역할이 겹치는 것을 두지 않는다
--
-- LSP 방침 (2026-08-26 변경)
--   원래는 "LSP 를 넣지 않는다 — 코드 인텔리전스는 Claude Code 가 담당" 이었다.
--   써 보니 둘은 겹치지 않아 방침을 바꿨다:
--     · LSP         = 즉각적·기계적 정확성. gd 점프, 실시간 타입 오류, 참조 찾기.
--                     0.05초에 끝나고 물어볼 필요가 없다
--     · Claude Code = 이해와 판단. "왜 이렇게 짰나", 리팩터링, 버그 추적
--   설정은 lua/plugins/lsp.lua 하나이고, 서버 바이너리가 있으면 켜지고 없으면
--   조용히 안 켜진다. 그래서 이 설정을 원격 서버에 그대로 배포해도 안전하다.
--
-- 이전 상태(LazyVim)로 되돌리려면:
--   cd ~/dotfiles && git checkout nvim-lazyvim-final -- nvim/
-- ============================================================================

-- leader 는 플러그인 로드 전에 정해야 한다 (플러그인이 이걸 기준으로 키를 잡음)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- ── 기본 동작 ───────────────────────────────────────────────────────────────
local opt = vim.opt

opt.number = true
opt.relativenumber = true -- 상대 줄번호 — 10j 같은 이동에 유용
opt.signcolumn = "yes" -- git 표시가 들락날락하며 화면이 흔들리는 것 방지
opt.cursorline = true
opt.scrolloff = 8 -- 커서 위아래로 최소 8줄 남김
opt.sidescrolloff = 8
opt.wrap = false

opt.expandtab = true -- 탭 대신 스페이스
opt.tabstop = 2
opt.shiftwidth = 2
opt.smartindent = true

opt.ignorecase = true -- 검색은 대소문자 무시
opt.smartcase = true --   단 대문자를 쓰면 구분
opt.hlsearch = false -- 검색 후 하이라이트가 계속 남지 않게
opt.incsearch = true

opt.splitright = true -- 새 분할은 오른쪽·아래로 (tmux 습관과 일치)
opt.splitbelow = true

opt.undofile = true -- nvim 을 닫아도 undo 이력 유지
opt.swapfile = false
opt.backup = false

opt.termguicolors = true -- 24bit 색 (Ghostty 가 RGB 지원)
opt.updatetime = 250 -- 진단·gitsigns 반응 속도
opt.timeoutlen = 400 -- 키 조합 대기 시간
opt.mouse = "a"
opt.clipboard = "unnamedplus" -- 시스템 클립보드 공유
opt.confirm = true -- 저장 안 한 버퍼를 닫을 때 물어봄

-- ── 키맵 ────────────────────────────────────────────────────────────────────
local map = vim.keymap.set

-- insert 모드에서 jk 로 빠져나오기 (기존 손버릇)
map("i", "jk", "<Esc>", { desc = "Esc" })

-- 검색 하이라이트 지우기
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "하이라이트 해제" })

-- 창 이동 — tmux 의 prefix+hjkl 과 같은 감각
map("n", "<C-h>", "<C-w>h", { desc = "왼쪽 창" })
map("n", "<C-j>", "<C-w>j", { desc = "아래 창" })
map("n", "<C-k>", "<C-w>k", { desc = "위 창" })
map("n", "<C-l>", "<C-w>l", { desc = "오른쪽 창" })

-- 버퍼 이동 — S-h/S-l 과 [b/]b 둘 다.
-- [ ] 접두사는 vim 관례(unimpaired 스타일)이고 ]h(git hunk)와 결이 맞는다.
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "이전 버퍼" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "다음 버퍼" })
map("n", "[b", "<cmd>bprevious<CR>", { desc = "이전 버퍼" })
map("n", "]b", "<cmd>bnext<CR>", { desc = "다음 버퍼" })

-- quickfix 항목 이동 (grug-far 로 전역 치환할 때 결과를 훑는 데 쓴다)
map("n", "[q", "<cmd>cprevious<CR>", { desc = "이전 quickfix" })
map("n", "]q", "<cmd>cnext<CR>", { desc = "다음 quickfix" })
map("n", "<leader>xq", "<cmd>copen<CR>", { desc = "quickfix 열기" })

-- 버퍼 정리
map("n", "<leader>bo", "<cmd>%bdelete|edit#|bdelete#<CR>", { desc = "다른 버퍼 모두 닫기" })

-- 시각 모드에서 들여쓰기 후에도 선택 유지
map("v", "<", "<gv")
map("v", ">", ">gv")

-- 선택 영역 위아래로 이동
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "아래로 이동" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "위로 이동" })

-- 저장·종료
map("n", "<leader>w", "<cmd>write<CR>", { desc = "저장" })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "닫기" })

-- ── 자동 명령 ───────────────────────────────────────────────────────────────
-- yank 한 영역을 잠깐 하이라이트 (뭘 복사했는지 눈으로 확인)
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "yank 하이라이트",
  callback = function()
    vim.hl.on_yank()
  end,
})

-- 글을 쓰는 파일에서는 코드와 다른 설정이 필요하다.
-- wrap=false 는 코드에는 맞지만 문장이 화면 밖으로 잘려 글에는 못 쓴다.
vim.api.nvim_create_autocmd("FileType", {
  desc = "문서 파일은 줄바꿈·맞춤법 켜기",
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true -- 단어 중간에서 끊지 않고 어절 단위로 감싼다
    vim.opt_local.breakindent = true -- 감긴 줄도 들여쓰기 유지 (목록이 안 깨짐)
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us" -- 한글은 사전이 없어 영어만 검사
    -- 감긴 줄에서도 j/k 가 "보이는 한 줄" 단위로 움직이게
    vim.keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, buffer = true })
    vim.keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, buffer = true })
  end,
})

-- ── 플러그인 매니저 (lazy.nvim) ─────────────────────────────────────────────
-- LazyVim(배포판)과 lazy.nvim(매니저)은 별개다. 매니저만 쓴다.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("lazy.nvim 설치 실패:\n" .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

-- [VSCode 안에서는 플러그인을 로드하지 않는다]
-- vscode-neovim 확장은 nvim 을 띄우고 g:vscode 를 1 로 설정한다. 이때 UI 는
-- VSCode 가 그리므로 상태줄(lualine)·탭줄(bufferline)·파일트리(snacks)·
-- LSP·자동완성·git 표시는 전부 VSCode 쪽과 중복이고, 서로 화면을 잡으려 해
-- 충돌한다. 편집 동작(모션·텍스트오브젝트)만 nvim 이 맡으면 된다.
--
-- lazy.nvim 의 defaults.cond 가 정확히 이 용도다(공식 주석에 vscode 예시가 있다).
-- 각 플러그인 파일을 고칠 필요 없이 여기서 한 번에 막는다.
--
-- VSCode 에서도 살리고 싶은 플러그인이 생기면 그 spec 에만
-- `cond = true` 를 명시하면 이 전역 설정을 덮는다.
--   예: mini.surround 는 순수 텍스트 조작이라 VSCode 안에서도 유용하다.
local in_vscode = vim.g.vscode ~= nil

require("lazy").setup({
  spec = { { import = "plugins" } },
  defaults = { cond = not in_vscode },
  install = { colorscheme = { "habamax" } },
  checker = { enabled = false }, -- 업데이트 자동 확인 끔
  change_detection = { notify = false },
})

-- ── VSCode 전용 키맵 ────────────────────────────────────────────────────────
-- 플러그인이 전부 꺼져 있으므로(위 defaults.cond) fzf-lua 의 <leader>f* 가
-- 없다. 손버릇은 유지하면서 VSCode 의 대응 기능이 뜨게 연결한다.
--
-- [floating 미리보기는 포기해야 한다] vscode-neovim 은 nvim 의 floating
-- window 를 그리지 못한다 — UI 를 ext_multigrid 로 받으면서도 win_float_pos
-- 이벤트 핸들러가 없다(확장 번들에서 확인). 그래서 fzf-lua 창 자체가 화면에
-- 나타나지 않는다. 대신 VSCode 의 Quick Open 이 같은 자리를 대신한다.
--
-- ⌘P·⇧⌘F 같은 VSCode 기본 키는 그대로 두고, leader 키만 추가로 얹는다.
if vim.g.vscode then
  -- pcall 로 감싼다. 이 모듈은 vscode-neovim 확장이 런타임 경로에 넣어주는
  -- 것이라 확장 밖(예: g:vscode 만 켜고 띄우는 테스트)에서는 없다.
  -- require 가 실패하면 init.lua 전체가 중단되므로 조용히 건너뛴다.
  local ok, vscode = pcall(require, "vscode")
  if not ok then return end
  local function act(cmd, opts)
    return function() vscode.action(cmd, opts) end
  end
  local map = vim.keymap.set

  map("n", "<leader><space>", act("workbench.action.quickOpen"), { desc = "파일 찾기" })
  map("n", "<leader>ff", act("workbench.action.quickOpen"), { desc = "파일 찾기" })
  map("n", "<leader>fb", act("workbench.action.showAllEditors"), { desc = "버퍼 목록" })
  map("n", "<leader>fc", act("workbench.action.showCommands"), { desc = "명령 목록" })
  map("n", "<leader>fg", act("workbench.action.findInFiles"), { desc = "전역 그렙" })
  map("n", "<leader>fr", act("workbench.action.openRecent"), { desc = "최근 파일" })
  map("n", "<leader>fs", act("workbench.view.scm"), { desc = "git 변경 파일" })
  -- 커서 아래 단어로 검색을 채워서 연다. seedWithNearestWord 설정에 기대지
  -- 않고 인자로 직접 넘긴다 — 그 설정은 검색창이 "포커스를 받을 때"만 듣는다.
  map("n", "<leader>fw", function()
    vscode.action("workbench.action.findInFiles", { args = { query = vim.fn.expand("<cword>") } })
  end, { desc = "커서 단어 그렙" })

  -- 대응이 없어 뺀 것:
  --   <leader>fh  도움말 검색 — nvim :help 라 VSCode 에 개념이 없다
  --   <leader>ft  TODO 목록   — 내장 기능이 아니다 (todo-tree 같은 확장 필요)
end

