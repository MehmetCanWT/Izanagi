import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false
    property bool powered: false
    property bool scanning: false
    property var devices: []
    property string statusMsg: ""
    signal changed()

    IpcHandler {
        target: "bluetooth"
        function toggle(): void {
            if (!root.open) {
                root.statusMsg = ""
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
        scanProc.command = [
            "sh", "-c",
            "pwr=$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2; exit}'); " +
            "printf 'PWR:%s\\n' \"$pwr\"; " +
            "bluetoothctl devices 2>/dev/null | while read -r _ mac name; do " +
            "  info=$(bluetoothctl info \"$mac\" 2>/dev/null); " +
            "  conn=$(printf '%s\\n' \"$info\" | awk '/Connected:/{print $2; exit}'); " +
            "  paired=$(printf '%s\\n' \"$info\" | awk '/Paired:/{print $2; exit}'); " +
            "  printf 'DEV:%s|%s|%s|%s\\n' \"$mac\" \"$conn\" \"$paired\" \"$name\"; " +
            "done"
        ]
        scanProc.running = true
    }

    function togglePower() {
        const next = root.powered ? "off" : "on"
        actionProc.command = ["bluetoothctl", "power", next]
        actionProc.running = true
    }

    function startScan() {
        root.scanning = true
        root.statusMsg = "Scanning..."
        btScanProc.running = true
    }

    function toggleDevice(mac, connected) {
        root.statusMsg = connected ? "Disconnecting..." : "Connecting..."
        actionProc.command = ["bluetoothctl", connected ? "disconnect" : "connect", mac]
        actionProc.running = true
    }

    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                const items = []
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim()
                    if (!line) continue
                    if (line.startsWith("PWR:")) {
                        root.powered = line.slice(4).trim() === "yes"
                        continue
                    }
                    if (line.startsWith("DEV:")) {
                        const parts = line.slice(4).split("|")
                        if (parts.length < 4) continue
                        items.push({
                            mac: parts[0],
                            connected: parts[1] === "yes",
                            paired: parts[2] === "yes",
                            name: parts.slice(3).join("|") || parts[0]
                        })
                    }
                }
                items.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired))
                root.devices = items
            }
        }
    }

    Process {
        id: btScanProc
        command: ["bluetoothctl", "--timeout", "5", "scan", "on"]
        onExited: {
            root.scanning = false
            root.statusMsg = ""
            root.refresh()
        }
    }

    Process {
        id: actionProc
        onExited: {
            root.statusMsg = ""
            root.refresh()
            root.changed()
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
            width: 340
            height: Math.min(440, col.implicitHeight + 24)
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
                spacing: 10

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: root.powered ? "󰂯  Bluetooth" : "󰂲  Bluetooth"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: "#ffffff"
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 28
                        height: 24
                        radius: 6
                        color: Theme.surfaceContainerHigh
                        Text {
                            anchors.centerIn: parent
                            text: root.scanning ? "󰑐" : "󰑓"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: "#ffffff"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.startScan()
                        }
                    }

                    Rectangle {
                        width: 44
                        height: 24
                        radius: 12
                        color: root.powered ? Theme.accent : Theme.surfaceContainerHigh
                        Text {
                            anchors.centerIn: parent
                            text: root.powered ? "ON" : "OFF"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.powered ? Theme.onPrimary : "#ffffff"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.togglePower()
                        }
                    }
                }

                Text {
                    visible: root.statusMsg.length > 0
                    Layout.fillWidth: true
                    text: root.statusMsg
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.accent
                }

                // Devices List
                ListView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(310, Math.max(48, root.devices.length * 42))
                    clip: true
                    spacing: 4
                    model: root.devices
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 38
                        radius: 8
                        color: modelData.connected ? Theme.primaryContainer : Theme.surfaceContainer
                        border.width: modelData.connected ? 1 : 0
                        border.color: Theme.accent

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 10
                            }
                            spacing: 8

                            Text {
                                text: modelData.connected ? "󰂱" : "󰂯"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: modelData.connected ? Theme.accent : "#ffffff"
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: modelData.connected
                                color: "#ffffff"
                                elide: Text.ElideRight
                            }

                            Text {
                                text: modelData.connected ? "Connected" : (modelData.paired ? "Paired" : "Available")
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: modelData.connected ? Theme.accent : Theme.textDim
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.toggleDevice(modelData.mac, modelData.connected)
                        }
                    }
                }
            }
        }
    }
}
