#!/usr/bin/env bash
# Builds & enables Hyprland plugins via hyprpm. Run from inside a Hyprland session
# (install.sh does this for you when it runs inside one).
set -euo pipefail
hyprpm update
hyprpm add https://github.com/hyprwm/hyprland-plugins || true
hyprpm enable hyprfocus
hyprpm reload -n
