import Quickshell

ShellRoot {
    Bar { id: bar }
    WallpaperPicker {}
    Notifications {}
    Launcher {}
    WifiMenu { onChanged: bar.refreshStats() }
    BluetoothMenu { onChanged: bar.refreshStats() }
    AudioMenu { onChanged: bar.refreshStats() }
    BrightnessMenu { onChanged: bar.refreshStats() }
    Osd {}
    CalendarMediaMenu {}
}
