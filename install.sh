#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Dotfiles Bootstrap
# 사용법: bash ~/dotfiles/install.sh
# 멱등성: 이미 설치된 도구는 스킵
# ============================================================================

DOTFILES="$(cd "$(dirname "$0")" && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${BLUE}→${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
skip()  { echo -e "${YELLOW}⊘${NC} $*  (이미 설치됨)"; }
warn()  { echo -e "${YELLOW}!${NC} $*"; }
err()   { echo -e "${RED}✗${NC} $*"; exit 1; }

# ============================================================================
# OS 감지
# ============================================================================
OS="unknown"
if [[ "$OSTYPE" == darwin* ]]; then
    OS="mac"
elif [[ -f /etc/os-release ]]; then
    source /etc/os-release
    if [[ "$ID" == "ubuntu" || "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
        OS="debian"
    fi
fi

if [[ "$OS" == "unknown" ]]; then
    err "지원하지 않는 OS. Ubuntu/Debian/macOS만 지원."
fi

echo ""
echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Dotfiles Installer             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
echo ""
info "OS: $OS"
echo ""

# ============================================================================
# 헬퍼: symlink (기존 파일 백업)
# ============================================================================
backup_and_link() {
    local src="$1" dst="$2"

    if [[ -L "$dst" ]]; then
        if [[ "$(readlink "$dst")" == "$src" ]]; then
            skip "symlink $dst"
            return
        fi
        rm "$dst"
    elif [[ -f "$dst" ]]; then
        local bak="${dst}.bak.$(date +%Y%m%d%H%M%S)"
        info "백업: $dst → $bak"
        mv "$dst" "$bak"
    fi

    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    ok "symlink $dst → $src"
}

# ============================================================================
# 1. 기본 패키지 (Debian/Ubuntu)
# ============================================================================
if [[ "$OS" == "debian" ]]; then
    info "apt 패키지 설치..."
    sudo apt-get update -qq
    # build-essential: nvim treesitter 컴파일 / ripgrep: LazyVim 검색 / ruby: tmuxinator
    sudo apt-get install -y -qq \
        zsh git curl wget unzip xclip fontconfig \
        build-essential ripgrep tmux ruby-full > /dev/null 2>&1
    ok "기본 패키지"
fi

# ============================================================================
# 1.5 Homebrew + Brewfile (macOS)
#     새 맥 부트스트랩: brew 자체가 없으므로 먼저 설치한 뒤 Brewfile을 적용한다.
#     --no-upgrade: 없는 것만 설치. 기존 패키지를 대량 업그레이드하지 않는다.
# ============================================================================
if [[ "$OS" == "mac" ]]; then
    echo ""
    if command -v brew &> /dev/null; then
        skip "Homebrew"
    else
        info "Homebrew 설치 (암호 입력이 필요할 수 있음)..."
        NONINTERACTIVE=1 /bin/bash -c \
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
            [[ -x "$brew_bin" ]] && eval "$("$brew_bin" shellenv)" && break
        done
        command -v brew &> /dev/null || err "Homebrew 설치 실패"
        ok "Homebrew"
    fi

    if [[ -f "$DOTFILES/Brewfile" ]]; then
        info "Brewfile 적용 (앱·CLI 도구 일괄 설치, 시간이 오래 걸릴 수 있음)..."
        # 실패해도 중단하지 않는다. cask 하나(예: 신뢰되지 않은 서드파티 tap) 때문에
        # symlink·nvim·Claude 설정까지 통째로 건너뛰는 게 훨씬 손해다.
        if brew bundle install --file="$DOTFILES/Brewfile" --no-upgrade; then
            ok "Brewfile"
        else
            warn "Brewfile 일부 실패 — 위 메시지 확인. 나머지 설치는 계속합니다."
            warn "  'untrusted tap' 오류라면:  brew trust <tap 이름>  후 재실행"
        fi
    fi
fi

# ============================================================================
# 2. CLI 도구 설치 (Debian용 — mac은 위 Brewfile에서 이미 처리됨)
# ============================================================================
echo ""
info "CLI 도구 설치..."

# --- eza ---
if command -v eza &> /dev/null; then
    skip "eza"
else
    if [[ "$OS" == "debian" ]]; then
        sudo mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null || true
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list > /dev/null
        sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        sudo apt-get update -qq && sudo apt-get install -y -qq eza > /dev/null 2>&1
    elif [[ "$OS" == "mac" ]]; then
        brew install eza
    fi
    ok "eza"
fi

# --- fd ---
if command -v fdfind &> /dev/null || command -v fd &> /dev/null; then
    skip "fd"
else
    if [[ "$OS" == "debian" ]]; then
        sudo apt-get install -y -qq fd-find > /dev/null 2>&1
        if command -v fdfind &> /dev/null && ! command -v fd &> /dev/null; then
            mkdir -p "$HOME/.local/bin"
            ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
        fi
    elif [[ "$OS" == "mac" ]]; then
        brew install fd
    fi
    ok "fd"
fi

# --- bat ---
if command -v batcat &> /dev/null || command -v bat &> /dev/null; then
    skip "bat"
else
    if [[ "$OS" == "debian" ]]; then
        sudo apt-get install -y -qq bat > /dev/null 2>&1
    elif [[ "$OS" == "mac" ]]; then
        brew install bat
    fi
    ok "bat"
fi

# --- jq (Claude Code 상태줄이 사용) ---
if command -v jq &> /dev/null; then
    skip "jq"
else
    if [[ "$OS" == "debian" ]]; then
        sudo apt-get install -y -qq jq > /dev/null 2>&1
    elif [[ "$OS" == "mac" ]]; then
        brew install jq
    fi
    ok "jq"
fi

# --- fzf ---
if command -v fzf &> /dev/null; then
    skip "fzf"
else
    if [[ "$OS" == "debian" ]]; then
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" 2>/dev/null
        "$HOME/.fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish
    elif [[ "$OS" == "mac" ]]; then
        brew install fzf
    fi
    ok "fzf"
fi

# --- zoxide ---
if command -v zoxide &> /dev/null; then
    skip "zoxide"
else
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    ok "zoxide"
fi

# --- starship ---
if command -v starship &> /dev/null; then
    skip "starship"
else
    curl -sSfL https://starship.rs/install.sh | sh -s -- -y
    ok "starship"
fi

# --- nvm ---
if [[ -d "$HOME/.nvm" ]]; then
    skip "nvm"
else
    curl -sSfLo- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    ok "nvm"
fi

# --- yazi ---
if command -v yazi &> /dev/null; then
    skip "yazi"
else
    if [[ "$OS" == "debian" ]]; then
        YAZI_VERSION=$(curl -s https://api.github.com/repos/sxyazi/yazi/releases/latest | grep tag_name | cut -d '"' -f 4)
        curl -Lo /tmp/yazi.zip "https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yazi-x86_64-unknown-linux-gnu.zip"
        unzip -oq /tmp/yazi.zip -d /tmp/yazi
        sudo mv /tmp/yazi/yazi-x86_64-unknown-linux-gnu/yazi /usr/local/bin/
        sudo chmod +x /usr/local/bin/yazi
        rm -rf /tmp/yazi /tmp/yazi.zip
    elif [[ "$OS" == "mac" ]]; then
        brew install yazi
    fi
    ok "yazi"
fi

# --- neovim ---
# Debian apt 의 neovim 은 LazyVim 요구치(0.9+)보다 낮은 경우가 많아 공식 릴리스를 쓴다.
nvim_version_ok() {
    command -v nvim &> /dev/null || return 1
    local major minor
    read -r major minor < <(nvim --version | head -1 | sed -E 's/^NVIM v([0-9]+)\.([0-9]+).*/\1 \2/')
    [[ "${major:-0}" -gt 0 || "${minor:-0}" -ge 9 ]]
}

if nvim_version_ok; then
    skip "neovim ($(nvim --version | head -1 | awk '{print $2}'))"
else
    if [[ "$OS" == "debian" ]]; then
        case "$(uname -m)" in
            x86_64)        NVIM_ASSET="nvim-linux-x86_64" ;;
            aarch64|arm64) NVIM_ASSET="nvim-linux-arm64" ;;
            *)             err "neovim: 지원하지 않는 아키텍처 $(uname -m)" ;;
        esac
        curl -sSfLo /tmp/nvim.tar.gz \
            "https://github.com/neovim/neovim/releases/latest/download/${NVIM_ASSET}.tar.gz"
        sudo rm -rf "/opt/$NVIM_ASSET"
        sudo tar -C /opt -xzf /tmp/nvim.tar.gz
        sudo ln -sf "/opt/$NVIM_ASSET/bin/nvim" /usr/local/bin/nvim
        rm -f /tmp/nvim.tar.gz
    elif [[ "$OS" == "mac" ]]; then
        brew install neovim
    fi
    ok "neovim"
