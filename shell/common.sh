# Shared by Bash and Zsh; source this file before shell integration.
export FZF_FD_BIN="$(command -v fdfind || command -v fd)"
export FZF_BAT_BIN="$(command -v batcat || command -v bat)"
if [ -z "$FZF_FD_BIN" ] || [ -z "$FZF_BAT_BIN" ] || ! command -v fzf >/dev/null; then
    printf '%s\n' 'Install fzf, fd-find and bat first.' >&2
    return 1
fi

export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
export FZF_DEFAULT_COMMAND='"$FZF_FD_BIN" --type f --exclude .git --exclude node_modules --exclude .venv'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS='--preview '\''"$FZF_BAT_BIN" --style=numbers --color=always --paging=never --line-range=:300 -- {}'\'' --preview-window=right:60% --bind=alt-j:preview-down,alt-k:preview-up'
export FZF_ALT_C_COMMAND='"$FZF_FD_BIN" --type d --exclude .git --exclude node_modules --exclude .venv'

_ftk_ff_run() (
    # A subshell keeps the caller's working directory unchanged.
    local hidden="$1" base="${2:-.}"
    cd -- "$base" || return
    local -a opts
    opts=(--type f --color never --absolute-path --print0
        --exclude .git --exclude node_modules --exclude .venv
        --exclude __pycache__ --exclude dist --exclude build)
    if [ "$hidden" = yes ]; then
        opts+=(--hidden --exclude .cache)
    fi
    "$FZF_FD_BIN" "${opts[@]}" |
        fzf --read0 --no-multi --height 80% --layout=reverse --border \
            --preview '"$FZF_BAT_BIN" --style=numbers --color=always --paging=never --line-range=:300 -- {}' \
            --preview-window=right:60% --bind 'alt-j:preview-down,alt-k:preview-up'
)
ff() { _ftk_ff_run no "${1:-.}"; }
ffh() { _ftk_ff_run yes "${1:-.}"; }
fpreview() { ff "$@"; }
