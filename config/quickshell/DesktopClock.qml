import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Scope {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PanelWindow {
        anchors {
            top: true
            left: true
        }
        margins {
            top: 52
            left: 28
        }
        implicitWidth: col.implicitWidth
        implicitHeight: col.implicitHeight
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.exclusiveZone: -1

        ColumnLayout {
            id: col
            spacing: 2

            Text {
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.family: Theme.fontFamily
                font.pixelSize: 64
                font.bold: true
                color: "#ffffff"
                style: Text.Outline
                styleColor: "#66000000"
            }

            RowLayout {
                spacing: 8
                Rectangle {
                    width: 24
                    height: 3
                    radius: 2
                    color: Theme.accent
                }
                Text {
                    text: Qt.formatDateTime(clock.date, "dddd, dd MMMM")
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    color: Theme.accent
                    style: Text.Outline
                    styleColor: "#88000000"
                }
            }
        }
    }
}
