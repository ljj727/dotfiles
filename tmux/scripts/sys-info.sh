#!/bin/bash
# 상태 표시줄용 시스템 정보: CPU 부하 · 배터리 · 네트워크.
# pane 경계선(하단바)에서 호출된다.
#
# [아이콘] Nerd Font 의 Material Design 영역(U+F0000~)만 쓴다. 흔히 쓰는
# U+E000~U+F8FF 사설영역 글리프는 이 파일을 만드는 경로에서 유실됐다.
# FiraCode Nerd Font 에 실제로 들어있는지 fontTools 로 확인한 코드포인트들이다.
#
# [캐시] pane-border-format 은 pane 마다 평가되므로 분할이 늘어나면 호출도
# 늘어난다. 그래서 결과를 TTL 동안 파일에 캐시한다. tmux 쪽에서도
# pane_at_bottom && pane_at_left 인 pane 하나에서만 부르지만, 이중으로 막아둔다.
#
# [속도] 느린 명령(top -l1, networksetup, memory_pressure)은 쓰지 않는다.
# 여기 쓰인 것들은 전부 10ms 이하로 측정했다.

CACHE="${TMPDIR:-/tmp}/tmux-sysinfo.$(id -u)"
TTL=5

now=$(date +%s)
if [ -f "$CACHE" ]; then
    mtime=$(stat -f %m "$CACHE" 2>/dev/null || stat -c %Y "$CACHE" 2>/dev/null || echo 0)
    if [ $((now - mtime)) -lt "$TTL" ]; then
        cat "$CACHE"
        exit 0
    fi
fi

# ── CPU: 1분 부하평균을 코어 수로 나눠 백분율로 ──────────────────────────────
# top 을 부르면 1초씩 걸린다. 부하평균은 커널이 이미 들고 있어 즉시 읽힌다.
if [ "$(uname)" = "Darwin" ]; then
    load=$(sysctl -n vm.loadavg | awk '{print $2}')
    ncpu=$(sysctl -n hw.ncpu)
else
    load=$(awk '{print $1}' /proc/loadavg)
    ncpu=$(nproc 2>/dev/null || echo 1)
fi
cpu_pct=$(awk -v l="$load" -v n="$ncpu" 'BEGIN{ p=l/n*100; if(p>999)p=999; printf "%d", p }')

# ── 배터리 ──────────────────────────────────────────────────────────────────
pct=""; state=""
if [ "$(uname)" = "Darwin" ]; then
    line=$(pmset -g batt 2>/dev/null | grep -m1 'InternalBattery')
    if [ -n "$line" ]; then
        pct=$(printf '%s' "$line" | grep -oE '[0-9]+%' | tr -d '%')
        # 순서 주의: "AC attached; not charging" 은 " charging" 을 포함한다.
        # not charging 을 먼저 걸러내지 않으면 충전 중으로 오판한다.
        case "$line" in
            *"not charging"*) state=ac ;;
            *" charging"*)    state=charging ;;
            *"AC attached"*)  state=ac ;;
            *)                state=battery ;;
        esac
    fi
elif [ -d /sys/class/power_supply/BAT0 ]; then
    pct=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
    case "$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)" in
        Charging) state=charging ;;
        Full)     state=ac ;;
        *)        state=battery ;;
    esac
fi

bat=""
if [ -n "$pct" ]; then
    # 충전 중이면 번개, AC 연결이면 플러그, 아니면 잔량 5단계
    if   [ "$state" = "charging" ]; then icon="󰂄"
    elif [ "$state" = "ac" ];       then icon="󰚥"
    elif [ "$pct" -ge 85 ];         then icon="󰁹"
    elif [ "$pct" -ge 60 ];         then icon="󰂀"
    elif [ "$pct" -ge 35 ];         then icon="󰁾"
    elif [ "$pct" -ge 15 ];         then icon="󰁼"
    else                                 icon="󰁺"
    fi
    bat=$(printf '%s %s%%' "$icon" "$pct")
fi

# ── 네트워크: 기본 경로가 나가는 인터페이스 ─────────────────────────────────
# ping 을 쓰지 않는다(느리고 네트워크를 건드린다). 라우팅 테이블만 본다.
net="󰖪 offline"
if [ "$(uname)" = "Darwin" ]; then
    iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
    if [ -n "$iface" ]; then
        if ifconfig -v "$iface" 2>/dev/null | grep -q 'type: Wi'; then
            net="󰖩 $iface"
        else
            net="󰈀 $iface"
        fi
    fi
else
    iface=$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')
    if [ -n "$iface" ]; then
        case "$iface" in
            wl*) net="󰖩 $iface" ;;
            *)   net="󰈀 $iface" ;;
        esac
    fi
fi

out=$(printf '󰘚 %s%%   %s   %s' "$cpu_pct" "${bat:-–}" "$net")
printf '%s' "$out" > "$CACHE.tmp" 2>/dev/null && mv "$CACHE.tmp" "$CACHE" 2>/dev/null
printf '%s' "$out"