fi

# --- tmuxinator (tmux 자체는 Debian apt / mac Brewfile 에서 설치됨) ---
if command -v tmuxinator &> /dev/null; then
    skip "tmuxinator"
else
    if [[ "$OS" == "debian" ]]; then
        gem install --user-install --no-document tmuxinator > /dev/null 2>&1
        # .zshrc 의 PATH 에 이미 ~/.local/bin 이 있으므로 거기로 링크
        mkdir -p "$HOME/.local/bin"
        GEM_BIN="$(ruby -e 'require "rubygems"; print Gem.user_dir' 2>/dev/null)/bin/tmuxinator"
        [[ -x "$GEM_BIN" ]] && ln -sf "$GEM_BIN" "$HOME/.local/bin/tmuxinator"
    elif [[ "$OS" == "mac" ]]; then
        brew install tmuxinator
    fi
    ok "tmuxinator"
fi

# ============================================================================
# 3. Nerd Font (Debian 전용 — mac 은 Brewfile 의 cask 폰트로 설치된다)
# ============================================================================
if [[ "$OS" == "debian" ]]; then
    echo ""
    FONT_DIR="$HOME/.local/share/fonts"
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono\|FiraCode"; then
        skip "Nerd Font"
    else
        info "JetBrainsMono Nerd Font 설치..."
        mkdir -p "$FONT_DIR"
        wget -qO /tmp/JetBrainsMono.zip \
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
        unzip -oq /tmp/JetBrainsMono.zip -d "$FONT_DIR"
        rm -f /tmp/JetBrainsMono.zip
        fc-cache -f "$FONT_DIR"
        ok "JetBrainsMono Nerd Font"
    fi
