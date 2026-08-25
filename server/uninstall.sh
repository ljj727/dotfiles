#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# server/install.sh 되돌리기 — Ubuntu / sudo 없음
#
#   사용법:  bash ~/dotfiles/server/uninstall.sh
#            bash ~/dotfiles/server/uninstall.sh --dry-run   미리보기
#            bash ~/dotfiles/server/uninstall.sh --all       plugin 캐시까지 제거
#
#   안전장치: install.sh 가 남긴 manifest 에 적힌 경로만 지운다.
#             manifest 에 없는 것(원래 시스템에 있던 도구, 직접 만든 파일)은
#             건드리지 않는다. manifest 가 없으면 알려진 경로 목록으로
#             폴백하되, 각 항목을 지우기 전에 확인을 받는다.
#
#   기본적으로 남기는 것 (--all 로 제거):
#     ~/.local/share/zinit  — 플러그인 캐시. 재설치 시 다시 받으면 되지만
#                             네트워크가 느린 서버에서는 수십 초가 아깝다.
#     ~/.zshrc.local        — 머신별 수동 설정. 날리면 복구할 수 없다.
#     ~/.zsh_history        — 절대 자동 삭제하지 않는다.
# ============================================================================

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="$HOME/.local"
BIN="$PREFIX/bin"
MANIFEST="$PREFIX/share/dotfiles-server/manifest"

DRY_RUN=0
REMOVE_ALL=0
for a in "$@"; do
    case "$a" in
        --dry-run) DRY_RUN=1 ;;
        --all)     REMOVE_ALL=1 ;;
        *) echo "알 수 없는 옵션: $a" >&2; exit 2 ;;
    esac
