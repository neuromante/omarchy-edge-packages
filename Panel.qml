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
  readonly property int totalCount: hostWidget ? hostWidget.totalCount : 0
  readonly property int itemLimit: hostWidget ? hostWidget.itemLimit : 50
  readonly property bool checking: hostWidget ? hostWidget.checking : false
  readonly property string error: hostWidget ? hostWidget.error : ""

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
                : root.totalCount + (root.totalCount === 1 ? " unread update" : " unread updates"))
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
              delegate: Rectangle {
                required property int modelData
                readonly property bool selected: root.itemLimit === modelData
                implicitWidth: limitText.implicitWidth + Style.space(24)
                implicitHeight: Style.space(30)
                radius: height / 2
                color: selected ? "#ffffff" : "#b8bec7"
                border.width: Style.spacing.hairline
                border.color: selected ? Qt.darker(root.fg, 1.4) : "#747b85"
                Text {
                  id: limitText
                  anchors.centerIn: parent
                  text: String(parent.modelData)
                  color: "#202124"
                  font.family: root.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: parent.selected
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.setLimit(parent.modelData)
                }
              }
            }
            Rectangle {
              implicitWidth: markReadText.implicitWidth + Style.space(24)
              implicitHeight: Style.space(30)
              radius: height / 2
              color: root.totalCount > 0 ? "#ffffff" : "#b8bec7"
              border.width: Style.spacing.hairline
              border.color: root.totalCount > 0 ? Qt.darker(root.fg, 1.4) : "#747b85"
              opacity: root.totalCount > 0 ? 1 : 0.55

              Text {
                id: markReadText
                anchors.centerIn: parent
                text: "Mark all read"
                color: "#202124"
                font.family: root.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
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
            height: Style.spacing.hairline
            color: root.fg
            opacity: 0.12
          }

          Text {
            visible: root.items.length === 0
            width: parent.width
            topPadding: Style.space(8)
            bottomPadding: Style.space(8)
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            text: root.error !== ""
              ? root.error
              : (root.checking ? "Connecting to the feed…" : "No unread updates in the feed.")
            color: root.dim
            font.family: root.family
            font.pixelSize: Style.font.bodySmall
            font.italic: true
          }

          Column {
            visible: root.items.length > 0
            width: parent.width
            spacing: 0
            Repeater {
              model: root.items
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
                  visible: index < root.items.length - 1
                }
              }
            }
          }
        }
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
