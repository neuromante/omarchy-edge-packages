# Omarchy Edge Packages — RSS Feed and Quickshell Widget

**Version 1.7.0** · Public RSS feed of new and updated packages in Omarchy's `core`, `extra`, `multilib`, and `omarchy` edge repositories, with a Quickshell widget for the Omarchy bar.

## RSS feed

GitHub Actions checks the public pacman databases every 15 minutes and keeps the package-name and version snapshot in GitHub Actions' remote cache. The first run establishes a baseline without reporting existing packages as new. Packages added later and version changes become RSS items. The feed retains the latest 100 events.

Feed URL: <https://neuromante.github.io/omarchy-edge-packages/feed.xml>

Checks and processing run on GitHub-hosted runners. The widget only fetches the RSS response over HTTPS; it does not download pacman databases or save the package list locally.

### Keeping the feed fresh

GitHub's `schedule` trigger is best-effort: runs are frequently delayed by minutes and can be skipped entirely, so the feed can lag behind the edge repositories. For predictable updates, point an external cron service (for example [cron-job.org](https://cron-job.org)) at the workflow's dispatch API every 15 minutes.

1. Create a token with permission to trigger workflows:
   - classic personal access token with the `workflow` scope, or
   - fine-grained token with **Actions: Read and write**.
   Keep it in the cron service's secret storage; never commit it.

2. Schedule a `POST` every 15 minutes to:

   ```
   https://api.github.com/repos/neuromante/omarchy-edge-packages/actions/workflows/publish-feed.yml/dispatches
   Authorization: Bearer <TOKEN>
   Accept: application/vnd.github+json
   Content-Type: application/json

   {"ref":"main"}
   ```

   The workflow also accepts the `repository_dispatch` event, so the equivalent call is the following (a fine-grained token then needs **Contents: Read and write** instead of Actions):

   ```
   https://api.github.com/repos/neuromante/omarchy-edge-packages/dispatches
   Authorization: Bearer <TOKEN>
   Accept: application/vnd.github+json
   Content-Type: application/json

   {"event_type":"publish-feed"}
   ```

The built-in `schedule` trigger stays in place as a fallback. Because the workflow only deploys when the generated feed actually changed, extra dispatches are harmless.

## Omarchy widget

The repository can be installed directly as an Omarchy plugin. Its bar icon flashes red when unread feed entries are available; click it to open the list. Use **Mark all read** to clear the current updates; future feed entries will appear as unread. The panel lets you choose the latest **10, 50, or 100** unread entries, search their text, and jump back to the top of long lists.

```bash
omarchy plugin add https://github.com/neuromante/omarchy-edge-packages --enable
```

The item limit can be changed in the widget panel. The refresh interval and feed URL are per-widget bar settings; set them from a terminal with `omarchy bar set`:

```bash
# Set the refresh interval in minutes (15–360; --json stores it as a number)
omarchy bar set neuromante.omarchy-edge-packages refreshIntervalMinutes 30 --json

# Use a different RSS endpoint
omarchy bar set neuromante.omarchy-edge-packages feedUrl https://example.org/packages.xml
```

The default refresh interval is 15 minutes. These two options do not currently have controls in the widget panel.

## Development and tests

```bash
python -m pip install -r requirements.txt
python -m unittest discover -s tests
```

The publishing workflow requires `pages: write` and `id-token: write`, declared in the workflow. Its package snapshot and event history are kept in GitHub Actions cache, not committed to the repository. See [CHANGELOG.md](CHANGELOG.md) for the initial release notes.
