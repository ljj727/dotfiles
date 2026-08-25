-- snacks.nvim — 파일 트리(explorer) · 이미지 · 잡다한 UI 보조
--
-- 이미지 동작 조건
--   · 터미널이 kitty graphics protocol 지원 → Ghostty 필요
--   · ImageMagick(magick) 필요 — brew install imagemagick
--   · herdr 안에서는 [experimental] kitty_graphics = true 가 필요하다
--     (tmux 시절 allow-passthrough 에 해당). 기본값은 꺼짐이라,
--     현재는 herdr 밖의 맨 셸 창에서만 이미지가 보인다.
--   · SSH 세션에서는 파일명이 아니라 이미지 데이터를 직접 전송한다
return {
  {
    "folke/snacks.nvim",
    priority = 900,
    lazy = false,
    opts = {
      image = {
        enabled = true,
        doc = {
          enabled = true, -- markdown 등 문서 안의 이미지를 인라인 렌더
          inline = true,
          float = true,
          max_width = 80,
          max_height = 40,
        },
      },

      -- 파일 트리 사이드바. explorer 는 picker 위에 올라가 있어 picker 도 켠다.
      explorer = { enabled = true },
      picker = {
        enabled = true,
        sources = {
          explorer = {
            layout = { preset = "sidebar", preview = false },
            auto_close = false,
            hidden = true, -- 점파일도 보이게
            ignored = false, -- .gitignore 된 것은 숨김

            -- Tab: 오른쪽에 열되 커서는 트리에 남긴다.
            --
            -- 액션 이름 조합({ "jump", "focus_list" })이 아니라 직접 구현했다.
            -- 이름 해석·설정 병합 단계에서 조용히 실패하는 경우가 있어서,
            -- 파일 열기와 포커스 되돌리기를 명시적으로 수행한다.
            -- 커스텀 액션은 (picker, item) 을 받는다 (core/actions.lua 의 resolve).
            --
            -- Space 를 쓰지 않는 이유: leader 가 Space 라서 <leader>e 같은 조합의
            -- 시작인지 판단하려고 timeoutlen(400ms)을 기다리고 which-key 가 뜬다.
            -- 포커스가 입력창에 있을 수도 있어 list·input 양쪽에 등록한다.
            actions = {
              open_keep_focus = function(picker, item)
                if not item or item.dir then
                  return
                end

                local prev = vim.g.snacks_preview_buf

                -- 정식 jump 액션을 쓴다. 직접 vim.cmd("edit") 하면
                -- autocmd 발생 순서가 달라져 snacks.image 가 렌더하지 않는다.
                -- action.cmd 가 필요하므로 { cmd = "edit" } 을 명시적으로 넘긴다.
                require("snacks.picker.actions").jump(picker, item, { cmd = "edit" })

                local cur = vim.api.nvim_get_current_buf()
                vim.g.snacks_preview_buf = cur

                -- 이전에 Tab 으로 띄웠던 버퍼를 정리한다. 이게 없으면 Tab 을
                -- 누를 때마다 버퍼가 쌓이고, 같은 파일을 다시 열 때 이미 로드된
                -- 버퍼로 전환만 되어 이미지가 다시 렌더되지 않는다.
                -- 사용자가 편집했거나 다른 창에 떠 있으면 건드리지 않는다.
                if
                  prev
                  and prev ~= cur
                  and vim.api.nvim_buf_is_valid(prev)
                  and not vim.bo[prev].modified
                  and #vim.fn.win_findbuf(prev) == 0
                then
                  pcall(vim.api.nvim_buf_delete, prev, { force = false })
                end

                picker:focus("list", { show = true })
              end,
            },
            win = {
              list = { keys = { ["<Tab>"] = "open_keep_focus" } },
              input = { keys = { ["<Tab>"] = "open_keep_focus" } },
            },
          },
        },
      },

      bigfile = { enabled = true }, -- 큰 파일은 하이라이팅 끄고 가볍게
      quickfile = { enabled = true }, -- 파일을 즉시 그려 체감 시작 속도 개선
      notifier = { enabled = true }, -- vim.notify 를 하단 알림으로
      indent = { enabled = true }, -- 들여쓰기 안내선
      words = { enabled = true }, -- 커서 아래 단어와 같은 것 표시

      -- 쓰지 않는 것
      dashboard = { enabled = false },
      input = { enabled = false },
      scope = { enabled = false },
      scroll = { enabled = false }, -- 부드러운 스크롤 — 원격에서 렉이 생겨 끔
      statuscolumn = { enabled = false },
    },
    keys = {
      { "<leader>e", function() Snacks.explorer() end, desc = "파일 트리" },
      { "<leader>iv", function() Snacks.image.hover() end, desc = "커서 위치 이미지" },
      { "<leader>un", function() Snacks.notifier.hide() end, desc = "알림 지우기" },
    },
  },
}
