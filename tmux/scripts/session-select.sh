#!/bin/bash
# 세션 목록에서 골라 전환한다. tmux 팝업(prefix+s)에서 호출된다.
#
# 왜 스크립트로 뺐나:
#   display-popup 의 "명령 인자"는 #{...} 포맷을 확장하지 않는다(직접 확인).
#   run-shell 은 확장하기 때문에 같을 거라 착각하기 쉬운데 다르다.
#   인라인으로 --color='#{@fzf_colors}' 를 넘기면 fzf 가 그 문자열을 그대로 받아
#     invalid color specification: #{@fzf_colors}
#   로 즉시 죽고, 팝업이 깜빡하고 닫혀서 "키가 안 먹는다"처럼 보인다.
#
# 색은 ssh-select.sh 와 같은 방식으로 tmux 옵션에서 직접 읽는다.
FZF_COLORS="$(tmux show -gv @fzf_colors 2>/dev/null)"

# 현재 붙어 있는 세션은 목록에서 빼지 않는다 — 어디에 있었는지 보이는 편이 낫다.
target=$(tmux list-sessions -F '#{session_name}#{?session_attached, ●,}' 2>/dev/null | fzf \
  --prompt=' ❯ ' --pointer='▶' --marker='✓' \
  --border=none --height=100% --layout=reverse \
  ${FZF_COLORS:+--color="$FZF_COLORS"} | awk '{print $1}')

[ -n "$target" ] && tmux switch-client -t "$target"
