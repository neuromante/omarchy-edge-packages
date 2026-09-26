# Omarchy Edge Packages — RSS Feed and Quickshell Widget

**Version 1.0.0** · Public RSS feed of new and updated packages in Omarchy's `core`, `extra`, `multilib`, and `omarchy` edge repositories, with a Quickshell widget for the Omarchy bar.

## RSS feed

GitHub Actions checks the public pacman databases hourly and keeps the package-name and version snapshot in GitHub Actions' remote cache. The first run establishes a baseline without reporting existing packages as new. Packages added later and version changes become RSS items. The feed retains the latest 100 events.

Feed URL: <https://neuromante.github.io/omarchy-edge-packages/feed.xml>

Checks and processing run on GitHub-hosted runners. The widget only fetches the RSS response over HTTPS; it does not download pacman databases or save the package list locally.

## Omarchy widget

The repository can be installed directly as an Omarchy plugin. Its bar icon shows the number of recent feed entries; click it to open the list. The panel lets you choose the latest **10, 50, or 100** entries.

```bash
omarchy plugin add https://github.com/neuromante/omarchy-edge-packages --enable
```

The default feed refresh interval is one hour. The item limit, refresh interval, and feed URL can be changed in the plugin settings.

## Development and tests

```bash
python -m pip install -r requirements.txt
python -m unittest discover -s tests
```

The publishing workflow requires `pages: write` and `id-token: write`, declared in the workflow. Its package snapshot and event history are kept in GitHub Actions cache, not committed to the repository. See [CHANGELOG.md](CHANGELOG.md) for the initial release notes.
