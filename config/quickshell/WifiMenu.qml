import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false
    property bool wifiEnabled: true
    property bool scanning: false
    property var networks: []
    property string promptSsid: ""
    property string statusMsg: ""
    signal changed()

    IpcHandler {
        target: "wifi"
        function toggle(): void {
            if (!root.open) {
                root.promptSsid = ""
                root.statusMsg = ""
                root.refresh(false)
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

    function refresh(rescan) {
        root.scanning = rescan
        scanProc.command = [
            "sh", "-c",
            "radio=$(nmcli radio wifi 2>/dev/null); " +
            (rescan ? "nmcli dev wifi rescan 2>/dev/null || true; " : "") +
            "list=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null); " +
            "printf 'RADIO:%s\\n%s\\n' \"$radio\" \"$list\""
        ]
        scanProc.running = true
    }

    function toggleRadio() {
        const next = root.wifiEnabled ? "off" : "on"
        actionProc.command = ["nmcli", "radio", "wifi", next]
        actionProc.running = true
    }

    function connectNetwork(ssid, password) {
        root.statusMsg = "Connecting to " + ssid + "..."
        if (password && password.length > 0) {
            actionProc.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", password]
        } else {
            actionProc.command = ["nmcli", "dev", "wifi", "connect", ssid]
        }
        root.promptSsid = ""
        actionProc.running = true
    }

    function disconnectNetwork(ssid) {
        root.statusMsg = "Disconnecting..."
        actionProc.command = ["nmcli", "con", "down", "id", ssid]
        actionProc.running = true
    }

    Process {
        id: scanProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.scanning = false
                const lines = this.text.split("\n")
                const seen = {}
                const items = []
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim()
                    if (!line) continue
                    if (line.startsWith("RADIO:")) {
                        root.wifiEnabled = line.slice(6).trim() === "enabled"
                        continue
                    }
                    const parts = line.split(":")
                    if (parts.length < 3) continue
                    const active = parts[0] === "*"
                    const ssid = parts[1]
                    if (!ssid || seen[ssid]) continue
                    seen[ssid] = true
                    const signal = parseInt(parts[2], 10) || 0
                    const sec = parts.slice(3).join(":")
                    items.push({ active, ssid, signal, secured: sec.length > 0 })
                }
                items.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
                root.networks = items
            }
        }
    }

    Process {
        id: actionProc
        stderr: StdioCollector {
            onStreamFinished: {
                const err = this.text.trim()
                if (err.length > 0) {
                    root.statusMsg = err.split("\n")[0]
                } else {
                    root.statusMsg = ""
                }
            }
        }
        onExited: {
            root.refresh(false)
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
            id: panel
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

            Keys.onEscapePressed: {
                if (root.promptSsid !== "") root.promptSsid = ""
                else root.open = false
            }

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
                        text: root.wifiEnabled ? "󰤨  Wi-Fi" : "󰤭  Wi-Fi"
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
                            onClicked: root.refresh(true)
                        }
                    }

                    Rectangle {
                        width: 44
                        height: 24
                        radius: 12
                        color: root.wifiEnabled ? Theme.accent : Theme.surfaceContainerHigh
                        Text {
                            anchors.centerIn: parent
                            text: root.wifiEnabled ? "ON" : "OFF"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.wifiEnabled ? Theme.onPrimary : "#ffffff"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.toggleRadio()
                        }
                    }
                }

                // Inline password prompt
                Rectangle {
                    visible: root.promptSsid.length > 0
                    Layout.fillWidth: true
                    height: 36
                    radius: 8
                    color: Theme.surfaceContainer
                    border.width: 1
                    border.color: Theme.accent

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 8
                        }
                        spacing: 6

                        TextInput {
                            id: passInput
                            Layout.fillWidth: true
                            echoMode: TextInput.Password
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: "#ffffff"
                            clip: true
                            onVisibleChanged: {
                                if (visible) {
                                    text = ""
                                    forceActiveFocus()
                                }
                            }
                            Keys.onReturnPressed: root.connectNetwork(root.promptSsid, text)
                            Keys.onEscapePressed: root.promptSsid = ""

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Password for " + root.promptSsid + "..."
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textDim
                                visible: !passInput.text
                            }
                        }
                    }
                }

                // Status message
                Text {
                    visible: root.statusMsg.length > 0
                    Layout.fillWidth: true
                    text: root.statusMsg
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.accent
                    elide: Text.ElideRight
                }

                // Network List
                ListView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(310, Math.max(48, root.networks.length * 42))
                    clip: true
                    spacing: 4
                    model: root.networks
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 38
                        radius: 8
                        color: modelData.active ? Theme.primaryContainer : Theme.surfaceContainer
                        border.width: modelData.active ? 1 : 0
                        border.color: Theme.accent

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 10
                            }
                            spacing: 8

                            Text {
                                text: modelData.signal >= 70 ? "󰤨" : (modelData.signal >= 40 ? "󰤥" : "󰤟")
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: modelData.active ? Theme.accent : "#ffffff"
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.ssid
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: modelData.active
                                color: "#ffffff"
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: modelData.secured
                                text: ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textDim
                            }

                            Text {
                                text: modelData.active ? "Connected" : (modelData.signal + "%")
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: modelData.active ? Theme.accent : Theme.textDim
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (modelData.active) {
                                    root.disconnectNetwork(modelData.ssid)
                                } else if (modelData.secured) {
                                    // Try saved connection first, or open password prompt on right-click / if failed
                                    root.promptSsid = modelData.ssid
                                } else {
                                    root.connectNetwork(modelData.ssid, "")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
