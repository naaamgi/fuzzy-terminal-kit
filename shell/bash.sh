# Bash only: add after sourcing fuzzy-common.sh.
eval "$(fzf --bash)"
fh() {
    local selected
    selected=$(HISTTIMEFORMAT= builtin history |
        sed -E 's/^ *[0-9]+\*? +//' |
        awk '!seen[$0]++' |
        fzf --tac --no-sort --no-multi --query="$*") || return
    [ -n "$selected" ] && printf '%s\n' "$selected"
}
