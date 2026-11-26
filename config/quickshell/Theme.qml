pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme

    readonly property string fontFamily: "0xProto Nerd Font"
    readonly property int fontSize: 13
    readonly property int barHeight: 34

    // Live Material You 3 palette loaded from colors.json
    property var palette: ({})

    property FileView colorsFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                theme.palette = JSON.parse(text())
            } catch (e) {
                // Keep fallback palette on transient partial write
            }
        }
    }

    function c(key, fallback) {
        return (palette && palette[key]) ? palette[key] : fallback
    }

    // Full Material You 3 tokens
    readonly property color sourceColor: c("source_color", "#89b4fa")
    readonly property color primary: c("primary", "#89b4fa")
    readonly property color onPrimary: c("on_primary", "#11111b")
    readonly property color primaryContainer: c("primary_container", "#313244")
    readonly property color onPrimaryContainer: c("on_primary_container", "#cdd6f4")
    readonly property color secondary: c("secondary", "#b4befe")
    readonly property color onSecondary: c("on_secondary", "#11111b")
    readonly property color secondaryContainer: c("secondary_container", "#313244")
    readonly property color tertiary: c("tertiary", "#cba6f7")
    readonly property color onTertiary: c("on_tertiary", "#11111b")
    readonly property color tertiaryContainer: c("tertiary_container", "#45475a")

    readonly property color background: c("background", "#11111b")
    readonly property color surface: c("surface", "#181825")
    readonly property color surfaceDim: c("surface_dim", "#11111b")
    readonly property color surfaceBright: c("surface_bright", "#313244")
    readonly property color surfaceContainerLowest: c("surface_container_lowest", "#0b0b12")
    readonly property color surfaceContainerLow: c("surface_container_low", "#181825")
    readonly property color surfaceContainer: c("surface_container", "#1e1e2e")
    readonly property color surfaceContainerHigh: c("surface_container_high", "#2a2a3c")
    readonly property color surfaceContainerHighest: c("surface_container_highest", "#313244")

    readonly property color onSurface: c("on_surface", "#cdd6f4")
    readonly property color onSurfaceVariant: c("on_surface_variant", "#a6adc8")
    readonly property color outline: c("outline", "#6c7086")
    readonly property color outlineVariant: c("outline_variant", "#45475a")
    readonly property color error: c("error", "#f38ba8")

    // Semantic aliases used across Bar & WallpaperPicker
    readonly property color bg: Qt.rgba(surfaceContainerLowest.r, surfaceContainerLowest.g, surfaceContainerLowest.b, 0.88)
    readonly property color surfaceAlt: surfaceContainerHigh
    readonly property color text: onSurface
    readonly property color textDim: onSurfaceVariant
    readonly property color accent: primary
    readonly property color accentAlt: tertiary
    readonly property color border: Qt.rgba(primary.r, primary.g, primary.b, 0.38)
}
