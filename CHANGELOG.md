# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

- Lyrics support for the current track in the popup.
- Additional cava visualizer designs/themes, switchable from the popup.
- More polish on the progress bar and playback control fallbacks.

## [0.2.0]

### Added

- YouTube track download via clipboard: copy a YouTube link, click Download,
  confirm in popup, save as tagged MP3 with embedded metadata and artwork.
- Confirmation popup showing video title, artist, thumbnail, and duration
  before download.
- Download button always visible (no longer gated on playing a YouTube track).
- Clipboard reading via `wl-paste` for YouTube URL detection.
- Metadata fetching via `yt-dlp --no-download` for preview info.
- Dependency detection for `yt-dlp` and `ffmpeg` with clear error messages.
- Download progress reporting (percentage displayed in the button).
- Cancel support for in-progress downloads and metadata fetches.
- Retry support for failed downloads.
- `--no-overwrites` and `--no-playlist` flags for safe, single-track downloads.

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

[Unreleased]: https://github.com/sanjar-xolmatov/OmniMedia/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/sanjar-xolmatov/OmniMedia/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/sanjar-xolmatov/OmniMedia/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/sanjar-xolmatov/NowPlaying/releases/tag/v0.1.0
