#!/usr/bin/env bash
# Installs the monochrome Hyprland + Quickshell rice on Arch Linux:
# packages, NVIDIA drivers (when there's an NVIDIA GPU), themes, fonts, and
# symlinks from ~/.config into this repo. Safe to re-run; anything it replaces
# is moved to ~/.local/state/dotfiles/backup-<time>.
set -euo pipefail

DOTFILES=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$DOTFILES/lib/ui.sh"
source "$DOTFILES/lib/cat.sh"

ASSUME_YES=0 DRY_RUN=0 NO_ANIM=0
DO_PACKAGES=1 DO_GPU=1 DO_THEMES=1 APPS=ask

usage() {
    cat <<EOF
usage: ./install.sh [options]

  -y, --yes          answer every prompt with its default (non-interactive pacman/yay)
  -n, --dry-run      show what would happen, change nothing
      --links-only   only (re)create the config symlinks
      --no-packages  skip pacman/AUR packages
      --no-gpu       skip GPU driver setup
      --no-themes    skip GTK/icon/cursor themes and fonts
      --apps         install the optional apps without asking
      --no-apps      skip the optional apps
      --no-anim      no cat animation (the cat stays)
  -h, --help         this help
EOF
}

while (($#)); do
    case $1 in
        -y | --yes) ASSUME_YES=1 ;;
        -n | --dry-run) DRY_RUN=1 ;;
        --links-only) DO_PACKAGES=0 DO_GPU=0 DO_THEMES=0 APPS=no ;;
        --no-packages) DO_PACKAGES=0 ;;
        --no-gpu) DO_GPU=0 ;;
        --no-themes) DO_THEMES=0 ;;
        --apps) APPS=yes ;;
        --no-apps) APPS=no ;;
        --no-anim) NO_ANIM=1 ;;
        -h | --help) usage; exit 0 ;;
        *) usage >&2; die "unknown option: $1" ;;
    esac
    shift
done

NOCONFIRM=()
((ASSUME_YES)) && NOCONFIRM=(--noconfirm)
BACKUP="$HOME/.local/state/dotfiles/backup-$(date +%Y%m%d-%H%M%S)"
NOTES=()  # things to tell the user at the end
REBOOT=0

trap 'printf "\e[?25h"; warn "failed at line $LINENO: $BASH_COMMAND"' ERR

# ── preflight ─────────────────────────────────────────────────────────────────

preflight() {
    step "preflight"
    [[ -f /etc/arch-release ]] || die "this rice targets Arch Linux"
    ((EUID != 0)) || die "run as your user, not root (sudo is used where needed)"
    ok "Arch Linux, user $USER"
    ((DRY_RUN)) && info "dry run: nothing will be changed"

    if ((DO_PACKAGES || DO_GPU)) && ((!DRY_RUN)); then
        info "sudo is needed for packages and system config"
        sudo -v || die "sudo failed"
        # keep the sudo timestamp fresh while we run
        while kill -0 $$ 2>/dev/null; do sudo -n true; sleep 50; done 2>/dev/null &
    fi
}

aur_helper() {
    command -v yay >/dev/null && return
    info "installing yay (AUR helper)"
    if ((DRY_RUN)); then
        run makepkg -si  # yay-bin from the AUR
        return
    fi
    run sudo pacman -S --needed "${NOCONFIRM[@]}" git base-devel
    local tmp
    tmp=$(mktemp -d)
    run git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && run makepkg -si "${NOCONFIRM[@]}")
    rm -rf "$tmp"
}

yay_install() {
    local flags=(--needed)
    ((ASSUME_YES)) && flags+=(--noconfirm --answerdiff None --answerclean None)
    run yay -S "${flags[@]}" "$@"
}

# ── packages ──────────────────────────────────────────────────────────────────

packages() {
    step "packages"
    local core aur
    mapfile -t core < <(read_list "$DOTFILES/packages/core.txt")
    mapfile -t aur < <(read_list "$DOTFILES/packages/aur.txt")

    info "${#core[@]} official packages (full system upgrade first, as Arch expects)"
    run sudo pacman -Syu --needed "${NOCONFIRM[@]}" "${core[@]}"
    aur_helper
    info "${#aur[@]} AUR packages: ${aur[*]}"
    yay_install "${aur[@]}"
    ok "packages installed"
}

