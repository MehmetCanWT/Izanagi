import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false
    property string query: ""

    onOpenChanged: {
        if (!open) {
            query = ""
            Qt.callLater(gc)
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (!root.open) {
                root.query = ""
                searchInput.text = ""
                appList.currentIndex = 0
                root.open = true
                searchInput.forceActiveFocus()
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

    function launchSelected() {
        const vals = filteredModel.values
        if (vals.length > 0 && appList.currentIndex >= 0 && appList.currentIndex < vals.length) {
            vals[appList.currentIndex].execute()
            root.open = false
        }
    }

    ScriptModel {
        id: filteredModel
        values: {
            if (!root.open) return []
            const q = root.query.trim().toLowerCase()
            const apps = [...DesktopEntries.applications.values]
            apps.sort((a, b) => a.name.localeCompare(b.name))
            if (q === "") return apps
            return apps.filter(app => {
                const name = (app.name || "").toLowerCase()
                const gen = (app.genericName || "").toLowerCase()
                const comment = (app.comment || "").toLowerCase()
                const id = (app.id || "").toLowerCase()
                return name.includes(q) || gen.includes(q) || comment.includes(q) || id.includes(q)
            })
        }
        onValuesChanged: {
            if (appList.currentIndex >= values.length) {
                appList.currentIndex = Math.max(0, values.length - 1)
            } else if (values.length > 0 && appList.currentIndex < 0) {
                appList.currentIndex = 0
            }
        }
    }

    PanelWindow {
        id: win
        visible: root.open
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "#66000000"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }

        Rectangle {
            id: box
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 580)
            height: 440
            radius: 16
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: 12

                // Search bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 42
                    radius: 10
                    color: Theme.surfaceContainer
                    border.width: 1
                    border.color: Theme.accent

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 12
                        }
                        spacing: 10

                        Text {
                            text: ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: Theme.accent
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: "#ffffff"
                            clip: true
                            focus: root.open
                            onTextChanged: {
                                root.query = text
                                appList.currentIndex = 0
                            }

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Escape) {
                                    root.open = false
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) || event.key === Qt.Key_Tab) {
                                    if (filteredModel.values.length > 0)
                                        appList.currentIndex = (appList.currentIndex + 1) % filteredModel.values.length
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) || event.key === Qt.Key_Backtab) {
                                    if (filteredModel.values.length > 0)
                                        appList.currentIndex = (appList.currentIndex - 1 + filteredModel.values.length) % filteredModel.values.length
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.launchSelected()
                                    event.accepted = true
                                }
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Search applications..."
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                color: Theme.textDim
                                visible: !searchInput.text
                            }
                        }
                    }
                }

                // Applications list
                ListView {
                    id: appList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: filteredModel
                    highlightMoveDuration: 100
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool isCurrent: index === appList.currentIndex

                        width: appList.width
                        height: 46
                        radius: 10
                        color: isCurrent ? Theme.primaryContainer : "transparent"
                        border.width: isCurrent ? 1 : 0
                        border.color: Theme.accent

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 12
                            }
                            spacing: 12

                            Image {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                source: Quickshell.iconPath(modelData.icon, true)
                                sourceSize: Qt.size(26, 26)
                                smooth: true
                                asynchronous: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    font.bold: isCurrent
                                    color: "#ffffff"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: (modelData.genericName || modelData.comment || "").length > 0
                                    Layout.fillWidth: true
                                    text: modelData.genericName || modelData.comment || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    color: Theme.textDim
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: appList.currentIndex = index
                            onClicked: {
                                modelData.execute()
                                root.open = false
                            }
                        }
                    }
                }
            }
        }
    }
}
