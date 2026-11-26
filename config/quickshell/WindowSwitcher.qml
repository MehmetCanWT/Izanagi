import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false
    property int currentIndex: 0
    property var windows: []
    readonly property int cols: Math.max(1, Math.min(4, windows.length))
    readonly property int rows: Math.max(1, Math.min(3, Math.ceil(windows.length / cols)))

    onOpenChanged: {
        if (!open) {
            windows = []
            Qt.callLater(gc)
        }
    }

    IpcHandler {
        target: "switcher"
        function next(): void {
            if (!root.open) {
                root.refreshWindows()
                root.open = root.windows.length > 0
                if (root.windows.length > 1) root.currentIndex = 1
                else root.currentIndex = 0
            } else if (root.windows.length > 0) {
                root.currentIndex = (root.currentIndex + 1) % root.windows.length
            }
        }
        function prev(): void {
            if (!root.open) {
                root.refreshWindows()
                root.open = root.windows.length > 0
                root.currentIndex = Math.max(0, root.windows.length - 1)
            } else if (root.windows.length > 0) {
                root.currentIndex = (root.currentIndex - 1 + root.windows.length) % root.windows.length
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

    function refreshWindows() {
        const list = [...Hyprland.toplevels.values].filter(t => t && t.title)
        root.windows = list
    }

    function iconFor(toplevel) {
        const cls = (toplevel.lastIpcObject && toplevel.lastIpcObject.class) ? toplevel.lastIpcObject.class : ""
        if (!cls) return ""
        const entry = DesktopEntries.heuristicLookup(cls)
        if (entry && entry.icon) return Quickshell.iconPath(entry.icon, true)
        return Quickshell.iconPath(cls.toLowerCase(), true)
    }

    function focusCurrent() {
        if (root.windows.length > 0 && root.currentIndex >= 0 && root.currentIndex < root.windows.length) {
            const win = root.windows[root.currentIndex]
            const addr = win.address ? String(win.address) : ""
            if (addr.length > 0) {
                const hex = addr.startsWith("0x") ? addr : ("0x" + addr)
                Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + hex + "\" })")
            }
        }
        root.open = false
    }

    PanelWindow {
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
            anchors.centerIn: parent
            width: root.cols * 276 + 24
            height: root.rows * 204 + 24
            radius: 18
            color: Theme.bg
            border.width: 1
            border.color: Theme.border
            focus: root.open

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.open = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                    if (root.windows.length > 0)
                        root.currentIndex = (root.currentIndex + 1) % root.windows.length
                    event.accepted = true
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                    if (root.windows.length > 0)
                        root.currentIndex = (root.currentIndex - 1 + root.windows.length) % root.windows.length
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.focusCurrent()
                    event.accepted = true
                }
            }

            GridView {
                id: grid
                anchors {
                    fill: parent
                    margins: 12
                }
                clip: true
                cellWidth: 276
                cellHeight: 204
                model: root.windows
                currentIndex: root.currentIndex
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: index === root.currentIndex

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors {
                            fill: parent
                            margins: 6
                        }
                        radius: 12
                        color: isCurrent ? Theme.primaryContainer : Theme.surfaceContainer
                        border.width: isCurrent ? 2 : 1
                        border.color: isCurrent ? Theme.accent : "#22ffffff"

                        ColumnLayout {
                            anchors {
                                fill: parent
                                margins: 8
                            }
                            spacing: 6

                            // Card Header (Icon + Title + Workspace)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Image {
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    source: root.iconFor(modelData)
                                    sourceSize: Qt.size(16, 16)
                                    smooth: true
                                    visible: status === Image.Ready
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: isCurrent
                                    color: "#ffffff"
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 5
                                    color: isCurrent ? Theme.accent : Theme.surfaceContainerHigh
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.workspace ? modelData.workspace.id : "•"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: isCurrent ? Theme.onPrimary : "#ffffff"
                                    }
                                }
                            }

                            // Live Window Preview via ScreencopyView
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: "#11111b"
                                }

                                Item {
                                    id: previewWrap
                                    anchors.fill: parent

                                    ScreencopyView {
                                        anchors.centerIn: parent
                                        captureSource: root.open ? modelData.wayland : null
                                        live: root.open
                                        constraintSize: Qt.size(previewWrap.width, previewWrap.height)
                                    }
                                }

                                Rectangle {
                                    id: previewMask
                                    anchors.fill: parent
                                    radius: 8
                                    visible: false
                                    layer.enabled: true
                                }

                                MultiEffect {
                                    anchors.fill: parent
                                    source: previewWrap
                                    maskEnabled: true
                                    maskSource: previewMask
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.currentIndex = index
                            onClicked: root.focusCurrent()
                        }
                    }
                }
            }
        }
    }
}
