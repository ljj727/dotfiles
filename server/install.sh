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
#     - tmux 설정 심링크 (tmux 자체는 apt 가 필요해 설치하지 않는다)
#     - neovim + 설정 (2026-08-26 추가 — 원격에서도 쓴다)
#     - eza / fd / bat / jq          — 사용자가 요청한 도구
#     - fzf / zoxide / starship      — .zshrc 가 요구하므로 필수 (아래 주석 참고)
#
#   설치하지 않는 것: yazi, LSP 서버
#     LSP 서버를 빼는 이유: 대부분 node/go/JDK 런타임을 요구하는데 이 서버엔
#     없다. nvim/lua/plugins/lsp.lua 가 "있으면 켜고 없으면 조용히 안 켠다"
#     방식이라 서버가 없어도 nvim 은 정상 동작한다. 그 서버에서 꼭 필요한
#     것만 :Mason 으로 직접 깔면 된다.
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
# 4. neovim — 공식 릴리스 tarball ($HOME 안에만, sudo 없음)
#    apt 의 neovim 은 보통 0.9 미만이고 여기선 apt 를 쓸 수도 없다.
#    nvim/lua/plugins/lsp.lua 가 0.11 의 vim.lsp.config/enable 을 쓰므로
#    0.11 이상이 필요하다 — 그보다 낮으면 있어도 새로 받는다.
# ============================================================================
echo ""
info "neovim 설치..."

nvim_ok() {
    command -v nvim &>/dev/null || return 1
    local major minor
    read -r major minor < <(nvim --version | head -1 \
        | sed -E 's/^NVIM v([0-9]+)\.([0-9]+).*/\1 \2/')
    [[ "${major:-0}" -gt 0 || "${minor:-0}" -ge 11 ]]
}

if nvim_ok; then
    skip "neovim ($(nvim --version | head -1 | awk '{print $2}'))"
else
    # 이 스크립트는 위 0번 섹션에서 x86_64 만 통과시킨다(eza·fd·bat 의 릴리스
    # URL 에 x86_64 가 박혀 있어서다). 그래서 여기서 아키텍처를 다시 분기해도
    # arm 쪽은 도달하지 않는다 — 혼동을 피하려고 분기를 두지 않는다.
    # arm64 서버를 지원하려면 0번 섹션의 가드와 위 도구들의 URL 을 함께 고쳐야 한다.
    NVIM_ASSET="nvim-linux-x86_64"
    run curl -fsSL --retry 3 --connect-timeout 10 --max-time 300 \
        -o "$SRC/nvim.tar.gz" \
        "https://github.com/neovim/neovim/releases/latest/download/${NVIM_ASSET}.tar.gz"
    run rm -rf "$PREFIX/$NVIM_ASSET"
    run tar -xzf "$SRC/nvim.tar.gz" -C "$PREFIX"
    run ln -sfn "$PREFIX/$NVIM_ASSET/bin/nvim" "$BIN/nvim"
    run rm -f "$SRC/nvim.tar.gz"
    record "$PREFIX/$NVIM_ASSET"
    record "$BIN/nvim"
    ok "neovim"
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

# link() 은 파일만 다룬다([[ -f ]]). 디렉토리는 이쪽을 쓴다.
link_dir() {   # $1=원본 디렉토리  $2=대상
    local src="$1" dst="$2"
    [[ -d "$src" ]] || { warn "원본 없음, 건너뜀: $src"; return 0; }
    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        skip "$(basename "$dst")"; return 0
    fi
    # ln -sfn 은 대상이 "실제 디렉토리"면 덮어쓰지 않고 그 안에 링크를 만든다
    # (~/.config/nvim/nvim 이 생기고 바깥의 옛 사본이 계속 쓰인다). 먼저 치운다.
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        run mv "$dst" "${dst}.bak.$(date +%Y%m%d%H%M%S)"
        info "기존 디렉토리 백업: $dst"
    fi
    run mkdir -p "$(dirname "$dst")"
    run ln -sfn "$src" "$dst"
    record "$dst"
    ok "symlink $dst"
}

link "$DOTFILES/zsh/.zshrc"              "$HOME/.zshrc"
link "$DOTFILES/starship/starship.toml"  "$HOME/.config/starship/starship.toml"
link "$DOTFILES/tmux/.tmux.conf"         "$HOME/.tmux.conf"
link "$DOTFILES/tmux/tmux.reset.conf"    "$HOME/.config/tmux/tmux.reset.conf"
link "$DOTFILES/tmux/theme.conf"         "$HOME/.config/tmux/theme.conf"

# tmux/scripts — .tmux.conf 와 theme.conf 가 ~/.config/tmux/scripts/ 를
# 참조한다 (상태바의 git-info·sys-info, pane 하단바의 ssh-host,
# 사이드바 3종, ssh/session/tmuxinator 팝업). 이게 없으면 상태바 항목이
# 조용히 비고 bind g/s/w 팝업은 "파일 없음"으로 실패한다.
link_dir "$DOTFILES/tmux/scripts"        "$HOME/.config/tmux/scripts"

# nvim — 디렉토리 통째로. lazy-lock.json 을 nvim 이 직접 갱신하므로
# 링크여야 그 변경이 repo 에 남는다 (데스크톱 install.sh 와 같은 이유).
link_dir "$DOTFILES/nvim"                "$HOME/.config/nvim"

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
echo ""
echo "되돌리기:  bash $DOTFILES/server/uninstall.sh"
echo ""
