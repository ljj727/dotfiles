#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# 원격 서버용 경량 설치 — Ubuntu / sudo 없음
#
#   사용법:  bash ~/dotfiles/server/install.sh
#            bash ~/dotfiles/server/install.sh --dry-run    미리보기
#            bash ~/dotfiles/server/install.sh --auto-zsh   로그인 시 zsh 자동 진입
#
#   대상: root 권한이 없는 Ubuntu 서버 (공용 서버의 개인 계정 포함).
#         전부 $HOME 안에만 쓴다 — apt·/usr/local·/etc 는 건드리지 않는다.
#         x86_64 · aarch64 둘 다 지원한다.
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
#   로그인 셸은 건드리지 않는다 (2026-08-31).
#     기본값은 "bash 로 로그인하고, 필요할 때 zsh 를 직접 실행"이다.
#     공용 서버에서는 로그인 흐름이 조용한 편이 낫다 — scp/rsync·CI·배포
#     스크립트가 대화형 여부를 잘못 판단하면 셸을 갈아치우는 쪽이 먼저 깨진다.
#     자동 진입을 원하면 --auto-zsh 를 준다 (섹션 6).
#
#   되돌리기: bash ~/dotfiles/server/uninstall.sh
# ============================================================================

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="$HOME/.local"
BIN="$PREFIX/bin"
SRC="$PREFIX/src"
MANIFEST="$PREFIX/share/dotfiles-server/manifest"

DRY_RUN=0
AUTO_ZSH=0     # --auto-zsh 를 줘야 ~/.bashrc 에 zsh 진입 블록을 넣는다

# 이전에는 `[[ "${1:-}" == "--dry-run" ]]` 로 첫 인자만 봤다. 플래그가 둘이
# 되면서 순서에 상관없이 받도록 루프로 바꾼다.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=1 ;;
        --auto-zsh) AUTO_ZSH=1 ;;
        -h|--help)
            echo "사용법: bash $0 [--dry-run] [--auto-zsh]"
            echo "  --dry-run    아무것도 바꾸지 않고 할 일만 출력"
            echo "  --auto-zsh   ~/.bashrc 에 zsh 자동 진입 블록을 추가"
            exit 0 ;;
        *) echo "알 수 없는 옵션: $1  (--help 참고)" >&2; exit 1 ;;
    esac
    shift
done

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
# 아키텍처별 자산 이름. 도구마다 표기가 달라서 셋으로 나눠 둔다.
#   ARCH_GNU  : rust 계열(eza·fd·bat) 의 <arch>-unknown-linux-gnu
#   ARCH_JQ   : jq 는 amd64/arm64 표기
#   ARCH_NVIM : neovim 은 x86_64/arm64 표기 (linux 만 하이픈 표기가 다르다)
# fzf·zoxide·starship·zsh-bin 은 자체 설치 스크립트가 uname -m 을 보고
# 알아서 고르므로 여기서 다루지 않는다.
case "$(uname -m)" in
    x86_64)
        ARCH_GNU="x86_64";  ARCH_JQ="amd64"; ARCH_NVIM="x86_64" ;;
    aarch64|arm64)
        ARCH_GNU="aarch64"; ARCH_JQ="arm64"; ARCH_NVIM="arm64" ;;
    *)
        die "지원하지 않는 아키텍처: $(uname -m) (x86_64 · aarch64 만 지원)" ;;
esac
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
        "https://github.com/jqlang/jq/releases/latest/download/jq-linux-${ARCH_JQ}"
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
        "https://github.com/eza-community/eza/releases/latest/download/eza_${ARCH_GNU}-unknown-linux-gnu.tar.gz"
    run tar -xzf "$SRC/eza.tar.gz" -C "$SRC"
    run mv -f "$SRC/eza" "$BIN/eza"
    run chmod 755 "$BIN/eza"
    run rm -f "$SRC/eza.tar.gz"
    record "$BIN/eza"
    ok "eza"
fi

# --- fd / bat — 자산 이름에 버전이 박혀 있어 API 로 태그를 먼저 조회한다 ---
# [파이프를 쓰지 않는 이유 — 2026-08-26 실제로 여기서 설치가 죽었다]
# 예전 구현은  curl ... | grep -m1 '"tag_name"' | cut -d'"' -f4  였다.
# grep -m1 은 첫 매치에서 즉시 끝나며 파이프를 닫는데, 그러면 curl 이
# 남은 응답을 쓰지 못해 "Failure writing output to destination" 으로
# 죽는다(플랫폼에 따라 exit 23 또는 56). 이 스크립트는 set -o pipefail
# 이라 그 실패가 파이프라인 전체의 실패가 되고, set -e 가 설치를 중단시킨다.
# 응답이 작아 curl 이 먼저 끝나면 통과하기도 해서 재현이 들쭉날쭉했다.
#
# 그래서 응답을 변수에 통째로 받은 뒤 bash 문자열 치환으로만 뽑는다.
# 외부 명령도 파이프도 없어 이 실패 자체가 불가능하다.
gh_latest_tag() {
    local json
    json="$(curl -fsSL --retry 3 --max-time 30 \
        "https://api.github.com/repos/$1/releases/latest")" || return 1
    case "$json" in
        *'"tag_name"'*) ;;
        *) return 1 ;;
    esac
    json="${json#*\"tag_name\"}"   # "tag_name" 앞을 버린다
    json="${json#*\"}"             # : 와 여는 따옴표를 버린다
    printf '%s' "${json%%\"*}"     # 닫는 따옴표 앞까지가 태그
}

