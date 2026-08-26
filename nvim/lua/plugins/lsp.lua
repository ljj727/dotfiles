-- LSP — 정의로 점프·참조 찾기·실시간 진단·의미 기반 자동완성.
--
-- [설계] "있으면 켜고 없으면 조용히 안 켠다"
--   서버 바이너리가 있는지 vim.fn.executable() 로 보고, 있는 것만 활성화한다.
--   그래서 이 파일 하나를 맥과 원격 서버에 똑같이 배포해도 된다 — 서버에
--   node/go/JDK 가 없으면 그 LSP 만 안 뜨고 나머지는 정상 동작한다.
--   설치는 :Mason 에서 필요할 때 하나씩. 안 쓰는 언어는 안 깔면 그만이다.
--
-- [Neovim 0.11 네이티브 API] vim.lsp.config / vim.lsp.enable 을 쓴다.
--   nvim-lspconfig 는 lsp/<이름>.lua 로 서버별 기본값(실행 인자·파일타입·
--   루트 탐지)만 제공하고, 켜고 끄는 판단은 아래 루프가 한다.
--
-- [0.11 기본 키맵을 건드리지 않는다] 이미 내장된 것:
--   grr 참조 · gri 구현 · grn rename · gra code action · grt 타입정의
--   gO 문서심볼 · [d ]d 진단이동 · K 호버(LSP 붙으면 자동)
--   gr 은 저것들의 "접두사"라 gr 을 참조에 직접 매핑하면 5개가 다 깨진다.
--   그래서 여기서는 기본에 없는 gd/gD 만 추가한다.

-- [실행파일 이름을 손으로 적지 않는다]
--   서버 이름과 실행파일이 다른 경우가 흔하다 — pyright 는 pyright-langserver,
--   basedpyright 는 basedpyright-langserver 로 뜬다. 표를 손으로 유지하면
--   반드시 어긋난다(실제로 basedpyright 만 적어 두는 바람에 설치해 둔
--   pyright 를 못 잡았다). 그래서 lspconfig 설정에서 직접 읽는다.
--
-- cmd 가 함수인 서버만 예외로 적는다 (정적으로 읽을 수 없다).
local CMD_OVERRIDE = {
  jdtls = "jdtls",
  ts_ls = "typescript-language-server",
}

-- [택일] 같은 일을 하는 서버들. 앞에서부터 찾아 처음 발견된 하나만 켠다.
--   여러 개가 깔려 있으면 전부 붙어 같은 진단이 두 번 뜬다.
local PICK_ONE = {
  python = { "basedpyright", "pyright", "pylsp" },  -- 타입체크·정의점프
  ts     = { "vtsls", "ts_ls" },                    -- js/ts/jsx/tsx (react 포함)
}

-- [단독] 역할이 겹치지 않아 있으면 그냥 켠다.
--   ruff 는 린트·포매팅 전담이라 위 python 타입체커와 함께 쓰는 게 정상이다.
local ALWAYS = {
  "ruff",
  "gopls",         -- go
  "rust_analyzer", -- rust
  "clangd",        -- c/c++
  "jdtls",         -- java
  -- 요청 목록에는 없었지만 이 repo 자체가 lua 라서 넣어 둔다.
  -- 불필요하면 이 줄만 지우면 된다 (없으면 어차피 안 켜진다).
  "lua_ls",
}

-- lspconfig 가 이 서버를 띄울 때 쓰는 실행파일 이름
local function exe_of(name)
  local ok, cfg = pcall(function() return vim.lsp.config[name] end)
  local cmd = ok and cfg and cfg.cmd
  if type(cmd) == "table" then return cmd[1] end
  return CMD_OVERRIDE[name]
end

local function have(name)
  local exe = exe_of(name)
  return exe ~= nil and vim.fn.executable(exe) == 1, exe
end

