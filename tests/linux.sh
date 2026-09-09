#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
case_dir=$(mktemp -d)
profile="$case_dir/bashrc"
prefix="$case_dir/space and 'quote/install"
printf '%s\n' '# existing profile' 'export FTK_EXISTING=kept' > "$profile"
cp "$profile" "$case_dir/baseline"
args=(--shell bash --profile "$profile" --prefix "$prefix" --skip-dependencies)
bash "$root/install.sh" "${args[@]}"
bash "$root/install.sh" "${args[@]}"
[[ $(grep -c '^# >>> fuzzy-terminal-kit >>>$' "$profile") == 1 ]]
bash -n "$profile"
bash --noprofile --norc -ic 'source "$1"; [[ $FTK_EXISTING == kept ]]; type ff ffh fh >/dev/null' _ "$profile"
source "$prefix/shell/common.sh"
fixture="$case_dir/files"
mkdir -p "$fixture/.hidden" "$fixture/node_modules"
printf preview > "$fixture/한글 space.txt"
printf hidden > "$fixture/.hidden/secret.txt"
printf excluded > "$fixture/node_modules/excluded.txt"
export FZF_DEFAULT_OPTS='--filter=space.txt$'
[[ $(ff "$fixture") == "$fixture/한글 space.txt" ]]
export FZF_DEFAULT_OPTS='--filter=secret.txt$'
if ff "$fixture"; then echo 'Hidden file leaked'; exit 1; fi
ffh "$fixture" | grep -q secret.txt
export FZF_DEFAULT_OPTS='--filter=excluded.txt$'
if ffh "$fixture"; then echo 'Excluded file leaked'; exit 1; fi
printf '%s\n' '# user edit after install' >> "$profile"
bash "$root/install.sh" "${args[@]}" --uninstall
! grep -q '^# >>> fuzzy-terminal-kit >>>$' "$profile"
grep -q '# user edit after install' "$profile"
bash "$root/install.sh" "${args[@]}" --restore-backup
cmp "$profile" "$case_dir/baseline"
printf 'PASS: install, repeat, quoted path, preservation, file selection, hidden/excluded files, uninstall, exact restore\nArtifacts: %s\n' "$case_dir"
