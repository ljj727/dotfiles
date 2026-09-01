# ============================================================================
# PATH
# ============================================================================
export PATH="/opt/homebrew/bin:$HOME/.local/bin:$HOME/.local/share/pnpm:$PATH"

# ============================================================================
# Zinit - 플러그인 매니저
# https://github.com/zdharma-continuum/zinit
# 첫 실행 시 자동 설치됨
# ============================================================================
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing zinit...%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git"
fi
source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# ============================================================================
# Completions
# compinit은 fzf-tab보다 먼저 와야 함
# 24시간마다 한번만 재생성 (.zcompdump 캐싱)
# ============================================================================
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi
autoload bashcompinit && bashcompinit

# ============================================================================
# Zinit Plugins
#
# [로딩 순서 중요!]
# 1. zsh-completions  — 추가 completion 정의 (compinit 뒤)
# 2. fzf-tab          — tab 완성을 fzf로 교체 (compinit 뒤, autosuggestions 앞)
# 3. zsh-autosuggestions — 히스토리 기반 자동 제안
# 4. fast-syntax-highlighting — 실시간 구문 하이라이팅 (반드시 마지막)
# 5. 나머지는 순서 무관
# ============================================================================

# zsh-completions: docker, cargo, fd, rg 등 수백 개 명령어의 tab completion 추가
zinit light zsh-users/zsh-completions

# fzf-tab: Tab 누르면 기본 zsh 메뉴 대신 fzf 팝업이 뜸
zinit light Aloxaf/fzf-tab

# zsh-autosuggestions: 타이핑하면 히스토리 기반 회색 제안이 뜸
zinit light zsh-users/zsh-autosuggestions

# fast-syntax-highlighting: 명령어를 치는 동안 실시간으로 색상 표시
# [주의] 반드시 autosuggestions 뒤에 로드해야 충돌 없음
zinit light zdharma-continuum/fast-syntax-highlighting

# history-search-multi-word 는 제거했다 (2026-09-01) — ^R 을 fzf 에 넘겼다.
# 되살리려면 이 줄과 아래 FZF 섹션의 bindkey 를 같이 되돌려야 한다:
#   zinit load zdharma-continuum/history-search-multi-word

# you-should-use: alias가 있는 명령을 풀로 치면 "alias 쓰라"고 알려줌
zinit light MichaelAquilina/zsh-you-should-use

# OMZP::sudo: ESC 두 번 → 현재/이전 명령어 앞에 sudo 붙여줌
zinit snippet OMZP::sudo

# OMZP::command-not-found: 없는 명령어 치면 어떤 패키지를 설치해야 하는지 알려줌
zinit snippet OMZP::command-not-found

# ============================================================================
# Autosuggestions 설정
# ============================================================================
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666,underline"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# ============================================================================
# fzf-tab 설정
# ============================================================================
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:ls:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:cat:*' fzf-preview 'batcat --color=always --line-range :50 $realpath 2>/dev/null || cat $realpath'
zstyle ':fzf-tab:*' fzf-flags --height=40%
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

# ============================================================================
# PNPM
# ============================================================================
export PNPM_HOME="$HOME/.local/share/pnpm"

# ============================================================================
# NVM
# ============================================================================
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# ============================================================================
# Environment
# ============================================================================
export XDG_CONFIG_HOME="$HOME/.config"
export LANG=en_US.UTF-8
export EDITOR=nvim
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow'
export FZF_DEFAULT_OPTS="--bind 'ctrl-j:down,ctrl-k:up'"

# ============================================================================
# Starship
# ============================================================================
export STARSHIP_CONFIG=~/.config/starship/starship.toml

# ============================================================================
# History
# ============================================================================
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt APPEND_HISTORY

