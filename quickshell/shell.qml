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
}
