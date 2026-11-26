import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

Scope {
    id: root
    property bool locked: false
    property string password: ""
    property string errorText: ""
    property bool authenticating: false
    property string wallpaperPath: ""

    IpcHandler {
        target: "lock"
        function lock(): void {
            if (!root.locked) {
                root.password = ""
                root.errorText = ""
                root.authenticating = false
                wpFile.reload()
                root.locked = true
            }
        }
    }

    FileView {
        id: wpFile
        path: Quickshell.env("HOME") + "/.config/hypr/hyprpaper.conf"
        onLoaded: {
            const m = text().match(/^\s*path\s*=\s*(.+)$/m)
            if (m) {
                let p = m[1].trim()
                if (p.startsWith("~/")) p = Quickshell.env("HOME") + p.slice(1)
                root.wallpaperPath = p
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PamContext {
        id: pam
        config: "system-auth"
        user: Quickshell.env("USER")
        onPamMessage: {
            if (responseRequired) {
                respond(root.password)
            }
        }
        onCompleted: (result) => {
            root.authenticating = false
            if (result === PamResult.Success) {
                root.locked = false
                root.password = ""
                root.errorText = ""
            } else {
                root.password = ""
                root.errorText = "Authentication failed"
            }
        }
        onError: {
            root.authenticating = false
            root.password = ""
            root.errorText = "PAM error"
        }
    }

    function submit() {
        if (root.authenticating || root.password.length === 0) return
        root.errorText = ""
        root.authenticating = true
        pam.start()
    }

    WlSessionLock {
        id: sessionLock
        locked: root.locked

        WlSessionLockSurface {
            color: "#0b0b12"

            Image {
                id: bgImg
                anchors.fill: parent
                source: root.wallpaperPath ? ("file://" + root.wallpaperPath) : ""
                fillMode: Image.PreserveAspectCrop
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                visible: root.wallpaperPath.length > 0
                source: bgImg
                blurEnabled: true
                blur: 0.75
                blurMax: 48
            }

            Rectangle {
                anchors.fill: parent
                color: "#770b0b12"
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    font.family: Theme.fontFamily
                    font.pixelSize: 78
                    font.bold: true
                    color: "#ffffff"
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "dddd, dd MMMM yyyy")
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    color: Theme.accent
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    text: Quickshell.env("USER")
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.textDim
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 270
                    height: 44
                    radius: 12
                    color: Theme.bg
                    border.width: 2
                    border.color: root.errorText.length > 0 ? Theme.error : Theme.accent

                    TextInput {
                        id: passField
                        anchors {
                            fill: parent
                            leftMargin: 14
                            rightMargin: 14
                        }
                        verticalAlignment: TextInput.AlignVCenter
                        horizontalAlignment: TextInput.AlignHCenter
                        echoMode: TextInput.Password
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        color: "#ffffff"
                        focus: root.locked
                        enabled: !root.authenticating
                        text: root.password
                        onTextChanged: root.password = text
                        Keys.onReturnPressed: root.submit()
                        Keys.onEnterPressed: root.submit()

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: root.authenticating ? "Checking..." : "Password..."
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textDim
                            visible: passField.text.length === 0
                        }
                    }
                }

                Text {
                    visible: root.errorText.length > 0
                    Layout.alignment: Qt.AlignHCenter
                    text: root.errorText
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    color: Theme.error
                }
            }
        }
    }
}
