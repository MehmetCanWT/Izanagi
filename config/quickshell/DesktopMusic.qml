import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property string status: ""
    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property real posSec: 0
    property real lenSec: 0

    function fmtTime(sec) {
        if (!sec || sec < 0) return "0:00"
        const s = Math.floor(sec)
        const m = Math.floor(s / 60)
        const r = s % 60
        return m + ":" + (r < 10 ? "0" + r : r)
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: mediaProc.running = true
    }

    function mediaCmd(arg) {
        actProc.command = ["playerctl", arg]
        actProc.running = true
    }

    function seekTo(sec) {
        actProc.command = ["playerctl", "position", String(Math.max(0, Math.floor(sec)))]
        actProc.running = true
    }

    Process {
        id: mediaProc
        command: [
            "sh", "-c",
            "st=$(playerctl status 2>/dev/null || true); " +
            "t=$(playerctl metadata title 2>/dev/null || true); " +
            "a=$(playerctl metadata artist 2>/dev/null || true); " +
            "art=$(playerctl metadata mpris:artUrl 2>/dev/null || true); " +
            "pos=$(playerctl position 2>/dev/null || echo 0); " +
            "len=$(playerctl metadata mpris:length 2>/dev/null || echo 0); " +
            "printf '%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n' \"$st\" \"$t\" \"$a\" \"$art\" \"$pos\" \"$len\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                root.status = (lines[0] || "").trim()
                root.title = (lines[1] || "").trim()
                root.artist = (lines[2] || "").trim()
                root.artUrl = (lines[3] || "").trim()
                root.posSec = parseFloat(lines[4] || "0") || 0
                const lenUs = parseFloat(lines[5] || "0") || 0
                root.lenSec = lenUs > 0 ? (lenUs / 1000000.0) : 0
            }
        }
    }

    Process {
        id: actProc
        onExited: mediaProc.running = true
    }

    PanelWindow {
        visible: root.title.length > 0
        anchors {
            bottom: true
            right: true
        }
        margins {
            bottom: 28
            right: 28
        }
        implicitWidth: 280
        implicitHeight: col.implicitHeight + 24
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.exclusiveZone: -1

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            ColumnLayout {
                id: col
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 12
                }
                spacing: 10

                // Large Square Cover Art
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 256

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: Theme.surfaceContainer
                        visible: root.artUrl.length === 0
                        Text {
                            anchors.centerIn: parent
                            text: "󰎈"
                            font.family: Theme.fontFamily
                            font.pixelSize: 48
                            color: Theme.accent
                        }
                    }

                    Image {
                        id: coverImg
                        anchors.fill: parent
                        source: root.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }

                    Rectangle {
                        id: coverMask
                        anchors.fill: parent
                        radius: 14
                        visible: false
                        layer.enabled: true
                    }

                    MultiEffect {
                        anchors.fill: parent
                        visible: root.artUrl.length > 0
                        source: coverImg
                        maskEnabled: true
                        maskSource: coverMask
                    }
                }

                // Track Info
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.title
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: "#ffffff"
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: root.artist.length > 0
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.artist
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.textDim
                        elide: Text.ElideRight
                    }
                }

                // Timestamp + Seekable Progress Bar
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Item {
                        Layout.fillWidth: true
                        height: 12

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 5
                            radius: 3
                            color: Theme.surfaceContainerHigh

                            Rectangle {
                                readonly property real ratio: root.lenSec > 0 ? Math.min(1, Math.max(0, root.posSec / root.lenSec)) : 0
                                width: parent.width * ratio
                                height: parent.height
                                radius: 3
                                color: Theme.accent
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: (mouse) => {
                                if (root.lenSec > 0) root.seekTo((mouse.x / width) * root.lenSec)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: root.fmtTime(root.posSec)
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.textDim
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.fmtTime(root.lenSec)
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            color: Theme.textDim
                        }
                    }
                }

                // Media Controls
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16

                    Rectangle {
                        width: 34; height: 34; radius: 17
                        color: Theme.surfaceContainerHigh
                        Text { anchors.centerIn: parent; text: "󰒮"; font.family: Theme.fontFamily; font.pixelSize: 14; color: "#ffffff" }
                        MouseArea { anchors.fill: parent; onClicked: root.mediaCmd("previous") }
                    }
                    Rectangle {
                        width: 42; height: 42; radius: 21
                        color: Theme.accent
                        Text {
                            anchors.centerIn: parent
                            text: root.status === "Playing" ? "󰏤" : "󰐊"
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            color: Theme.onPrimary
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.mediaCmd("play-pause") }
                    }
                    Rectangle {
                        width: 34; height: 34; radius: 17
                        color: Theme.surfaceContainerHigh
                        Text { anchors.centerIn: parent; text: "󰒭"; font.family: Theme.fontFamily; font.pixelSize: 14; color: "#ffffff" }
                        MouseArea { anchors.fill: parent; onClicked: root.mediaCmd("next") }
                    }
                }
            }
        }
    }
}
