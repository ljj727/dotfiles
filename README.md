# Dotfiles

한 줄이면 어디서든 동일한 셸 환경.

| 플랫폼 | 상태 |
|--------|------|
| macOS | 주 사용 환경. 실제로 검증됨 |
| Ubuntu / Debian | 지원. **아직 실기 검증은 안 됨** |
| Windows | 미지원 — WSL2 안에서 Ubuntu 경로로 동작 |

Debian 계열에서는 neovim 을 apt 대신 공식 릴리스로 설치한다 (apt 버전이 LazyVim 요구치 0.9 미만인 경우가 많음).
Finder 연동·Brewfile 은 macOS 전용이라 자동으로 건너뛴다.

```bash
git clone https://github.com/ljj727/dotfiles.git ~/dotfiles
bash ~/dotfiles/install.sh
```

## 새 맥 세팅 (맥을 갈아탈 때)

새 맥에는 Homebrew조차 없으므로 `install.sh`가 그것부터 깔고 `Brewfile`로 앱·도구를 일괄 복원한다.

```bash
xcode-select --install                                       # 1. CLT (git 필요)
git clone https://github.com/ljj727/dotfiles.git ~/dotfiles  # 2. clone
bash ~/dotfiles/install.sh                                   # 3. 나머지 전부
```

순서대로 Homebrew → Brewfile(앱·CLI·npm 전역) → Nerd Font → symlink → Claude 설정 → 기본 셸 zsh 까지 진행된다.

| 알아둘 것 | 내용 |
|-----------|------|
| 소요 시간 | Brewfile 전체 설치는 수십 분. GUI 앱(cask)이 대부분의 시간을 차지한다 |
| 암호 입력 | Homebrew 설치와 일부 cask에서 sudo 암호를 물어본다 (완전 무인 진행은 불가) |
| 업그레이드 안 함 | `--no-upgrade`로 **없는 것만** 설치. 기존 패키지를 멋대로 업그레이드하지 않는다 |
| 수동으로 남는 것 | App Store 앱, 로그인·자격증명, 은행 보안 플러그인, 시스템 설정 |

**Brewfile 갱신** — 앱을 새로 깔거나 지운 뒤 현재 상태를 다시 덤프:

```bash
cd ~/dotfiles && brew bundle dump --force --file=Brewfile
```

## 구조

```
~/dotfiles/
├── install.sh                  # bootstrap (이것만 실행)
├── Brewfile                    # macOS 앱·CLI·npm 전역 패키지 목록 (brew bundle)
├── zsh/.zshrc                  # portable zshrc (zinit + plugins)
├── starship/starship.toml      # 프롬프트 테마
├── tmux/.tmux.conf             # tmux 설정 (catppuccin)
├── tmux/tmux.reset.conf        # tmux 키바인딩
├── tmux/scripts/               # tmux 헬퍼 스크립트
├── wezterm/                    # WezTerm 터미널 (Mac only)
├── wezterm-windows/            # WezTerm Windows용 설정 (install.sh 대상 아님)
├── yazi/yazi.toml              # yazi 파일 매니저
├── nvim/                       # Neovim (LazyVim). ~/.config/nvim 으로 심링크
├── bin/open-in-terminal        # Finder에서 연 파일 → WezTerm + nvim 으로 열기
├── macos/                      # macOS 전용 (Finder 기본 앱 지정, .app 래퍼)
├── claude/                     # Claude Code 설정 (자세히는 claude/README.md)
│   └── install.sh              #   → ~/.claude 로 복사 (로컬 전용 파일 보존)
└── local/.zshrc.local.example  # 머신별 설정 예시
```

## Neovim (LazyVim)

`nvim/` 을 `~/.config/nvim` 으로 **심링크**한다. `lazy-lock.json`(플러그인 버전 고정)과
`lazyvim.json`(활성 extras)을 nvim이 직접 갱신하는데, 심링크여야 그 변경이 repo에 남는다.

**활성화된 extras** — `:LazyExtras` 에서 켜고 끄면 `lazyvim.json` 에 기록된다.

