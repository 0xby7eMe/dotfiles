# The cat from 0xby7eMe (components/tools/AsciiCat.tsx), for the terminal.
# Same tricks as the site: the fur decodes top-left to bottom-right, then the cat
# looks down at its laptop, types the command and blinks. Shaded by glyph density
# in 256-colour grays, like the neofetch art.

CAT_FILE="$DOTFILES/lib/cat.txt"
CAT_ROWS=$(wc -l < "$CAT_FILE")
CAT_COLS=$(awk '{ if (length($0) > m) m = length($0) } END { print m }' "$CAT_FILE")
CAT_SWEEP=$((CAT_ROWS * 2 + CAT_COLS))

# Patches laid over the art as row,col,text (0-based), joined by "|".
# Copied from the site: pupils move inside the white of each eye.
CAT_BLINK="9,32,%%%%|10,31,%%%%%|11,31,-----|12,32,%%%%|11,20,%%%|12,19,------|13,19,%%%%%%"
CAT_DOWN="10,31,     |11,31, #@# |12,19,      |13,19,  *#@ "

CAT_AWK='
BEGIN {
    srand(seed)
    glyphs = "!<>-_\\/[]{}=+*^?#01"
    np = split(patch, P, "|")
}
{ rows[NR - 1] = $0 }
function shade(ch) {
    if (index("@%#", ch)) return 255
    if (index("*+=", ch)) return 250
    if (index(";:", ch))  return 244
    return 240
}
END {
    for (i = 1; i <= np; i++) {
        a = index(P[i], ","); r = substr(P[i], 1, a - 1); rest = substr(P[i], a + 1)
        b = index(rest, ","); c = substr(rest, 1, b - 1); text = substr(rest, b + 1)
        line = rows[r]
        while (length(line) < c + length(text)) line = line " "
        rows[r] = substr(line, 1, c) text substr(line, c + length(text) + 1)
    }
    for (r = 0; r < NR; r++) {
        line = rows[r]; out = ""; cur = -1
        for (c = 0; c < length(line); c++) {
            ch = substr(line, c + 1, 1)
            if (ch == " ") { out = out ch; continue }
            if (progress != "" && r * 2 + c >= progress) {
                ch = substr(glyphs, int(rand() * length(glyphs)) + 1, 1); col = 238
            } else col = shade(ch)
            if (col != cur) { out = out sprintf("\033[38;5;%dm", col); cur = col }
            out = out ch
        }
        printf "  %s\033[0m\033[K\n", out
    }
    # the cat'\''s shell session, under the laptop
    printf "  %30s\033[38;5;244m> \033[38;5;255m%s\033[0m\033[K\n", "", prompt
}'

# cat_frame [patch] [prompt text] [decode progress]
cat_frame() {
    awk -v seed="$RANDOM" -v patch="${1:-}" -v prompt="${2:-}" -v progress="${3:-}" "$CAT_AWK" "$CAT_FILE"
}

# Move back up over the last frame so the next one draws in place.
_cat_rewind() { printf '\e[%dA' $((CAT_ROWS + 1)); }

# cat_intro <command>: decode, look down, type <command>, blink.
# Falls back to a still frame without a tty, on narrow terminals or with --no-anim.
cat_intro() {
    local cmd=$1 i
    [[ -t 1 ]] || return 0
    if (( $(tput cols 2>/dev/null || echo 80) < CAT_COLS + 4 )); then
        printf '\n  \e[38;5;255m=^.^=\e[38;5;244m  %s\e[0m\n' "$cmd"
        return 0
    fi
    if [[ ${NO_ANIM:-0} == 1 ]]; then
        echo; cat_frame "" "$cmd"
        return 0
    fi

    printf '\e[?25l'
    trap 'printf "\e[?25h"' RETURN
    echo
    for ((i = 0; i <= CAT_SWEEP; i += 4)); do
        ((i > 0)) && _cat_rewind
        cat_frame "" "" "$i"
        sleep 0.045
    done
    _cat_rewind; cat_frame "" "_"
    sleep 0.35
    for ((i = 1; i <= ${#cmd}; i++)); do
        _cat_rewind; cat_frame "$CAT_DOWN" "${cmd:0:i}_"
        sleep "0.0$((6 + RANDOM % 5))"
    done
    sleep 0.3
    _cat_rewind; cat_frame "" "$cmd"
    sleep 0.5
    _cat_rewind; cat_frame "$CAT_BLINK" "$cmd"
    sleep 0.13
    _cat_rewind; cat_frame "" "$cmd"
}
