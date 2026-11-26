import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false
    property date currentDate: new Date()
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaStatus: ""

    IpcHandler {
        target: "calendar"
        function toggle(): void {
            if (!root.open) {
                root.currentDate = new Date()
                root.refreshMedia()
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

    function refreshMedia() {
        mediaProc.running = true
    }

    function mediaCmd(arg) {
        mediaActionProc.command = ["playerctl", "-i", "kdeconnect", arg]
        mediaActionProc.running = true
    }

    Timer {
        interval: 2000
        running: root.open
        repeat: true
        onTriggered: root.refreshMedia()
    }

    Process {
        id: mediaProc
        command: [
            "sh", "-c",
            "st=$(playerctl -i kdeconnect status 2>/dev/null || true); " +
            "t=$(playerctl -i kdeconnect metadata title 2>/dev/null || true); " +
            "a=$(playerctl -i kdeconnect metadata artist 2>/dev/null || true); " +
            "printf '%s\\n%s\\n%s\\n' \"$st\" \"$t\" \"$a\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                root.mediaStatus = (lines[0] || "").trim()
                root.mediaTitle = (lines[1] || "").trim()
                root.mediaArtist = (lines[2] || "").trim()
            }
        }
    }

    Process {
        id: mediaActionProc
        onExited: root.refreshMedia()
    }

    function buildDays(d) {
        const year = d.getFullYear()
        const month = d.getMonth()
        const first = new Date(year, month, 1)
        const offset = (first.getDay() + 6) % 7 // Monday = 0
        const daysInMonth = new Date(year, month + 1, 0).getDate()
        const cells = []
        for (let i = 0; i < offset; i++) cells.push(0)
        for (let day = 1; day <= daysInMonth; day++) cells.push(day)
        return cells
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
                left: parent.left
                topMargin: 42
                leftMargin: 10
            }
            width: 310
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
                spacing: 10

                // Month Header
                Text {
                    text: Qt.formatDateTime(root.currentDate, "MMMM yyyy")
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                    color: "#ffffff"
                }

                // Weekday headers
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    rowSpacing: 4
                    columnSpacing: 4

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                        delegate: Text {
                            required property string modelData
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.textDim
                        }
                    }

                    Repeater {
                        model: root.buildDays(root.currentDate)
                        delegate: Rectangle {
                            required property int modelData
                            readonly property bool isToday: modelData === root.currentDate.getDate()
                            Layout.fillWidth: true
                            height: 28
                            radius: 6
                            color: modelData === 0 ? "transparent" : (isToday ? Theme.accent : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: modelData > 0 ? modelData : ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: isToday
                                color: isToday ? Theme.onPrimary : "#ffffff"
                            }
                        }
                    }
                }

                // MPRIS Media Controls (shown when a player is active)
                Rectangle {
                    visible: root.mediaTitle.length > 0
                    Layout.fillWidth: true
                    height: 68
                    radius: 10
                    color: Theme.surfaceContainer
                    border.width: 1
                    border.color: "#22ffffff"

                    RowLayout {
                        anchors {
                            fill: parent
                            margins: 10
                        }
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: root.mediaTitle
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: "#ffffff"
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: root.mediaArtist.length > 0
                                Layout.fillWidth: true
                                text: root.mediaArtist
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textDim
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            spacing: 6
                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: Theme.surfaceContainerHigh
                                Text { anchors.centerIn: parent; text: "󰒮"; font.family: Theme.fontFamily; color: "#ffffff" }
                                MouseArea { anchors.fill: parent; onClicked: root.mediaCmd("previous") }
                            }
                            Rectangle {
                                width: 28; height: 28; radius: 14
                                color: Theme.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: root.mediaStatus === "Playing" ? "󰏤" : "󰐊"
                                    font.family: Theme.fontFamily
                                    color: Theme.onPrimary
                                }
                                MouseArea { anchors.fill: parent; onClicked: root.mediaCmd("play-pause") }
                            }
                            Rectangle {
                                width: 28; height: 28; radius: 14
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
}
