import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false
    property int brightPct: 100
    signal changed()

    IpcHandler {
        target: "brightness"
        function toggle(): void {
            if (!root.open) {
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
        infoProc.running = true
    }

    function setBrightness(pct) {
        const clamped = Math.max(5, Math.min(100, Math.round(pct)))
        root.brightPct = clamped
        actionProc.command = ["brightnessctl", "-q", "set", clamped + "%"]
        actionProc.running = true
    }

    Process {
        id: infoProc
        command: ["sh", "-c", "brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const b = parseInt(this.text.trim(), 10)
                if (!isNaN(b)) root.brightPct = b
            }
        }
    }

    Process {
        id: actionProc
        onExited: root.changed()
    }

    PanelWindow {
        visible: root.open
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }

        Rectangle {
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 42
                rightMargin: 10
            }
            width: 320
            height: col.implicitHeight + 24
            radius: 14
            color: Theme.bg
            border.width: 1
            border.color: Theme.border
            focus: root.open

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            Keys.onEscapePressed: root.open = false

            ColumnLayout {
                id: col
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 12
                }
                spacing: 12

                Text {
                    text: "󰃠  Brightness  " + root.brightPct + "%"
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                    color: "#ffffff"
                }

                // Brightness Slider
                Item {
                    Layout.fillWidth: true
                    height: 20

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 8
                        radius: 4
                        color: Theme.surfaceContainerHigh

                        Rectangle {
                            width: Math.max(0, Math.min(parent.width, parent.width * (root.brightPct / 100)))
                            height: parent.height
                            radius: 4
                            color: Theme.accent
                        }
                    }

                    Rectangle {
                        x: Math.max(0, Math.min(parent.width - width, parent.width * (root.brightPct / 100) - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 8
                        color: "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onPressed: (mouse) => root.setBrightness((mouse.x / width) * 100)
                        onPositionChanged: (mouse) => {
                            if (pressed) root.setBrightness((mouse.x / width) * 100)
                        }
                    }
                }

                // Quick Presets
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [25, 50, 75, 100]
                        delegate: Rectangle {
                            required property int modelData
                            Layout.fillWidth: true
                            height: 28
                            radius: 8
                            color: Math.abs(root.brightPct - modelData) <= 3 ? Theme.primaryContainer : Theme.surfaceContainer
                            border.width: Math.abs(root.brightPct - modelData) <= 3 ? 1 : 0
                            border.color: Theme.accent

                            Text {
                                anchors.centerIn: parent
                                text: modelData + "%"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.setBrightness(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
