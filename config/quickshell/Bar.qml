import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

PanelWindow {
    id: bar
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: "transparent"

    property bool wifiOn: false
    property bool btOn: false
    property int volPct: 0
    property bool volMuted: false
    property int brightPct: 100
    property int batPct: -1
    property bool batCharging: false

    function refreshStats() {
        statsProc.running = true
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: bar.refreshStats()
    }

    Process {
        id: statsProc
        command: [
            "sh", "-c",
            "wifi=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | head -n1 | cut -d: -f2-); " +
            "bt=$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2; exit}'); " +
            "vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); " +
            "br=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'); " +
            "bat_cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1); " +
            "bat_st=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1); " +
            "printf '%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n' \"$wifi\" \"$bt\" \"$vol\" \"$br\" \"$bat_cap\" \"$bat_st\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                bar.wifiOn = (lines[0] || "").trim().length > 0
                bar.btOn = (lines[1] || "").trim() === "yes"

                const volLine = (lines[2] || "").trim()
                bar.volMuted = volLine.indexOf("[MUTED]") !== -1
                const m = volLine.match(/Volume:\s*([0-9.]+)/)
                if (m) bar.volPct = Math.round(parseFloat(m[1]) * 100)

                const b = parseInt((lines[3] || "").trim(), 10)
                if (!isNaN(b)) bar.brightPct = b

                const bc = parseInt((lines[4] || "").trim(), 10)
                bar.batPct = isNaN(bc) ? -1 : bc
                bar.batCharging = (lines[5] || "").trim() === "Charging"
            }
        }
    }

    Process {
        id: actionProc
        onExited: bar.refreshStats()
    }

    function runAction(cmd) {
        actionProc.command = ["sh", "-c", cmd]
        actionProc.running = true
    }

    Rectangle {
        anchors {
            fill: parent
            topMargin: 4
            leftMargin: 8
            rightMargin: 8
        }
        radius: 10
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        clip: true

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 12
                rightMargin: 12
            }
            spacing: 10

            // Left: Date & Time (clickable -> Calendar & Media) + Open Workspaces
            Rectangle {
                Layout.preferredWidth: clockLabel.implicitWidth + 12
                Layout.preferredHeight: 22
                radius: 6
                color: "transparent"

                Text {
                    id: clockLabel
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    color: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["sh", "-c", "for t in wifi bluetooth audio brightness battery; do qs ipc call $t closeIfOpen >/dev/null 2>&1; done; qs ipc call calendar toggle"])
                }
            }

            Row {
                spacing: 5
                Repeater {
                    model: Hyprland.workspaces
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isActive: Hyprland.focusedWorkspace?.id === modelData.id
                        visible: modelData.id > 0
                        width: 26
                        height: 22
                        radius: 6
                        color: isActive ? Theme.accent : Theme.surfaceAlt

                        Text {
                            anchors.centerIn: parent
                            text: modelData.id
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: isActive
                            color: isActive ? Theme.onPrimary : "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + modelData.id + " })")
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // System Tray Icons (left of controls)
            Row {
                visible: SystemTray.items.values.length > 0
                spacing: 8

                Repeater {
                    model: SystemTray.items
                    delegate: Item {
                        id: trayItem
                        required property var modelData
                        width: 20
                        height: 20

                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: modelData.icon
                            sourceSize: Qt.size(16, 16)
                            smooth: true
                        }

                        QsMenuAnchor {
                            id: trayMenu
                            menu: modelData.menu
                            anchor.window: bar
                            anchor.edges: Edges.Bottom
                            anchor.rect.x: trayItem.mapToItem(null, 0, 0).x
                            anchor.rect.y: trayItem.mapToItem(null, 0, 0).y
                            anchor.rect.width: trayItem.width
                            anchor.rect.height: trayItem.height
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) {
                                    if (modelData.onlyMenu && modelData.hasMenu) trayMenu.open()
                                    else modelData.activate()
                                } else if (mouse.button === Qt.MiddleButton) {
                                    modelData.secondaryActivate()
                                } else if (mouse.button === Qt.RightButton) {
                                    if (modelData.hasMenu) trayMenu.open()
                                }
                            }
                        }
                    }
                }
            }

            // Prominent separator between tray and right controls
            Text {
                visible: SystemTray.items.values.length > 0
                text: "|"
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.bold: true
                color: Theme.accent
            }

            // Right (left-to-right): Volume, Brightness, Wi-Fi, Bluetooth, Battery
            Rectangle {
                Layout.preferredWidth: volLabel.implicitWidth + 16
                Layout.preferredHeight: 22
                radius: 6
                color: Theme.surfaceAlt
                clip: true

                Text {
                    id: volLabel
                    anchors.centerIn: parent
                    text: (bar.volMuted ? "󰖁 " : "󰕾 ") + bar.volPct + "%"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: bar.volMuted ? Theme.error : "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton || mouse.button === Qt.RightButton) {
                            bar.runAction("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                        } else {
                            Quickshell.execDetached(["sh", "-c", "for t in wifi bluetooth brightness calendar battery; do qs ipc call $t closeIfOpen >/dev/null 2>&1; done; qs ipc call audio toggle"])
                        }
                    }
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) bar.runAction("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+")
                        else bar.runAction("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: brightLabel.implicitWidth + 16
                Layout.preferredHeight: 22
                radius: 6
                color: Theme.surfaceAlt
                clip: true

                Text {
                    id: brightLabel
                    anchors.centerIn: parent
                    text: "󰃠 " + bar.brightPct + "%"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["sh", "-c", "for t in wifi bluetooth audio calendar battery; do qs ipc call $t closeIfOpen >/dev/null 2>&1; done; qs ipc call brightness toggle"])
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) bar.runAction("brightnessctl -q set +5%")
                        else bar.runAction("brightnessctl -q set 5%-")
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: wifiLabel.implicitWidth + 16
                Layout.preferredHeight: 22
                radius: 6
                color: Theme.surfaceAlt
                clip: true

                Text {
                    id: wifiLabel
                    anchors.centerIn: parent
                    text: bar.wifiOn ? "󰤨 Wi-Fi" : "󰤭 Off"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: bar.wifiOn ? "#ffffff" : "#a6adc8"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["sh", "-c", "for t in bluetooth audio brightness calendar battery; do qs ipc call $t closeIfOpen >/dev/null 2>&1; done; qs ipc call wifi toggle"])
                }
            }

            Rectangle {
                Layout.preferredWidth: btLabel.implicitWidth + 16
                Layout.preferredHeight: 22
                radius: 6
                color: Theme.surfaceAlt
                clip: true

                Text {
                    id: btLabel
                    anchors.centerIn: parent
                    text: bar.btOn ? "󰂯" : "󰂲"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: bar.btOn ? Theme.accent : "#a6adc8"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["sh", "-c", "for t in wifi audio brightness calendar battery; do qs ipc call $t closeIfOpen >/dev/null 2>&1; done; qs ipc call bluetooth toggle"])
                }
            }

            Rectangle {
                visible: bar.batPct >= 0
                Layout.preferredWidth: batLabel.implicitWidth + 16
                Layout.preferredHeight: 22
                radius: 6
                color: Theme.surfaceAlt
                clip: true

                Text {
                    id: batLabel
                    anchors.centerIn: parent
                    text: (bar.batCharging ? "󰂄 " : (bar.batPct <= 20 ? "󰁺 " : "󰁹 ")) + bar.batPct + "%"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: (!bar.batCharging && bar.batPct <= 20) ? Theme.error : "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["sh", "-c", "for t in wifi bluetooth audio brightness calendar; do qs ipc call $t closeIfOpen >/dev/null 2>&1; done; qs ipc call battery toggle"])
                }
            }
        }
    }
}
