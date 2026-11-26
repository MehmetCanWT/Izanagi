import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property string deviceName: ""
    property bool reachable: false
    property int charge: -1
    property bool charging: false

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: phoneProc.running = true
    }

    Process {
        id: phoneProc
        command: [
            "sh", "-c",
            "id=$(kdeconnect-cli -l --id-only 2>/dev/null | head -n1); " +
            "if [ -z \"$id\" ]; then printf '\\nfalse\\n-1\\nfalse\\n'; exit 0; fi; " +
            "name=$(qdbus6 org.kde.kdeconnect \"/modules/kdeconnect/devices/$id\" org.kde.kdeconnect.device.name 2>/dev/null || true); " +
            "reach=$(qdbus6 org.kde.kdeconnect \"/modules/kdeconnect/devices/$id\" org.kde.kdeconnect.device.isReachable 2>/dev/null || echo false); " +
            "chg=$(qdbus6 org.kde.kdeconnect \"/modules/kdeconnect/devices/$id/battery\" org.kde.kdeconnect.device.battery.charge 2>/dev/null || echo -1); " +
            "is_c=$(qdbus6 org.kde.kdeconnect \"/modules/kdeconnect/devices/$id/battery\" org.kde.kdeconnect.device.battery.isCharging 2>/dev/null || echo false); " +
            "printf '%s\\n%s\\n%s\\n%s\\n' \"$name\" \"$reach\" \"$chg\" \"$is_c\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                root.deviceName = (lines[0] || "").trim()
                root.reachable = (lines[1] || "").trim() === "true"
                const c = parseInt((lines[2] || "-1").trim(), 10)
                root.charge = isNaN(c) ? -1 : c
                root.charging = (lines[3] || "").trim() === "true"
            }
        }
    }

    PanelWindow {
        visible: root.deviceName.length > 0
        anchors {
            bottom: true
            left: true
        }
        margins {
            bottom: 158
            left: 28
        }
        implicitWidth: 230
        implicitHeight: col.implicitHeight + 12
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.exclusiveZone: -1

        Rectangle {
            anchors.fill: parent
            color: "transparent"

            ColumnLayout {
                id: col
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 6
                }
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: (root.charging ? "󰂄  " : "  ") + root.deviceName
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: root.reachable ? "#ffffff" : "#99ffffff"
                        style: Text.Outline
                        styleColor: "#aa000000"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.reachable && root.charge >= 0 ? (root.charge + "%") : "Offline"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: root.reachable ? (root.charge <= 20 ? Theme.error : Theme.accent) : "#88ffffff"
                        style: Text.Outline
                        styleColor: "#aa000000"
                    }
                }

                Rectangle {
                    visible: root.reachable && root.charge >= 0
                    Layout.fillWidth: true
                    height: 5
                    radius: 3
                    color: "#55000000"

                    Rectangle {
                        width: parent.width * (Math.min(100, Math.max(0, root.charge)) / 100)
                        height: parent.height
                        radius: 3
                        color: root.charge <= 20 ? Theme.error : Theme.accent
                    }
                }
            }
        }
    }
}
