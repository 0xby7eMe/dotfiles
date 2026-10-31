pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

// Wallpapers from ~/.config/wallpapers. The pick is remembered and copied to
// ~/.config/background, which hyprlock (and GNOME) also read.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dir: home + "/.config/wallpapers"
    readonly property string thumbDir: Quickshell.cachePath("wallpaper-thumbs")
    readonly property string fallback: home + "/.config/background"

    readonly property string current: saved.current
    readonly property string source: "file://" + (current !== "" ? current : fallback)
    property bool thumbsReady: false

    readonly property alias model: folder
    readonly property int currentIndex: {
        folder.count; // re-evaluate when the folder loads
        return current !== "" ? folder.indexOf("file://" + current) : -1;
    }

    function thumb(fileName: string): string {
        return "file://" + thumbDir + "/" + fileName + ".jpg";
    }

    function set(path: string): void {
        if (!path || path === current)
            return;
        saved.current = path;
        savedFile.writeAdapter();
        Quickshell.execDetached(["cp", "-f", path, fallback]);
    }

    function random(): void {
        if (folder.count < 2)
            return;
        let i;
        do
            i = Math.floor(Math.random() * folder.count);
        while (i === currentIndex);
        set(folder.get(i, "filePath"));
    }

    function refreshThumbs(): void {
        if (!thumbProc.running)
            thumbProc.running = true;
    }

    FolderListModel {
        id: folder
        folder: "file://" + root.dir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        caseSensitive: false
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: root.refreshThumbs()
    }

    FileView {
        id: savedFile
        path: Quickshell.statePath("wallpaper.json")
        blockLoading: true
        printErrors: false
        JsonAdapter {
            id: saved
            property string current: ""
        }
    }

    Process {
        id: thumbProc
        command: [Quickshell.shellPath("scripts/wallpaper-thumbs.sh"), root.dir, root.thumbDir]
        onExited: root.thumbsReady = true
    }

    Component.onCompleted: refreshThumbs()
}
