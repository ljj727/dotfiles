-- 프로젝트 전역 찾기·바꾸기.
-- LSP rename(grn)은 스코프를 이해하는 대신 서버가 붙은 파일 안에서만 동작한다.
-- 이건 반대로 저장소 전체를 텍스트로 훑는다 — 문자열·주석·설정파일·서버가
-- 없는 언어까지 한 번에 바꿀 때 여전히 이게 맞다.
-- ripgrep 으로 찾고 결과를 버퍼에서 직접 편집하듯 치환한다.
return {
  {
    "MagicDuck/grug-far.nvim",
    cmd = "GrugFar",
    opts = { headerMaxWidth = 80 },
    keys = {
      {
        "<leader>sr",
        function()
          -- 현재 파일 확장자만 대상으로 미리 채워서 연다
          local ext = vim.bo.buftype == "" and vim.fn.expand("%:e") or nil
          require("grug-far").open({
            transient = true,
            prefills = { filesFilter = ext and ext ~= "" and ("*." .. ext) or nil },
          })
        end,
        desc = "찾기·바꾸기 (현재 확장자)",
      },
      {
        "<leader>sR",
        function() require("grug-far").open({ transient = true }) end,
        desc = "찾기·바꾸기 (전체)",
      },
      {
        "<leader>sw",
        mode = { "n", "x" },
        function()
          require("grug-far").open({ transient = true, prefills = { search = vim.fn.expand("<cword>") } })
        end,
        desc = "커서 단어 찾기·바꾸기",
      },
    },
  },
}
