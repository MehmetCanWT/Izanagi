import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: root
    property bool dnd: false
    property bool historyOpen: false
    property var history: []

    onHistoryOpenChanged: {
        if (!historyOpen) Qt.callLater(gc)
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void {
            root.historyOpen = !root.historyOpen
        }
        function closeIfOpen(): bool {
            if (root.historyOpen) {
                root.historyOpen = false
                return true
            }
            return false
        }
        function toggleDnd(): void {
            root.dnd = !root.dnd
        }
        function clear(): void {
            root.history = []
        }
    }

    NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: true
        onNotification: (n) => {
            const item = {
                appName: n.appName || "Notification",
                summary: n.summary || n.appName || "Notification",
                body: n.body || "",
                time: Qt.formatDateTime(new Date(), "HH:mm")
            }
            const next = [item].concat(root.history)
            if (next.length > 30) next.length = 30
            root.history = next

            if (!root.dnd) {
                n.tracked = true
            }
        }
    }

    // Live popup toasts
    PanelWindow {
        visible: !root.dnd && server.trackedNotifications.values.length > 0
        anchors {
            bottom: true
            right: true
        }
        margins {
            bottom: 14
            right: 14
        }
        implicitWidth: 400
        implicitHeight: col.implicitHeight
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusiveZone: -1

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 10

            Repeater {
                model: server.trackedNotifications
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: contentCol.implicitHeight + 28
                    radius: 14
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.border

                    Timer {
                        interval: 5000
                        running: true
                        onTriggered: modelData.dismiss()
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: modelData.dismiss()
                    }

                    ColumnLayout {
                        id: contentCol
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 14
                        }
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: modelData.summary || modelData.appName || "Notification"
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.bold: true
                                color: "#ffffff"
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.appName || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.accent
                            }
                        }

                        Text {
                            visible: (modelData.body || "").length > 0
                            Layout.fillWidth: true
                            text: modelData.body || ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textDim
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // Notification History & DND Center
    PanelWindow {
        visible: root.historyOpen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.historyOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.historyOpen = false
        }

        Rectangle {
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 42
                rightMargin: 10
            }
            width: 360
            height: Math.min(480, Math.max(150, histCol.implicitHeight + 24))
            radius: 14
            color: Theme.bg
            border.width: 1
            border.color: Theme.border
            focus: root.historyOpen

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            Keys.onEscapePressed: root.historyOpen = false

            ColumnLayout {
                id: histCol
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "󰂚  Notifications (" + root.history.length + ")"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: "#ffffff"
                    }

                    Rectangle {
                        Layout.preferredWidth: dndBtnText.implicitWidth + 14
                        height: 24
                        radius: 6
                        color: root.dnd ? Theme.accent : Theme.surfaceContainer

                        Text {
                            id: dndBtnText
                            anchors.centerIn: parent
                            text: root.dnd ? "󰂛 DND On" : "󰂚 DND"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: root.dnd
                            color: root.dnd ? Theme.onPrimary : "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.dnd = !root.dnd
                        }
                    }

                    Rectangle {
                        visible: root.history.length > 0
                        Layout.preferredWidth: clrBtnText.implicitWidth + 14
                        height: 24
                        radius: 6
                        color: Theme.surfaceContainer

                        Text {
                            id: clrBtnText
                            anchors.centerIn: parent
                            text: "Clear"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: Theme.error
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.history = []
                        }
                    }
                }

                Text {
                    visible: root.history.length === 0
                    Layout.fillWidth: true
                    Layout.topMargin: 18
                    Layout.bottomMargin: 18
                    horizontalAlignment: Text.AlignHCenter
                    text: root.dnd ? "Do Not Disturb is active" : "No notifications yet"
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.textDim
                }

                ListView {
                    visible: root.history.length > 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: Math.min(390, contentHeight)
                    clip: true
                    spacing: 6
                    model: root.history

                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: itemCol.implicitHeight + 16
                        radius: 10
                        color: Theme.surfaceContainer

                        ColumnLayout {
                            id: itemCol
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 8
                            }
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.summary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: "#ffffff"
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: modelData.appName + " · " + modelData.time
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Theme.accent
                                }
                            }

                            Text {
                                visible: modelData.body.length > 0
                                Layout.fillWidth: true
                                text: modelData.body
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.textDim
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
