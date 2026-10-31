#!/usr/bin/env bash
# Decodes cliphist image entries to <dir>/<id>.<ext> for launcher previews;
# skips ones already decoded and drops files no longer in the history.
# usage: clip-thumbs.sh <dir> <id>.<ext>...
set -u
out=$1
shift
mkdir -p "$out"
for f in "$@"; do
    [ -s "$out/$f" ] && continue
    printf '%s\t\n' "${f%%.*}" | cliphist decode >"$out/$f" 2>/dev/null || rm -f "$out/$f"
done
keep=" $* "
for t in "$out"/*; do
    [ -e "$t" ] || continue
    case $keep in *" ${t##*/} "*) ;; *) rm -f "$t" ;; esac
done
