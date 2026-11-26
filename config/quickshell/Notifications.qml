import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: root

    NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: true
        onNotification: (n) => {
            n.tracked = true
        }
    }

    PanelWindow {
        visible: server.trackedNotifications.values.length > 0
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
}
