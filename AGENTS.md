# scorched-desktop -- working agreements

The desktop identity for ScorchedBlue: Hyprland configuration and the Quickshell
shell. Reasoning and history live in `scorched-planning`; this states what is
true now.

## Do not reopen

- **Hyprland 0.56 configures in Lua**, not the older `hyprland.conf` format.
  Community dotfiles and most tutorials are still the old format and will not
  work. Prefer https://wiki.hypr.land over copying configs.
- **The shell is written here, not forked.** Reusing an existing Quickshell
  config was considered and rejected.
- **dwindle is the layout.** Scrolling and master were both considered.

- **The session target is started from here, and must be.**
  `hl.on("hyprland.start", …)` runs
  `systemctl --user start hyprland-session.target`. The unit ships in the image;
  starting it is this repository's job. Remove that line and portals stop
  working -- no screen sharing, no file chooser -- with nothing in any log until
  something asks for a portal. This is the job upstream expects `uwsm` to do,
  and `uwsm` is not packaged for Fedora.
- **`ecosystem.no_update_news` and `no_donation_nag` stay on.** Both popups are
  drawn by `hyprland-qtutils`, which no enabled repository packages, so both
  fail and complain. They are also wrong for a bootc image, which updates as a
  whole rather than per-component.

- **No Nerd Font, ever.** The image ships none -- its only symbol fonts are
  Noto Sans Symbols and URW Standard Symbols PS. The 288 Nerd Font files on the
  workstation live in `~/.local/share/fonts` and belong to the user, not the
  image, so a shell that depends on them gives a fresh account a bar full of
  tofu. Every icon is drawn in `Icon.qml` on a 24x24 grid. Add icons there.
- **Only `Theme.qml` holds colours and dimensions.** If a hex value appears
  anywhere else, that is the bug.

- **The shell never opens `~/.claude/.credentials.json`.** `ai-usage.sh` reads
  the token and emits only numbers, so no QML ever holds a credential; the token
  goes into curl's stdin config rather than an argument, so it is not in
  `/proc/*/cmdline` either. The usage endpoint behind it is undocumented and
  internal -- its replies carry fields called `nimbus_quill` and
  `iguana_necktie` -- so `ai-usage.jq` type-checks every field and a shape it
  does not recognise becomes **unknown, never 0%**. Plenty of headroom, shown at
  the moment there is none, is the failure that indicator exists to prevent.
  `just unit` pins it.

- **Monitors use `mode = "highres"`, never `"preferred"`.** A monitor's
  preferred mode is whatever its EDID advertises first, which is routinely not
  its best -- 144Hz panels commonly advertise 60. `highres` takes the highest
  resolution then the best rate at it; `highrr` would drop resolution to win Hz.
  The rule is `output = ""`, so nothing is hardcoded to one machine.

- **Monitor power goes through `quickshell/screen-power.sh`.** Hyprland 0.56
  offers no way to *command* a DPMS state: `hyprctl dispatch dpms off` is a parse
  error, and every Lua form -- `hl.dsp.dpms("on")`, `{ state = "on" }`,
  `{ on = true }` -- ignores its argument and toggles. That script reads the
  state first and toggles only when it differs, which is what makes it safe on an
  idle timer that may fire resume more than once. Never call the dispatcher
  directly.

## Rules

- **`hyprctl keyword` does not work.** Against a Lua config it refuses:
  "keyword can't work with non-legacy parsers. Use eval." Every guide online
  says `keyword`. Use `hyprctl eval` with the Lua API instead, e.g.
  `hyprctl eval 'hl.monitor({ output = "DP-2", mode = "highres", ... })'`.
- **Key repeat on a bind is spelled `repeating`.** Not `repeat` (a Lua keyword),
  and none of the obvious alternatives. Hyprland accepts an unknown option key
  **silently** -- `hl.bind` returns ok either way -- so a wrong name fails
  invisibly. `hyprctl binds -j` reports the resulting `repeat` field, and that
  is the only way to know it took.
- **`Hyprland.activeToplevel` is still null** in Quickshell 0.3.1, and
  `Hyprland.toplevels` is empty, while `hyprctl activewindow` reports correctly.
  Do not build on the Quickshell side of that until it is re-tested.
- **`set` and `toggle` cannot be signal names** in QML; the parser takes them
  for something else and fails with "Expected token ':'". Hence
  `valueRequested` and `muteRequested` in `VolumeRow.qml`.
- **Singletons are constructed lazily**, on first access. A service that polls
  will not have polled at the instant you first read it -- that is not a broken
  service, it is a service that has existed for a microsecond.
