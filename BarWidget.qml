import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "neuromante.omarchy-edge-packages"

  readonly property string readerScript: Qt.resolvedUrl("bin/read-feed.py").toString().replace("file://", "")
  readonly property string feedUrl: String(setting("feedUrl", "https://neuromante.github.io/omarchy-edge-packages/feed.xml"))
  readonly property int itemLimit: {
    var n = parseInt(String(setting("itemLimit", "50")), 10)
    return [10, 50, 100].indexOf(n) >= 0 ? n : 50
  }
  readonly property int refreshIntervalMs: {
    var minutes = Math.round(Number(setting("refreshIntervalMinutes", 60)))
    if (!isFinite(minutes) || minutes < 15) minutes = 60
    if (minutes > 360) minutes = 360
    return minutes * 60000
  }

  property bool checking: false
  property int totalCount: 0
  property var items: []
  property string error: ""
  property real lastChecked: 0
  property bool pending: false
  property var panelItem: null

  readonly property bool opened: panelItem ? panelItem.opened === true : false
  readonly property bool popoutSwitchClosing: panelItem ? panelItem.popoutSwitchClosing === true : false
  readonly property bool hasItems: totalCount > 0

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
  onSettingsChanged: injectPanel()
  onItemLimitChanged: refresh()
  onFeedUrlChanged: refresh()

  function updateSetting(key, value) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry[key] = String(value)
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setItemLimit(value) {
    if ([10, 50, 100].indexOf(Number(value)) < 0) return
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
    items = Array.isArray(result.items) ? result.items : []
    totalCount = Math.max(0, Math.round(Number(result.total) || 0))
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
    activeColor: Color.accent
    tooltipText: root.tooltipText
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.togglePanel()
      else if (b === Qt.MiddleButton) root.refresh()
    }
  }

  readonly property string tooltipText: {
    if (root.error !== "") return "Omarchy edge RSS: " + root.error
    if (root.checking && root.items.length === 0) return "Lettura novità Omarchy edge…"
    if (!root.hasItems) return "Nessuna novità recente in Omarchy edge"
    var lines = [root.totalCount + " eventi recenti in Omarchy edge"]
    for (var i = 0; i < Math.min(root.items.length, 10); i++)
      lines.push(root.items[i].title)
    if (root.totalCount > root.items.length) lines.push("…")
    return lines.join("\n")
  }

  Rectangle {
    visible: root.totalCount > 0
    anchors.top: button.top
    anchors.right: button.right
    z: 10
    readonly property string countText: root.totalCount > 99 ? "99+" : String(root.totalCount)
    implicitWidth: Math.max(Style.space(12), badgeLabel.implicitWidth + Style.space(5))
    implicitHeight: Style.space(12)
    radius: height / 2
    color: Color.accent
    border.width: 1
    border.color: root.bar ? root.bar.background : "transparent"

    Text {
      id: badgeLabel
      anchors.centerIn: parent
      text: parent.countText
      color: Color.background
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption * 0.72
      font.bold: true
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

  Component.onCompleted: initialTimer.start()

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
