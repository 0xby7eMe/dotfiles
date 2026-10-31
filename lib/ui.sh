# Output helpers: monochrome, like the rest of the rice.

if [[ -t 1 ]]; then
    _W=$'\e[38;5;255m' _L=$'\e[38;5;250m' _D=$'\e[38;5;244m' _F=$'\e[38;5;240m'
    _B=$'\e[1m' _R=$'\e[0m'
else
    _W='' _L='' _D='' _F='' _B='' _R=''
fi

step() { printf '\n%s%s◆ %s%s\n' "$_W" "$_B" "$*" "$_R"; }
info() { printf '  %s·%s %s%s\n' "$_D" "$_L" "$*" "$_R"; }
ok()   { printf '  %s✓%s %s%s\n' "$_W" "$_L" "$*" "$_R"; }
skip() { printf '  %s–%s %s%s\n' "$_F" "$_D" "$*" "$_R"; }
warn() { printf '  %s%s!%s %s%s\n' "$_W" "$_B" "$_R$_W" "$*" "$_R" >&2; }
die()  { printf '\n  %s%s✗ %s%s\n\n' "$_W" "$_B" "$*" "$_R" >&2; exit 1; }

# ask "question" [y|n]: default answer second; --yes answers with the default.
ask() {
    local q=$1 def=${2:-y} hint reply
    [[ $def == y ]] && hint="Y/n" || hint="y/N"
    if [[ ${ASSUME_YES:-0} == 1 || ! -r /dev/tty ]]; then
        printf '  %s?%s %s %s[%s]%s %s\n' "$_W" "$_L" "$q" "$_D" "$hint" "$_R" "$def"
        [[ $def == y ]]
        return
    fi
    printf '  %s?%s %s %s[%s]%s ' "$_W" "$_L" "$q" "$_D" "$hint" "$_R"
    read -r reply </dev/tty || reply=
    reply=${reply:-$def}
    [[ ${reply,,} == y* ]]
}

# run cmd...: execute, or just print it with --dry-run.
run() {
    if [[ ${DRY_RUN:-0} == 1 ]]; then
        printf '  %s$ %s%s\n' "$_F" "$*" "$_R"
        return 0
    fi
    "$@"
}

# root_write <path>: write stdin to a root-owned file, only if it changed.
# Returns 0 when the file was (or would be) changed, 1 when it was already up to date.
root_write() {
    local path=$1 tmp
    tmp=$(mktemp)
    cat > "$tmp"
    if [[ -f $path ]] && cmp -s "$tmp" "$path"; then
        rm -f "$tmp"
        return 1
    fi
    if [[ ${DRY_RUN:-0} == 1 ]]; then
        printf '  %s> %s%s\n' "$_F" "$path" "$_R"
        sed "s/^/  $_F│ /; s/\$/$_R/" "$tmp"
    else
        sudo install -Dm644 "$tmp" "$path"
    fi
    rm -f "$tmp"
    return 0
}

# Package list files: one name per line, "#" comments.
read_list() { grep -vE '^\s*(#|$)' "$1" | sed 's/\s*#.*//'; }
