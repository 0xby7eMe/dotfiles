#!/usr/bin/env bash
# Builds 480x300 jpg thumbnails for the wallpaper picker; skips up-to-date ones.
# usage: wallpaper-thumbs.sh <wallpaper dir> <thumb dir>
set -u
src=$1 out=$2
mkdir -p "$out"
find "$src" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 |
    xargs -0 -r -P "$(nproc)" -I{} sh -c '
        t="$0/$(basename "$1").jpg"
        [ "$t" -nt "$1" ] || magick "$1[0]" -auto-orient -thumbnail "480x300^" -gravity center -extent 480x300 -quality 85 "$t" 2>/dev/null
    ' "$out" {}
# drop thumbnails whose wallpaper is gone
for t in "$out"/*.jpg; do
    [ -e "$t" ] || continue
    [ -e "$src/$(basename "$t" .jpg)" ] || rm -f "$t"
done
