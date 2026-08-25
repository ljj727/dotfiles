#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# 원격 서버용 경량 설치 — Ubuntu / sudo 없음
#
#   사용법:  bash ~/dotfiles/server/install.sh
#            bash ~/dotfiles/server/install.sh --dry-run   미리보기
#
#   대상: root 권한이 없는 공용 계정 Ubuntu 서버. 전부 $HOME 안에만 쓴다.
#         apt·/usr/local·/etc 는 건드리지 않는다.
#
#   설치 범위 (데스크톱용 install.sh 와 다름):
#     - zsh + 자동완성 환경 (zinit 플러그인은 첫 zsh 실행 때 자동 설치)
#     - eza / fd / bat / jq          — 사용자가 요청한 도구
#     - fzf / zoxide / starship      — .zshrc 가 요구하므로 필수 (아래 주석 참고)
#     - herdr                        — 원격 세션 매니저
#
#   설치하지 않는 것: neovim, yazi (원격 서버에 불필요 — 사용자 결정)
#
#   ※ fzf/zoxide/starship 을 "선택"으로 둘 수 없는 이유:
#     zsh/.zshrc 의 `eval "$(zoxide init zsh)"`(152행) 와
#     `eval "$(starship init zsh)"`(157행) 이 가드 없이 호출된다.
#     없으면 셸을 열 때마다 에러가 난다. fzf 는 fzf-tab 플러그인이 쓴다.
#
#   되돌리기: bash ~/dotfiles/server/uninstall.sh
# ============================================================================

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="$HOME/.local"
BIN="$PREFIX/bin"
SRC="$PREFIX/src"
MANIFEST="$PREFIX/share/dotfiles-server/manifest"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${BLUE}→${NC} $1"; }
ok()   { echo -e "${GREEN}✓${NC} $1"; }
skip() { echo -e "${YELLOW}⊘${NC} $1  (이미 설치됨)"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
die()  { echo -e "${RED}✗${NC} $1" >&2; exit 1; }

run() {
    if [[ $DRY_RUN -eq 1 ]]; then echo "    [dry-run] $*"; else "$@"; fi
}

# 설치한 경로를 기록해 둔다 — uninstall.sh 가 이 목록만 지운다
record() {
    [[ $DRY_RUN -eq 1 ]] && return 0
    mkdir -p "$(dirname "$MANIFEST")"
    grep -qxF "$1" "$MANIFEST" 2>/dev/null || echo "$1" >> "$MANIFEST"
}

echo ""
echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  서버 설치 (Ubuntu · sudo 없음)      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
echo ""
[[ $DRY_RUN -eq 1 ]] && warn "dry-run — 아무것도 바꾸지 않습니다" && echo ""

# ============================================================================
# 0. 전제 조건
# ============================================================================
[[ "$(uname -s)" == "Linux" ]]  || die "Linux 전용입니다 (현재: $(uname -s))"
[[ "$(uname -m)" == "x86_64" ]] || die "x86_64 전용입니다 (현재: $(uname -m)). 다른 아키텍처는 아래 URL 을 바꿔야 합니다."
command -v curl >/dev/null || die "curl 이 필요합니다"
command -v git  >/dev/null || die "git 이 필요합니다"
command -v tar  >/dev/null || die "tar 가 필요합니다"

info "DOTFILES = $DOTFILES"
info "설치 경로 = $PREFIX  (sudo 미사용)"
echo ""

run mkdir -p "$BIN" "$SRC"

# ============================================================================
# 1. 단일 바이너리 도구
# ============================================================================
info "CLI 도구 설치..."

# --- jq — 단일 바이너리, 자산 이름이 고정이라 latest 링크를 그대로 쓴다 ---
if command -v jq &>/dev/null; then
    skip "jq"
else
    run curl -fsSL --retry 3 --connect-timeout 10 --max-time 180 \
        -o "$BIN/jq" \
        "https://github.com/jqlang/jq/releases/latest/download/jq-linux-amd64"
    run chmod 755 "$BIN/jq"
    record "$BIN/jq"
    ok "jq"
fi

# --- eza — 자산 이름에 버전이 없어 latest 링크 사용 가능 ---
if command -v eza &>/dev/null; then
    skip "eza"
else
    run curl -fsSL --retry 3 --connect-timeout 10 --max-time 180 \
        -o "$SRC/eza.tar.gz" \
        "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz"
    run tar -xzf "$SRC/eza.tar.gz" -C "$SRC"
    run mv -f "$SRC/eza" "$BIN/eza"
    run chmod 755 "$BIN/eza"
    run rm -f "$SRC/eza.tar.gz"
    record "$BIN/eza"
    ok "eza"
fi

# --- fd / bat — 자산 이름에 버전이 박혀 있어 API 로 태그를 먼저 조회한다 ---
gh_latest_tag() {
    curl -fsSL --retry 3 --max-time 30 "https://api.github.com/repos/$1/releases/latest" \
        | grep -m1 '"tag_name"' | cut -d'"' -f4
}

install_sharkdp() {   # $1=repo  $2=binary
    local repo="$1" bin="$2" tag dir
    if command -v "$bin" &>/dev/null; then skip "$bin"; return 0; fi
    tag="$(gh_latest_tag "$repo")"
    [[ -n "$tag" ]] || die "$repo 최신 태그 조회 실패"
    dir="${bin}-${tag}-x86_64-unknown-linux-gnu"
    run curl -fsSL --retry 3 --connect-timeout 10 --max-time 180 \
        -o "$SRC/$bin.tar.gz" \
        "https://github.com/$repo/releases/download/$tag/$dir.tar.gz"
    run tar -xzf "$SRC/$bin.tar.gz" -C "$SRC"
    run mv -f "$SRC/$dir/$bin" "$BIN/$bin"
    run chmod 755 "$BIN/$bin"
    run rm -rf "$SRC/$dir" "$SRC/$bin.tar.gz"
    record "$BIN/$bin"
    ok "$bin ($tag)"
}

install_sharkdp sharkdp/fd  fd
install_sharkdp sharkdp/bat bat

# zsh/.zshrc:206 이 `alias bat=batcat` 로 Debian apt 이름을 전제한다.
# 업스트림 릴리스는 바이너리 이름이 bat 이므로 batcat 별칭을 만들어 준다.
# (.zshrc:81 의 fzf-tab 프리뷰도 batcat 을 호출한다.)
if [[ -e "$BIN/batcat" ]]; then
    skip "batcat 심링크"
elif command -v batcat &>/dev/null; then
    skip "batcat (시스템 제공)"
else
    run ln -sf "$BIN/bat" "$BIN/batcat"
    record "$BIN/batcat"
    ok "batcat → bat 심링크"
fi

# ============================================================================
# 2. .zshrc 가 요구하는 도구 (없으면 셸 시작 시 에러)
# ============================================================================
echo ""
info ".zshrc 의존 도구 설치..."

# --- fzf — fzf-tab 플러그인이 사용. ~/.fzf 에 설치 ---
if [[ -d "$HOME/.fzf" ]] || command -v fzf &>/dev/null; then
    skip "fzf"
else
    run git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    run "$HOME/.fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
    record "$HOME/.fzf"
    record "$HOME/.fzf.zsh"
    ok "fzf"
fi

# --- zoxide — .zshrc:152 가 가드 없이 eval 한다 ---
if command -v zoxide &>/dev/null; then
    skip "zoxide"
else
    run bash -c "curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh -s -- --bin-dir '$BIN'"
    record "$BIN/zoxide"
    ok "zoxide"
fi

# --- starship — .zshrc:157 이 가드 없이 eval 한다 ---
if command -v starship &>/dev/null; then
    skip "starship"
else
    run bash -c "curl -sSfL https://starship.rs/install.sh | sh -s -- -y -b '$BIN'"
    record "$BIN/starship"
    ok "starship"
fi

# ============================================================================
# 3. zsh 본체
#    apt 가 없으므로 romkatv/zsh-bin 의 정적 빌드를 $HOME/.local 에 푼다.
#    -e no : /etc/shells 를 건드리지 않는다 (sudo 가 필요하고, 우리는 없다)
# ============================================================================
echo ""
info "zsh 설치..."

if command -v zsh &>/dev/null; then
    skip "zsh ($(zsh --version 2>/dev/null | head -1))"
else
    run bash -c "curl -fsSL https://raw.githubusercontent.com/romkatv/zsh-bin/master/install \
        | sh -s -- -q -d '$PREFIX' -e no"
    record "$BIN/zsh"
    record "$PREFIX/share/zsh"
    ok "zsh (zsh-bin 정적 빌드)"
fi

# ============================================================================
# 4. herdr — 원격 세션 매니저
#    로컬 Ghostty 의 cmd+* 패스스루가 이 설정의 prefix(ctrl+b)를 전제한다.
# ============================================================================
echo ""
info "herdr 설치..."

if command -v herdr &>/dev/null; then
    skip "herdr ($(herdr --version 2>/dev/null))"
else
    HERDR_URL="$(curl -fsSL --max-time 30 https://herdr.dev/latest.json \
        | grep -o '"linux-x86_64"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4)"
    [[ -n "$HERDR_URL" ]] || die "herdr 다운로드 URL 조회 실패"
    run curl -fsSL --retry 3 --connect-timeout 10 --max-time 300 -o "$BIN/herdr" "$HERDR_URL"
    run chmod 755 "$BIN/herdr"
    record "$BIN/herdr"
    ok "herdr"
fi

# ============================================================================
# 5. Symlink — 데스크톱 install.sh 와 동일한 설정을 공유한다
# ============================================================================
echo ""
info "Symlink 설정..."

link() {   # $1=원본  $2=대상
    local src="$1" dst="$2"
    [[ -f "$src" ]] || { warn "원본 없음, 건너뜀: $src"; return 0; }
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        skip "$(basename "$dst")"; return 0
    fi
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        run mv "$dst" "${dst}.bak.$(date +%Y%m%d%H%M%S)"
        info "기존 파일 백업: $dst"
    fi
    run mkdir -p "$(dirname "$dst")"
    run ln -sfn "$src" "$dst"
    record "$dst"
    ok "symlink $dst"
}

link "$DOTFILES/zsh/.zshrc"              "$HOME/.zshrc"
link "$DOTFILES/starship/starship.toml"  "$HOME/.config/starship/starship.toml"
link "$DOTFILES/herdr/config.toml"       "$HOME/.config/herdr/config.toml"

if [[ ! -f "$HOME/.zshrc.local" ]]; then
    run cp "$DOTFILES/local/.zshrc.local.example" "$HOME/.zshrc.local"
    record "$HOME/.zshrc.local"
    ok "~/.zshrc.local 생성 — 머신에 맞게 수정하세요"
else
    skip "~/.zshrc.local"
fi

# ============================================================================
# 6. 로그인 시 zsh 진입
#    chsh 는 쓸 수 없다: $HOME/.local/bin/zsh 가 /etc/shells 에 없고,
#    등록하려면 sudo 가 필요하다. 대신 ~/.bashrc 에서 zsh 로 넘긴다.
#    마커로 감싸 uninstall.sh 가 정확히 제거할 수 있게 한다.
# ============================================================================
echo ""
info "로그인 셸 연결..."

MARK_BEGIN="# >>> dotfiles server (zsh) >>>"
MARK_END="# <<< dotfiles server (zsh) <<<"

if grep -qF "$MARK_BEGIN" "$HOME/.bashrc" 2>/dev/null; then
    skip "~/.bashrc zsh 진입 블록"
else
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "    [dry-run] ~/.bashrc 에 zsh 진입 블록 추가"
    else
        cat >> "$HOME/.bashrc" <<EOF

$MARK_BEGIN
# sudo 가 없어 chsh 를 쓸 수 없다. 대화형 로그인일 때만 zsh 로 넘어간다.
# \$SHELL 을 바꿔 두지 않으면 일부 도구가 bash 를 가정한다.
if [ -z "\${ZSH_VERSION:-}" ] && [ -x "$BIN/zsh" ] && case \$- in *i*) true;; *) false;; esac; then
    export SHELL="$BIN/zsh"
    exec "$BIN/zsh" -l
