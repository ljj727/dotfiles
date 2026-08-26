#!/bin/bash
# 왼쪽 사이드바: 현재 세션의 윈도우 목록을 세로로 그린다.
# cmux 의 세로 탭에 해당하는 부분을 tmux 로 만든 것.
#
# 세션 목록이 아니라 "윈도우" 목록인 이유: tmux pane 은 한 세션 안에 산다.
# 세션을 바꾸면 그 pane 도 같이 사라지므로 세션 사이드바는 구조적으로 불가능하다.
#
# 클릭 처리는 이 스크립트가 하지 않는다. tmux 의 MouseDown1Pane 바인딩이
# #{mouse_line}(마우스 아래 줄의 텍스트)을 읽어 sidebar-click.sh 로 넘긴다.
# 좌표 계산이 필요 없어서 pane 위치나 상태줄 높이가 바뀌어도 안 깨진다.
#
# 갱신: 내용이 바뀔 때만 다시 그린다(깜빡임 방지). 1초 폴링.

c() { tmux show -gv "$1" 2>/dev/null; }
hex2rgb() { printf '%d;%d;%d' 0x"${1:1:2}" 0x"${1:3:2}" 0x"${1:5:2}"; }

C_PINK=$(hex2rgb "$(c @c_pink)")
C_MUTED=$(hex2rgb "$(c @c_muted)")
C_SURF=$(hex2rgb "$(c @c_surface)")
C_PURPLE=$(hex2rgb "$(c @c_purple)")
C_GREEN=$(hex2rgb "$(c @c_green)")
C_YELLOW=$(hex2rgb "$(c @c_yellow)")

FG()  { printf '\033[38;2;%sm' "$1"; }
RESET=$'\033[0m'
BOLD=$'\033[1m'

prev=""
while true; do
    # -t "$TMUX_PANE" 필수. 안 주면 활성 pane(=본문)의 폭이 나와서
    # 구분선이 사이드바 폭을 넘어 여러 줄로 접힌다(확인함).
    width=$(tmux display -p -t "${TMUX_PANE:-}" '#{pane_width}' 2>/dev/null)
    width=${width:-22}
    # #{E:@win_icon} 은 theme.conf 가 정의한 명령별 아이콘 규칙을 그대로 쓴다.
    # tmux 포맷 문자열은 \t 를 탭으로 해석하지 않는다. 실제 탭 문자를 넣어야 한다.
    list=$(tmux list-windows -F '#{window_active}	#{window_index}	#{E:@win_icon}	#{window_name}	#{window_zoomed_flag}' 2>/dev/null)
    [ -z "$list" ] && { sleep 1; continue; }

    # git 정보는 활성 창 기준. git-info.sh 는 저장소가 아니면 조용히 빈 값.
    active_path=$(tmux display -p '#{pane_current_path}' 2>/dev/null)
    gitinfo=$("$HOME/.config/tmux/scripts/git-info.sh" "$active_path" 2>/dev/null)
    clock=$(date '+%a %d · %H:%M')

    if [ "$list$width$gitinfo$clock" != "$prev" ]; then
        prev="$list$width$gitinfo$clock"
        out=""
        out+="$(FG "$C_PURPLE")${BOLD} $(tmux display -p '#{session_name}')${RESET}\n"
        out+="$(FG "$C_SURF")$(printf '%*s' "$((width - 1))" '' | sed 's/ /─/g')${RESET}\n"
        while IFS=$'	' read -r active idx icon name zoomed; do
            [ -z "$idx" ] && continue
            [ "$zoomed" = "1" ] && zi=" ⚡" || zi=""
            if [ "$active" = "1" ]; then
                out+="$(FG "$C_PINK")${BOLD}▎${icon} ${idx} ${name}${zi}${RESET}\n"
            else
                out+="$(FG "$C_MUTED") ${icon} ${idx} ${name}${zi}${RESET}\n"
            fi
            # 폴더 줄은 제거(2026-08-26, 사용자 요청 — 세션·창 목록만 본다).
            # 경로는 pane 하단바(pane-border-format)가 pane 별로 보여주므로
            # 여기서 반복할 필요가 없다. 부수 효과로 오클릭도 사라졌다 —
            # sidebar-click.sh 가 줄에서 "첫 숫자"를 창 번호로 읽는데,
            # ~/ptrg/02.injest 같은 경로를 클릭하면 02 번 창으로 튀었다.
        done <<< "$list"
        # ── 아래쪽: git · 시계 ──────────────────────────────────────────
        # 위 상태줄을 껐으므로(sidebar-toggle.sh) 여기로 옮겨왔다.
        # 사이드바 맨 아래에 붙이려고 남은 줄만큼 개행을 채운다.
        height=$(tmux display -p -t "${TMUX_PANE:-}" '#{pane_height}' 2>/dev/null)
        height=${height:-24}
        used=$(printf '%b' "$out" | grep -c '')
        foot=3
        pad=$((height - used - foot))
        [ "$pad" -gt 0 ] && out+="$(printf '%*s' "$pad" '' | sed 's/ /\\n/g')"

        out+="$(FG "$C_SURF")$(printf '%*s' "$((width - 1))" '' | sed 's/ /─/g')${RESET}\n"
        [ -n "$gitinfo" ] && out+="$(FG "$C_GREEN")${gitinfo}${RESET}\n"
        out+="$(FG "$C_YELLOW")${clock}${RESET}"

        # 커서를 좌상단으로 옮기고 화면 끝까지 지우며 그린다 (clear 는 깜빡인다)
        printf '\033[H\033[J'
        printf '%b' "$out"
    fi
    sleep 1
done
