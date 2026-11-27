import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false
    property bool searchOpen: false
    property var allWallpapers: []
    property var filteredWallpapers: []
    property string searchQuery: ""
    property string activeWallpaper: ""

    onOpenChanged: {
        if (!open) {
            searchOpen = false
            searchQuery = ""
            allWallpapers = []
            filteredWallpapers = []
            Qt.callLater(gc)
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            if (!root.open) {
                root.searchOpen = false
                root.searchQuery = ""
                root.refresh()
                root.open = true
            } else {
                root.open = false
            }
        }
        function closeIfOpen(): bool {
            if (root.open) {
                root.open = false
                return true
            }
            return false
        }
    }

    function refresh() {
        scanProc.running = true
    }

    function applyFilter() {
        const q = searchQuery.trim().toLowerCase()
        if (q === "") {
            filteredWallpapers = allWallpapers
        } else {
            filteredWallpapers = allWallpapers.filter(item =>
                item.title.toLowerCase().includes(q) || item.target.toLowerCase().includes(q)
            )
        }
        if (filteredWallpapers.length > 0) {
            let idx = -1
            if (root.activeWallpaper) {
                idx = filteredWallpapers.findIndex(item => item.target === root.activeWallpaper)
            }
            carousel.currentIndex = idx >= 0 ? idx : 0
        }
    }

    function applyWallpaper(item) {
        if (!item || !item.target) return
        applyProc.command = [Quickshell.env("HOME") + "/.local/bin/apply-wallpaper", item.target]
        applyProc.running = true
        root.open = false
    }

    function stepNext() {
        if (filteredWallpapers.length > 0) carousel.incrementCurrentIndex()
    }

    function stepPrev() {
        if (filteredWallpapers.length > 0) carousel.decrementCurrentIndex()
    }

    function applyCurrent() {
        if (filteredWallpapers.length > 0 && carousel.currentIndex >= 0 && carousel.currentIndex < filteredWallpapers.length) {
            applyWallpaper(filteredWallpapers[carousel.currentIndex])
        }
    }

    Process {
        id: scanProc
        command: [
            "sh", "-c",
            "cur=''; " +
            "if [ -f \"$HOME/.cache/izanagi-wallpaper\" ]; then cur=$(head -n1 \"$HOME/.cache/izanagi-wallpaper\" 2>/dev/null || true); fi; " +
            "if [ -z \"$cur\" ]; then cur=$(sed -n 's/^[[:space:]]*path[[:space:]]*=[[:space:]]*//p' \"$HOME/.config/hypr/hyprpaper.conf\" 2>/dev/null | head -n1); cur=${cur/#\\~/$HOME}; fi; " +
            "printf 'ACTIVE:%s\\n' \"$cur\"; " +
            "we_dir=\"$HOME/.local/share/Steam/steamapps/workshop/content/431960\"; " +
            "if [ -d \"$we_dir\" ]; then " +
            "  for p in \"$we_dir\"/*/project.json; do " +
            "    [ -f \"$p\" ] || continue; " +
            "    dir=${p%/project.json}; wid=${dir##*/}; " +
            "    wtype=$(jq -r '.type // \"scene\"' \"$p\" 2>/dev/null | tr '[:upper:]' '[:lower:]'); " +
            "    [ \"$wtype\" = \"scene\" ] || [ \"$wtype\" = \"video\" ] || continue; " +
            "    title=$(jq -r '.title // empty' \"$p\" 2>/dev/null | tr -d '|'); " +
            "    [ -n \"$title\" ] || title=\"$wid\"; " +
            "    prev=$(jq -r '.preview // empty' \"$p\" 2>/dev/null); " +
            "    pp=\"$dir/$prev\"; " +
            "    [ -f \"$pp\" ] || pp=$(find \"$dir\" -maxdepth 1 -type f -iname 'preview.*' 2>/dev/null | head -n1 || true); " +
            "    [ -f \"$pp\" ] && printf 'WE|%s|%s|%s\\n' \"$wid\" \"$pp\" \"$title\"; " +
            "  done; " +
            "fi; " +
            "find \"$HOME/Pictures/Wallpapers\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = this.text.split("\n").map(s => s.trim()).filter(s => s.length > 0)
                const items = []
                for (let i = 0; i < raw.length; i++) {
                    const line = raw[i]
                    if (line.startsWith("ACTIVE:")) {
                        root.activeWallpaper = line.slice(7).trim()
                    } else if (line.startsWith("WE|")) {
                        const parts = line.split("|")
                        if (parts.length >= 4) {
                            items.push({
                                target: "we:" + parts[1],
                                preview: parts[2],
                                title: parts.slice(3).join("|"),
                                isWe: true
                            })
                        }
                    } else {
                        const name = line.split("/").pop()
                        items.push({
                            target: line,
                            preview: line,
                            title: name,
                            isWe: false
                        })
                    }
                }
                root.allWallpapers = items
                root.applyFilter()
            }
        }
    }

    Process {
        id: applyProc
    }

    PanelWindow {
        id: win
        visible: root.open
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "#66000000"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }

        Rectangle {
            id: container
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, 1760)
            height: root.searchOpen ? 480 : 440
            radius: 16
            color: "transparent"
            border.width: 0
            focus: root.open

            Behavior on height {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0) {
                        root.stepNext()
                    } else if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                        root.stepPrev()
                    }
                }
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.open = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_D) {
                    root.stepNext()
                    event.accepted = true
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_A) {
                    root.stepPrev()
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.applyCurrent()
                    event.accepted = true
                } else if (event.key === Qt.Key_Slash || event.key === Qt.Key_Colon) {
                    root.searchOpen = true
                    searchInput.forceActiveFocus()
                    event.accepted = true
                }
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                    topMargin: 12
                    bottomMargin: 12
                }
                spacing: 10

                // Tear-free infinite GPU-scaled carousel
                PathView {
                    id: carousel
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: false
                    model: root.filteredWallpapers
                    pathItemCount: Math.min(5, Math.max(1, root.filteredWallpapers.length))
                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5
                    highlightRangeMode: PathView.StrictlyEnforceRange
                    highlightMoveDuration: 220
                    snapMode: PathView.SnapToItem
                    cacheItemCount: 2

                    path: Path {
                        startX: 200
                        startY: carousel.height / 2
                        PathAttribute { name: "cardScale"; value: 0.62 }
                        PathAttribute { name: "cardOpacity"; value: 0.65 }
                        PathAttribute { name: "cardZ"; value: 1 }

                        PathLine {
                            x: carousel.width / 2
                            y: carousel.height / 2
                        }
                        PathAttribute { name: "cardScale"; value: 1.0 }
                        PathAttribute { name: "cardOpacity"; value: 1.0 }
                        PathAttribute { name: "cardZ"; value: 20 }

                        PathLine {
                            x: carousel.width - 200
                            y: carousel.height / 2
                        }
                        PathAttribute { name: "cardScale"; value: 0.62 }
                        PathAttribute { name: "cardOpacity"; value: 0.65 }
                        PathAttribute { name: "cardZ"; value: 1 }
                    }

                    delegate: Item {
                        required property var modelData
                        required property int index
                        readonly property bool isCurrent: PathView.isCurrentItem
                        readonly property bool isGif: modelData && modelData.preview ? modelData.preview.toLowerCase().endsWith(".gif") : false

                        width: 600
                        height: 360
                        scale: PathView.cardScale ?? 1.0
                        opacity: PathView.cardOpacity ?? 1.0
                        z: PathView.cardZ ?? 1

                        Item {
                            id: wpVisual
                            anchors.fill: parent
                            visible: false

                            Rectangle {
                                anchors.fill: parent
                                color: "#111118"
                            }

                            // Dimmed fill backdrop for square WE previews
                            Image {
                                visible: modelData.isWe
                                anchors.fill: parent
                                source: (root.open && modelData.isWe) ? ("file://" + modelData.preview) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                smooth: true
                                opacity: 0.25
                                sourceSize: Qt.size(256, 256)
                            }

                            // Static image (non-GIF)
                            Image {
                                visible: !isGif
                                anchors.fill: parent
                                source: (root.open && !isGif) ? ("file://" + modelData.preview) : ""
                                fillMode: modelData.isWe ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                smooth: true
                                sourceSize: modelData.isWe ? undefined : Qt.size(1080, 648)
                            }

                            // Animated GIF preview (plays when focused)
                            AnimatedImage {
                                visible: isGif
                                anchors.fill: parent
                                source: (root.open && isGif) ? ("file://" + modelData.preview) : ""
                                fillMode: modelData.isWe ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                smooth: true
                                playing: root.open && isCurrent
                            }
                        }

                        Rectangle {
                            id: wpMask
                            anchors.fill: parent
                            radius: 16
                            visible: false
                            layer.enabled: true
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: wpVisual
                            maskEnabled: true
                            maskSource: wpMask
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            radius: 16
                            border.width: isCurrent ? 2 : 1
                            border.color: isCurrent ? Theme.accent : "#33ffffff"
                        }

                        Rectangle {
                            visible: modelData.isWe
                            anchors {
                                top: parent.top
                                left: parent.left
                                margins: 10
                            }
                            width: weText.implicitWidth + 12
                            height: 22
                            radius: 6
                            color: "#cc101015"
                            border.width: 1
                            border.color: Theme.accent

                            Text {
                                id: weText
                                anchors.centerIn: parent
                                text: "󰎁 WE"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.accent
                            }
                        }

                        Rectangle {
                            visible: modelData.isWe && isCurrent && modelData.title.length > 0
                            anchors {
                                bottom: parent.bottom
                                horizontalCenter: parent.horizontalCenter
                                bottomMargin: 10
                            }
                            width: Math.min(parent.width - 24, weTitle.implicitWidth + 16)
                            height: 24
                            radius: 6
                            color: "#cc101015"

                            Text {
                                id: weTitle
                                anchors {
                                    fill: parent
                                    leftMargin: 8
                                    rightMargin: 8
                                }
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData.title
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: "#ffffff"
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (isCurrent) {
                                    root.applyWallpaper(modelData)
                                } else {
                                    carousel.currentIndex = index
                                }
                            }
                            onDoubleClicked: root.applyWallpaper(modelData)
                        }
                    }
                }

                // Minimal bottom search bar (only visible when '/' or ':' pressed)
                Rectangle {
                    visible: root.searchOpen
                    Layout.fillWidth: true
                    height: 30
                    radius: 8
                    color: "#1c1c26"
                    border.width: 1
                    border.color: Theme.accentAlt

                    TextInput {
                        id: searchInput
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.text
                        clip: true
                        onTextChanged: {
                            root.searchQuery = text
                            root.applyFilter()
                        }
                        Keys.onEscapePressed: {
                            text = ""
                            root.searchOpen = false
                            container.forceActiveFocus()
                        }
                        Keys.onReturnPressed: root.applyCurrent()
                    }
                }
            }
        }
    }
}
