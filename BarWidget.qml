import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "neuromante.omarchy-edge-packages"

  readonly property string readerScript: Qt.resolvedUrl("bin/read-feed.py").toString().replace("file://", "")
  readonly property string feedUrl: String(setting("feedUrl", "https://neuromante.github.io/omarchy-edge-packages/feed.xml"))
  readonly property int itemLimit: {
    var n = parseInt(String(setting("itemLimit", "25")), 10)
    return [5, 25, 50].indexOf(n) >= 0 ? n : 25
  }
  readonly property int refreshIntervalMs: {
    var minutes = Math.round(Number(setting("refreshIntervalMinutes", 15)))
    if (!isFinite(minutes) || minutes < 15) minutes = 15
    if (minutes > 360) minutes = 360
    return minutes * 60000
  }

  property bool checking: false
  property int totalCount: 0
  property var items: []
  property var feedItems: []
  property var readIds: []
  property string error: ""
  property real lastChecked: 0
  property bool pending: false
  property bool blinkActive: false
  property bool blinkDimmed: false
  property var panelItem: null

  readonly property bool opened: panelItem ? panelItem.opened === true : false
  readonly property bool popoutSwitchClosing: panelItem ? panelItem.popoutSwitchClosing === true : false
  readonly property bool hasItems: totalCount > 0

  // Flash the icon when new unread updates appear, then hold a steady red.
  onTotalCountChanged: {
    if (totalCount > 0) {
      blinkDimmed = false
      blinkActive = true
      blinkStopTimer.restart()
    } else {
      blinkActive = false
      blinkDimmed = false
      blinkStopTimer.stop()
    }
  }

  function open() { if (panelItem && panelItem.openFromHotkey) panelItem.openFromHotkey() }
  function close() { if (panelItem && panelItem.close) panelItem.close() }
  function togglePanel() { if (panelItem && panelItem.toggle) panelItem.toggle() }
  function closeForPopoutSwitch() { if (panelItem && panelItem.closeForPopoutSwitch) panelItem.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    panelItem = target
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  onBarChanged: injectPanel()
  onSettingsChanged: {
    injectPanel()
    loadReadIds()
  }
  onItemLimitChanged: {
    updateUnread()
    refresh()
  }
  onFeedUrlChanged: refresh()

  function loadReadIds() {
    var saved = String(setting("readItemIds", "[]"))
    try {
      var parsed = JSON.parse(saved)
      readIds = Array.isArray(parsed) ? parsed : []
    } catch (e) {
      readIds = []
    }
    updateUnread()
  }

  function eventId(item) {
    return String(item.id || [item.title || "", item.pubDate || "", item.link || ""].join("|"))
  }

  function updateUnread() {
    var seen = {}
    for (var i = 0; i < readIds.length; i++) seen[String(readIds[i])] = true
    var unread = []
    for (var j = 0; j < feedItems.length; j++) {
      if (!seen[eventId(feedItems[j])]) unread.push(feedItems[j])
    }
    totalCount = unread.length
    items = unread.slice(0, itemLimit)
  }

  function markAllRead() {
    if (feedItems.length === 0) return
    var ids = {}
    for (var i = 0; i < readIds.length; i++) ids[String(readIds[i])] = true
    for (var j = 0; j < feedItems.length; j++) ids[eventId(feedItems[j])] = true
    var saved = Object.keys(ids).slice(-500)
    readIds = saved
    updateSetting("readItemIds", JSON.stringify(saved))
    updateUnread()
  }

  function updateSetting(key, value) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry[key] = String(value)
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setItemLimit(value) {
    if ([5, 25, 50].indexOf(Number(value)) < 0) return
    if (root.itemLimit === Number(value)) return
    root.updateSetting("itemLimit", String(value))
    root.refresh()
  }

  function refresh() {
    if (proc.running) {
      pending = true
      return
    }
    pending = false
    checking = true
    proc.command = ["python3", root.readerScript, root.feedUrl, String(root.itemLimit)]
    proc.running = true
  }

  function applyResult(text) {
    var result = null
    try { result = JSON.parse(text || "{}") } catch (e) { result = null }
    if (!result) {
      error = "Risposta del feed non valida"
      checking = false
      return
    }
    feedItems = Array.isArray(result.allItems)
      ? result.allItems
      : (Array.isArray(result.items) ? result.items : [])
    updateUnread()
    error = String(result.error || "")
    lastChecked = Number(result.checked) || 0
    checking = false
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "neuromante.omarchy-edge-packages"
    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf09e"
    active: root.hasItems
    activeColor: Commons.Color.urgent
    opacity: root.hasItems && root.blinkDimmed ? 0.35 : 1.0
    tooltipText: root.tooltipText
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.togglePanel()
      else if (b === Qt.MiddleButton) root.refresh()
    }
  }

  readonly property string tooltipText: {
    if (root.error !== "") return "Omarchy edge RSS: " + root.error
    if (root.checking && root.items.length === 0) return "Loading Omarchy edge updates…"
    if (!root.hasItems) return "No recent Omarchy edge updates"
    var lines = [root.totalCount + " unread Omarchy edge updates"]
    for (var i = 0; i < Math.min(root.items.length, 10); i++)
      lines.push(root.items[i].title)
    if (root.totalCount > root.items.length) lines.push("…")
    return lines.join("\n")
  }

  Timer {
    id: blinkTimer
    interval: 500
    running: root.blinkActive
    repeat: true
    onTriggered: root.blinkDimmed = !root.blinkDimmed
  }

  Timer {
    id: blinkStopTimer
    interval: 10000
    repeat: false
    onTriggered: {
      root.blinkActive = false
      root.blinkDimmed = false
    }
  }

  Timer {
    interval: root.refreshIntervalMs
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: initialTimer
    interval: 8000
    repeat: false
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    root.loadReadIds()
    initialTimer.start()
  }

  Process {
    id: proc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyResult(text)
    }
    onRunningChanged: {
      if (!running && root.pending) root.refresh()
    }
  }
}