install_sharkdp() {   # $1=repo  $2=binary
    local repo="$1" bin="$2" tag dir
    if command -v "$bin" &>/dev/null; then skip "$bin"; return 0; fi
    tag="$(gh_latest_tag "$repo")"
    [[ -n "$tag" ]] || die "$repo 최신 태그 조회 실패"
    dir="${bin}-${tag}-${ARCH_GNU}-unknown-linux-gnu"
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
#
# [디렉토리가 아니라 바이너리로 판단한다 — 2026-08-26 실제로 당했다]
# 예전 조건은  [[ -d "$HOME/.fzf" ]] || command -v fzf  였다. clone 은 됐는데
# install 이 실패하면 ~/.fzf 만 남는데, 그 뒤로는 디렉토리가 있다는 이유로
# 영원히 skip 되어 fzf 없는 상태가 고착된다. 실제로 그렇게 돼서
# cd<Tab> 을 누를 때마다 fzf-tab 이 fzf 를 못 찾고, Ubuntu 의
# command-not-found 가 "Please ask your administrator." 를 뱉었다.
# 껍데기 디렉토리가 남아 있으면 지우고 다시 받는다.
if command -v fzf &>/dev/null || [[ -x "$HOME/.fzf/bin/fzf" ]]; then
    skip "fzf"
else
    [[ -e "$HOME/.fzf" ]] && { run rm -rf "$HOME/.fzf"; info "불완전한 ~/.fzf 제거"; }
    run git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    run "$HOME/.fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
    # install 이 조용히 실패해도 여기서 잡는다 (dry-run 때는 검사하지 않는다)
    if [[ $DRY_RUN -eq 0 && ! -x "$HOME/.fzf/bin/fzf" ]]; then
        die "fzf 설치 실패 — ~/.fzf/bin/fzf 가 없습니다"
    fi
    # PATH 확보를 이중으로 한다. 원래 경로는 ~/.fzf.zsh 가 PATH 에 ~/.fzf/bin 을
    # 넣고 .zshrc:143 이 그걸 source 하는 것인데, 그 파일이 없거나 source 가
    # 실패하면 fzf 가 조용히 사라진다. $BIN 은 .zshrc:4 가 항상 PATH 에 넣으므로
    # 여기에 심링크를 걸어 두면 그 연결고리와 무관하게 잡힌다.
    run ln -sf "$HOME/.fzf/bin/fzf" "$BIN/fzf"
    record "$BIN/fzf"
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
    NVIM_ASSET="nvim-linux-${ARCH_NVIM}"
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
# 6. 로그인 시 zsh 진입  —  --auto-zsh 를 줄 때만 (기본 꺼짐)
#
#    chsh 는 쓸 수 없다: $HOME/.local/bin/zsh 가 /etc/shells 에 없고,
#    등록하려면 sudo 가 필요하다. 그래서 ~/.bashrc 에서 zsh 로 넘기는
#    우회로를 쓴다. 마커로 감싸 uninstall.sh 가 정확히 제거할 수 있게 한다.
#
#    [기본을 끔으로 바꾼 이유 — 2026-08-31]
#    공용 서버에서 "bash 로 로그인하고 필요할 때만 zsh" 를 쓰려는데 접속하자마자
#    zsh 로 넘어가 버렸다. exec 로 셸을 갈아치우는 동작이라 되돌릴 수도 없다.
#    자동 진입은 편의일 뿐이고, 없어도 `exec ~/.local/bin/zsh -l` 한 줄이면
#    똑같이 쓴다. 편의 때문에 로그인 흐름을 바꾸는 건 기본값으로 과하다.
# ============================================================================
echo ""
info "로그인 셸 연결..."

MARK_BEGIN="# >>> dotfiles server (zsh) >>>"
MARK_END="# <<< dotfiles server (zsh) <<<"

if [[ $AUTO_ZSH -eq 0 ]]; then
    if grep -qF "$MARK_BEGIN" "$HOME/.bashrc" 2>/dev/null; then
        warn "~/.bashrc 에 예전 zsh 진입 블록이 남아 있습니다."
        echo "      지우려면: bash $DOTFILES/server/uninstall.sh --bashrc-only"
    else
        # skip() 은 "(이미 설치됨)" 을 붙이므로 여기선 안 쓴다 — 설치를 건너뛴
        # 게 아니라 애초에 기본값이 꺼짐이다.
        echo -e "${YELLOW}⊘${NC} zsh 자동 진입 안 함 (원하면 --auto-zsh)"
    fi
elif grep -qF "$MARK_BEGIN" "$HOME/.bashrc" 2>/dev/null; then
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
if [[ $AUTO_ZSH -eq 1 ]]; then
    echo "  1. 새로 로그인하거나  exec \"$BIN/zsh\" -l"
else
    echo "  1. zsh 로 들어가려면:  exec \"$BIN/zsh\" -l"
    echo "     (로그인 시 자동 진입을 원하면 --auto-zsh 로 다시 실행)"
fi
echo "     → 첫 zsh 실행 때 zinit 이 자동으로 플러그인을 받습니다"
echo "        (zsh-completions · fzf-tab · autosuggestions · syntax-highlighting)"
echo "        수십 초 걸리고, 그동안 프롬프트가 잠깐 멈춘 것처럼 보입니다."
echo ""
echo ""
echo "되돌리기:  bash $DOTFILES/server/uninstall.sh"
echo ""
