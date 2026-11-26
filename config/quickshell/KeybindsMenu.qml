import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property bool open: false
    property string query: ""
    property var allBinds: []
    property var filteredBinds: []

    onOpenChanged: {
        if (!open) {
            query = ""
            allBinds = []
            filteredBinds = []
            Qt.callLater(gc)
        }
    }

    IpcHandler {
        target: "keybinds"
        function toggle(): void {
            if (!root.open) {
                root.query = ""
                searchInput.text = ""
                root.loadBinds()
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

    function loadBinds() {
        bindsFile.reload()
    }

    function parseLua(src) {
        const items = [
            { keys: "SUPER + 1..0", desc: "Switch to workspace 1-10" },
            { keys: "SUPER + SHIFT + 1..0", desc: "Move window to workspace 1-10" },
            { keys: "SUPER + Mouse Drag", desc: "Move / Resize floating or tiled window" }
        ]
        const lines = src.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (!line.startsWith("hl.bind(")) continue
            const m = line.match(/^hl\.bind\(([^,]+),\s*(.+)\)$/)
            if (!m) continue
            let rawKey = m[1].trim()
                .replace(/mainMod\s*\.\.\s*"/g, '"SUPER')
                .replace(/"/g, "")
                .replace(/\s+/g, " ")
            let rawAct = m[2].trim()
                .replace(/,\s*\{[^}]*\}\s*$/, "")
                .replace(/^hl\.dsp\.exec_cmd\((.*)\)$/, "$1")
                .replace(/^hl\.dsp\./, "")
                .replace(/hl\.plugin\.hyprcapture\./, "hyprcapture: ")
                .replace(/["']/g, "")

            if (rawAct === "launcher") rawAct = "Open App Launcher"
            else if (rawAct === "terminal") rawAct = "Open Ghostty Terminal"
            else if (rawAct === "fileManager") rawAct = "Open Dolphin File Manager"
            else if (rawAct === "browser") rawAct = "Open Zen Browser"
            else if (rawAct === "wallpaper") rawAct = "Open Wallpaper Picker"
            else if (rawAct.includes("clipboard toggle")) rawAct = "Open Clipboard History"
            else if (rawAct.includes("keybinds toggle")) rawAct = "Show Keybinds Menu"
            else if (rawAct.includes("smart-close.sh")) rawAct = "Close Active Overlay or Window"
            else if (rawAct.includes("show-desktop.sh")) rawAct = "Toggle Show Desktop"

            items.push({ keys: rawKey, desc: rawAct })
        }
        root.allBinds = items
        root.applyFilter()
    }

    function applyFilter() {
        const q = query.trim().toLowerCase()
        if (q === "") {
            filteredBinds = allBinds
        } else {
            filteredBinds = allBinds.filter(b =>
                b.keys.toLowerCase().includes(q) || b.desc.toLowerCase().includes(q)
            )
        }
    }

    FileView {
        id: bindsFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/keybinds.lua"
        onLoaded: root.parseLua(text())
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
            width: Math.min(parent.width - 48, 640)
            height: 480
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

                // Search bar
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
                            text: "󰌌"
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
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
                            Keys.onEscapePressed: root.open = false

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Search keybinds..."
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                color: Theme.textDim
                                visible: !searchInput.text
                            }
                        }
                    }
                }

                // Keybinds list
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: root.filteredBinds
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 36
                        radius: 8
                        color: Theme.surfaceContainer

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 12
                            }
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: keyText.implicitWidth + 16
                                Layout.preferredHeight: 24
                                radius: 6
                                color: Theme.primaryContainer
                                border.width: 1
                                border.color: Theme.accent

                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: modelData.keys
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#ffffff"
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.desc
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: "#ffffff"
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
