# AGENTS.md

Hand-written Omarchy shell plugin: bar icon (`Widget.qml`) that opens a bar-anchored popup on hover (MPRIS track info, playback controls, and a cava visualizer in `CavaVisualizer.qml`). Not a git checkout. Runs inside the long-running Quickshell process `omarchy-shell`.

Start here: load the `omarchy` skill (plugins.md) and read `/usr/share/omarchy/shell/README.md`. Best packaged references (read-only, safe to read): `services/media/BarWidget.qml` (canonical media widget: `BarWidget` root + anchored `PopupCard`), `Ui/BarWidget.qml` + `Ui/PopupCard.qml` (base + popup API), `Ui/Button.qml` (control API).

## Plugin id

- The shell keys the plugin by the **manifest `id`**, not the directory name. Directory is `omnimedia/` and the manifest id is `omnimedia` (renamed from `sanjar.now-playing` — formerly the template `yourname.now-playing`). Keep dir name == manifest id.
- The id appears in `manifest.json` `id` and in `Widget.qml` `moduleName`. If you ever rename it, update BOTH (there is no hardcoded `toggle <id>` IPC anymore — the widget opens its own popup).
- Enabling/placement is persisted in `~/.config/omarchy/shell.json` `bar.layout.<section>`; the widget currently sits in `right`. Manage it with `omarchy bar put/move <id>`. Check with `omarchy plugin list`, validate the manifest with `omarchy plugin validate <dir>`.

## Reload loop

Files under `~/.config/omarchy/plugins/` hot-reload on save; force with `omarchy-shell shell rescanPlugins`. There is no build/test step. `omarchy plugin enable` requires the manifest id to be correct first. Component load failures surface as `Plugin widget <id> failed:` warnings in `journalctl --user` (from the `omarchy-shell` process) — check there when nothing appears on the bar.

## Architecture

- Single `bar-widget` kind (the old `panel` kind was dropped): `Widget.qml` is a `BarWidget` (root: `moduleName`) hosting its own `PopupCard` anchored to itself, opened by hovering the icon (`triggerMode: "hover"`, `popupOpen` from the trigger `MouseArea`/`popup.containsMouse` with a 220 ms `closeDelay` to bridge the gap between icon and popup). A summoned `panel` entry point is NOT used, so a `panel`-kind manifest would hand the popup to the shell's panel loader and render it as an invisible floating surface instead.
- Why hover, not click: the default `PopupCard` click mode relies on `HyprlandFocusGrab`'s `onCleared` to dismiss on outside-click, and in this environment the compositor clears the grab ~2–4 s after the popup opens with no focus change, closing the popup spuriously. Hover mode skips the focus grab entirely.
- The bar injects `bar` / `moduleName` / `settings` into the widget root; `PopupCard` requires `anchorItem` + `bar`. Colors must come from the theme (`bar.foreground` / `bar.barForeground`, `Color.accent`, `Style.*`) — no hardcoded colors.
- Popup layout (`Column` in `Widget.qml`): title/artist texts, a `PanelSeparator`, a wallpaper-backed button band, another `PanelSeparator`, then the cava visualizer. The buttons band shows the current wallpaper (`~/.local/state/omarchy/current/background` symlink, read via `Util.fileUrl` + a `?v=` cache-buster bumped on popup open) dimmed with a translucent `Color.popups.background` overlay.
- Hot reload reloads the plugin's component, but a changed `Widget.qml` is only picked up after a full `omarchy restart shell` (the reload keeps a stale component in the slot).

## cava visualizer

Requires the `cava` binary (`/usr/bin/cava`). `CavaVisualizer` spawns `cava -p <config>` via `Quickshell.Io` `Process`; stdout goes through `SplitParser` (split each line on `;`, values 0–100 into `levels[]`). The config path is derived with `Qt.resolvedUrl("cava_config")` (same directory as the QML), so it stays correct wherever the plugin lives — do not hardcode a path. `cava_config` is the format contract (raw ascii, `;` delimiter, `ascii_max_range = 100`, `bars = 20`) — keep `barCount` in the QML in sync with `bars`. The process is gated by a `running` property (bound to the popup open state) so cava only runs while the popup is visible.

## MPRIS

`import Quickshell.Services.Mpris`; players = `Mpris.players.values`. Player API: `trackTitle`, `trackArtist`, `trackArtUrl`, `isPlaying`, `canGoPrevious/Next`, `canTogglePlaying`, `previous()/next()/togglePlaying()`. The widget tracks the active player (mirrors `omarchy.media`'s selection, minus the Pipewire playback-stream tiebreaker): players that start playing get an increasing `playSerial` in `playerStartedAt`, and `selectActivePlayer()` prefers a `preferredPlayerKey` (pinned when a control button is clicked), then the oldest currently-playing player, then the first player with metadata. An `Instantiator` of `Connections` re-syncs play order on `isPlayingChanged`. First-party `omarchy.media` (services/media/) is still the canonical full solution.
