# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

- Lyrics support for the current track in the popup.
- Additional cava visualizer designs/themes, switchable from the popup.
- More polish on the progress bar and playback control fallbacks.

## [0.1.0] - 2026-08-15

First release.

### Added

- Bar widget (`Widget.qml`) showing the current track and play/pause state.
- Hover-open popup with album art, title, and artist.
- Draggable progress bar with seek support.
- Playback controls: repeat, previous, play/pause, next, shuffle.
- Live cava audio visualizer (`CavaVisualizer.qml`), running only while the
  popup is open.
- Automatic switching between MPRIS players (e.g. cliamp + YouTube Music),
  with a clickable source list when multiple players are active.
- `cliamp` repeat/shuffle support via the `cliamp` CLI.
- README, LICENSE, and AGENTS.md.

[Unreleased]: https://github.com/sanjar-xolmatov/NowPlaying/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sanjar-xolmatov/NowPlaying/releases/tag/v0.1.0
