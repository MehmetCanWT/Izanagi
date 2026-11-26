import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false
    property string icon: "󰕾"
    property string label: "Volume"
    property int value: 0
    property bool muted: false

    IpcHandler {
        target: "osd"
        function showVolume(): void {
            volProc.running = true
        }
        function showBrightness(): void {
            brightProc.running = true
        }
    }

    function trigger(ic, lbl, val, isMuted) {
        root.icon = ic
        root.label = lbl
        root.value = Math.max(0, Math.min(100, val))
        root.muted = isMuted
        root.open = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.open = false
    }

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim()
                const muted = s.indexOf("[MUTED]") !== -1
                const m = s.match(/Volume:\s*([0-9.]+)/)
                const pct = m ? Math.round(parseFloat(m[1]) * 100) : 0
                root.trigger(muted ? "󰖁" : "󰕾", "Volume", pct, muted)
            }
        }
    }

    Process {
        id: brightProc
        command: ["sh", "-c", "brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const b = parseInt(this.text.trim(), 10)
                if (!isNaN(b)) root.trigger("󰃠", "Brightness", b, false)
            }
        }
    }

    PanelWindow {
        visible: root.open
        anchors {
            bottom: true
        }
        margins {
            bottom: 56
        }
        implicitWidth: 260
        implicitHeight: 54
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusiveZone: -1

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 14
                    rightMargin: 14
                }
                spacing: 12

                Text {
                    text: root.icon
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    color: root.muted ? Theme.error : Theme.accent
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: root.label
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textDim
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.muted ? "Muted" : (root.value + "%")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: "#ffffff"
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Theme.surfaceContainerHigh

                        Rectangle {
                            width: Math.max(0, Math.min(parent.width, parent.width * (root.value / 100)))
                            height: parent.height
                            radius: 3
                            color: root.muted ? Theme.error : Theme.accent
                        }
                    }
                }
            }
        }
    }
}