done

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${BLUE}→${NC} $1"; }
ok()   { echo -e "${GREEN}✓${NC} $1"; }
skip() { echo -e "${YELLOW}⊘${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }

echo ""
echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  서버 설치 되돌리기                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
echo ""
[[ $DRY_RUN -eq 1 ]] && warn "dry-run — 아무것도 지우지 않습니다" && echo ""

rm_path() {   # $1=경로  $2=설명
    local p="$1" d="${2:-}"
    if [[ ! -e "$p" && ! -L "$p" ]]; then
        skip "없음: $p"; return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "    [dry-run] rm -rf $p ${d:+($d)}"; return 0
    fi
    rm -rf "$p"
    ok "제거: $p ${d:+($d)}"
}

# ============================================================================
# 1. herdr 서버부터 정지 — 실행 중이면 바이너리를 지워도 프로세스가 남는다
# ============================================================================
if command -v herdr &>/dev/null; then
    info "herdr 서버 정지..."
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "    [dry-run] herdr server stop"
    else
        herdr server stop >/dev/null 2>&1 || true
        ok "herdr 서버 정지 (떠 있지 않았으면 무시됨)"
    fi
fi

# ============================================================================
# 2. ~/.bashrc 의 zsh 진입 블록 제거
#    install.sh 가 마커로 감싸 두었으므로 그 구간만 잘라낸다.
# ============================================================================
echo ""
info "~/.bashrc 정리..."

MARK_BEGIN="# >>> dotfiles server (zsh) >>>"
MARK_END="# <<< dotfiles server (zsh) <<<"

if [[ -f "$HOME/.bashrc" ]] && grep -qF "$MARK_BEGIN" "$HOME/.bashrc"; then
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "    [dry-run] ~/.bashrc 에서 zsh 진입 블록 제거"
    else
        cp "$HOME/.bashrc" "$HOME/.bashrc.bak.$(date +%Y%m%d%H%M%S)"
        awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
            index($0,b) { skipping=1 }
            !skipping   { print }
            index($0,e) { skipping=0 }
        ' "$HOME/.bashrc" > "$HOME/.bashrc.tmp$$"
        mv "$HOME/.bashrc.tmp$$" "$HOME/.bashrc"
        ok "~/.bashrc 블록 제거 (원본은 .bak 으로 백업)"
    fi
else
    skip "~/.bashrc 에 블록 없음"
fi

# ============================================================================
# 3. manifest 기반 제거
# ============================================================================
echo ""
if [[ -f "$MANIFEST" ]]; then
    info "manifest 기준으로 제거합니다: $MANIFEST"
    echo ""
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        # 안전장치: $HOME 밖은 어떤 경우에도 지우지 않는다
        case "$p" in
            "$HOME"/*) ;;
            *) warn "HOME 밖이라 건너뜀: $p"; continue ;;
        esac
        # 보존 대상 (--all 일 때만 제거)
        if [[ $REMOVE_ALL -eq 0 && "$p" == "$HOME/.zshrc.local" ]]; then
            skip "보존: ~/.zshrc.local  (--all 로 제거)"
            continue
        fi
        rm_path "$p"
    done < "$MANIFEST"
    rm_path "$(dirname "$MANIFEST")" "manifest"
else
    warn "manifest 가 없습니다 ($MANIFEST)"
    warn "알려진 경로 목록으로 폴백합니다 — 각 항목을 확인하세요."
    echo ""
    for p in \
        "$BIN/zsh" "$PREFIX/share/zsh" \
        "$BIN/jq" "$BIN/eza" "$BIN/fd" "$BIN/bat" "$BIN/batcat" \
        "$BIN/zoxide" "$BIN/starship" "$BIN/herdr" \
        "$HOME/.fzf" "$HOME/.fzf.zsh"
    do
        [[ -e "$p" || -L "$p" ]] || continue
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "    [dry-run] rm -rf $p"
        else
            read -r -p "  제거할까요? $p [y/N] " ans </dev/tty || ans=n
            [[ "$ans" == "y" || "$ans" == "Y" ]] && rm_path "$p" || skip "유지: $p"
        fi
    done

    # 설정 심링크는 dotfiles 를 가리킬 때만 제거 (직접 만든 파일 보호)
    for dst in "$HOME/.zshrc" "$HOME/.config/starship/starship.toml" "$HOME/.config/herdr/config.toml"; do
        if [[ -L "$dst" && "$(readlink "$dst")" == "$DOTFILES"/* ]]; then
            rm_path "$dst" "dotfiles 심링크"
        elif [[ -e "$dst" ]]; then
            skip "심링크가 아니라 유지: $dst"
        fi
    done
fi

# ============================================================================
# 4. 부수 생성물
# ============================================================================
echo ""
info "부수 생성물 정리..."

rm_path "$HOME/.config/herdr" "herdr 설정 디렉토리"
rm_path "$PREFIX/state/herdr" "herdr 상태 캐시"
rm_path "$HOME/.herdr"        "herdr worktree"
rm_path "$PREFIX/src"         "다운로드 임시 디렉토리"

if [[ $REMOVE_ALL -eq 1 ]]; then
    rm_path "$PREFIX/share/zinit" "zinit 플러그인 캐시"
    rm_path "$HOME/.zshrc.local"  "머신별 설정"
    for f in "$HOME"/.zcompdump*; do rm_path "$f"; done
else
    skip "보존: ~/.local/share/zinit  (--all 로 제거)"
    skip "보존: ~/.zcompdump*         (--all 로 제거)"
fi

# 히스토리는 어떤 경우에도 지우지 않는다
[[ -f "$HOME/.zsh_history" ]] && warn "~/.zsh_history 는 의도적으로 남깁니다 (필요하면 직접 삭제)"

# ============================================================================
# 완료
# ============================================================================
echo ""
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo -e "${GREEN}  되돌리기 완료${NC}"
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo ""
echo "확인:"
echo "  exec bash -l          # bash 로 돌아왔는지"
echo "  command -v zsh eza fd bat jq herdr    # 아무것도 안 나와야 정상"
echo ""
[[ $REMOVE_ALL -eq 0 ]] && echo "플러그인 캐시·머신별 설정까지 지우려면:  bash $DOTFILES/server/uninstall.sh --all"
echo ""
