import QtQuick
import qs.Commons
import qs.Ui
import qs.Ui as Ui

// Bar pill: headset glyph + battery %. Click opens the detail popup (OrbitPanel.qml),
// middle-click forces a refresh. Structure mirrors the built-in weather widget.
Ui.BarWidget {
  id: root
  moduleName: "bwzkk.orbit"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.anchorItem = button
    target.hostWidget = root
  }

  // Shape contract for shell summon/hide/toggle routing.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("OrbitPanel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // WidgetButton (not BarIconButton) so the "82%" label renders as regular
  // bar text in the theme font instead of being squeezed into an icon slot.
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: panelLoader.item ? panelLoader.item.label : "󰢔"
    dimmed: !panelLoader.item || !panelLoader.item.connected
    tooltipText: ""

    onPressed: function(b) {
      if (!root.bar || !panelLoader.item) return
      if (b === Qt.MiddleButton) panelLoader.item.refresh(true)
      else panelLoader.item.toggle()
    }
  }
}
