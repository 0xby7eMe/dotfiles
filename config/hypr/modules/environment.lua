-- Environment variables

local function exists(path)
    local ok, f = pcall(io.open, path, "r")
    if ok and f then
        f:close()
        return true
    end
    return false
end

hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("XDG_SESSION_TYPE", "wayland")

-- GPUs. The symlinks come from /etc/udev/rules.d/61-hypr-gpu.rules, written by
-- install.sh (card0/card1 numbering is not stable between boots).
local igpu = (exists("/dev/dri/amd-igpu") and "/dev/dri/amd-igpu")
    or (exists("/dev/dri/intel-igpu") and "/dev/dri/intel-igpu")
local dgpu = exists("/dev/dri/nvidia-dgpu") and "/dev/dri/nvidia-dgpu"

if igpu and dgpu then
    -- Hybrid: render on the iGPU (eDP + USB-C/DP outputs), keep the NVIDIA dGPU
    -- available for the ports wired to it (HDMI on most laptops).
    hl.env("AQ_DRM_DEVICES", igpu .. ":" .. dgpu)
elseif exists("/proc/driver/nvidia/version") then
    -- NVIDIA is the only GPU: point the whole stack at it.
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("GBM_BACKEND", "nvidia-drm")
    hl.env("NVD_BACKEND", "direct")
end
