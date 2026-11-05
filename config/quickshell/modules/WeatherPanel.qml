pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.services
import qs.components

// iOS-style weather sheet: a coloured sky picked from the conditions and the
// time of day (blue days, navy nights, slate rain, warm sunsets) with soft
// sun glow and clouds, a centred hero, then frosted cards that blur the sky
// behind them: hourly strip, 10-day forecast and detail tiles.
DropPanel {
    id: root

    open: ShellState.weatherOpen
    align: "right"
    ns: "qs-weather"
    panelWidth: 336
    // Light base: the sky carries the colour, and the total alpha stays above
    // the qs-blur rule's ignore_alpha (0.6) so the wallpaper still blurs through.
    fill: Qt.rgba(0, 0, 0, 0.2)
    maxHeight: Math.min(1000, (target?.height ?? 1080) - Theme.barZone - 2 * Theme.barGap)
    contentHeight: Math.min(page.height, maxHeight)
    onDismissed: ShellState.autoClose()

    property bool editing: false
    onOpenChanged: {
        if (editing)
            cityInput.submit();   // closing the panel keeps what was typed
        editing = false;
        flick.contentY = 0;
        if (open && Date.now() - Weather.fetched > 10 * 60 * 1000)
            Weather.refresh();
    }

    readonly property var cur: Weather.current
    readonly property var today: Weather.daily[0] ?? null
    readonly property int gap: 8
    readonly property real half: (col.width - gap) / 2
    readonly property color dim: Qt.rgba(1, 1, 1, 0.7)
    readonly property color faint: Qt.rgba(1, 1, 1, 0.5)

    // ---------- sky palette (see Weather) ----------
    readonly property string fam: Weather.skyFamily
    readonly property bool day: Weather.isDay
    readonly property bool golden: Weather.golden
    readonly property var palette: Weather.palette

    // Clips the sky to the sheet's rounded corners, also while it opens
    // (DropPanel slides the body up by (1 - p) * 28 px meanwhile).
    ClippingRectangle {
        width: root.panelWidth
        height: Math.min(root.contentHeight, root.contentHeight * root.p + (1 - root.p) * 28)
        radius: 24
        color: "transparent"

        Flickable {
            id: flick
            width: parent.width
            height: root.contentHeight
            contentHeight: page.height
            interactive: page.height > height
            boundsBehavior: Flickable.StopAtBounds

            Item {
                id: page
                width: root.panelWidth
                height: col.implicitHeight + 2 * col.y

                // ---------------- sky ----------------
                Item {
                    id: sky
                    anchors.fill: parent

                    Rectangle {
                        anchors.fill: parent
                        opacity: 0.62   // lets the compositor blur show through, like the media card
                        gradient: Gradient {
                            GradientStop { position: 0; color: root.palette[0] }
                            GradientStop { position: 0.75; color: root.palette[1] }
                        }
                    }

                    // sun / moon glow and clouds, blurred into soft shapes
                    Item {
                        id: glow
                        anchors.fill: parent

                        readonly property bool lit: root.fam === "clear" || root.fam === "partly"
                        readonly property real cloudAlpha: root.fam === "partly" ? 0.16 : root.fam === "storm" ? 0.1
                            : root.fam === "snow" ? 0.24 : root.fam === "rain" ? 0.13 : 0.19
                        // {x, y} centre as fractions of the page, s scale
                        readonly property var clouds: root.fam === "clear" ? []
                            : root.fam === "partly" ? [{ x: 0.18, y: 0.06, s: 1 }, { x: 0.8, y: 0.36, s: 1.2 }]
                            : [{ x: 0.16, y: 0.05, s: 1.1 }, { x: 0.84, y: 0.17, s: 1.3 }, { x: 0.2, y: 0.47, s: 1.2 },
                                { x: 0.8, y: 0.76, s: 1.3 }]
                        // [dx, dy, size] of the circles making up one cloud
                        readonly property var puffs: [[-0.45, 0.08, 0.55], [0, -0.1, 0.78], [0.48, 0.04, 0.6], [0.12, 0.16, 0.62]]

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            autoPaddingEnabled: false
                            blurEnabled: true
                            blur: 1
                            blurMax: 56
                        }

                        // halo + disc
                        Repeater {
                            model: glow.lit ? (root.day ? [[260, 0.35], [96, 0.95]] : [[190, 0.14], [56, 0.7]]) : []
                            Rectangle {
                                required property var modelData
                                width: modelData[0]
                                height: width
                                radius: width / 2
                                x: sky.width * 0.82 - width / 2
                                y: (root.golden ? 104 : 40) - height / 2
                                color: root.palette[2]
                                opacity: modelData[1]
                            }
                        }

                        Repeater {
                            model: glow.clouds
                            Item {
                                id: cloud
                                required property var modelData
                                x: modelData.x * sky.width
                                y: modelData.y * sky.height
                                Repeater {
                                    model: glow.puffs
                                    Rectangle {
                                        required property var modelData
                                        width: 130 * cloud.modelData.s * modelData[2]
                                        height: width
                                        radius: width / 2
                                        x: modelData[0] * 130 * cloud.modelData.s - width / 2
                                        y: modelData[1] * 130 * cloud.modelData.s - height / 2
                                        color: Qt.rgba(1, 1, 1, glow.cloudAlpha)
                                    }
                                }
                            }
                        }
                    }

                    // stars on clear nights, crisp until a card frosts them
                    Repeater {
                        model: !root.day && glow.lit ? 50 : 0
                        Rectangle {
                            required property int index
                            // deterministic scatter
                            readonly property real r1: Math.abs(Math.sin(index * 12.9898) * 43758.5453) % 1
                            readonly property real r2: Math.abs(Math.sin(index * 78.233) * 12543.123) % 1
                            width: r1 > 0.85 ? 2 : 1.4
                            height: width
                            radius: width / 2
                            x: r1 * sky.width
                            y: r2 * sky.height * 0.8
                            color: Qt.rgba(1, 1, 1, 0.3 + 0.5 * ((r1 * 7) % 1))
                        }
                    }
                }

                // ---------------- content ----------------
                Column {
                    id: col
                    x: 12
                    y: 12
                    width: parent.width - 2 * x
                    spacing: root.gap

                    // ---- hero ----
                    Item {
                        width: parent.width
                        height: 172

                        // units + refresh
                        Row {
                            anchors.right: parent.right
                            z: 1
                            spacing: 2

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: unitTxt.implicitWidth + 16
                                height: 24
                                radius: 12
                                color: unitMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
                                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                                Txt {
                                    id: unitTxt
                                    anchors.centerIn: parent
                                    text: Weather.imperial ? "°F" : "°C"
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                                MouseArea {
                                    id: unitMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Weather.setUnits(Weather.imperial ? "metric" : "imperial")
                                }
                            }
                            IconButton {
                                id: refreshBtn
                                implicitWidth: 28
                                implicitHeight: 28
                                iconSize: 14
                                icon: "refresh-cw"
                                onClicked: Weather.refresh()
                                RotationAnimation on rotation {
                                    running: Weather.loading
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 900
                                    onRunningChanged: if (!running) refreshBtn.rotation = 0
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            y: 8

                            Txt {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: Weather.autoLocation
                                text: "MY LOCATION"
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 1.2
                                color: root.dim
                            }

                            // place (click to change)
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: root.editing ? 220 : placeTxt.width + 32
                                height: 30

                                Txt {
                                    id: placeTxt
                                    visible: !root.editing
                                    anchors.centerIn: parent
                                    width: Math.min(implicitWidth, 210)
                                    text: Weather.place || "Locating…"
                                    font.pixelSize: 23
                                    font.weight: Font.Medium
                                }
                                MIcon {
                                    visible: !root.editing
                                    anchors.left: placeTxt.right
                                    anchors.leftMargin: 6
                                    anchors.verticalCenter: placeTxt.verticalCenter
                                    icon: "pencil"
                                    size: 12
                                    color: root.dim
                                    opacity: placeMouse.containsMouse ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                                }
                                MouseArea {
                                    id: placeMouse
                                    anchors.fill: parent
                                    visible: !root.editing
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        cityInput.text = Weather.autoLocation ? "" : Weather.place;
                                        root.editing = true;
                                        cityInput.forceActiveFocus();
                                        cityInput.selectAll();
                                    }
                                }

                                Rectangle {
                                    visible: root.editing
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: 28
                                    radius: height / 2
                                    color: Qt.rgba(0, 0, 0, 0.2)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.2)

                                    MIcon {
                                        id: searchIcon
                                        x: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                        icon: "search"
                                        size: 13
                                        color: root.dim
                                    }
                                    TextInput {
                                        id: cityInput
                                        anchors.left: searchIcon.right
                                        anchors.leftMargin: 7
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: Theme.fg
                                        selectionColor: Theme.accent
                                        selectedTextColor: Theme.accentFg
                                        clip: true
                                        function submit(): void {
                                            root.editing = false;
                                            Weather.setCity(text);
                                        }
                                        Keys.onReturnPressed: submit()
                                        Keys.onEnterPressed: submit()
                                        Keys.onEscapePressed: root.editing = false
                                        // clicking away saves too (Esc clears `editing` first, so it doesn't)
                                        onActiveFocusChanged: if (!activeFocus && root.editing) submit()

                                        Txt {
                                            visible: parent.text === ""
                                            text: "City, or empty for your location"
                                            font.pixelSize: 13
                                            color: root.faint
                                        }
                                    }
                                }
                            }

                            // the number stays centred; the degree sign hangs off it
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: bigTemp.implicitWidth
                                height: 76
                                Text {
                                    id: bigTemp
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.cur ? Math.round(root.cur.temp) : "--"
                                    font.family: Theme.font
                                    font.pixelSize: 74
                                    font.weight: Font.ExtraLight
                                    font.letterSpacing: -3
                                    color: Theme.fg
                                }
                                Text {
                                    anchors.left: bigTemp.right
                                    anchors.top: bigTemp.top
                                    visible: root.cur !== null
                                    text: "°"
                                    font: bigTemp.font
                                    color: Theme.fg
                                }
                            }

                            Txt {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Weather.condition || (Weather.error || "Loading weather…")
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                color: root.dim
                            }
                            Txt {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: root.today !== null
                                text: root.today ? `H:${Weather.deg(root.today.hi)}   L:${Weather.deg(root.today.lo)}` : ""
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    // ---- hourly ----
                    FrostCard {
                        visible: Weather.ready
                        backdrop: sky
                        width: col.width
                        radius: 16
                        tint: 0.04
                        darken: 0.05
                        height: summary.y + summary.height + 88

                        Txt {
                            id: summary
                            x: 14
                            y: 10
                            width: parent.width - 24
                            text: Weather.summary
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                            font.pixelSize: 12
                        }
                        Rectangle {
                            id: hourRule
                            x: 14
                            y: summary.y + summary.height + 8
                            width: parent.width - 24
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.16)
                        }

                        ListView {
                            x: 6
                            y: hourRule.y + 8
                            width: parent.width - 12
                            height: 70
                            orientation: ListView.Horizontal
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true
                            model: Weather.hourly
                            delegate: Column {
                                id: hour
                                required property var modelData
                                required property int index
                                readonly property bool sun: modelData.sun !== undefined
                                width: 45
                                spacing: 3
                                Txt {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: hour.modelData.label
                                    font.pixelSize: 11
                                    font.weight: hour.index === 0 ? Font.Bold : Font.DemiBold
                                }
                                Item {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 28
                                    height: 28
                                    MIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: popTxt.visible ? 0 : 5
                                        icon: hour.sun ? hour.modelData.sun : Weather.iconFor(hour.modelData.code, hour.modelData.day)
                                        size: 17
                                        color: hour.sun ? "#ffb340" : Weather.iconColor(hour.modelData.code, hour.modelData.day)
                                    }
                                    Txt {
                                        id: popTxt
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        visible: !hour.sun && hour.modelData.pop >= 20
                                        text: (hour.modelData.pop ?? 0) + "%"
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        color: Weather.rainColor
                                    }
                                }
                                Txt {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: hour.sun ? (hour.modelData.sun === "sunset" ? "Sunset" : "Sunrise") : Weather.deg(hour.modelData.temp)
                                    font.pixelSize: hour.sun ? 10 : 13
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }

                    // ---- 10-day ----
                    FrostCard {
                        visible: Weather.ready
                        backdrop: sky
                        width: col.width
                        radius: 16
                        tint: 0.04
                        darken: 0.05
                        height: days.y + days.height + 4

                        WeatherCardHeader { icon: "calendar-days"; text: Weather.daily.length + "-DAY FORECAST" }

                        Column {
                            id: days
                            x: 12
                            y: 30
                            width: parent.width - 24

                            Repeater {
                                model: Weather.daily
                                Item {
                                    id: dayRow
                                    required property var modelData
                                    required property int index
                                    readonly property real span: Math.max(1, Weather.weekMax - Weather.weekMin)
                                    width: days.width
                                    height: 31

                                    Rectangle {
                                        width: parent.width
                                        height: 1
                                        color: Qt.rgba(1, 1, 1, 0.16)
                                    }
                                    Txt {
                                        width: 52
                                        height: parent.height
                                        text: dayRow.modelData.label
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }
                                    Column {
                                        x: 52
                                        width: 30
                                        anchors.verticalCenter: parent.verticalCenter
                                        MIcon {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            icon: Weather.iconFor(dayRow.modelData.code, true)
                                            size: 16
                                            color: Weather.iconColor(dayRow.modelData.code, true)
                                        }
                                        Txt {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            visible: dayRow.modelData.pop >= 20
                                            text: dayRow.modelData.pop + "%"
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                            color: Weather.rainColor
                                        }
                                    }
                                    Txt {
                                        id: lo
                                        x: 84
                                        width: 32
                                        height: parent.height
                                        horizontalAlignment: Text.AlignRight
                                        text: Weather.deg(dayRow.modelData.lo)
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        color: root.faint
                                    }
                                    // temperature range against the whole forecast
                                    Rectangle {
                                        anchors.left: lo.right
                                        anchors.leftMargin: 10
                                        anchors.right: hi.left
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 4
                                        radius: 2
                                        color: Qt.rgba(0, 0, 0, 0.2)

                                        Rectangle {
                                            x: (dayRow.modelData.lo - Weather.weekMin) / dayRow.span * parent.width
                                            width: Math.max(height, (dayRow.modelData.hi - dayRow.modelData.lo) / dayRow.span * parent.width)
                                            height: parent.height
                                            radius: parent.radius
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0; color: Weather.tempColor(dayRow.modelData.lo) }
                                                GradientStop { position: 1; color: Weather.tempColor(dayRow.modelData.hi) }
                                            }
                                        }
                                        // where it is right now
                                        Rectangle {
                                            visible: dayRow.index === 0 && root.cur !== null
                                            width: 8
                                            height: 8
                                            radius: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: Math.max(0, Math.min(1, ((root.cur?.temp ?? 0) - Weather.weekMin) / dayRow.span)) * parent.width - width / 2
                                            color: Theme.fg
                                            border.width: 2
                                            border.color: Qt.rgba(0, 0, 0, 0.35)
                                        }
                                    }
                                    Txt {
                                        id: hi
                                        anchors.right: parent.right
                                        width: 32
                                        height: parent.height
                                        horizontalAlignment: Text.AlignRight
                                        text: Weather.deg(dayRow.modelData.hi)
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }
                    }

                    // ---- details ----
                    Row {
                        visible: Weather.ready
                        spacing: root.gap

                        WeatherTile {
                            id: uvTile
                            readonly property real uv: root.cur?.uv ?? 0
                            backdrop: sky
                            width: root.half
                            icon: "sun-medium"
                            title: "UV INDEX"
                            value: Math.round(uv)
                            caption: Weather.uvLevel(uv)
                            sub: root.today ? `Peaks at ${Math.round(root.today.uvMax)} today.` : ""

                            Rectangle {
                                x: 12
                                y: 78
                                width: parent.width - 24
                                height: 4
                                radius: 2
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: "#34c759" }
                                    GradientStop { position: 0.3; color: "#ffd60a" }
                                    GradientStop { position: 0.55; color: "#ff9f0a" }
                                    GradientStop { position: 0.8; color: "#ff453a" }
                                    GradientStop { position: 1; color: "#bf5af2" }
                                }
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.min(1, uvTile.uv / 11) * parent.width - width / 2
                                    color: Theme.fg
                                    border.width: 2
                                    border.color: Qt.rgba(0, 0, 0, 0.35)
                                }
                            }
                        }

                        WeatherTile {
                            id: sunTile
                            // next sun event, judged in the forecast's local time
                            readonly property string now: Weather.data?.current?.time ?? ""
                            readonly property var tomorrow: Weather.daily[1] ?? null
                            readonly property string phase: !root.today ? "" : now < root.today.sunrise ? "dawn"
                                : now < root.today.sunset ? "day" : "night"
                            backdrop: sky
                            width: root.half
                            icon: phase === "day" ? "sunset" : "sunrise"
                            title: phase === "day" ? "SUNSET" : "SUNRISE"
                            value: !root.today ? "" : phase === "dawn" ? root.today.sunrise.slice(11)
                                : phase === "day" ? root.today.sunset.slice(11) : (tomorrow?.sunrise ?? "").slice(11)
                            sub: !root.today ? "" : phase === "day" ? "Sunrise: " + root.today.sunrise.slice(11)
                                : "Sunset: " + (phase === "dawn" ? root.today : tomorrow ?? root.today).sunset.slice(11)

                            // the sun's path over the day, horizon line and where it is now
                            Canvas {
                                id: arc
                                readonly property real rise: root.today ? Weather.minutes(root.today.sunrise) : 360
                                readonly property real set: root.today ? Weather.minutes(root.today.sunset) : 1080
                                readonly property real nowM: Weather.minutes(sunTile.now)
                                x: 8
                                y: 52
                                width: parent.width - 16
                                height: 32
                                onRiseChanged: requestPaint()
                                onSetChanged: requestPaint()
                                onNowMChanged: requestPaint()
                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.reset();
                                    const noon = (rise + set) / 2;
                                    const f = m => Math.cos(2 * Math.PI * (m - noon) / 1440);
                                    const horizon = f(rise);
                                    const yOf = m => height / 2 - (f(m) - horizon) * height * 0.42;
                                    ctx.lineWidth = 2;
                                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.45);
                                    ctx.beginPath();
                                    for (let i = 0; i <= 60; i++) {
                                        const m = i * 24, px = i / 60 * width;
                                        if (i === 0)
                                            ctx.moveTo(px, yOf(m));
                                        else
                                            ctx.lineTo(px, yOf(m));
                                    }
                                    ctx.stroke();
                                    ctx.fillStyle = Qt.rgba(1, 1, 1, 0.3);
                                    ctx.fillRect(0, height / 2, width, 1);
                                    const sx = nowM / 1440 * width, sy = yOf(nowM);
                                    ctx.fillStyle = Qt.rgba(1, 1, 1, 0.25);
                                    ctx.beginPath();
                                    ctx.arc(sx, sy, 8, 0, 2 * Math.PI);
                                    ctx.fill();
                                    ctx.fillStyle = "#ffffff";
                                    ctx.beginPath();
                                    ctx.arc(sx, sy, 4, 0, 2 * Math.PI);
                                    ctx.fill();
                                }
                            }
                        }
                    }

                    FrostCard {
                        visible: Weather.ready
                        backdrop: sky
                        width: col.width
                        radius: 16
                        tint: 0.04
                        darken: 0.05
                        height: 96

                        WeatherCardHeader { icon: "wind"; text: "WIND" }

                        Column {
                            x: 12
                            y: 26
                            width: parent.width - 24 - compass.width - 14

                            Repeater {
                                model: root.cur ? [
                                    ["Wind", Math.round(root.cur.wind) + " " + Weather.windUnit],
                                    ["Gusts", Math.round(root.cur.gusts) + " " + Weather.windUnit],
                                    ["Direction", Math.round(root.cur.windDir) + "° " + Weather.compass(root.cur.windDir)]
                                ] : []
                                Item {
                                    id: windRow
                                    required property var modelData
                                    required property int index
                                    width: parent.width
                                    height: 22
                                    Rectangle {
                                        visible: windRow.index > 0
                                        width: parent.width
                                        height: 1
                                        color: Qt.rgba(1, 1, 1, 0.16)
                                    }
                                    Txt {
                                        height: parent.height
                                        text: windRow.modelData[0]
                                        font.pixelSize: 12
                                    }
                                    Txt {
                                        anchors.right: parent.right
                                        height: parent.height
                                        text: windRow.modelData[1]
                                        font.pixelSize: 12
                                        color: root.dim
                                    }
                                }
                            }
                        }

                        // compass: the needle points where the wind blows to
                        Item {
                            id: compass
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 74
                            height: 74

                            Repeater {
                                model: 36
                                Rectangle {
                                    required property int index
                                    x: compass.width / 2 - width / 2
                                    width: index % 9 === 0 ? 2 : 1
                                    height: index % 9 === 0 ? 7 : 4
                                    color: Qt.rgba(1, 1, 1, index % 9 === 0 ? 0.7 : 0.3)
                                    transform: Rotation {
                                        origin.x: 0.5
                                        origin.y: compass.height / 2
                                        angle: index * 10
                                    }
                                }
                            }
                            Repeater {
                                model: ["N", "E", "S", "W"]
                                Txt {
                                    required property string modelData
                                    required property int index
                                    readonly property real a: index * Math.PI / 2
                                    x: compass.width / 2 + Math.sin(a) * 26 - width / 2
                                    y: compass.height / 2 - Math.cos(a) * 26 - height / 2
                                    text: modelData
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: root.dim
                                }
                            }
                            Item {
                                anchors.fill: parent
                                rotation: (root.cur?.windDir ?? 0) + 180
                                Rectangle {
                                    x: parent.width / 2 - 1
                                    y: 12
                                    width: 2
                                    height: parent.height - 24
                                    radius: 1
                                    color: Theme.fg
                                }
                                MIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 5
                                    icon: "chevron-up"
                                    size: 14
                                }
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                radius: 15
                                color: Qt.tint(root.palette[1], Qt.rgba(0, 0, 0, 0.35))
                                Txt {
                                    anchors.centerIn: parent
                                    text: root.cur ? Math.round(root.cur.wind) : ""
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }

                    Row {
                        visible: Weather.ready
                        spacing: root.gap

                        WeatherTile {
                            readonly property real diff: root.cur ? root.cur.feels - root.cur.temp : 0
                            backdrop: sky
                            width: root.half
                            icon: "thermometer"
                            title: "FEELS LIKE"
                            value: root.cur ? Weather.deg(root.cur.feels) : ""
                            sub: diff < -1.5 ? "Wind is making it feel colder."
                                : diff > 1.5 ? "Humidity is making it feel warmer."
                                : "Similar to the actual temperature."
                        }
                        WeatherTile {
                            backdrop: sky
                            width: root.half
                            icon: "droplets"
                            title: "HUMIDITY"
                            value: root.cur ? root.cur.humidity + "%" : ""
                            sub: root.cur ? `The dew point is ${Weather.deg(root.cur.dew)} right now.` : ""
                        }
                    }

                    // ---- footer ----
                    Txt {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Weather.error && Weather.ready ? Weather.error + " · showing last reading"
                            : Weather.ready ? "Open-Meteo · updated " + Qt.formatTime(new Date(Weather.fetched), "HH:mm") : ""
                        font.pixelSize: 10
                        color: root.faint
                    }
                }
            }
        }
    }
}
