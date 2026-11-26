import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false
    property int currentIndex: 0
    property var windows: []

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

    function focusCurrent() {
        if (root.windows.length > 0 && root.currentIndex >= 0 && root.currentIndex < root.windows.length) {
            const win = root.windows[root.currentIndex]
            const addr = win.address ? String(win.address) : ""
            if (addr.length > 0) {
                const hex = addr.startsWith("0x") ? addr : ("0x" + Number(addr).toString(16))
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
        color: "#55000000"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 540)
            height: Math.min(440, list.contentHeight + 28)
            radius: 16
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
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                    if (root.windows.length > 0)
                        root.currentIndex = (root.currentIndex + 1) % root.windows.length
                    event.accepted = true
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                    if (root.windows.length > 0)
                        root.currentIndex = (root.currentIndex - 1 + root.windows.length) % root.windows.length
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.focusCurrent()
                    event.accepted = true
                }
            }

            ListView {
                id: list
                anchors {
                    fill: parent
                    margins: 14
                }
                clip: true
                spacing: 6
                model: root.windows
                currentIndex: root.currentIndex
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool isCurrent: index === root.currentIndex

                    width: list.width
                    height: 44
                    radius: 10
                    color: isCurrent ? Theme.primaryContainer : Theme.surfaceContainer
                    border.width: isCurrent ? 1 : 0
                    border.color: Theme.accent

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 12
                        }
                        spacing: 10

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 6
                            color: isCurrent ? Theme.accent : Theme.surfaceContainerHigh
                            Text {
                                anchors.centerIn: parent
                                text: modelData.workspace ? modelData.workspace.id : "•"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: isCurrent ? Theme.onPrimary : "#ffffff"
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.title || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.bold: isCurrent
                            color: "#ffffff"
                            elide: Text.ElideRight
                        }

                        Text {
                            text: (modelData.lastIpcObject && modelData.lastIpcObject.class) ? modelData.lastIpcObject.class : ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textDim
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
