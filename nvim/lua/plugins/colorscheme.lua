-- 터미널(Ghostty)·tmux 와 같은 Dracula 로 통일
return {
  {
    "Mofiqul/dracula.nvim",
    priority = 1000, -- 다른 플러그인보다 먼저 로드해야 색이 깜빡이지 않는다
    config = function()
      require("dracula").setup({
        transparent_bg = true, -- 터미널의 background-opacity/blur 가 보이게
        italic_comment = true,
      })
      vim.cmd.colorscheme("dracula")
    end,
  },
}
