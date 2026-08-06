#!/bin/bash
# 현재 세션의 모든 윈도우에 사이드바를 붙이거나 뗀다.
#
# 사이드바는 pane 이므로 윈도우마다 하나씩 있어야 한다. 창을 옮겨도 같은 자리에
# 같은 모습으로 있으니 하나의 고정 사이드바처럼 보인다.
#
# [지난 실패 두 가지 — 같은 실수 반복 금지]
#  1) 대상을 창 번호만으로 지정(-t 2)하면 세션이 모호해서 엉뚱한 세션의 창에
#     붙는다. 반드시 "세션명:창번호" 로 완전지정한다.
#  2) 새로 만든 pane 을 "맨 왼쪽 pane" 으로 추측하면, 이미 분할된 창에서는
#     다른 pane 을 집어 그쪽에 sidebar 제목을 달아버린다. split-window -P -F
#     로 새 pane 의 ID 를 직접 받아서 쓴다.

set -u

WIDTH=$(tmux show -gv @sidebar_width 2>/dev/null); WIDTH=${WIDTH:-22}
SCRIPT="$HOME/.config/tmux/scripts/sidebar.sh"
SESSION=$(tmux display -p '#{session_name}')

has_sidebar() {  # $1 = "세션:창번호"
    tmux list-panes -t "$1" -F '#{pane_title}' 2>/dev/null | grep -qx 'sidebar'
}

add_to() {  # $1 = "세션:창번호"
    has_sidebar "$1" && return
    # -f 는 "창 전체" 기준으로 나눈다. 이게 없으면 활성 pane 만 쪼개서, 이미
    #    분할된 창에서는 사이드바가 창 중간에 끼어 들어간다(확인함).
    # -b 대상 앞(왼쪽) / -d 포커스 이동 안 함 / -P -F 새 pane 의 ID 를 돌려받음
    local id
    id=$(tmux split-window -fh -b -d -l "$WIDTH" -t "$1" -P -F '#{pane_id}' \
            "/bin/bash $SCRIPT" 2>/dev/null) || return
    [ -n "$id" ] && tmux select-pane -t "$id" -T sidebar
}

remove_from() {  # $1 = "세션:창번호"
    tmux list-panes -t "$1" -F '#{pane_id} #{pane_title}' 2>/dev/null \
      | awk '$2=="sidebar"{print $1}' \
      | while read -r id; do tmux kill-pane -t "$id"; done
}

case "${1:-toggle}" in
    on)   want=1 ;;
    off)  want=0 ;;
    hook) # 새 창이 생겼을 때만 호출된다 — 켜져 있을 때만 붙인다.
          #
          # 대상($2)을 훅에서 인자로 받아야 한다. run-shell 안에서 그냥
          # `tmux display -p` 를 부르면 "새로 만들어진 창" 이 아니라 클라이언트가
          # 지금 보고 있는 창이 잡힌다. 마찬가지로 `show -v` 도 세션을 명시하지
          # 않으면 값을 못 찾아 조용히 빠져나간다(둘 다 실제로 겪음).
          target="${2:-}"
          [ -z "$target" ] && exit 0
          sess="${target%%:*}"
          [ "$(tmux show -t "$sess" -v @sidebar 2>/dev/null)" = "1" ] || exit 0
          add_to "$target"
          exit 0 ;;
    *)    [ "$(tmux show -t "$SESSION" -v @sidebar 2>/dev/null)" = "1" ] && want=0 || want=1 ;;
esac

cur=$(tmux display -p '#{window_index}')
# 현재 세션의 창만 건드린다.
while read -r w; do
    [ -z "$w" ] && continue
    if [ "$want" = "1" ]; then add_to "$SESSION:$w"; else remove_from "$SESSION:$w"; fi
done < <(tmux list-windows -t "$SESSION" -F '#{window_index}')

tmux set -q -t "$SESSION" @sidebar "$want"

# 사이드바에 세션·창·폴더가 다 나오므로 위 상태줄은 통째로 끈다.
# git·시계는 사이드바 아래쪽으로 옮겼다(sidebar.sh).
# 끌 때는 -u 로 세션 설정을 지워 전역값(theme.conf 의 status on)으로 되돌린다.
if [ "$want" = "1" ]; then
    tmux set -q -t "$SESSION" status off
else
    tmux set -q -u -t "$SESSION" status
fi

tmux select-window -t "$SESSION:$cur"

if [ "$want" = "1" ]; then
    tmux display-message "사이드바 켜짐 — prefix+B 로 끄기"
else
    tmux display-message "사이드바 꺼짐"
fi
