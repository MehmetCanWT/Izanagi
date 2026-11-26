import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false
    property int capacity: 0
    property string batStatus: "Unknown"
    property string powerProfile: "balanced"
    property int healthPct: 100
    property string wattStr: ""
    property string limitPath: ""
    property string limitType: "" // "bool" (health_mode / battery_limiter) or "pct" (charge_control_end_threshold)
    property bool limitEnabled: false
    property string statusMsg: ""
    signal changed()

    IpcHandler {
        target: "battery"
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
        infoProc.running = true
    }

    function setProfile(prof) {
        root.powerProfile = prof
        actionProc.command = ["powerprofilesctl", "set", prof]
        actionProc.running = true
    }

    function toggleBatteryLimit() {
        if (!root.limitPath) return
        const nextBool = !root.limitEnabled
        const val = root.limitType === "pct" ? (nextBool ? "80" : "100") : (nextBool ? "1" : "0")
        root.statusMsg = "Applying 80% lock..."
        actionProc.command = ["pkexec", "sh", "-c", "printf '%s\\n' \"$1\" > \"$2\"", "sh", val, root.limitPath]
        actionProc.running = true
    }

    Process {
        id: infoProc
        command: [
            "sh", "-c",
            "bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1); " +
            "cap=$(cat \"$bat/capacity\" 2>/dev/null || echo 0); " +
            "st=$(cat \"$bat/status\" 2>/dev/null || echo Unknown); " +
            "full=$(cat \"$bat/charge_full\" 2>/dev/null || cat \"$bat/energy_full\" 2>/dev/null || echo 0); " +
            "des=$(cat \"$bat/charge_full_design\" 2>/dev/null || cat \"$bat/energy_full_design\" 2>/dev/null || echo 0); " +
            "cur=$(cat \"$bat/current_now\" 2>/dev/null || echo 0); " +
            "volt=$(cat \"$bat/voltage_now\" 2>/dev/null || echo 0); " +
            "pwr=$(cat \"$bat/power_now\" 2>/dev/null || echo 0); " +
            "prof=$(powerprofilesctl get 2>/dev/null || echo balanced); " +
            "lp=''; lt=''; lv=''; " +
            "for p in /sys/devices/platform/acer-wmi/nitro_sense/battery_limiter /sys/bus/wmi/drivers/acer-wmi-battery/health_mode; do " +
            "  if [ -e \"$p\" ]; then lp=\"$p\"; lt=\"bool\"; lv=$(cat \"$p\" 2>/dev/null || echo 0); break; fi; " +
            "done; " +
            "if [ -z \"$lp\" ] && [ -e \"$bat/charge_control_end_threshold\" ]; then " +
            "  lp=\"$bat/charge_control_end_threshold\"; lt=\"pct\"; lv=$(cat \"$lp\" 2>/dev/null || echo 100); " +
            "fi; " +
            "printf '%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n' \"$cap\" \"$st\" \"$full\" \"$des\" \"$cur\" \"$volt\" \"$pwr\" \"$prof\" \"$lp\" \"$lt\" \"$lv\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                root.capacity = parseInt(lines[0] || "0", 10) || 0
                root.batStatus = (lines[1] || "Unknown").trim()
                const full = parseFloat(lines[2] || "0")
                const des = parseFloat(lines[3] || "0")
                if (des > 0 && full > 0) {
                    root.healthPct = Math.min(100, Math.round((full / des) * 100))
                }
                const cur = parseFloat(lines[4] || "0")
                const volt = parseFloat(lines[5] || "0")
                const pwr = parseFloat(lines[6] || "0")
                let watts = 0
                if (pwr > 0) watts = pwr / 1e6
                else if (cur > 0 && volt > 0) watts = (cur * volt) / 1e12
                root.wattStr = watts > 0.1 ? watts.toFixed(1) + "W" : ""

                root.powerProfile = (lines[7] || "balanced").trim()
                root.limitPath = (lines[8] || "").trim()
                root.limitType = (lines[9] || "").trim()
                const lv = (lines[10] || "").trim()
                if (root.limitType === "pct") {
                    root.limitEnabled = (parseInt(lv, 10) || 100) <= 85
                } else if (root.limitType === "bool") {
                    root.limitEnabled = lv === "1"
                } else {
                    root.limitEnabled = false
                }
            }
        }
    }

    Process {
        id: actionProc
        stderr: StdioCollector {
            onStreamFinished: {
                const err = this.text.trim()
                root.statusMsg = err.length > 0 ? err.split("\n")[0] : ""
            }
        }
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

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: (root.batStatus === "Charging" ? "󰂄  " : "󰁹  ") + root.capacity + "%  (" + root.batStatus + ")"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: "#ffffff"
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: root.wattStr.length > 0
                        text: root.wattStr
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.accent
                    }
                }

                // Health info
                Text {
                    text: "Battery Health: " + root.healthPct + "%"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.textDim
                }

                // Performance Profiles
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Power Profile"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textDim
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: [
                                { id: "power-saver", label: "󰌪 Saver" },
                                { id: "balanced", label: "󰾅 Balanced" },
                                { id: "performance", label: "󰓅 Perf" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: root.powerProfile === modelData.id
                                Layout.fillWidth: true
                                height: 32
                                radius: 8
                                color: active ? Theme.primaryContainer : Theme.surfaceContainer
                                border.width: active ? 1 : 0
                                border.color: Theme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: active
                                    color: "#ffffff"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.setProfile(modelData.id)
                                }
                            }
                        }
                    }
                }

                // 80% Battery Lock (Acer Nitro)
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 10
                    color: Theme.surfaceContainer

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: "80% Battery Lock"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: "#ffffff"
                            }
                            Text {
                                text: root.limitPath.length > 0 ? "Acer Nitro charge limit" : "Requires acer-wmi-battery"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: root.limitPath.length > 0 ? Theme.textDim : Theme.error
                            }
                        }

                        Rectangle {
                            enabled: root.limitPath.length > 0
                            width: 46
                            height: 24
                            radius: 12
                            opacity: enabled ? 1.0 : 0.4
                            color: root.limitEnabled ? Theme.accent : Theme.surfaceContainerHigh

                            Text {
                                anchors.centerIn: parent
                                text: root.limitEnabled ? "80%" : "OFF"
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                color: root.limitEnabled ? Theme.onPrimary : "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.limitPath.length > 0
                                onClicked: root.toggleBatteryLimit()
                            }
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
                    elide: Text.ElideRight
                }
            }
        }
    }
}
