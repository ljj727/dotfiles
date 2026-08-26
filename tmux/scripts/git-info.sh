#!/bin/bash
# 상태바 둘째 줄에 표시할 git 정보: 브랜치 + 변경 파일 수.
# 인자로 경로를 받는다 (tmux 가 #{pane_current_path} 를 넘긴다).
#
# 상태바는 status-interval(5초)마다 이 스크립트를 호출하므로 빨라야 한다.
# --porcelain 을 세는 대신 --porcelain=v1 을 한 번만 돌려 재사용한다.
# git 저장소가 아니면 아무것도 출력하지 않고 조용히 끝낸다.

cd "${1:-.}" 2>/dev/null || exit 0

branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null) \
  || branch=$(git rev-parse --short HEAD 2>/dev/null) \
  || exit 0

dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

if [ "$dirty" -gt 0 ] 2>/dev/null; then
    printf ' %s ±%s' "$branch" "$dirty"
else
    printf ' %s' "$branch"
fi
