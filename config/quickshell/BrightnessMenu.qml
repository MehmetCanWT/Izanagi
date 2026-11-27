import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false
    property int brightPct: 100
    property bool nightLightOn: false
    property int nightTemp: 4000
    property bool hasHyprsunset: false
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
        const clamped = Math.max(1, Math.min(100, Math.round(pct)))
        root.brightPct = clamped
        actionProc.command = ["brightnessctl", "-q", "set", clamped + "%"]
        actionProc.running = true
    }

    function setNightLight(enable, temp) {
        const t = temp || root.nightTemp
        root.nightTemp = t
        if (enable) {
            root.nightLightOn = true
            Quickshell.execDetached(["sh", "-c", "pkill -x hyprsunset 2>/dev/null || true; hyprsunset -t " + t + " >/dev/null 2>&1 &"])
        } else {
            root.nightLightOn = false
            Quickshell.execDetached(["pkill", "-x", "hyprsunset"])
        }
    }

    Process {
        id: infoProc
        command: ["sh", "-c", "br=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'); nl=$(pgrep -x hyprsunset >/dev/null && echo 1 || echo 0); hs=$(command -v hyprsunset >/dev/null && echo 1 || echo 0); printf '%s\\n%s\\n%s\\n' \"$br\" \"$nl\" \"$hs\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                const b = parseInt((lines[0] || "").trim(), 10)
                if (!isNaN(b)) root.brightPct = b
                root.nightLightOn = (lines[1] || "").trim() === "1"
                root.hasHyprsunset = (lines[2] || "").trim() === "1"
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

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                }

                // Night Light (hyprsunset)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: root.hasHyprsunset ? ("󰖔  Night Light  " + (root.nightLightOn ? (root.nightTemp + "K") : "Off")) : "󰖔  Night Light (install hyprsunset)"
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: root.hasHyprsunset ? "#ffffff" : Theme.textDim
                    }

                    Rectangle {
                        visible: root.hasHyprsunset
                        Layout.preferredWidth: 54
                        height: 26
                        radius: 8
                        color: root.nightLightOn ? Theme.accent : Theme.surfaceContainer

                        Text {
                            anchors.centerIn: parent
                            text: root.nightLightOn ? "On" : "Off"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: root.nightLightOn ? Theme.onPrimary : "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.setNightLight(!root.nightLightOn, root.nightTemp)
                        }
                    }
                }

                RowLayout {
                    visible: root.hasHyprsunset
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [3000, 4000, 5000]
                        delegate: Rectangle {
                            required property int modelData
                            Layout.fillWidth: true
                            height: 26
                            radius: 8
                            color: (root.nightLightOn && root.nightTemp === modelData) ? Theme.primaryContainer : Theme.surfaceContainer
                            border.width: (root.nightLightOn && root.nightTemp === modelData) ? 1 : 0
                            border.color: Theme.accent

                            Text {
                                anchors.centerIn: parent
                                text: modelData + "K"
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.setNightLight(true, modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
