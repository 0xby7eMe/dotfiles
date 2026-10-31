#!/usr/bin/env bash
# Status for the hyprlock top-right pill: same Lucide icons as the Quickshell bar.

icon() { printf '<span font_family="lucide" size="larger" rise="-1pt">%s</span>' "$1"; }

if nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q '^ethernet:connected$'; then
    net=$''                                   # ethernet-port
elif [ "$(nmcli -t -f WIFI g 2>/dev/null)" != "enabled" ]; then
    net=$''                                   # wifi-off
else
    signal=$(nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')
    if [ -z "$signal" ]; then net=$''         # wifi-zero
    elif [ "$signal" -gt 66 ]; then net=$''   # wifi
    elif [ "$signal" -gt 33 ]; then net=$''   # wifi-high
    else net=$''; fi                          # wifi-low
fi
out="$(icon "$net")"

bat=/sys/class/power_supply/BAT0
if [ -r "$bat/capacity" ]; then
    cap=$(<"$bat/capacity")
    if [ "$(<"$bat/status")" != "Discharging" ]; then b=$''   # battery-charging
    elif [ "$cap" -gt 80 ]; then b=$''                         # battery-full
    elif [ "$cap" -gt 45 ]; then b=$''                         # battery-medium
    elif [ "$cap" -gt 15 ]; then b=$''                         # battery-low
    else b=$''; fi                                             # battery-warning
    out+="   $(icon "$b") $cap%"
fi

echo "$out"
