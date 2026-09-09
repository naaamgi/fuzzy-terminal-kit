# Zsh only: add after sourcing fuzzy-common.sh.
source <(fzf --zsh)
fh() {
    emulate -L zsh
    local selected
    selected=$(fc -lnr 1 | fzf --no-sort --no-multi --query="$*") || return
    [[ -n "$selected" ]] && print -r -- "$selected"
}
