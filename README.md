# dotfiles

Monochrome, macOS-ish Hyprland rice for Arch Linux: frosted-glass Quickshell
shell (bar, dock, launcher, control center, notification center + calendar,
iOS-style weather, OSD, lock screen, app switcher, overview), Hyprland in Lua,
kitty, starship and a neofetch with the cat from [0xby7eMe](../0xby7eMe/components/tools/AsciiCat.tsx).

```sh
git clone <this repo> ~/dev/dotfiles
cd ~/dev/dotfiles
./install.sh            # or --dry-run first to see every step
```

The installer greets you with the cat, then:

| step | what it does |
| --- | --- |
| packages | `pacman -Syu` with `packages/core.txt`, bootstraps `yay`, AUR from `packages/aur.txt` |
| apps | optional apps from `packages/apps.txt` (pacman, AUR, Flathub), asks first |
| graphics | Mesa for AMD/Intel; if there's an NVIDIA GPU, see below |
| themes + fonts | Colloid-Dark GTK + mono, Colloid-Grey-Dark icons, Bibata cursor, Manrope + Lucide |
| configs | symlinks `~/.config/*`, `~/.bashrc`, `~/.bash_profile` into `config/` and `home/` |
| desktop | default wallpaper, gsettings, spicetify Mono theme (if Spotify is installed) |
| services | NetworkManager, bluetooth, power-profiles-daemon |
| plugins | hyprpm `hyprfocus` (only from inside Hyprland, else run `scripts/hyprpm-plugins.sh` later) |

Anything it replaces is moved to `~/.local/state/dotfiles/backup-<time>/`.
It's safe to re-run; already-linked files and unchanged system files are skipped.

```
-y, --yes          defaults for every prompt, non-interactive pacman/yay
-n, --dry-run      print what would happen, change nothing
    --links-only   only (re)create the symlinks
    --no-packages / --no-gpu / --no-themes / --apps / --no-apps / --no-anim
```

## Shell

Most of the shell is monochrome glass; colour comes from content.

- **Notification center** (click the clock, or `Super+N`): the center pill grows into
  a month calendar, a weather widget and the notification history. Popups time out
  into the history instead of disappearing; Do Not Disturb sends them straight there.
  The history survives Quickshell reloads.
- **Weather** (bar chip next to the status icons): an iOS Weather-style sheet whose
  sky follows the conditions and time of day, with frosted cards that blur it
  (`components/FrostCard.qml`). Also on the lock screen and as a control center
  module (add it with *Edit Controls*). Data from [Open-Meteo](https://open-meteo.com)
  (no API key), location from your IP via ipinfo.io until you click the city name
  and type one. Location and units are kept in `~/.local/state/quickshell`.
- **Now playing** tints its progress bar and play button with the album cover's
  colour (Spotify covers are cached in `~/.cache/quickshell`).

```sh
qs ipc call shell dash                 # notification center + calendar
qs ipc call shell weather              # weather sheet
qs ipc call weather city "Berlin"      # pin a city ("" = back to IP location)
qs ipc call weather units imperial     # or metric
qs ipc call weather refresh
```

## NVIDIA

Detected with `lspci`. When an NVIDIA GPU is present the installer:

- picks the driver: `nvidia-open` on the stock kernel, `nvidia-open-dkms` + headers
  when other kernels (lts, zen, …) are installed, the AUR `nvidia-580xx` branch for
  pre-Turing cards (GTX 10xx and older), plus `nvidia-utils`, `lib32-nvidia-utils`
  (with multilib), `egl-wayland`, `libva-nvidia-driver`, `nvidia-settings`
- writes `/etc/modprobe.d/nvidia.conf`: DRM modesetting + fbdev, VRAM preserved across
  suspend, and runtime power management on hybrid laptops
- enables `nvidia-suspend/resume/hibernate`, rebuilds the initramfs
- **NVIDIA only:** loads the modules early (`/etc/mkinitcpio.conf.d/nvidia.conf`), adds a
  pacman hook to rebuild the initramfs on driver updates; Hyprland sets
  `LIBVA_DRIVER_NAME`, `GBM_BACKEND`, `__GLX_VENDOR_LIBRARY_NAME`, `NVD_BACKEND`
- **hybrid (AMD/Intel iGPU + NVIDIA):** adds `nvidia-prime` (`prime-run <app>`) and
  `switcheroo-control`, and writes `/etc/udev/rules.d/61-hypr-gpu.rules` with stable
  `/dev/dri/{amd,intel}-igpu` and `/dev/dri/nvidia-dgpu` symlinks. Hyprland renders
  on the iGPU and keeps the dGPU for its ports (`AQ_DRM_DEVICES`).

## Layout

```
config/        → ~/.config/*  (hypr, quickshell, kitty, starship.toml, neofetch, micro,
                  bat, htop, zathura, zed, gtk-3.0/4.0 files, spicetify theme)
home/          → ~/.bashrc, ~/.bash_profile
themes/        copied to ~/.themes
fonts/         copied to ~/.local/share/fonts
wallpapers/    default wallpaper; your collection lives in ~/.config/wallpapers (not tracked)
packages/      package lists
scripts/       hyprpm-plugins.sh
lib/           installer helpers + the cat
```

Machine-specific bits to check on a new machine: `config/hypr/modules/monitors.lua`
(eDP-1 at 1920x1200@165, 125 %) and the `de` keyboard layout in `input.lua`.
