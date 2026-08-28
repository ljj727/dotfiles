-- 상태줄 · 버퍼 탭줄 · 키맵 안내
return {
  -- 상태줄
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "catppuccin",
        globalstatus = true, -- 분할해도 상태줄은 화면 아래 하나만
        -- 둥근 캡 (U+E0B4 / U+E0B6). FiraCode Nerd Font 에 두 글리프가 있는지
        -- fontTools 로 확인했다 — 없으면 두부(□)로 나온다.
        section_separators = { left = "", right = "" },
        -- 섹션 안 구분선은 제거. 캡만으로 경계가 충분하고 폭도 아낀다.
        component_separators = "",
      },
      sections = {
        -- 모드는 첫 글자만 (NORMAL → N). 색으로 이미 구분되므로 글자는 짧게.
        lualine_a = { { "mode", fmt = function(s) return s:sub(1, 1) end } },
        lualine_b = { "branch" },
        -- 진단을 파일명 옆에 붙인다 (LSP 도입 후 실효가 생긴 정보)
        lualine_c = { { "filename", path = 1 }, "diagnostics" },
        lualine_x = { "diff" },
        lualine_y = { { "filetype", icon_only = true } },
        -- progress(45%) 는 뺐다 — location(12:34) 과 정보가 겹친다
        lualine_z = { "location" },
      },
    },
  },

  -- 열린 버퍼를 상단에 탭처럼 (S-h / S-l 로 이동)
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        -- LSP 진단 개수를 버퍼 탭에 표시 (2026-08-26 LSP 도입과 함께 켬)
        diagnostics = "nvim_lsp",
        show_close_icon = false,
        show_buffer_close_icons = false,
        -- 곡선형 구분자. 완전한 원형(U+E0B4/E0B6)을 커스텀으로 넣을 수도 있지만
        -- bufferline 의 is_slant 목록에 없어서 배경색 하이라이트를 못 받고
        -- 캡 색이 탭과 어긋난다. 색이 제대로 맞는 것 중 가장 둥근 게 slope.
        separator_style = "slope",
        -- 활성 버퍼 표시를 막대(▎) 대신 밑줄로 — 한 칸을 아낀다
        indicator = { style = "underline" },
        max_name_length = 16,
        tab_size = 14,
        -- 기본 표시는 " 2 " 처럼 길다. 점 하나로 줄인다.
        diagnostics_indicator = function(count)
          return "● " .. count
        end,
        offsets = {
          { filetype = "snacks_layout_box", text = "파일", highlight = "Directory" },
        },
      },
    },
  },

  -- 키를 누르면 다음에 뭘 누를 수 있는지 보여준다.
  -- 키맵이 늘어날 때 외우지 않아도 되게 해주는 장치.
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      spec = {
        { "<leader>f", group = "찾기" },
        { "<leader>g", group = "git" },
        { "<leader>b", group = "버퍼" },
        { "<leader>i", group = "이미지" },
        { "<leader>u", group = "토글·undo" },
        { "<leader>s", group = "찾기·바꾸기" },
        { "<leader>q", group = "세션" },
        { "<leader>x", group = "quickfix" },
        { "[", group = "이전으로" },
        { "]", group = "다음으로" },
      },
    },
  },
}
