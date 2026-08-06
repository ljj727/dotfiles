#!/bin/bash
# ~/.ssh/config 의 Host 목록에서 골라 새 tmux 윈도우로 접속한다.
# tmux 팝업(prefix+g)에서 호출된다.
#
# 색은 tmux 옵션 @fzf_colors(theme.conf)에서 읽는다. 여기에 헥사를 박아두면
# 테마를 바꿀 때 이 파일도 같이 고쳐야 해서 어긋난다.
#
# TERM 은 여기서 건드리지 않는다. tmux 안쪽 TERM 을 .tmux.conf 가
# tmux-256color(없으면 screen-256color)로 정하고 그 값이 원격으로 전파된다.
# 예전에는 xterm-ghostty 가 그대로 넘어가 원격에서 tput 오류가 쏟아지고
# zsh 라인편집이 깨졌다.
FZF_COLORS="$(tmux show -gv @fzf_colors 2>/dev/null)"

host=$(grep -E '^Host ' ~/.ssh/config 2>/dev/null | awk '{print $2}' | grep -v '*' | fzf \
  --prompt=' ❯ ' --pointer='▶' --marker='✓' \
  --border=none --height=100% --layout=reverse \
  ${FZF_COLORS:+--color="$FZF_COLORS"})

if [ -n "$host" ]; then
    # TERM 명시: tmux new-window 명령은 zsh alias(TERM=... ssh)를 타지 않아
    # 전역 환경의 xterm-ghostty 가 원격으로 샐 수 있다 (2026-08-06 server 사고).
    tmux new-window -n "$host" "TERM=xterm-256color ssh '$host'"
fi
