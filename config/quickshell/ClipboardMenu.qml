import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false
    property string query: ""
    property var allItems: []
    property var filteredItems: []

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            if (!root.open) {
                root.query = ""
                searchInput.text = ""
                root.refresh()
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

    function refresh() {
        listProc.running = true
    }

    function applyFilter() {
        const q = query.trim().toLowerCase()
        if (q === "") {
            filteredItems = allItems
        } else {
            filteredItems = allItems.filter(it => it.preview.toLowerCase().includes(q))
        }
        if (clipList.currentIndex >= filteredItems.length) {
            clipList.currentIndex = Math.max(0, filteredItems.length - 1)
        }
    }

    function copyItem(id) {
        if (!id) return
        actionProc.command = ["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", id]
        actionProc.running = true
        root.open = false
    }

    function wipeAll() {
        actionProc.command = ["cliphist", "wipe"]
        actionProc.running = true
        root.allItems = []
        root.filteredItems = []
    }

    Process {
        id: listProc
        command: ["sh", "-c", "cliphist list 2>/dev/null | head -n 80"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                const items = []
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i]
                    if (!line.trim()) continue
                    const tab = line.indexOf("\t")
                    if (tab === -1) continue
                    const id = line.slice(0, tab)
                    const preview = line.slice(tab + 1).trim()
                    items.push({ id, preview })
                }
                root.allItems = items
                root.applyFilter()
                if (items.length > 0) clipList.currentIndex = 0
            }
        }
    }

    Process {
        id: actionProc
    }

    PanelWindow {
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
                spacing: 10

                // Header + Search + Wipe
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 38
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
                            spacing: 8

                            Text {
                                text: "󰅌"
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                color: Theme.accent
                            }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: "#ffffff"
                                clip: true
                                focus: root.open
                                onTextChanged: {
                                    root.query = text
                                    root.applyFilter()
                                }

                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_Escape) {
                                        root.open = false
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                        if (root.filteredItems.length > 0)
                                            clipList.currentIndex = (clipList.currentIndex + 1) % root.filteredItems.length
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                                        if (root.filteredItems.length > 0)
                                            clipList.currentIndex = (clipList.currentIndex - 1 + root.filteredItems.length) % root.filteredItems.length
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (root.filteredItems.length > 0 && clipList.currentIndex >= 0)
                                            root.copyItem(root.filteredItems[clipList.currentIndex].id)
                                        event.accepted = true
                                    }
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Search clipboard..."
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    color: Theme.textDim
                                    visible: !searchInput.text
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 60
                        height: 38
                        radius: 10
                        color: Theme.surfaceContainerHigh
                        Text {
                            anchors.centerIn: parent
                            text: "Clear"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: Theme.error
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.wipeAll()
                        }
                    }
                }

                // Clipboard list
                ListView {
                    id: clipList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: root.filteredItems
                    highlightMoveDuration: 80
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool isCurrent: index === clipList.currentIndex

                        width: clipList.width
                        height: 40
                        radius: 8
                        color: isCurrent ? Theme.primaryContainer : Theme.surfaceContainer
                        border.width: isCurrent ? 1 : 0
                        border.color: Theme.accent

                        Text {
                            anchors {
                                fill: parent
                                leftMargin: 12
                                rightMargin: 12
                            }
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.preview
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            color: "#ffffff"
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: clipList.currentIndex = index
                            onClicked: root.copyItem(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
