import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property int cpuPct: 0
    property int ramPct: 0
    property string ramText: "0.0G"
    property int tempC: 0

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: sysProc.running = true
    }

    Process {
        id: sysProc
        command: [
            "sh", "-c",
            "cpu=$(awk '/^cpu /{u=$2+$4; t=$2+$4+$5; if (NR==1){print int(u*100/t)}}' /proc/stat 2>/dev/null); " +
            "read -r mem_tot mem_avail <<< $(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print t, a}' /proc/meminfo 2>/dev/null); " +
            "ram_pct=$(( (mem_tot - mem_avail) * 100 / mem_tot )); " +
            "ram_gb=$(awk -v u=$((mem_tot - mem_avail)) 'BEGIN{printf \"%.1fG\", u/1048576}'); " +
            "tmp=$(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | sort -nr | head -n1); " +
            "tmp_c=$(( ${tmp:-0} / 1000 )); " +
            "printf '%s\\n%s\\n%s\\n%s\\n' \"$cpu\" \"$ram_pct\" \"$ram_gb\" \"$tmp_c\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                root.cpuPct = parseInt(lines[0] || "0", 10) || 0
                root.ramPct = parseInt(lines[1] || "0", 10) || 0
                root.ramText = (lines[2] || "0.0G").trim()
                root.tempC = parseInt(lines[3] || "0", 10) || 0
            }
        }
    }

    PanelWindow {
        anchors {
            bottom: true
            left: true
        }
        margins {
            bottom: 28
            left: 28
        }
        implicitWidth: 230
        implicitHeight: col.implicitHeight + 24
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
                spacing: 8

                // CPU
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "  CPU"; font.family: Theme.fontFamily; font.pixelSize: 12; color: "#e6ffffff"; style: Text.Outline; styleColor: "#aa000000"; Layout.fillWidth: true }
                        Text { text: root.cpuPct + "%"; font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true; color: "#ffffff"; style: Text.Outline; styleColor: "#aa000000" }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 5; radius: 3; color: "#55000000"
                        Rectangle { width: parent.width * (Math.min(100, root.cpuPct) / 100); height: parent.height; radius: 3; color: Theme.accent }
                    }
                }

                // RAM
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "  RAM"; font.family: Theme.fontFamily; font.pixelSize: 12; color: "#e6ffffff"; style: Text.Outline; styleColor: "#aa000000"; Layout.fillWidth: true }
                        Text { text: root.ramText + " (" + root.ramPct + "%)"; font.family: Theme.fontFamily; font.pixelSize: 12; font.bold: true; color: "#ffffff"; style: Text.Outline; styleColor: "#aa000000" }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 5; radius: 3; color: "#55000000"
                        Rectangle { width: parent.width * (Math.min(100, root.ramPct) / 100); height: parent.height; radius: 3; color: Theme.tertiary }
                    }
                }

                // Temp
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "  Temp"; font.family: Theme.fontFamily; font.pixelSize: 12; color: "#e6ffffff"; style: Text.Outline; styleColor: "#aa000000"; Layout.fillWidth: true }
                    Text {
                        text: root.tempC + "°C"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: root.tempC >= 80 ? Theme.error : "#ffffff"
                        style: Text.Outline
                        styleColor: "#aa000000"
                    }
                }
            }
        }
    }
}