- **A service nothing on screen references never runs at all.** `Idle` is only
  used by the Session popout, which lives in a Loader, so swayidle never started
  until that popout was opened. `shell.qml` holds a property *binding* to it to
  force construction; a bare `void Idle.x;` in `Component.onCompleted` is
  optimised away and constructs nothing.
- **`StdioCollector` does not fire `onStreamFinished` on an empty stream.** A
  `cat` of a file that does not exist yet therefore never calls back, and any
  `loaded` flag set in that handler stays false forever. Append `; echo`.

- **Only bind programs the image ships.** A binding to something absent fails
  silently. `ghostty`, `swaylock`, `grim`, `slurp` are present; `kitty`,
  `dolphin` and `hyprlauncher` are not, which is what makes Hyprland's
  autogenerated default useless here. `foot` was the terminal until Ghostty
  shipped and is gone from the image; `fuzzel` and `mako` are gone too, for
  the reason in the next bullet.
- **No stand-ins remain.** The shell provides the launcher and the notification
  server; `fuzzel` and `mako` are gone from autostart *and* from the image.
  Removing mako from autostart alone is not enough -- it ships a D-Bus service
  file and gets activated on demand, and whichever process wins
  `org.freedesktop.Notifications` takes every notification while the other
  silently receives none.
- **`hyprctl dispatch` takes Lua too.** `hyprctl dispatch exec ghostty` fails in
  0.56; it is `hyprctl dispatch 'hl.dsp.exec_cmd("ghostty")'`. The old string
  dispatchers are gone along with the old config format.
- **Run `just check` before syncing.** Hyprland reports a bad config by failing
  to start a session, which is a slow way to find a typo.

- **Nothing reads the QML, and `just ci` passing says nothing about it.**
  `lint` reads Lua and shell, `check` reads Lua, `unit` reads one jq filter,
  and SonarQube Cloud supports neither QML nor Lua. The 7,400 lines under
  `quickshell/` are checked by nothing until a human runs a session and looks.
  That is how five calls to a popout API deleted by #14 reached `main` green in
  #12 and #13. Assume any QML you have not run is unverified.

  `qmllint` **can** read it -- established 2026-09-11 under #23 -- but only
  with all three of these, and it is not wired into `ci` yet:

  1. **Quickshell's `qmldir` and `.qmltypes` on the import path** (`-I`). The
     image installs them since scorchedblue#32; they are 480K of text across
     66 files and resolve identically when copied into a container that has Qt
     but no Quickshell. Without them all six Quickshell imports fail and every
     warning after that is cascade.
  2. **A `qmldir` for this repository's own 14 `pragma Singleton` files.**
     Without it they resolve as types but not as members, and every
     `Popouts.toggle` reads as a missing property.
  3. **`pragma ComponentBehavior: Bound` on `Bar.qml`.** Inside a nested
     `Component`, `root.x` is otherwise reported as bare `Unqualified access`
     -- qmllint cannot resolve `root` to a type, so it cannot judge the member,
     so the #12/#13 defect is invisible. With it, that defect reports as
     `Member "toggle" not found on type "Bar"`.

  Warnings across the 46 files, counted from qmllint's JSON: **1468** today,
  1192 with (1), **170** with (1)+(2), 136 with (1)+(2)+(3). The 12 that
  survive are all `Loader.item.x` and `parent.x` reads that are duck-typed on
  purpose, and need annotating rather than fixing.

- **`pragma ComponentBehavior: Bound` breaks implicit `modelData` and `index`.**
  It is not a lint-only pragma. Under it a `Repeater` delegate can no longer
  read the model data the view injects -- proven against Qt 6.11.2, the Qt the
  image ships -- so it may only be added to a file whose delegates already
  declare `required property`. `Bar.qml` does, for both its own `modelData` and
  the bar-entry delegate's, which is why it is the one file that can take it.
  The other 11 files with delegates carry 80 implicit reads between them, and
  adding the pragma to any of them blanks that list at runtime with nothing
  failing at load.

## Development loop

Config lives in `$HOME`, so it never needs an image rebuild. `just sync` pushes
to a running VM and reloads in place. See README for the VM's ssh forwarding.

## Unattended sessions

Work may be picked up by an unattended agent from the issue queue. The landing
path is a pull request with auto-merge, never a push to `main`.

**Never, at any authority level:**

- cosign keys, or anything in the signing path
- publishing to GHCR
- `bootc switch` / `rpm-ostree rebase` on the running machine
- adding a dependency that fails the vetting bar
- making `scorched-planning` public
- committing when `gitleaks` fires

Anything that cannot be settled alone becomes a `needs-decision` issue rather
than a guess. Report by commenting on the issue, not by committing a report.
