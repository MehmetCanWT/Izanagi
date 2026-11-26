import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false
    property int volPct: 50
    property bool volMuted: false
    property int micPct: 50
    property bool micMuted: false
    property var sinks: []
    signal changed()

    IpcHandler {
        target: "audio"
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

    function setVolume(pct) {
        const clamped = Math.max(0, Math.min(100, Math.round(pct)))
        root.volPct = clamped
        actionProc.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", clamped + "%"]
        actionProc.running = true
    }

    function setMicVolume(pct) {
        const clamped = Math.max(0, Math.min(100, Math.round(pct)))
        root.micPct = clamped
        actionProc.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SOURCE@", clamped + "%"]
        actionProc.running = true
    }

    function toggleMute() {
        actionProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        actionProc.running = true
    }

    function toggleMicMute() {
        actionProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
        actionProc.running = true
    }

    function setDefaultSink(id) {
        actionProc.command = ["wpctl", "set-default", String(id)]
        actionProc.running = true
    }

    Process {
        id: infoProc
        command: [
            "sh", "-c",
            "sink=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); " +
            "src=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null); " +
            "printf 'SINK:%s\\nSRC:%s\\n' \"$sink\" \"$src\"; " +
            "wpctl status 2>/dev/null | awk '/├─ Sinks:/,/├─ Sources:/{ if ($0 ~ /[0-9]+\\./) print \"DEV:\" $0 }'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                const sinkList = []
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i]
                    if (line.startsWith("SINK:")) {
                        const s = line.slice(5)
                        root.volMuted = s.indexOf("[MUTED]") !== -1
                        const m = s.match(/Volume:\s*([0-9.]+)/)
                        if (m) root.volPct = Math.round(parseFloat(m[1]) * 100)
                    } else if (line.startsWith("SRC:")) {
                        const s = line.slice(4)
                        root.micMuted = s.indexOf("[MUTED]") !== -1
                        const m = s.match(/Volume:\s*([0-9.]+)/)
                        if (m) root.micPct = Math.round(parseFloat(m[1]) * 100)
                    } else if (line.startsWith("DEV:")) {
                        const raw = line.slice(4)
                        const active = raw.indexOf("*") !== -1
                        const m = raw.match(/(\d+)\.\s*(.+?)(\s*\[vol:.*\])?$/)
                        if (m) {
                            sinkList.push({ id: m[1], name: m[2].trim(), active })
                        }
                    }
                }
                root.sinks = sinkList
            }
        }
    }

    Process {
        id: actionProc
        onExited: {
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

                // Output Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: (root.volMuted ? "󰖁  " : "󰕾  ") + "Volume  " + root.volPct + "%"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: "#ffffff"
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 56
                        height: 24
                        radius: 12
                        color: root.volMuted ? Theme.error : Theme.accent
                        Text {
                            anchors.centerIn: parent
                            text: root.volMuted ? "MUTED" : "LIVE"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: Theme.onPrimary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.toggleMute()
                        }
                    }
                }

                // Volume Slider
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
                            width: Math.max(0, Math.min(parent.width, parent.width * (root.volPct / 100)))
                            height: parent.height
                            radius: 4
                            color: root.volMuted ? Theme.error : Theme.accent
                        }
                    }

                    Rectangle {
                        x: Math.max(0, Math.min(parent.width - width, parent.width * (root.volPct / 100) - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 8
                        color: "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onPressed: (mouse) => root.setVolume((mouse.x / width) * 100)
                        onPositionChanged: (mouse) => {
                            if (pressed) root.setVolume((mouse.x / width) * 100)
                        }
                    }
                }

                // Mic Header + Slider
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: (root.micMuted ? "󰍭  " : "󰍬  ") + "Mic  " + root.micPct + "%"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: "#ffffff"
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 56
                        height: 22
                        radius: 11
                        color: root.micMuted ? Theme.error : Theme.surfaceContainerHigh
                        Text {
                            anchors.centerIn: parent
                            text: root.micMuted ? "MUTED" : "ON"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.micMuted ? Theme.onPrimary : "#ffffff"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.toggleMicMute()
                        }
                    }
                }

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
                            width: Math.max(0, Math.min(parent.width, parent.width * (root.micPct / 100)))
                            height: parent.height
                            radius: 4
                            color: root.micMuted ? Theme.error : Theme.tertiary
                        }
                    }

                    Rectangle {
                        x: Math.max(0, Math.min(parent.width - width, parent.width * (root.micPct / 100) - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 8
                        color: "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onPressed: (mouse) => root.setMicVolume((mouse.x / width) * 100)
                        onPositionChanged: (mouse) => {
                            if (pressed) root.setMicVolume((mouse.x / width) * 100)
                        }
                    }
                }

                // Output Devices
                ColumnLayout {
                    visible: root.sinks.length > 0
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Output Devices"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textDim
                    }

                    Repeater {
                        model: root.sinks
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            height: 32
                            radius: 8
                            color: modelData.active ? Theme.primaryContainer : Theme.surfaceContainer
                            border.width: modelData.active ? 1 : 0
                            border.color: Theme.accent

                            Text {
                                anchors {
                                    fill: parent
                                    leftMargin: 10
                                    rightMargin: 10
                                }
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: modelData.active
                                color: "#ffffff"
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.setDefaultSink(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
