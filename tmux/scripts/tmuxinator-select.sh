#!/bin/bash
command -v tmuxinator >/dev/null || { echo "tmuxinator not installed"; exit 1; }
project=$(tmuxinator list -n | tail -n +2 | tr ' ' '\n' | grep -v '^$' | fzf \
  --prompt=' ❯ ' --pointer='▶' --marker='✓' \
  --border=none --height=100% --layout=reverse \
  --color='fg:#f8f8f2,bg:#282a36,hl:#ff79c6,fg+:#ffffff,bg+:#44475a,hl+:#bd93f9,info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6,marker:#50fa7b,header:#6272a4')
if [ -n "$project" ]; then
    # 세션이 이미 있으면 전환만, 없으면 생성 후 전환
    if tmux has-session -t "$project" 2>/dev/null; then
        tmux switch-client -t "$project"
    else
        TMUX='' tmuxinator start "$project" --no-attach
        tmux switch-client -t "$project"
    fi
fi
