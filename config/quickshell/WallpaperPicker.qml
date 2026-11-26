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
            filteredWallpapers = allWallpapers.filter(p => p.toLowerCase().includes(q))
        }
        if (filteredWallpapers.length > 0) {
            carousel.currentIndex = 0
        }
    }

    function applyWallpaper(path) {
        if (!path) return
        applyProc.command = [Quickshell.env("HOME") + "/.local/bin/apply-wallpaper", path]
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
        command: ["sh", "-c", "find \"$HOME/Pictures/Wallpapers\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").map(s => s.trim()).filter(s => s.length > 0)
                root.allWallpapers = lines
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
            width: Math.min(parent.width - 48, 1340)
            height: root.searchOpen ? 410 : 370
            radius: 16
            color: "#ea101015"
            border.width: 1
            border.color: "#2affffff"
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

                // Tear-free infinite GPU-scaled carousel (fixed size + fixed sourceSize)
                PathView {
                    id: carousel
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.filteredWallpapers
                    pathItemCount: Math.min(7, Math.max(1, root.filteredWallpapers.length))
                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5
                    highlightRangeMode: PathView.StrictlyEnforceRange
                    highlightMoveDuration: 220
                    snapMode: PathView.SnapToItem
                    cacheItemCount: 4

                    path: Path {
                        startX: -40
                        startY: carousel.height / 2
                        PathAttribute { name: "cardScale"; value: 0.62 }
                        PathAttribute { name: "cardOpacity"; value: 0.55 }
                        PathAttribute { name: "cardZ"; value: 1 }

                        PathLine {
                            x: carousel.width / 2
                            y: carousel.height / 2
                        }
                        PathAttribute { name: "cardScale"; value: 1.0 }
                        PathAttribute { name: "cardOpacity"; value: 1.0 }
                        PathAttribute { name: "cardZ"; value: 20 }

                        PathLine {
                            x: carousel.width + 40
                            y: carousel.height / 2
                        }
                        PathAttribute { name: "cardScale"; value: 0.62 }
                        PathAttribute { name: "cardOpacity"; value: 0.55 }
                        PathAttribute { name: "cardZ"; value: 1 }
                    }

                    delegate: Item {
                        required property string modelData
                        required property int index
                        readonly property bool isCurrent: PathView.isCurrentItem

                        width: 520
                        height: 310
                        scale: PathView.cardScale ?? 1.0
                        opacity: PathView.cardOpacity ?? 1.0
                        z: PathView.cardZ ?? 1

                        Image {
                            id: wpImg
                            anchors.fill: parent
                            source: "file://" + modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            visible: false
                            sourceSize: Qt.size(960, 560)
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
                            source: wpImg
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
