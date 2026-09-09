#!/usr/bin/env bash
set -euo pipefail
action=install
target_shell=
profile=
prefix="${XDG_CONFIG_HOME:-$HOME/.config}/fuzzy-terminal-kit"
skip_dependencies=no
while (( $# )); do
    case "$1" in
        --uninstall) action=uninstall; shift ;;
        --restore-backup) action=restore; shift ;;
        --skip-dependencies) skip_dependencies=yes; shift ;;
        --shell|--profile|--prefix)
            (( $# >= 2 )) || { echo "Missing value for $1" >&2; exit 1; }
            case "$1" in --shell) target_shell=$2;; --profile) profile=$2;; --prefix) prefix=$2;; esac
            shift 2 ;;
        --help)
            echo 'bash install.sh [--shell bash|zsh] [--uninstall|--restore-backup]'
            echo 'Advanced: --skip-dependencies --profile PATH --prefix PATH'
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done
if [[ -z $target_shell ]]; then
    target_shell=$(ps -p "$PPID" -o comm= 2>/dev/null | tr -d '[:space:]')
    case "$target_shell" in bash|zsh) ;; *) target_shell=${SHELL##*/};; esac
fi
case "$target_shell" in bash|zsh) ;; *) echo 'Use --shell bash or --shell zsh.' >&2; exit 1;; esac
profile=${profile:-"$HOME/.${target_shell}rc"}
prefix=$(realpath -m -- "$prefix")
profile=$(realpath -m -- "$profile")
state="$prefix/state/$target_shell"
start='# >>> fuzzy-terminal-kit >>>'
end='# <<< fuzzy-terminal-kit <<<'
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -e $state/profile ]] && [[ $(cat "$state/profile") != "$profile" ]]; then
    echo 'This prefix belongs to another profile. Use a different --prefix.' >&2; exit 1
fi
if [[ -d $prefix ]] && [[ ! -d $prefix/state ]] && [[ -n $(ls -A "$prefix") ]]; then
    echo 'Install prefix is not empty and has no installation state.' >&2; exit 1
fi
if [[ -f $profile ]]; then
    awk -v start="$start" -v end="$end" '
        $0==start { if (inside || seen++) exit 1; inside=1 }
        $0==end { if (!inside) exit 1; inside=0 }
        END { if (inside) exit 1 }
    ' "$profile" || { echo 'Broken managed block; repair the profile first.' >&2; exit 1; }
fi
if [[ $action != install && ! -f $state/profile ]]; then
    [[ $action != restore ]] || { echo 'No baseline backup exists.' >&2; exit 1; }
    echo 'Nothing installed for this shell.'; exit 0
fi
if [[ $action == install ]]; then
    for file in common.sh bash.sh zsh.sh; do
        [[ -f $source_dir/shell/$file ]] || { echo 'Extract the entire project ZIP first.' >&2; exit 1; }
    done
    missing=no
    command -v fzf >/dev/null || missing=yes
    { command -v fdfind || command -v fd; } >/dev/null || missing=yes
    { command -v batcat || command -v bat; } >/dev/null || missing=yes
    if [[ $missing == yes ]]; then
        [[ $skip_dependencies != yes ]] || { echo 'Install fzf, fd-find and bat first.' >&2; exit 1; }
        command -v apt-get >/dev/null || { echo 'Automatic packages require apt-get. Install fzf, fd and bat manually.' >&2; exit 1; }
        elevate=()
        if (( EUID != 0 )); then elevate=(sudo); fi
        "${elevate[@]}" apt-get update
        "${elevate[@]}" apt-get install -y fzf fd-find bat
    fi
    fzf "--$target_shell" >/dev/null || { echo 'Update fzf to a version with --bash/--zsh support.' >&2; exit 1; }
    bash -n "$source_dir/shell/common.sh" "$source_dir/shell/bash.sh"
    if [[ $target_shell == zsh ]]; then zsh -n "$source_dir/shell/common.sh"; zsh -n "$source_dir/shell/zsh.sh"; fi
fi

mkdir -p -- "$state" "$(dirname -- "$profile")"
snapshot="$prefix/backups/$target_shell-$(date +%Y%m%d-%H%M%S-%N)"
mkdir -p -- "$snapshot"
[[ ! -f $profile ]] || cp -p -- "$profile" "$snapshot/profile"
if [[ ! -f $state/profile ]]; then
    printf '%s\n' "$profile" > "$state/profile"
    if [[ -f $profile ]]; then cp -p -- "$profile" "$state/baseline"; fi
fi
if [[ $action == restore ]]; then
    if [[ -f $state/baseline ]]; then cp -p -- "$state/baseline" "$profile"; else rm -f -- "$profile"; fi
    printf 'Baseline restored. Previous profile backed up: %s\n' "$snapshot"
    exit 0
fi
tmp=$(mktemp)
trap 'rm -f -- "$tmp"' EXIT
if [[ -f $profile ]]; then
    awk -v start="$start" -v end="$end" '$0==start {inside=1; next} $0==end {inside=0; next} !inside {print}' "$profile" > "$tmp"
fi
if [[ $action == install ]]; then
    mkdir -p -- "$prefix/shell"
    for file in common.sh bash.sh zsh.sh; do
        [[ ! -f $prefix/shell/$file ]] || cp -p -- "$prefix/shell/$file" "$snapshot/$file"
        cp -- "$source_dir/shell/$file" "$prefix/shell/$file"
    done
    # Single-quote the path for both Bash and Zsh (never evaluate file content).
    quote_path() { printf "'%s'" "${1//\'/\'\\\'\'}"; }
    {
        printf '%s\n' "$start"
        printf 'if [ -r '; quote_path "$prefix/shell/common.sh"; printf ' ]; then\n'
        printf '  source '; quote_path "$prefix/shell/common.sh"; printf ' && source '; quote_path "$prefix/shell/$target_shell.sh"; printf '\n'
        printf 'fi\n%s\n' "$end"
    } >> "$tmp"
fi
if [[ -f $profile ]]; then cat "$tmp" > "$profile"; else install -m 600 "$tmp" "$profile"; fi
printf '%s: %s\nBackup: %s\n' "$action" "$profile" "$snapshot"
echo 'Open a new terminal. Commands: ff, ffh, fh. Keys: Ctrl+R, Ctrl+T, Alt+C.'