apps() {
    [[ $APPS == no ]] && return
    step "apps"
    local entry repo=() aur=() flat=()
    while read -r entry; do
        case $entry in
            flatpak:*) flat+=("${entry#flatpak:}") ;;
            aur:*) aur+=("${entry#aur:}") ;;
            *) repo+=("$entry") ;;
        esac
    done < <(read_list "$DOTFILES/packages/apps.txt")

    info "${repo[*]} ${aur[*]} ${flat[*]}"
    if [[ $APPS == ask ]] && ! ask "install these optional apps?" y; then
        skip "apps"
        return
    fi
    ((${#repo[@]})) && run sudo pacman -S --needed "${NOCONFIRM[@]}" "${repo[@]}"
    ((${#aur[@]})) && yay_install "${aur[@]}"
    if ((${#flat[@]})); then
        run sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        run flatpak install -y --noninteractive flathub "${flat[@]}"
    fi
    ok "apps installed"
}

# ── GPU ───────────────────────────────────────────────────────────────────────

# Display controllers as "<pci address> <vendor id> <description>".
gpus() {
    lspci -Dnn | grep -E '\[03(00|02|80)\]' |
        sed -E 's/^(\S+) .*\[03..\]: (.*) \[([0-9a-f]{4}):[0-9a-f]{4}\].*/\1 \3 \2/'
}

# NVIDIA's open kernel modules need Turing (GTX 16xx / RTX 20xx) or newer; older
# cards need the 580xx legacy branch from the AUR. lspci names the chip first:
# TU116, GA104, AD107, GB207M... vs GP107, GM204, GK104.
nvidia_legacy() {
    local chip
    chip=$(sed -E 's/.*NVIDIA Corporation ([A-Z]+)[0-9].*/\1/' <<< "$1")
    [[ $chip =~ ^(GP|GM|GK|GF|NV)$ ]]
}

gpu() {
    step "graphics"
    local list nvidia others
    list=$(gpus)
    nvidia=$(grep -E '^\S+ 10de ' <<< "$list" || true)
    others=$(grep -vE '^\S+ 10de ' <<< "$list" || true)
    while read -r line; do [[ -n $line ]] && info "${line#* * }"; done <<< "$list"

    # Mesa userspace for AMD / Intel
    local mesa=(mesa)
    grep -qE '^\S+ 1002 ' <<< "$others" && mesa+=(vulkan-radeon)
    grep -qE '^\S+ 8086 ' <<< "$others" && mesa+=(vulkan-intel intel-media-driver)
    if [[ -n $others ]]; then
        run sudo pacman -S --needed "${NOCONFIRM[@]}" "${mesa[@]}"
    fi

    if [[ -z $nvidia ]]; then
        skip "no NVIDIA GPU, nothing else to set up"
        return
    fi

    local hybrid=0 legacy=0
    [[ -n $others ]] && hybrid=1
    nvidia_legacy "$nvidia" && legacy=1
    ok "NVIDIA GPU found ($( ((hybrid)) && echo "hybrid with an iGPU" || echo "only GPU"))"

    nvidia_driver "$legacy" "$hybrid"
    nvidia_config "$hybrid"
    if ((hybrid)); then gpu_symlinks "$nvidia" "$others"; fi
}

nvidia_driver() {
    local legacy=$1 hybrid=$2 kernels=() k multilib=0 pkgs=() aur=() swap=0
    for k in linux linux-lts linux-zen linux-hardened linux-rt linux-rt-lts; do
        pacman -Qq "$k" &>/dev/null && kernels+=("$k")
    done
    ((${#kernels[@]})) || kernels=(linux)
    grep -q '^\[multilib\]' /etc/pacman.conf && multilib=1

    if ((legacy)); then
        info "pre-Turing card: legacy 580xx driver from the AUR (dkms)"
        aur+=(nvidia-580xx-dkms nvidia-580xx-utils)
        ((multilib)) && aur+=(lib32-nvidia-580xx-utils)
        for k in "${kernels[@]}"; do pkgs+=("$k-headers"); done
    elif [[ ${kernels[*]} == linux ]] && ! pacman -Qq nvidia-open-dkms &>/dev/null; then
        info "stock kernel: nvidia-open"
        pkgs+=(nvidia-open nvidia-utils)
    else
        # dkms builds the module for every installed kernel (${kernels[*]})
        info "kernels ${kernels[*]}: nvidia-open-dkms"
        pkgs+=(nvidia-open-dkms nvidia-utils)
        for k in "${kernels[@]}"; do pkgs+=("$k-headers"); done
        if pacman -Qq nvidia-open &>/dev/null; then
            # pacman asks before replacing the conflicting package, so this can't run with --noconfirm
            if ((ASSUME_YES)) || ! ask "replace nvidia-open (stock kernel only) with nvidia-open-dkms?" y; then
                NOTES+=("nvidia-open only covers the stock kernel; re-run without --yes to switch to nvidia-open-dkms")
                pkgs=(nvidia-utils)
            else
                swap=1
            fi
        fi
    fi
    if ((!legacy)); then
        ((multilib)) && pkgs+=(lib32-nvidia-utils)
    fi
    ((multilib)) || NOTES+=("enable [multilib] in /etc/pacman.conf for 32-bit NVIDIA libs (Steam, Wine), then re-run")

    pkgs+=(nvidia-settings egl-wayland libva-nvidia-driver)
    ((hybrid)) && pkgs+=(nvidia-prime switcheroo-control)

    if ((swap)); then
        run sudo pacman -S --needed "${pkgs[@]}"
    else
        run sudo pacman -S --needed "${NOCONFIRM[@]}" "${pkgs[@]}"
    fi
    if ((${#aur[@]})); then yay_install "${aur[@]}"; fi
    ok "driver packages installed"
}

nvidia_config() {
    local hybrid=$1 initramfs=0

    # DRM modesetting + framebuffer (needed for Wayland), keep VRAM across suspend.
    # Hybrid laptops also get fine-grained power management so the dGPU sleeps.
    {
        echo "# Written by dotfiles/install.sh"
        echo "options nvidia_drm modeset=1 fbdev=1"
        echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp"
        if ((hybrid)); then echo "options nvidia NVreg_DynamicPowerManagement=0x02"; fi
    } | root_write /etc/modprobe.d/nvidia.conf && { ok "/etc/modprobe.d/nvidia.conf"; initramfs=1; } || skip "modprobe options up to date"

    if ((!hybrid)); then
        # Only GPU: load the driver early so the console and the login screen come up on it.
        cat <<'EOF' | root_write /etc/mkinitcpio.conf.d/nvidia.conf && { ok "early KMS (mkinitcpio.conf.d/nvidia.conf)"; initramfs=1; } || skip "early KMS up to date"
# Written by dotfiles/install.sh: load NVIDIA early (KMS)
MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF
        # The modules live in the initramfs now, so rebuild it when the driver updates.
        cat <<'EOF' | root_write /etc/pacman.d/hooks/nvidia.hook && ok "pacman hook: rebuild initramfs on driver updates" || true
# Written by dotfiles/install.sh
[Trigger]
Operation = Install
Operation = Upgrade
Operation = Remove
Type = Package
Target = nvidia-open
Target = nvidia-open-dkms
Target = nvidia-580xx-dkms
Target = linux*

[Action]
Description = Rebuilding initramfs for NVIDIA...
Depends = mkinitcpio
When = PostTransaction
NeedsTargets
Exec = /bin/sh -c 'while read -r trg; do case $trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF
    fi

    if ((initramfs)); then
        info "rebuilding initramfs"
        run sudo mkinitcpio -P
        REBOOT=1
    fi

    # Suspend/resume helpers that go with PreserveVideoMemoryAllocations.
    run sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service
    ((hybrid)) && run sudo systemctl enable switcheroo-control.service
    ok "suspend/resume services enabled"
    if ((hybrid)); then NOTES+=("run an app on the NVIDIA GPU with: prime-run <app>"); fi
}

# Stable /dev/dri/{amd,intel}-igpu and nvidia-dgpu symlinks for Hyprland's
# AQ_DRM_DEVICES (see config/hypr/modules/environment.lua): cardN numbering
# can swap between boots.
gpu_symlinks() {
    local nvidia=$1 others=$2 addr vendor name rules
    rules="# Written by dotfiles/install.sh: stable GPU paths for Hyprland"$'\n'
    while read -r addr vendor _; do
        case $vendor in
            1002) name=amd-igpu ;;
            8086) name=intel-igpu ;;
            *) continue ;;
        esac
        rules+="KERNEL==\"card*\", KERNELS==\"$addr\", SUBSYSTEM==\"drm\", SUBSYSTEMS==\"pci\", SYMLINK+=\"dri/$name\""$'\n'
        break  # the first iGPU renders
    done <<< "$others"
    read -r addr _ <<< "$nvidia"
    rules+="KERNEL==\"card*\", KERNELS==\"$addr\", SUBSYSTEM==\"drm\", SUBSYSTEMS==\"pci\", SYMLINK+=\"dri/nvidia-dgpu\""

    if printf '%s\n' "$rules" | root_write /etc/udev/rules.d/61-hypr-gpu.rules; then
        run sudo udevadm control --reload
        run sudo udevadm trigger --subsystem-match=drm
        ok "udev GPU symlinks (Hyprland renders on the iGPU, NVIDIA drives its own ports)"
    else
        skip "udev GPU symlinks up to date"
    fi
}

# ── themes + fonts ────────────────────────────────────────────────────────────

themes() {
    step "themes + fonts"
    run mkdir -p "$HOME/.themes" "$HOME/.local/share/fonts" "$HOME/.icons/default"

    run rsync -a "$DOTFILES/themes/" "$HOME/.themes/"
    ok "GTK: Colloid-Dark, mono"

    if [[ -d $HOME/.icons/Colloid-Grey-Dark || -d $HOME/.local/share/icons/Colloid-Grey-Dark ]]; then
        skip "icons: Colloid-Grey-Dark already installed"
    else
        local tmp
        tmp=$(mktemp -d)
        run git clone --depth 1 https://github.com/vinceliuice/Colloid-icon-theme.git "$tmp/colloid"
        run "$tmp/colloid/install.sh" -t grey
        rm -rf "$tmp"
        ok "icons: Colloid-Grey-Dark"
    fi

    # default cursor for apps that don't read gsettings
    local cursor=$'[Icon Theme]\nInherits=Bibata-Modern-Classic'
    if [[ $(cat "$HOME/.icons/default/index.theme" 2>/dev/null) != "$cursor" ]]; then
        ((DRY_RUN)) || printf '%s\n' "$cursor" > "$HOME/.icons/default/index.theme"
    fi
    ok "cursor: Bibata-Modern-Classic"

    run rsync -a "$DOTFILES/fonts/" "$HOME/.local/share/fonts/"
    run fc-cache -f
    ok "fonts: Manrope, Lucide (+ Inter, JetBrains Mono Nerd, Material Symbols from packages)"
}

# ── links ─────────────────────────────────────────────────────────────────────

# link <repo path> <target>: symlink target -> repo path, backing up whatever was there.
link() {
    local src=$DOTFILES/$1 dst=$2
    if [[ -L $dst && $(readlink "$dst") == "$src" ]]; then
        skip "${dst/#$HOME/\~}"
        return
    fi
    if [[ -e $dst || -L $dst ]]; then
        local rel=${dst#"$HOME"/}
        run mkdir -p "$(dirname "$BACKUP/$rel")"
        run mv "$dst" "$BACKUP/$rel"
    fi
    run mkdir -p "$(dirname "$dst")"
    run ln -s "$src" "$dst"
    ok "${dst/#$HOME/\~} → ${1}"
}

links() {
    step "configs"
    local name
    for name in hypr quickshell kitty neofetch micro bat htop zathura zed starship.toml; do
        link "config/$name" "$HOME/.config/$name"
    done
    # GTK dirs also hold app state (bookmarks), so link the files only
    for name in gtk-3.0/settings.ini gtk-3.0/gtk.css gtk-4.0/settings.ini gtk-4.0/gtk.css spicetify/Themes/Mono; do
        link "config/$name" "$HOME/.config/$name"
    done
    link home/.bashrc "$HOME/.bashrc"
    link home/.bash_profile "$HOME/.bash_profile"
    [[ -d $BACKUP ]] && NOTES+=("replaced files are in ${BACKUP/#$HOME/\~}")
    return 0
}

# ── desktop ───────────────────────────────────────────────────────────────────

desktop() {
    step "desktop"
    # Wallpaper: Quickshell picks from ~/.config/wallpapers and copies the pick to
    # ~/.config/background (hyprlock reads that one).
    run mkdir -p "$HOME/.config/wallpapers" "$HOME/Pictures/Screenshots"
    if [[ -z $(ls -A "$HOME/.config/wallpapers" 2>/dev/null) ]]; then
        run cp "$DOTFILES/wallpapers/default.jpg" "$HOME/.config/wallpapers/default.jpg"
    fi
    [[ -e $HOME/.config/background ]] || run cp "$DOTFILES/wallpapers/default.jpg" "$HOME/.config/background"
    ok "wallpaper (drop more into ~/.config/wallpapers, Super+Shift+W to pick)"

    command -v xdg-user-dirs-update >/dev/null && run xdg-user-dirs-update

    if command -v gsettings >/dev/null && gsettings list-schemas 2>/dev/null | grep -qx org.gnome.desktop.interface; then
        local key val
        while read -r key val; do
            run gsettings set org.gnome.desktop.interface "$key" "$val"
        done <<'EOF'
gtk-theme Colloid-Dark
icon-theme Colloid-Grey-Dark
cursor-theme Bibata-Modern-Classic
cursor-size 24
color-scheme prefer-dark
font-name Manrope 8.398
EOF
        ok "GTK settings (gsettings)"
    else
        skip "gsettings unavailable, GTK uses settings.ini"
    fi

    if command -v spicetify >/dev/null && [[ -d /opt/spotify ]]; then
        if ask "theme Spotify with spicetify (Mono)?" y; then
            run sudo chmod a+wr /opt/spotify
            run sudo chmod -R a+wr /opt/spotify/Apps
            run spicetify config current_theme Mono color_scheme Mono inject_css 1 replace_colors 1
            run spicetify backup apply || warn "spicetify failed; open Spotify once, then run: spicetify backup apply"
        fi
    fi
}

services() {
    step "services"
    local unit
    # NetworkManager is only enabled, not started: if something else manages the
    # network right now, starting it here could cut the connection mid-install.
    pacman -Qq networkmanager &>/dev/null && run sudo systemctl enable NetworkManager.service
    for unit in bluetooth.service power-profiles-daemon.service; do
        systemctl list-unit-files "$unit" &>/dev/null && run sudo systemctl enable --now "$unit"
    done
    ok "NetworkManager, bluetooth, power-profiles-daemon"

    if ! systemctl is-enabled display-manager.service &>/dev/null; then
        NOTES+=("no display manager: log in on a TTY and run Hyprland (or install one, e.g. gdm or sddm)")
    fi
}

plugins() {
    step "hyprland plugins"
    if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        run "$DOTFILES/scripts/hyprpm-plugins.sh" || warn "hyprpm failed; retry with scripts/hyprpm-plugins.sh"
        ok "hyprfocus"
    else
        skip "not inside Hyprland"
        NOTES+=("inside Hyprland, run once: $DOTFILES/scripts/hyprpm-plugins.sh")
    fi
}

# ── main ──────────────────────────────────────────────────────────────────────

cat_intro "./install.sh"

preflight
((DO_PACKAGES)) && packages
((DO_PACKAGES)) && apps
((DO_GPU)) && gpu
((DO_THEMES)) && themes
links
((DO_PACKAGES || DO_THEMES)) && desktop
((DO_PACKAGES)) && services
((DO_PACKAGES)) && plugins

step "done"
for note in "${NOTES[@]}"; do info "$note"; done
((REBOOT)) && info "reboot to load the new GPU driver config" || info "log out and pick Hyprland at the login screen"
printf '\n  %s=^.^=%s  %shappy ricing%s\n\n' "$_W$_B" "$_R" "$_D" "$_R"