return {
  -- Mason — 서버를 "구하는" 수단일 뿐, LSP 동작이 여기 의존하지 않는다.
  -- :Mason 으로 골라 설치하면 ~/.local/share/nvim/mason/bin 이 PATH 에 붙어
  -- 아래 executable 검사에 자동으로 걸린다. 서버에 Mason 이 못 깔아도 무방.
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    opts = { ui = { border = "rounded" } },
  },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    -- :LspStatus 는 파일을 열기 전에도 쓸 수 있어야 한다. 이게 없으면
    -- 빈 nvim 에서 "Not an editor command" 가 난다 (지연 로드라 아직 config
    -- 가 안 돌아 명령이 등록되지 않은 상태). cmd 를 적어 두면 lazy.nvim 이
    -- 그 명령을 가로채 플러그인을 먼저 로드한다.
    cmd = { "LspStatus" },
    dependencies = { "mason-org/mason.nvim", "saghen/blink.cmp" },
    config = function()
      -- ── 진단 표시 ────────────────────────────────────────────────────
      -- 기본값은 virtual_text 가 꺼져 있어 오류가 눈에 안 띈다.
      vim.diagnostic.config({
        virtual_text = { spacing = 2, prefix = "●" },
        severity_sort = true,
        float = { border = "rounded", source = true },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN]  = " ",
            [vim.diagnostic.severity.INFO]  = " ",
            [vim.diagnostic.severity.HINT]  = " ",
          },
        },
      })

      -- ── 자동완성 능력 전달 ───────────────────────────────────────────
      -- blink.cmp 가 지원하는 기능(스니펫·추가 편집 등)을 서버에 알린다.
      -- '*' 는 모든 서버에 적용되는 0.11 의 와일드카드.
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      -- ── 있는 것만 켠다 ───────────────────────────────────────────────
      local enabled, missing, skipped = {}, {}, {}

      -- 택일 그룹: 처음 발견된 하나만. 나머지는 "겹쳐서 건너뜀"으로 기록한다.
      for _, group in pairs(PICK_ONE) do
        local won = nil
        for _, name in ipairs(group) do
          local ok = have(name)
          if ok and not won then
            vim.lsp.enable(name)
            enabled[#enabled + 1] = name
            won = name
          elseif ok then
            skipped[#skipped + 1] = name .. " (" .. won .. " 사용 중)"
          end
        end
        if not won then
          missing[#missing + 1] = table.concat(group, "|")
        end
      end

      -- 단독 서버
      for _, name in ipairs(ALWAYS) do
        local ok, exe = have(name)
        if ok then
          vim.lsp.enable(name)
          enabled[#enabled + 1] = name
        else
          missing[#missing + 1] = exe or name
        end
      end

      table.sort(enabled)
      table.sort(missing)
      table.sort(skipped)

      -- :LspStatus 로 지금 뭐가 켜졌고 뭐가 없는지 본다.
      -- (없는 서버는 오류가 아니라 "안 깐 것"이므로 시작 시 경고하지 않는다.)
      vim.api.nvim_create_user_command("LspStatus", function()
        local lines = { "활성: " .. (next(enabled) and table.concat(enabled, ", ") or "없음") }
        if next(skipped) then
          lines[#lines + 1] = "중복 건너뜀: " .. table.concat(skipped, ", ")
        end
        if next(missing) then
          lines[#lines + 1] = "미설치: " .. table.concat(missing, ", ")
          lines[#lines + 1] = "  → :Mason 에서 설치하면 다음 실행부터 자동으로 켜진다"
        end
        vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
      end, { desc = "LSP 서버 활성/미설치 목록" })

      -- ── 키맵 — LSP 가 붙은 버퍼에서만 ────────────────────────────────
      vim.api.nvim_create_autocmd("LspAttach", {
        desc = "LSP 키맵",
        callback = function(ev)
          local function map(key, fn, desc)
            vim.keymap.set("n", key, fn, { buffer = ev.buf, desc = "LSP: " .. desc })
          end
          -- 0.11 기본에 없는 것만 추가한다. 나머지는 위 주석의 내장 키맵 참고.
          map("gd", vim.lsp.buf.definition, "정의로 이동")
          map("gD", vim.lsp.buf.declaration, "선언으로 이동")
          map("<leader>e", vim.diagnostic.open_float, "진단 상세 보기")
        end,
      })
    end,
  },
}
