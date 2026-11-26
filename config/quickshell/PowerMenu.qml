import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false

    IpcHandler {
        target: "power"
        function toggle(): void {
            root.open = !root.open
        }
        function closeIfOpen(): bool {
            if (root.open) {
                root.open = false
                return true
            }
            return false
        }
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
            width: 360
            height: 130
            radius: 16
            color: Theme.bg
            border.width: 1
            border.color: Theme.border
            focus: root.open

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            Keys.onEscapePressed: root.open = false

            RowLayout {
                anchors {
                    fill: parent
                    margins: 16
                }
                spacing: 12

                Repeater {
                    model: [
                        { label: "Lock", icon: "", cmd: ["qs", "ipc", "call", "lock", "lock"], accent: false },
                        { label: "Reboot", icon: "󰜉", cmd: ["systemctl", "reboot"], accent: false },
                        { label: "Shutdown", icon: "⏻", cmd: ["systemctl", "poweroff"], accent: true }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: Theme.surfaceContainer
                        border.width: 1
                        border.color: modelData.accent ? Theme.error : "#22ffffff"

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.icon
                                font.family: Theme.fontFamily
                                font.pixelSize: 22
                                color: modelData.accent ? Theme.error : Theme.accent
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.open = false
                                Quickshell.execDetached(modelData.cmd)
                            }
                        }
                    }
                }
            }
        }
    }
}