| extra | 얻는 것 |
|-------|---------|
| `lang.markdown` | render-markdown.nvim — 편집하면서 렌더링된 마크다운을 본다 (glow와 달리 편집 가능) |
| `lang.json` | SchemaStore 연동 — 스키마 검증·자동완성 |
| `lang.yaml` | 위와 동일 (yaml 스키마) |
| `lang.toml` | toml LSP |
| `lang.typescript` | ts/js/tsx LSP·포매터 |
| `lang.python` | python LSP·venv 선택기 |

새 머신에서는 첫 `nvim` 실행 시 lazy.nvim이 `lazy-lock.json` 버전 그대로 플러그인을 받고,
Mason이 LSP·포매터를 설치한다. 헤드리스로 미리 받으려면:

```bash
nvim --headless "+Lazy! sync" +qa
```

## Finder 기본 앱 (macOS)

`md`/`json`/`yaml`/소스코드 등 44개 확장자를 더블클릭했을 때 열릴 앱을 `duti` 로 지정한다.
**현재 기본값은 WezTerm 새 창의 nvim.**

```bash
bash macos/set-default-apps.sh local.openinterminal # → WezTerm 새 창의 nvim
bash macos/set-default-apps.sh <번들ID>              # → 다른 앱으로 지정
```

터미널로 여는 쪽을 고르면 `OpenInTerminal.app` 이 처리한다. Finder 가 CLI 를 직접 호출할 수 없어
`.app` 래퍼가 필요하기 때문이다. macOS 기본 터미널 설정과 무관하게 항상 WezTerm 을 쓴다.

**구성 요소**

| 파일 | 역할 |
|------|------|
| `macos/set-default-apps.sh` | `duti` 로 확장자별 기본 앱 지정 (인자로 번들 ID 전달 가능) |
| `bin/open-in-terminal` | WezTerm + nvim 으로 파일 열기 |
| `macos/OpenInTerminal.applescript` | Finder 가 CLI 를 못 부르므로 필요한 `.app` 래퍼 소스 |
| `macos/build-open-in-terminal.sh` | `~/Applications/OpenInTerminal.app` 빌드 (sudo 불필요) |

**되돌리기** — `duti -s com.apple.TextEdit md all` 처럼 원하는 앱으로 다시 지정.

**한계** — `toml`, `conf`, `go`, `rs`, `lua` 등 macOS가 모르는 확장자는 동적 UTI로 잡혀
`duti` 자동 지정이 거부된다. Finder에서 한 번만 "정보 가져오기 → 다음으로 열기 → 모두 변경" 하면 된다.

## install.sh이 하는 일

| 단계 | 내용 |
|------|------|
| OS 감지 | Ubuntu/Debian/macOS 자동 감지 |
| apt 패키지 | zsh, git, curl, wget, unzip, xclip, build-essential, ripgrep, tmux, ruby (Debian) |
| Homebrew | 없으면 설치 (macOS) |
| Brewfile | 앱·CLI·npm 전역 일괄 설치 (macOS, `--no-upgrade`) |
| CLI 도구 | eza, fd, bat, jq, fzf, zoxide, starship, nvm, yazi, neovim, tmuxinator |
| Nerd Font | JetBrainsMono (Debian 전용 — mac 은 Brewfile cask) |
| Symlink | .zshrc, starship, yazi, tmux, nvim (+ wezterm on Mac) |
| Finder 연동 | 기본 앱 지정 + `.app` 래퍼 빌드 (macOS) |
| Claude 설정 | `claude/install.sh` 호출 → `~/.claude` 로 복사 |
| 기본 셸 | zsh로 변경 |

이미 설치된 도구는 자동 스킵 (멱등성).

## Claude Code 설정

`claude/` 디렉토리에 공유 가능한 Claude 설정만 담는다 (자격증명·세션·캐시는 제외).

```bash
# 단독 실행도 가능 (install.sh에 포함되어 자동 실행됨)
bash ~/dotfiles/claude/install.sh
```

| 공유 ✅ | 로컬 전용 ❌ (건드리지 않음) |
|---------|------------------------------|
| `settings.json` (플러그인·마켓플레이스 선언) | `.credentials.json` (OAuth/키) |
| `CLAUDE.md` (개인 전역 지침) | `settings.local.json` (머신별 권한) |
| `statusline.sh` · `keybindings.json` · `themes/` | `sessions/` · `history.jsonl` · `cache/` |
| `commands/` · `agents/` · `skills/` | `plugins/` · `projects/` · `shell-snapshots/` |

