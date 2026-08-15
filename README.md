# OmniMedia

A friendly little music widget for the Omarchy status bar.

The bar icon shows the current track (and a playing/paused state). Hover it to
open a popup with album art, a draggable progress bar, playback controls, and a
live audio visualizer.

## Features

- Now-playing info on the bar: song name + play/pause state
- Popup with album art, title, and artist
- Progress bar — drag to seek
- Controls: repeat, previous, play/pause, next, shuffle
- Audio visualizer (cava) while the popup is open
- Switches between players (e.g. cliamp + YouTube Music) automatically,
  with a clickable source list when more than one is active

## Requirements

- Omarchy (the shell plugin API)
- `cava` — needed for the visualizer. Install it if you want the visualizer:

  ```sh
  omarchy pkg add cava
  ```

## Install

1. Put this folder in your user plugin directory:

   ```sh
   mkdir -p ~/.config/omarchy/plugins
   cp -r omnimedia ~/.config/omarchy/plugins/
   ```

2. Enable the plugin:

   ```sh
   omarchy plugin enable omnimedia
   ```

3. Add it to the bar (the right side is the default):

   ```sh
   omarchy bar put omnimedia --section right
   ```

4. Restart the shell to pick everything up:

   ```sh
   omarchy restart shell
   ```

## Use

- Hover the music icon on the bar to open the popup.
- Drag the progress bar to seek.
- Use repeat / previous / play-pause / next / shuffle to control playback.
- Repeat and shuffle light up with a background while active. If the current
  player doesn't support them (for example YouTube Music), the widget does its
  best: repeat loops the current track on its own, and shuffle stays greyed out
  since it can't be controlled.
- With multiple players open, click a source in the list to switch to it.

## Notes

- `cliamp` repeat/shuffle are driven through the `cliamp` CLI. Other players
  use the standard MPRIS interface.
- Changes to files in `~/.config/omarchy/plugins/` hot-reload; a full
  `omarchy restart shell` is recommended after editing `Widget.qml`.