fi

# ============================================================================
# 4. Symlinks
# ============================================================================
echo ""
info "Symlink 설정..."

# zsh
backup_and_link "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"

# starship — .zshrc 의 STARSHIP_CONFIG 가 ~/.config/starship/starship.toml 을 가리킨다
mkdir -p "$HOME/.config/starship"
backup_and_link "$DOTFILES/starship/starship.toml" "$HOME/.config/starship/starship.toml"

# yazi
mkdir -p "$HOME/.config/yazi"
backup_and_link "$DOTFILES/yazi/yazi.toml" "$HOME/.config/yazi/yazi.toml"

# ghostty (Mac only) — WezTerm 과 병행. 설정 파일 하나뿐
if [[ "$OS" == "mac" && -f "$DOTFILES/ghostty/config" ]]; then
    mkdir -p "$HOME/.config/ghostty"
    backup_and_link "$DOTFILES/ghostty/config" "$HOME/.config/ghostty/config"
fi

# tmux (Mac에서만 WezTerm과 함께 사용)
backup_and_link "$DOTFILES/tmux/.tmux.conf" "$HOME/.tmux.conf"
mkdir -p "$HOME/.config/tmux"
backup_and_link "$DOTFILES/tmux/tmux.reset.conf" "$HOME/.config/tmux/tmux.reset.conf"
backup_and_link "$DOTFILES/tmux/theme.conf" "$HOME/.config/tmux/theme.conf"
if [[ -d "$DOTFILES/tmux/scripts" ]]; then
    # ln -sfn 은 대상이 "실제 디렉토리"면 덮어쓰지 않고 그 안에 링크를 만든다.
    # (~/.config/tmux/scripts/scripts 가 생기고, 바깥의 오래된 사본이 계속 쓰인다.
    #  실제로 이 상태였고 dotfiles 의 스크립트 수정이 반영되지 않고 있었다.)
    # nvim 쪽과 같은 방식으로 먼저 백업해 치운다.
    if [[ -e "$HOME/.config/tmux/scripts" && ! -L "$HOME/.config/tmux/scripts" ]]; then
        mv "$HOME/.config/tmux/scripts" \
           "$HOME/.config/tmux/scripts.bak.$(date +%Y%m%d%H%M%S)"
        info "기존 ~/.config/tmux/scripts 백업"
    fi
    ln -sfn "$DOTFILES/tmux/scripts" "$HOME/.config/tmux/scripts"
    ok "symlink ~/.config/tmux/scripts → $DOTFILES/tmux/scripts"