fi
$MARK_END
EOF
    fi
    ok "~/.bashrc 에 zsh 진입 블록 추가"
fi

# PATH 안내 — .zshrc:4 가 이미 ~/.local/bin 을 넣지만, bash 로 들어올 때 필요
case ":${PATH}:" in
    *":$BIN:"*) ok "PATH 에 $BIN 포함됨" ;;
    *) warn "PATH 에 $BIN 이 없습니다. 새 로그인 후 반영되거나, 아래를 ~/.bashrc 에 추가하세요:"
       echo "      export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

# ============================================================================
# 완료
# ============================================================================
echo ""
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo -e "${GREEN}  설치 완료${NC}"
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo ""
echo "다음 단계:"
echo "  1. 새로 로그인하거나  exec \"$BIN/zsh\" -l"
echo "     → 첫 zsh 실행 때 zinit 이 자동으로 플러그인을 받습니다"
echo "        (zsh-completions · fzf-tab · autosuggestions · syntax-highlighting)"
echo "        수십 초 걸리고, 그동안 프롬프트가 잠깐 멈춘 것처럼 보입니다."
echo ""
echo "  2. 로컬 맥에서:  herdr --remote <이 서버>"
echo ""
echo "되돌리기:  bash $DOTFILES/server/uninstall.sh"
echo ""
