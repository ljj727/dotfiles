#!/bin/bash
# 사이드바에서 클릭된 줄을 받아 해당 윈도우로 전환한다.
# tmux 가 #{mouse_line}(마우스 아래 줄의 텍스트)을 인자로 넘긴다.
#
# 줄 형식:  "▎<아이콘> <번호> <이름>"  또는  " <아이콘> <번호> <이름>"
# 색은 ANSI 이스케이프라 mouse_line 에는 안 들어온다(텍스트만 온다).
line="$1"

# 앞쪽 표시문자·아이콘을 걷어내고 첫 숫자를 창 번호로 본다.
idx=$(printf '%s' "$line" | grep -oE '[0-9]+' | head -1)
[ -n "$idx" ] && tmux select-window -t "$idx" 2>/dev/null

# 전환 후 포커스는 사이드바가 아닌 본문 pane 으로 돌린다.
main=$(tmux list-panes -F '#{pane_index} #{pane_title}' | awk '$2!="sidebar"{print $1; exit}')
[ -n "$main" ] && tmux select-pane -t "$main"