fi

# nvim (LazyVim) — 디렉토리 통째로 심링크.
# lazy-lock.json / lazyvim.json 은 nvim 이 직접 갱신하므로 링크여야 repo 에 반영된다.
if [[ -e "$HOME/.config/nvim" && ! -L "$HOME/.config/nvim" ]]; then
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak.$(date +%Y%m%d%H%M%S)"
    info "기존 ~/.config/nvim 백업"
fi
mkdir -p "$HOME/.config"
ln -sfn "$DOTFILES/nvim" "$HOME/.config/nvim"
ok "symlink ~/.config/nvim → $DOTFILES/nvim"

# wezterm (Mac only)
if [[ "$OS" == "mac" ]]; then
    mkdir -p "$HOME/.config/wezterm"
    for f in "$DOTFILES"/wezterm/*.lua; do
        backup_and_link "$f" "$HOME/.config/wezterm/$(basename "$f")"
    done
fi

# ============================================================================
# 5. ~/.zshrc.local (없을 때만 예시 복사)
# ============================================================================
if [[ ! -f "$HOME/.zshrc.local" ]]; then
    cp "$DOTFILES/local/.zshrc.local.example" "$HOME/.zshrc.local"
    ok "~/.zshrc.local 생성됨 — 머신에 맞게 수정하세요"
else
    skip "~/.zshrc.local"
fi

# ============================================================================
# 5.3 Finder 기본 앱 → 터미널 (macOS)
#     md/json/yaml/소스코드를 더블클릭하면 WezTerm 새 창의 nvim/jless/glow 로 열린다.
# ============================================================================
if [[ "$OS" == "mac" && -f "$DOTFILES/macos/build-open-in-terminal.sh" ]]; then
    echo ""
    info "Finder → 터미널 연동..."
    bash "$DOTFILES/macos/build-open-in-terminal.sh"
    bash "$DOTFILES/macos/set-default-apps.sh"
fi

# ============================================================================
# 5.5 Claude Code 설정 (있을 때만)
# ============================================================================
if [[ -f "$DOTFILES/claude/install.sh" ]]; then
    echo ""
    info "Claude Code 설정 설치..."
    bash "$DOTFILES/claude/install.sh"
fi

# ============================================================================
# 6. 기본 셸 → zsh
# ============================================================================
echo ""
ZSH_PATH="$(which zsh)"
if [[ "$SHELL" == "$ZSH_PATH" ]]; then
    skip "zsh 기본 셸"
else
    info "기본 셸 → zsh"
    chsh -s "$ZSH_PATH"
    ok "기본 셸 변경 (다음 로그인부터 적용)"
fi

# ============================================================================
# 완료
# ============================================================================
echo ""
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo -e "${GREEN}  설치 완료!${NC}"
echo -e "${GREEN}══════════════════════════════════════${NC}"
echo ""
echo "  다음 단계:"
echo "  1. exec zsh (또는 새 터미널)"
echo "  2. ~/.zshrc.local 머신별 설정 확인"
echo "  3. 터미널 폰트 → JetBrainsMono Nerd Font"
echo ""
echo "  주요 도구:"
echo "  z <dir>   zoxide (스마트 cd)"
echo "  yazi      yazi (파일 매니저)"
echo ""
