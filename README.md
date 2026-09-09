# fuzzy-terminal-kit

Windows PowerShell과 Kali WSL에서 `ff`, `ffh`, `fh`를 사용하는 설치 프로젝트.

| 명령·키 | 기능 |
|---|---|
| `ff [경로]` | 파일 검색·내용 미리보기. 선택 경로 출력 |
| `ffh [경로]` | 숨김 파일 포함 검색 |
| `fh [검색어]` | 명령어 기록 검색. 선택한 명령 출력 |
| `Ctrl+R` | 기록 검색 후 입력줄에 삽입 |
| `Ctrl+T` | 파일 경로를 입력줄에 삽입 |
| `Alt+C` | 폴더 검색 후 이동 |

선택한 명령·파일을 자동 실행하지 않는다. `fzf`는 목록 검색, `fd`는 파일 목록 생성, `bat`는 텍스트 미리보기를 담당한다.

## 설치

GitHub에서 **Code → Download ZIP**을 선택하고 **전체 압축을 해제**한다. 설치 후 새 터미널을 연다. 프로젝트 폴더는 설치 후 이동하거나 삭제해도 된다.

### Windows

**`install-windows.cmd` 더블클릭.**

- Windows PowerShell **5.1**에 적용한다.
- 없는 `fzf`, `fd`, `bat`는 WinGet으로 설치한다. 패키지 설치에 따라 확인 창이 나타날 수 있다.
- 기존 프로필을 백업하고 이 프로젝트의 로드 블록만 추가한다.
- PowerShell 7은 해당 창에서 아래 명령을 실행한다.

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

WinGet이 없으면 Microsoft App Installer를 설치한 뒤 다시 실행한다. 프로필 실행이 정책에 의해 차단된 환경에서는 허용된 프로필 실행 정책이 필요하다. 설치 파일의 `Bypass`는 **설치 프로세스에만 적용**되며 영구 실행 정책을 바꾸지 않는다.

### Kali / Debian 계열

압축을 해제한 프로젝트 폴더에서:

```bash
bash install.sh
```

- 실행한 부모 셸이 Bash/Zsh이면 해당 셸을 선택하고, 아니면 `$SHELL`을 확인한다.
- 없는 패키지는 `sudo apt-get`으로 설치한다. sudo 비밀번호를 물어볼 수 있다.
- 기본 설정 파일은 `~/.bashrc` 또는 `~/.zshrc`다.
- 설치기 전체를 `sudo bash install.sh`로 실행하지 않는다. 그러면 root 사용자 설정에 적용된다.

셸을 직접 지정하려면:

```bash
bash install.sh --shell bash
# 또는
bash install.sh --shell zsh
```

Zsh의 `ZDOTDIR`를 별도로 사용한다면 `--profile "$ZDOTDIR/.zshrc"`로 경로를 지정한다. 다른 셸의 문법을 설정 파일에 넣거나 기본 로그인 셸을 변경하지 않는다.

## 사용

```bash
ff
ffh ~/.config
ff /usr/share/wordlists
fh nmap
```

Windows 경로 예:

```powershell
ff 'C:\Pentest\Wordlists'
```

| 검색창에 입력 | 의미 |
|---|---|
| `'wordlist` | 연속된 문자열 포함 |
| `^scan` | 해당 문자열로 시작 |
| `.txt$` | 해당 문자열로 끝 |
| `!backup` | 해당 문자열 제외 |

↑/↓로 이동, Enter로 선택, Esc/Ctrl+C로 취소한다. 파일 미리보기에서 Alt+J/K로 스크롤한다. 기록을 수정해 실행하려면 `fh` 대신 `Ctrl+R`을 사용한다.

## 기존 설정·재설치

- 같은 설치기를 다시 실행해도 로드 블록은 하나만 유지된다.
- 설치 전에 프로필과 기존 설치 파일의 사본을 만든다.
- 기존 수동 `ff`·`fh` 정의는 삭제하지 않으며 새 정의가 뒤에서 로드된다. 이전에 Enter 같은 키까지 재정의했다면 그 설정이 남아 있으므로 중복되는 수동 설정을 정리한다.
- 실행 파일이 이미 설치돼 있으면 자동으로 업그레이드하지 않는다. fzf 버전 검사가 실패하면 패키지 관리자로 업데이트한 뒤 다시 실행한다.

## 제거 / 복원

Windows: **`uninstall-windows.cmd` 더블클릭.** PowerShell 7은 해당 셸에서 `./install.ps1 -Uninstall`을 실행한다.

Kali:

```bash
bash install.sh --uninstall
```

제거는 프로젝트의 프로필 블록만 없앤다. 나중에 추가한 사용자 설정, 설치한 도구, 백업 파일은 남긴다. 새 터미널을 열어 적용한다.

**첫 설치 전의 프로필 전체로 돌아가려면** 다음을 사용한다. 설치 이후의 다른 수정도 되돌아간다. 복원 직전 파일은 별도 백업된다.

```powershell
.\install.ps1 -RestoreBackup
```

```bash
bash install.sh --restore-backup
```

| 환경 | 설치 파일·백업 위치 |
|---|---|
| Windows | `%LOCALAPPDATA%\fuzzy-terminal-kit\powershell-5` 또는 `powershell-7` |
| Kali | `${XDG_CONFIG_HOME:-~/.config}/fuzzy-terminal-kit` |

도구 설치는 패키지 관리자에서 처리되므로 패키지 제거는 별도다.

## 범위

- `ffh`는 숨김 파일을 포함하지만 ignore 규칙까지 해제하지 않는다.
- `.git`, `node_modules`, `.venv`, `__pycache__`, `dist`, `build`를 제외한다. 숨김 검색에서는 `.cache`, Windows에서는 `AppData`도 제외한다.
- 파일 미리보기는 앞 300줄이다. 이미지·PDF·압축파일 전용 미리보기나 용량별 건너뛰기는 구현하지 않았다.
- `fh`는 한 줄 명령 기준이다. 여러 줄 기록은 `Ctrl+R`을 우선 사용한다.
- POSIX의 줄바꿈 포함 파일명을 자동 처리하려는 용도는 아니다.
- `.bash_history`, `.zsh_history`, PowerShell 기록을 수집하거나 업로드하지 않는다.

## 개발·검증

테스트는 별도 프로필과 설치 경로를 사용한다. 실제 개인 프로필은 수정하지 않는다. 필요한 실행 파일은 미리 설치돼 있어야 한다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\windows.ps1
pwsh -NoProfile -File tests\windows.ps1
```

```bash
bash tests/linux.sh
# Zsh가 설치된 환경:
bash tests/zsh.sh
```

검증 결과와 스크린샷 해석은 [검증 기록](docs/validation.md)에 정리한다.

## GitHub 업로드

저장소 이름은 `fuzzy-terminal-kit`, 기본 브랜치는 `main`으로 사용하면 블로그에 준비한 주소와 일치한다. 이 폴더 **안의 내용**을 저장소 루트에 올린다. `.gitattributes`, `.gitignore`도 포함한다. `test-results/`는 제외한다.

예정 주소: `https://github.com/naaamgi/fuzzy-terminal-kit`

## 사용한 도구

- [fzf](https://github.com/junegunn/fzf)
- [fd](https://github.com/sharkdp/fd)
- [bat](https://github.com/sharkdp/bat)

각 도구는 별도 프로젝트이며 해당 프로젝트의 라이선스를 따른다.
