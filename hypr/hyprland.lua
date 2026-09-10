-- ScorchedBlue Hyprland configuration.
--
-- Hyprland 0.56 configures in Lua, not the older hyprland.conf format. Almost
-- every config and tutorial online is still the old format, so prefer the wiki
-- over community dotfiles when extending this: https://wiki.hypr.land
--
-- This replaces the config Hyprland autogenerates on first launch. That default
-- binds SUPER+Q to kitty and SUPER+E to dolphin, neither of which ScorchedBlue
-- ships, so a fresh user's first two keystrokes do nothing.

------------------
---- PROGRAMS ----
------------------

-- Only programs the image actually ships. Anything added here must be in
-- scorchedblue' package list, or the binding silently fails.
local terminal = "ghostty"
local lock = "swaylock -f"

local mainMod = "SUPER"

-----------------
---- MONITOR ----
-----------------

-- Detect the best mode; never hardcode one.
--
-- `output = ""` is the wildcard, so this applies to every monitor on every
-- machine. Nothing here names a specific display, resolution or rate.
--
-- "preferred" is the obvious choice and the wrong one. A monitor's *preferred*
-- mode is whatever its EDID advertises first, and that is routinely not its
-- best: a panel capable of 144Hz commonly advertises 60Hz as preferred, so
-- "preferred" quietly runs good hardware at half speed forever.
--
-- "highres" rather than "highrr": highres takes the highest resolution, then
-- the highest refresh rate available at it. highrr takes the highest refresh
-- rate first, which on a display offering 1080p240 and 4K120 would drop it to
-- 1080p to win the Hz. Resolution first is the right trade on a desktop.
--
-- This is only the starting mode. The display panel in the Quickshell shell
-- overrides it per monitor at runtime, and offers "Auto" to come back to it.
hl.monitor({
    output = "",
    mode = "highres",
    position = "auto",
    scale = "auto",
})

-- HDR, for HDR content, on displays that can do it.
--
-- This is a global render setting rather than a monitor rule, and that is the
-- whole reason it is usable here. `cm = "hdr"` on the wildcard above would
-- force the HDR PQ transfer function onto *every* display including ones that
-- cannot do it, which is washed-out SDR on a panel that never asked for it.
-- Gating that per display would mean naming a monitor, and nothing in this file
-- names a monitor. cm_auto_hdr names none: it engages for HDR content and
-- leaves everything else alone, so a non-HDR display is unaffected by
-- construction rather than by configuration.
--
-- The desktop therefore stays SDR. That is the intended reading of "displays
-- that support HDR get it by default" -- HDR when there is HDR to show, not an
-- HDR desktop with SDR content tone-mapped into it all day.
--
-- 1, not 2. Value 2 is `hdredid`, which takes primaries from the display's
-- EDID; upstream calls that source "known to be inaccurate". BT2020 primaries
-- are predictable. Change this only with a real side-by-side recorded, not on
-- spec-reading.
--
-- Note what this does NOT do: it changes no mode. The `highres` choice above
-- keeps the highest resolution and the best rate at it, and HDR never costs a
-- refresh rate here.
--
-- Two traps, both checked against 0.56.2 rather than assumed:
--   * Do not also set `cm = "wide"` on the monitor rule. cm_auto_hdr misbehaves
--     in that combination -- hyprwm/Hyprland#12971 and #12958.
--   * `cm_fs_passthrough` does not exist in this version. Wiki and forum advice
--     pairs it with cm_auto_hdr; it is for a different release and Hyprland
--     rejects the whole config on an unknown key.
hl.config({
    render = {
        cm_enabled = true,
        cm_auto_hdr = 1,
    },
})

-------------------
---- AUTOSTART ----
-------------------

-- Everything here must be started from the "hyprland.start" event, not at the
-- top level. hl.exec_cmd() runs the moment the config is parsed, which is
-- before the backend is up and before WAYLAND_DISPLAY is even set -- so a
-- top-level exec_cmd hands the child an empty WAYLAND_DISPLAY and a socket
-- that refuses connections. Wayland clients die there: Quickshell gets
-- "Failed to create wl_display (Connection refused)", falls through to the
-- xcb plugin, finds no X display, and Qt calls qFatal(). Silent SIGABRT, no
-- bar. "hyprland.start" fires once the compositor is listening.
hl.on("hyprland.start", function()
    -- First, before anything that might want a portal.
    --
    -- xdg-desktop-portal.service has Requisite=graphical-session.target, and
    -- that target sets RefuseManualStart=yes -- it is only ever reachable as a
    -- dependency. gnome-session brought it up; Hyprland does not. Without this
    -- every portal request fails with "Could not activate remote peer
    -- 'org.freedesktop.portal.Desktop': startup job failed", which takes screen
    -- sharing with it -- the capability the pivot to Hyprland was for.
    --
    -- Nothing reports this until something asks for a portal, so the session
    -- looks completely healthy while the one feature it exists for is dead.
    --
    -- The target itself ships in the image, not here: it is session plumbing,
    -- the job upstream expects uwsm to do. uwsm is packaged neither in Fedora
    -- nor in the Hyprland COPR, so the hyprland-uwsm.desktop session the RPM
    -- ships cannot run at all.
    hl.exec_cmd("systemctl --user start hyprland-session.target")

    -- The shell. Started from here rather than a systemd user unit so it inherits
    -- HYPRLAND_INSTANCE_SIGNATURE from the session -- without it Quickshell loads
    -- and renders, but its Hyprland IPC never connects, so workspaces silently
    -- stay empty.
    --
    -- It now provides the launcher and the notification server too, so fuzzel
    -- and mako are both gone. mako in particular MUST NOT come back: only one
    -- process can own the D-Bus name org.freedesktop.Notifications, so with
    -- both running whichever wins it takes every notification and the other
    -- silently receives nothing at all.
    hl.exec_cmd("quickshell -d")

    hl.exec_cmd("lxpolkit")
    hl.exec_cmd("swaybg -m fill -i /usr/share/hypr/wall0.png")

    -- Idle is deliberately NOT started here. The shell owns swayidle, because a
    -- thing you can switch off has to be owned by something still running when
    -- it is off -- started from here, the only way to stop locking was to kill a
    -- process by hand. See Idle.qml.
end)

