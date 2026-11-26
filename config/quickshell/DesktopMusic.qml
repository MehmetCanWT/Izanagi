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

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: mediaProc.running = true
    }

    function mediaCmd(arg) {
        actProc.command = ["playerctl", arg]
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
            "printf '%s\\n%s\\n%s\\n%s\\n' \"$st\" \"$t\" \"$a\" \"$art\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                root.status = (lines[0] || "").trim()
                root.title = (lines[1] || "").trim()
                root.artist = (lines[2] || "").trim()
                root.artUrl = (lines[3] || "").trim()
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
        implicitWidth: 340
        implicitHeight: 92
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.exclusiveZone: -1

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            RowLayout {
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 12

                // Cover Art
                Item {
                    Layout.preferredWidth: 68
                    Layout.preferredHeight: 68

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Theme.surfaceContainer
                        visible: root.artUrl.length === 0
                        Text {
                            anchors.centerIn: parent
                            text: "󰎈"
                            font.family: Theme.fontFamily
                            font.pixelSize: 24
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
                        radius: 10
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

                // Track Info + Controls
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: root.title
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.bold: true
                        color: "#ffffff"
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: root.artist.length > 0
                        Layout.fillWidth: true
                        text: root.artist
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        color: Theme.textDim
                        elide: Text.ElideRight
                    }

                    Row {
                        spacing: 8
                        Layout.topMargin: 2

                        Rectangle {
                            width: 26; height: 26; radius: 13
                            color: Theme.surfaceContainerHigh
                            Text { anchors.centerIn: parent; text: "󰒮"; font.family: Theme.fontFamily; color: "#ffffff" }
                            MouseArea { anchors.fill: parent; onClicked: root.mediaCmd("previous") }
                        }
                        Rectangle {
                            width: 26; height: 26; radius: 13
                            color: Theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: root.status === "Playing" ? "󰏤" : "󰐊"
                                font.family: Theme.fontFamily
                                color: Theme.onPrimary
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.mediaCmd("play-pause") }
                        }
                        Rectangle {
                            width: 26; height: 26; radius: 13
                            color: Theme.surfaceContainerHigh
                            Text { anchors.centerIn: parent; text: "󰒭"; font.family: Theme.fontFamily; color: "#ffffff" }
                            MouseArea { anchors.fill: parent; onClicked: root.mediaCmd("next") }
                        }
                    }
                }
            }
        }
    }
}
