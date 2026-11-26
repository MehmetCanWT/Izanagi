import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root
    property string status: ""
    property string title: ""
    property string artist: ""
    property string artUrl: ""
    readonly property bool isVideo: /\.(mp4|webm|mkv|mov)(\?.*)?$/i.test(artUrl)
    property real posSec: 0
    property real lenSec: 0

    // Sonata synced lyrics state
    property var lyricsLines: []
    property int activeLyricIndex: -1
    property var visibleLyrics: []

    readonly property string sonataRuntimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    function updateVisibleLyrics() {
        const lines = root.lyricsLines
        if (!lines || lines.length === 0) {
            root.visibleLyrics = []
            return
        }
        const total = lines.length
        const maxRows = 5
        const idx = root.activeLyricIndex >= 0 ? root.activeLyricIndex : 0
        let start = Math.max(0, idx - 2)
        let end = start + maxRows
        if (end > total) {
            end = total
            start = Math.max(0, end - maxRows)
        }
        const out = []
        for (let i = start; i < end; i++) {
            const line = lines[i]
            if (!line || !line.text) continue
            const dist = Math.abs(i - idx)
            out.push({
                idx: i,
                text: line.text,
                isActive: i === idx,
                dist: dist
            })
        }
        root.visibleLyrics = out
    }

    FileView {
        id: lyricsFile
        path: root.sonataRuntimeDir + "/sonata/lyrics.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text())
                if (data && Array.isArray(data.lines) && data.lines.length > 0 && (data.state === "Synced" || data.state === "Plain")) {
                    root.lyricsLines = data.lines
                    if (typeof data.active_index === "number") {
                        root.activeLyricIndex = data.active_index
                    }
                } else {
                    root.lyricsLines = []
                    root.activeLyricIndex = -1
                }
                root.updateVisibleLyrics()
            } catch (e) {
                // Ignore transient write
            }
        }
    }

    FileView {
        id: nowPlayingFile
        path: root.sonataRuntimeDir + "/sonata/now_playing.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text())
                if (data && data.lyrics && typeof data.lyrics.active_index === "number") {
                    if (root.activeLyricIndex !== data.lyrics.active_index) {
                        root.activeLyricIndex = data.lyrics.active_index
                        root.updateVisibleLyrics()
                    }
                }
            } catch (e) {
                // Ignore transient write
            }
        }
    }

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
            "art=$(playerctl metadata sonata:motionArtUrl 2>/dev/null || true); " +
            "[ -n \"$art\" ] || art=$(playerctl metadata mpris:artUrl 2>/dev/null || true); " +
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
        implicitWidth: 300
        implicitHeight: col.implicitHeight + 20
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.exclusiveZone: -1

        Rectangle {
            anchors.fill: parent
            color: "transparent"

            ColumnLayout {
                id: col
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 6
                }
                spacing: 12

                // Max 5-line synced lyrics above the artwork
                Column {
                    visible: root.visibleLyrics.length > 0
                    Layout.fillWidth: true
                    spacing: 5

                    Repeater {
                        model: root.visibleLyrics
                        delegate: Text {
                            required property var modelData
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: modelData.text
                            font.family: Theme.fontFamily
                            font.pixelSize: modelData.isActive ? 13 : 11
                            font.bold: modelData.isActive
                            color: modelData.isActive ? "#ffffff" : "#d9ffffff"
                            style: Text.Outline
                            styleColor: "#bb000000"
                            opacity: modelData.isActive ? 1.0 : (modelData.dist === 1 ? 0.68 : 0.36)
                            scale: modelData.isActive ? 1.04 : 0.96

                            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                // Large Square Cover Art
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 268

                    Item {
                        id: coverVisual
                        anchors.fill: parent

                        Rectangle {
                            anchors.fill: parent
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

                        AnimatedImage {
                            id: coverImg
                            anchors.fill: parent
                            source: !root.isVideo ? root.artUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            playing: root.status === "Playing"
                            visible: root.artUrl.length > 0 && !root.isVideo
                        }

                        MediaPlayer {
                            id: coverPlayer
                            source: root.isVideo ? root.artUrl : ""
                            loops: MediaPlayer.Infinite
                            audioOutput: AudioOutput { muted: true }
                            videoOutput: coverVideo
                            Component.onCompleted: if (root.isVideo && root.status === "Playing") play()
                            onSourceChanged: if (root.isVideo && root.status === "Playing") play()
                        }

                        Connections {
                            target: root
                            function onStatusChanged() {
                                if (!root.isVideo) return
                                if (root.status === "Playing") coverPlayer.play()
                                else coverPlayer.pause()
                            }
                        }

                        VideoOutput {
                            id: coverVideo
                            anchors.fill: parent
                            fillMode: VideoOutput.PreserveAspectCrop
                            visible: root.artUrl.length > 0 && root.isVideo
                        }
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
                        source: coverVisual
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
                        style: Text.Outline
                        styleColor: "#aa000000"
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: root.artist.length > 0
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.artist
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: "#e6ffffff"
                        style: Text.Outline
                        styleColor: "#aa000000"
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
                            color: "#66000000"

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
                            font.pixelSize: 11
                            color: "#e6ffffff"
                            style: Text.Outline
                            styleColor: "#aa000000"
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.fmtTime(root.lenSec)
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            color: "#e6ffffff"
                            style: Text.Outline
                            styleColor: "#aa000000"
                        }
                    }
                }

                // Media Controls
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 18

                    Rectangle {
                        width: 34; height: 34; radius: 17
                        color: "#55000000"
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
                        color: "#55000000"
                        Text { anchors.centerIn: parent; text: "󰒭"; font.family: Theme.fontFamily; font.pixelSize: 14; color: "#ffffff" }
                        MouseArea { anchors.fill: parent; onClicked: root.mediaCmd("next") }
                    }
                }
            }
        }
    }
}
