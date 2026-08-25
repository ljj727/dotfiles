#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Finder 기본 앱 지정
#   기본값은 Zed. 터미널(nvim)로 열고 싶으면 인자로 번들 ID 를 넘긴다:
#     set-default-apps.sh                      → Zed
#     set-default-apps.sh local.openinterminal → Ghostty + nvim
#
#   되돌리려면: duti -s com.apple.TextEdit <확장자> all
# ============================================================================

# 기본값: OpenInTerminal (Finder 더블클릭 → 터미널+nvim). Zed 는 2026-08 에 제거됨.
BUNDLE_ID="${1:-local.openinterminal}"

command -v duti >/dev/null 2>&1 || { echo "duti 가 없습니다: brew install duti"; exit 1; }

# 대상 앱이 실제로 있는지 확인 (없는 앱을 지정하면 Finder 가 깨진다)
if ! mdfind "kMDItemCFBundleIdentifier == '$BUNDLE_ID'" 2>/dev/null | grep -q .; then
    echo "번들 ID '$BUNDLE_ID' 인 앱을 찾을 수 없습니다."
    exit 1
fi
echo "핸들러: $BUNDLE_ID"
echo ""

# 문서·설정
DOC_EXTS=(md markdown json xml yaml yml toml txt log conf ini env csv tsv properties)
# 소스코드
# dockerfile/makefile 은 확장자가 아니라 파일명이라 확장자 매핑 대상이 아니다.
SRC_EXTS=(py js mjs cjs ts tsx jsx go rs rb php pl lua vim sh bash zsh fish
          c h cpp cc hpp java kt swift scala sql gradle)

failed=()
for ext in "${DOC_EXTS[@]}" "${SRC_EXTS[@]}"; do
    if duti -s "$BUNDLE_ID" "$ext" all 2>/dev/null; then
        printf '  %-12s ✓\n' ".$ext"
    else
        failed+=("$ext")
    fi
done

echo ""
total=$((${#DOC_EXTS[@]} + ${#SRC_EXTS[@]}))
echo "$((total - ${#failed[@]}))/$total 개 확장자 매핑 완료"

if ((${#failed[@]})); then
    cat <<EOF

아래 확장자는 macOS 가 아직 모르는 타입이라 동적 UTI(dyn.xxx)로 잡혀 자동 지정이 거부됐다:
  ${failed[*]}

해결: Finder 에서 해당 파일 하나를 우클릭 → 정보 가져오기 → "다음으로 열기"
      → 원하는 앱 선택 → "모두 변경".
      (재로그인 후 이 스크립트를 다시 돌리면 자동으로 잡히기도 한다)
EOF
fi
