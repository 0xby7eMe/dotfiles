#!/usr/bin/env bash
# Screenshot → clipboard + ~/Pictures/Screenshots, then a notification with a
# preview. Clicking it (or "Edit") opens the annotation editor (satty: arrows,
# circles, boxes, text, blur…); edits are saved over the file and copied.
#   screenshot.sh region | output | window

mode=${1:-region}
dir="$HOME/Pictures/Screenshots"
name="Screenshot $(date +%F\ %H.%M.%S).png"
file="$dir/$name"
mkdir -p "$dir"

# grim/slurp directly: hyprshot returns as soon as slurp closes and saves in
# the background, so the file wasn't there yet when we checked for it.
case $mode in
    output) grim -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused).name')" "$file" ;;
    window) grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" "$file" ;;
    *)      geom=$(slurp -d) && grim -g "$geom" "$file" ;;
esac

# cancelled (Esc in the region picker) or failed
[ -s "$file" ] || exit 0
wl-copy --type image/png < "$file"

edit() {
    if command -v satty >/dev/null; then
        # copying (Ctrl+C) also saves over the file; either one closes satty
        satty --filename "$file" --output-filename "$file" --copy-command wl-copy \
            --save-after-copy --early-exit
    elif command -v swappy >/dev/null; then
        swappy -f "$file" -o "$file" && wl-copy --type image/png < "$file"
    else
        xdg-open "$file"
    fi
}

action=$(notify-send --app-name=Screenshot --expire-time=8000 \
    --hint="string:image-path:$file" --icon=camera \
    --action=default=Edit --action=edit=Edit --action=open=Open --action=folder="Show in Folder" \
    "Screenshot saved" "Copied to clipboard · $name")

case $action in
    default | edit) edit ;;
    open) xdg-open "$file" ;;
    folder) xdg-open "$dir" ;;
esac