-----------------
---- ENVIRON ----
-----------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Electron and Chromium default to X11 under XWayland unless told otherwise.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

----------------
---- LOOK -----
----------------

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        -- dwindle, deliberately: the scrolling and master layouts were both
        -- considered and rejected. This is the layout the pivot was for.
        layout = "dwindle",
        resize_on_border = true,
    },
})

hl.config({
    decoration = {
        rounding = 6,
        blur = {
            enabled = true,
            size = 4,
            passes = 2,
        },
    },
})

hl.config({
    dwindle = {
        -- preserve_split only. `pseudotile` is a valid key in the old
        -- hyprland.conf format but not in the Lua config, and Hyprland rejects
        -- the whole file with "unknown config key". Pseudotiling is still
        -- reachable -- it is bound to SUPER+P below via hl.dsp.window.pseudo().
        preserve_split = true,
    },
})

-- Hyprland's update-news and donation popups are rendered by hyprland-qtutils,
-- which is packaged neither in Fedora nor in the Hyprland COPR this image
-- builds from -- so both default to on and both fail, complaining that
-- hyprland-qtutils is not installed.
--
-- They are the wrong idea here regardless of packaging: this is a bootc image
-- that updates as a whole, so a compositor telling the user about its own new
-- release has nothing useful to offer them.
hl.config({
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
        },
    },
})

--------------------
---- KEYBINDING ----
--------------------

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))

-- The launcher lives inside the shell process, so a keybind cannot create it
-- directly -- it asks the running shell over IPC instead. SUPER+D is kept as an
-- alias for the muscle memory it replaces.
local launcher = "quickshell ipc call launcher toggle"
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(launcher))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(launcher))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(lock))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + M", hl.dsp.exit())

-- Bar popouts, opened without a mouse. Same IPC trick as the launcher above:
-- these live inside the Quickshell process, so a keybind cannot open one
-- directly. Once a popout is open, Down/Up move its keyboard cursor,
-- Enter/Space activates whatever it is on, Left/Right adjust a volume slider,
-- and Escape closes it -- see quickshell/Popouts.qml and quickshell/Bar.qml.
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("quickshell ipc call popout toggleNet"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("quickshell ipc call popout toggleTs"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("quickshell ipc call popout toggleBt"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("quickshell ipc call popout toggleAudio"))
hl.bind(mainMod .. " + SHIFT + O", hl.dsp.exec_cmd("quickshell ipc call popout toggleDisplay"))
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.exec_cmd("quickshell ipc call popout toggleAi"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("quickshell ipc call popout toggleSys"))
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd("quickshell ipc call popout toggleNotifs"))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.exec_cmd("quickshell ipc call popout toggleCalendar"))
hl.bind(mainMod .. " + SHIFT + X", hl.dsp.exec_cmd("quickshell ipc call popout togglePower"))

-- Screenshot a region. grim and slurp are both shipped; this is the closest
-- thing to the region capture the GNOME session could not do.
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))

-- Media and hardware keys.
--
-- `repeating = true` is what makes holding a volume key keep changing the
-- volume. The option is spelled neither `repeat` (a Lua keyword) nor any of the
-- obvious alternatives, and Hyprland accepts an unknown option key silently --
-- `hl.bind` returns ok either way -- so a wrong name here fails invisibly.
-- `hyprctl binds -j` reports the resulting `repeat` field, which is the only
-- way to tell that it took.
--
-- wpctl rather than pactl for volume: `-l 1.0` caps the raise at 100%, and
-- pactl has no equivalent, so a held key would happily push output past unity
-- and into distortion.
local repeating = { repeating = true }

hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"),
    repeating
)
hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    repeating
)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))

-- Brightness is bound even though this desktop has no backlight device: the
-- image is not desktop-only, brightnessctl ships, and a laptop running it
-- should not need a config change to dim its screen. On hardware without a
-- backlight the command simply finds nothing to set.
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"), repeating)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), repeating)

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"))

-- No GUI calculator ships, so this does not bind one. `bc -l` in a terminal
-- window uses two things the image actually has, which beats a key that does
-- nothing. Built from `terminal` rather than naming the binary again, so this
-- cannot be left behind the next time the terminal changes.
hl.bind("XF86Calculator", hl.dsp.exec_cmd(terminal .. " -e bc -l"))

-- Focus
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Workspaces. 10 maps to key 0, matching the template's convention.
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("scratch"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratch" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

--------------------
---- WINDOW RULE ----
--------------------

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
    },
    no_focus = true,
})
