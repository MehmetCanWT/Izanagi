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
    readonly property string thumbDir: Quickshell.env("HOME") + "/.cache/cliphist-thumbs"

    onOpenChanged: {
        if (!open) {
            query = ""
            allItems = []
            filteredItems = []
            Qt.callLater(gc)
        }
    }

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
        actionProc.command = ["sh", "-c", "cliphist wipe && rm -rf \"$HOME/.cache/cliphist-thumbs\"/*"]
        actionProc.running = true
        root.allItems = []
        root.filteredItems = []
    }

    Process {
        id: listProc
        command: [
            "sh", "-c",
            "td=\"${XDG_CACHE_HOME:-$HOME/.cache}/cliphist-thumbs\"; " +
            "mkdir -p \"$td\"; " +
            "find \"$td\" -type f -mtime +7 -delete 2>/dev/null || true; " +
            "cliphist list 2>/dev/null | head -n 80 | while IFS=$(printf '\\t') read -r id txt; do " +
            "  case \"$txt\" in " +
            "    '[[ binary data '*) " +
            "      th=\"$td/${id}.img\"; " +
            "      [ -s \"$th\" ] || cliphist decode \"$id\" > \"$th\" 2>/dev/null || true; " +
            "      printf '%s\\t1\\t%s\\n' \"$id\" \"$txt\" ;; " +
            "    *) " +
            "      printf '%s\\t0\\t%s\\n' \"$id\" \"$txt\" ;; " +
            "  esac; " +
            "done"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                const items = []
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i]
                    if (!line.trim()) continue
                    const parts = line.split("\t")
                    if (parts.length < 3) continue
                    const id = parts[0]
                    const isImage = parts[1] === "1"
                    const raw = parts.slice(2).join("\t").trim()
                    const preview = isImage
                        ? raw.replace(/^\[\[\s*binary data\s*/, "Image (").replace(/\s*\]\]$/, ")")
                        : raw
                    items.push({
                        id,
                        isImage,
                        thumbPath: isImage ? (root.thumbDir + "/" + id + ".img") : "",
                        preview
                    })
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
            height: 460
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
                    spacing: 5
                    model: root.filteredItems
                    highlightMoveDuration: 80
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool isCurrent: index === clipList.currentIndex

                        width: clipList.width
                        height: modelData.isImage ? 72 : 40
                        radius: 8
                        color: isCurrent ? Theme.primaryContainer : Theme.surfaceContainer
                        border.width: isCurrent ? 1 : 0
                        border.color: Theme.accent

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 12
                            }
                            spacing: 10

                            Rectangle {
                                visible: modelData.isImage
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 56
                                radius: 6
                                color: Theme.surfaceContainerHigh
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: modelData.isImage ? ("file://" + modelData.thumbPath) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                    sourceSize: Qt.size(200, 112)
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.preview
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: "#ffffff"
                                elide: Text.ElideRight
                            }
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