**외형·조작 설정** (자세히는 `claude/README.md`)

| 항목 | 파일 | 내용 |
|------|------|------|
| 테마 | `themes/catppuccin-mocha.json` | WezTerm과 같은 Catppuccin Mocha 팔레트 |
| 상태줄 | `statusline.sh` | 모델 · 컨텍스트 게이지 · git 브랜치 · 사용량 · 경로 (`jq` 필요) |
| 키맵 | `keybindings.json` | transcript 뷰(`Ctrl+O`) 반페이지 스크롤 `u`/`d` |
| 알림음 | `settings.json` 의 hook | 응답 완료 시 Glass 사운드 (macOS 전용, 그 외엔 무해하게 무시) |

**동작 방식**
- **복사(copy)** 방식 — 기존 파일은 `~/.claude/.dotfiles-backup.<timestamp>/` 로 백업 후 덮어씀.
- 내용이 같으면 스킵 (멱등성). JSON은 Claude Code가 키 순서를 바꿔 다시 쓰므로 **정규화 후 비교**한다.
- **플러그인은 선언적으로 관리**: `plugins/` 캐시(절대경로·stale 상태)는 커밋하지 않고,
  `settings.json` 의 `enabledPlugins`/마켓플레이스만 공유 → 첫 `claude` 실행 시 자동 재설치.
- 로그인은 머신마다 `claude` 실행 후 직접 인증.

## 머신별 설정

`~/.zshrc.local`에서 머신 전용 경로를 관리:

```bash
# GPU 서버 예시
export PATH="/usr/local/cuda-11.8/bin:/opt/nvim-linux64/bin:$PATH"
export LD_LIBRARY_PATH=/usr/local/cuda-11.8/lib64:$LD_LIBRARY_PATH
export EDITOR=/opt/nvim-linux64/bin/nvim
```

이 파일은 gitignore 대상. 머신마다 다르게 설정.

## Zsh 플러그인 (zinit)

| 플러그인 | 설명 |
|----------|------|
| zsh-completions | 수백 개 명령어 tab completion |
| fzf-tab | tab → fzf 팝업 |
| zsh-autosuggestions | 히스토리 기반 자동 제안 |
| fast-syntax-highlighting | 실시간 구문 하이라이팅 |
| history-search-multi-word | Ctrl+R 다중 키워드 검색 |
| you-should-use | alias 알림 |
| sudo (omz) | ESC ESC → sudo 붙이기 |
| command-not-found (omz) | 패키지 설치 안내 |

## 주요 단축키

### 셸

| 키 | 기능 |
|----|------|
| `jk` | vi normal mode |
| `Ctrl+R` | 히스토리 검색 (multi-word) |
| `Ctrl+E` | autosuggestion accept |
| `↑` / `↓` | 입력 기반 히스토리 검색 |

### Git aliases

| alias | 명령 |
|-------|------|
| `gst` | git status |
| `gc "msg"` | git commit -m |
| `gp` | git push origin HEAD |
| `glog` | git log --graph |
| `ga` | git add -p |
| `gco` | git checkout |

### 도구

| 명령 | 설명 |
|------|------|
| `z <dir>` | zoxide (스마트 cd) |
| `yazi` | yazi (파일 매니저 + 이미지 프리뷰) |
| `vf` | fzf로 파일 찾아서 nvim으로 열기 |
| `cx <dir>` | cd + ls |
| `extract <file>` | 압축 해제 (tar/zip/7z 등) |

### WezTerm + tmux (Mac)

| 키 | 기능 |
|----|------|
| `Cmd+\` | SSH 호스트 선택 |
| `Cmd+,` | tmux 세션 선택 |
| `Cmd+Shift+N` | 새 세션 |
| `Cmd+t` / `Cmd+w` | 윈도우 열기/닫기 |
| `Cmd+1~5` | 윈도우 이동 |
| `Cmd+Shift+D/E` | 수직/수평 분할 |
| `Ctrl+hjkl` | pane 이동 |
| `Cmd+z` | pane 줌 |
| `Cmd+f` | yazi |
