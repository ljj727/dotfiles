# VSCode — 설정 스냅샷 (심링크 아님)

**이 디렉토리는 기록용 사본이다. `install.sh` 가 심링크하지 않는다.**

실제로 쓰이는 파일은 여기다:

```
~/Library/Application Support/Code/User/settings.json
~/Library/Application Support/Code/User/keybindings.json
```

VSCode 설정은 **VSCode 자체 Settings Sync**(Microsoft/GitHub 계정)로 동기화하고
있고, dotfiles 는 관여하지 않는다. 두 곳에서 관리하면 반드시 어긋나기 때문이다.

## 그래서 주의할 것

이 파일들은 **복사한 시점의 상태**다. VSCode 에서 설정을 바꿔도 자동으로
갱신되지 않는다. 실제 설정과 다를 수 있다는 뜻이다.

2026-08-28 에 실제로 그 착각이 있었다 — 여기 파일이 2023년 12월 사본인 채로
남아 있는데 "dotfiles 에 정리해 뒀다"고 오해했다.

## 갱신하는 법

```bash
cd ~/dotfiles
D=~/Library/Application\ Support/Code/User
cp "$D/settings.json" vscode/settings.json
cp "$D/keybindings.json" vscode/keybindings.json
code --list-extensions | sort > vscode/extensions.txt
```

## 파일

| 파일 | 내용 |
|------|------|
| `settings.json` | 에디터·테마·색 커스터마이징 |
| `keybindings.json` | 키 재정의 (`-` 접두사는 기본 바인딩 해제) |
| `extensions.txt` | 설치된 확장 목록. 복원은 아래 참고 |

## 확장 복원

```bash
xargs -n1 code --install-extension < vscode/extensions.txt
```

## 이력

- 원래 `vscode/` 는 Local History·workspaceStorage 잔해까지 189개 파일이
  `0d6bb5d "Init dotfiles"` 로 딸려 들어왔다가 `d8d664f` 에서 삭제됐다.
  2026-08-26 에 그중 참고 가치가 있는 3개만 꺼내 이 디렉토리를 만들었다.
  나머지를 되살리려면: `git archive 0d6bb5d vscode/ | tar -x -C <경로>`
