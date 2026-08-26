#!/bin/bash
# pane 하단바용 — 그 pane 이 접속 중인 SSH 호스트 이름을 출력한다.
#
# 왜 프로세스를 뒤지나:
#   · tmux 포맷은 pane 안의 환경변수를 못 읽는다 (#{SSH_CONNECTION} 은 항상 빈 값)
#   · #{pane_current_path} 는 ssh pane 에서도 "로컬" 경로를 준다 (원격 경로가 아님)
#   · #{pane_title} 은 원격이 user@host 로 채워주기도 하지만, 원격에서 Claude Code
#     같은 게 돌면 제목을 덮어써서 호스트가 사라진다 (실제로 그런 pane 이 있었다)
#   그래서 pane 셸의 자식 프로세스에서 ssh 인자를 직접 읽는 방식이 유일하게 확실하다.
#
# 사용법: ssh-host.sh <pane_pid>
# 출력:   호스트 이름 한 줄. 못 찾으면 아무것도 출력하지 않는다.
#
# pane-border-format 은 status-interval(5초)마다 pane 수만큼 평가되므로
# 외부 명령은 pgrep/ps 두 번으로 끝낸다.

pane_pid="${1:-}"
[[ -n "$pane_pid" ]] || exit 0

# pane 셸의 자식 중 ssh 를 찾는다. 자식이 없으면 조용히 끝낸다.
for child in $(pgrep -P "$pane_pid" 2>/dev/null); do
    cmd=$(ps -o command= -p "$child" 2>/dev/null) || continue
    [[ "$cmd" == ssh\ * ]] || continue

    # 인자에서 호스트를 고른다. 값을 받는 플래그는 다음 토큰까지 건너뛴다.
    # (-p 2222, -i key, -l user, -o Opt=v, -L/-R/-D 포워딩 등)
    skip_next=0
    for arg in ${cmd#ssh }; do
        if (( skip_next )); then skip_next=0; continue; fi
        case "$arg" in
            -[bcDEeFIiJLlmOopQRSWw]) skip_next=1 ;;   # 값을 따로 받는 플래그
            -*)                      ;;               # 값 없는 플래그 (-v, -N, -T ...)
            *) printf '%s\n' "${arg#*@}"; exit 0 ;;   # user@host 면 host 만
        esac
    done
done

exit 0
