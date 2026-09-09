#!/usr/bin/env bash
set -euo pipefail
command -v zsh >/dev/null
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
case_dir=$(mktemp -d)
profile="$case_dir/zshrc"
prefix="$case_dir/space and 'quote/install"
printf '%s\n' '# existing profile' 'export FTK_EXISTING=kept' > "$profile"
cp "$profile" "$case_dir/baseline"
args=(--shell zsh --profile "$profile" --prefix "$prefix" --skip-dependencies)
bash "$root/install.sh" "${args[@]}"
bash "$root/install.sh" "${args[@]}"
[[ $(grep -c '^# >>> fuzzy-terminal-kit >>>$' "$profile") == 1 ]]
mkdir -p "$case_dir/files/.hidden"
printf preview > "$case_dir/files/한글 space.txt"
printf hidden > "$case_dir/files/.hidden/secret.txt"
zsh -f -i -c '
    if [[ -n ${FTK_TEST_MODULE_PATH:-} ]]; then module_path=("$FTK_TEST_MODULE_PATH" $module_path); fi
    zmodload zsh/zle || exit 1
    source "$1" || exit 1
    [[ $(bindkey "^R") == *fzf-history-widget* ]] || exit 1
    [[ $(bindkey "^T") == *fzf-file-widget* ]] || exit 1
    [[ $FTK_EXISTING == kept ]] || exit 1
    whence -w ff ffh fh
    export FZF_DEFAULT_OPTS="--filter=space.txt\$"
    [[ $(ff "$2") == "$2/한글 space.txt" ]] || exit 1
    export FZF_DEFAULT_OPTS="--filter=secret.txt\$"
    [[ -z $(ff "$2") ]] || exit 1
    [[ $(ffh "$2") == "$2/.hidden/secret.txt" ]] || exit 1
    print -s -- "echo zsh-history-fixture"
    export FZF_DEFAULT_OPTS="--filter=zsh-history-fixture"
    [[ $(fh) == *zsh-history-fixture* ]] || exit 1
' _ "$profile" "$case_dir/files"
printf '%s\n' '# user edit after install' >> "$profile"
bash "$root/install.sh" "${args[@]}" --uninstall
! grep -q '^# >>> fuzzy-terminal-kit >>>$' "$profile"
grep -q '# user edit after install' "$profile"
bash "$root/install.sh" "${args[@]}" --restore-backup
cmp "$profile" "$case_dir/baseline"
printf 'PASS Zsh: repeat install, quoted path, profile, files, hidden, history, uninstall, restore\nArtifacts: %s\n' "$case_dir"