# ============================================================================
# Options & Keybindings
# ============================================================================
setopt prompt_subst
export KEYTIMEOUT=15
bindkey jj vi-cmd-mode
bindkey '^F' forward-char
bindkey '^B' backward-char
bindkey '^E' end-of-line
bindkey '^A' beginning-of-line
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[OA' history-search-backward
bindkey '^[OB' history-search-forward

# ============================================================================
# FZF
# ============================================================================
# 셸 통합 — ^R 히스토리, ^T 파일 경로 삽입, ⌥C 디렉토리 이동.
#
# 예전에는 `[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh` 만 있었는데, 그 파일은
# fzf 설치 방식에 따라 안 생긴다 (맥 brew 는 안 만든다). 그래서 맥에서는
# fzf 통합이 통째로 빠져 있었다 — ^T 가 self-insert 였다 (2026-09-01 확인).
# fzf 0.48+ 는 `fzf --zsh` 로 스크립트를 직접 뱉으므로 그쪽을 먼저 쓴다.
#
# fzf 가 없으면 조용히 건너뛴다 (서버에 없을 수 있다).
if (( $+commands[fzf] )); then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  elif [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
  fi
fi

# ^R 은 fzf 로 간다 (2026-09-01).
# 예전에는 여기서 ^R 을 뺏어 history-search-multi-word 에 줬다. 그쪽은 자체
# hsmw keymap 을 ^R 누를 때마다 emacs 에서 새로 만들기 때문에(플러그인 281행)
# ^J/^K 같은 키를 추가할 방법이 없었다. fzf 는 FZF_DEFAULT_OPTS 의
# ctrl-j/ctrl-k 가 그대로 먹는다.
#
# main keymap 이 viins 다 — EDITOR 가 nvim 이라 zsh 가 vi 모드를 고른다.
# fzf 가 emacs/vicmd/viins 에 다 걸지만, main 에도 명시해 확실히 한다.
if (( $+widgets[fzf-history-widget] )); then
  bindkey '^R' fzf-history-widget
fi

# ^G — 파일을 골라 에디터로 연다 (2026-09-01).
#
# ^T 와 역할이 다르다: ^T 는 경로를 커서 위치에 "삽입"만 하고(`nvim ` 뒤에
# 붙여 쓰는 용도), ^G 는 고른 파일을 바로 "연다".
#
# 어디서 실행 중이냐에 따라 에디터가 갈린다:
#   VSCode 통합 터미널  → code -r -g   (-r = 현재 창 재사용)
#   그 외(ghostty/tmux) → $EDITOR (없으면 nvim)
# VSCode 안에서 nvim 을 터미널에 띄우면 에디터와 이중으로 겹쳐서 불편하다.
#
# ^G 를 고른 이유: zsh 기본은 list-expand 로 거의 안 쓰고, VSCode 쪽
# keybindings.json 에도 없다. VSCode 기본 ctrl+g(Go to Line)는 터미널
# 포커스일 때만 해제해 뒀다 (keybindings.json).
_dotfiles_edit_cmd() {
  if [[ -n "${VSCODE_INJECTION:-}" || "${TERM_PROGRAM:-}" == "vscode" ]] \
     && (( $+commands[code] )); then
    print -r -- "code -r -g"
  else
    print -r -- "${EDITOR:-nvim}"
  fi
}

fzf-edit-widget() {
  local sel
  if (( $+commands[fd] )); then
    sel="$(fd --type f --hidden --exclude .git 2>/dev/null | fzf --multi --prompt='edit ❯ ')"
  else
    sel="$(find . -type f -not -path '*/.*' 2>/dev/null | fzf --multi --prompt='edit ❯ ')"
  fi
  if [[ -n "$sel" ]]; then
    # 여러 줄 선택을 각각 따옴표 처리해 이어 붙인다 (공백 있는 경로 대비).
    # (@q) 여야 한다 — (q) 만 쓰면 배열을 문자열로 먼저 합친 뒤 따옴표를
    # 붙여서 구분자 공백까지 이스케이프된다 (`a\ b.txt\ c.txt`).
    local -a files
    files=("${(f)sel}")
    BUFFER="$(_dotfiles_edit_cmd) ${(j: :)${(@q)files}}"
    zle accept-line
  else
    zle reset-prompt
  fi
}
zle -N fzf-edit-widget
bindkey '^G' fzf-edit-widget

# ============================================================================
# Zoxide
# ============================================================================
eval "$(zoxide init zsh)"

# ============================================================================
# Starship (init은 마지막에)
# ============================================================================
eval "$(starship init zsh)"

# ============================================================================
# Aliases: Git
# ============================================================================
alias gc="git commit -m"
alias gca="git commit -a -m"
alias gp="git push origin HEAD"
alias gpu="git pull origin"
alias gst="git status"
alias glog="git log --graph --topo-order --pretty='%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N' --abbrev-commit"
alias gdiff="git diff"
alias gco="git checkout"
alias gb='git branch'
alias gba='git branch -a'
alias gadd='git add'
alias ga='git add -p'
alias gcoall='git checkout -- .'
alias gr='git remote'
alias gre='git reset'

# ============================================================================
# Aliases: Navigation
# ============================================================================
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."

# ============================================================================
# Aliases: SSH (xterm-ghostty terminfo 없는 서버 대응)
# ============================================================================
alias ssh='TERM=xterm-256color ssh'

# ============================================================================
# Aliases: Tools
# ============================================================================
alias vim="nvim"
alias cl='clear'
alias bat=batcat
alias la=tree
alias tm='task-master'
alias taskmaster='task-master'

# ============================================================================
# Aliases: Eza (ls 대체)
# ============================================================================
alias ls="eza --icons --git"
alias l="eza -l --icons --git -a"
alias lt="eza --tree --level=2 --long --icons --git"
alias ltree="eza --tree --level=2 --icons --git"

# ============================================================================
# Aliases: FZF helpers
# ============================================================================
alias vf='fd --type f --hidden --exclude .git | fzf-tmux -p --reverse | xargs nvim'

# ============================================================================
# Aliases: Network/Security
# ============================================================================
alias nm="nmap -sC -sV -oN nmap"
alias gobust='gobuster dir --wordlist ~/security/wordlists/diccnoext.txt --wildcard --url'
alias dirsearch='python dirsearch.py -w db/dicc.txt -b -u'
alias massdns='~/hacking/tools/massdns/bin/massdns -r ~/hacking/tools/massdns/lists/resolvers.txt -t A -o S bf-targets.txt -w livehosts.txt -s 4000'
alias server='python -m http.server 4445'
alias tunnel='ngrok http 4445'
alias fuzz='ffuf -w ~/hacking/SecLists/content_discovery_all.txt -mc all -u'
alias mat='osascript -e "tell application \"System Events\" to key code 126 using {command down}" && tmux neww "cmatrix"'

# ============================================================================
# Functions
# ============================================================================
function ranger {
    local IFS=$'\t\n'
    local tempfile="$(mktemp -t tmp.XXXXXX)"
    local ranger_cmd=(
        command
        ranger
        --cmd="map Q chain shell echo %d > "$tempfile"; quitall"
    )
    ${ranger_cmd[@]} "$@"
    if [[ -f "$tempfile" ]] && [[ "$(cat -- "$tempfile")" != "$(echo -n `pwd`)" ]]; then
        cd -- "$(cat "$tempfile")" || return
    fi
    command rm -f -- "$tempfile" 2>/dev/null
}
alias rr='ranger'

cx() { cd "$@" && l; }
fcd() { cd "$(find . -type d -not -path '*/.*' | fzf)" && l; }
f() { echo "$(find . -type f -not -path '*/.*' | fzf)" | pbcopy }
fv() { nvim "$(find . -type f -not -path '*/.*' | fzf)" }

extract() {
    if [[ -z "$1" ]]; then
        echo "Usage: extract <archive>"
        return 1
    fi
    if [[ ! -f "$1" ]]; then
        echo "'$1' is not a valid file"
        return 1
    fi
    case "$1" in
        *.tar.bz2) tar xvjf "$1"   ;;
        *.tar.gz)  tar xvzf "$1"   ;;
        *.tar.xz)  tar xvJf "$1"   ;;
        *.bz2)     bunzip2 "$1"    ;;
        *.rar)     unrar x -ad "$1";;
        *.gz)      gunzip "$1"     ;;
        *.tar)     tar xvf "$1"    ;;
        *.tbz2)    tar xvjf "$1"   ;;
        *.tgz)     tar xvzf "$1"   ;;
        *.zip)     unzip "$1"      ;;
        *.Z)       uncompress "$1" ;;
        *.7z)      7z x "$1"       ;;
        *.xz)      unxz "$1"       ;;
        *)         echo "'$1' - unknown archive type" ;;
    esac
}

# ============================================================================
# Nix
# ============================================================================
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

# ============================================================================
# Machine-local overrides (cuda, nvim path, etc.)
# ============================================================================
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

