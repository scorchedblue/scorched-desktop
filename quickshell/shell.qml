// ScorchedBlue shell -- entry point.
//
// Quickshell discovers this as the "default" config at
// ~/.config/quickshell/shell.qml. Its QML modules are compiled into the
// quickshell binary rather than installed into Qt's qml directory, so there is
// nothing to add to QML2_IMPORT_PATH -- the absence of
// /usr/lib64/qt6/qml/Quickshell is expected.
//
// Layout:
//   Theme.qml      every colour and dimension, in one place
//   Icon.qml       vector icons, because the image ships no Nerd Font
//   Bar.qml        the bar and its popout
//   Net/Bt/Audio/Displays.qml    state, polled from the system tools
//   *Panel.qml     what each popout shows
//
// One Bar per screen. Variants builds a delegate per entry in the model, which
// is how a layer-shell config covers monitors that appear after startup rather
// than only those present when it began.

import Quickshell
import Quickshell.Io

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Bar {}
    }

    // Toasts, one layer per screen.
    Variants {
        model: Quickshell.screens

        delegate: ToastLayer {}
    }

    // One launcher for the whole session, on the primary output.
    Launcher {
        id: launcher
    }

    // Idle has to be referenced here or it never exists.
    //
    // QML singletons are constructed on first access. Every other service is
    // reached by a bar indicator that is always on screen; Idle is only used by
    // the Session panel, which lives inside a Loader that does not exist until
    // that popout is opened. So swayidle never started and the screen never
    // blanked until someone happened to click the power button.
    //
    // This is a property *binding*, not a statement in Component.onCompleted --
    // a bare `void Idle.blankEnabled;` there is optimised away and constructs
    // nothing. A binding has to be evaluated, so the singleton has to be built.
    readonly property bool idleRunning: Idle.blankEnabled || Idle.lockEnabled

    // SUPER+Space reaches the launcher through here. A compositor keybind
    // cannot create a window inside this process, so Hyprland runs
    // `quickshell ipc call launcher toggle` and this turns that into a call.
    IpcHandler {
        target: "launcher"

        function toggle(): string {
            launcher.toggle();
            return launcher.open ? "opened" : "closed";
        }

        function open(): string {
            launcher.show();
            return "opened";
        }

        function close(): string {
            launcher.hide();
            return "closed";
        }
    }

    // Every bar popout, reachable from a keybind the same way the launcher
    // is. A keybind knows no pixel position and no screen, so these always
    // land on Quickshell.screens[0] -- the same "one instance, the primary
    // output" call the launcher above already makes, not a per-monitor one.
    // A click on the indicator itself still opens the popout on whichever
    // screen was clicked; this is only the keyboard path.
    IpcHandler {
        target: "popout"

        function toggleNet(): string {
            Popouts.toggle("net", 0, Quickshell.screens[0]);
            return Popouts.active;
        }

        function toggleBt(): string {
            Popouts.toggle("bt", 0, Quickshell.screens[0]);
            return Popouts.active;
        }

        function toggleAudio(): string {
            Popouts.toggle("audio", 0, Quickshell.screens[0]);
            return Popouts.active;
        }

        function toggleDisplay(): string {
            Popouts.toggle("display", 0, Quickshell.screens[0]);
            return Popouts.active;
        }

        // The AI indicator hides itself when no provider is configured, but the
        // keybind stays bound: a popout that reports "unavailable" is a better
        // answer than a key that silently does nothing.
        function toggleAi(): string {
            Popouts.toggle("ai", 0, Quickshell.screens[0]);
            return Popouts.active;
        }

        function toggleSys(): string {
            Popouts.toggle("sys", 0, Quickshell.screens[0]);
            return Popouts.active;
        }

        function toggleNotifs(): string {
            Popouts.toggle("notifs", 0, Quickshell.screens[0]);
            return Popouts.active;
        }

        function toggleCalendar(): string {
            Popouts.toggle("calendar", 0, Quickshell.screens[0]);
            return Popouts.active;
        }

        function togglePower(): string {
            Popouts.toggle("power", 0, Quickshell.screens[0]);
            return Popouts.active;
        }
    }
}
