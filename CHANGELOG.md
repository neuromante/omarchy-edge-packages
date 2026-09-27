# Changelog

## [1.3.0] — 2026-09-27

- Add a persistent “Mark all read” action to the widget; the badge and list now show only unread feed entries.

## [1.2.0] — 2026-09-26

- Increase repository polling and the widget's default refresh interval from 60 to 15 minutes.
- Restyle the 10/50/100 selector as rounded gray and white pills for clearer selection.

## [1.0.0] — 2026-09-26

Initial public release.

### Added

- Hourly monitoring of the x86_64 `core`, `extra`, `multilib`, and Omarchy `omarchy` edge pacman repositories.
- RSS 2.0 feed for newly added packages and package-version changes, retaining the latest 100 events.
- GitHub Actions polling and GitHub Pages feed hosting. Package snapshots and feed history stay in GitHub Actions' remote cache.
- Omarchy Quickshell bar widget with a popup list and 10, 50, or 100 item limits.
- HTTPS-only RSS fetching in the widget; package databases are not downloaded or stored on the user's machine.
