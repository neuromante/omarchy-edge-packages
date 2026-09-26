# Changelog

## [1.0.0] — 2026-09-26

Initial public release.

### Added

- Hourly monitoring of the x86_64 `core`, `extra`, `multilib`, and Omarchy `omarchy` edge pacman repositories.
- RSS 2.0 feed for newly added packages and package-version changes, retaining the latest 100 events.
- GitHub Actions polling and GitHub Pages feed hosting. Package snapshots and feed history stay in GitHub Actions' remote cache.
- Omarchy Quickshell bar widget with a popup list and 10, 50, or 100 item limits.
- HTTPS-only RSS fetching in the widget; package databases are not downloaded or stored on the user's machine.
- Baseline initialization that avoids presenting packages already in the repositories as new arrivals.
- Tests for pacman database parsing (gzip and zstd), package change detection, RSS generation, and widget feed parsing.

### Verification

- Confirmed the GitHub-hosted workflow can fetch and parse all four edge databases; its baseline scan reported 299 `core`, 14,996 `extra`, 182 `multilib`, and 261 `omarchy` packages.
- Confirmed subsequent workflow runs restore the previous remote snapshot and complete successfully.
