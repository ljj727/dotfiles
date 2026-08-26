-- 자동완성 — LSP · 경로 · 버퍼 단어.
--
-- 2026-08-26 에 lsp 소스를 추가했다(이 파일 주석이 예고하던 그것).
--   · lsp    — 의미 기반. obj. 치면 실제 멤버가 나온다. 서버가 붙은 버퍼에서만
--   · path   — 파일 경로 보완 (마크다운에 이미지 경로 쓸 때 특히 유용)
--   · buffer — 열려 있는 버퍼의 단어 (긴 변수명 반복 입력 줄임)
-- lsp 를 맨 앞에 두어 의미 있는 후보가 위로 오게 한다. 서버가 없는 버퍼에서는
-- lsp 소스가 아무것도 안 내놓으므로 예전과 똑같이 path/buffer 만 동작한다.
--
-- version 을 고정하면 미리 빌드된 fuzzy 라이브러리를 받으므로
-- Rust 툴체인이 필요 없다 (원격 서버에서도 동작).
return {
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = "InsertEnter",
    opts = {
      keymap = {
        preset = "default", -- C-y 로 확정, C-n/C-p 로 이동, C-e 로 취소
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
      },
      completion = {
        -- 자동으로 창을 띄우되 첫 항목을 미리 선택하지 않는다.
        -- 엔터를 눌렀을 때 원치 않는 보완이 들어가는 걸 막는다.
        list = { selection = { preselect = false, auto_insert = false } },
        menu = { border = "rounded" },
        documentation = { auto_show = true, auto_show_delay_ms = 300 },
      },
      sources = {
        default = { "lsp", "path", "buffer" },
      },
      -- treesitter 로 표시를 다듬음
      appearance = { nerd_font_variant = "mono" },
    },
  },
}
