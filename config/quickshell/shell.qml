//@ pragma UseQApplication
import Quickshell

ShellRoot {
    Bar {
        id: bar
        dndOn: notif.dnd
        notifCount: notif.history.length
    }
    WallpaperPicker {}
    Notifications { id: notif }
    Launcher {}
    WifiMenu { onChanged: bar.refreshStats() }
    BluetoothMenu { onChanged: bar.refreshStats() }
    AudioMenu { onChanged: bar.refreshStats() }
    BrightnessMenu { onChanged: bar.refreshStats() }
    Osd {}
    CalendarMediaMenu {}
    BatteryMenu { onChanged: bar.refreshStats() }
    ClipboardMenu {}
    KeybindsMenu {}
    DesktopClock {}
    DesktopMusic {}
    DesktopSysMon {}
    DesktopPhone {}
    PowerMenu {}
    WindowSwitcher {}
    LockScreen {}
}
