import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "neuromante.omarchy-edge-packages"
  ipcTarget: ""
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var barObj: root.bar
  readonly property color fg: barObj ? barObj.foreground : Color.foreground
  readonly property color dim: Qt.darker(fg, 1.35)
  readonly property color accent: Color.accent
  readonly property string family: barObj ? barObj.fontFamily : Style.font.family
  readonly property var items: hostWidget ? hostWidget.items : []
  readonly property var allFeedItems: hostWidget ? hostWidget.feedItems : []
  property string searchText: ""
  readonly property var filteredItems: {
    var query = String(searchText || "").trim().toLowerCase()
    var source = query.length > 0 ? allFeedItems : items
    if (query.length === 0) return source
    var matches = []
    for (var i = 0; i < source.length; i++) {
      var item = source[i] || {}
      var text = [item.title || "", item.description || "", item.repo || "", item.kind || "", item.pubDate || ""]
        .join(" ").toLowerCase()
      if (text.indexOf(query) >= 0) matches.push(item)
    }
    return matches
  }
  readonly property var visibleItems: filteredItems.slice(0, itemLimit)
  readonly property int totalCount: hostWidget ? hostWidget.totalCount : 0
  readonly property int itemLimit: hostWidget ? hostWidget.itemLimit : 50
  readonly property bool checking: hostWidget ? hostWidget.checking : false
  readonly property string error: hostWidget ? hostWidget.error : ""

  onSearchTextChanged: flick.contentY = 0
  onItemLimitChanged: flick.contentY = 0

  function open() {
    root.controller.show()
    if (root.hostWidget && root.hostWidget.refresh) root.hostWidget.refresh()
  }
  function openFromHotkey() { root.open() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.open() }
  function closeForPopoutSwitch() { root.close() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }
  function refreshNow() { if (root.hostWidget && root.hostWidget.refresh) root.hostWidget.refresh() }
  function setLimit(value) { if (root.hostWidget && root.hostWidget.setItemLimit) root.hostWidget.setItemLimit(value) }
  function openExternal(url) {
    var target = String(url || "")
    if (/^https?:\/\//.test(target)) Qt.openUrlExternally(target)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTextKey: function(t) { if (t === "r") root.refreshNow() }
      onMoveRequested: function(dx, dy) {
        var step = dy * Style.space(44)
        flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + step))
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          property real speedMultiplier: 2.5
          onWheel: function(event) {
            var d = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * Style.space(40)
            var maxY = Math.max(0, flick.contentHeight - flick.height)
            flick.contentY = Math.max(0, Math.min(maxY, flick.contentY - d * speedMultiplier))
            event.accepted = true
          }
        }

        Column {
          id: content
          width: flick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            iconComponent: rssIcon
            title: "Omarchy edge updates"
            meta: root.error !== ""
              ? root.error
              : (root.checking
                ? "Loading RSS feed…"
                : (root.searchText.trim() !== ""
                  ? root.filteredItems.length + (root.filteredItems.length === 1 ? " match" : " matches")
                  : root.totalCount + (root.totalCount === 1 ? " unread update" : " unread updates")))
            foreground: root.fg
            fontFamily: root.family
          }

          Row {
            width: parent.width
            spacing: Style.space(8)
            Text {
              text: "Show"
              color: root.dim
              font.family: root.family
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }
            Repeater {
              model: [10, 50, 100]
              delegate: Item {
                required property int modelData
                readonly property bool selected: root.itemLimit === modelData
                implicitWidth: limitText.implicitWidth + Style.space(8)
                implicitHeight: Style.space(30)

                Text {
                  id: limitText
                  anchors.centerIn: parent
                  text: String(parent.modelData)
                  color: parent.selected ? root.accent : root.dim
                  font.family: root.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: parent.selected
                }

                Rectangle {
                  visible: parent.selected
                  width: Style.space(12)
                  height: Style.spacing.hairline
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.bottom: parent.bottom
                  color: root.accent
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setLimit(parent.modelData)
                }
              }
            }
            Item {
              implicitWidth: markReadText.implicitWidth + Style.space(8)
              implicitHeight: Style.space(30)

              Text {
                id: markReadText
                anchors.centerIn: parent
                text: "Mark all read"
                color: root.totalCount > 0 ? root.accent : root.dim
                font.family: root.family
                font.pixelSize: Style.font.bodySmall
                font.bold: root.totalCount > 0
              }

              MouseArea {
                anchors.fill: parent
                enabled: root.totalCount > 0
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  if (root.hostWidget && root.hostWidget.markAllRead)
                    root.hostWidget.markAllRead()
                }
              }
            }
            Text {
              text: "r · refresh"
              color: root.dim
              font.family: root.family
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Rectangle {
            width: parent.width
            height: Style.space(36)
            radius: Style.space(6)
            color: root.barObj ? Qt.darker(root.barObj.background, 1.08) : Color.background
            border.width: Style.spacing.hairline
            border.color: Qt.darker(root.fg, 1.5)

            TextInput {
              id: searchInput
              anchors.left: parent.left
              anchors.right: clearSearch.left
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              height: parent.height - Style.space(6)
              verticalAlignment: TextInput.AlignVCenter
              text: root.searchText
              color: root.fg
              font.family: root.family
              font.pixelSize: Style.font.bodySmall
              selectByMouse: true
              onTextChanged: root.searchText = text
            }

            Text {
              visible: searchInput.text.length === 0
              anchors.left: parent.left
              anchors.leftMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: "Search the feed…"
              color: root.dim
              font.family: root.family
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              id: clearSearch
              visible: searchInput.text.length > 0
              anchors.right: parent.right
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: "×"
              color: root.dim
              font.family: root.family
              font.pixelSize: Style.font.body

              MouseArea {
                anchors.fill: parent
                anchors.margins: -Style.space(5)
                cursorShape: Qt.PointingHandCursor
                onClicked: searchInput.clear()
              }
            }
          }

          Rectangle {
            width: parent.width
            height: Style.spacing.hairline
            color: root.fg
            opacity: 0.12
          }

          Text {
            visible: root.visibleItems.length === 0
            width: parent.width
            topPadding: Style.space(8)
            bottomPadding: Style.space(8)
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: root.error !== ""
              ? root.error
              : (root.checking
                ? "Connecting to the feed…"
                : (root.searchText.trim() !== ""
                  ? "No feed entries match this search."
                  : "No unread updates in the feed."))
            color: root.dim
            font.family: root.family
            font.pixelSize: Style.font.bodySmall
            font.italic: true
          }

          Column {
            visible: root.visibleItems.length > 0
            width: parent.width
            spacing: 0
            Repeater {
              model: root.visibleItems
              delegate: Column {
                required property var modelData
                required property int index
                width: content.width
                spacing: Style.space(4)

                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  Text {
                    text: String(modelData.repo || "edge").toUpperCase()
                    color: root.accent
                    font.family: root.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    width: parent.width - Style.space(80)
                    text: String(modelData.title || "Pacchetto edge")
                    color: root.fg
                    font.family: root.family
                    font.pixelSize: Style.font.body
                    font.bold: true
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                Text {
                  width: parent.width
                  text: String(modelData.description || "")
                  color: root.dim
                  font.family: root.family
                  font.pixelSize: Style.font.bodySmall
                  wrapMode: Text.WordWrap
                  maximumLineCount: 3
                  elide: Text.ElideRight
                }

                Text {
                  text: String(modelData.pubDate || "")
                  color: root.dim
                  opacity: 0.75
                  font.family: root.family
                  font.pixelSize: Style.font.caption
                }

                Rectangle {
                  width: parent.width
                  height: Style.spacing.hairline
                  color: root.fg
                  opacity: 0.08
                  visible: index < root.visibleItems.length - 1
                }
              }
            }
          }
        }
      }

      Rectangle {
        visible: root.visibleItems.length > 10 && flick.contentY > 0
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: Style.space(14)
        anchors.bottomMargin: Style.space(14)
        width: Style.space(34)
        height: Style.space(34)
        radius: Style.space(6)
        color: root.barObj ? root.barObj.background : Color.background
        border.width: Style.spacing.hairline
        border.color: root.dim
        z: 10

        Text {
          anchors.centerIn: parent
          text: "↑"
          color: root.accent
          font.family: root.family
          font.pixelSize: Style.font.body
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: scrollToTop.start()
        }
      }

      NumberAnimation {
        id: scrollToTop
        target: flick
        property: "contentY"
        to: 0
        duration: 220
        easing.type: Easing.OutCubic
      }
    }
  }

  Component {
    id: rssIcon
    Text {
      text: "\uf09e"
      color: root.fg
      font.family: root.family
      font.pixelSize: Style.font.displayLarge
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }
  }
}
