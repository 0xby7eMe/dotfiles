pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Global shell state, IPC entry points and small helpers.
Singleton {
    id: root

    property bool launcherOpen: false
    property string launcherMode: "apps"   // "apps" | "clip"
    property bool wallpaperOpen: false
    property bool dashOpen: false          // notification center + calendar in the center pill
    property string pillScreen: ""         // monitor whose center pill hosts the launcher / wallpaper picker / dash
    property bool controlOpen: false
    property bool weatherOpen: false
    property bool overviewOpen: false
    property bool cheatsheetOpen: false
    property bool authOpen: false          // polkit prompt (set by PolkitPrompt)
    property string overlayScreen: ""      // monitor hosting the overview / cheat sheet; the others get a blur backdrop
    property bool dnd: false
    property bool caffeine: false
    property bool nightLight: false
    property real brightness: 0.5
    property list<string> pinned: []

    // OSD
    property string osdKind: ""
    property real osdValue: 0
    property bool osdMuted: false
    property int osdSerial: 0

    readonly property string focusedScreen: Hyprland.focusedMonitor?.name ?? ""

    // Set when a panel closes because of an outside click, so the same click
    // landing on a bar button doesn't immediately reopen it.
    property real lastAutoClose: 0

    function autoClose(): void {
        lastAutoClose = Date.now();
        closeAll();
    }

    function toggleLauncher(mode: string): void {
        if (!launcherOpen && Date.now() - lastAutoClose < 250)
            return;
        if (launcherOpen && launcherMode === mode) {
            launcherOpen = false;
            return;
        }
        controlOpen = false;
        weatherOpen = false;
        overviewOpen = false;
        cheatsheetOpen = false;
        if (!launcherOpen && !wallpaperOpen && !dashOpen)
            pillScreen = focusedScreen;
        wallpaperOpen = false;
        dashOpen = false;
        launcherMode = mode;
        launcherOpen = true;
    }

    function toggleWallpaper(): void {
        if (!wallpaperOpen && Date.now() - lastAutoClose < 250)
            return;
        if (wallpaperOpen) {
            wallpaperOpen = false;
            return;
        }
        controlOpen = false;
        weatherOpen = false;
        overviewOpen = false;
        cheatsheetOpen = false;
        if (!launcherOpen && !dashOpen)
            pillScreen = focusedScreen;
        launcherOpen = false;
        dashOpen = false;
        wallpaperOpen = true;
    }

    // Opened from the bar's clock, so it lands on that bar's screen.
    function toggleDash(screen: string): void {
        if (!dashOpen && Date.now() - lastAutoClose < 250)
            return;
        if (dashOpen) {
            dashOpen = false;
            return;
        }
        controlOpen = false;
        weatherOpen = false;
        overviewOpen = false;
        cheatsheetOpen = false;
        if (!launcherOpen && !wallpaperOpen)
            pillScreen = screen || focusedScreen;
        launcherOpen = false;
        wallpaperOpen = false;
        dashOpen = true;
        Notifs.clearPopups();
    }

    function toggleControl(): void {
        if (!controlOpen && Date.now() - lastAutoClose < 250)
            return;
        launcherOpen = false;
        wallpaperOpen = false;
        dashOpen = false;
        weatherOpen = false;
        overviewOpen = false;
        cheatsheetOpen = false;
        controlOpen = !controlOpen;
    }

    function toggleWeather(): void {
        if (!weatherOpen && Date.now() - lastAutoClose < 250)
            return;
        launcherOpen = false;
        wallpaperOpen = false;
        dashOpen = false;
        controlOpen = false;
        overviewOpen = false;
        cheatsheetOpen = false;
        weatherOpen = !weatherOpen;
    }

    // Fullscreen overlays: workspace overview and keybind cheat sheet.
    function toggleOverview(): void {
        const o = !overviewOpen;
        closeAll();
        if (o)
            overlayScreen = focusedScreen;
        overviewOpen = o;
    }

    function toggleCheatsheet(): void {
        const o = !cheatsheetOpen;
        closeAll();
        if (o)
            overlayScreen = focusedScreen;
        cheatsheetOpen = o;
    }

    function closeAll(): void {
        launcherOpen = false;
        wallpaperOpen = false;
        dashOpen = false;
        controlOpen = false;
        weatherOpen = false;
        overviewOpen = false;
        cheatsheetOpen = false;
    }

    // Hyprland 0.56 uses a Lua config; dispatch takes Lua expressions there.
    function dispatch(lua: string, legacy: string): void {
        Hyprland.dispatch(Hyprland.usingLua ? lua : legacy);
    }

    function focusWorkspace(ws: string): void {
        const arg = /^-?\d+$/.test(ws) ? ws : `"${ws}"`;
        dispatch(`hl.dsp.focus({ workspace = ${arg} })`, `workspace ${ws}`);
    }

    function sh(cmd: string): void {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function showOsd(kind: string, value: real, muted: bool): void {
        osdKind = kind;
        osdValue = value;
        osdMuted = muted;
        osdSerial++;
    }

    // ---------- pinned apps (shared with the GNOME dock) ----------
    function normId(id: string): string {
        return id.replace(/\.desktop$/, "");
    }

    function parseFavorites(text: string): void {
        const m = text.match(/\[.*\]/);
        if (!m) {
            pinned = [];
            return;
        }
        try {
            pinned = JSON.parse(m[0].replace(/'/g, '"')).map(normId);
        } catch (e) {
            console.warn("favorites parse failed:", e);
        }
    }

    function setPinned(list: var): void {
        const v = "[" + list.map(id => `'${id}.desktop'`).join(", ") + "]";
        Quickshell.execDetached(["gsettings", "set", "org.gnome.shell", "favorite-apps", v]);
        pinned = list;
    }

    function togglePin(id: string): void {
        const l = [...pinned];
        const i = l.indexOf(id);
        if (i >= 0)
            l.splice(i, 1);
        else
            l.push(id);
        setPinned(l);
    }

    Process {
        running: true
        command: ["gsettings", "get", "org.gnome.shell", "favorite-apps"]
        stdout: StdioCollector {
            onStreamFinished: root.parseFavorites(text)
        }
    }

    Process {
        running: true
        command: ["gsettings", "monitor", "org.gnome.shell", "favorite-apps"]
        stdout: SplitParser {
            onRead: line => root.parseFavorites(line)
        }
    }

    // ---------- brightness ----------
    function setBrightness(v: real): void {
        v = Math.max(0.01, Math.min(1, v));
        brightness = v;
        Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(v * 100) + "%"]);
    }

    function stepBrightness(delta: real): void {
        setBrightness(brightness + delta);
        showOsd("brightness", brightness, false);
    }

    Process {
        id: brightnessRead
        running: true
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length >= 4)
                    root.brightness = parseInt(f[3]) / 100;
            }
        }
    }

    // ---------- night light ----------
    onNightLightChanged: {
        if (nightLight)
            Quickshell.execDetached(["hyprsunset", "-t", "4500"]);
        else
            Quickshell.execDetached(["pkill", "-x", "hyprsunset"]);
    }

    IpcHandler {
        target: "shell"

        function launcher(): void {
            root.toggleLauncher("apps");
        }
        function clipboard(): void {
            root.toggleLauncher("clip");
        }
        function control(): void {
            root.toggleControl();
        }
        function weather(): void {
            root.toggleWeather();
        }
        function dash(): void {
            root.toggleDash("");
        }
        function wallpaper(): void {
            root.toggleWallpaper();
        }
        function overview(): void {
            root.toggleOverview();
        }
        function cheatsheet(): void {
            root.toggleCheatsheet();
        }
        function randomWallpaper(): void {
            Wallpapers.random();
        }
        function close(): void {
            root.closeAll();
        }
        function brightnessUp(): void {
            root.stepBrightness(0.05);
        }
        function brightnessDown(): void {
            root.stepBrightness(-0.05);
        }
    }
}
